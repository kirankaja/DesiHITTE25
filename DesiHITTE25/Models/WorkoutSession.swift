import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var id: UUID
    var templateName: String
    var startDate: Date
    var endDate: Date?
    var totalDuration: TimeInterval
    var splatPoints: Int
    var caloriesBurned: Int
    var averageHeartRate: Int
    var maxHeartRate: Int
    var timeInGrey: TimeInterval
    var timeInBlue: TimeInterval
    var timeInGreen: TimeInterval
    var timeInOrange: TimeInterval
    var timeInRed: TimeInterval

    init(
        templateName: String,
        startDate: Date = Date(),
        endDate: Date? = nil,
        totalDuration: TimeInterval = 0,
        splatPoints: Int = 0,
        caloriesBurned: Int = 0,
        averageHeartRate: Int = 0,
        maxHeartRate: Int = 0,
        timeInGrey: TimeInterval = 0,
        timeInBlue: TimeInterval = 0,
        timeInGreen: TimeInterval = 0,
        timeInOrange: TimeInterval = 0,
        timeInRed: TimeInterval = 0
    ) {
        self.id = UUID()
        self.templateName = templateName
        self.startDate = startDate
        self.endDate = endDate
        self.totalDuration = totalDuration
        self.splatPoints = splatPoints
        self.caloriesBurned = caloriesBurned
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.timeInGrey = timeInGrey
        self.timeInBlue = timeInBlue
        self.timeInGreen = timeInGreen
        self.timeInOrange = timeInOrange
        self.timeInRed = timeInRed
    }

    var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    func timeInZone(_ zone: WorkoutZone) -> TimeInterval {
        switch zone {
        case .grey: return timeInGrey
        case .blue: return timeInBlue
        case .green: return timeInGreen
        case .orange: return timeInOrange
        case .red: return timeInRed
        }
    }

    var totalZoneTime: TimeInterval {
        timeInGrey + timeInBlue + timeInGreen + timeInOrange + timeInRed
    }

    func zonePercentage(_ zone: WorkoutZone) -> Double {
        guard totalZoneTime > 0 else { return 0 }
        return timeInZone(zone) / totalZoneTime * 100
    }
}

@Model
final class UserProfile {
    var id: UUID
    var age: Int
    var customMaxHR: Int?
    var coachMuted: Bool
    var coachVolume: Float
    var motivationFrequency: TimeInterval
    var hasCompletedOnboarding: Bool
    var preferredHRSourceRaw: String
    var preferredMusicGenreRaw: String
    /// Optional so existing on-device profiles (from older builds) can migrate
    /// without a schema break — a nil value is treated as `.jamendo` (default).
    var musicSourceRaw: String?

    init(
        age: Int = 30,
        customMaxHR: Int? = nil,
        coachMuted: Bool = false,
        coachVolume: Float = 0.8,
        motivationFrequency: TimeInterval = 35,
        hasCompletedOnboarding: Bool = false,
        preferredHRSourceRaw: String = HeartRateSourceKind.bluetoothFTMS.rawValue,
        preferredMusicGenreRaw: String = MusicGenre.bollywood.rawValue,
        musicSourceRaw: String? = MusicSourceKind.jamendo.rawValue
    ) {
        self.id = UUID()
        self.age = age
        self.customMaxHR = customMaxHR
        self.coachMuted = coachMuted
        self.coachVolume = coachVolume
        self.motivationFrequency = motivationFrequency
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.preferredHRSourceRaw = preferredHRSourceRaw
        self.preferredMusicGenreRaw = preferredMusicGenreRaw
        self.musicSourceRaw = musicSourceRaw
    }

    var maxHR: Int {
        customMaxHR ?? (220 - age)
    }

    var preferredHRSource: HeartRateSourceKind {
        get { HeartRateSourceKind(rawValue: preferredHRSourceRaw) ?? .bluetoothFTMS }
        set { preferredHRSourceRaw = newValue.rawValue }
    }

    var preferredMusicGenre: MusicGenre {
        get { MusicGenre(rawValue: preferredMusicGenreRaw) ?? .bollywood }
        set { preferredMusicGenreRaw = newValue.rawValue }
    }

    var musicSource: MusicSourceKind {
        get { MusicSourceKind(rawValue: musicSourceRaw ?? "") ?? .jamendo }
        set { musicSourceRaw = newValue.rawValue }
    }
}
