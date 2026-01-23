# Issue 014: UI Polish and Settings Reorganization

**Severity:** Medium (UX)
**Status:** Open
**Reported:** 2026-01-23

## Summary

Reorganize UI for better user experience. Move configuration to settings, simplify main screen, add background sync controls prominently.

## Current State

UI has grown organically during development. Needs restructuring for end users.

## Proposed Layout

### Main Screen (Release Mode)

Clean and focused:

```
┌─────────────────────────────────────────┐
│  Vikunja Sync                     ⚙️    │
├─────────────────────────────────────────┤
│                                         │
│         [🔄 Sync Now]                   │
│                                         │
│  Last sync: 5 minutes ago               │
│  Status: ✅ 3 changes synced            │
│                                         │
├─────────────────────────────────────────┤
│  Background Sync                        │
│  ┌─────────────────────────────────┐    │
│  │ ☑ Enable automatic sync         │    │
│  │                                 │    │
│  │ Frequency: [Every 30 minutes ▼] │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Next sync: in 25 minutes               │
│                                         │
└─────────────────────────────────────────┘
```

### Settings Screen (⚙️)

All configuration in one place:

```
┌─────────────────────────────────────────┐
│  ← Settings                             │
├─────────────────────────────────────────┤
│                                         │
│  LISTS TO SYNC                          │
│  ┌─────────────────────────────────┐    │
│  │ ☑ Shopping                      │    │
│  │ ☑ Work Tasks                    │    │
│  │ ☐ Personal (not synced)         │    │
│  │ ☐ Someday Maybe                 │    │
│  └─────────────────────────────────┘    │
│  [Refresh Lists]                        │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  VIKUNJA CONNECTION                     │
│  ☑ Use Vikunja Cloud                    │
│  Status: ✅ Connected as @david         │
│  [Disconnect] [Test Connection]         │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  ADVANCED                               │
│  • Export diagnostic log                │
│  • About / Version info                 │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  #if DEBUG                              │
│  DEVELOPER                              │
│  ☐ Enable dev mode                      │
│  #endif                                 │
│                                         │
└─────────────────────────────────────────┘
```

### Main Screen (Dev Mode Additions)

When dev mode enabled, add:

```
┌─────────────────────────────────────────┐
│  ... (normal main screen) ...           │
├─────────────────────────────────────────┤
│  DEVELOPER TOOLS                        │
│  [Dry Run]  [View Sync Log]             │
│                                         │
│  Background Sync Debug:                 │
│  ┌─────────────────────────────────┐    │
│  │ 14:23:01 - Sync triggered       │    │
│  │ 14:23:02 - Fetched 45 reminders │    │
│  │ 14:23:03 - Fetched 42 tasks     │    │
│  │ 14:23:04 - 3 changes detected   │    │
│  │ 14:23:05 - Sync complete ✅     │    │
│  └─────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

## Specific Changes

### 1. Move "Select Lists" to Settings

Currently on main screen → Move to settings cog.

**Rationale:** Users set this once, rarely change it. Doesn't need main screen real estate.

### 2. Background Sync Controls on Main Screen

Make prominent:
- Enable/disable toggle
- Frequency dropdown
- "Next sync in X minutes" indicator

**Rationale:** This is core functionality users care about.

### 3. Hide Debug Output (Release Mode)

Background sync log/debug output → Dev mode only.

**Rationale:** Users don't need to see internal operations.

### 4. Sync Status Improvements

Current: Basic "last sync" text
Improved:
- Relative time ("5 minutes ago")
- Change count ("3 changes synced")
- Error state with actionable message
- "Syncing..." state with progress

### 5. Settings Cog Placement

Top-right corner, standard iOS/macOS convention.

### 6. Connection Status

Show in settings:
- Connected/disconnected state
- Username (confirms right account)
- Test connection button
- Easy disconnect/reconnect

## Additional Polish Ideas

### Sync Animation
- Subtle rotation on sync button while syncing
- Checkmark animation on success

### Empty State
- First-run experience: "Connect to Vikunja to get started"
- Guide users through setup

### Error States
- Network error: "Couldn't connect. Check your internet."
- Auth error: "Session expired. Please reconnect in settings."
- Conflict: "X conflicts found. [Review]"

### Notifications (Optional)
- "Sync failed" notification after N failures
- Success notifications (probably off by default, noisy)

### Menu Bar Item (macOS)
- Quick sync from menu bar
- Status indicator (green dot = recent sync, yellow = stale, red = error)
- Last sync time on hover

## Acceptance Criteria

- [ ] Main screen focused on sync action and status
- [ ] List selection moved to settings
- [ ] Background sync toggle and frequency on main screen
- [ ] Settings cog in standard location
- [ ] Debug output hidden in release mode
- [ ] Connection status visible in settings
- [ ] Sync status shows relative time and change count
- [ ] Consistent visual styling throughout

## Related

- Issue 011: Vikunja Cloud Onboarding (connection UI)
- Issue 012: Background Sync (frequency controls)
- Issue 013: Dev Mode (conditional UI)
