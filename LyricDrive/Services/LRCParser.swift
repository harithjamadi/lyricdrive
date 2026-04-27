import Foundation

struct LRCParser {
    // Cached at type level — compiled once for the lifetime of the app
    private static let standardRegex = try? NSRegularExpression(pattern: #"^\[(\d+):(\d+)[.:](\d+)\](.*)"#)
    private static let wordRegex = try? NSRegularExpression(pattern: #"<(\d+):(\d+)[.:](\d+)>\s*([^<]+)"#)
    private static let tagRegex = try? NSRegularExpression(pattern: #"<\d+:\d+[.:]\d+>"#)
    
    static func parse(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rows = lrc.components(separatedBy: .newlines)
        
        for row in rows {
            guard !row.isEmpty else { continue }
            let nsRow = row as NSString
            guard let match = standardRegex?.firstMatch(in: row, range: NSRange(location: 0, length: nsRow.length)) else { continue }
            
            let min = Double(nsRow.substring(with: match.range(at: 1))) ?? 0
            let sec = Double(nsRow.substring(with: match.range(at: 2))) ?? 0
            let msStr = nsRow.substring(with: match.range(at: 3))
            let msVal = Double(msStr) ?? 0
            // LRC uses centiseconds (2 digits) or milliseconds (3 digits)
            let msSec = msStr.count > 2 ? msVal / 1000.0 : msVal / 100.0
            
            let startTime = (min * 60) + sec + msSec
            let content = nsRow.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
            
            let words = parseEnhancedWords(content, baseStartTime: startTime)
            lines.append(LyricLine(startTime: startTime, words: words, content: cleanContent(content)))
        }
        
        return lines.sorted(by: { $0.startTime < $1.startTime })
    }
    
    private static func parseEnhancedWords(_ content: String, baseStartTime: TimeInterval) -> [LyricWord] {
        guard let wordRegex = wordRegex else { return [] }
        var words: [LyricWord] = []
        let nsContent = content as NSString
        let matches = wordRegex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        
        for match in matches {
            let min = Double(nsContent.substring(with: match.range(at: 1))) ?? 0
            let sec = Double(nsContent.substring(with: match.range(at: 2))) ?? 0
            let msStr = nsContent.substring(with: match.range(at: 3))
            let msVal = Double(msStr) ?? 0
            let msSec = msStr.count > 2 ? msVal / 1000.0 : msVal / 100.0
            let startTime = (min * 60) + sec + msSec
            let word = nsContent.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
            words.append(LyricWord(startTime: startTime, endTime: startTime + 0.5, word: word))
        }
        
        return words
    }
    
    private static func cleanContent(_ content: String) -> String {
        guard let tagRegex = tagRegex else {
            return content.trimmingCharacters(in: .whitespaces)
        }
        let ns = content as NSString
        return tagRegex
            .stringByReplacingMatches(in: content, range: NSRange(location: 0, length: ns.length), withTemplate: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
