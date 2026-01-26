# Issue 006: Tags/Labels not syncing

**Severity:** Medium
**Status:** Implemented
**Reported:** 2026-01-23
**Updated:** 2026-01-26
**Implemented:** 2026-01-26

## Summary

Native Reminders tags cannot be accessed via EventKit (API limitation). We implemented an **opt-in feature** to sync Vikunja labels as inline hashtags for users who manage labels programmatically (e.g., via agents).

## Solution: Opt-in Hashtag Sync

Added a settings toggle: **"Sync tags using hashtags"** (default: OFF)

When enabled:
- **Vikunja → Reminders:** Labels appear as `#label1 #label2` in the reminder title/notes
- **Reminders → Vikunja:** Parse `#hashtag` text and create Vikunja labels

### Tag Placement Rules

Tags are placed in the **title** if the reminder has no notes, otherwise in **notes**:

```
If notes is empty/nil:
  title = "Original title #tag1 #tag2"
  notes = nil

If notes exists:
  title = "Original title"
  notes = "Original notes\n\n#tag1 #tag2"
```

This keeps titles clean when notes are available, but still shows tags when there's no other text.

### Parsing Rules

- **Extract tags:** Match `#[a-zA-Z0-9_-]+` patterns
- **Strip tags:** Remove tag text from title/notes before syncing to Vikunja
- **Round-trip safe:** Tags extracted and re-embedded produce identical results

## Implementation Details

### Files Changed

**SyncLib.swift:**
- Added `labels` field to `CommonTask`
- Added `syncTagsEnabled` to `Config`
- Pure functions: `extractTagsFromText()`, `stripTagsFromText()`, `embedTagsInText()`, `embedTagsWithPlacement()`, `extractTagsFromTask()`, `stripTagsFromTask()`

**SyncRunner.swift:**
- Added `VikunjaLabel` struct for API decoding
- Added label API functions: `fetchVikunjaLabels()`, `createVikunjaLabel()`, `updateVikunjaTaskLabels()`, `ensureVikunjaLabelsExist()`
- Label cache in `runSync()` for efficient label ID lookup
- `fetchVikunjaTasks()` now includes labels in CommonTask
- `fetchReminders()` extracts hashtags from title/notes as labels
- `createReminder()`/`updateReminder()` embed labels as hashtags when enabled
- `createVikunjaTask()`/`updateVikunjaTask()` strip hashtags and update labels via API

**AppSettings.swift:**
- Added `syncTagsEnabled` setting (default: false)

**SyncCoordinator.swift:**
- Pass `syncTagsEnabled` to Config

**SyncView.swift:**
- Added "Tags/Labels" section with toggle and explanation

**SyncLibTests.swift:**
- 25 new unit tests for hashtag parsing/embedding

## Why This Is Useful

### Agent Workflows

Users with automated agents (e.g., AI assistants managing tasks):
1. Agent creates tasks in Vikunja with labels like `NextAction`, `Waiting`, `Project-X`
2. Labels sync to Reminders as `#NextAction #Waiting #Project-X`
3. User sees context in Reminders without opening Vikunja
4. User can add `#NewTag` in Reminders notes → syncs back to Vikunja

### GTD/Organization Enthusiasts

Users who want consistent tag visibility across systems, accepting the text-based representation.

## Limitations (Documented for Users)

1. **Native Reminders tags don't sync** - Tags added via Reminders UI (the tag picker) are stored in Apple's private database and cannot be read by EventKit
2. **Text-based only** - Tags appear as plain text `#hashtags`, not native tag chips
3. **Requires user opt-in** - Default is OFF to avoid surprising users with hashtag text

## API Limitation Details

| System | Native Tags? | API Access? |
|--------|--------------|-------------|
| Apple Reminders | Yes (UI feature) | No (private database) |
| Vikunja | Yes (labels) | Yes |

**Empirical verification (2026-01-23):**
- Added "NextAction" tag to reminder via Reminders UI
- Probed via EventKit - tag is invisible
- `EKReminder` has no `tags`, `hashTags`, or similar properties
- Native tags cannot be synced - this opt-in feature is for hashtag text only

## Related

- Issue 008: URLs - Cannot Fix (same EventKit limitation pattern for `EKReminder.url`)
- Issue 010: Attachments - Cannot Fix (EventKit has no attachment API)
