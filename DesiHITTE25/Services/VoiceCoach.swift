import Foundation
import AVFoundation
import Combine

class VoiceCoach: ObservableObject {
    // MARK: - Published Properties
    @Published var isSpeaking = false
    @Published var isMuted = false
    @Published var coachVolume: Float = 0.8

    // MARK: - Private
    private let synthesizer = AVSpeechSynthesizer()
    private let delegate: SpeechDelegate

    // MARK: - Motivational Phrases (English + Hindi mix)
    private let pushMotivations: [String] = [
        "Chalo! Let's go! You're doing amazing!",
        "Bahut acche! Keep pushing!",
        "Ek aur minute! One more minute, give it everything!",
        "Dil se push karo! Push from the heart!",
        "You're on fire! Aag laga do!",
        "Don't stop now! Rukna nahi hai!",
        "Shandar performance! Keep it up!",
        "Tum best ho! You're the best!",
        "Jor se! Harder! You've got this!",
        "Kya baat hai! Looking strong!",
        "Power badhao! Increase that power!",
        "Ab dikhao! Show what you've got!",
        "Himmat mat haro! Don't give up!",
        "Arre wah! Incredible effort!",
        "Full power! Maximum effort!",
        "Tu kar sakta hai! You can do this!",
        "Bahut badhiya! Absolutely fantastic!",
        "Aur tez! Faster! Let's go!",
        "Champion! You're a champion today!",
        "Fateh ke liye! Push for victory!",
    ]

    private let zoneMessages: [WorkoutZone: [String]] = [
        .grey: [
            "Aaram se. Nice and easy, bring that heart rate down.",
            "Relax karo. Let your body recover.",
            "Easy does it. Breathe deeply.",
        ],
        .blue: [
            "Warm up zone. Dhire dhire shuru karo.",
            "Blue zone. Light effort, find your rhythm.",
            "Recovery time. Saans lo, breathe easy.",
        ],
        .green: [
            "Green zone! Base pace. Comfortable but challenging.",
            "Green zone! Ye tera base hai. Hold this pace.",
            "Moderate effort. You should be able to talk.",
        ],
        .orange: [
            "Orange zone! Push pace! This is where splats happen!",
            "Orange zone! Ab kaam shuru! Time to work!",
            "Push zone! Feel that burn, embrace it!",
        ],
        .red: [
            "Red zone! All out! Sab kuch de do!",
            "Maximum effort! Red zone! Leave nothing behind!",
            "All out! Puri taakat! Give everything!",
        ],
    ]

    init() {
        self.delegate = SpeechDelegate()
        synthesizer.delegate = delegate
        delegate.onFinish = { [weak self] in
            self?.isSpeaking = false
            self?.restoreAudioSession()
        }
    }

    // MARK: - Public Methods

    func announce(_ text: String) {
        guard !isMuted else { return }

        configureAudioSessionForSpeech()

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.52
        utterance.volume = coachVolume
        utterance.pitchMultiplier = 1.05

        // Detect Hindi words to choose voice
        if containsHindi(text) {
            utterance.voice = AVSpeechSynthesisVoice(language: "hi-IN")
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        // Use English voice for mixed content (most messages)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func announceZoneChange(to zone: WorkoutZone) {
        guard !isMuted else { return }
        let messages = zoneMessages[zone] ?? []
        let message = messages.randomElement() ?? "Moving to \(zone.name) zone!"
        announce(message)
    }

    func announceIntervalChange(_ interval: WorkoutInterval) {
        guard !isMuted else { return }
        let resistanceText = "Resistance \(interval.resistanceRange.lowerBound) to \(interval.resistanceRange.upperBound)"
        let durationText = interval.formattedDuration

        switch interval.targetZone {
        case .grey, .blue:
            announce("\(interval.name) starting. \(durationText). \(resistanceText). Aaram se, take it easy.")
        case .green:
            announce("\(interval.name) starting now! \(durationText). \(resistanceText). Find your base pace!")
        case .orange:
            announce("\(interval.name) starting now! \(durationText) at high intensity! \(resistanceText). Chalo, push it!")
        case .red:
            announce("\(interval.name)! \(durationText)! All out! \(resistanceText). Sab kuch de do!")
        }
    }

    func motivate() {
        guard !isMuted else { return }
        let phrase = pushMotivations.randomElement() ?? "Keep going!"
        announce(phrase)
    }

    func countdown(from count: Int) {
        guard !isMuted else { return }
        switch count {
        case 3:
            announce("3...")
        case 2:
            announce("2...")
        case 1:
            announce("1... GO!")
        default:
            break
        }
    }

    func announceSplatMilestone(_ points: Int) {
        guard !isMuted else { return }
        announce("Shandar! \(points) splat points! Keep pushing!")
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        restoreAudioSession()
    }

    // MARK: - Audio Session Management

    private func configureAudioSessionForSpeech() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("VoiceCoach: Failed to configure audio session: \(error)")
        }
    }

    private func restoreAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("VoiceCoach: Failed to restore audio session: \(error)")
        }
    }

    private func containsHindi(_ text: String) -> Bool {
        let hindiWords = ["chalo", "bahut", "acche", "aaram", "shandar", "karo",
                          "hai", "dil", "jor", "tez", "badhiya", "himmat",
                          "fateh", "arre", "wah", "dhire", "saans", "taakat",
                          "rukna", "dikhao", "sakta", "se"]
        let lowered = text.lowercased()
        return hindiWords.contains { lowered.contains($0) }
    }
}

// MARK: - Speech Delegate

private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.onFinish?()
        }
    }
}
