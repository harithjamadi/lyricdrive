import Foundation

struct LyricLine: Identifiable, Codable, Equatable {
    let id = UUID()
    let startTime: TimeInterval // Seconds
    let words: [LyricWord]
    let content: String // Fallback for line-level sync

    var isEnhanced: Bool {
        !words.isEmpty
    }
}

struct LyricWord: Identifiable, Codable, Equatable {
    let id = UUID()
    let startTime: TimeInterval
    let endTime: TimeInterval
    let word: String
}

struct LyricData: Codable {
    let id: Int
    let name: String
    let artistName: String
    let albumName: String
    let duration: Int
    let instrumental: Bool
    let plainLyrics: String?
    let syncedLyrics: String?
}
