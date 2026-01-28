# Issue 016: Date-only reminders display wrong time after sync

**Severity:** Medium
**Status:** Resolved
**Reported:** 2026-01-28
**Resolved:** 2026-01-28

## Resolution

Fixed in two parts:

1. **`createReminder()` in SyncRunner.swift** (lines 1407, 1411): Now uses `task.dueIsDateOnly ?? isDateOnlyString(task.due)` instead of just `isDateOnlyString(task.due)`. This preserves date-only intent from the mapping metadata.

2. **`vikunjaDateString()` in SyncLib.swift** (line 263): Now uses local midnight (`T00:00:00+11:00` for Melbourne) instead of UTC midnight (`T00:00:00Z`). This ensures Vikunja displays the correct local date.

**Verification:** Integration test at `scripts/test_016_integration.swift` confirms date-only is preserved after round-trip.

## Problem

When a reminder is created in Apple Reminders with just a date (no time), it syncs to Vikunja as UTC midnight (`00:00:00Z`). On round-trip back to Reminders, the "date-only" intent is lost and the reminder shows a specific time (e.g., 11:00am in Melbourne).

**Reproduction steps:**
1. Create reminder in Apple Reminders with due date but no time
2. Sync to Vikunja - stores as `2026-01-27T00:00:00Z`
3. Sync back to Reminders
4. Reminder now shows "11:00am" instead of date-only

**Expected:** Date-only reminders should remain date-only after round-trip.

## Root Cause Analysis

### Vikunja API Limitation (Confirmed)

**Vikunja does not support date-only tasks.** This is a [known feature request](https://community.vikunja.io/t/set-due-date-without-time/3393) in the Vikunja community. All due dates require a time component.

### Code Bug #1: `fetchVikunjaTasks()` cannot detect date-only

In `SyncRunner.swift:451-452`:
```swift
dueIsDateOnly: isDateOnlyString($0.due_date),
startIsDateOnly: isDateOnlyString($0.start_date),
```

`isDateOnlyString()` checks if the string is exactly 10 characters (like `2026-01-27`). But Vikunja always returns full datetime strings like `2026-01-27T00:00:00Z`, so this **always returns `false`**.

This means `task.dueIsDateOnly` is always `false` for tasks fetched from Vikunja, even if they were originally date-only in Reminders.

### Code Bug #2: `createReminder()` ignores `dueIsDateOnly` property

In `SyncRunner.swift:1407` and `1411`:
```swift
if let due = dateComponentsFromISO(task.due, dateOnly: isDateOnlyString(task.due)) {
    reminder.dueDateComponents = due
}
if let start = dateComponentsFromISO(task.start, dateOnly: isDateOnlyString(task.start)) {
    reminder.startDateComponents = start
}
```

This recalculates `dateOnly` from the string instead of using `task.dueIsDateOnly`. Since the string is `2026-01-27T00:00:00Z` (not 10 chars), `isDateOnlyString()` returns `false`, and the time component is preserved.

### Working Code: `updateReminder()` does it correctly

In `SyncRunner.swift:1481` and `1486`:
```swift
if let due = dateComponentsFromISO(task.due, dateOnly: dateOnlyDue) {
    item.dueDateComponents = due
}
```

The `updateReminder()` function correctly receives `dateOnlyDue` from the mapping record. But for **new** tasks created from Vikunja, there's no mapping record yet.

## The Full Bug Flow

1. **Reminders → Vikunja (initial sync)**
   - Reminder has date-only due (no time components)
   - `dateComponentsToISO()` outputs `2026-01-27` (10 chars, date-only)
   - `vikunjaDateString()` converts to `2026-01-27T00:00:00Z` (UTC midnight)
   - Mapping record stores `dateOnlyDue = true` ✓

2. **Vikunja → Reminders (round-trip sync)**
   - `fetchVikunjaTasks()` gets `2026-01-27T00:00:00Z`
   - `isDateOnlyString("2026-01-27T00:00:00Z")` returns `false` (not 10 chars)
   - `task.dueIsDateOnly` is set to `false` ✗
   - Even though mapping record has `dateOnlyDue = true`, it's not used for diff comparison
   - Task appears "unchanged" or gets updated with wrong dateOnly flag

## Required Fixes

### Fix 1: Use mapping record's dateOnly flags in diff logic

When comparing tasks for updates, use the mapping record's `dateOnlyDue`/`dateOnlyStart` values, not the task's `dueIsDateOnly` property (which is unreliable for Vikunja tasks).

### Fix 2: Fix `createReminder()` to use `task.dueIsDateOnly`

```swift
// Before (broken)
if let due = dateComponentsFromISO(task.due, dateOnly: isDateOnlyString(task.due)) {

// After (fixed)
if let due = dateComponentsFromISO(task.due, dateOnly: task.dueIsDateOnly ?? isDateOnlyString(task.due)) {
```

### Fix 3: Store as local midnight instead of UTC midnight

In `vikunjaDateString()`, convert date-only to local midnight:

```swift
// Before: UTC midnight (causes timezone display issues)
return normalized + "T00:00:00Z"

// After: Local midnight (displays correctly in user's timezone)
let tz = TimeZone.current
let offsetSeconds = tz.secondsFromGMT()
let hours = abs(offsetSeconds) / 3600
let mins = (abs(offsetSeconds) % 3600) / 60
let sign = offsetSeconds >= 0 ? "+" : "-"
return normalized + String(format: "T00:00:00%@%02d:%02d", sign, hours, mins)
```

This ensures Vikunja displays the correct local date (00:00 Melbourne time shows as "midnight" not "11am").

### Fix 4 (Optional): Heuristic for Vikunja-originated tasks

For tasks that originated in Vikunja (no mapping record), detect `T00:00:00Z` as likely date-only:

```swift
func isLikelyDateOnly(_ dateString: String?) -> Bool {
    guard let s = dateString else { return false }
    return s.hasSuffix("T00:00:00Z") || s.hasSuffix("T00:00:00+00:00")
}
```

**Caveat:** This has false positives for legitimate midnight deadlines.

## Files to Modify

- `Sources/VikunjaSyncLib/SyncLib.swift`
  - `vikunjaDateString()` - use local midnight instead of UTC

- `Sources/VikunjaSyncLib/SyncRunner.swift`
  - `createReminder()` lines 1407, 1411 - use `task.dueIsDateOnly` property
  - Possibly `fetchVikunjaTasks()` - add heuristic for midnight detection

## Test Cases

1. **Round-trip preservation (main bug)**
   - Create date-only reminder in Reminders
   - Sync to Vikunja
   - Sync back to Reminders
   - Verify still date-only (no time badge)

2. **Vikunja display**
   - Create date-only reminder in Reminders
   - Sync to Vikunja
   - Verify Vikunja shows correct date at local midnight (not 11am for Melbourne)

3. **Update preserves dateOnly**
   - Create date-only reminder, sync both ways
   - Edit title in Vikunja
   - Sync to Reminders
   - Verify still date-only after update

4. **Timezone edge cases**
   - Date-only reminder near date boundary
   - Verify date doesn't shift across timezone

## References

- [Vikunja: Set due date without time](https://community.vikunja.io/t/set-due-date-without-time/3393) - Feature request, not implemented
- [Vikunja: Default due time configuration](https://community.vikunja.io/t/default-due-time-configuration/1253) - Related discussion
- Issue 005: Spurious start_date (similar date handling fix)
- `docs/translation-rules.md` - Date-Only Policy section
