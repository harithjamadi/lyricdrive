import Foundation
import QuartzCore // For CACurrentMediaTime

class SyncEngine: ObservableObject {
    @Published var currentPosition: TimeInterval = 0
    @Published var currentLineIndex: Int = 0
    @Published var currentWordIndex: Int? = nil
    
    private var lines: [LyricLine] = []
    private var anchorPosition: TimeInterval = 0
    private var anchorTime: Double = 0
    private var isPlaying: Bool = false
    
    private var timer: Timer?
    
    /// Updates the sync anchor based on the SDK's position and current wall clock time.
    func updateAnchor(positionMS: Int, isPlaying: Bool) {
        self.anchorPosition = TimeInterval(positionMS) / 1000.0
        self.anchorTime = CACurrentMediaTime()
        self.isPlaying = isPlaying
        
        if isPlaying {
            startTimer()
        } else {
            stopTimer()
            self.currentPosition = self.anchorPosition
            updateCurrentIndices()
        }
    }
    
    func setLyrics(_ syncedLyrics: String) {
        self.lines = LRCParser.parse(syncedLyrics)
        updateCurrentIndices()
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            let now = CACurrentMediaTime()
            self.currentPosition = self.anchorPosition + (now - self.anchorTime)
            self.updateCurrentIndices()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCurrentIndices() {
        guard !lines.isEmpty else { return }
        
        // Find the current line
        let index = lines.lastIndex(where: { $0.startTime <= currentPosition }) ?? 0
        if index != currentLineIndex {
            currentLineIndex = index
        }
        
        // Find current word if enhanced
        let currentLine = lines[currentLineIndex]
        if currentLine.isEnhanced {
            currentWordIndex = currentLine.words.lastIndex(where: { $0.startTime <= currentPosition })
        } else {
            currentWordIndex = nil
        }
    }
}

struct LRCParser {
    static func parse(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rows = lrc.components(separatedBy: .newlines)
        
        for row in rows {
            // Very basic regex for [mm:ss.xx]
            // Real implementation should handle [mm:ss.xxx] and Enhanced <mm:ss.xx>
            if let line = parseLine(row) {
                lines.append(line)
            }
        }
        
        return lines.sorted(by: { $0.startTime < $1.startTime })
    }
    
    private static func parseLine(_ row: String) -> LyricLine? {
        // Implementation for parsing [00:12.34] Content
        // And [00:12.34] <00:12.34> Word1 <00:12.50> Word2
        // This is a placeholder for the actual complex regex/parsing logic
        return nil 
    }
}
