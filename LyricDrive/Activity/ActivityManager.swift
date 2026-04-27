import Foundation
import ActivityKit
import Combine

@MainActor
class ActivityManager: ObservableObject {
    static let shared = ActivityManager()
    private var activity: Activity<LyricAttributes>?
    
    private init() {}
    
    /// Requests a new Live Activity. Ends any existing activities first.
    func startTracking(trackName: String, artistName: String, albumArtURL: String? = nil) async {
        await endTracking()
        
        let attributes = LyricAttributes(
            trackName: trackName,
            artistName: artistName,
            albumArtURL: albumArtURL
        )
        
        let initialContentState = LyricAttributes.ContentState(
            currentLine: "Loading lyrics...",
            nextLine: nil,
            progress: 0.0,
            isPlaying: true
        )
        
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialContentState, staleDate: nil),
                pushType: nil // Set to .token for remote pushes if needed
            )
            print("Live Activity started: \(activity?.id ?? "unknown")")
        } catch {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    /// Updates the current Live Activity state.
    func update(currentLine: String, nextLine: String?, progress: Double, isPlaying: Bool) {
        // Validation: Avoid redundant updates if state is identical (handled by ActivityKit internally, but good for local logs)
        let state = LyricAttributes.ContentState(
            currentLine: currentLine,
            nextLine: nextLine,
            progress: progress,
            isPlaying: isPlaying
        )
        
        Task {
            await activity?.update(.init(state: state, staleDate: nil))
        }
    }
    
    /// Ends all active lyric activities.
    func endTracking() async {
        for activity in Activity<LyricAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}
