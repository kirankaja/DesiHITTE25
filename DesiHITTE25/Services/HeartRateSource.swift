import Foundation
import Combine

/// User-selectable heart-rate provider kinds. The raw value is what we persist
/// on `UserProfile.preferredHRSourceRaw`, so keep these strings stable.
enum HeartRateSourceKind: String, CaseIterable, Identifiable {
    case bluetoothFTMS        // Sole E25 / any BLE HRM
    case healthKit            // Passive: HR samples the Watch writes to Health
    case appleWatchLive       // Future: watchOS companion streaming 1Hz HR

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bluetoothFTMS:    return "Bluetooth (Sole E25 / HRM)"
        case .healthKit:        return "Apple Watch (via Health)"
        case .appleWatchLive:   return "Apple Watch (live) — coming soon"
        }
    }

    var subtitle: String {
        switch self {
        case .bluetoothFTMS:    return "Real-time from the elliptical or a chest strap. Most accurate for splat scoring."
        case .healthKit:        return "Reads HR samples Apple Watch writes to Health. Updated every 5-10s — laggy for zone changes."
        case .appleWatchLive:   return "Requires the DesiHITTE25 Watch app (not yet built)."
        }
    }

    var isAvailable: Bool {
        switch self {
        case .bluetoothFTMS:    return true
        case .healthKit:        return true
        case .appleWatchLive:   return false   // enable once WatchHRSource is real
        }
    }
}

/// Common contract every HR provider must satisfy so `WorkoutEngine` can
/// bind to whichever one the user picked without knowing the details.
///
/// All implementations MUST publish updates on the main thread — WorkoutEngine
/// subscribes without further scheduling.
protocol HeartRateSource: AnyObject {
    var kind: HeartRateSourceKind { get }

    /// Latest heart rate in BPM. 0 means "no reading yet / disconnected".
    var currentHeartRate: Int { get }

    /// A human-readable status ("Connected to Sole E25", "Waiting for Watch", …).
    var statusDescription: String { get }

    /// True when the source is actively producing recent HR samples.
    var isReceivingData: Bool { get }

    /// Combine publisher of HR updates. Emits every new reading; may repeat values.
    var heartRatePublisher: AnyPublisher<Int, Never> { get }

    /// Called by the router when this source becomes the active one. Providers
    /// should start any queries / permission requests here.
    func activate()

    /// Called by the router when a different source is chosen. Stop queries,
    /// release resources, but don't destroy long-lived connections the user
    /// might want back (e.g. BLE pairing).
    func deactivate()
}
