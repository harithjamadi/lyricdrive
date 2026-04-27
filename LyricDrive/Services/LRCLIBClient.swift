import Foundation

class LRCLIBClient {
    static let shared = LRCLIBClient()
    private let cacheDirectory: URL

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = base.appendingPathComponent("LyricCache")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func fetchLyrics(trackName: String, artistName: String, duration: Int) async -> String? {
        
        let cacheKey = "\(artistName)_\(trackName)_\(duration)".lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
        let cacheURL = cacheDirectory.appendingPathComponent("\(cacheKey).lrc")
        
        if FileManager.default.fileExists(atPath: cacheURL.path),
           let cached = try? String(contentsOf: cacheURL, encoding: .utf8) {
            return cached
        }
        
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName),
            URLQueryItem(name: "duration", value: "\(duration)")
        ]
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("LyricDrive/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("LRCLIB Server returned error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return nil
            }
            
            let lyricData = try JSONDecoder().decode(LyricData.self, from: data)
            
            if let lyrics = lyricData.syncedLyrics ?? lyricData.plainLyrics {
                try? lyrics.write(to: cacheURL, atomically: true, encoding: String.Encoding.utf8)
                return lyrics
            }
            return nil
        } catch {
            print("Error fetching lyrics from \(url.absoluteString): \(error.localizedDescription)")
            return nil
        }
    }
}
