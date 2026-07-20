import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let template: WorkoutTemplate
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var voiceCoach: VoiceCoach
    @ObservedObject var youtubeManager: YouTubePlayerManager
    @ObservedObject var hrRouter: HeartRateRouter
    let maxHR: Int
    let motivationFrequency: TimeInterval

    @StateObject private var workoutEngine: WorkoutEngine

    @State private var showSummary = false
    @State private var completedSession: WorkoutSession?
    @State private var showEndConfirm = false

    init(template: WorkoutTemplate,
         bluetoothManager: BluetoothManager,
         voiceCoach: VoiceCoach,
         youtubeManager: YouTubePlayerManager,
         hrRouter: HeartRateRouter,
         maxHR: Int,
         motivationFrequency: TimeInterval) {
        self.template = template
        self.bluetoothManager = bluetoothManager
        self.voiceCoach = voiceCoach
        self.youtubeManager = youtubeManager
        self.hrRouter = hrRouter
        self.maxHR = maxHR
        self.motivationFrequency = motivationFrequency
        _workoutEngine = StateObject(wrappedValue: WorkoutEngine(
            heartRateRouter: hrRouter,
            voiceCoach: voiceCoach,
            youtubeManager: youtubeManager
        ))
    }

    var body: some View {
        ZStack {
            workoutEngine.currentZone.color.opacity(0.1)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.0), value: workoutEngine.currentZone)

            VStack(spacing: 0) {
                ZoneBarView(
                    currentZone: workoutEngine.currentZone,
                    heartRate: hrRouter.heartRate,
                    maxHR: maxHR
                )
                .padding(.horizontal)
                .padding(.top, 8)

                statsRow
                    .padding(.horizontal)
                    .padding(.top, 8)

                YouTubePlayerView(manager: youtubeManager)
                    .frame(height: UIScreen.main.bounds.height * 0.3)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 8)

                if let track = youtubeManager.currentTrack {
                    HStack(spacing: 8) {
                        Image(systemName: "music.quarternote.3")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(track.title)
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("· \(track.bpm) BPM")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }

                intervalInfo
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                controlBar
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            workoutEngine.startWorkout(
                template: template,
                maxHR: maxHR,
                motivationFrequency: motivationFrequency
            )
        }
        .onChange(of: workoutEngine.workoutState) { _, newState in
            if newState == .complete {
                let session = workoutEngine.createSession()
                modelContext.insert(session)
                completedSession = session
                showSummary = true
            }
        }
        .fullScreenCover(isPresented: $showSummary) {
            if let session = completedSession {
                WorkoutSummaryView(session: session, onDismiss: {
                    showSummary = false
                    dismiss()
                })
            }
        }
        .alert("End Workout?", isPresented: $showEndConfirm) {
            Button("End", role: .destructive) {
                workoutEngine.endWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this workout?")
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            // Heart Rate
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(workoutEngine.currentZone.color)
                    Text("\(hrRouter.heartRate)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(workoutEngine.currentZone.color)
                }
                Text("BPM")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            // Splat Points
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(workoutEngine.splatPoints)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                Text("Splats")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            // Timer
            VStack(spacing: 2) {
                Text(workoutEngine.formattedElapsedTime)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("Elapsed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Interval Info

    private var intervalInfo: some View {
        VStack(spacing: 8) {
            if let interval = workoutEngine.currentInterval {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(interval.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        HStack(spacing: 8) {
                            Label(interval.targetZone.name, systemImage: "target")
                                .font(.caption)
                                .foregroundColor(interval.targetZone.color)
                            Label(
                                "R: \(interval.resistanceRange.lowerBound)-\(interval.resistanceRange.upperBound)",
                                systemImage: "dial.medium"
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(workoutEngine.formattedIntervalTimeRemaining)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(interval.targetZone.color)
                        Text("remaining")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if !workoutEngine.resistanceSuggestion.isEmpty {
                    Text(workoutEngine.resistanceSuggestion)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.yellow)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.15))
                        .cornerRadius(8)
                }

                // Interval progress bar
                ProgressView(value: 1.0 - (workoutEngine.intervalTimeRemaining / (workoutEngine.currentInterval?.duration ?? 1)))
                    .tint(interval.targetZone.color)

                // Next interval preview
                let nextIndex = workoutEngine.currentIntervalIndex + 1
                if nextIndex < template.intervals.count {
                    let next = template.intervals[nextIndex]
                    HStack {
                        Text("Up Next:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(next.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(next.targetZone.color)
                        Text("• \(next.formattedDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 20) {
            // Mute Coach
            Button {
                voiceCoach.isMuted.toggle()
            } label: {
                Image(systemName: voiceCoach.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundColor(voiceCoach.isMuted ? .red : .white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            // Skip Interval
            Button {
                workoutEngine.skipInterval()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            // Play/Pause
            Button {
                if workoutEngine.isWorkoutActive {
                    workoutEngine.pauseWorkout()
                } else if workoutEngine.workoutState != .complete {
                    workoutEngine.resumeWorkout()
                }
            } label: {
                Image(systemName: workoutEngine.isWorkoutActive ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            }

            // Skip song (finds a similar-BPM track in the current playlist)
            Button {
                workoutEngine.skipSong()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Skip song, similar BPM")

            // End Workout
            Button {
                showEndConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.red)
                    .frame(width: 44, height: 44)
                    .background(Color.red.opacity(0.15))
                    .clipShape(Circle())
            }
        }
    }
}
