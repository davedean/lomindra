# Issue 010: Attachments not syncing

**Severity:** Medium
**Status:** Cannot Fix (API Limitation)
**Reported:** 2026-01-23
**Closed:** 2026-01-23

## Resolution

**EventKit does NOT expose an attachments API for EKReminder.**

While the Reminders.app UI supports file attachments (you can add images and files to reminders), this data is stored in a private database that Apple does not expose through the EventKit framework.

**This is a hard platform limitation, not something we can work around.**

## Research Findings

### EventKit Attachment Support

- `EKReminder` inherits from `EKCalendarItem`
- `EKCalendarItem` has NO `attachments` property for reminders
- `EKEvent` (calendar events) does have attachment support, but `EKReminder` does not
- Third-party apps **cannot read OR write** reminder attachments
- This is confirmed by examining:
  - Apple's EventKit documentation
  - The apple-reminders-cli project (no attachment support)
  - Our own probe scripts (no attachment properties available)

### Vikunja Attachment Support

Vikunja fully supports attachments via its API:
- `GET /api/v1/tasks/{taskId}/attachments` - list attachments
- `POST /api/v1/tasks/{taskId}/attachments` - upload (multipart/form-data)
- `GET /api/v1/tasks/{taskId}/attachments/{attachmentId}` - download
- `DELETE /api/v1/tasks/{taskId}/attachments/{attachmentId}` - delete

But this is irrelevant since we can't access Reminders attachments.

## Why Workarounds Don't Work

### Option: Store Vikunja attachment URLs in Reminders notes
- Links would appear as plain text, not actual attachments
- Can't sync back (can't read from Reminders to know what changed)
- Poor user experience

### Option: Metadata preservation in sync database
- Could store Vikunja attachment metadata when syncing to Reminders
- But can't detect if user adds attachment in Reminders
- Can't read attachment data to sync to Vikunja
- Breaks the bidirectional sync model

## Conclusion

**Attachment syncing is not feasible** due to Apple's API design choice.

If Apple adds attachment support to EventKit in a future macOS/iOS version, this could be revisited. Until then, attachments should be documented as an unsupported feature.

## User Guidance

Users who rely on attachments have two options:

1. **Use Vikunja for attachments** - Add attachments in Vikunja web/app; they won't appear in Reminders but will be accessible in Vikunja
2. **Use Reminders for attachments** - Add attachments in Reminders; they won't sync to Vikunja but will stay in Reminders

Attachments added in either system remain in that system only.

## Original Problem Statement

Attachments on tasks are not synced between systems.

**Reminders → Vikunja:**
- Reminder with image/file attachment → Vikunja has no attachments

**Vikunja → Reminders:**
- Task with attachments → Reminders has no attachments

## References

- Apple EventKit Documentation: https://developer.apple.com/documentation/eventkit
- EKReminder Class Reference: https://developer.apple.com/documentation/eventkit/ekreminder
- Comparison with apple-reminders-cli: No attachment support (same limitation)
