import Foundation

struct LRCParser {
    static func parse(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rows = lrc.components(separatedBy: .newlines)
        
        // Regex for standard LRC: [00:12.34] Lyrics
        let standardRegex = try? NSRegularExpression(pattern: #"^\[(\d+):(\d+).(\d+)\](.*)"#)
        
        for row in rows {
            let nsRow = row as NSString
            if let match = standardRegex?.firstMatch(in: row, range: NSRange(location: 0, length: nsRow.length)) {
                let min = Double(nsRow.substring(with: match.range(at: 1))) ?? 0
                let sec = Double(nsRow.substring(with: match.range(at: 2))) ?? 0
                let ms = Double(nsRow.substring(with: match.range(at: 3))) ?? 0
                
                let startTime = (min * 60) + sec + (ms / 100.0)
                let content = nsRow.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                
                // Enhanced LRC parsing: Check for <00:12.34> word timestamps within content
                let words = parseEnhancedWords(content, baseStartTime: startTime)
                
                lines.append(LyricLine(startTime: startTime, words: words, content: cleanContent(content)))
            }
        }
        
        return lines.sorted(by: { $0.startTime < $1.startTime })
    }
    
    private static func parseEnhancedWords(_ content: String, baseStartTime: TimeInterval) -> [LyricWord] {
        var words: [LyricWord] = []
        let wordRegex = try? NSRegularExpression(pattern: #"<(\d+):(\d+).(\d+)>\s*([^<]+)"#)
        let nsContent = content as NSString
        
        let matches = wordRegex?.matches(in: content, range: NSRange(location: 0, length: nsContent.length)) ?? []
        
        for match in matches {
            let min = Double(nsContent.substring(with: match.range(at: 1))) ?? 0
            let sec = Double(nsContent.substring(with: match.range(at: 2))) ?? 0
            let ms = Double(nsContent.substring(with: match.range(at: 3))) ?? 0
            
            let startTime = (min * 60) + sec + (ms / 100.0)
            let word = nsContent.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
            
            // For now, we set endTime as the next word's startTime or +1s
            words.append(LyricWord(startTime: startTime, endTime: startTime + 0.5, word: word))
        }
        
        return words
    }
    
    private static func cleanContent(_ content: String) -> String {
        // Remove all <00:12.34> tags from content for clean display
        return content.replacingOccurrences(of: #"<\d+:\d+.\d+>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
