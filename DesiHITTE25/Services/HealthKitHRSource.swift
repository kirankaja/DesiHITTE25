import Foundation
import Combine
import HealthKit

/// Reads Apple Watch heart-rate samples via HealthKit. This is the "Option A"
/// integration: it does NOT require a watchOS companion app — the Watch itself
/// writes HR samples to Health continuously (roughly every 5-10s during a
/// Watch-detected workout, less often otherwise). Latency is meaningfully
/// worse than a live BLE stream, which is why the settings picker warns users.
///
/// For real 1-Hz streaming we need `WatchHRSource` + a watchOS target running
/// `HKWorkoutSession`, which is queued as future work.
final class HealthKitHRSource: NSObject, ObservableObject, HeartRateSource {
    let kind: HeartRateSourceKind = .healthKit

    @Published private(set) var currentHeartRate: Int = 0
    @Published private(set) var statusDescription: String = "Not activated"
    @Published private(set) var isReceivingData: Bool = false

    var heartRatePublisher: AnyPublisher<Int, Never> {
        $currentHeartRate.eraseToAnyPublisher()
    }

    private let healthStore = HKHealthStore()
    private var anchorQuery: HKAnchoredObjectQuery?
    private var lastSampleAt: Date?
    private var staleCheckTimer: Timer?

    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    /// Consider the feed "stale" (isReceivingData=false) if we haven't seen a
    /// sample in this long. Health typically delivers samples every 5-30s
    /// during a Watch workout, so 45s is a generous grace window.
    private let staleThreshold: TimeInterval = 45

    override init() {
        super.init()
    }

    func activate() {
        guard HKHealthStore.isHealthDataAvailable() else {
            statusDescription = "HealthKit unavailable on this device"
            return
        }

        statusDescription = "Requesting Health permission…"
        healthStore.requestAuthorization(toShare: nil, read: [heartRateType]) { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.statusDescription = "Health permission error: \(error.localizedDescription)"
                    return
                }
                guard granted else {
                    // HealthKit returns granted=true whether the user allows or denies —
                    // it never leaks the choice. So a false here is only a system error.
                    self.statusDescription = "Health permission not requested"
                    return
                }
                self.startAnchoredQuery()
            }
        }
    }

    func deactivate() {
        if let q = anchorQuery {
            healthStore.stop(q)
        }
        anchorQuery = nil
        staleCheckTimer?.invalidate()
        staleCheckTimer = nil
        isReceivingData = false
        statusDescription = "Not activated"
    }

    // MARK: - Query

    private func startAnchoredQuery() {
        statusDescription = "Waiting for Watch HR samples…"

        // Only samples from the last 10 min to avoid flooding on activation.
        let sinceStart = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-600),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: sinceStart,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            self?.handle(samples: samples, error: error)
        }
        // Long-lived: fires whenever a new HR sample lands in Health.
        query.updateHandler = { [weak self] _, samples, _, _, error in
            self?.handle(samples: samples, error: error)
        }

        healthStore.execute(query)
        anchorQuery = query

        // Kick off a stale-checker so isReceivingData drops if the Watch
        // stops delivering (workout ended, wrist off, etc.).
        staleCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshStaleFlag()
        }
    }

    private func handle(samples: [HKSample]?, error: Error?) {
        DispatchQueue.main.async {
            if let error {
                self.statusDescription = "Health query error: \(error.localizedDescription)"
                self.isReceivingData = false
                return
            }
            guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
                return
            }
            // Sort ascending, take latest — HK doesn't guarantee delivery order.
            let sorted = quantitySamples.sorted { $0.endDate < $1.endDate }
            guard let newest = sorted.last else { return }

            let bpm = Int(newest.quantity.doubleValue(for: self.bpmUnit).rounded())
            self.currentHeartRate = bpm
            self.lastSampleAt = newest.endDate
            self.isReceivingData = true
            self.statusDescription = "Live from Apple Watch (\(bpm) BPM)"
        }
    }

    private func refreshStaleFlag() {
        guard let last = lastSampleAt else { return }
        if Date().timeIntervalSince(last) > staleThreshold {
            isReceivingData = false
            statusDescription = "No recent Watch samples — start a workout on your Watch"
        }
    }
}
