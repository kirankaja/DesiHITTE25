import Foundation

/// Tracks which YouTube video IDs are playable inside the embedded IFrame.
///
/// YouTube has no free API that definitively answers "is this video
/// embeddable?" (Data API v3 does, but needs an API key). We combine two
/// signals:
///
///   1. Runtime failures — when the player fires onError for a video ID,
///      the manager reports it here and it's blocklisted forever. This is
///      self-healing: any video whose embed permission gets revoked is
///      caught the first time we try to play it and then skipped in
///      every future session.
///
///   2. Upfront oEmbed probe — YouTube's public oEmbed endpoint returns
///      401 for embed-disabled videos and 404 for private/removed ones.
///      Not perfect (some videos oEmbed-OK but still block embed at play
///      time), but catches the obvious dead IDs before a workout starts.
///
/// State persists across app launches via UserDefaults so the app gets
/// smarter about its curated library over time.
/// Tracks which YouTube video IDs are playable inside the embedded IFrame.
///
/// (See file header for the rationale — runtime blocklist + oEmbed probe.)
final class YouTubePlayabilityFilter: ObservableObject, @unchecked Sendable {
    static let shared = YouTubePlayabilityFilter()

    private let blockedKey = "YTPlayabilityFilter.blockedIDs.v1"
    private let checkedKey = "YTPlayabilityFilter.checkedIDs.v1"

    // `blockedIDs` drives UI reactively so it must publish on main. The
    // internal setter routes all mutations through the main queue.
    @Published private(set) var blockedIDs: Set<String>
    /// IDs we've already oEmbed-probed (whether they passed or not) so we
    /// don't waste bandwidth re-checking them every launch.
    private var checkedIDs: Set<String>
    private let lock = NSLock()

    private let defaults: UserDefaults
    private let session: URLSession

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
        self.blockedIDs = Set(defaults.stringArray(forKey: blockedKey) ?? [])
        self.checkedIDs = Set(defaults.stringArray(forKey: checkedKey) ?? [])
    }

    // MARK: - Runtime signal

    /// Called by YouTubePlayerManager when the IFrame reports an error for
    /// the currently-loaded video ID. The ID is blocklisted permanently
    /// and future session plans skip it.
    func markBlocked(_ id: String) {
        guard !id.isEmpty else { return }
        lock.lock()
        let alreadyBlocked = blockedIDs.contains(id)
        lock.unlock()
        guard !alreadyBlocked else { return }

        let update = { [weak self] in
            guard let self else { return }
            self.blockedIDs.insert(id)
            self.persistBlocked()
        }
        if Thread.isMainThread { update() } else { DispatchQueue.main.async(execute: update) }
    }

    func isBlocked(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return blockedIDs.contains(id)
    }

    // MARK: - Filtering helpers

    /// Return the subset of tracks not on the blocklist. Order preserved.
    func playableTracks(_ tracks: [MusicTrack]) -> [MusicTrack] {
        lock.lock()
        let blocked = blockedIDs
        lock.unlock()
        return tracks.filter { !blocked.contains($0.videoID) }
    }

    /// Snapshot of the current blocklist, safe to read from any thread.
    var currentBlockedIDs: Set<String> {
        lock.lock(); defer { lock.unlock() }
        return blockedIDs
    }

    // MARK: - Upfront probe

    /// Probe every ID in the curated library that we haven't checked yet.
    /// Runs in the background, hits oEmbed with a small concurrent pool.
    /// Safe to call on every app launch — after the first pass most IDs
    /// are in `checkedIDs` and are skipped.
    func probeLibraryInBackground() {
        let allIDs = Self.allLibraryIDs()
        lock.lock()
        let unchecked = allIDs.filter { !checkedIDs.contains($0) }
        lock.unlock()
        guard !unchecked.isEmpty else { return }
        Task.detached(priority: .utility) { [weak self] in
            await self?.probe(ids: unchecked)
        }
    }

    private func probe(ids: [String]) async {
        // Small concurrency cap so we don't hammer oembed.
        let batchSize = 4
        for chunk in stride(from: 0, to: ids.count, by: batchSize).map({
            Array(ids[$0..<min($0 + batchSize, ids.count)])
        }) {
            await withTaskGroup(of: (String, Bool).self) { group in
                for id in chunk {
                    group.addTask { [weak self] in
                        let ok = (await self?.probeOne(id: id)) ?? true
                        return (id, ok)
                    }
                }
                for await (id, ok) in group {
                    if !ok { markBlocked(id) }
                    lock.lock()
                    checkedIDs.insert(id)
                    lock.unlock()
                }
            }
        }
        persistChecked()
    }

    private func probeOne(id: String) async -> Bool {
        let urlString = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(id)&format=json"
        guard let url = URL(string: urlString) else { return true }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return true }
            // 401 = embed disabled by owner. 404 = private / deleted.
            // 403 = region-restricted (treat as blocked for our purposes).
            switch http.statusCode {
            case 401, 403, 404: return false
            default: return true
            }
        } catch {
            // Network hiccup — don't blocklist on transient failure.
            return true
        }
    }

    // MARK: - Persistence

    private func persistBlocked() {
        lock.lock()
        let list = Array(blockedIDs)
        lock.unlock()
        defaults.set(list, forKey: blockedKey)
    }

    private func persistChecked() {
        lock.lock()
        let list = Array(checkedIDs)
        lock.unlock()
        defaults.set(list, forKey: checkedKey)
    }

    // MARK: - Library discovery

    /// Flatten every video ID in the curated library so the probe can
    /// walk them without hardcoding each playlist.
    private static func allLibraryIDs() -> [String] {
        let playlists: [MusicPlaylist] = [
            MusicLibrary.bollywoodHighEnergy,
            MusicLibrary.bollywoodModerate,
            MusicLibrary.bollywoodCoolDown,
            MusicLibrary.popHighEnergy,
            MusicLibrary.popModerate,
            MusicLibrary.popCoolDown
        ]
        return playlists.flatMap { $0.videoIDs }
    }

    // MARK: - Debug / recovery

    /// Wipe the blocklist. Exposed for a future Settings toggle if the
    /// user wants to re-test previously-blocked tracks.
    func resetBlocklist() {
        let clear = { [weak self] in
            guard let self else { return }
            self.blockedIDs.removeAll()
            self.lock.lock()
            self.checkedIDs.removeAll()
            self.lock.unlock()
            self.persistBlocked()
            self.persistChecked()
        }
        if Thread.isMainThread { clear() } else { DispatchQueue.main.async(execute: clear) }
    }
}
