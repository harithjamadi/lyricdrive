import Foundation
import Combine

enum AppRemoteState {
    case connected(position: Int, isPlaying: Bool)
    case reconnecting
    case disconnected(since: Date)
}

class SpotifyManager: NSObject, ObservableObject {
    @Published var connectionState: AppRemoteState = .disconnected(since: Date())
    @Published var currentTrack: LyricData?
    
    // In a real app, these would be the Spotify SDK classes
    // private var appRemote: SPTAppRemote!
    // private var configuration: SPTConfiguration!
    
    private var cancellables = Set<AnyCancellable>()
    private let syncEngine: SyncEngine
    
    init(syncEngine: SyncEngine) {
        self.syncEngine = syncEngine
        super.init()
        setupStateSubscription()
    }
    
    func setupStateSubscription() {
        // Update the SyncEngine whenever the connection state changes
        $connectionState.sink { [weak self] state in
            switch state {
            case .connected(let position, let isPlaying):
                self?.syncEngine.updateAnchor(positionMS: position, isPlaying: isPlaying)
            case .reconnecting, .disconnected:
                // Let the syncEngine continue dead-reckoning or stop
                break
            }
        }.store(in: &cancellables)
    }
    
    // MARK: - Spotify SDK Delegates (Simulated)
    
    func appRemoteDidEstablishConnection() {
        print("Connected to Spotify")
        // Cold start fix: immediately request state
        // self.appRemote.playerAPI?.getPlayerState { (result, error) in ... }
        
        // Mocking a successful connection
        self.connectionState = .connected(position: 0, isPlaying: true)
    }
    
    func appRemoteDidDisconnect() {
        print("Disconnected from Spotify")
        self.connectionState = .disconnected(since: Date())
    }
    
    func playerStateDidChange(_ state: Any) {
        // Map the SPTAppRemotePlayerState to our anchor system
        // let position = state.playbackPosition
        // let isPlaying = !state.isPaused
        
        // Update anchor
        // self.connectionState = .connected(position: position, isPlaying: isPlaying)
    }
    
    func connect(clientId: String) {
        // self.configuration = SPTConfiguration(clientID: clientId, redirectURL: ...)
        // self.appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        // self.appRemote.delegate = self
        // self.appRemote.connect()
    }
}
