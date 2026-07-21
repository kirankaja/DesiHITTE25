import Foundation

/// Fetches Bollywood/Hindi tracks from YouTube Data API v3 dynamically per
/// workout intensity, filtering to only videos that are:
///   * embeddable (status.embeddable == true)
///   * publicly viewable (status.privacyStatus == "public")
///   * in Music category (id 10)
///   * of reasonable workout length (short/medium duration)
///
/// This exists because the previous curated Bollywood library was fragile:
/// labels routinely mark videos as embed-disabled or geo-block them, causing
/// the player to hit YT error 101/150 and go silent. Dynamic search gives us
/// a fresh, filtered pool every session so blocked videos never surface.
///
/// Requires a Google Cloud YouTube Data API v3 key stored in APIKeyStore.
/// If no key is present, this service silently returns nil and callers fall
/// back to the curated MusicLibrary.
final class YouTubeSearchService {
    static let shared = YouTubeSearchService()

    // MARK: - Cache

    /// Per-category pool of vetted tracks. Cached for the lifetime of the
    /// process — refreshed only when the API key changes or when the caller
    /// explicitly invalidates. Search + validate is ~2 quota units per call
    /// against a 10,000/day default budget, so we're stingy.
    private var pool: [PlaylistCategory: [MusicTrack]] = [:]

    /// Guards against concurrent duplicate fetches for the same category
    /// (e.g. planSession firing while a warmPool is already in flight).
    private var inFlight: [PlaylistCategory: Task<[MusicTrack], Never>] = [:]

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyChange),
            name: .youtubeAPIKeyDidChange,
            object: nil
        )
    }

    @objc private func handleKeyChange() {
        // New key = potentially different quota / region — dump the cache.
        pool.removeAll()
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
    }

    // MARK: - Public API

    /// Return cached tracks for a category, or nil if we haven't fetched yet.
    /// Non-blocking; use this on the synchronous planSession path so the UI
    /// doesn't wait for network.
    func cachedTracks(for category: PlaylistCategory) -> [MusicTrack]? {
        let cached = pool[category]
        return (cached?.isEmpty ?? true) ? nil : cached
    }

    /// Fetch tracks for a category, using the cache when available. Returns
    /// nil (and does no work) if there's no API key configured — callers
    /// should fall back to the curated library.
    @discardableResult
    func fetchPool(for category: PlaylistCategory) async -> [MusicTrack]? {
        guard APIKeyStore.shared.hasYoutubeAPIKey else { return nil }
        if let cached = pool[category], !cached.isEmpty { return cached }
        if let existing = inFlight[category] {
            return await existing.value
        }
        let task = Task<[MusicTrack], Never> { [weak self] in
            let result = await self?.runFetch(for: category) ?? []
            await MainActor.run { [weak self] in
                self?.pool[category] = result
                self?.inFlight[category] = nil
            }
            return result
        }
        inFlight[category] = task
        let result = await task.value
        return result.isEmpty ? nil : result
    }

    /// Kick off (fire-and-forget) fetches for a set of categories so cached
    /// results are hot by the time the workout hits the corresponding
    /// intervals. Safe to call from a synchronous context.
    func warmPool(for categories: [PlaylistCategory]) {
        guard APIKeyStore.shared.hasYoutubeAPIKey else { return }
        let unique = Array(Set(categories))
        for cat in unique {
            if pool[cat] != nil || inFlight[cat] != nil { continue }
            Task { [weak self] in
                _ = await self?.fetchPool(for: cat)
            }
        }
    }

    // MARK: - Fetch pipeline

    private func runFetch(for category: PlaylistCategory) async -> [MusicTrack] {
        guard let apiKey = APIKeyStore.shared.youtubeAPIKey, !apiKey.isEmpty else { return [] }
        let queries = searchQueries(for: category)
        var collected: [String: MusicTrack] = [:] // dedupe by videoID
        for q in queries {
            do {
                let ids = try await searchIDs(query: q, apiKey: apiKey, category: category)
                if ids.isEmpty { continue }
                let vetted = try await validate(ids: ids, apiKey: apiKey, category: category)
                for track in vetted { collected[track.videoID] = track }
                if collected.count >= 20 { break } // enough for a session
            } catch {
                print("[YouTubeSearchService] fetch failed for '\(q)': \(error)")
            }
        }
        return Array(collected.values).shuffled()
    }

    // MARK: - Query construction

    /// Curated per-intensity Bollywood/Hindi search queries. These are seeded
    /// from what actually surfaces embeddable content on YouTube — official
    /// T-Series and Zee Music uploads tend to be geo-blocked or embed-off,
    /// so we bias toward workout-mashup and cover-channel keywords which are
    /// far more likely to be embeddable.
    private func searchQueries(for category: PlaylistCategory) -> [String] {
        switch category {
        case .highEnergy:
            return [
                "bollywood workout mashup high energy",
                "bollywood cardio mix hindi",
                "bollywood dance workout mix",
                "hindi party remix nonstop",
            ]
        case .moderate:
            return [
                "bollywood upbeat hindi mix",
                "bollywood dance hits playlist",
                "hindi bollywood pop mix",
            ]
        case .coolDown:
            return [
                "bollywood chill acoustic hindi",
                "hindi soft romantic mix",
                "bollywood cooldown slow songs",
            ]
        }
    }

    // MARK: - REST calls

    private func searchIDs(query: String, apiKey: String, category: PlaylistCategory) async throws -> [String] {
        var comps = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        comps.queryItems = [
            .init(name: "part", value: "snippet"),
            .init(name: "q", value: query),
            .init(name: "type", value: "video"),
            .init(name: "videoEmbeddable", value: "true"),
            .init(name: "videoSyndicated", value: "true"),
            .init(name: "videoCategoryId", value: "10"), // Music
            .init(name: "videoDuration", value: category == .coolDown ? "medium" : "medium"),
            .init(name: "maxResults", value: "25"),
            .init(name: "safeSearch", value: "moderate"),
            .init(name: "key", value: apiKey),
        ]
        guard let url = comps.url else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkResponse(response, data: data, endpoint: "search.list")
        struct SearchResponse: Decodable {
            struct Item: Decodable {
                struct ID: Decodable { let videoId: String? }
                let id: ID
            }
            let items: [Item]
        }
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.items.compactMap { $0.id.videoId }
    }

    /// Second-pass filter: search.list's `videoEmbeddable` flag is not always
    /// respected in practice, so we call videos.list to double-check
    /// status.embeddable + contentDetails.duration.
    private func validate(ids: [String], apiKey: String, category: PlaylistCategory) async throws -> [MusicTrack] {
        guard !ids.isEmpty else { return [] }
        var comps = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")!
        comps.queryItems = [
            .init(name: "part", value: "snippet,status,contentDetails"),
            .init(name: "id", value: ids.joined(separator: ",")),
            .init(name: "key", value: apiKey),
        ]
        guard let url = comps.url else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)
        try checkResponse(response, data: data, endpoint: "videos.list")

        struct VideosResponse: Decodable {
            struct Item: Decodable {
                struct Snippet: Decodable { let title: String }
                struct Status: Decodable {
                    let embeddable: Bool
                    let privacyStatus: String
                }
                struct Content: Decodable { let duration: String }
                let id: String
                let snippet: Snippet
                let status: Status
                let contentDetails: Content
            }
            let items: [Item]
        }
        let decoded = try JSONDecoder().decode(VideosResponse.self, from: data)
        let assumedBPM = Int((Double(category.bpmRange.lowerBound) + Double(category.bpmRange.upperBound)) / 2.0)
        return decoded.items.compactMap { item -> MusicTrack? in
            guard item.status.embeddable, item.status.privacyStatus == "public" else { return nil }
            // ISO 8601 duration parsing — accept 2:00-10:00 minute range.
            let seconds = parseISODuration(item.contentDetails.duration)
            guard seconds >= 90, seconds <= 720 else { return nil }
            return MusicTrack(
                videoID: item.id,
                title: item.snippet.title,
                bpm: assumedBPM
            )
        }
    }

    private func checkResponse(_ response: URLResponse, data: Data, endpoint: String) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            throw NSError(
                domain: "YouTubeSearchService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "\(endpoint) HTTP \(http.statusCode): \(body.prefix(200))"]
            )
        }
    }

    /// Parse a small subset of ISO 8601 duration (PT#H#M#S) into seconds.
    private func parseISODuration(_ s: String) -> Int {
        var seconds = 0
        var current = ""
        // Skip "PT" prefix.
        let stripped = s.hasPrefix("PT") ? String(s.dropFirst(2)) : s
        for ch in stripped {
            if ch.isNumber {
                current.append(ch)
            } else {
                let value = Int(current) ?? 0
                current = ""
                switch ch {
                case "H": seconds += value * 3600
                case "M": seconds += value * 60
                case "S": seconds += value
                default: break
                }
            }
        }
        return seconds
    }
}
