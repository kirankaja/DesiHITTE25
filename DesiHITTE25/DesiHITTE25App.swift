import SwiftUI
import SwiftData

@main
struct DesiHITTE25App: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Shared long-lived services. Hoisted here so state (paired BLE device,
    // voice-coach settings, YouTube player) survives the onboarding→main transition.
    @StateObject private var bluetoothManager: BluetoothManager
    @StateObject private var voiceCoach = VoiceCoach()
    @StateObject private var youtubeManager = YouTubePlayerManager()

    // HR router owns every HR source (BLE / HealthKit / Watch stub) and
    // publishes the currently-selected source's readings. WorkoutEngine now
    // subscribes to the router instead of the BluetoothManager directly.
    @StateObject private var hrRouter: HeartRateRouter

    init() {
        let bt = BluetoothManager()
        _bluetoothManager = StateObject(wrappedValue: bt)
        _hrRouter = StateObject(wrappedValue: HeartRateRouter(bluetooth: bt))
    }

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
                    youtubeManager: youtubeManager,
                    hrRouter: hrRouter
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
