# Reminders ↔ Vikunja Sync Tool Issues

Tested: 2026-01-23

## Summary

Round-trip sync preserves data that exists only on one side (good!), but several fields don't sync in either direction.

---

## Issue 1: Priority not syncing (either direction)

**Severity:** Medium

**Vikunja → Reminders:**
- Vikunja `priority: 5` → Reminders `priority: 0`
- Priority completely lost

**Reminders → Vikunja:**
- Reminders `priority: 1` (high) → Vikunja `priority: 0`
- Reminders `priority: 5` (medium) → Vikunja `priority: 0`
- Priority completely lost

**Expected:** Map between scales:
- Vikunja: 0 (none), 1-5 (low to high)
- Reminders: 0 (none), 1 (high), 5 (medium), 9 (low)

Suggested mapping:
| Vikunja | Reminders |
|---------|-----------|
| 0 | 0 |
| 1-2 | 9 (low) |
| 3 | 5 (medium) |
| 4-5 | 1 (high) |

---

## Issue 2: Notes/description not syncing (either direction)

**Severity:** Medium-High

**Vikunja → Reminders:**
- Task with `description: "multiline text..."` → Reminders has no notes field visible
- (May need to verify in Reminders UI - CLI might not show notes)

**Reminders → Vikunja:**
- Reminders with `notes: "multiline text..."` → Vikunja `description: ""`
- Notes completely lost

**Expected:** Bidirectional sync of notes ↔ description

---

## Issue 3: Reminders/alerts not syncing (Vikunja → Reminders)

**Severity:** Medium

**Vikunja → Reminders:**
- Vikunja task with `reminders: [{reminder: "2026-01-24T09:00:00Z"}]`
- Reminders: no alert set

**Reminders → Vikunja:**
- Partially works: tasks with due dates get a reminder created at due_date time
- This may be intentional (Reminders fires at due time by default)

**Expected:** Vikunja explicit reminders should create Reminders alerts

---

## Issue 4: Recurrence not syncing (either direction)

**Severity:** Medium

**Vikunja → Reminders:**
- Vikunja `repeat_after: 86400` (daily) → Reminders: no recurrence
- Recurrence rule lost

**Reminders → Vikunja:**
- Not tested (couldn't easily create recurring reminder via CLI)

**Expected:** Map recurrence rules between systems

---

## Issue 5: Spurious start_date added (Vikunja → Reminders)

**Severity:** Low

**Observed:**
- Vikunja task with only `due_date: "2026-01-25T17:00:00Z"`
- Reminders: `dueDate` AND `startDate` both set to same value

**Impact:** Minor - may cause visual noise in Reminders UI

**Expected:** Only set startDate when Vikunja has explicit start_date

---

## Issue 6: Completed tasks not synced (Vikunja → Reminders)

**Severity:** Low (probably intentional)

**Observed:**
- Vikunja task with `done: true` not synced to Reminders

**This is probably correct behavior** - no need to sync completed tasks. Documenting for completeness.

---

## Test Data Reference

**Project:** "Sync Test Jan26" (Vikunja ID: 42)

**Original Vikunja tasks (IDs 3824-3832):**
- Simple task - title only
- Task with due date (2026-01-25T17:00:00Z)
- High priority task (priority: 5)
- Task with notes (multiline description)
- Task with reminder (2026-01-24T09:00:00Z)
- Already completed task (done: true)
- Recurring daily task (repeat_after: 86400)
- Task with start and end date
- All-day task (due date at midnight)

**Test Reminders created (IDs 3833-3837 in Vikunja after sync):**
- R: Simple reminder
- R: With due date
- R: High priority (priority: 1)
- R: With notes (multiline)
- R: Priority and due (priority: 5, with due date)

---

## Positive Findings

1. **Round-trip doesn't overwrite Vikunja data** - Original Vikunja fields (priority, description, reminders, repeat_after) are preserved in the Vikunja database after sync. However, this is cold comfort if you're using Reminders as your primary UI - you won't see those fields since they never sync to Reminders in the first place.

2. **Title sync works perfectly** - No issues with task titles.

3. **Due date sync works** - Dates transfer correctly (timezone handling appears correct).

4. **Start + end date combo works** - When both are set, both sync correctly.
