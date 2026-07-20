import Foundation
import Combine

/// BluetoothManager already publishes `heartRate` as an `Int`. This extension
/// adopts the `HeartRateSource` contract without touching the (larger) main
/// file, so BLE code stays focused on CoreBluetooth concerns.
extension BluetoothManager: HeartRateSource {
    var kind: HeartRateSourceKind { .bluetoothFTMS }

    var currentHeartRate: Int { heartRate }

    var statusDescription: String { connectionStatus }

    var isReceivingData: Bool { isConnected && heartRate > 0 }

    var heartRatePublisher: AnyPublisher<Int, Never> {
        $heartRate.eraseToAnyPublisher()
    }

    func activate() {
        // BluetoothManager is long-lived and already auto-starts scanning
        // in the simulator / waits for user to pair on device. Nothing extra
        // to do on activation today.
    }

    func deactivate() {
        // We deliberately do NOT tear down the CBCentralManager or drop the
        // paired peripheral just because the user picked a different HR
        // source — they may switch back, and re-scanning the room is slow.
        // If the user wants to release BLE they can hit Disconnect in
        // Settings.
    }
}
