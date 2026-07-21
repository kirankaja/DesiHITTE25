import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let template: WorkoutTemplate
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var voiceCoach: VoiceCoach
    @ObservedObject var musicRouter: MusicRouter
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
         musicRouter: MusicRouter,
         hrRouter: HeartRateRouter,
         maxHR: Int,
         motivationFrequency: TimeInterval) {
        self.template = template
        self.bluetoothManager = bluetoothManager
        self.voiceCoach = voiceCoach
        self.musicRouter = musicRouter
        self.hrRouter = hrRouter
        self.maxHR = maxHR
        self.motivationFrequency = motivationFrequency
        _workoutEngine = StateObject(wrappedValue: WorkoutEngine(
            heartRateRouter: hrRouter,
            voiceCoach: voiceCoach,
            musicController: musicRouter
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
                    targetZone: workoutEngine.currentInterval?.targetZone,
                    heartRate: hrRouter.heartRate,
                    maxHR: maxHR
                )
                .padding(.horizontal)
                .padding(.top, 8)

                workoutProgress
                    .padding(.horizontal)
                    .padding(.top, 6)

                statsRow
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Compact audio strip — YouTube video is intentionally tiny
                // (48pt) so it doesn't compete with workout data. Jamendo has
                // no video, so we show a small album-art tile instead. The
                // now-playing row below is the primary "what's playing" cue.
                HStack(spacing: 10) {
                    Group {
                        if musicRouter.activeSource == .youtube {
                            YouTubePlayerView(manager: musicRouter.youtubeManager)
                        } else {
                            JamendoMiniArt(track: musicRouter.jamendoSource.currentTrack)
                        }
                    }
                    .frame(width: 72, height: 48)
                    .cornerRadius(6)
                    .clipped()
                    .accessibilityHidden(true)

                    if !musicRouter.currentTitle.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: "music.quarternote.3")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(musicRouter.currentTitle)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            if let bpm = musicRouter.currentBPM {
                                Text("\(bpm) BPM")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(.white.opacity(0.6))
                            } else {
                                Text(musicRouter.activeSource.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Now playing \(musicRouter.currentTitle)")
                    } else {
                        Text("Loading music…")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

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
            // Keep the screen awake during a workout — locking mid-set is a
            // real usability failure when the user's hands are on the machine.
            UIApplication.shared.isIdleTimerDisabled = true
            workoutEngine.startWorkout(
                template: template,
                maxHR: maxHR,
                motivationFrequency: motivationFrequency
            )
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: workoutEngine.currentIntervalIndex)
        .sensoryFeedback(.selection, trigger: workoutEngine.currentZone)
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

    // MARK: - Workout Progress

    /// Slim progress strip: "Interval 3 of 7" + total-workout progress bar.
    /// Lets the user pace themselves at a glance without doing mental math.
    private var workoutProgress: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Interval \(workoutEngine.currentIntervalIndex + 1) of \(template.intervals.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(template.formattedTotalDuration)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            ProgressView(value: workoutEngine.progress)
                .tint(.orange)
                .scaleEffect(x: 1, y: 0.6, anchor: .center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Interval \(workoutEngine.currentIntervalIndex + 1) of \(template.intervals.count)")
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
        HStack(spacing: 16) {
            controlButton(
                systemImage: voiceCoach.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: voiceCoach.isMuted ? "Unmute" : "Mute",
                tint: voiceCoach.isMuted ? .red : .white,
                accessibilityLabel: voiceCoach.isMuted ? "Unmute coach" : "Mute coach"
            ) {
                voiceCoach.isMuted.toggle()
            }

            controlButton(
                systemImage: "forward.fill",
                label: "Interval",
                tint: .white,
                accessibilityLabel: "Skip to next interval"
            ) {
                workoutEngine.skipInterval()
            }

            // Play / Pause — primary, larger
            VStack(spacing: 4) {
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
                .accessibilityLabel(workoutEngine.isWorkoutActive ? "Pause workout" : "Resume workout")
                .sensoryFeedback(.impact(weight: .heavy), trigger: workoutEngine.isWorkoutActive)

                Text(workoutEngine.isWorkoutActive ? "Pause" : "Play")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }

            controlButton(
                systemImage: "forward.end.fill",
                label: "Song",
                tint: .white,
                accessibilityLabel: "Skip song, similar BPM"
            ) {
                workoutEngine.skipSong()
            }

            controlButton(
                systemImage: "xmark",
                label: "End",
                tint: .red,
                bg: Color.red.opacity(0.15),
                accessibilityLabel: "End workout"
            ) {
                showEndConfirm = true
            }
        }
    }

    /// Consistent secondary control button — icon + label + haptic. Adding
    /// the label under each icon eliminates the ambiguity between
    /// forward.fill (Skip Interval) and forward.end.fill (Skip Song).
    private func controlButton(
        systemImage: String,
        label: String,
        tint: Color,
        bg: Color = Color.white.opacity(0.15),
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 4) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundColor(tint)
                    .frame(width: 44, height: 44)
                    .background(bg)
                    .clipShape(Circle())
            }
            .accessibilityLabel(accessibilityLabel)
            .sensoryFeedback(.impact(weight: .light), trigger: label)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(1)
        }
    }
}

// MARK: - Jamendo Mini Art

/// Tiny album-art tile shown in place of the YouTube video frame when Jamendo
/// is the active music source. AsyncImage handles Jamendo's album art URLs;
/// falls back to a music-note icon when the track has no image or hasn't
/// loaded yet.
struct JamendoMiniArt: View {
    let track: JamendoMusicSource.JamendoTrack?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.orange.opacity(0.4), .red.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let url = track?.albumImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: "music.note")
            .font(.title3)
            .foregroundColor(.white.opacity(0.8))
    }
}
