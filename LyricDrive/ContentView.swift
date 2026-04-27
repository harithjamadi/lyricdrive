import SwiftUI
import MediaPlayer

enum MusicService: String, CaseIterable {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
}

enum AccentTheme: String, CaseIterable {
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case orange = "Orange"

    var color: Color {
        switch self {
        case .green:  return Color(red: 0.12, green: 0.90, blue: 0.45)
        case .blue:   return Color(red: 0.25, green: 0.65, blue: 1.00)
        case .purple: return Color(red: 0.72, green: 0.35, blue: 1.00)
        case .pink:   return Color(red: 1.00, green: 0.22, blue: 0.58)
        case .orange: return Color(red: 1.00, green: 0.56, blue: 0.10)
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var syncEngine: SyncEngine
    @EnvironmentObject var spotifyManager: SpotifyManager
    @EnvironmentObject var appleMusicManager: AppleMusicManager

    @AppStorage("SelectedMusicService") var selectedService: MusicService = .spotify
    @AppStorage("SpotifyClientID") var storedClientID: String = ""
    @AppStorage("AccentThemeName") var accentThemeName: String = AccentTheme.green.rawValue
    @AppStorage("ContextLinesCount") var contextLinesCount: Int = 3
    @AppStorage("LyricFontSize") var lyricFontSize: Double = 18

    @State private var showingSettings = false

    var accentColor: Color {
        AccentTheme(rawValue: accentThemeName)?.color ?? AccentTheme.green.color
    }

    private var currentTrackName: String? {
        selectedService == .spotify ? spotifyManager.currentTrack?.name : appleMusicManager.currentTrackTitle
    }
    private var currentArtistName: String? {
        selectedService == .spotify ? spotifyManager.currentTrack?.artistName : appleMusicManager.currentArtist
    }
    private var currentAlbumArt: UIImage? {
        selectedService == .spotify ? spotifyManager.currentAlbumArtImage : appleMusicManager.currentAlbumArtImage
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(
                    colors: [accentColor.opacity(0.22), .clear],
                    center: .top, startRadius: 0, endRadius: 480
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: accentThemeName)

                VStack(spacing: 0) {
                    nowPlayingHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 6)

                    servicePickerView
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    LyricScrollView(
                        syncEngine: syncEngine,
                        accentColor: accentColor,
                        fontSize: lyricFontSize,
                        contextLines: contextLinesCount,
                        selectedService: selectedService
                    )

                    bottomBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
            .foregroundColor(.white)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                // Isolated struct — its @State slider drags never re-render ContentView
                SettingsSheet()
            }
        }
    }

    // MARK: Now Playing Header

    private var nowPlayingHeader: some View {
        HStack(spacing: 12) {
            albumArtThumbnail
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(currentTrackName ?? "Not Playing")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(currentArtistName ?? "—")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .animation(.easeInOut(duration: 0.2), value: currentTrackName)

            Spacer()

            connectionBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var albumArtThumbnail: some View {
        if let img = currentAlbumArt {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            ZStack {
                Color.white.opacity(0.07)
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }

    private var connectionBadge: some View {
        HStack(spacing: 5) {
            Circle().fill(connectionColor).frame(width: 6, height: 6)
                .shadow(color: connectionColor, radius: 3)
            Text(connectionStatusText)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
    }

    // MARK: Service Picker

    private var servicePickerView: some View {
        Picker("Service", selection: $selectedService) {
            ForEach(MusicService.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .onAppear {
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(white: 1, alpha: 0.18)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        }
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 14) {
            progressRow

            if selectedService == .spotify { spotifyControls }
            else { appleMusicControls }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var progressRow: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let pct = syncEngine.trackDuration > 0
                    ? min(syncEngine.currentPosition / syncEngine.trackDuration, 1.0) : 0.0
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10)).frame(height: 3)
                    Capsule().fill(accentColor)
                        .frame(width: geo.size.width * pct, height: 3)
                        .shadow(color: accentColor.opacity(0.7), radius: 4)
                }
            }
            .frame(height: 3)

            HStack {
                Text(formatTime(syncEngine.currentPosition))
                Spacer()
                Text(formatTime(syncEngine.trackDuration))
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.35))
        }
    }

    private var spotifyControls: some View {
        Group {
            if case .disconnected = spotifyManager.connectionState {
                Button { spotifyManager.connect() } label: {
                    Label("Connect Spotify", systemImage: "link")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(storedClientID.isEmpty ? Color.white.opacity(0.07) : accentColor)
                        .clipShape(Capsule())
                        .foregroundColor(storedClientID.isEmpty ? .white.opacity(0.3) : .black)
                }
                .disabled(storedClientID.isEmpty)
            } else {
                Label("Synced to Spotify", systemImage: "waveform")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(accentColor)
                    .frame(height: 44)
            }
        }
    }

    private var appleMusicControls: some View {
        Group {
            if !appleMusicManager.isAuthorized {
                Button { appleMusicManager.requestPermission() } label: {
                    Label("Authorize Apple Music", systemImage: "applelogo")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color(red: 0.98, green: 0.22, blue: 0.42))
                        .clipShape(Capsule()).foregroundColor(.white)
                }
            } else {
                Label("Synced to Apple Music", systemImage: "waveform")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.98, green: 0.22, blue: 0.42))
                    .frame(height: 44)
            }
        }
    }

    // MARK: Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    private var connectionStatusText: String {
        if selectedService == .appleMusic {
            return appleMusicManager.isAuthorized ? "Authorized" : "Unauthorized"
        }
        switch spotifyManager.connectionState {
        case .connected:    return "Connected"
        case .reconnecting: return "Linking…"
        case .disconnected: return "Offline"
        }
    }

    private var connectionColor: Color {
        if selectedService == .appleMusic {
            return appleMusicManager.isAuthorized ? accentColor : .red
        }
        switch spotifyManager.connectionState {
        case .connected:    return accentColor
        case .reconnecting: return .yellow
        case .disconnected: return .red
        }
    }
}

// MARK: - LyricScrollView
// Separate struct so @AppStorage changes in SettingsSheet don't re-render this

struct LyricScrollView: View {
    @ObservedObject var syncEngine: SyncEngine
    let accentColor: Color
    let fontSize: Double
    let contextLines: Int
    let selectedService: MusicService

    var body: some View {
        GeometryReader { geo in
            if syncEngine.allLines.isEmpty {
                emptyState(geo: geo)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: geo.size.height * 0.36)
                            ForEach(0..<syncEngine.allLines.count, id: \.self) { i in
                                LyricLineRow(
                                    text: syncEngine.allLines[i].content,
                                    offset: i - syncEngine.currentLineIndex,
                                    accentColor: accentColor,
                                    fontSize: fontSize,
                                    contextLines: contextLines
                                )
                                .id(i)
                            }
                            Color.clear.frame(height: geo.size.height * 0.54)
                        }
                    }
                    .onChange(of: syncEngine.currentLineIndex) { idx in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(idx, anchor: .center)
                        }
                    }
                    .onAppear { proxy.scrollTo(syncEngine.currentLineIndex, anchor: .center) }
                }
                .mask(LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.10),
                        .init(color: .white, location: 0.90),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                ))
            }
        }
    }

    private func emptyState(geo: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundColor(accentColor.opacity(0.45))
            Text(syncEngine.currentLineContent.isEmpty
                 ? "Play a song on \(selectedService.rawValue)"
                 : syncEngine.currentLineContent)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - LyricLineRow

struct LyricLineRow: View {
    let text: String
    let offset: Int
    let accentColor: Color
    let fontSize: Double
    let contextLines: Int

    private var isActive: Bool { offset == 0 }
    private var absOffset: Int { abs(offset) }

    private var opacity: Double {
        guard !isActive else { return 1.0 }
        guard absOffset <= contextLines else { return 0.0 }
        let ratio = 1.0 - Double(absOffset) / Double(contextLines + 1)
        return max(0.12, ratio * 0.55)
    }

    // scaleEffect: visual only, no layout recalculation → no scroll jitter
    private var scale: CGFloat {
        guard !isActive else { return 1.0 }
        return max(0.78, 1.0 - CGFloat(absOffset) * 0.07)
    }

    var body: some View {
        Group {
            if text.isEmpty {
                Color.clear.frame(height: 12)
            } else {
                Text(text)
                    .font(.system(size: fontSize, weight: isActive ? .bold : .regular, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(opacity)
                    .scaleEffect(scale)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background {
                        if isActive {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(accentColor.opacity(0.13))
                                .padding(.horizontal, 10)
                        }
                    }
            }
        }
        .frame(minHeight: fontSize * 2.2) // fixed height prevents scroll jitter
        .animation(.easeInOut(duration: 0.28), value: isActive)
        .animation(.easeInOut(duration: 0.28), value: opacity)
    }
}

// MARK: - SettingsSheet
// Own struct with local @State for sliders — changes here never re-render ContentView
// until the user lifts their finger (onEditingChanged) or taps Done.

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("SpotifyClientID")  private var storedClientID: String = ""
    @AppStorage("AccentThemeName") private var accentThemeName: String = AccentTheme.green.rawValue
    @AppStorage("ContextLinesCount") private var contextLinesCount: Int = 3
    @AppStorage("LyricFontSize")   private var lyricFontSize: Double = 18

    // Local mirrors — slider drags mutate these, NOT @AppStorage
    @State private var localFontSize: Double = 18
    @State private var localContextLines: Double = 3

    private var accentColor: Color {
        AccentTheme(rawValue: accentThemeName)?.color ?? AccentTheme.green.color
    }

    var body: some View {
        NavigationStack {
            Form {
                spotifySection
                displaySection
                previewSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Commit local slider values to @AppStorage on Done
                        lyricFontSize = localFontSize
                        contextLinesCount = Int(localContextLines)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                }
            }
            .onAppear {
                localFontSize = lyricFontSize
                localContextLines = Double(contextLinesCount)
            }
        }
    }

    private var spotifySection: some View {
        Section {
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundColor(accentColor)
                    .frame(width: 28)
                TextField("Client ID", text: $storedClientID)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(.body, design: .monospaced))
            }
            Link(destination: URL(string: "https://developer.spotify.com/dashboard")!) {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(accentColor)
                        .frame(width: 28)
                    Text("Open Spotify Developer Dashboard")
                        .font(.callout)
                }
            }
        } header: {
            Text("Spotify")
        } footer: {
            Text("Create an app and paste the Client ID above. Add lyricdrive://spotify-login-callback as a Redirect URI.")
                .font(.caption)
        }
    }

    private var displaySection: some View {
        Section("Appearance") {
            // Accent colour inline picker
            Picker("Accent Color", selection: $accentThemeName) {
                ForEach(AccentTheme.allCases, id: \.rawValue) { theme in
                    HStack {
                        Circle().fill(theme.color).frame(width: 14, height: 14)
                        Text(theme.rawValue)
                    }.tag(theme.rawValue)
                }
            }

            // Font size — local state, committed on finger lift
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Lyric Size")
                    Spacer()
                    Text("\(Int(localFontSize)) pt")
                        .font(.callout).foregroundColor(.secondary)
                }
                Slider(value: $localFontSize, in: 14...28, step: 2) { editing in
                    if !editing { lyricFontSize = localFontSize }
                }
                .tint(accentColor)
            }
            .padding(.vertical, 2)

            // Context lines — local state, committed on finger lift
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Context Lines")
                    Spacer()
                    Text("\(Int(localContextLines)) each side")
                        .font(.callout).foregroundColor(.secondary)
                }
                Slider(value: $localContextLines, in: 1...6, step: 1) { editing in
                    if !editing { contextLinesCount = Int(localContextLines) }
                }
                .tint(accentColor)
            }
            .padding(.vertical, 2)
        }
    }

    private var previewSection: some View {
        Section("Preview") {
            VStack(spacing: 4) {
                Text("Previous line")
                    .font(.system(size: localFontSize * 0.82, design: .rounded))
                    .foregroundColor(.secondary)
                Text("Current lyric line")
                    .font(.system(size: localFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                Text("Next line")
                    .font(.system(size: localFontSize * 0.82, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}
