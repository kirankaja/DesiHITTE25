import SwiftUI
import CoreBluetooth

struct DevicePairingView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Connection Status
            Section("Connection Status") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bluetoothManager.connectionStatus)
                            .font(.headline)
                        Text(bluetoothManager.isConnected
                             ? "Device is connected and streaming data"
                             : "No device connected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Circle()
                        .fill(statusColor)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(statusColor.opacity(0.3), lineWidth: 4)
                        )
                }
            }

            // Live Data (when connected)
            if bluetoothManager.isConnected {
                Section("Live Data") {
                    DataRow(label: "Heart Rate", value: "\(bluetoothManager.heartRate) BPM", icon: "heart.fill", color: .red)
                    DataRow(label: "Speed", value: String(format: "%.1f km/h", bluetoothManager.speed), icon: "speedometer", color: .blue)
                    DataRow(label: "Cadence", value: "\(bluetoothManager.cadence) RPM", icon: "arrow.triangle.2.circlepath", color: .green)
                    DataRow(label: "Resistance", value: "\(bluetoothManager.resistance)", icon: "dial.medium.fill", color: .orange)
                    DataRow(label: "Power", value: "\(bluetoothManager.power) W", icon: "bolt.fill", color: .yellow)
                }
            }

            // Discovered Devices
            Section {
                if bluetoothManager.discoveredDevices.isEmpty {
                    if bluetoothManager.isScanning {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Scanning for devices...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("No devices found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Make sure your Sole E25 is powered on\nand Bluetooth is enabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else {
                    ForEach(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                        DeviceRow(
                            device: device,
                            isConnected: bluetoothManager.isConnected,
                            onConnect: {
                                bluetoothManager.connect(peripheral: device)
                            }
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Available Devices")
                    Spacer()
                    if bluetoothManager.isScanning {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }

            // Actions
            Section {
                Button {
                    bluetoothManager.startScanning()
                } label: {
                    Label("Scan for Devices", systemImage: "magnifyingglass")
                }
                .disabled(bluetoothManager.isScanning)

                if bluetoothManager.isConnected {
                    Button(role: .destructive) {
                        bluetoothManager.disconnect()
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                }
            }

            // Info
            Section("Supported Devices") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This app connects to devices using the FTMS (Fitness Machine Service) Bluetooth protocol.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Sole E25 Elliptical")
                            .font(.caption)
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Bluetooth Heart Rate Monitors")
                            .font(.caption)
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("FTMS-compatible equipment")
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Device Pairing")
        .onAppear {
            if !bluetoothManager.isConnected {
                bluetoothManager.startScanning()
            }
        }
    }

    private var statusColor: Color {
        if bluetoothManager.isConnected {
            return .green
        } else if bluetoothManager.isScanning {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: CBPeripheral
    let isConnected: Bool
    let onConnect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "wave.3.right")
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name ?? "Unknown Device")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(device.identifier.uuidString.prefix(8).uppercased())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isConnected {
                Button("Connect") {
                    onConnect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Row

struct DataRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}
