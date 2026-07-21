import Foundation

// MARK: - Music Source Kind

/// Which backend supplies music for a workout. `.jamendo` streams CC-licensed
/// MP3s directly (ad-free, no key needed). `.youtube` uses the existing IFrame
/// player over a curated Bollywood/Pop library (region- and embed-restricted).
enum MusicSourceKind: String, Codable, CaseIterable, Identifiable {
    case jamendo
    case youtube

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .jamendo: return "Jamendo (Ad-Free)"
        case .youtube: return "YouTube (Bollywood / Pop)"
        }
    }

    var subtitle: String {
        switch self {
        case .jamendo:
            return "Streams royalty-free workout tracks (electronic / pop / chill) matched to interval intensity. No ads, no account, no region blocks. Genre picker below has no effect in this mode."
        case .youtube:
            return "Plays the curated Bollywood or Pop library via YouTube. Some songs may be blocked from playback by their labels; the app auto-skips them but coverage can be spotty."
        }
    }
}

// MARK: - Music Controller Protocol

/// The interface WorkoutEngine talks to. Both `YouTubePlayerManager` and
/// `JamendoMusicSource` conform, and `MusicRouter` forwards calls to whichever
/// backend the user selected in Settings.
protocol MusicController: AnyObject {
    var currentGenre: MusicGenre { get }

    /// Pre-select one track per workout interval so the whole session's music
    /// ramps with the intensity plan. Call once at `startWorkout`.
    func planSession(categories: [PlaylistCategory], genre: MusicGenre)

    /// Play the pre-selected track for a given interval index. Falls back to a
    /// same-category swap if there's no plan (e.g. mid-workout genre change).
    func playPlannedTrack(at intervalIndex: Int, fallbackCategory: PlaylistCategory)

    /// Jump to a different track whose BPM is close to what's currently
    /// playing (user's manual skip button).
    func skipToSimilarBPM()

    func play()
    func pause()

    /// Drop the per-interval plan and stop playback (called on workout end).
    func clearSessionPlan()

    func setGenre(_ genre: MusicGenre)
}
