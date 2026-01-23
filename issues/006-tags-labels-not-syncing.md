# Issue 006: Tags/Labels not syncing

**Severity:** Medium
**Status:** Open
**Reported:** 2026-01-23
**Updated:** 2026-01-23

## Summary

Native Reminders tags cannot be accessed via EventKit (API limitation), but we can implement an **opt-in feature** to sync Vikunja labels as inline hashtags for users who manage labels programmatically (e.g., via agents).

## Proposed Solution: Opt-in Hashtag Sync

Add a settings toggle: **"Sync tags using inline text"** (default: OFF)

When enabled:
- **Vikunja → Reminders:** Labels appear as `#label1 #label2` in the reminder
- **Reminders → Vikunja:** Parse `#hashtag` text and create Vikunja labels

### Tag Placement Rules

Tags should be placed in the **title** if the reminder has no notes, otherwise in **notes**:

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
- **Strip tags:** Remove tag text from title/notes before comparing/syncing
- **Round-trip safe:** Tags extracted and re-embedded should produce identical results

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
| Apple Reminders | ✅ Yes (UI feature) | ❌ No (private database) |
| Vikunja | ✅ Yes (labels) | ✅ Yes |

**Empirical verification (2026-01-23):**
- Added "NextAction" tag to reminder via Reminders UI
- Probed via EventKit - tag is invisible
- `EKReminder` has no `tags`, `hashTags`, or similar properties
- Native tags cannot be synced - this opt-in feature is for hashtag text only

## Implementation Plan

1. Add settings toggle: "Sync tags using inline text" (default OFF)
2. Add `extractTagsFromText()` function - parse `#hashtag` patterns
3. Add `embedTagsInText()` function - append tags to title or notes
4. Add `stripTagsFromText()` function - remove tags for comparison
5. Modify `CommonTask` construction to handle tag extraction/embedding
6. Add unit tests for tag parsing/embedding
7. Document the feature and its limitations

## Related

- Issue 008: URLs - Cannot Fix (same EventKit limitation pattern for `EKReminder.url`)
- Issue 010: Attachments - Cannot Fix (EventKit has no attachment API)
