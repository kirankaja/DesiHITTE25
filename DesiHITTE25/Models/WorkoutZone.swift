import SwiftUI

enum WorkoutZone: Int, CaseIterable, Codable {
    case grey = 0
    case blue = 1
    case green = 2
    case orange = 3
    case red = 4

    var name: String {
        switch self {
        case .grey: return "Grey"
        case .blue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .red: return "Red"
        }
    }

    var color: Color {
        switch self {
        case .grey: return Color(hex: "96969C")
        case .blue: return Color(hex: "0072CE")
        case .green: return Color(hex: "00A651")
        case .orange: return Color(hex: "F7941D")
        case .red: return Color(hex: "ED1C24")
        }
    }

    var hrRangePercent: ClosedRange<Double> {
        switch self {
        case .grey: return 0...60
        case .blue: return 61...70
        case .green: return 71...83
        case .orange: return 84...91
        case .red: return 92...100
        }
    }

    var description: String {
        switch self {
        case .grey: return "Rest / Very Light"
        case .blue: return "Warm Up / Recovery"
        case .green: return "Base Pace / Moderate"
        case .orange: return "Push Pace / Hard"
        case .red: return "All Out / Max Effort"
        }
    }

    var splatEligible: Bool {
        self == .orange || self == .red
    }

    static func zone(forHeartRate hr: Int, maxHR: Int) -> WorkoutZone {
        guard maxHR > 0 else { return .grey }
        let percent = Double(hr) / Double(maxHR) * 100.0
        for zone in WorkoutZone.allCases.reversed() {
            if percent >= zone.hrRangePercent.lowerBound {
                return zone
            }
        }
        return .grey
    }

    func hrRange(maxHR: Int) -> ClosedRange<Int> {
        let lower = Int(hrRangePercent.lowerBound / 100.0 * Double(maxHR))
        let upper = Int(hrRangePercent.upperBound / 100.0 * Double(maxHR))
        return lower...upper
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
