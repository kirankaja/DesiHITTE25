import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var voiceCoach: VoiceCoach
    @ObservedObject var hrRouter: HeartRateRouter
    @ObservedObject var musicRouter: MusicRouter
    @Bindable var userProfile: UserProfile

    @State private var youtubeAPIKeyDraft: String = ""
    @State private var youtubeAPIKeySaved: Bool = false
    @State private var showAPIKeyHelp: Bool = false

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

                // Heart Rate Source
                Section {
                    Picker("Source", selection: $userProfile.preferredHRSourceRaw) {
                        ForEach(HeartRateSourceKind.allCases.filter { $0.isAvailable }, id: \.rawValue) { kind in
                            Text(kind.displayName).tag(kind.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Text(userProfile.preferredHRSource.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Circle()
                            .fill(hrRouter.activeSourceIsReceiving ? .green : .orange)
                            .frame(width: 8, height: 8)
                        Text(hrRouter.activeSourceStatus.isEmpty ? "Idle" : hrRouter.activeSourceStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(hrRouter.heartRate) BPM")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Heart Rate Source")
                } footer: {
                    Text("Choose where DesiHITTE25 reads your heart rate from. Apple Watch (via Health) needs a workout running on the Watch for continuous readings. A dedicated Watch app for live streaming is coming in a future update.")
                }

                // Music Source (which backend supplies playback)
                Section {
                    Picker("Source", selection: Binding(
                        get: { userProfile.musicSource },
                        set: { userProfile.musicSource = $0 }
                    )) {
                        ForEach(MusicSourceKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Text(userProfile.musicSource.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Music Source")
                } footer: {
                    Text("Jamendo streams free, ad-free CC-licensed workout tracks — the safest default. YouTube gives you Bollywood/Pop hits but some tracks may be blocked by labels; the app auto-skips them.")
                }

                // Music Genre
                Section {
                    Picker("Genre", selection: $userProfile.preferredMusicGenreRaw) {
                        ForEach(MusicGenre.allCases) { genre in
                            Text(genre.displayName).tag(genre.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Text(userProfile.preferredMusicGenre.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if userProfile.musicSource == .jamendo {
                        Label("Genre applies to YouTube source only. Jamendo picks tracks by intensity (cool-down / moderate / high-energy) from its royalty-free catalog.", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Music Genre")
                } footer: {
                    Text("Playlists are curated by intensity and matched to each interval's target zone (not your current heart rate) — so the music helps push you toward the target. Songs are tagged with approximate BPM: 60–95 for cool-down, 95–125 for moderate, 125+ for high energy. Switch genre anytime, even mid-workout.")
                }

                // YouTube Data API key — only relevant when YouTube source
                // is selected. Without a key we fall back to the curated
                // (fragile) library; with a key we dynamically search and
                // filter for embeddable Bollywood tracks per session.
                if userProfile.musicSource == .youtube {
                    Section {
                        HStack {
                            SecureField("Paste API key", text: $youtubeAPIKeyDraft)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.footnote, design: .monospaced))
                            if youtubeAPIKeySaved {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }

                        HStack {
                            Button {
                                let trimmed = youtubeAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                APIKeyStore.shared.youtubeAPIKey = trimmed
                                youtubeAPIKeySaved = !trimmed.isEmpty
                            } label: {
                                Label("Save Key", systemImage: "key.fill")
                            }
                            .disabled(youtubeAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Spacer()

                            if APIKeyStore.shared.hasYoutubeAPIKey {
                                Button(role: .destructive) {
                                    APIKeyStore.shared.youtubeAPIKey = nil
                                    youtubeAPIKeyDraft = ""
                                    youtubeAPIKeySaved = false
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }

                        Button {
                            showAPIKeyHelp.toggle()
                        } label: {
                            Label(
                                showAPIKeyHelp ? "Hide setup steps" : "How do I get a key?",
                                systemImage: "questionmark.circle"
                            )
                            .font(.footnote)
                        }

                        if showAPIKeyHelp {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Free — 5 min. No credit card required.")
                                    .font(.caption.weight(.semibold))
                                Text("1. Open console.cloud.google.com")
                                Text("2. New Project → name it \"DesiHITTE25\"")
                                Text("3. APIs & Services → Library → enable \"YouTube Data API v3\"")
                                Text("4. APIs & Services → Credentials → Create Credentials → API key")
                                Text("5. Copy the AIza… key and paste it above")
                                Text("6. (Recommended) Edit key → restrict to YouTube Data API v3")
                                Text("Free quota: 10,000 units/day (~500 workouts).")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: APIKeyStore.shared.hasYoutubeAPIKey ? "sparkles" : "info.circle")
                                .foregroundColor(APIKeyStore.shared.hasYoutubeAPIKey ? .orange : .secondary)
                            Text(APIKeyStore.shared.hasYoutubeAPIKey
                                 ? "Dynamic search active — fresh embeddable tracks each workout."
                                 : "Using curated list. Add a key for dynamically-searched Bollywood.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("YouTube Data API Key")
                    } footer: {
                        Text("Stored in your device's Keychain — never leaves the phone except in requests to googleapis.com. Only used to search for currently-embeddable Bollywood tracks per workout intensity.")
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
            .onAppear {
                if let existing = APIKeyStore.shared.youtubeAPIKey, !existing.isEmpty {
                    youtubeAPIKeyDraft = existing
                    youtubeAPIKeySaved = true
                }
            }
        }
    }
}
