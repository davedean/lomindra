# Issue 004: Recurrence not syncing (either direction)

**Severity:** Medium
**Status:** Resolved
**Reported:** 2026-01-23
**Resolved:** 2026-01-23

## Resolution

Fixed by extracting recurrence parsing into `parseVikunjaRecurrence()` function in `SyncLib.swift`. The function now defaults `repeat_mode` to 0 (time-based) when nil, allowing recurrence to be parsed correctly when Vikunja omits the field.

**Changes:**
- Added `parseVikunjaRecurrence(repeatAfter:repeatMode:)` to `Sources/VikunjaSyncLib/SyncLib.swift`
- Updated `SyncRunner.swift` to use the new function
- Added 8 unit tests covering all recurrence parsing scenarios

## Problem

Recurrence rules are lost in both sync directions:

**Vikunja → Reminders:**
- Vikunja `repeat_after: 86400` (daily, in seconds) → Reminders: no recurrence

**Reminders → Vikunja:**
- Likely also broken (same root cause)

## Root Cause

**Guard condition requires BOTH `repeat_after` AND `repeat_mode` to be non-nil.**

When Vikunja returns a task with `repeat_after: 86400`, it may return `repeat_mode: null`. The combined guard fails, so recurrence parsing is skipped entirely.

## Analysis

### The Bug

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 418-429)

```swift
if let repeatAfter = $0.repeat_after, let repeatMode = $0.repeat_mode {
    // This entire block is SKIPPED if repeat_mode is nil!
    if repeatMode == 1 {
        recurrence = CommonRecurrence(frequency: "monthly", interval: 1)
    } else if repeatMode == 0, repeatAfter > 0 {
        // ... daily/weekly parsing ...
    }
}
```

### What Works

The rest of the recurrence pipeline works correctly:

| Component | Status |
|-----------|--------|
| CommonRecurrence → EKRecurrenceRule | WORKS |
| EKRecurrenceRule → CommonRecurrence | WORKS |
| CommonRecurrence → Vikunja payload | WORKS |
| Recurrence diffing/comparison | WORKS |

Only the initial Vikunja parsing is broken.

## Required Changes

### Fix Vikunja parsing logic

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 418-429)

Allow `repeat_mode` to be nil and default to 0:

```swift
var recurrence: CommonRecurrence?
let repeatMode = $0.repeat_mode ?? 0  // Default to 0 if nil
if let repeatAfter = $0.repeat_after {
    if repeatMode == 1 {
        recurrence = CommonRecurrence(frequency: "monthly", interval: 1)
    } else if repeatMode == 0, repeatAfter > 0 {
        if repeatAfter % 604800 == 0 {
            recurrence = CommonRecurrence(frequency: "weekly", interval: repeatAfter / 604800)
        } else if repeatAfter % 86400 == 0 {
            recurrence = CommonRecurrence(frequency: "daily", interval: repeatAfter / 86400)
        }
    }
}
```

Alternative (handle each case separately):

```swift
var recurrence: CommonRecurrence?
if let repeatMode = $0.repeat_mode, repeatMode == 1 {
    recurrence = CommonRecurrence(frequency: "monthly", interval: 1)
} else if let repeatAfter = $0.repeat_after, repeatAfter > 0 {
    // No repeat_mode or repeat_mode == 0: assume time-based
    if repeatAfter % 604800 == 0 {
        recurrence = CommonRecurrence(frequency: "weekly", interval: repeatAfter / 604800)
    } else if repeatAfter % 86400 == 0 {
        recurrence = CommonRecurrence(frequency: "daily", interval: repeatAfter / 86400)
    }
}
```

## Vikunja repeat_mode Reference

| repeat_mode | Meaning |
|-------------|---------|
| 0 (or nil)  | Time-based: use `repeat_after` seconds |
| 1           | Monthly: ignore `repeat_after` |
| 2           | From completion date (skip for MVP) |

## Additional Gap: Recurrence End Conditions

**Good news:** Vikunja's `end_date` field IS the recurrence end date!

Verified via `vja show`:
```
id: 3978
title: this is a new task
repeat_after: 1 day, 0:00:00
end_date: Fri 2026-01-30 12:00:00
```

| Reminders | Vikunja | Status |
|-----------|---------|--------|
| `EKRecurrenceEnd.endDate` | `end_date` | **Direct mapping!** |

### Required Changes for Recurrence End

**Add to VikunjaTask struct:**
```swift
struct VikunjaTask: Decodable {
    // ... existing fields ...
    let end_date: String?  // Recurrence end date
}
```

**Add to CommonRecurrence:**
```swift
public struct CommonRecurrence {
    // ... existing fields ...
    public let endDate: String?  // ISO date when recurrence ends
}
```

**Extract in fetchReminders():**
```swift
if let end = rule.recurrenceEnd, let endDate = end.endDate {
    recurrence.endDate = isoDate(endDate)
}
```

**Extract in fetchVikunjaTasks():**
```swift
// end_date on a recurring task IS the recurrence end date
if let endDate = $0.end_date, recurrence != nil {
    recurrence?.endDate = endDate
}
```

**Send to Vikunja API (createVikunjaTask/updateVikunjaTask):**
```swift
if let recurrence = task.recurrence {
    // ... existing repeat_after/repeat_mode logic ...
    if let endDate = recurrence.endDate {
        payload["end_date"] = endDate
    }
}
```

**Restore in createReminder()/updateReminder():**
```swift
var recurrenceEnd: EKRecurrenceEnd? = nil
if let endDate = recurrence.endDate, let date = parseISODate(endDate) {
    recurrenceEnd = EKRecurrenceEnd(end: date)
} else if let count = recurrence.occurrenceCount {
    recurrenceEnd = EKRecurrenceEnd(occurrenceCount: count)
}

let rule = EKRecurrenceRule(
    recurrenceWith: frequency,
    interval: recurrence.interval,
    end: recurrenceEnd  // Pass the end condition
)
```

## Acceptance Criteria

### Basic Recurrence
- [ ] Vikunja `repeat_after: 86400` with `repeat_mode: null` → daily recurrence
- [ ] Vikunja `repeat_after: 86400` with `repeat_mode: 0` → daily recurrence
- [ ] Vikunja `repeat_mode: 1` → monthly recurrence
- [ ] Reminders daily repeat → Vikunja `repeat_after: 86400`
- [ ] Reminders weekly repeat → Vikunja `repeat_after: 604800`
- [ ] Round-trip preserves recurrence

### Recurrence End (if implementing)
- [ ] Reminders "repeat until date" preserved in sync metadata
- [ ] Reminders "repeat X times" preserved in sync metadata
- [ ] Round-trip restores end condition in Reminders
