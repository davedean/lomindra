# Issue 006: Tags/Labels not syncing

**Severity:** Medium
**Status:** Cannot Fix (API Limitation)
**Reported:** 2026-01-23
**Closed:** 2026-01-23

## Resolution

**EventKit does NOT expose tags added via the Reminders app UI.**

While the Reminders app (iOS 17+/macOS Sonoma+) supports native tags that users can add to reminders, this data is stored in Apple's private database and is **not accessible through the EventKit framework**.

**Empirical verification:**
- Added "NextAction" tag to "Call Bev to say hello" reminder via Reminders UI
- Probed the reminder via EventKit - tag is invisible
- `EKReminder` has no `tags`, `hashTags`, or similar properties
- Selectors like `tags`, `hashTags`, `calendarItemTags` all return `false` for `responds(to:)`

**This means:**
- Native tags users add in Reminders → Cannot be read by our app → Cannot sync to Vikunja
- Vikunja labels → Could be written as hashtags in notes → But users expect native tags, not workarounds

**Conclusion:** Even if we implemented hashtag-in-notes as a workaround, users would naturally use the native Reminders tag feature (it's right there in the UI), and those tags would never sync. This defeats the purpose of "tag sync."

## Why Workarounds Don't Work

### Hashtag-in-notes approach
Previously proposed: Parse `#hashtag` from notes, sync as Vikunja labels.

**Problems:**
1. Users won't type `#hashtags` in notes - they'll use the native tag UI
2. Native tags are invisible to us, so we can't sync what users actually use
3. Requires users to change their behavior, which defeats seamless sync
4. Creates confusion: "Why don't my tags sync?" (because they used native tags)

### Metadata preservation
Store Vikunja labels in sync database, restore on round-trip.

**Problems:**
1. Still can't read native Reminders tags
2. One-way only (Vikunja → Reminders via hashtags in notes)
3. Users would see `#work #urgent` in notes instead of native tags
4. Poor UX compared to native tag support

## The Fundamental Problem

| System | Native Tags? | API Access? |
|--------|--------------|-------------|
| Apple Reminders | ✅ Yes (UI feature) | ❌ No (private database) |
| Vikunja | ✅ Yes (labels) | ✅ Yes |

Apple added tags to Reminders but didn't expose them through EventKit. This is a deliberate API design choice by Apple, not something we can work around.

## User Guidance

Tags/labels are system-specific:
- **Reminders tags** stay in Reminders only
- **Vikunja labels** stay in Vikunja only

Users who need tag organization should:
1. Use Vikunja for tag-based workflows (labels fully supported there)
2. Use Reminders lists for organization (lists DO sync as Vikunja projects)

## Original Problem Statement

Vikunja labels are not synced to/from Apple Reminders.

**Vikunja → Reminders:**
- Task with labels `["urgent", "work"]` → Reminders has no tag representation

**Reminders → Vikunja:**
- Reminder with native tags → Tags invisible to EventKit → Cannot sync

## References

- Empirical probe: Tags added via Reminders UI are not visible to EventKit
- `EKReminder` class has no tag-related properties
- iOS 17+ hashtag display in notes is UI-only (not API-accessible)
- Same limitation as attachments (Issue 010)
