# Field Audit: What Should We Be Syncing?

**Created:** 2026-01-23
**Purpose:** Comprehensive comparison of Reminders vs Vikunja fields to identify gaps

## Legend

| Symbol | Meaning |
|--------|---------|
| :white_check_mark: | Currently synced and working |
| :wrench: | Has open issue |
| :x: | Not synced, no issue |
| :no_entry: | Cannot sync (no equivalent in other system) |
| :grey_question: | Needs investigation |

---

## Task Fields

| Field | Reminders | Vikunja | Sync Status | Issue |
|-------|-----------|---------|-------------|-------|
| **Title** | `title` | `title` | :white_check_mark: Synced | - |
| **Notes/Description** | `notes` | `description` | :wrench: Missing | #001 |
| **URL** | `url` | _(none)_ | :wrench: Missing | #008 |
| **Completed** | `isCompleted` | `done` | :white_check_mark: Synced | - |
| **Completed At** | `completionDate` | `done_at` | :wrench: Missing | #001 (updated) |
| **Due Date** | `dueDateComponents` | `due_date` | :white_check_mark: Synced | - |
| **Start Date** | `startDateComponents` | `start_date` | :wrench: Bug | #005 |
| **End Date** | _(see Recurrence End)_ | `end_date` | :wrench: Used for recurrence end | #004 |
| **Priority** | `priority` (0/1/5/9) | `priority` (0-5) | :wrench: Missing | #001 |
| **Flagged/Favorite** | `isFlagged` | `is_favorite` | :wrench: Missing | #001 |
| **Percent Done** | _(none)_ | `percent_done` | :no_entry: Reminders doesn't support | - |
| **Color** | _(none on task)_ | `hex_color` | :no_entry: Reminders tasks have no color | - |
| **Labels/Tags** | _(none)_ | `labels` | :wrench: Missing | #006 |
| **Alarms** | `alarms` | `reminders` | :wrench: Broken | #003 |
| **Recurrence** | `recurrenceRules` | `repeat_after`/`repeat_mode` | :wrench: Broken | #004 |
| **Recurrence End Date** | `EKRecurrenceEnd.endDate` | `end_date` | :wrench: Direct mapping! | #004 |
| **Recurrence End Count** | `EKRecurrenceEnd.occurrenceCount` | _(none)_ | :wrench: Metadata only | #004 |
| **Location Trigger** | `EKAlarm.structuredLocation` | _(none)_ | :wrench: Missing | #009 |
| **Attachments** | _(partial, OS-dependent)_ | `attachments` | :wrench: Research needed | #010 |
| **Subtasks** | _(UI only, no API)_ | `related_tasks` (subtask/parenttask) | :no_entry: **EventKit API doesn't expose subtasks** | - |
| **Assignees** | _(none)_ | `assignees` | :no_entry: Reminders doesn't support | - |
| **Comments** | _(none)_ | `comments` | :no_entry: Reminders doesn't support | - |
| **Related Tasks** | _(none)_ | `related_tasks` | :no_entry: Reminders doesn't support | - |
| **Created At** | `creationDate` | `created` | :grey_question: Read-only both sides | - |
| **Updated At** | `lastModifiedDate` | `updated` | :white_check_mark: Used for conflicts | - |
| **Time Zone** | `timeZone` | _(implicit in timestamp)_ | :grey_question: Partial | - |

---

## List/Project Fields

| Field | Reminders | Vikunja | Sync Status | Notes |
|-------|-----------|---------|-------------|-------|
| **Title** | `title` | `title` | :grey_question: | List sync not implemented? |
| **Color** | `cgColor` | `hex_color` | :grey_question: | Could sync |
| **Description** | _(none)_ | `description` | :no_entry: | Reminders lists have no description |
| **Archived** | _(none)_ | `is_archived` | :no_entry: | Reminders can't archive |
| **Favorite** | _(none)_ | `is_favorite` | :no_entry: | Reminders lists can't be favorited |

---

## Gap Analysis

### Currently Working :white_check_mark:
- Title
- Completed status
- Due date
- Updated at (for conflict detection)

### Has Issue Filed :wrench:
- Notes/Description (#001)
- Priority (#001)
- Flagged/Favorite (#001)
- Alarms (#003)
- Recurrence (#004)
- Start date bug (#005)
- Labels (#006)
- URLs (#008)
- Locations (#009)

### **NOT SYNCED - No Issue Filed** :x:

#### 1. Completion Timestamp (`completionDate` ↔ `done_at`)
- Both systems track when a task was completed
- Could be useful for reporting/analytics
- **Severity:** Low
- **Recommendation:** Add to Issue 001 or create new issue

#### 2. Attachments
- Reminders: Partial support (OS-dependent, not in current probe)
- Vikunja: Full support via separate endpoints
- **Severity:** Medium
- **Recommendation:** Create new issue, mark as future/research needed

### Cannot Sync :no_entry:
- End date (Vikunja only)
- Percent done (Vikunja only)
- Task color (Vikunja only)
- **Subtasks** - Reminders has UI support but **EventKit API doesn't expose parent-child relationships**; Vikunja has full API support via `related_tasks` but can't sync without Reminders API access
- Assignees (Vikunja only)
- Comments (Vikunja only)
- Related tasks (Vikunja only - Reminders has no concept)
- List description (Vikunja only)
- List archived/favorite (Vikunja only)

---

## Recommendations

### Skip (document as unsupported):
- End date, percent done, task color, subtasks, assignees, comments, related tasks
- These are features unique to one system with no reasonable mapping

### All gaps now covered:
- Completion timestamp added to Issue #001
- Attachments covered by Issue #010 (research needed)

---

## Summary

| Category | Count |
|----------|-------|
| Working | 4 fields |
| Has issue | 8 issues covering ~14 fields |
| Missing issue | 0 |
| Cannot sync | 10+ fields (no equivalent or API limitation) |

**Verdict:** All syncable fields are now covered by issues.

**Key API limitation discovered:** Apple's EventKit does NOT expose subtask/nested reminder relationships, even though the Reminders app UI supports them. This means subtasks cannot be synced programmatically - it's not something we missed, it's an Apple limitation.
