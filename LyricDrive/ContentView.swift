import SwiftUI

struct ContentView: View {
    @StateObject var syncEngine = SyncEngine()
    @StateObject var spotifyManager: SpotifyManager
    @State private var clientId: String = UserDefaults.standard.string(forKey: "SpotifyClientId") ?? ""
    
    init() {
        let engine = SyncEngine()
        _syncEngine = StateObject(wrappedValue: engine)
        _spotifyManager = StateObject(wrappedValue: SpotifyManager(syncEngine: engine))
    }
    
    var body: some View {
        ZStack {
            // Animated background color based on album art (simulated)
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                if clientId.isEmpty {
                    VStack(spacing: 20) {
                        Text("Spotify Client ID Required")
                            .font(.headline)
                        TextField("Enter Client ID", text: $clientId)
                            .textFieldStyle(.roundedBorder)
                            .padding()
                        Button("Save & Connect") {
                            UserDefaults.standard.set(clientId, forKey: "SpotifyClientId")
                            spotifyManager.connect(clientId: clientId)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
                    .padding()
                } else {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Now Playing")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Song Title") // To be replaced by spotifyManager.currentTrack
                                .font(.title3.bold())
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding()
                    
                    // Lyrics View
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 30) {
                                ForEach(0..<20) { index in // Simulated lines
                                    LyricLineView(
                                        content: "Line \(index) of the song",
                                        isCurrent: syncEngine.currentLineIndex == index,
                                        isEnhanced: false
                                    )
                                    .id(index)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .onChange(of: syncEngine.currentLineIndex) { newIndex in
                            withAnimation(.spring()) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct LyricLineView: View {
    let content: String
    let isCurrent: Bool
    let isEnhanced: Bool
    
    var body: some View {
        Text(content)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(isCurrent ? .white : .white.opacity(0.3))
            .scaleEffect(isCurrent ? 1.05 : 1.0)
            .blur(radius: isCurrent ? 0 : 0.5)
            .animation(.spring(), value: isCurrent)
            .multilineTextAlignment(.leading)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
