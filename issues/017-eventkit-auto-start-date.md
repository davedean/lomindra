# Issue 017: EventKit auto-populates startDateComponents

**Severity:** Low
**Status:** Open
**Reported:** 2026-01-28

## Problem

When creating a reminder with only a due date, EventKit automatically sets `startDateComponents` to match `dueDateComponents`. This causes spurious `start_date` values to appear in Vikunja for reminders that don't have an explicit start date.

**Observed behavior:**
```
// Set ONLY dueDateComponents
reminder.dueDateComponents = DateComponents(year: 2026, month: 1, day: 30)

// BEFORE SAVE - startDateComponents is ALREADY set!
dueDateComponents: year: 2026 month: 1 day: 30
startDateComponents: year: 2026 month: 1 day: 30  // Auto-populated!

// AFTER SAVE - startDateComponents gains time components
startDateComponents: year: 2026 month: 1 day: 30 hour: 0 minute: 0 second: 0
```

## Root Cause

This is **documented EventKit behavior**, not a bug in our code. Apple treats reminders as having a time range (start → due), and auto-populates start when you set due.

From Apple's documentation: the due date represents when the reminder should be completed, and the start date represents when it becomes relevant.

## Impact

When syncing Reminders → Vikunja:
1. User creates reminder with only due date
2. EventKit auto-adds startDateComponents
3. Sync sends both `due_date` and `start_date` to Vikunja
4. Vikunja shows a start date the user never set

This is confusing but not data-corrupting.

## Possible Fixes

### Option A: Don't sync start_date if it matches due_date

If `startDateComponents == dueDateComponents`, assume it was auto-populated and don't send `start_date` to Vikunja.

```swift
// In fetchReminders() or createVikunjaTask()
let shouldSyncStart = reminder.startDateComponents != nil
    && reminder.startDateComponents != reminder.dueDateComponents
```

**Pros:** Simple heuristic
**Cons:** False positive if user intentionally set start = due

### Option B: Track "user explicitly set start" in metadata

Store a flag indicating whether start_date was explicitly set vs auto-populated.

**Pros:** Accurate
**Cons:** Complex, requires metadata tracking

### Option C: Accept the behavior

Document that Reminders with due dates will have start dates in Vikunja. Users can ignore or clear the start_date in Vikunja if unwanted.

**Pros:** No code changes
**Cons:** Surprising UX

## Recommendation

**Option A** - don't sync start_date when it equals due_date. This matches user intent in most cases (they set a due date, not a time range).

## Test Case

```swift
// Create reminder with only due date
let reminder = EKReminder(eventStore: store)
reminder.dueDateComponents = DateComponents(year: 2026, month: 1, day: 30)
// Do NOT set startDateComponents

// Sync to Vikunja
// Expected: only due_date is set, start_date is null/omitted
// Current: both due_date and start_date are set to same value
```

## Related Issues

- Issue 005: Spurious start_date (Vikunja → Reminders direction, fixed)
- Issue 016: Date-only timezone drift (related date handling)

## References

- Apple EventKit documentation on EKReminder date components
- Probe script: `scripts/probe_start_date.swift` (in scratchpad)
