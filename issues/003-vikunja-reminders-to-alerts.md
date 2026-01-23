# Issue 003: Vikunja reminders not syncing to Reminders alerts

**Severity:** Medium
**Status:** Open
**Reported:** 2026-01-23

## Problem

Vikunja reminder times don't create alerts in Apple Reminders:

**Vikunja → Reminders:**
- Vikunja task with `reminders: [{reminder: "2026-01-24T09:00:00Z"}]`
- Apple Reminders: no alert set

## Root Cause

**Alarms added before first EventKit save may not persist.**

The code correctly:
1. Parses Vikunja reminders into CommonAlarm objects
2. Converts CommonAlarm to EKAlarm with correct dates

But in `createReminder()`, alarms are added to a new EKReminder before the first `store.save()` call. EventKit may silently discard these alarms.

## Analysis

### Parsing (WORKS)

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 412-417)

```swift
let alarms: [CommonAlarm] = ($0.reminders ?? []).map { reminder in
    if let abs = reminder.reminder {
        return CommonAlarm(type: "absolute", absolute: abs, ...)
    }
    return CommonAlarm(type: "relative", ...)
}
```

### EKAlarm Creation (WORKS)

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 1283-1291)

```swift
if alarm.type == "absolute", let abs = alarm.absolute, let date = parseISODate(abs) {
    reminder.addAlarm(EKAlarm(absoluteDate: date))
}
```

### The Bug (lines 1266-1305)

```swift
func createReminder(from task: CommonTask) throws -> (String, Bool) {
    let reminder = EKReminder(eventStore: store)
    // ... set properties ...

    // Alarms added here (before save)
    for alarm in task.alarms {
        reminder.addAlarm(EKAlarm(absoluteDate: date))
    }

    // Save happens AFTER adding alarms
    try store.save(reminder, commit: true)  // Alarms may not persist!
}
```

## Required Changes

### Fix createReminder() function

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 1266-1305)
**Also:** `scripts/mvp_sync.swift` (lines 1054-1093)

Save the reminder first, re-fetch it, then add alarms:

```swift
func createReminder(from task: CommonTask) throws -> (String, Bool) {
    let reminder = EKReminder(eventStore: store)
    reminder.calendar = calendar
    reminder.title = task.title
    reminder.isCompleted = task.isCompleted
    // ... set dates ...

    // Save FIRST (without alarms)
    try store.save(reminder, commit: true)
    let reminderId = reminder.calendarItemIdentifier

    // Re-fetch the saved reminder
    guard let savedReminder = store.calendarItem(withIdentifier: reminderId) as? EKReminder else {
        throw SyncError.reminderNotFound
    }

    // NOW add alarms to the persisted reminder
    if !task.alarms.isEmpty {
        for alarm in task.alarms {
            if alarm.type == "absolute", let abs = alarm.absolute, let date = parseISODate(abs) {
                savedReminder.addAlarm(EKAlarm(absoluteDate: date))
            } else if alarm.type == "relative", let offset = alarm.relativeSeconds {
                savedReminder.addAlarm(EKAlarm(relativeOffset: TimeInterval(offset)))
            }
        }
        // Save again with alarms
        try store.save(savedReminder, commit: true)
    }

    return (reminderId, inferredDue)
}
```

### Consider same pattern for updateReminder()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 1307-1353)

The update function already works with an existing reminder, so it may work correctly. However, applying the same save-fetch-modify-save pattern would be safer.

## Testing Strategy

After fix, verify:
1. Vikunja task with absolute reminder creates EKAlarm
2. Vikunja task with multiple reminders creates multiple EKAlarms
3. Round-trip preserves alarm times
4. Tasks without due dates can still have absolute alarms

## Acceptance Criteria

- [ ] Vikunja absolute reminder times create EKAlarm at same time
- [ ] Multiple reminders on a single task all sync
- [ ] Relative reminders create relative EKAlarms
- [ ] Round-trip preserves reminder/alarm times
