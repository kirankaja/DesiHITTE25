import Foundation
import Combine

/// STUB. Represents the future "live 1-Hz heart rate from a paired
/// DesiHITTE25 Watch app". Requires a watchOS target running `HKWorkoutSession`
/// and streaming samples over `WatchConnectivity` — neither exists yet.
///
/// We ship this stub so the source-picker infrastructure is complete and the
/// user sees the option (grayed out via `HeartRateSourceKind.isAvailable`),
/// so nothing else has to change when the Watch target lands.
final class WatchHRSource: NSObject, ObservableObject, HeartRateSource {
    let kind: HeartRateSourceKind = .appleWatchLive

    @Published private(set) var currentHeartRate: Int = 0
    @Published private(set) var statusDescription: String = "Watch companion app not installed"
    @Published private(set) var isReceivingData: Bool = false

    var heartRatePublisher: AnyPublisher<Int, Never> {
        $currentHeartRate.eraseToAnyPublisher()
    }

    func activate() {
        // TODO: activate WCSession, wait for a paired reachable watch, subscribe
        // to `didReceiveMessage` with HR payloads. For now this is a no-op.
        statusDescription = "Watch companion app not installed"
    }

    func deactivate() {
        // TODO: deactivate WCSession messaging.
    }
}
