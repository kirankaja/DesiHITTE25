import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var profiles: [UserProfile]

    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var voiceCoach: VoiceCoach
    @ObservedObject var musicRouter: MusicRouter
    @ObservedObject var hrRouter: HeartRateRouter

    @State private var selectedTab = 0

    var body: some View {
        Group {
            // Ensure a persistent UserProfile exists before rendering tabs.
            // Passing a transient `UserProfile()` into @Bindable views produces
            // silently-dropped edits, so we guarantee the SwiftData-managed
            // instance is present first.
            if let profile = profiles.first {
                TabView(selection: $selectedTab) {
                    WorkoutTabView(
                        bluetoothManager: bluetoothManager,
                        voiceCoach: voiceCoach,
                        musicRouter: musicRouter,
                        hrRouter: hrRouter,
                        userProfile: profile
                    )
                    .tabItem {
                        Label("Workout", systemImage: "flame.fill")
                    }
                    .tag(0)

                    HistoryView(sessions: sessions)
                        .tabItem {
                            Label("History", systemImage: "clock.fill")
                        }
                        .tag(1)

                    SettingsView(
                        bluetoothManager: bluetoothManager,
                        voiceCoach: voiceCoach,
                        hrRouter: hrRouter,
                        musicRouter: musicRouter,
                        userProfile: profile
                    )
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(2)
                }
                .tint(.orange)
                .onAppear {
                    // Sync router with the persisted user preference the first
                    // time this view appears, and activate the current source.
                    hrRouter.select(profile.preferredHRSource)
                    hrRouter.activateCurrent()
                    musicRouter.setGenre(profile.preferredMusicGenre)
                    musicRouter.setActiveSource(profile.musicSource)
                }
                .onChange(of: profile.preferredHRSourceRaw) { _, newRaw in
                    if let kind = HeartRateSourceKind(rawValue: newRaw) {
                        hrRouter.select(kind)
                    }
                }
                .onChange(of: profile.preferredMusicGenreRaw) { _, newRaw in
                    if let genre = MusicGenre(rawValue: newRaw) {
                        musicRouter.setGenre(genre)
                    }
                }
                .onChange(of: profile.musicSourceRaw) { _, newRaw in
                    if let kind = MusicSourceKind(rawValue: newRaw ?? "") {
                        musicRouter.setActiveSource(kind)
                    }
                }
            } else {
                ProgressView()
                    .onAppear {
                        modelContext.insert(UserProfile())
                        try? modelContext.save()
                    }
            }
        }
    }
}

// MARK: - Workout Tab

struct WorkoutTabView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var voiceCoach: VoiceCoach
    @ObservedObject var musicRouter: MusicRouter
    @ObservedObject var hrRouter: HeartRateRouter
    var userProfile: UserProfile

    @State private var selectedTemplate: WorkoutTemplate?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    connectionStatus
                    templateCards
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("DesiHITTE25")
            .fullScreenCover(item: $selectedTemplate) { template in
                WorkoutView(
                    template: template,
                    bluetoothManager: bluetoothManager,
                    voiceCoach: voiceCoach,
                    musicRouter: musicRouter,
                    hrRouter: hrRouter,
                    maxHR: userProfile.maxHR,
                    motivationFrequency: userProfile.motivationFrequency
                )
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("🇮🇳 Desi HIIT 🔥")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("OTF-Style Workouts • Bollywood Beats")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 10)
    }

    private var connectionStatus: some View {
        HStack {
            Circle()
                .fill(bluetoothManager.isConnected ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            Text(bluetoothManager.connectionStatus)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if !bluetoothManager.isConnected {
                NavigationLink("Pair Device") {
                    DevicePairingView(bluetoothManager: bluetoothManager)
                }
                .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    private var templateCards: some View {
        VStack(spacing: 16) {
            Text("Choose Your Workout")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(WorkoutTemplate.allTemplates) { template in
                TemplateCard(template: template) {
                    selectedTemplate = template
                }
            }
        }
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: WorkoutTemplate
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(template.name)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text(template.formattedTotalDuration)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }

            Text(template.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack(spacing: 4) {
                ForEach(template.intervals.prefix(12)) { interval in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(interval.targetZone.color)
                        .frame(height: 8)
                }
            }

            Button(action: onStart) {
                Text("Start Workout")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - History View

struct HistoryView: View {
    let sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "flame")
                            .font(.system(size: 60))
                            .foregroundColor(.orange.opacity(0.3))
                        Text("No workouts yet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Complete your first workout to see it here!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(sessions) { session in
                        NavigationLink {
                            WorkoutSummaryView(session: session)
                        } label: {
                            SessionRow(session: session)
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.templateName)
                    .font(.headline)
                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                VStack {
                    Text("\(session.splatPoints)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Splats")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text(session.formattedDuration)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Duration")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
