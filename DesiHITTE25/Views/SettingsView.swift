import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var voiceCoach: VoiceCoach
    @Bindable var userProfile: UserProfile

    var body: some View {
        NavigationStack {
            Form {
                // Heart Rate Settings
                Section("Heart Rate") {
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("Age", value: $userProfile.age, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    HStack {
                        Text("Calculated Max HR")
                        Spacer()
                        Text("\(220 - userProfile.age) BPM")
                            .foregroundColor(.secondary)
                    }

                    Toggle("Custom Max HR", isOn: Binding(
                        get: { userProfile.customMaxHR != nil },
                        set: { enabled in
                            if enabled {
                                userProfile.customMaxHR = 220 - userProfile.age
                            } else {
                                userProfile.customMaxHR = nil
                            }
                        }
                    ))

                    if let customMax = userProfile.customMaxHR {
                        HStack {
                            Text("Max HR")
                            Spacer()
                            TextField("Max HR", value: Binding(
                                get: { customMax },
                                set: { userProfile.customMaxHR = $0 }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            Text("BPM")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Zone Preview
                Section("Your Heart Rate Zones") {
                    ForEach(WorkoutZone.allCases, id: \.self) { zone in
                        HStack {
                            Circle()
                                .fill(zone.color)
                                .frame(width: 14, height: 14)
                            Text(zone.name)
                                .fontWeight(.medium)
                            Spacer()
                            let range = zone.hrRange(maxHR: userProfile.maxHR)
                            Text("\(range.lowerBound)-\(range.upperBound) BPM")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Coach Settings
                Section("Voice Coach") {
                    Toggle("Mute Coach", isOn: $voiceCoach.isMuted)

                    VStack(alignment: .leading) {
                        Text("Coach Volume: \(Int(voiceCoach.coachVolume * 100))%")
                        Slider(value: $voiceCoach.coachVolume, in: 0...1, step: 0.1)
                    }

                    VStack(alignment: .leading) {
                        Text("Motivation Frequency: \(Int(userProfile.motivationFrequency))s")
                        Slider(value: $userProfile.motivationFrequency, in: 15...90, step: 5)
                    }

                    Button("Test Coach Voice") {
                        voiceCoach.announce("Chalo! Testing voice coach. Bahut acche!")
                    }
                }

                // Bluetooth Device
                Section("Bluetooth Device") {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(bluetoothManager.isConnected ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(bluetoothManager.connectionStatus)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink("Manage Device") {
                        DevicePairingView(bluetoothManager: bluetoothManager)
                    }

                    if bluetoothManager.isConnected {
                        Button("Disconnect", role: .destructive) {
                            bluetoothManager.disconnect()
                        }
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("App")
                        Spacer()
                        Text("DesiHITTE25")
                            .foregroundColor(.secondary)
                    }

                    Link("Report an Issue", destination: URL(string: "https://github.com/kirankaja/DesiHITTE25/issues")!)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
