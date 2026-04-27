import Foundation

enum LyricsError: Error {
    import Foundation

enum LyricsError: Error {
    case notFound
    case invalidResponse
    case networkError(Error)
}

class LRCLIBClient {
    private let baseURL = URL(string: "https://lrclib.net/api")!
    
    func fetchLyrics(title: String, artist: String, album: String, duration: Int) async throws -> LyricData {
        var components = URLComponents(url: baseURL.appendingPathComponent("get"), resolvingAgainstBaseURL: false)!
        
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "album_name", value: album),
            URLQueryItem(name: "duration", value: String(duration))
        ]
        
        guard let url = components.url else { throw LyricsError.invalidResponse }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else { throw LyricsError.invalidResponse }
        
        if httpResponse.statusCode == 404 {
            throw LyricsError.notFound
        }
        
        guard httpResponse.statusCode == 200 else { throw LyricsError.invalidResponse }
        
        return try JSONDecoder().decode(LyricData.self, from: data)
    }
}
