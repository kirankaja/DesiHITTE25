import Foundation
import Combine
import WebKit

class YouTubePlayerManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var currentVideoTitle = ""
    @Published var musicVolume: Float = 0.7
    @Published private(set) var currentTrack: MusicTrack?

    // MARK: - Private
    private var currentCategory: PlaylistCategory = .moderate
    private(set) var currentGenre: MusicGenre = .bollywood
    private var currentPlaylist: [String] = []
    private var currentPlaylistTracks: [MusicTrack] = []
    private var currentVideoIndex: Int = 0

    /// Pre-planned track sequence, one entry per workout interval, chosen at
    /// session start so intensity ramps line up with intended BPM targets.
    /// Empty when no workout is planned; falls back to plain playlist cycling.
    private var sessionPlan: [MusicTrack] = []
    private var sessionPlanCategories: [PlaylistCategory] = []
    weak var webView: WKWebView?

    init() {
        let seed = MusicLibrary.playlist(genre: currentGenre, category: .moderate)
        currentPlaylist = seed.videoIDs
        currentPlaylistTracks = seed.tracks
    }

    // MARK: - Player HTML

    var playerHTML: String {
        let videoID = currentPlaylist.first ?? ""
        let playlistString = currentPlaylist.joined(separator: ",")
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; }
                body { background: #000; overflow: hidden; }
                #player { width: 100%; height: 100%; }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <script>
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

                var player;
                var playerReady = false;
                var pendingCommands = [];
                var playlist = '\(playlistString)'.split(',');
                var errorSkipCount = 0;

                function runOrQueue(fn) {
                    if (playerReady && player) {
                        fn();
                    } else {
                        pendingCommands.push(fn);
                    }
                }

                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        height: '100%',
                        width: '100%',
                        videoId: '\(videoID)',
                        playerVars: {
                            'playsinline': 1,
                            'controls': 0,
                            'modestbranding': 1,
                            'rel': 0,
                            'fs': 0,
                            'iv_load_policy': 3,
                            'autoplay': 1
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onError': onPlayerError
                        }
                    });
                }

                function onPlayerError(event) {
                    // 2 = bad param, 5 = html5 error, 100 = not found/private,
                    // 101 / 150 = embed disabled by owner. Skip and try next.
                    window.webkit.messageHandlers.playerError.postMessage(String(event.data));
                    if (errorSkipCount < playlist.length) {
                        errorSkipCount++;
                        setTimeout(playNext, 200);
                    }
                }

                function onPlayerReady(event) {
                    event.target.setVolume(\(Int(musicVolume * 100)));
                    playerReady = true;
                    window.webkit.messageHandlers.playerReady.postMessage('ready');
                    // Drain any commands that arrived before the player was ready
                    while (pendingCommands.length > 0) {
                        var fn = pendingCommands.shift();
                        try { fn(); } catch (e) {}
                    }
                }

                function onPlayerStateChange(event) {
                    if (event.data == YT.PlayerState.PLAYING) {
                        errorSkipCount = 0; // reset on successful play
                    }
                    if (event.data == YT.PlayerState.ENDED) {
                        playNext();
                    }
                    var title = player.getVideoData().title || '';
                    window.webkit.messageHandlers.titleUpdate.postMessage(title);
                    var state = event.data == YT.PlayerState.PLAYING ? 'playing' : 'paused';
                    window.webkit.messageHandlers.stateChange.postMessage(state);
                }

                function playVideo() {
                    runOrQueue(function() { player.playVideo(); });
                }

                function pauseVideo() {
                    runOrQueue(function() { player.pauseVideo(); });
                }

                function playNext() {
                    runOrQueue(function() {
                        var currentIndex = playlist.indexOf(player.getVideoData().video_id);
                        var nextIndex = (currentIndex + 1) % playlist.length;
                        player.loadVideoById(playlist[nextIndex]);
                    });
                }

                function setVolume(vol) {
                    runOrQueue(function() { player.setVolume(vol); });
                }

                function loadPlaylist(ids) {
                    playlist = ids.split(',');
                    errorSkipCount = 0;
                    runOrQueue(function() {
                        if (playlist.length > 0) player.loadVideoById(playlist[0]);
                    });
                }

                function loadVideo(id) {
                    errorSkipCount = 0;
                    runOrQueue(function() { player.loadVideoById(id); });
                }
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Control Methods

    func play() {
        isPlaying = true
        webView?.evaluateJavaScript("playVideo();", completionHandler: nil)
    }

    func pause() {
        isPlaying = false
        webView?.evaluateJavaScript("pauseVideo();", completionHandler: nil)
    }

    func next() {
        currentVideoIndex = (currentVideoIndex + 1) % currentPlaylist.count
        webView?.evaluateJavaScript("playNext();", completionHandler: nil)
    }

    func setVolume(_ volume: Float) {
        musicVolume = volume
        let jsVolume = Int(volume * 100)
        webView?.evaluateJavaScript("setVolume(\(jsVolume));", completionHandler: nil)
    }

    func switchPlaylist(to category: PlaylistCategory) {
        applyPlaylist(category: category, genre: currentGenre)
    }

    /// Change genre. If a workout is running, this immediately reloads the
    /// current category in the new genre so the switch is audible right away.
    func setGenre(_ genre: MusicGenre) {
        guard genre != currentGenre else { return }
        applyPlaylist(category: currentCategory, genre: genre, force: true)
        // Genre change invalidates the BPM-planned queue; re-plan against the
        // same interval-category sequence in the new genre.
        if !sessionPlanCategories.isEmpty {
            sessionPlan = MusicLibrary.planSession(
                categories: sessionPlanCategories,
                genre: genre
            )
        }
    }

    /// Pre-select one track per interval so the whole session's music is
    /// planned up front. Each interval gets a track whose BPM sits closest
    /// to the middle of its category's BPM range, avoiding immediate repeats.
    /// Call once at workout start; call `playPlannedTrack(at:)` on each
    /// interval boundary.
    func planSession(categories: [PlaylistCategory], genre: MusicGenre) {
        currentGenre = genre
        sessionPlanCategories = categories
        sessionPlan = MusicLibrary.planSession(categories: categories, genre: genre)
    }

    func clearSessionPlan() {
        sessionPlan = []
        sessionPlanCategories = []
    }

    /// Play the track pre-selected for a given interval index. Falls back to
    /// a plain category swap if the plan is empty or the index is out of range.
    func playPlannedTrack(at intervalIndex: Int, fallbackCategory: PlaylistCategory) {
        guard intervalIndex >= 0, intervalIndex < sessionPlan.count else {
            applyPlaylist(category: fallbackCategory, genre: currentGenre)
            return
        }
        let track = sessionPlan[intervalIndex]
        // Load the whole category playlist so ENDED wrap-around still works
        // after the planned track finishes.
        let playlist = MusicLibrary.playlist(genre: currentGenre, category: fallbackCategory)
        currentCategory = fallbackCategory
        currentPlaylist = playlist.videoIDs
        currentPlaylistTracks = playlist.tracks
        currentVideoIndex = playlist.videoIDs.firstIndex(of: track.videoID) ?? 0
        let idsString = currentPlaylist.joined(separator: ",")
        // Load the playlist context, then jump straight to the chosen track.
        webView?.evaluateJavaScript(
            "loadPlaylist('\(idsString)'); loadVideo('\(track.videoID)');",
            completionHandler: nil
        )
        DispatchQueue.main.async { [weak self] in
            self?.currentTrack = track
        }
    }

    /// Skip to another track in the *current* playlist whose BPM is closest
    /// to the current track's BPM (±10 first, widening as needed). If the
    /// current track's BPM is unknown, falls through to the next track.
    func skipToSimilarBPM() {
        guard !currentPlaylistTracks.isEmpty else {
            next()
            return
        }
        let currentID = currentTrack?.videoID
        let currentBPM = currentTrack?.bpm ?? currentCategory.bpmRange.lowerBound
        let candidates = currentPlaylistTracks.filter { $0.videoID != currentID }
        guard !candidates.isEmpty else { return }

        // Try increasing BPM tolerances so we prefer a close match but always
        // find something.
        let tolerances = [10, 20, 40, Int.max]
        var chosen: MusicTrack?
        for tol in tolerances {
            let inBand = candidates.filter { abs($0.bpm - currentBPM) <= tol }
            if let best = inBand.min(by: { abs($0.bpm - currentBPM) < abs($1.bpm - currentBPM) }) {
                chosen = best
                break
            }
        }
        guard let track = chosen else { return }
        currentVideoIndex = currentPlaylist.firstIndex(of: track.videoID) ?? currentVideoIndex
        webView?.evaluateJavaScript("loadVideo('\(track.videoID)');", completionHandler: nil)
        DispatchQueue.main.async { [weak self] in
            self?.currentTrack = track
        }
    }

    private func applyPlaylist(category: PlaylistCategory, genre: MusicGenre, force: Bool = false) {
        if !force, category == currentCategory, genre == currentGenre { return }
        currentCategory = category
        currentGenre = genre
        let playlist = MusicLibrary.playlist(genre: genre, category: category)
        currentPlaylist = playlist.videoIDs
        currentPlaylistTracks = playlist.tracks
        currentVideoIndex = 0
        let idsString = currentPlaylist.joined(separator: ",")
        webView?.evaluateJavaScript("loadPlaylist('\(idsString)');", completionHandler: nil)
        DispatchQueue.main.async { [weak self] in
            self?.currentTrack = playlist.tracks.first
        }
    }

    // MARK: - Message Handlers

    func handleTitleUpdate(_ title: String) {
        DispatchQueue.main.async { [weak self] in
            self?.currentVideoTitle = title
        }
    }

    func handleStateChange(_ state: String) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = (state == "playing")
        }
    }

    func handlePlayerError(_ code: String) {
        // Log so it shows up in Xcode console; the JS side already auto-skips
        // to the next track. Codes: 2=bad param, 5=html5, 100=not found,
        // 101/150=embed disabled by owner.
        print("[YouTubePlayer] error code=\(code) — auto-skipping to next track")
    }
}
