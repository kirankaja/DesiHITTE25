import Foundation

// MARK: - Genre

enum MusicGenre: String, Codable, CaseIterable, Identifiable {
    case bollywood
    case pop

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bollywood: return "Bollywood"
        case .pop:       return "Pop"
        }
    }

    var subtitle: String {
        switch self {
        case .bollywood: return "Hindi film hits — Malhari, Khalibali, Kabira"
        case .pop:       return "Western pop hits — Blinding Lights, Uptown Funk, Perfect"
        }
    }
}

// MARK: - Category (intensity bucket)

enum PlaylistCategory: String, Codable, CaseIterable {
    case highEnergy = "High Energy"
    case moderate   = "Moderate"
    case coolDown   = "Cool Down"

    /// Approximate BPM range songs in this category should target. Used to
    /// document and (optionally) sanity-check curated playlists — the actual
    /// selection of a track within a category is done by the YouTube player
    /// cycling the list.
    var bpmRange: ClosedRange<Int> {
        switch self {
        case .highEnergy: return 125...175
        case .moderate:   return 95...125
        case .coolDown:   return 60...95
        }
    }
}

// MARK: - Track

/// A single song entry. `bpm` is the recorded tempo of the studio track (or
/// dance-half-time equivalent where relevant). It's advisory today — used to
/// keep playlists honest — and can drive per-song selection later.
struct MusicTrack: Codable, Hashable {
    let videoID: String
    let title: String
    let bpm: Int
}

// MARK: - Playlist

struct MusicPlaylist: Identifiable, Codable {
    let id: UUID
    let genre: MusicGenre
    let category: PlaylistCategory
    let name: String
    let tracks: [MusicTrack]

    var videoIDs: [String] { tracks.map(\.videoID) }

    init(genre: MusicGenre, category: PlaylistCategory, name: String, tracks: [MusicTrack]) {
        self.id = UUID()
        self.genre = genre
        self.category = category
        self.name = name
        self.tracks = tracks
    }

    // MARK: - Map workout zone -> category

    static func category(for zone: WorkoutZone) -> PlaylistCategory {
        switch zone {
        case .grey, .blue: return .coolDown
        case .green:       return .moderate
        case .orange, .red: return .highEnergy
        }
    }

    // MARK: - Curated library

    static func playlist(genre: MusicGenre, category: PlaylistCategory) -> MusicPlaylist {
        MusicLibrary.playlist(genre: genre, category: category)
    }
}

// MARK: - Library

enum MusicLibrary {
    // BOLLYWOOD ---------------------------------------------------------------

    static let bollywoodHighEnergy = MusicPlaylist(
        genre: .bollywood,
        category: .highEnergy,
        name: "Bollywood Fire 🔥",
        tracks: [
            .init(videoID: "l_MyUGq7pgs", title: "Malhari",             bpm: 140),
            .init(videoID: "YxWlaYCA6MU", title: "Khalibali",           bpm: 128),
            .init(videoID: "Gc_jbBsSaa0", title: "Tattad Tattad",       bpm: 145),
            .init(videoID: "JTcKB4OAXDE", title: "Naach Meri Rani",     bpm: 130),
            .init(videoID: "vTIIMJ9tUc8", title: "Garmi",               bpm: 132),
            .init(videoID: "BddP6PYo2gs", title: "Ghungroo",            bpm: 128),
            .init(videoID: "YoB8t0B4jx4", title: "Zingaat",             bpm: 155),
            .init(videoID: "Qlsfr66ONXM", title: "Nashe Si Chadh Gayi", bpm: 130),
            .init(videoID: "yDr0fCRGxOA", title: "Kar Gayi Chull",      bpm: 135),
            .init(videoID: "AEIVhBS6baE", title: "Balam Pichkari",      bpm: 130),
        ]
    )

    static let bollywoodModerate = MusicPlaylist(
        genre: .bollywood,
        category: .moderate,
        name: "Bollywood Beats 🎵",
        tracks: [
            .init(videoID: "cYOB941gyXI", title: "Dil Diyan Gallan",    bpm: 108),
            .init(videoID: "atGMFalVm1c", title: "Hawayein",            bpm: 115),
            .init(videoID: "pElk1ShPrcE", title: "Kal Ho Naa Ho",       bpm: 110),
            .init(videoID: "jHNNMj5bNQw", title: "Kabira",              bpm: 100),
            .init(videoID: "nIT3k1-tPWA", title: "Ilahi",               bpm: 120),
            .init(videoID: "9sEI1AUFJKw", title: "Mast Magan",          bpm: 105),
            .init(videoID: "ik_BjYMhVbU", title: "Raabta",              bpm: 112),
            .init(videoID: "I0FP3bLbDnI", title: "Ae Dil Hai Mushkil",  bpm: 118),
            .init(videoID: "TH4V-yHbJXk", title: "Channa Mereya",       bpm: 100),
        ]
    )

    static let bollywoodCoolDown = MusicPlaylist(
        genre: .bollywood,
        category: .coolDown,
        name: "Bollywood Chill 🌙",
        tracks: [
            .init(videoID: "hoNb6HuNmU0", title: "Tujhe Dekha To",       bpm: 78),
            .init(videoID: "s3vhKGwSg_c", title: "Tera Ban Jaunga",      bpm: 82),
            .init(videoID: "fSS_R91Nimw", title: "Tum Se Hi",            bpm: 85),
            .init(videoID: "cJ-RKCbzBnI", title: "Tujh Mein Rab Dikhta", bpm: 76),
            .init(videoID: "bx7l8e5M4-I", title: "Khairiyat",            bpm: 88),
            .init(videoID: "Pa1otBbKb8g", title: "Mann Bharrya",         bpm: 80),
        ]
    )

    // POP ---------------------------------------------------------------------

    static let popHighEnergy = MusicPlaylist(
        genre: .pop,
        category: .highEnergy,
        name: "Pop Fire 🔥",
        tracks: [
            .init(videoID: "4NRXx6U8ABQ", title: "Blinding Lights",   bpm: 171),
            .init(videoID: "nfWlot6h_JM", title: "Shake It Off",      bpm: 160),
            .init(videoID: "9HDEHj2yzew", title: "Physical",          bpm: 147),
            .init(videoID: "fKopy74weus", title: "Thunder",           bpm: 168),
            .init(videoID: "orJSJGHjBLI", title: "Bad Habits",        bpm: 126),
            .init(videoID: "7wtfhZwyrcc", title: "Believer",          bpm: 125),
            .init(videoID: "DyDfgMOUjCI", title: "Bad Guy",           bpm: 135),
            .init(videoID: "OPf0YbXqDm0", title: "Uptown Funk",       bpm: 115), // borderline but hi-energy vibe
        ]
    )

    static let popModerate = MusicPlaylist(
        genre: .pop,
        category: .moderate,
        name: "Pop Beats 🎵",
        tracks: [
            .init(videoID: "TUVcZfQe-Kw", title: "Levitating",        bpm: 103),
            .init(videoID: "nSDgHBxUbVQ", title: "Photograph",        bpm: 108),
            .init(videoID: "BQ0mxQXmLsk", title: "Havana",            bpm: 105),
            .init(videoID: "E07s5ZYygMg", title: "Watermelon Sugar",  bpm: 95),
            .init(videoID: "m7Bc3pLyij0", title: "Happier",           bpm: 100),
            .init(videoID: "vWaRiD5ym74", title: "Cake by the Ocean", bpm: 119),
            .init(videoID: "CevxZvSJLk8", title: "Roar",              bpm: 90),
        ]
    )

    static let popCoolDown = MusicPlaylist(
        genre: .pop,
        category: .coolDown,
        name: "Pop Chill 🌙",
        tracks: [
            .init(videoID: "2Vv-BfVoq4g", title: "Perfect",           bpm: 80),
            .init(videoID: "hLQl3WQQoQ0", title: "Someone Like You",  bpm: 67),
            .init(videoID: "ApXoWvfEYVU", title: "Sunflower",         bpm: 90),
            .init(videoID: "31crA53Dgu0", title: "Cheap Thrills",     bpm: 90),
        ]
    )

    // Selection ---------------------------------------------------------------

    static func playlist(genre: MusicGenre, category: PlaylistCategory) -> MusicPlaylist {
        switch (genre, category) {
        case (.bollywood, .highEnergy): return bollywoodHighEnergy
        case (.bollywood, .moderate):   return bollywoodModerate
        case (.bollywood, .coolDown):   return bollywoodCoolDown
        case (.pop,       .highEnergy): return popHighEnergy
        case (.pop,       .moderate):   return popModerate
        case (.pop,       .coolDown):   return popCoolDown
        }
    }

    /// Pre-plan one track per interval. Each interval is assigned the track
    /// whose BPM is closest to the middle of its category's BPM range, while
    /// avoiding immediate repeats and preferring tracks not yet used earlier
    /// in the session. Falls back to any repeat only if a category has fewer
    /// tracks than uses.
    static func planSession(categories: [PlaylistCategory], genre: MusicGenre) -> [MusicTrack] {
        var used: Set<String> = []
        var lastVideoID: String?
        var plan: [MusicTrack] = []

        for category in categories {
            let tracks = playlist(genre: genre, category: category).tracks
            guard !tracks.isEmpty else { continue }

            let target = (category.bpmRange.lowerBound + category.bpmRange.upperBound) / 2

            // Prefer unused tracks. If all used, allow reuse but never the
            // most-recent one back-to-back.
            let unused = tracks.filter { !used.contains($0.videoID) && $0.videoID != lastVideoID }
            let pool = !unused.isEmpty
                ? unused
                : tracks.filter { $0.videoID != lastVideoID }
            let fallback = pool.isEmpty ? tracks : pool

            let pick = fallback.min(by: { abs($0.bpm - target) < abs($1.bpm - target) }) ?? fallback[0]
            plan.append(pick)
            used.insert(pick.videoID)
            lastVideoID = pick.videoID
        }
        return plan
    }
}
