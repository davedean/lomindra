# Issue 006: Tags/Labels not syncing

**Severity:** Medium
**Status:** Open
**Reported:** 2026-01-23

## Problem

Vikunja labels are not synced to/from Apple Reminders.

**Vikunja → Reminders:**
- Task with labels `["urgent", "work"]` → Reminders has no tag representation

**Reminders → Vikunja:**
- No direct tag equivalent in Reminders to sync back

## Root Cause Analysis

### Vikunja Labels

**API Structure** (from `docs/vikunja-model.md`):
- Labels are **read-only** in task responses; use separate label endpoints to manage
- Label structure (`models.Label`):
  - `id` (integer)
  - `title` (string)
  - `description` (string)
  - `hex_color` (string, #RRGGBB)
  - `created`, `updated` (timestamps, read-only)

**Current Implementation:**
- `VikunjaTask` struct does NOT include `labels` field
- `CommonTask` struct does NOT include `labels` field
- Translation rules (`docs/translation-rules.md` line 172): "Skip labels in MVP"

### EventKit/Apple Reminders

**No native tag support:**
- `EKReminder` has no tag/label properties
- iOS 17+ supports hashtags in notes (UI feature only, not API-accessible)
- The only grouping mechanism is lists (one per reminder)

## Recommended Approach: Hashtag Encoding in Notes

**Why this approach:**
1. Works on all iOS/macOS versions
2. Notes field already syncs bidirectionally
3. No separate metadata storage needed
4. User can see labels as `#tagname` in Reminders notes
5. Reversible without data loss

**Format:**
```
[Original notes content]

#label1 #label2 #label3
```

## Required Changes

### 1. Add VikunjaLabel struct

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (after line 232)

```swift
struct VikunjaLabel: Decodable {
    let id: Int
    let title: String
    let hex_color: String?
}
```

### 2. Add labels to VikunjaTask

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (line 222-232)

```swift
struct VikunjaTask: Decodable {
    // ... existing fields ...
    let labels: [VikunjaLabel]?  // ADD
}
```

### 3. Add labels to CommonTask

**File:** `Sources/VikunjaSyncLib/SyncLib.swift` (lines 25-53)

```swift
public struct CommonTask {
    // ... existing fields ...
    public let labels: [String]?  // Label titles only
}
```

### 4. Add label transformation functions

**File:** `Sources/VikunjaSyncLib/SyncLib.swift`

```swift
// Convert labels to hashtag string for appending to notes
public func labelsToHashtags(_ labels: [String]?) -> String? {
    guard let labels = labels, !labels.isEmpty else { return nil }
    return labels.map { "#\($0.lowercased().replacingOccurrences(of: " ", with: "-"))" }.joined(separator: " ")
}

// Extract hashtags from notes as labels
public func extractLabelsFromNotes(_ notes: String?) -> [String] {
    guard let notes = notes else { return [] }
    let regex = try! NSRegularExpression(pattern: "#([\\w-]+)", options: [])
    let matches = regex.matches(in: notes, range: NSRange(notes.startIndex..., in: notes))
    return matches.compactMap { match in
        guard let range = Range(match.range(at: 1), in: notes) else { return nil }
        return String(notes[range])
    }
}

// Remove hashtags from notes to get clean content
public func stripHashtagsFromNotes(_ notes: String?) -> String? {
    guard let notes = notes else { return nil }
    let cleaned = notes.replacingOccurrences(of: "#[\\w-]+\\s*", with: "", options: .regularExpression)
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

### 5. Update fetchVikunjaTasks()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (line 411-444)

Extract labels from task response:
```swift
let labelTitles = ($0.labels ?? []).map { $0.title }
```

### 6. Update fetchReminders()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (line 157-207)

Parse hashtags from notes:
```swift
let labels = extractLabelsFromNotes(reminder.notes)
let cleanNotes = stripHashtagsFromNotes(reminder.notes)
```

### 7. Update Vikunja task creation

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 1165-1206)

Note: Labels require separate API endpoint. For MVP, embed in description:
```swift
var description = task.notes ?? ""
if let hashtags = labelsToHashtags(task.labels) {
    description += "\n\n" + hashtags
}
payload["description"] = description
```

### 8. Update Reminders creation

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 1266-1305)

Append labels as hashtags to notes:
```swift
var notes = task.notes ?? ""
if let hashtags = labelsToHashtags(task.labels) {
    notes += "\n\n" + hashtags
}
reminder.notes = notes.isEmpty ? nil : notes
```

## Edge Cases to Handle

- Task already has hashtags unrelated to labels (preserve them)
- Label titles with special characters (sanitize to `[a-z0-9-]`)
- Many labels (notes field has no practical limit)
- Concurrent edits to notes and labels

## Alternative: Metadata-Only Storage

If hashtag approach is too risky:
- Store labels in sync database `labels_json` column
- Round-trip preserves labels
- Labels invisible in Reminders
- Lower risk of data corruption

## Acceptance Criteria

- [ ] VikunjaTask decodes labels from API response
- [ ] CommonTask includes labels field
- [ ] Labels converted to hashtags in Reminders notes
- [ ] Hashtags parsed back to labels when syncing from Reminders
- [ ] Round-trip preserves labels
- [ ] Existing notes content not corrupted
- [ ] Unit tests for hashtag encoding/decoding
