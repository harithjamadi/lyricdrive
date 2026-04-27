---
phase: 01-live-activity-prototype
reviewed: 2025-05-15T10:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - LyricDrive/Activity/ActivityManager.swift
  - LyricDrive/LyricDriveApp.swift
  - LyricDrive/Services/SpotifyManager.swift
  - LyricDrive/Services/SyncEngine.swift
  - LyricDrive/ContentView.swift
  - LyricWidget/LyricWidgetLiveActivity.swift
findings:
  critical: 1
  warning: 3
  info: 3
  total: 7
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2025-05-15
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

The prototype for Phase 1 establishes a solid foundation for Live Activity integration and lyric synchronization. The core logic for LRC parsing and the sync engine is well-structured. However, there are significant concerns regarding thread safety when interacting with Spotify SDK callbacks and the frequency of Live Activity updates which could lead to system-level throttling.

## Critical Issues

### CR-01: Thread Safety in SyncEngine and SpotifyManager

**File:** `LyricDrive/Services/SyncEngine.swift:15`, `LyricDrive/Services/SpotifyManager.swift:48`
**Issue:** `SyncEngine` and `SpotifyManager` update `@Published` properties from callbacks that may originate from background threads (Spotify SDK delegates). This can lead to UI crashes or inconsistent state. Since these classes are `ObservableObject` used for UI binding, they must ensure updates happen on the main thread.
**Fix:**
Mark both classes with `@MainActor` to ensure all property updates and method calls are isolated to the main thread.

```swift
@MainActor
class SyncEngine: ObservableObject { ... }

@MainActor
class SpotifyManager: NSObject, ObservableObject { ... }
```

## Warnings

### WR-01: Excessive Live Activity Updates

**File:** `LyricDrive/Services/SyncEngine.swift:54-79`
**Issue:** The `SyncEngine` timer runs every 0.1 seconds and calls `ActivityManager.shared.update` on every tick. Live Activities have a system-defined update budget. Updating 10 times per second will quickly exhaust this budget, causing the OS to throttle or stop updates entirely.
**Fix:**
Only update the Live Activity when the `currentLineIndex` changes, or at a much lower frequency for progress (e.g., every 5-10 seconds).

```swift
// Inside updateCurrentIndices()
let lineChanged = index != currentLineIndex
currentLineIndex = index

if lineChanged {
    ActivityManager.shared.update(...)
}
```

### WR-02: Race Condition in ActivityManager startTracking

**File:** `LyricDrive/Activity/ActivityManager.swift:13-14`
**Issue:** `startTracking` calls `endTracking()`, which spawns an asynchronous `Task` to end activities. It immediately proceeds to call `Activity.request`. If the OS hasn't finished closing the previous activity, the request for a new one might fail or result in multiple active sessions.
**Fix:**
Make `endTracking` async and await it in `startTracking`, or use a synchronous check to ensure clean state.

```swift
func startTracking(...) async {
    await endTracking()
    // ... request activity
}

func endTracking() async {
    for activity in Activity<LyricAttributes>.activities {
        await activity.end(dismissalPolicy: .immediate)
    }
    self.activity = nil
}
```

### WR-03: Hardcoded Client ID in UI

**File:** `LyricDrive/ContentView.swift:76`
**Issue:** The Spotify Client ID is hardcoded in the view's button action. This is a security risk and makes the app harder to configure for different environments.
**Fix:**
Move the Client ID to a configuration file or a secure constants file, and consider using an environment variable or `Info.plist` for storage.

```swift
// In a config file
enum SpotifyConfig {
    static let clientId = "..."
}
```

## Info

### IN-01: Redundant StateObject Initialization

**File:** `LyricDrive/LyricDriveApp.swift:5`
**Issue:** `syncEngine` is initialized twice: once at the declaration and once in the `init` block.
**Fix:**
Remove the initial assignment at the declaration.

```swift
@StateObject private var syncEngine: SyncEngine
```

### IN-02: Hardcoded Mocks in ContentView

**File:** `LyricDrive/ContentView.swift:101-108`
**Issue:** `currentLineText` and `nextLineText` are hardcoded strings, meaning the main app UI doesn't actually display the synced lyrics from `SyncEngine`.
**Fix:**
Bind these properties to `syncEngine.currentLine` (you may need to add this property to `SyncEngine`).

### IN-03: Duplicate LyricAttributes Definition

**File:** `LyricWidget/LyricWidgetLiveActivity.swift:6`
**Issue:** `LyricAttributes` is redefined in the widget target. While common in some setups, it can lead to "out of sync" errors if the structure is updated in the app but not the widget.
**Fix:**
Ensure both the App and the Widget Extension targets include `LyricAttributes.swift` in their Target Membership, and remove the local definition in the widget file.

---

_Reviewed: 2025-05-15_
_Reviewer: gsd-code-reviewer_
_Depth: standard_
