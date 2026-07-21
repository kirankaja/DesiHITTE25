import Foundation
import AVFoundation
import Combine

/// Streams CC-licensed MP3s from the Jamendo API and plays them via
/// AVQueuePlayer. Ad-free, no user auth. Uses the public demo client_id
/// `b6747d04` — swap for your own from https://developer.jamendo.com if you
/// hit rate limits.
///
/// Category → query mapping treats Bollywood/Pop genre as advisory only —
/// Jamendo's catalog is world/electronic/pop and doesn't carry major-label
/// Bollywood, so the source ignores `MusicGenre` and buckets purely by
/// intensity (cool-down / moderate / high-energy).
final class JamendoMusicSource: NSObject, ObservableObject, MusicController {
    static let clientID = "b6747d04"

    // MARK: - Published State
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTrack: JamendoTrack?
    @Published var musicVolume: Float = 0.7 {
        didSet { avPlayer?.volume = musicVolume }
    }

    // MARK: - MusicController
    private(set) var currentGenre: MusicGenre = .bollywood

    // MARK: - Private State
    private var sessionPlanCategories: [PlaylistCategory] = []
    private var avPlayer: AVQueuePlayer?
    private var currentPlayerItem: AVPlayerItem?
    private var itemEndObserver: NSObjectProtocol?

    /// Cached per-category track pool. Filled lazily on first `planSession`
    /// (and on demand if a category wasn't warmed).
    private var pool: [PlaylistCategory: [JamendoTrack]] = [:]
    /// Prevents duplicate concurrent fetches for the same category.
    private var inflight: [PlaylistCategory: Task<[JamendoTrack], Never>] = [:]
    /// Track IDs already played this session so we don't loop the same song
    /// repeatedly across intervals.
    private var playedIDs: Set<String> = []

    // MARK: - Types

    struct JamendoTrack: Hashable, Identifiable {
        let id: String
        let title: String
        let artist: String
        /// 0 when the API didn't provide a BPM — treated as "unknown".
        let bpm: Int
        let duration: TimeInterval
        let audioURL: URL
        let albumImageURL: URL?
    }

    // MARK: - MusicController

    func setGenre(_ genre: MusicGenre) {
        // Jamendo doesn't have curated Bollywood/Pop bins the way YouTube
        // does — genre is stored so the router's currentGenre reflects the
        // user's setting, but doesn't affect track selection here. Settings
        // shows a note explaining this.
        self.currentGenre = genre
    }

    func planSession(categories: [PlaylistCategory], genre: MusicGenre) {
        self.currentGenre = genre
        self.sessionPlanCategories = categories
        self.playedIDs.removeAll()
        // Kick off pool warm-up for every unique category we'll need so the
        // first per-interval track pick doesn't have to block on the network.
        let unique = Array(Set(categories))
        Task { await warmPool(for: unique) }
    }

    func clearSessionPlan() {
        sessionPlanCategories = []
        playedIDs.removeAll()
        stopPlayback()
    }

    func play() {
        avPlayer?.play()
        DispatchQueue.main.async { [weak self] in self?.isPlaying = true }
    }

    func pause() {
        avPlayer?.pause()
        DispatchQueue.main.async { [weak self] in self?.isPlaying = false }
    }

    func playPlannedTrack(at intervalIndex: Int, fallbackCategory: PlaylistCategory) {
        let category = intervalIndex < sessionPlanCategories.count
            ? sessionPlanCategories[intervalIndex]
            : fallbackCategory
        Task { @MainActor in
            let track = await pickTrack(for: category)
            if let track { playTrack(track) }
        }
    }

    func skipToSimilarBPM() {
        Task { @MainActor in
            guard let current = currentTrack else { return }
            let category = categoryForBPM(current.bpm > 0 ? current.bpm : 120)
            let track = await pickTrack(for: category, excluding: current.id)
            if let track { playTrack(track) }
        }
    }

    // MARK: - Playback

    @MainActor
    private func playTrack(_ track: JamendoTrack) {
        // Remove prior end-of-item observer so we don't stack callbacks when
        // intervals advance faster than tracks finish.
        if let observer = itemEndObserver {
            NotificationCenter.default.removeObserver(observer)
            itemEndObserver = nil
        }

        let item = AVPlayerItem(url: track.audioURL)
        let player = AVQueuePlayer(playerItem: item)
        player.volume = musicVolume

        // On natural end, pick another track from the same intensity bucket
        // so music keeps flowing between interval boundaries.
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let cat = self.categoryForBPM(track.bpm > 0 ? track.bpm : 120)
                if let next = await self.pickTrack(for: cat, excluding: track.id) {
                    self.playTrack(next)
                }
            }
        }

        self.avPlayer = player
        self.currentPlayerItem = item
        self.currentTrack = track
        self.playedIDs.insert(track.id)
        player.play()
        self.isPlaying = true
    }

    private func stopPlayback() {
        if let observer = itemEndObserver {
            NotificationCenter.default.removeObserver(observer)
            itemEndObserver = nil
        }
        avPlayer?.pause()
        avPlayer = nil
        currentPlayerItem = nil
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.currentTrack = nil
        }
    }

    // MARK: - Track selection

    private func categoryForBPM(_ bpm: Int) -> PlaylistCategory {
        switch bpm {
        case ..<95: return .coolDown
        case 95..<125: return .moderate
        default: return .highEnergy
        }
    }

    @MainActor
    private func pickTrack(for category: PlaylistCategory,
                           excluding excludeID: String? = nil) async -> JamendoTrack? {
        if pool[category] == nil {
            await warmPool(for: [category])
        }
        let all = pool[category] ?? []
        // Prefer unplayed tracks so we cycle through the pool before repeating.
        let unplayed = all.filter { !playedIDs.contains($0.id) && $0.id != excludeID }
        if let pick = unplayed.randomElement() { return pick }
        // Everything's been heard — allow repeats but still avoid the current one.
        let allowRepeats = all.filter { $0.id != excludeID }
        return allowRepeats.randomElement() ?? all.first
    }

    private func warmPool(for categories: [PlaylistCategory]) async {
        await withTaskGroup(of: (PlaylistCategory, [JamendoTrack]).self) { group in
            for cat in categories where pool[cat] == nil {
                group.addTask { [weak self] in
                    guard let self else { return (cat, []) }
                    let tracks = await self.fetchOrWaitForTracks(for: cat)
                    return (cat, tracks)
                }
            }
            for await (cat, tracks) in group {
                await MainActor.run {
                    self.pool[cat] = tracks
                }
            }
        }
    }

    /// Deduplicate concurrent fetches for the same category.
    private func fetchOrWaitForTracks(for category: PlaylistCategory) async -> [JamendoTrack] {
        if let existing = inflight[category] {
            return await existing.value
        }
        let task = Task<[JamendoTrack], Never> { [weak self] in
            guard let self else { return [] }
            return await self.fetchTracks(for: category)
        }
        inflight[category] = task
        let result = await task.value
        inflight[category] = nil
        return result
    }

    // MARK: - REST

    private func fetchTracks(for category: PlaylistCategory) async -> [JamendoTrack] {
        var comps = URLComponents(string: "https://api.jamendo.com/v3.0/tracks/")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "audioformat", value: "mp32"),
            URLQueryItem(name: "include", value: "musicinfo"),
            URLQueryItem(name: "order", value: "popularity_total"),
        ]
        switch category {
        case .highEnergy:
            items.append(URLQueryItem(name: "speed", value: "high+veryhigh"))
            items.append(URLQueryItem(name: "tags", value: "electronic+workout+energetic"))
        case .moderate:
            items.append(URLQueryItem(name: "speed", value: "medium"))
            items.append(URLQueryItem(name: "tags", value: "pop+upbeat+funky"))
        case .coolDown:
            items.append(URLQueryItem(name: "speed", value: "low"))
            items.append(URLQueryItem(name: "tags", value: "chill+relaxing+ambient"))
        }
        comps.queryItems = items
        guard let url = comps.url else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                print("[Jamendo] HTTP \(http.statusCode) for \(category)")
                return []
            }
            let decoded = try JSONDecoder().decode(JamendoResponse.self, from: data)
            let tracks = decoded.results.compactMap { $0.toTrack() }
            print("[Jamendo] fetched \(tracks.count) tracks for \(category.rawValue)")
            return tracks
        } catch {
            print("[Jamendo] fetch failed for \(category): \(error)")
            return []
        }
    }

    // MARK: - REST DTOs

    private struct JamendoResponse: Decodable {
        let results: [Result]
        struct Result: Decodable {
            let id: String
            let name: String
            let artist_name: String?
            let duration: Int?
            let audio: String
            let image: String?
            let musicinfo: MusicInfo?
            struct MusicInfo: Decodable {
                // The `bpm` field is sometimes a Number, sometimes absent —
                // decoding as Double? lets us treat missing as unknown.
                let bpm: Double?
            }
            func toTrack() -> JamendoTrack? {
                guard let audioURL = URL(string: audio) else { return nil }
                let bpm = Int(musicinfo?.bpm ?? 0)
                return JamendoTrack(
                    id: id,
                    title: name,
                    artist: artist_name ?? "",
                    bpm: bpm,
                    duration: TimeInterval(duration ?? 0),
                    audioURL: audioURL,
                    albumImageURL: image.flatMap(URL.init(string:))
                )
            }
        }
    }
}
