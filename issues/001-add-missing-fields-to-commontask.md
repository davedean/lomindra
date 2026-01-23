# Issue 001: Add missing fields to CommonTask (priority, notes, flags, completedAt)

**Severity:** Medium-High
**Status:** Complete (3/4 fields; flagged blocked by API limitation)
**Reported:** 2026-01-23
**Resolved:** 2026-01-23

## Progress

| Field | Reminders | Vikunja | Status |
|-------|-----------|---------|--------|
| **Priority** | `EKReminder.priority` (0/1/5/9) | `Task.priority` (0-5) | ✅ Complete |
| **Notes** | `EKReminder.notes` | `Task.description` | ✅ Complete |
| **Flags** | N/A | `Task.is_favorite` | ⚠️ API Limitation (see below) |
| **Completed At** | `EKReminder.completionDate` | `Task.done_at` | ✅ Complete |

## API Limitation: Flagged Status

**The "flagged" feature in Apple Reminders is NOT exposed via the EventKit API.**

Verified by checking macOS SDK headers - no `isFlagged` property exists on `EKReminder` or `EKCalendarItem`. The Reminders app "Flagged" smart list is an internal feature not accessible to third-party apps.

**Current behavior:**
- Vikunja `is_favorite` → Reminders: Value is ignored (cannot set flag)
- Reminders → Vikunja `is_favorite`: Always syncs as `false`

This is an Apple API limitation, not a bug in the sync implementation.

## Original Problem

Four core fields were completely missing from `CommonTask`, causing data loss in both sync directions.

## Root Cause

The `CommonTask` struct is missing these fields entirely. Without them in the neutral schema, there's no way to carry the data between systems.

**Current CommonTask** (`Sources/VikunjaSyncLib/SyncLib.swift` lines 25-53):
```swift
public struct CommonTask {
    public let source: String
    public let id: String
    public let listId: String
    public let title: String
    public let isCompleted: Bool
    public let due: String?
    public let start: String?
    public let updatedAt: String?
    public let alarms: [CommonAlarm]
    public let recurrence: CommonRecurrence?
    public let dueIsDateOnly: Bool?
    public let startIsDateOnly: Bool?
    // MISSING: priority, notes, isFlagged, completedAt
}
```

## Required Changes

### 1. Extend CommonTask struct

**File:** `Sources/VikunjaSyncLib/SyncLib.swift` (lines 25-53)

```swift
public struct CommonTask {
    // ... existing fields ...
    public let priority: Int?
    public let notes: String?
    public let isFlagged: Bool
    public let completedAt: String?  // ISO timestamp
}
```

Update initializer to include all four new parameters.

### 2. Add priority mapping functions

**File:** `Sources/VikunjaSyncLib/SyncLib.swift` (after line 234)

```swift
// MARK: - Priority Mapping

/// Convert Reminders priority (0/1/5/9) to Vikunja priority (0-3)
public func remindersPriorityToVikunja(_ priority: Int?) -> Int {
    guard let p = priority else { return 0 }
    switch p {
    case 1: return 3      // high
    case 5: return 2      // medium
    case 9: return 1      // low
    default: return 0     // none
    }
}

/// Convert Vikunja priority (0-5) to Reminders priority (0/1/5/9)
public func vikunjaPriorityToReminders(_ priority: Int?) -> Int {
    guard let p = priority else { return 0 }
    switch p {
    case 0: return 0      // none
    case 1: return 9      // low
    case 2: return 5      // medium
    case 3...: return 1   // high (3, 4, 5 all map to high)
    default: return 0
    }
}
```

### 3. Extend VikunjaTask struct

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 222-232)

```swift
struct VikunjaTask: Decodable {
    let id: Int
    let title: String
    let done: Bool?
    let done_at: String?      // ADD
    let due_date: String?
    let start_date: String?
    let updated: String?
    let reminders: [VikunjaReminder]?
    let repeat_after: Int?
    let repeat_mode: Int?
    let priority: Int?        // ADD
    let description: String?  // ADD
    let is_favorite: Bool?    // ADD
}
```

### 4. Update fetchReminders()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 192-205)

```swift
return CommonTask(
    source: "reminders",
    id: reminder.calendarItemIdentifier,
    listId: calendar.calendarIdentifier,
    title: reminder.title ?? "(untitled)",
    isCompleted: reminder.isCompleted,
    due: dateComponentsToISO(reminder.dueDateComponents),
    start: dateComponentsToISO(reminder.startDateComponents),
    updatedAt: isoDate(reminder.lastModifiedDate),
    alarms: alarms,
    recurrence: recurrence,
    dueIsDateOnly: dateComponentsIsDateOnly(reminder.dueDateComponents),
    startIsDateOnly: dateComponentsIsDateOnly(reminder.startDateComponents),
    priority: reminder.priority,           // ADD
    notes: reminder.notes,                 // ADD
    isFlagged: reminder.isFlagged,         // ADD
    completedAt: isoDate(reminder.completionDate)  // ADD
)
```

### 5. Update fetchVikunjaTasks()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 430-443)

```swift
return CommonTask(
    source: "vikunja",
    id: String($0.id),
    listId: String(projectId),
    title: $0.title,
    isCompleted: $0.done ?? false,
    due: $0.due_date,
    start: $0.start_date,
    updatedAt: $0.updated,
    alarms: alarms,
    recurrence: recurrence,
    dueIsDateOnly: isDateOnlyString($0.due_date),
    startIsDateOnly: isDateOnlyString($0.start_date),
    priority: vikunjaPriorityToReminders($0.priority),  // ADD (convert to Reminders scale)
    notes: $0.description,                               // ADD
    isFlagged: $0.is_favorite ?? false,                  // ADD
    completedAt: $0.done_at                              // ADD
)
```

### 6. Update createVikunjaTask()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 1165-1206)

Add to payload:
```swift
payload["priority"] = remindersPriorityToVikunja(task.priority)
payload["description"] = task.notes ?? ""
payload["is_favorite"] = task.isFlagged
if let completedAt = task.completedAt {
    payload["done_at"] = completedAt
}
```

### 7. Update updateVikunjaTask()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 1208-1251)

Add to payload:
```swift
payload["priority"] = remindersPriorityToVikunja(task.priority)
payload["description"] = task.notes ?? ""
payload["is_favorite"] = task.isFlagged
if let completedAt = task.completedAt {
    payload["done_at"] = completedAt
} else {
    payload["done_at"] = NSNull()  // Clear if task uncompleted
}
```

### 8. Update createReminder()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 1266-1305)

Add after setting other properties:
```swift
reminder.priority = task.priority ?? 0
reminder.notes = task.notes
reminder.isFlagged = task.isFlagged
// completionDate is typically auto-set when isCompleted = true
// but we can set it explicitly if we have a specific timestamp
if task.isCompleted, let completedAt = task.completedAt, let date = parseISODate(completedAt) {
    reminder.completionDate = date
}
```

### 9. Update updateReminder()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 1307+)

Add after setting other properties:
```swift
item.priority = task.priority ?? 0
item.notes = task.notes
item.isFlagged = task.isFlagged
if task.isCompleted, let completedAt = task.completedAt, let date = parseISODate(completedAt) {
    item.completionDate = date
} else if !task.isCompleted {
    item.completionDate = nil
}
```

### 10. Update diff detection

**File:** `Sources/VikunjaSyncLib/SyncLib.swift`

**In `tasksDiffer()` (lines 393-400):**
```swift
func tasksDiffer(_ left: CommonTask, _ right: CommonTask, ignoreDue: Bool = false) -> Bool {
    let sameTitle = left.title.caseInsensitiveCompare(right.title) == .orderedSame
    let sameDone = left.isCompleted == right.isCompleted
    let sameDue = ignoreDue || normalizeDueForMatch(left.due) == normalizeDueForMatch(right.due)
    let sameAlarms = alarmComparableSet(task: left) == alarmComparableSet(task: right)
    let sameRecurrence = recurrenceSignature(left.recurrence) == recurrenceSignature(right.recurrence)
    let samePriority = (left.priority ?? 0) == (right.priority ?? 0)  // ADD
    let sameNotes = left.notes == right.notes                          // ADD
    let sameFlagged = left.isFlagged == right.isFlagged                // ADD
    return !(sameTitle && sameDone && sameDue && sameAlarms && sameRecurrence
             && samePriority && sameNotes && sameFlagged)
}
```

**In `conflictFieldDiffs()` (lines 370-389):**
```swift
addDiff(field: "priority", reminders: String(reminders.priority ?? 0), vikunja: String(vikunja.priority ?? 0))
addDiff(field: "notes", reminders: reminders.notes ?? "", vikunja: vikunja.notes ?? "")
addDiff(field: "flagged", reminders: String(reminders.isFlagged), vikunja: String(vikunja.isFlagged))
```

### 11. Update test helpers

**File:** `Tests/VikunjaSyncLibTests/SyncLibTests.swift` (lines 8-35)

```swift
func makeTask(
    source: String = "reminders",
    id: String = "test-id",
    title: String = "Test Task",
    isCompleted: Bool = false,
    due: String? = nil,
    start: String? = nil,
    updatedAt: String? = nil,
    alarms: [CommonAlarm] = [],
    recurrence: CommonRecurrence? = nil,
    dueIsDateOnly: Bool? = nil,
    startIsDateOnly: Bool? = nil,
    priority: Int? = nil,       // ADD
    notes: String? = nil,       // ADD
    isFlagged: Bool = false,    // ADD
    completedAt: String? = nil  // ADD
) -> CommonTask {
    return CommonTask(
        source: source,
        id: id,
        listId: "list",
        title: title,
        isCompleted: isCompleted,
        due: due,
        start: start,
        updatedAt: updatedAt,
        alarms: alarms,
        recurrence: recurrence,
        dueIsDateOnly: dueIsDateOnly,
        startIsDateOnly: startIsDateOnly,
        priority: priority,
        notes: notes,
        isFlagged: isFlagged,
        completedAt: completedAt
    )
}
```

### 12. Add unit tests

**File:** `Tests/VikunjaSyncLibTests/SyncLibTests.swift`

```swift
// MARK: - Priority Mapping Tests

func testRemindersPriorityToVikunja() {
    XCTAssertEqual(remindersPriorityToVikunja(1), 3)   // high
    XCTAssertEqual(remindersPriorityToVikunja(5), 2)   // medium
    XCTAssertEqual(remindersPriorityToVikunja(9), 1)   // low
    XCTAssertEqual(remindersPriorityToVikunja(0), 0)   // none
    XCTAssertEqual(remindersPriorityToVikunja(nil), 0) // nil
}

func testVikunjaPriorityToReminders() {
    XCTAssertEqual(vikunjaPriorityToReminders(0), 0)   // none
    XCTAssertEqual(vikunjaPriorityToReminders(1), 9)   // low
    XCTAssertEqual(vikunjaPriorityToReminders(2), 5)   // medium
    XCTAssertEqual(vikunjaPriorityToReminders(3), 1)   // high
    XCTAssertEqual(vikunjaPriorityToReminders(5), 1)   // high (clamped)
    XCTAssertEqual(vikunjaPriorityToReminders(nil), 0) // nil
}

// MARK: - Diff Detection Tests

func testTasksDifferDetectsPriorityChange() {
    let task1 = makeTask(priority: 1)
    let task2 = makeTask(priority: 5)
    XCTAssertTrue(tasksDiffer(task1, task2))
}

func testTasksDifferDetectsNotesChange() {
    let task1 = makeTask(notes: "Original notes")
    let task2 = makeTask(notes: "Updated notes")
    XCTAssertTrue(tasksDiffer(task1, task2))
}

func testTasksDifferDetectsFlagChange() {
    let task1 = makeTask(isFlagged: false)
    let task2 = makeTask(isFlagged: true)
    XCTAssertTrue(tasksDiffer(task1, task2))
}

func testTasksDifferReturnsFalseWhenAllFieldsMatch() {
    let task1 = makeTask(priority: 1, notes: "Test", isFlagged: true)
    let task2 = makeTask(priority: 1, notes: "Test", isFlagged: true)
    XCTAssertFalse(tasksDiffer(task1, task2))
}
```

## Field Mapping Reference

### Priority

| Reminders | Vikunja | Meaning |
|-----------|---------|---------|
| 0         | 0       | None    |
| 9         | 1       | Low     |
| 5         | 2       | Medium  |
| 1         | 3+      | High    |

### Notes

Direct mapping:
- `EKReminder.notes` ↔ `Task.description`

### Flags

Direct boolean mapping:
- `EKReminder.isFlagged` ↔ `Task.is_favorite`

## Files Summary

| File | Changes |
|------|---------|
| `Sources/VikunjaSyncLib/SyncLib.swift` | Add fields to CommonTask, priority mapping funcs, diff detection |
| `Sources/VikunjaSyncLib/SyncRunner.swift` | Extend VikunjaTask, update fetch/create/update functions |
| `Tests/VikunjaSyncLibTests/SyncLibTests.swift` | Update makeTask(), add tests |
| `docs/translation-rules.md` | Document all three mappings |

## Acceptance Criteria

### Priority
- [ ] Vikunja high priority (3+) syncs to Reminders priority 1
- [ ] Vikunja medium priority (2) syncs to Reminders priority 5
- [ ] Vikunja low priority (1) syncs to Reminders priority 9
- [ ] Reminders priority 1 syncs to Vikunja priority 3
- [ ] Reminders priority 5 syncs to Vikunja priority 2
- [ ] Reminders priority 9 syncs to Vikunja priority 1
- [ ] Round-trip preserves priority

### Notes
- [ ] Vikunja description syncs to Reminders notes
- [ ] Reminders notes sync to Vikunja description
- [ ] Multiline content preserved
- [ ] Empty notes handled gracefully

### Flags
- [ ] Flagged reminders sync to Vikunja as favorited
- [ ] Favorited Vikunja tasks sync to Reminders as flagged
- [ ] Round-trip preserves flag state

### Completed At
- [ ] Reminders completionDate syncs to Vikunja done_at
- [ ] Vikunja done_at syncs to Reminders completionDate
- [ ] Uncompleting a task clears completedAt in both systems
- [ ] Round-trip preserves completion timestamp

### General
- [ ] All unit tests pass
- [ ] Changes trigger sync updates when fields differ
- [ ] Conflict detection includes all four fields
