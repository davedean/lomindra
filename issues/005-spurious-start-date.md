# Issue 005: Spurious start_date added on sync

**Severity:** Low
**Status:** Resolved
**Reported:** 2026-01-23
**Resolved:** 2026-01-23

## Resolution

Fixed by using explicit guarded assignments with nil clearing in `updateReminder()`. The unconditional assignment didn't properly clear dates when the source value was nil.

**Changes:**
- Updated `updateReminder()` in `Sources/VikunjaSyncLib/SyncRunner.swift`

## Problem

When syncing from Vikunja to Reminders, a start_date is incorrectly added:

**Observed:**
- Vikunja task with only `due_date: "2026-01-25T17:00:00Z"` (no start_date)
- After sync, Reminders has both `dueDate` AND `startDate` set to the same value

## Root Cause

**Unconditional assignment in `updateReminder()` function.**

In `createReminder()`, dates use guarded assignment:
```swift
if let due = dateComponentsFromISO(task.due, ...) {
    reminder.dueDateComponents = due
}
```

But in `updateReminder()`, dates are assigned unconditionally:
```swift
item.dueDateComponents = dateComponentsFromISO(task.due, ...)
item.startDateComponents = dateComponentsFromISO(task.start, ...)  // BUG
```

When `task.start` is nil, `dateComponentsFromISO` returns nil, but assigning nil to `startDateComponents` may not clear an existing value in EventKit.

## Required Changes

### Fix updateReminder() date assignments

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 1313-1314)

Replace unconditional assignments:

```swift
// Before (broken)
item.dueDateComponents = dateComponentsFromISO(task.due, dateOnly: dateOnlyDue)
item.startDateComponents = dateComponentsFromISO(task.start, dateOnly: dateOnlyStart)
```

With guarded assignments:

```swift
// After (fixed)
if let due = dateComponentsFromISO(task.due, dateOnly: dateOnlyDue) {
    item.dueDateComponents = due
} else {
    item.dueDateComponents = nil
}

if let start = dateComponentsFromISO(task.start, dateOnly: dateOnlyStart) {
    item.startDateComponents = start
} else {
    item.startDateComponents = nil
}
```

This matches the pattern already used in `createReminder()` which doesn't have the bug.

## Why This Happens

EventKit may not properly clear properties when assigned nil directly from a function return. The explicit `else { ... = nil }` branch ensures the property is explicitly cleared when there's no value.

## Acceptance Criteria

- [ ] Task with only due_date syncs with only dueDate in Reminders
- [ ] Task with both start_date and due_date syncs with both dates
- [ ] Updating a task to remove start_date clears startDate in Reminders
- [ ] No spurious date fields added during sync
