# Apple Reminders Data Model Notes (EventKit)

Sources (DocC JSON):
- `https://developer.apple.com/tutorials/data/documentation/eventkit/ekreminder.json`
- `https://developer.apple.com/tutorials/data/documentation/eventkit/ekcalendaritem.json`
- `https://developer.apple.com/tutorials/data/documentation/eventkit/ekcalendar.json`
- `https://developer.apple.com/tutorials/data/documentation/eventkit/ekalarm.json`
- `https://developer.apple.com/tutorials/data/documentation/eventkit/ekrecurrencerule.json`
- `https://developer.apple.com/tutorials/data/documentation/eventkit/ekrecurrenceend.json`

## Reminder (Task equivalent)
Class: `EKReminder` (inherits `EKCalendarItem`)

Reminder-specific properties (from `EKReminder`):
- `startDateComponents` (DateComponents): start date (date-only or date-time).
- `dueDateComponents` (DateComponents): due date (date-only or date-time).
- `isCompleted` (Bool).
- `completionDate` (Date).
- `priority` (Int) via `EKReminder/priority` (uses `EKReminderPriority` enum).

Inherited from `EKCalendarItem`:
- `title` (String).
- `notes` (String).
- `url` (URL).
- `calendar` (EKCalendar): the list this reminder belongs to.
- `creationDate` (Date).
- `lastModifiedDate` (Date).
- `timeZone` (TimeZone).
- `alarms` (array of `EKAlarm`).
- `recurrenceRules` (array of `EKRecurrenceRule`).
- `calendarItemIdentifier` (String).
- `calendarItemExternalIdentifier` (String).
- `uuid` (String).

## List (Project equivalent)
Class: `EKCalendar`

Relevant fields:
- `calendarIdentifier` (String): list identifier.
- `title` (String): list name.
- `type` (EKCalendarType).
- `allowedEntityTypes` (EKEntityMask).
- `source` (EKSource): account/source.
- `color` / `cgColor`.
- `allowsContentModifications` (Bool).
- `isImmutable` (Bool).
- `isSubscribed` (Bool).

## Alarms / Reminders
Class: `EKAlarm`
- `absoluteDate` (Date) or `relativeOffset` (TimeInterval).
- `proximity` + `structuredLocation` for geo-fence alarms.
- `type`, `emailAddress`, `soundName`.

## Recurrence
Class: `EKRecurrenceRule`
- `frequency` (EKRecurrenceFrequency) + `interval`.
- `recurrenceEnd` (EKRecurrenceEnd): `endDate` or `occurrenceCount`.
- `daysOfTheWeek`, `daysOfTheMonth`, `daysOfTheYear`.
- `weeksOfTheYear`, `monthsOfTheYear`, `setPositions`.
- `firstDayOfTheWeek`.

Class: `EKRecurrenceEnd`
- `endDate` (Date) or `occurrenceCount` (Int).

## Notes / Caveats
- Reminders and Events share `EKCalendarItem`; verify which inherited fields are writable for Reminders.
- Identifiers are opaque; confirm which identifiers are stable for long-lived sync keys.
- DateComponents can be date-only or date-time; confirm how time zone is stored and surfaced.
- Alarm `relativeOffset` semantics should be validated for Reminders (relative to due vs start date).

## POC Findings (local probe)
From `scripts/ekreminder_probe.swift` (see `reminders_probe_output.log`):
- `calendarItemIdentifier` and `calendarItemExternalIdentifier` matched and stayed stable across edits.
- `dueDateComponents` stored date-only when set that way; `startDateComponents` stored date-time when set.
- When only `dueDateComponents` was set, `startDateComponents` was auto-populated with midnight of the due date.
- When only `startDateComponents` was set, `dueDateComponents` remained `nil`.
- `DateComponents.timeZone` sometimes round-tripped (present in the one-off case), but not consistently.
- One-off completion:
  - `isCompleted = true` persisted.
  - `completionDate` was set and read back.
- Recurring completion:
  - Completing the reminder advanced it to the next occurrence.
  - `isCompleted` returned to `false` and `completionDate` became `nil`.
  - `startDateComponents`/`dueDateComponents` shifted forward.
- Alarm behavior:
  - Absolute alarms preserved `absoluteDate`.
  - Relative alarms preserved `relativeOffset`.
  - When a recurring reminder advanced, the absolute alarm time moved to the next occurrence.
