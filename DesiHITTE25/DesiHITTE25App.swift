import SwiftUI
import SwiftData

@main
struct DesiHITTE25App: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Shared long-lived services. Hoisted here so state (paired BLE device,
    // voice-coach settings, YouTube player) survives the onboarding→main transition.
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var voiceCoach = VoiceCoach()
    @StateObject private var youtubeManager = YouTubePlayerManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            UserProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView(
                    bluetoothManager: bluetoothManager,
                    voiceCoach: voiceCoach,
                    youtubeManager: youtubeManager
                )
            } else {
                OnboardingView(bluetoothManager: bluetoothManager) {
                    withAnimation {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
