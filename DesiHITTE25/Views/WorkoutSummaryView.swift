import SwiftUI

struct WorkoutSummaryView: View {
    let session: WorkoutSession
    var onDismiss: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("🔥 Workout Complete! 🔥")
                            .font(.title)
                            .fontWeight(.black)

                        Text(session.templateName)
                            .font(.title3)
                            .foregroundColor(.secondary)

                        Text(session.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Splat Points - Hero
                    splatHero

                    // Stats Grid
                    statsGrid

                    // Zone Breakdown
                    zoneBreakdown

                    // Share Button
                    ShareLink(
                        item: summaryText,
                        subject: Text("DesiHITTE25 Workout"),
                        message: Text("Check out my workout!")
                    ) {
                        Label("Share Results", systemImage: "square.and.arrow.up")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if onDismiss != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            onDismiss?()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Splat Hero

    private var splatHero: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange, .red.opacity(0.6), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                    Text("\(session.splatPoints)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Splat Points")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }

            Text(splatMessage)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var splatMessage: String {
        switch session.splatPoints {
        case 0..<8: return "Aaram se start kiya! You'll get more next time! 💪"
        case 8..<12: return "Accha effort! Getting into the zone! 🔥"
        case 12..<20: return "Bahut acche! Great workout today! 🌟"
        case 20..<30: return "Shandar! Outstanding performance! 🏆"
        default: return "CHAMPION! Legendary workout! 👑🔥"
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                icon: "timer",
                title: "Duration",
                value: session.formattedDuration,
                color: .blue
            )
            StatCard(
                icon: "bolt.heart.fill",
                title: "Calories",
                value: "\(session.caloriesBurned)",
                color: .green
            )
            StatCard(
                icon: "heart.fill",
                title: "Avg HR",
                value: "\(session.averageHeartRate) BPM",
                color: .pink
            )
            StatCard(
                icon: "heart.fill",
                title: "Max HR",
                value: "\(session.maxHeartRate) BPM",
                color: .red
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Zone Breakdown

    private var zoneBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zone Breakdown")
                .font(.headline)

            ForEach(WorkoutZone.allCases, id: \.self) { zone in
                let timeInZone = session.timeInZone(zone)
                let percentage = session.zonePercentage(zone)

                HStack(spacing: 12) {
                    Circle()
                        .fill(zone.color)
                        .frame(width: 12, height: 12)

                    Text(zone.name)
                        .font(.subheadline)
                        .frame(width: 55, alignment: .leading)

                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(zone.color)
                            .frame(width: max(4, geometry.size.width * percentage / 100))
                    }
                    .frame(height: 16)

                    Text(formatTime(timeInZone))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var summaryText: String {
        """
        🔥 DesiHITTE25 Workout Complete!
        📋 \(session.templateName)
        ⏱ Duration: \(session.formattedDuration)
        🔥 Splat Points: \(session.splatPoints)
        ❤️ Avg HR: \(session.averageHeartRate) BPM | Max: \(session.maxHeartRate) BPM
        🔥 Calories: \(session.caloriesBurned)
        #DesiHITTE25 #BollywoodHIIT
        """
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
