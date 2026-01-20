# Translation Rules (MVP)

Rules target a single list sync with minimal loss. All mappings go through the
Common Schema as defined in `docs/common-schema.md`.

## Reminders -> Common

### List
- `EKCalendar.calendarIdentifier` -> `CommonList.id`
- `EKCalendar.title` -> `CommonList.title`
- `EKCalendar.color`/`cgColor` -> `CommonList.color` (convert to hex)
- `EKCalendar.source.title` -> `CommonList.source`

### Task
- `EKReminder.calendarItemIdentifier` -> `CommonTask.id`
- `EKReminder.calendar.calendarIdentifier` -> `CommonTask.listId`
- `EKReminder.title` -> `CommonTask.title`
- `EKCalendarItem.notes` -> `CommonTask.notes`
- `EKCalendarItem.url` -> `CommonTask.url`
- `EKReminder.isCompleted` -> `CommonTask.isCompleted`
- `EKReminder.completionDate` -> `CommonTask.completedAt`
- `EKCalendarItem.creationDate` -> `CommonTask.createdAt`
- `EKCalendarItem.lastModifiedDate` -> `CommonTask.updatedAt`
- `EKReminder.priority` -> `CommonTask.priority`

#### Dates
- `EKReminder.dueDateComponents`:
  - if has time fields (hour/minute), set `CommonTask.due.hasTime = true`
  - else `CommonTask.due.hasTime = false`
  - set `CommonTask.due.date` using local time
  - copy timezone if present
- `EKReminder.startDateComponents`:
  - same conversion as `due`
  - note: Reminders may auto-populate start date for due-only reminders

#### Alarms
- For each `EKAlarm`:
  - if `absoluteDate` != nil -> `CommonAlarm.type = absolute`, `absolute = date`
  - else -> `CommonAlarm.type = relative`, `relativeSeconds = relativeOffset`
  - `relativeTo` is unknown in Reminders API; default to `due` if due exists,
    else `start` if start exists, else `due` and mark ambiguous.

#### Recurrence
- If no recurrence rules -> `CommonTask.recurrence = nil`
- For the first `EKRecurrenceRule`:
  - map `frequency` to `CommonRecurrence.frequency`
  - map `interval` to `CommonRecurrence.interval`
  - map `recurrenceEnd.endDate` -> `CommonRecurrence.until`
  - map `recurrenceEnd.occurrenceCount` -> `CommonRecurrence.count`
  - map `daysOfTheWeek`, `daysOfTheMonth`, `monthsOfTheYear` as available
  - if unsupported fields exist, store serialized details in `CommonRecurrence.notes`

## Common -> Vikunja

### List
- `CommonList.title` -> `models.Project.title`
- `CommonList.description` -> `models.Project.description` (if present)
- `CommonList.color` -> `models.Project.hex_color` (if convertible)
- Ignore `source` (no Vikunja equivalent)

### Task
- `CommonTask.title` -> `models.Task.title`
- `CommonTask.notes` -> `models.Task.description`
- `CommonTask.isCompleted` -> `models.Task.done`
- `CommonTask.completedAt` -> `models.Task.done_at` (read-only in API; set `done`)
- `CommonTask.priority` -> `models.Task.priority`
- `CommonTask.createdAt` / `updatedAt` are read-only (ignore)

#### Dates
- `CommonTask.due` -> `models.Task.due_date`
  - if `hasTime=false`, choose a policy:
    - store as local date at 00:00, or
    - store as local date at 23:59:59
  - record policy in sync metadata
- `CommonTask.start` -> `models.Task.start_date`

#### Alarms
- `CommonAlarm.type = absolute` -> `models.TaskReminder.reminder`
- `CommonAlarm.type = relative` -> `models.TaskReminder.relative_period`
  - `CommonAlarm.relativeTo` -> `models.TaskReminder.relative_to`

#### Recurrence
- If `CommonRecurrence.frequency` is daily/weekly and interval fits:
  - translate to `repeat_after` seconds (interval * 86400 or 604800).
  - `repeat_mode = 0`.
- If monthly:
  - set `repeat_mode = 1` (month-based), ignore `repeat_after`.
- Otherwise:
  - store in `CommonRecurrence.notes` and skip for MVP.

## Vikunja -> Common

### List
- `models.Project.id` -> `CommonList.id`
- `models.Project.title` -> `CommonList.title`
- `models.Project.description` -> `CommonList.description`
- `models.Project.hex_color` -> `CommonList.color`
- `models.Project.is_archived` -> `CommonList.archived`
- `models.Project.is_favorite` -> `CommonList.favorite`
- `models.Project.created` -> `CommonList.createdAt`
- `models.Project.updated` -> `CommonList.updatedAt`

### Task
- `models.Task.id` -> `CommonTask.id`
- `models.Task.project_id` -> `CommonTask.listId`
- `models.Task.title` -> `CommonTask.title`
- `models.Task.description` -> `CommonTask.notes`
- `models.Task.done` -> `CommonTask.isCompleted`
- `models.Task.done_at` -> `CommonTask.completedAt`
- `models.Task.created` -> `CommonTask.createdAt`
- `models.Task.updated` -> `CommonTask.updatedAt`
- `models.Task.priority` -> `CommonTask.priority`

#### Dates
- `models.Task.due_date` -> `CommonTask.due` (date-time)
- `models.Task.start_date` -> `CommonTask.start` (date-time)

#### Alarms
- For each `models.TaskReminder`:
  - if `reminder` set -> `CommonAlarm.type = absolute`
  - else -> `CommonAlarm.type = relative`
  - `relative_period` -> `CommonAlarm.relativeSeconds`
  - `relative_to` -> `CommonAlarm.relativeTo`

#### Recurrence
- If `repeat_mode = 0` and `repeat_after` set:
  - convert seconds to `CommonRecurrence.interval` with `frequency = custom`
  - store `intervalSeconds` in `CommonRecurrence.notes`
- If `repeat_mode = 1`:
  - set `frequency = monthly`, `interval = 1`
- If `repeat_mode = 2`:
  - set `frequency = custom`, note "from current date"

## Common -> Reminders

### List
- `CommonList.title` -> `EKCalendar.title`
- `CommonList.color` -> `EKCalendar.color` (best-effort)

### Task
- `CommonTask.title` -> `EKReminder.title`
- `CommonTask.notes` -> `EKCalendarItem.notes`
- `CommonTask.url` -> `EKCalendarItem.url`
- `CommonTask.isCompleted` -> `EKReminder.isCompleted`
- `CommonTask.completedAt` -> `EKReminder.completionDate`
- `CommonTask.priority` -> `EKReminder.priority`

#### Dates
- If `CommonTask.due`:
  - set `dueDateComponents` from `date` and `hasTime`
  - apply `timeZone` if available
- If `CommonTask.start`:
  - set `startDateComponents` from `date` and `hasTime`
  - apply `timeZone` if available

#### Alarms
- `CommonAlarm.type = absolute` -> `EKAlarm(absoluteDate:)`
- `CommonAlarm.type = relative` -> `EKAlarm(relativeOffset:)`
  - Use `relativeTo` to decide whether to set a due or start date if missing.

#### Recurrence
- If `CommonRecurrence.frequency` in daily/weekly/monthly/yearly:
  - create `EKRecurrenceRule` with `interval`
  - map `until` to `EKRecurrenceEnd(end:)`
  - map `count` to `EKRecurrenceEnd(occurrenceCount:)`
- If fields are unsupported, skip for MVP and add to notes.

## MVP Policies (initial)
- Use a per-task sync metadata store to remember lossy conversions.
- Treat date-only due dates as local date at 00:00 in Vikunja.
- For Reminders relative alarms, default to `due` when ambiguous.
- Skip labels, attachments, subtasks in MVP.

## Priority Mapping

Reminders priority is defined by `EKReminderPriority` (1 = high, 5 = medium, 9 = low, 0 = none).
Vikunja priority is an integer with no fixed range. For MVP:

### Reminders -> Vikunja
- `priority = 1` -> `Task.priority = 3`
- `priority = 5` -> `Task.priority = 2`
- `priority = 9` -> `Task.priority = 1`
- `priority = 0` or unset -> `Task.priority = 0`
- Any other value -> clamp to 1..3 based on nearest (1,5,9)

### Vikunja -> Reminders
- `Task.priority >= 3` -> `EKReminder.priority = 1`
- `Task.priority = 2` -> `EKReminder.priority = 5`
- `Task.priority = 1` -> `EKReminder.priority = 9`
- `Task.priority = 0` -> `EKReminder.priority = 0`

## Date-Only Policy (MVP)

Date-only values must survive a round-trip without time drift.

### Reminders -> Vikunja
- If `CommonDateTime.hasTime = false`:
  - Store `due_date` or `start_date` as local date at 00:00.
  - Record `dateOnly = true` in sync metadata for that task field.

### Vikunja -> Reminders
- If sync metadata says `dateOnly = true`:
  - Strip time components and set only date fields in `DateComponents`.
- Otherwise:
  - Set full date-time and allow time zone if present.

## Sync Metadata Storage

Per-task sync metadata is required to preserve:
- Date-only vs date-time intent.
- Ambiguous alarm bases.
- Identifier mappings between systems.

Minimal record shape (stored locally, not in either system):

```
{
  "remindersId": "EKReminder.calendarItemIdentifier",
  "vikunjaId": 123,
  "listRemindersId": "EKCalendar.calendarIdentifier",
  "projectId": 45,
  "dateOnly": {
    "due": true,
    "start": false
  },
  "relativeAlarmBase": {
    "alarmHash": "due"
  },
  "lastSyncedAt": "2026-01-19T09:27:46Z",
  "lastSeenModifiedAt": {
    "reminders": "2026-01-19T09:27:46Z",
    "vikunja": "2026-01-19T09:27:46Z"
  },
  "syncVersion": 1
}
```

Notes:
- `alarmHash` can be a stable hash of alarm properties (relative/absolute + offset/date).
- `lastSeenModifiedAt` is used for conflict detection.
- `syncVersion` supports future migrations.
