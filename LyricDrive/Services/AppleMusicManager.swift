import Foundation
import MediaPlayer
import Combine

@MainActor
class AppleMusicManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var currentTrackTitle: String?
    @Published var currentArtist: String?
    @Published var currentAlbumArtImage: UIImage?

    private let syncEngine: SyncEngine
    private let player = MPMusicPlayerController.systemMusicPlayer
    private var timer: AnyCancellable?

    init(syncEngine: SyncEngine) {
        self.syncEngine = syncEngine
        checkAuthorization()
    }

    func checkAuthorization() {
        let status = MPMediaLibrary.authorizationStatus()
        self.isAuthorized = (status == .authorized)
    }

    func requestPermission() {
        MPMediaLibrary.requestAuthorization { status in
            Task { @MainActor in
                self.isAuthorized = (status == .authorized)
                if self.isAuthorized {
                    self.startObserving()
                }
            }
        }
    }

    func startObserving() {
        player.beginGeneratingPlaybackNotifications()

        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateSync() }

        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in self?.handleTrackChange() }
    }

    private func handleTrackChange() {
        guard let item = player.nowPlayingItem else {
            currentTrackTitle = nil
            currentArtist = nil
            return
        }

        let trackName = item.title ?? ""
        let artistName = item.artist ?? ""
        let duration = item.playbackDuration

        currentTrackTitle = trackName
        currentArtist = artistName
        currentAlbumArtImage = item.artwork?.image(at: CGSize(width: 300, height: 300))

        syncEngine.setLyrics("[00:00.00] Loading lyrics...", duration: duration)

        Task {
            let lyrics = await LRCLIBClient.shared.fetchLyrics(
                trackName: trackName,
                artistName: artistName,
                duration: Int(duration)
            )

            guard currentTrackTitle == trackName, currentArtist == artistName else { return }

            if let synced = lyrics {
                syncEngine.setLyrics(synced, duration: duration)
            } else {
                syncEngine.setLyrics("[00:00.00] No lyrics found.", duration: duration)
            }
        }
    }

    private func updateSync() {
        let isPlaying = player.playbackState == .playing
        let positionMS = Int(player.currentPlaybackTime * 1000)
        syncEngine.updateAnchor(positionMS: positionMS, isPlaying: isPlaying)
    }
}
