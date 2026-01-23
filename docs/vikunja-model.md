# Vikunja Data Model Notes (from OpenAPI)

Source: `https://vikunja.example.com/api/v1/docs.json` (self-signed TLS)

## Project (List equivalent)
Definition: `models.Project`
- `id` (integer): project ID.
- `title` (string): project name.
- `description` (string).
- `hex_color` (string, `#RRGGBB`).
- `identifier` (string): short ID used in task identifiers.
- `parent_project_id` (integer).
- `is_archived` (boolean).
- `is_favorite` (boolean).
- `position` (number): ordering position.
- `created` (string, timestamp).
- `updated` (string, timestamp).
- `owner` (user.User, read-only).
- `views` (array of `models.ProjectView`).
- `subscription` (models.Subscription, read-only).
- `background_blur_hash` (string).
- `background_information` (object, read-only).

## Task
Definition: `models.Task`
- `id` (integer): task ID.
- `project_id` (integer): owning project.
- `title` (string): task title.
- `description` (string): task notes.
- `done` (boolean).
- `done_at` (string, timestamp, read-only).
- `created` (string, timestamp, read-only).
- `updated` (string, timestamp, read-only).
- `due_date` (string, timestamp).
- `start_date` (string, timestamp).
- `end_date` (string, timestamp).
- `priority` (integer).
- `percent_done` (number).
- `hex_color` (string, `#RRGGBB`).
- `is_favorite` (boolean).
- `index` (integer): per-project index (read-only).
- `identifier` (string): project identifier + index (read-only).
- `position` (number): ordering position (view-dependent).
- `bucket_id` (integer): only when using bucketed views.
- `reminders` (array of `models.TaskReminder`).
- `repeat_after` (integer): seconds between repeats.
- `repeat_mode` (models.TaskRepeatMode).
- `labels` (array of `models.Label`, read-only; use label endpoints).
- `attachments` (array of `models.TaskAttachment`, read-only; use attachment endpoints).
- `comments` (array of `models.TaskComment`, expand-only).
- `comment_count` (integer, expand-only).
- `assignees` (array of user.User).
- `related_tasks` (models.RelatedTaskMap).
- `buckets` (array of `models.Bucket`, expand-only).
- `reactions` (models.ReactionMap, read-only).
- `subscription` (models.Subscription, read-only; single-task fetch).
- `is_unread` (boolean).
- `cover_image_attachment_id` (integer).

## Reminder
Definition: `models.TaskReminder`
- `reminder` (string, timestamp): absolute reminder time.
- `relative_to` (models.ReminderRelation): `due_date`, `start_date`, or `end_date`.
- `relative_period` (integer): seconds offset from `relative_to` (negative = before).

Definition: `models.ReminderRelation`
- Enum values: `due_date`, `start_date`, `end_date`.

## Recurrence
Definition: `models.TaskRepeatMode`
- Enum values:
  - `0` = repeat after `repeat_after` seconds (default).
  - `1` = repeat monthly (ignores `repeat_after`).
  - `2` = repeat from current date rather than last date.

## Labels
Definition: `models.Label`
- `id` (integer).
- `title` (string).
- `description` (string).
- `hex_color` (string, `#RRGGBB`).
- `created` (string, timestamp, read-only).
- `updated` (string, timestamp, read-only).
- `created_by` (user.User, read-only).

## Attachments
Definition: `models.TaskAttachment`
- `id` (integer).
- `task_id` (integer).
- `created` (string, timestamp).
- `created_by` (user.User).
- `file` (files.File).

## Notes
- Some fields are read-only and require separate endpoints (`labels`, `attachments`).
- `position` and `bucket_id` are view-specific; may be irrelevant for Reminders.
- `repeat_mode` definition in OpenAPI lists values 0, 1, 2 but the task description references `3` for “from current date”; treat as doc inconsistency and verify via API behavior.

