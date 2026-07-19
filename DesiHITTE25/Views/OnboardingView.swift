import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var currentPage = 0
    @State private var age: String = "30"
    @State private var fitnessLevel: String = "intermediate"

    @ObservedObject var bluetoothManager: BluetoothManager

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "16213E"), Color(hex: "0F3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                profilePage.tag(1)
                zoneTutorialPage.tag(2)
                devicePage.tag(3)
                readyPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🇮🇳")
                .font(.system(size: 80))

            Text("DesiHITTE25")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                )

            Text("OTF-Style HIIT Workouts\nwith Bollywood Beats 🎵")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))

            VStack(spacing: 12) {
                FeatureRow(icon: "heart.fill", color: .red, text: "Heart rate zone training")
                FeatureRow(icon: "flame.fill", color: .orange, text: "Earn Splat Points")
                FeatureRow(icon: "music.note", color: .purple, text: "Bollywood music integration")
                FeatureRow(icon: "speaker.wave.2.fill", color: .green, text: "Hindi + English voice coach")
                FeatureRow(icon: "antenna.radiowaves.left.and.right", color: .blue, text: "Sole E25 Bluetooth sync")
            }
            .padding(.top, 20)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Let's Get Started! Chalo! 🚀")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .padding()
    }

    // MARK: - Profile Page

    private var profilePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.fill.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("About You")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Age")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                        .font(.title2)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Fitness Level")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))

                    Picker("Fitness Level", selection: $fitnessLevel) {
                        Text("Beginner").tag("beginner")
                        Text("Intermediate").tag("intermediate")
                        Text("Advanced").tag("advanced")
                    }
                    .pickerStyle(.segmented)
                }

                if let ageInt = Int(age) {
                    let maxHR = 220 - ageInt
                    VStack(spacing: 4) {
                        Text("Your Max Heart Rate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(maxHR) BPM")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)

            Spacer()

            Button {
                withAnimation { currentPage = 2 }
            } label: {
                Text("Next →")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .padding()
    }

    // MARK: - Zone Tutorial

    private var zoneTutorialPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Heart Rate Zones")
                .font(.title)
                .fontWeight(.bold)

            Text("Like OTF, we use 5 zones. Earn Splat Points\nin Orange and Red zones!")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))

            VStack(spacing: 10) {
                ForEach(WorkoutZone.allCases, id: \.self) { zone in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(zone.color)
                            .frame(width: 40, height: 36)
                            .overlay(
                                Text(zone.splatEligible ? "🔥" : "")
                                    .font(.caption)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(zone.name)
                                .font(.headline)
                                .foregroundColor(zone.color)
                            Text(zone.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("\(Int(zone.hrRangePercent.lowerBound))-\(Int(zone.hrRangePercent.upperBound))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(zone.color.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)

            Spacer()

            Button {
                withAnimation { currentPage = 3 }
            } label: {
                Text("Next →")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .padding()
    }

    // MARK: - Device Page

    private var devicePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Connect Your Device")
                .font(.title)
                .fontWeight(.bold)

            Text("Pair your Sole E25 elliptical or\nheart rate monitor via Bluetooth")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))

            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(bluetoothManager.isConnected ? .green : .yellow)
                        .frame(width: 10, height: 10)
                    Text(bluetoothManager.connectionStatus)
                        .foregroundColor(.secondary)
                }

                Button {
                    bluetoothManager.startScanning()
                } label: {
                    Label("Scan for Devices", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(12)
                }

                if !bluetoothManager.discoveredDevices.isEmpty {
                    ForEach(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                        Button {
                            bluetoothManager.connect(peripheral: device)
                        } label: {
                            HStack {
                                Image(systemName: "wave.3.right")
                                Text(device.name ?? "Unknown Device")
                                Spacer()
                                Text("Connect")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    withAnimation { currentPage = 4 }
                } label: {
                    Text("Next →")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }

                Button {
                    withAnimation { currentPage = 4 }
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .padding()
    }

    // MARK: - Ready Page

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🔥")
                .font(.system(size: 80))

            Text("You're Ready!")
                .font(.title)
                .fontWeight(.black)

            Text("Tayyar ho? Let's crush it!")
                .font(.title3)
                .foregroundColor(.orange)

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                Text("Start My First Workout! 💪")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .padding()
    }

    // MARK: - Helpers

    private func completeOnboarding() {
        let profile: UserProfile
        if let existing = profiles.first {
            profile = existing
        } else {
            profile = UserProfile()
            modelContext.insert(profile)
        }

        if let ageInt = Int(age) {
            profile.age = ageInt
        }
        profile.hasCompletedOnboarding = true

        onComplete()
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}
