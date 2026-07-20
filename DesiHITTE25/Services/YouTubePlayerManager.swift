import Foundation
import Combine
import WebKit

class YouTubePlayerManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var currentVideoTitle = ""
    @Published var musicVolume: Float = 0.7

    // MARK: - Private
    private var currentCategory: PlaylistCategory = .moderate
    private(set) var currentGenre: MusicGenre = .bollywood
    private var currentPlaylist: [String] = []
    private var currentVideoIndex: Int = 0
    weak var webView: WKWebView?

    init() {
        currentPlaylist = MusicLibrary.playlist(genre: currentGenre, category: .moderate).videoIDs
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
                var playlist = '\(playlistString)'.split(',');

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
                            'autoplay': 0
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange
                        }
                    });
                }

                function onPlayerReady(event) {
                    event.target.setVolume(\(Int(musicVolume * 100)));
                    window.webkit.messageHandlers.playerReady.postMessage('ready');
                }

                function onPlayerStateChange(event) {
                    if (event.data == YT.PlayerState.ENDED) {
                        playNext();
                    }
                    var title = player.getVideoData().title || '';
                    window.webkit.messageHandlers.titleUpdate.postMessage(title);
                    var state = event.data == YT.PlayerState.PLAYING ? 'playing' : 'paused';
                    window.webkit.messageHandlers.stateChange.postMessage(state);
                }

                function playVideo() {
                    if (player && player.playVideo) player.playVideo();
                }

                function pauseVideo() {
                    if (player && player.pauseVideo) player.pauseVideo();
                }

                function playNext() {
                    var currentIndex = playlist.indexOf(player.getVideoData().video_id);
                    var nextIndex = (currentIndex + 1) % playlist.length;
                    if (player && player.loadVideoById) {
                        player.loadVideoById(playlist[nextIndex]);
                    }
                }

                function setVolume(vol) {
                    if (player && player.setVolume) player.setVolume(vol);
                }

                function loadPlaylist(ids) {
                    playlist = ids.split(',');
                    if (player && player.loadVideoById && playlist.length > 0) {
                        player.loadVideoById(playlist[0]);
                    }
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
    }

    private func applyPlaylist(category: PlaylistCategory, genre: MusicGenre, force: Bool = false) {
        if !force, category == currentCategory, genre == currentGenre { return }
        currentCategory = category
        currentGenre = genre
        let playlist = MusicLibrary.playlist(genre: genre, category: category)
        currentPlaylist = playlist.videoIDs
        currentVideoIndex = 0
        let idsString = currentPlaylist.joined(separator: ",")
        webView?.evaluateJavaScript("loadPlaylist('\(idsString)');", completionHandler: nil)
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
}
