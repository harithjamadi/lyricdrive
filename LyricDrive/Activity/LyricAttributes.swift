import Foundation
import ActivityKit

struct LyricAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic data that changes frequently
        var currentLine: String
        var nextLine: String?
        var progress: Double // 0.0 to 1.0 for the progress bar
        var isPlaying: Bool
    }

    // Fixed data that doesn't change during the session
    var trackName: String
    var artistName: String
    var albumArtURL: String? // Optional: for the widget background
}
