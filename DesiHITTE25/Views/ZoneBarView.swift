import SwiftUI

struct ZoneBarView: View {
    let currentZone: WorkoutZone
    let heartRate: Int
    let maxHR: Int

    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 4) {
            // Zone labels
            HStack(spacing: 2) {
                ForEach(WorkoutZone.allCases, id: \.self) { zone in
                    Text(zone.name)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(zone == currentZone ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Zone bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        ForEach(WorkoutZone.allCases, id: \.self) { zone in
                            ZoneSegment(
                                zone: zone,
                                isActive: zone == currentZone,
                                pulseAnimation: pulseAnimation
                            )
                        }
                    }

                    // HR position indicator
                    if heartRate > 0 && maxHR > 0 {
                        let hrPercent = min(1.0, max(0.0, Double(heartRate) / Double(maxHR)))
                        let xPosition = hrPercent * geometry.size.width

                        VStack(spacing: 0) {
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                            Rectangle()
                                .fill(.white)
                                .frame(width: 2, height: 20)
                        }
                        .offset(x: xPosition - 5)
                        .animation(.spring(response: 0.5), value: heartRate)
                    }
                }
            }
            .frame(height: 28)

            // HR range labels
            HStack {
                Text("<\(Int(Double(maxHR) * 0.61))")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(heartRate > 0 ? "\(heartRate) BPM" : "--")")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(currentZone.color)
                Spacer()
                Text("\(maxHR)+")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
}

// MARK: - Zone Segment

struct ZoneSegment: View {
    let zone: WorkoutZone
    let isActive: Bool
    let pulseAnimation: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(zone.color)
            .opacity(isActive ? 1.0 : 0.35)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isActive ? Color.white : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: isActive ? zone.color.opacity(pulseAnimation ? 0.8 : 0.3) : .clear,
                radius: isActive ? (pulseAnimation ? 8 : 3) : 0
            )
            .scaleEffect(isActive ? (pulseAnimation ? 1.05 : 1.0) : 1.0)
            .animation(.easeInOut(duration: 1.0), value: isActive)
    }
}
