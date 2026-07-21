import Foundation
import Combine

/// Routes music playback calls to whichever backend the user picked in
/// Settings (Jamendo MP3s or YouTube IFrame). Presents a unified `MusicController`
/// surface to WorkoutEngine and unified `@Published` state (title, BPM, isPlaying)
/// to WorkoutView.
///
/// Both concrete sources are held long-lived so switching mid-session doesn't
/// tear down their caches / web view. WorkoutView still peeks at
/// `youtubeManager` directly to embed the WKWebView when YT is active.
final class MusicRouter: ObservableObject, MusicController {

    let youtubeManager: YouTubePlayerManager
    let jamendoSource: JamendoMusicSource

    @Published var activeSource: MusicSourceKind

    private var cancellables = Set<AnyCancellable>()

    init(youtubeManager: YouTubePlayerManager,
         jamendoSource: JamendoMusicSource,
         initial: MusicSourceKind = .jamendo) {
        self.youtubeManager = youtubeManager
        self.jamendoSource = jamendoSource
        self.activeSource = initial

        // Re-publish any change on either child so views observing the router
        // re-render (title, isPlaying, BPM — all live on the child objects).
        youtubeManager.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        jamendoSource.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private var active: MusicController {
        activeSource == .jamendo ? jamendoSource : youtubeManager
    }

    // MARK: - Source Switching

    func setActiveSource(_ kind: MusicSourceKind) {
        guard kind != activeSource else { return }
        // Stop the outgoing source cleanly so we don't have two audio pipes
        // playing at once when the user flips the toggle mid-workout.
        active.pause()
        active.clearSessionPlan()
        activeSource = kind
    }

    // MARK: - MusicController

    var currentGenre: MusicGenre { active.currentGenre }

    func planSession(categories: [PlaylistCategory], genre: MusicGenre) {
        active.planSession(categories: categories, genre: genre)
    }

    func playPlannedTrack(at intervalIndex: Int, fallbackCategory: PlaylistCategory) {
        active.playPlannedTrack(at: intervalIndex, fallbackCategory: fallbackCategory)
    }

    func skipToSimilarBPM() {
        active.skipToSimilarBPM()
    }

    func play() { active.play() }
    func pause() { active.pause() }

    func clearSessionPlan() { active.clearSessionPlan() }

    func setGenre(_ genre: MusicGenre) {
        // Route genre changes to both sources so the router's `currentGenre`
        // stays consistent no matter which one is active later.
        youtubeManager.setGenre(genre)
        jamendoSource.setGenre(genre)
    }

    // MARK: - UI Helpers (WorkoutView reads these)

    var isPlaying: Bool {
        activeSource == .jamendo ? jamendoSource.isPlaying : youtubeManager.isPlaying
    }

    var currentTitle: String {
        switch activeSource {
        case .jamendo:
            guard let t = jamendoSource.currentTrack else { return "" }
            return t.artist.isEmpty ? t.title : "\(t.title) — \(t.artist)"
        case .youtube:
            return youtubeManager.currentVideoTitle.isEmpty
                ? (youtubeManager.currentTrack?.title ?? "")
                : youtubeManager.currentVideoTitle
        }
    }

    var currentBPM: Int? {
        switch activeSource {
        case .jamendo:
            let bpm = jamendoSource.currentTrack?.bpm ?? 0
            return bpm > 0 ? bpm : nil
        case .youtube:
            return youtubeManager.currentTrack?.bpm
        }
    }

    var musicVolume: Float {
        get {
            activeSource == .jamendo ? jamendoSource.musicVolume : youtubeManager.musicVolume
        }
    }

    /// Setter side-effect: mirror volume to both sources so a mid-workout
    /// source swap doesn't blast at the last-set value.
    func setVolume(_ volume: Float) {
        youtubeManager.setVolume(volume)
        jamendoSource.musicVolume = volume
    }
}
