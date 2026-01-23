# Issue 013: Dev Mode vs Release Mode

**Severity:** Medium (UX/polish)
**Status:** Open
**Reported:** 2026-01-23

## Summary

Add a toggle to switch between "dev mode" (full debugging UI) and "release mode" (clean user-facing UI). Dev mode exposes testing tools; release mode hides them for a polished App Store experience.

## Motivation

Current UI includes features useful for development but confusing/unnecessary for end users:
- Dry Run button (users just want to sync)
- Background sync debug output
- Detailed sync logs
- Possibly other debug info

These should be hidden in release builds or behind a toggle.

## Proposed Modes

### Release Mode (Default for App Store)

Clean, simple UI:
- **Main screen:** Sync button, last sync status, background sync toggle
- **Settings:** List selection, Vikunja connection, sync frequency
- No dry run, no debug output, no raw logs

### Dev Mode (For Development/Testing)

Full debugging UI:
- Everything in release mode, plus:
- **Dry Run button** - Preview changes without applying
- **Background sync debug output** - See what's happening
- **Download sync log** - Export detailed logs
- **1-minute sync interval** - For testing (see Issue 012)
- **Raw API responses** - Debug Vikunja communication
- **SQLite browser** - Inspect mapping database

## Implementation Options

### Option A: Compile-Time Flag

```swift
#if DEBUG
    // Show dev UI
#else
    // Show release UI
#endif
```

**Pros:** Simple, no runtime overhead, can't accidentally ship dev mode
**Cons:** Can't test release UI during development without rebuilding

### Option B: Runtime Toggle (Hidden)

Secret gesture or hidden setting to enable dev mode:
- Triple-tap version number
- Type "devmode" somewhere
- Hidden preference

```swift
@AppStorage("devModeEnabled") var devMode = false
```

**Pros:** Can test both modes easily, can enable for beta testers
**Cons:** Could accidentally ship with dev mode on, users might discover it

### Option C: Hybrid (Recommended)

- **Debug builds:** Dev mode always available via toggle
- **Release builds:** Dev mode hidden by default, accessible via secret gesture
- **App Store builds:** Dev mode completely removed (compile-time)

```swift
#if DEBUG
    let canEnableDevMode = true
#elseif BETA
    let canEnableDevMode = true  // Hidden but accessible
#else
    let canEnableDevMode = false  // App Store: no dev mode
#endif
```

## UI Elements by Mode

| Element | Release Mode | Dev Mode |
|---------|--------------|----------|
| Sync Now button | ✅ | ✅ |
| Last sync status | ✅ | ✅ |
| Background sync toggle | ✅ | ✅ |
| Sync frequency picker | ✅ | ✅ |
| List selection (settings) | ✅ | ✅ |
| Vikunja connection (settings) | ✅ | ✅ |
| Dry Run button | ❌ | ✅ |
| Background sync log | ❌ | ✅ |
| Download sync log | ❓ Maybe | ✅ |
| 1-min sync interval | ❌ | ✅ |
| Raw API debug | ❌ | ✅ |
| SQLite viewer | ❌ | ✅ |
| Dev mode toggle | ❌ | ✅ |

### Download Sync Log - Release Mode?

**Arguments for including in release mode:**
- Helps users report bugs with full context
- Support can request logs for troubleshooting
- Power users appreciate transparency

**Arguments against:**
- Clutters UI
- May expose sensitive data (task titles, etc.)
- Most users won't use it

**Recommendation:** Include in release mode but in settings, not main screen. Label as "Export diagnostic log" or similar.

## Required Changes

### 1. Add DevMode State

```swift
class AppSettings: ObservableObject {
    @Published var devModeEnabled: Bool = false

    var showDevFeatures: Bool {
        #if DEBUG
        return devModeEnabled
        #else
        return false
        #endif
    }
}
```

### 2. Conditional UI Rendering

```swift
struct ContentView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack {
            SyncButton()

            if settings.showDevFeatures {
                DryRunButton()
                DebugLogView()
            }
        }
    }
}
```

### 3. Dev Mode Toggle (Debug Builds Only)

```swift
#if DEBUG
Toggle("Developer Mode", isOn: $settings.devModeEnabled)
#endif
```

### 4. Build Configurations

- `DEBUG` - Development builds
- `BETA` - TestFlight builds (optional dev mode)
- `RELEASE` - App Store builds (no dev mode)

## Acceptance Criteria

- [ ] Dev mode toggle visible in debug builds
- [ ] Dry run button hidden in release mode
- [ ] Background sync debug output hidden in release mode
- [ ] 1-minute sync interval only available in dev mode
- [ ] Download sync log accessible in release mode (settings)
- [ ] App Store build has no way to access dev features
- [ ] Can easily test both modes during development

## Related

- Issue 012: Background Sync (1-min interval is dev-only)
- Issue 014: UI Polish (overall layout)
