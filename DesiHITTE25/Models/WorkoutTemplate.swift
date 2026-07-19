import Foundation

struct WorkoutInterval: Identifiable, Codable {
    let id: UUID
    let name: String
    let duration: TimeInterval
    let targetZone: WorkoutZone
    let resistanceRange: ClosedRange<Int>

    init(name: String, duration: TimeInterval, targetZone: WorkoutZone, resistanceRange: ClosedRange<Int>) {
        self.id = UUID()
        self.name = name
        self.duration = duration
        self.targetZone = targetZone
        self.resistanceRange = resistanceRange
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if seconds == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

struct WorkoutTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let totalDuration: TimeInterval
    let intervals: [WorkoutInterval]

    init(name: String, description: String, intervals: [WorkoutInterval]) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.intervals = intervals
        self.totalDuration = intervals.reduce(0) { $0 + $1.duration }
    }

    var formattedTotalDuration: String {
        let minutes = Int(totalDuration) / 60
        return "\(minutes) min"
    }

    static let endurance = WorkoutTemplate(
        name: "Endurance 🏃‍♂️",
        description: "Long green/orange pushes with short recoveries. Build your aerobic base.",
        intervals: [
            WorkoutInterval(name: "Warm Up", duration: 300, targetZone: .blue, resistanceRange: 1...3),
            WorkoutInterval(name: "Base Pace", duration: 180, targetZone: .green, resistanceRange: 4...6),
            WorkoutInterval(name: "Push", duration: 180, targetZone: .orange, resistanceRange: 6...8),
            WorkoutInterval(name: "Base Pace", duration: 120, targetZone: .green, resistanceRange: 4...6),
            WorkoutInterval(name: "Push", duration: 240, targetZone: .orange, resistanceRange: 6...8),
            WorkoutInterval(name: "Recovery", duration: 90, targetZone: .blue, resistanceRange: 2...4),
            WorkoutInterval(name: "Push", duration: 180, targetZone: .orange, resistanceRange: 7...9),
            WorkoutInterval(name: "Base Pace", duration: 120, targetZone: .green, resistanceRange: 4...6),
            WorkoutInterval(name: "Long Push", duration: 300, targetZone: .orange, resistanceRange: 6...8),
            WorkoutInterval(name: "Recovery", duration: 90, targetZone: .blue, resistanceRange: 2...4),
            WorkoutInterval(name: "Push", duration: 180, targetZone: .orange, resistanceRange: 7...9),
            WorkoutInterval(name: "Cool Down", duration: 300, targetZone: .grey, resistanceRange: 1...2),
        ]
    )

    static let power = WorkoutTemplate(
        name: "Power ⚡",
        description: "Short all-out bursts with recovery periods. Build explosive power.",
        intervals: [
            WorkoutInterval(name: "Warm Up", duration: 300, targetZone: .blue, resistanceRange: 1...3),
            WorkoutInterval(name: "Base Pace", duration: 120, targetZone: .green, resistanceRange: 4...6),
            WorkoutInterval(name: "All Out!", duration: 30, targetZone: .red, resistanceRange: 10...12),
            WorkoutInterval(name: "Recovery", duration: 90, targetZone: .blue, resistanceRange: 2...3),
            WorkoutInterval(name: "All Out!", duration: 30, targetZone: .red, resistanceRange: 10...12),
            WorkoutInterval(name: "Recovery", duration: 90, targetZone: .blue, resistanceRange: 2...3),
            WorkoutInterval(name: "All Out!", duration: 45, targetZone: .red, resistanceRange: 10...12),
            WorkoutInterval(name: "Recovery", duration: 90, targetZone: .blue, resistanceRange: 2...3),
            WorkoutInterval(name: "Push", duration: 120, targetZone: .orange, resistanceRange: 7...9),
            WorkoutInterval(name: "All Out!", duration: 30, targetZone: .red, resistanceRange: 11...13),
            WorkoutInterval(name: "Recovery", duration: 90, targetZone: .blue, resistanceRange: 2...3),
            WorkoutInterval(name: "All Out!", duration: 45, targetZone: .red, resistanceRange: 11...13),
            WorkoutInterval(name: "Recovery", duration: 90, targetZone: .blue, resistanceRange: 2...3),
            WorkoutInterval(name: "All Out!", duration: 60, targetZone: .red, resistanceRange: 10...12),
            WorkoutInterval(name: "Cool Down", duration: 300, targetZone: .grey, resistanceRange: 1...2),
        ]
    )

    static let esp = WorkoutTemplate(
        name: "ESP 🔥",
        description: "Endurance, Strength, Power — the ultimate mix of all three.",
        intervals: [
            WorkoutInterval(name: "Warm Up", duration: 300, targetZone: .blue, resistanceRange: 1...3),
            // Endurance block
            WorkoutInterval(name: "Base Pace", duration: 150, targetZone: .green, resistanceRange: 4...6),
            WorkoutInterval(name: "Push", duration: 180, targetZone: .orange, resistanceRange: 6...8),
            WorkoutInterval(name: "Base Pace", duration: 120, targetZone: .green, resistanceRange: 4...6),
            WorkoutInterval(name: "Push", duration: 120, targetZone: .orange, resistanceRange: 7...9),
            // Strength block
            WorkoutInterval(name: "Recovery", duration: 60, targetZone: .blue, resistanceRange: 2...3),
            WorkoutInterval(name: "Strength Push", duration: 120, targetZone: .orange, resistanceRange: 8...10),
            WorkoutInterval(name: "Base Pace", duration: 90, targetZone: .green, resistanceRange: 5...7),
            WorkoutInterval(name: "Strength Push", duration: 120, targetZone: .orange, resistanceRange: 9...11),
            // Power block
            WorkoutInterval(name: "Recovery", duration: 60, targetZone: .blue, resistanceRange: 2...3),
            WorkoutInterval(name: "All Out!", duration: 30, targetZone: .red, resistanceRange: 10...12),
            WorkoutInterval(name: "Recovery", duration: 60, targetZone: .blue, resistanceRange: 2...3),
            WorkoutInterval(name: "All Out!", duration: 30, targetZone: .red, resistanceRange: 11...13),
            WorkoutInterval(name: "Recovery", duration: 60, targetZone: .blue, resistanceRange: 2...3),
            WorkoutInterval(name: "All Out!", duration: 45, targetZone: .red, resistanceRange: 10...12),
            WorkoutInterval(name: "Cool Down", duration: 300, targetZone: .grey, resistanceRange: 1...2),
        ]
    )

    static let allTemplates: [WorkoutTemplate] = [endurance, power, esp]
}
