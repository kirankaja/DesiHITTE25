import Foundation
import Combine

enum WorkoutState: String {
    case idle
    case warmup
    case active
    case cooldown
    case complete
}

class WorkoutEngine: ObservableObject {
    // MARK: - Published Properties
    @Published var currentInterval: WorkoutInterval?
    @Published var currentZone: WorkoutZone = .grey
    @Published var splatPoints: Int = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var intervalTimeRemaining: TimeInterval = 0
    @Published var isWorkoutActive = false
    @Published var caloriesEstimate: Int = 0
    @Published var workoutState: WorkoutState = .idle
    @Published var currentIntervalIndex: Int = 0
    @Published var resistanceSuggestion: String = ""

    // MARK: - Dependencies
    private var heartRateRouter: HeartRateRouter
    private var voiceCoach: VoiceCoach
    private var youtubeManager: YouTubePlayerManager

    // MARK: - Private State
    private var template: WorkoutTemplate?
    private var workoutTimer: Timer?
    private var splatAccumulator: Double = 0.0
    private var hrReadings: [Int] = []
    private var maxRecordedHR: Int = 0
    private var maxHR: Int = 190
    private var lastZone: WorkoutZone = .grey
    private var lastMotivationTime: Date = Date.distantPast
    private var motivationInterval: TimeInterval = 35
    private var zoneTimers: [WorkoutZone: TimeInterval] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(heartRateRouter: HeartRateRouter, voiceCoach: VoiceCoach, youtubeManager: YouTubePlayerManager) {
        self.heartRateRouter = heartRateRouter
        self.voiceCoach = voiceCoach
        self.youtubeManager = youtubeManager

        for zone in WorkoutZone.allCases {
            zoneTimers[zone] = 0
        }

        setupHRSubscription()
    }

    // MARK: - HR Subscription

    private func setupHRSubscription() {
        heartRateRouter.$heartRate
            .receive(on: RunLoop.main)
            .sink { [weak self] hr in
                guard let self = self, hr > 0 else { return }
                self.processHeartRate(hr)
            }
            .store(in: &cancellables)
    }

    private func processHeartRate(_ hr: Int) {
        let newZone = WorkoutZone.zone(forHeartRate: hr, maxHR: maxHR)
        hrReadings.append(hr)
        if hr > maxRecordedHR { maxRecordedHR = hr }

        if newZone != lastZone && isWorkoutActive {
            voiceCoach.announceZoneChange(to: newZone)
            let category = BollywoodPlaylist.category(for: newZone)
            youtubeManager.switchPlaylist(to: category)
            lastZone = newZone
        }

        currentZone = newZone
        updateResistanceSuggestion()
    }

    // MARK: - Workout Control

    func startWorkout(template: WorkoutTemplate, maxHR: Int, motivationFrequency: TimeInterval = 35) {
        self.template = template
        self.maxHR = maxHR
        self.motivationInterval = motivationFrequency
        splatPoints = 0
        splatAccumulator = 0
        elapsedTime = 0
        caloriesEstimate = 0
        hrReadings = []
        maxRecordedHR = 0
        currentIntervalIndex = 0
        lastZone = .grey
        lastMotivationTime = Date()

        for zone in WorkoutZone.allCases {
            zoneTimers[zone] = 0
        }

        #if targetEnvironment(simulator)
        heartRateRouter.bluetooth.startSimulatedWorkout()
        #endif

        isWorkoutActive = true
        advanceToInterval(index: 0)
        startTimer()

        voiceCoach.announce("Chalo! Let's begin! \(template.name) workout starting now!")
        youtubeManager.switchPlaylist(to: .moderate)
        youtubeManager.play()
    }

    func pauseWorkout() {
        workoutTimer?.invalidate()
        workoutTimer = nil
        isWorkoutActive = false
        voiceCoach.announce("Workout paused. Take a breath.")
        youtubeManager.pause()
    }

    func resumeWorkout() {
        isWorkoutActive = true
        startTimer()
        voiceCoach.announce("Let's go! Workout resumed!")
        youtubeManager.play()
    }

    func skipInterval() {
        guard let template = template else { return }
        let nextIndex = currentIntervalIndex + 1
        if nextIndex < template.intervals.count {
            advanceToInterval(index: nextIndex)
            voiceCoach.announce("Skipping ahead. \(template.intervals[nextIndex].name) starting now!")
        } else {
            completeWorkout()
        }
    }

    func endWorkout() {
        completeWorkout()
    }

    func createSession() -> WorkoutSession {
        let avgHR = hrReadings.isEmpty ? 0 : hrReadings.reduce(0, +) / hrReadings.count
        return WorkoutSession(
            templateName: template?.name ?? "Workout",
            startDate: Date().addingTimeInterval(-elapsedTime),
            endDate: Date(),
            totalDuration: elapsedTime,
            splatPoints: splatPoints,
            caloriesBurned: caloriesEstimate,
            averageHeartRate: avgHR,
            maxHeartRate: maxRecordedHR,
            timeInGrey: zoneTimers[.grey] ?? 0,
            timeInBlue: zoneTimers[.blue] ?? 0,
            timeInGreen: zoneTimers[.green] ?? 0,
            timeInOrange: zoneTimers[.orange] ?? 0,
            timeInRed: zoneTimers[.red] ?? 0
        )
    }

    // MARK: - Private Methods

    private func startTimer() {
        workoutTimer?.invalidate()
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard isWorkoutActive else { return }

        elapsedTime += 1
        intervalTimeRemaining -= 1

        // Track zone time
        zoneTimers[currentZone, default: 0] += 1

        // Splat point accumulation (1 point per minute in orange/red)
        if currentZone.splatEligible {
            splatAccumulator += 1.0
            if splatAccumulator >= 60.0 {
                splatPoints += 1
                splatAccumulator -= 60.0

                if splatPoints % 5 == 0 {
                    voiceCoach.announce("Shandar! \(splatPoints) splat points! Keep pushing!")
                }
            }
        }

        // Calorie estimation (rough MET-based)
        let metValue: Double
        switch currentZone {
        case .grey: metValue = 2.0
        case .blue: metValue = 4.0
        case .green: metValue = 6.5
        case .orange: metValue = 9.0
        case .red: metValue = 12.0
        }
        // ~75kg assumed weight, calories per second
        caloriesEstimate = Int(Double(elapsedTime) / 60.0 * metValue * 75.0 / 200.0)

        // Motivational phrases during pushes
        if currentZone == .orange || currentZone == .red {
            let timeSinceMotivation = Date().timeIntervalSince(lastMotivationTime)
            if timeSinceMotivation >= motivationInterval {
                voiceCoach.motivate()
                lastMotivationTime = Date()
            }
        }

        // Interval countdown
        if intervalTimeRemaining <= 3 && intervalTimeRemaining > 0 {
            voiceCoach.countdown(from: Int(intervalTimeRemaining))
        }

        // Check interval completion
        if intervalTimeRemaining <= 0 {
            advanceToNextInterval()
        }

        #if targetEnvironment(simulator)
        // In simulator, gradually shift HR toward target zone
        if let interval = currentInterval {
            heartRateRouter.bluetooth.simulateHRForZone(interval.targetZone, maxHR: maxHR)
        }
        #endif
    }

    private func advanceToInterval(index: Int) {
        guard let template = template, index < template.intervals.count else {
            completeWorkout()
            return
        }

        currentIntervalIndex = index
        let interval = template.intervals[index]
        currentInterval = interval
        intervalTimeRemaining = interval.duration

        // Determine workout state
        if interval.name.lowercased().contains("warm") {
            workoutState = .warmup
        } else if interval.name.lowercased().contains("cool") {
            workoutState = .cooldown
        } else {
            workoutState = .active
        }

        voiceCoach.announceIntervalChange(interval)
        updateResistanceSuggestion()
    }

    private func advanceToNextInterval() {
        let nextIndex = currentIntervalIndex + 1
        advanceToInterval(index: nextIndex)
    }

    private func completeWorkout() {
        workoutTimer?.invalidate()
        workoutTimer = nil
        isWorkoutActive = false
        workoutState = .complete

        #if targetEnvironment(simulator)
        heartRateRouter.bluetooth.stopSimulatedWorkout()
        #endif

        voiceCoach.announce("Bahut acche! Workout complete! You earned \(splatPoints) splat points today! Great job!")
        youtubeManager.pause()
    }

    private func updateResistanceSuggestion() {
        guard let interval = currentInterval, isWorkoutActive else {
            resistanceSuggestion = ""
            return
        }

        let targetZone = interval.targetZone
        if currentZone.rawValue < targetZone.rawValue {
            let suggestedResistance = interval.resistanceRange.upperBound
            resistanceSuggestion = "⬆️ Increase resistance to \(suggestedResistance)"
            if currentZone.rawValue < targetZone.rawValue - 1 {
                voiceCoach.announce("Pick it up! Increase your resistance!")
            }
        } else if currentZone.rawValue > targetZone.rawValue {
            let suggestedResistance = interval.resistanceRange.lowerBound
            resistanceSuggestion = "⬇️ Decrease resistance to \(suggestedResistance)"
        } else {
            resistanceSuggestion = "✅ Perfect zone! Resistance \(interval.resistanceRange.lowerBound)-\(interval.resistanceRange.upperBound)"
        }
    }

    // MARK: - Computed Properties

    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedIntervalTimeRemaining: String {
        let minutes = Int(max(0, intervalTimeRemaining)) / 60
        let seconds = Int(max(0, intervalTimeRemaining)) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard let template = template else { return 0 }
        return min(1.0, elapsedTime / template.totalDuration)
    }

    var averageHR: Int {
        guard !hrReadings.isEmpty else { return 0 }
        return hrReadings.reduce(0, +) / hrReadings.count
    }
}
