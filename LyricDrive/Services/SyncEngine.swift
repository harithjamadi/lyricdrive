import Foundation
import QuartzCore // For CACurrentMediaTime
import Combine

@MainActor
class SyncEngine: ObservableObject {
    @Published var currentPosition: TimeInterval = 0
    @Published var currentLineIndex: Int = 0
    @Published var currentLineContent: String = ""
    @Published var nextLineContent: String? = nil
    @Published var currentWordIndex: Int? = nil
    @Published var trackDuration: TimeInterval = 0
    
    @Published var allLines: [LyricLine] = []
    private var anchorPosition: TimeInterval = 0
    private var anchorTime: Double = 0
    private var isPlaying: Bool = false
    
    private var timer: Timer?
    private var lastActivityUpdateTime: TimeInterval = 0
    
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
            updateCurrentIndices(forceActivityUpdate: true)
        }
    }
    
    func setLyrics(_ syncedLyrics: String, duration: TimeInterval) {
        self.allLines = LRCParser.parse(syncedLyrics)
        self.trackDuration = duration
        self.currentLineIndex = 0
        updateCurrentIndices(forceActivityUpdate: true)
    }
    
    private func startTimer() {
        timer?.invalidate()
        // 16ms for smooth 60fps local UI updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isPlaying else { return }
                let now = CACurrentMediaTime()
                self.currentPosition = self.anchorPosition + (now - self.anchorTime)
                self.updateCurrentIndices()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCurrentIndices(forceActivityUpdate: Bool = false) {
        guard !allLines.isEmpty else {
            currentLineContent = ""
            nextLineContent = nil
            return
        }

        let index = allLines.lastIndex(where: { $0.startTime <= currentPosition }) ?? 0

        let lineChanged = index != currentLineIndex
        if lineChanged || currentLineContent.isEmpty {
            currentLineIndex = index
            currentLineContent = allLines[index].content
            nextLineContent = (index + 1 < allLines.count) ? allLines[index + 1].content : nil
        }

        let currentLine = allLines[currentLineIndex]
        if currentLine.isEnhanced {
            currentWordIndex = currentLine.words.lastIndex(where: { $0.startTime <= currentPosition })
        } else {
            currentWordIndex = nil
        }
        
        // Throttled Live Activity updates: 
        let now = CACurrentMediaTime()
        if lineChanged || forceActivityUpdate || (now - lastActivityUpdateTime) >= 5.0 {
            updateLiveActivity(currentLine: currentLine)
            lastActivityUpdateTime = now
        }
    }
    
    private func updateLiveActivity(currentLine: LyricLine) {
        let progress = trackDuration > 0 ? currentPosition / trackDuration : 0
        
        ActivityManager.shared.update(
            currentLine: currentLineContent,
            nextLine: nextLineContent,
            progress: min(max(progress, 0), 1),
            isPlaying: isPlaying
        )
    }
}
