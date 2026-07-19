import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject {
    // MARK: - FTMS UUIDs
    static let ftmsServiceUUID = CBUUID(string: "1826")
    static let heartRateServiceUUID = CBUUID(string: "180D")
    static let heartRateCharUUID = CBUUID(string: "2A37")
    static let ftmsIndoorBikeDataUUID = CBUUID(string: "2AD2")
    static let ftmsCrossTrainerDataUUID = CBUUID(string: "2ACE")
    static let ftmsMachineControlPointUUID = CBUUID(string: "2AD9")
    static let ftmsMachineStatusUUID = CBUUID(string: "2ADA")

    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var heartRate: Int = 0
    @Published var speed: Double = 0.0
    @Published var cadence: Int = 0
    @Published var resistance: Int = 0
    @Published var power: Int = 0
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var isScanning = false
    @Published var connectionStatus: String = "Disconnected"

    // MARK: - Private
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var controlPointCharacteristic: CBCharacteristic?
    private var reconnectPeripheralID: UUID?
    private var reconnectTimer: Timer?

    #if targetEnvironment(simulator)
    private var simulatorTimer: Timer?
    private var simulatedHR: Int = 72
    private var simulatedHRDirection: Int = 1
    #endif

    override init() {
        super.init()
        #if targetEnvironment(simulator)
        startSimulatorMode()
        #else
        centralManager = CBCentralManager(delegate: self, queue: nil)
        #endif
    }

    // MARK: - Public Methods

    func startScanning() {
        #if targetEnvironment(simulator)
        generateMockDevices()
        return
        #else
        guard centralManager.state == .poweredOn else {
            connectionStatus = "Bluetooth not available"
            return
        }
        discoveredDevices.removeAll()
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: [Self.ftmsServiceUUID, Self.heartRateServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.stopScanning()
        }
        #endif
    }

    func stopScanning() {
        #if !targetEnvironment(simulator)
        centralManager.stopScan()
        #endif
        isScanning = false
    }

    func connect(peripheral: CBPeripheral) {
        #if targetEnvironment(simulator)
        isConnected = true
        connectionStatus = "Connected (Simulator)"
        return
        #else
        stopScanning()
        connectionStatus = "Connecting..."
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
        #endif
    }

    func disconnect() {
        #if targetEnvironment(simulator)
        isConnected = false
        connectionStatus = "Disconnected"
        heartRate = 0
        speed = 0
        cadence = 0
        resistance = 0
        return
        #else
        reconnectPeripheralID = nil
        reconnectTimer?.invalidate()
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        isConnected = false
        connectionStatus = "Disconnected"
        #endif
    }

    func setResistance(level: Int) {
        let clampedLevel = max(1, min(20, level))
        #if targetEnvironment(simulator)
        resistance = clampedLevel
        return
        #else
        guard let characteristic = controlPointCharacteristic else { return }
        // FTMS Machine Control Point: OpCode 0x04 = Set Target Resistance Level
        // Resistance is in 0.1 units, so level 5 = 50
        var data = Data()
        data.append(0x04) // Set Target Resistance Level opcode
        let resistanceValue = UInt8(clampedLevel * 10)
        data.append(resistanceValue)
        connectedPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
        resistance = clampedLevel
        #endif
    }

    // MARK: - Simulator Support

    #if targetEnvironment(simulator)
    private func startSimulatorMode() {
        isConnected = false
        connectionStatus = "Simulator Mode"
    }

    private func generateMockDevices() {
        isScanning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isScanning = false
        }
    }

    func startSimulatedWorkout() {
        isConnected = true
        connectionStatus = "Connected (Simulator)"
        simulatedHR = 72
        simulatedHRDirection = 1
        simulatorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Simulate HR fluctuations
            let hrChange = Int.random(in: -2...4) * self.simulatedHRDirection
            self.simulatedHR = max(60, min(195, self.simulatedHR + hrChange))
            if self.simulatedHR > 185 { self.simulatedHRDirection = -1 }
            if self.simulatedHR < 75 { self.simulatedHRDirection = 1 }
            self.heartRate = self.simulatedHR
            self.speed = Double.random(in: 2.5...6.5)
            self.cadence = Int.random(in: 60...140)
            self.power = Int.random(in: 50...250)
        }
    }

    func stopSimulatedWorkout() {
        simulatorTimer?.invalidate()
        simulatorTimer = nil
        heartRate = 0
        speed = 0
        cadence = 0
        power = 0
    }

    func simulateHRForZone(_ zone: WorkoutZone, maxHR: Int) {
        let midPercent = (zone.hrRangePercent.lowerBound + zone.hrRangePercent.upperBound) / 2.0
        simulatedHR = Int(midPercent / 100.0 * Double(maxHR))
    }
    #endif

    // MARK: - Auto-reconnect

    private func attemptReconnect() {
        guard let peripheralID = reconnectPeripheralID else { return }
        connectionStatus = "Reconnecting..."
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [peripheralID])
        if let peripheral = peripherals.first {
            connectedPeripheral = peripheral
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
        } else {
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                self?.attemptReconnect()
            }
        }
    }

    // MARK: - Heart Rate Parsing

    private func parseHeartRate(from data: Data) -> Int {
        guard data.count >= 2 else { return 0 }
        let flags = data[0]
        let is16Bit = (flags & 0x01) != 0
        if is16Bit && data.count >= 3 {
            return Int(UInt16(data[1]) | (UInt16(data[2]) << 8))
        } else {
            return Int(data[1])
        }
    }

    // MARK: - Indoor Bike Data Parsing

    private func parseIndoorBikeData(from data: Data) {
        guard data.count >= 2 else { return }
        let flags = UInt16(data[0]) | (UInt16(data[1]) << 8)
        var offset = 2

        // Instantaneous Speed (0.01 km/h resolution) - present if bit 0 is NOT set
        if (flags & 0x0001) == 0 && offset + 2 <= data.count {
            let rawSpeed = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            speed = Double(rawSpeed) / 100.0
            offset += 2
        }

        // Average Speed - present if bit 1 is set
        if (flags & 0x0002) != 0 && offset + 2 <= data.count {
            offset += 2
        }

        // Instantaneous Cadence (0.5 /min resolution) - present if bit 2 is set
        if (flags & 0x0004) != 0 && offset + 2 <= data.count {
            let rawCadence = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            cadence = Int(rawCadence / 2)
            offset += 2
        }

        // Average Cadence - present if bit 3 is set
        if (flags & 0x0008) != 0 && offset + 2 <= data.count {
            offset += 2
        }

        // Total Distance - present if bit 4 is set
        if (flags & 0x0010) != 0 && offset + 3 <= data.count {
            offset += 3
        }

        // Resistance Level - present if bit 5 is set
        if (flags & 0x0020) != 0 && offset + 2 <= data.count {
            let rawResistance = Int16(data[offset]) | (Int16(data[offset + 1]) << 8)
            resistance = Int(rawResistance)
            offset += 2
        }

        // Instantaneous Power - present if bit 6 is set
        if (flags & 0x0040) != 0 && offset + 2 <= data.count {
            let rawPower = Int16(data[offset]) | (Int16(data[offset + 1]) << 8)
            power = Int(rawPower)
            offset += 2
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectionStatus = "Ready to scan"
        case .poweredOff:
            connectionStatus = "Bluetooth is off"
        case .unauthorized:
            connectionStatus = "Bluetooth unauthorized"
        case .unsupported:
            connectionStatus = "Bluetooth not supported"
        default:
            connectionStatus = "Bluetooth unavailable"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectionStatus = "Connected"
        reconnectPeripheralID = peripheral.identifier
        peripheral.discoverServices([
            Self.ftmsServiceUUID,
            Self.heartRateServiceUUID
        ])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Connection failed"
        isConnected = false
        attemptReconnect()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectionStatus = "Disconnected"
        if reconnectPeripheralID != nil {
            attemptReconnect()
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case Self.heartRateCharUUID:
                peripheral.setNotifyValue(true, for: characteristic)
            case Self.ftmsIndoorBikeDataUUID, Self.ftmsCrossTrainerDataUUID:
                peripheral.setNotifyValue(true, for: characteristic)
            case Self.ftmsMachineControlPointUUID:
                controlPointCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case Self.ftmsMachineStatusUUID:
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch characteristic.uuid {
            case Self.heartRateCharUUID:
                self.heartRate = self.parseHeartRate(from: data)
            case Self.ftmsIndoorBikeDataUUID, Self.ftmsCrossTrainerDataUUID:
                self.parseIndoorBikeData(from: data)
            default:
                break
            }
        }
    }
}
