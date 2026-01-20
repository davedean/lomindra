# Common Schema: Reminders <-> Vikunja

This is a neutral model used to translate between Apple Reminders (EventKit) and Vikunja.
Fields are split into list-level and task-level, with shared concepts for recurrence, alarms,
and metadata.

## CommonList
Represents a Reminders list / Vikunja project.

- `id` (string): stable local ID for sync mapping.
- `title` (string).
- `description` (string?).
- `color` (string? `#RRGGBB`).
- `source` (string?): account/source name (Reminders).
- `archived` (bool?).
- `favorite` (bool?).
- `createdAt` (datetime?).
- `updatedAt` (datetime?).

## CommonTask
Represents a Reminders task / Vikunja task.

- `id` (string): stable local ID for sync mapping.
- `listId` (string): parent list ID.
- `title` (string).
- `notes` (string?).
- `url` (string?).
- `isCompleted` (bool).
- `completedAt` (datetime?).
- `createdAt` (datetime?).
- `updatedAt` (datetime?).
- `due` (CommonDateTime?).
- `start` (CommonDateTime?).
- `priority` (integer?).
- `percentDone` (number? 0..1).
- `labels` (array of CommonLabel?).
- `recurrence` (CommonRecurrence?).
- `alarms` (array of CommonAlarm?).
- `attachments` (array of CommonAttachment?).
- `subtasks` (array of CommonTask?).

## CommonLabel
- `id` (string).
- `title` (string).
- `color` (string? `#RRGGBB`).

## CommonDateTime
Represents a due/start date with optional time.

- `date` (string, ISO-8601 date or datetime).
- `hasTime` (bool): false for date-only.
- `timeZone` (string? IANA TZ name).

## CommonAlarm
- `type` (enum: `absolute`, `relative`).
- `absolute` (datetime?).
- `relativeSeconds` (integer?).
- `relativeTo` (enum: `start`, `due`, `end`).

## CommonRecurrence
- `frequency` (enum: `daily`, `weekly`, `monthly`, `yearly`, `custom`).
- `interval` (integer).
- `byWeekday` (array?).
- `byMonthDay` (array?).
- `byMonth` (array?).
- `count` (integer?).
- `until` (datetime?).
- `notes` (string?): for unsupported details.

## CommonAttachment
- `id` (string).
- `filename` (string).
- `mimeType` (string?).
- `url` (string?).

## SyncMetadata (per item)
Not synced, used to maintain stable mappings.

- `vikunjaId` (integer?).
- `remindersId` (string? calendarItemIdentifier).
- `lastSyncedAt` (datetime?).
- `lastSeenModifiedAt` (datetime?).
- `syncVersion` (integer?).

## Mapping Notes

### Lists
- Reminders lists map to Vikunja projects.
- Reminders list identifiers are `EKCalendar.calendarIdentifier`.
- Vikunja list identifiers are `models.Project.id`.

### Tasks
- Reminders task identifiers: `EKReminder.calendarItemIdentifier`.
- Vikunja task identifiers: `models.Task.id`.
- Notes map to `EKCalendarItem.notes` <-> `models.Task.description`.
- URL maps to `EKCalendarItem.url` <-> `models.Task` (store in `description` or `links` if supported).

### Dates
- Reminders `dueDateComponents` can be date-only or date-time.
- Reminders `startDateComponents` can be nil, date-only, or date-time.
- Vikunja uses `due_date` and `start_date` timestamps (datetime).
- For Reminders date-only, represent `hasTime=false` and carry timezone if present.

### Completion
- One-off Reminders: `isCompleted` and `completionDate` persist.
- Recurring Reminders: completing advances the occurrence and resets completion.
- Vikunja uses `done` and `done_at`.

### Recurrence
- Reminders: `EKRecurrenceRule` supports rich RRULE-like options.
- Vikunja: `repeat_after` (seconds) + `repeat_mode` (0/1/2).
- Expect lossy mapping for complex recurrence rules.

### Alarms / Reminders
- Reminders `EKAlarm` can be absolute or relative.
- Vikunja reminders support absolute (`reminder`) or relative (`relative_to`, `relative_period`).
- Relative alarm base (due vs start) should be detected or defaulted per policy.

### Labels / Tags
- Reminders has no native labels; these can be encoded in notes or ignored.
- Vikunja labels are first-class (`models.Label`).

### Attachments
- Reminders supports attachments in newer OS versions (not in this probe).
- Vikunja has task attachments with separate endpoints.

## Compatibility Table (initial)

Legend:
- **S** = supported
- **P** = partial / lossy
- **N** = not supported

### Lists

| Common field | Apple Reminders | Vikunja | Notes |
| --- | --- | --- | --- |
| `title` | S | S | |
| `description` | N | S | Reminders lists do not expose description. |
| `color` | P | S | Reminders list color is available but not hex; needs conversion. |
| `source` | S | N | Reminders has source/account; Vikunja does not. |
| `archived` | N | S | |
| `favorite` | N | P | Vikunja projects support favorites. |
| `createdAt` | N | S | Reminders list created date not exposed. |
| `updatedAt` | N | S | Reminders list updated date not exposed. |

### Tasks

| Common field | Apple Reminders | Vikunja | Notes |
| --- | --- | --- | --- |
| `title` | S | S | |
| `notes` | S | S | `EKCalendarItem.notes` <-> `Task.description`. |
| `url` | S | P | Vikunja has no dedicated URL field; use description or link conventions. |
| `isCompleted` | S | S | Recurring completion behaves differently in Reminders. |
| `completedAt` | P | S | Reminders uses `completionDate`; recurring rolls forward. |
| `createdAt` | S | S | `creationDate` <-> `created` (read-only). |
| `updatedAt` | S | S | `lastModifiedDate` <-> `updated` (read-only). |
| `due` | P | S | Reminders allows date-only; Vikunja uses datetime. |
| `start` | P | S | Reminders allows date-only; also auto-populates for due-only. |
| `priority` | P | S | Reminders priority scale differs from Vikunja integer. |
| `percentDone` | N | S | Reminders does not support percent complete. |
| `labels` | N | P | Reminders has no labels; Vikunja labels exist. |
| `recurrence` | P | P | Reminders is rich; Vikunja limited to repeat-after + mode. |
| `alarms` | S | P | Vikunja supports absolute and relative reminders; base date mapping needed. |
| `attachments` | P | P | Reminders supports attachments (OS-dependent); Vikunja via separate endpoints. |
| `subtasks` | P | N | Reminders supports subtasks (hierarchy); Vikunja lacks native subtasks. |

### Alarms / Reminders

| Common field | Apple Reminders | Vikunja | Notes |
| --- | --- | --- | --- |
| `type` | S | S | Absolute or relative. |
| `absolute` | S | S | |
| `relativeSeconds` | S | S | |
| `relativeTo` | P | S | Reminders relative base not explicit in API; verify behavior. |

### Recurrence

| Common field | Apple Reminders | Vikunja | Notes |
| --- | --- | --- | --- |
| `frequency` | S | P | Vikunja has limited modes. |
| `interval` | S | P | Vikunja `repeat_after` in seconds. |
| `byWeekday` | S | N | |
| `byMonthDay` | S | N | |
| `byMonth` | S | N | |
| `count` | S | N | |
| `until` | S | N | |
| `notes` | S | S | Use to store lossy details if desired. |
