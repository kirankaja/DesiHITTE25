import Foundation
import Combine

/// Central switchboard that owns every available `HeartRateSource` and exposes
/// the currently selected one's readings as its own `@Published heartRate`.
///
/// `WorkoutEngine` subscribes to `$heartRate` on the router (instead of
/// directly on `BluetoothManager` as it used to) so switching sources at
/// runtime is transparent to the engine.
final class HeartRateRouter: ObservableObject {
    @Published private(set) var heartRate: Int = 0
    @Published private(set) var activeKind: HeartRateSourceKind
    @Published private(set) var activeSourceStatus: String = ""
    @Published private(set) var activeSourceIsReceiving: Bool = false

    let bluetooth: BluetoothManager
    let healthKit: HealthKitHRSource
    let watch: WatchHRSource

    private var activeCancellables = Set<AnyCancellable>()

    init(bluetooth: BluetoothManager,
         healthKit: HealthKitHRSource = HealthKitHRSource(),
         watch: WatchHRSource = WatchHRSource(),
         initialKind: HeartRateSourceKind = .bluetoothFTMS) {
        self.bluetooth = bluetooth
        self.healthKit = healthKit
        self.watch = watch
        self.activeKind = initialKind
        // Bind to the initial source WITHOUT calling activate() — the caller
        // (App entry) decides when the app has enough context to prompt for
        // permissions.
        bindToActive()
    }

    // MARK: - Public

    /// Switch which source drives `heartRate`. Deactivates the previous one
    /// and activates the new one. Safe to call from the UI thread.
    func select(_ kind: HeartRateSourceKind) {
        guard kind != activeKind else { return }
        guard kind.isAvailable else { return }
        currentSource.deactivate()
        activeKind = kind
        bindToActive()
        currentSource.activate()
    }

    /// Activate the currently-selected source. Call once at app start after
    /// the router is fully wired.
    func activateCurrent() {
        currentSource.activate()
    }

    // MARK: - Private

    private var currentSource: HeartRateSource {
        source(for: activeKind)
    }

    private func source(for kind: HeartRateSourceKind) -> HeartRateSource {
        switch kind {
        case .bluetoothFTMS:    return bluetooth
        case .healthKit:        return healthKit
        case .appleWatchLive:   return watch
        }
    }

    private func bindToActive() {
        activeCancellables.removeAll()
        let src = currentSource

        src.heartRatePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] hr in self?.heartRate = hr }
            .store(in: &activeCancellables)

        // Mirror status/isReceiving from whichever concrete type it is so the
        // UI can show "Live from Apple Watch (128 BPM)" etc. We bind to the
        // ObservableObject's objectWillChange rather than reaching into
        // Published<...> of specific concrete types — this keeps the protocol
        // simple and side-steps existential-Publisher gymnastics.
        if let bt = src as? BluetoothManager {
            bt.$connectionStatus
                .receive(on: RunLoop.main)
                .sink { [weak self] status in self?.activeSourceStatus = status }
                .store(in: &activeCancellables)
            bt.$isConnected
                .receive(on: RunLoop.main)
                .sink { [weak self] connected in self?.activeSourceIsReceiving = connected }
                .store(in: &activeCancellables)
        } else if let hk = src as? HealthKitHRSource {
            hk.$statusDescription
                .receive(on: RunLoop.main)
                .sink { [weak self] s in self?.activeSourceStatus = s }
                .store(in: &activeCancellables)
            hk.$isReceivingData
                .receive(on: RunLoop.main)
                .sink { [weak self] r in self?.activeSourceIsReceiving = r }
                .store(in: &activeCancellables)
        } else if let w = src as? WatchHRSource {
            w.$statusDescription
                .receive(on: RunLoop.main)
                .sink { [weak self] s in self?.activeSourceStatus = s }
                .store(in: &activeCancellables)
            w.$isReceivingData
                .receive(on: RunLoop.main)
                .sink { [weak self] r in self?.activeSourceIsReceiving = r }
                .store(in: &activeCancellables)
        }

        // Prime the router with whatever the source already knows.
        heartRate = src.currentHeartRate
        activeSourceStatus = src.statusDescription
        activeSourceIsReceiving = src.isReceivingData
    }
}
