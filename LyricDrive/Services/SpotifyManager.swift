import Foundation
import Combine
import SpotifyiOS

enum AppRemoteState: Equatable {
    case connected(position: Int, isPlaying: Bool)
    case reconnecting
    case disconnected(since: Date)
}

@MainActor
class SpotifyManager: NSObject, ObservableObject {
    @Published var connectionState: AppRemoteState = .disconnected(since: Date())
    @Published var currentTrack: LyricData?
    @Published var currentAlbumArtImage: UIImage?
    
    private var lastFetchedURI: String?
    
    private let redirectURL = URL(string: "lyricdrive://spotify-login-callback")!

    private var cancellables = Set<AnyCancellable>()
    private let syncEngine: SyncEngine

    // Spotify SDK Properties
    private var appRemote: SPTAppRemote?

    private var clientID: String {
        UserDefaults.standard.string(forKey: "SpotifyClientID") ?? ""
    }

    private var configuration: SPTConfiguration {
        SPTConfiguration(clientID: clientID, redirectURL: redirectURL)
    }
    
    init(syncEngine: SyncEngine) {
        self.syncEngine = syncEngine
        super.init()
        setupStateSubscription()
    }
    
    private func setupStateSubscription() {
        $connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                switch state {
                case .connected(let position, let isPlaying):
                    self?.syncEngine.updateAnchor(positionMS: position, isPlaying: isPlaying)
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    func handle(url: URL) {
        guard let appRemote = appRemote else { return }
        let parameters = appRemote.authorizationParameters(from: url)
        
        if let accessToken = parameters?[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = accessToken
            appRemote.connect() 
        } else if let errorDescription = parameters?[SPTAppRemoteErrorDescriptionKey] {
            print("Auth Error: \(errorDescription)")
        }
    }
    
    func connect() {
        guard !clientID.isEmpty else { return }
        
        if appRemote == nil {
            appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
            appRemote?.delegate = self
        }
        
        guard let appRemote = appRemote else { return }
        
        if appRemote.connectionParameters.accessToken != nil {
            appRemote.connect()
        } else {
            appRemote.authorizeAndPlayURI("")
        }
    }
    
    func startLiveActivity() {
        guard let track = currentTrack else { return }
        Task {
            await ActivityManager.shared.startTracking(
                trackName: track.name,
                artistName: track.artistName
            )
        }
    }
}

extension SpotifyManager: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("Connected to Spotify")
        self.connectionState = .connected(position: 0, isPlaying: true)
        
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { (result, error) in
            if let error = error {
                print("Error subscribing to player state: \(error.localizedDescription)")
            }
        })
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("Failed connection attempt: \(error?.localizedDescription ?? "unknown")")
        self.connectionState = .disconnected(since: Date())
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("Disconnected from Spotify: \(error?.localizedDescription ?? "unknown")")
        self.connectionState = .disconnected(since: Date())
        Task {
            await ActivityManager.shared.endTracking()
        }
    }
}

extension SpotifyManager: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        let position = playerState.playbackPosition
        let isPlaying = !playerState.isPaused
        
        // Update anchor for millisecond sync instantly
        self.connectionState = .connected(position: position, isPlaying: isPlaying)
        
        let track = playerState.track
        let trackURI = track.uri
        
        // If track URI changed, handle instant metadata update
        if lastFetchedURI != trackURI {
            lastFetchedURI = trackURI
            currentAlbumArtImage = nil

            let trackName = track.name
            let artistName = track.artist.name
            let duration = TimeInterval(track.duration) / 1000.0

            // Fetch album art from Spotify SDK
            self.appRemote?.imageAPI?.fetchImage(forItem: track, with: CGSize(width: 300, height: 300)) { [weak self] result, _ in
                if let image = result as? UIImage {
                    Task { @MainActor in self?.currentAlbumArtImage = image }
                }
            }
            
            // 1. Extract image URL from Spotify URI
            // spotify:image:ab67616d0000b273... -> https://i.scdn.co/image/ab67616d0000b273...
            let imageURI = track.imageIdentifier
            let imageID = imageURI.components(separatedBy: ":").last ?? ""
            let albumArtURL = imageID.isEmpty ? nil : "https://i.scdn.co/image/\(imageID)"

            // 2. Update metadata INSTANTLY
            self.currentTrack = LyricData(
                id: 0,
                name: trackName,
                artistName: artistName,
                albumName: "",
                duration: Int(duration),
                instrumental: false,
                plainLyrics: nil,
                syncedLyrics: nil,
                albumArtURL: albumArtURL
            )
            
            // 2. Clear previous lyrics and show loading state in SyncEngine immediately
            syncEngine.setLyrics("[00:00.00] Loading lyrics...", duration: duration)
            
            // 3. Update the Live Activity/Dynamic Island with the new song info right away
            self.startLiveActivity()
            
            Task {
                // 4. Fetch real lyrics in the background
                let lyrics = await LRCLIBClient.shared.fetchLyrics(
                    trackName: trackName,
                    artistName: artistName,
                    duration: Int(duration)
                )
                
                // 5. Verify we are still on the SAME track (handles rapid skipping)
                guard self.lastFetchedURI == trackURI else { return }
                
                // 6. Update again with the downloaded lyrics
                self.currentTrack = LyricData(
                    id: 0,
                    name: trackName,
                    artistName: artistName,
                    albumName: "",
                    duration: Int(duration),
                    instrumental: false,
                    plainLyrics: nil,
                    syncedLyrics: lyrics
                )
                
                if let synced = lyrics {
                    syncEngine.setLyrics(synced, duration: duration)
                } else {
                    syncEngine.setLyrics("[00:00.00] No lyrics found.", duration: duration)
                }
            }
        }
    }
}
