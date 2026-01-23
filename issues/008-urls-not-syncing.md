# Issue 008: URLs not syncing

**Severity:** Medium
**Status:** Cannot Fix (API Limitation)
**Reported:** 2026-01-23
**Closed:** 2026-01-23

## Resolution

**The `EKReminder.url` property is broken/disconnected from the Reminders UI.**

Previously implemented URL sync using description embedding, but testing revealed that:
- URLs set via `EKReminder.url` in code do NOT appear in the Reminders app UI
- URLs added via the Reminders app UI are NOT readable via `EKReminder.url`
- The Reminders app stores URLs as attachments (which EventKit cannot access)

This was confirmed by external developers:
> "Even a documented property such as `url` (from EKCalendarItem) doesn't work. If you add an event via code and set a URL, the URL isn't actually visible in the Reminders app. Or if a URL is set on a reminder in the Reminders app, your code can't read its value."
> — Stack Overflow, Feb 2025

**The URL embedding code has been removed** as it syncs a ghost field that doesn't connect to anything users see.

## The Problem

`EKReminder.url` is a **documented but non-functional API**:

| Action | Expected | Actual |
|--------|----------|--------|
| Set `reminder.url` via code | URL shows in Reminders app | URL invisible to user |
| Add URL in Reminders app UI | `reminder.url` readable | `reminder.url` is nil |

The Reminders app stores URLs as **attachments**, not in the `url` property. Since EventKit doesn't expose attachments for reminders, URLs are inaccessible.

## User Guidance

**URLs should be pasted as plain text in notes/description.**

- Paste URLs directly in the notes field
- They'll sync as part of normal description sync
- No special handling needed

This is the same guidance as for tags and attachments - these features use Apple's private storage that EventKit cannot access.

## Previous Implementation (Removed)

The following code was implemented but has been removed:
- `url: String?` field in CommonTask
- `embedUrlInDescription()` / `extractUrlFromDescription()` / `stripUrlFromDescription()` functions
- `---URL_START---` / `---URL_END---` markers in Vikunja descriptions
- URL diff detection in `tasksDiffer()`
- 16 unit tests for URL embedding

This added complexity for a feature that never worked in practice.

## Related

- Issue 006: Tags - Cannot Fix (same API limitation pattern)
- Issue 010: Attachments - Cannot Fix (same API limitation)
- All three features (tags, URLs, attachments) are stored by Apple in ways EventKit cannot access
