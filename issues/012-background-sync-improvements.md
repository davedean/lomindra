# Issue 012: Background Sync Improvements

**Severity:** High (core functionality)
**Status:** Open
**Reported:** 2026-01-23

## Summary

Background sync needs better testing, configurable frequency, and reliability verification. The goal is "set and forget" - users should never need to open the app once configured.

## Current State

Background sync exists but:
- Not fully tested/verified to work reliably
- Fixed frequency (not configurable)
- No easy way to test different intervals
- Unclear what happens on failures

## Goals

1. **Verify it works** - Confirm background sync actually triggers and completes successfully
2. **Configurable frequency** - Allow users to choose sync interval
3. **Reliability** - Handle edge cases (network failures, app suspension, etc.)
4. **Invisible operation** - Users forget the app exists because it just works

## Frequency Configuration

### User-Facing Options

Suggested presets:
- Every 15 minutes (battery-intensive, for power users)
- Every 30 minutes (balanced)
- Every hour (recommended default)
- Every 2 hours (battery saver)
- Manual only (disable background sync)

### Testing Mode

For development/testing, allow arbitrary intervals:
- "Every 1 minute" (dev testing only, not in release UI)
- Custom interval input (dev mode)

### Implementation Considerations

**macOS LaunchAgent:**
- `StartInterval` controls frequency
- Can be modified programmatically
- Need to unload/reload agent for changes to take effect

**iOS Background App Refresh:**
- iOS controls actual timing (not guaranteed)
- `BGAppRefreshTaskRequest` with `earliestBeginDate`
- System may delay based on battery, usage patterns
- Less predictable than macOS

## Testing Plan

### Manual Testing

1. Set frequency to 1 minute (dev mode)
2. Make a change in Reminders
3. Wait for sync interval
4. Verify change appears in Vikunja
5. Repeat in reverse direction

### Automated Testing

- Log all background sync attempts with timestamps
- Record success/failure/skip (no changes) status
- Surface this in dev mode UI
- Alert on repeated failures

### Edge Cases to Test

- [ ] App suspended mid-sync
- [ ] Network unavailable during scheduled sync
- [ ] Vikunja server unreachable
- [ ] Conflicting changes during sync
- [ ] Very large sync (many changes)
- [ ] System sleep/wake cycles
- [ ] After system restart
- [ ] After app update

## Sync Frequency Expectations

### User Expectations vs Reality

Users may expect "instant" sync like iCloud. Reality:
- **Periodic polling** is the only option without server-side push support
- **15-minute minimum** is reasonable for battery/network balance
- **Manual sync button** available for "I need it NOW" moments

## Research: Real-Time Sync Feasibility

### Direction 1: Vikunja → Client (Webhooks)

**Finding: Vikunja HAS webhooks** (since v0.22.0)

Available events:
- `task.created`
- `task.updated`
- `task.deleted`
- `task.assigned`
- And more per-project events

Configuration:
- Per-project (not global)
- JSON payload: `{"event_name": "...", "time": "ISO8601", "data": {...}}`
- HMAC signing available (`X-Vikunja-Signature` header)

**The catch:** Webhooks push to a URL endpoint. For a client app, we'd need:

```
Vikunja change → Webhook → Relay server → Apple Push Notification → App wakes → Sync
```

This requires infrastructure we don't currently have:
1. A server to receive webhook callbacks (per-user registration)
2. Apple Push Notification Service (APNS) integration
3. Ongoing server costs and maintenance

**Options for power users (self-hosted):**
- Point webhooks at a local service (Shortcuts, Hazel, script)
- That service could trigger our app via URL scheme or AppleScript

**Future possibility:**
- If we ever run a relay service, could receive webhooks and push to users
- Vikunja Cloud users would benefit most from this

Sources:
- https://vikunja.io/docs/webhooks/
- https://community.vikunja.io/t/webhook-issue-notifying-on-task-updated/2617

---

### Direction 2: Reminders → Vikunja (iOS Limitations)

**This is the harder direction, and probably the more common use case** (user edits reminder on phone while out and about).

**The problem:** We don't control Apple's infrastructure. When a Reminder changes, how does our app know?

**Available iOS mechanisms:**

| Mechanism | How it works | Limitations |
|-----------|--------------|-------------|
| `EKEventStoreChangedNotification` | Fires when EventKit data changes | App must be running/backgrounded to receive |
| Background App Refresh | iOS wakes app periodically | iOS controls timing (15-30min+), unreliable, battery-optimized |
| On app foreground | Sync when user opens app | Requires user action |
| Manual sync | User taps button | Requires user action |

**Hard truth:** iOS is very restrictive about background execution. There's NO way to get instant notification that a Reminder changed. Apple doesn't expose push notifications for Reminders changes to third-party apps.

**What this means:**

```
User edits Reminder on phone
         ↓
   [iOS black box - we have no control here]
         ↓
Our app eventually wakes (iOS decides when, or user opens app)
         ↓
Sync to Vikunja
```

Changes made on phone while out won't reach Vikunja until:
- iOS decides to grant us background execution (unpredictable)
- User opens our sync app
- User returns to Mac (if macOS sync runs more reliably)

**macOS is better:** LaunchAgent runs reliably on schedule. The Mac can be the "anchor" that catches up phone changes.

**Possible iOS improvements (research needed):**

1. **`EKEventStoreChangedNotification` + background modes** - Can we stay alive longer to catch changes?

2. **Significant location change** - Wake app on location change, opportunistically sync (hacky, battery impact)

3. **Silent push from our server** - If we had server infrastructure, could periodically wake the app (but still need server)

4. **Shortcuts/Automation** - User creates "When I leave home, run Vikunja Sync" automation (user setup required)

5. **Watch complication** - watchOS apps can have more background time (complex)

---

### Pragmatic Approach

For MVP:
1. Reliable periodic sync (30min-1hr default)
2. Sync on app launch (when user does open it)
3. Manual sync button for immediate needs
4. Clear messaging: "Syncs automatically every X minutes"

## Required Changes

### 1. Frequency Configuration Storage

Store selected frequency in:
- macOS: UserDefaults or config file
- iOS: UserDefaults

### 2. LaunchAgent Modification (macOS)

```swift
func updateSyncFrequency(minutes: Int) {
    // 1. Unload current LaunchAgent
    // 2. Modify plist StartInterval
    // 3. Reload LaunchAgent
}
```

### 3. UI for Frequency Selection

- Dropdown/picker with preset options
- Show current setting
- "Apply" triggers LaunchAgent reload

### 4. Sync Logging

```swift
struct SyncLogEntry {
    let timestamp: Date
    let trigger: SyncTrigger  // .background, .manual, .appLaunch
    let result: SyncResult    // .success(changes: Int), .noChanges, .failure(Error)
    let duration: TimeInterval
}
```

### 5. Failure Handling

- Retry with exponential backoff on transient failures
- Notification after N consecutive failures (optional)
- Don't retry on auth failures (requires user action)

## Acceptance Criteria

- [ ] Frequency configurable via UI
- [ ] Changes take effect without app restart
- [ ] Background sync verified working at configured interval
- [ ] Sync log captures all background sync attempts
- [ ] Failures handled gracefully with retry
- [ ] Dev mode allows 1-minute intervals for testing
- [ ] Release mode limits to reasonable intervals (15min+)

## Related

- Issue 013: Dev Mode vs Release Mode (frequency limits)
- Issue 014: UI Polish (frequency selector placement)
