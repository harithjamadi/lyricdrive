import SwiftUI

@main
struct LyricDriveApp: App {
    @StateObject private var syncEngine: SyncEngine
    @StateObject private var spotifyManager: SpotifyManager
    @StateObject private var appleMusicManager: AppleMusicManager
    
    init() {
        let engine = SyncEngine()
        let spotify = SpotifyManager(syncEngine: engine)
        let apple = AppleMusicManager(syncEngine: engine)
        
        _syncEngine = StateObject(wrappedValue: engine)
        _spotifyManager = StateObject(wrappedValue: spotify)
        _appleMusicManager = StateObject(wrappedValue: apple)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncEngine)
                .environmentObject(spotifyManager)
                .environmentObject(appleMusicManager)
                .onOpenURL { url in
                    if url.scheme == "lyricdrive" {
                        spotifyManager.handle(url: url)
                    }
                }
        }
    }
}
