# Issue 008: URLs not syncing

**Severity:** Medium
**Status:** Resolved
**Reported:** 2026-01-23
**Resolved:** 2026-01-23

## Resolution

Implemented URL sync using description embedding:
- Added `url: String?` field to CommonTask
- URLs embedded in Vikunja description with `---URL_START---`/`---URL_END---` markers
- Extracted/stripped on read, embedded on write
- EKReminder.url property used for Reminders side
- 16 unit tests for URL embedding/extraction and diff detection

## Problem

URLs attached to tasks are not synced between systems.

**Reminders → Vikunja:**
- Reminder with URL → Vikunja has no URL

**Vikunja → Reminders:**
- Task with URL in description → Reminders URL field empty

## Root Cause Analysis

### EventKit URL API

**Property:** `EKCalendarItem.url: URL?`
- Dedicated URL field inherited by `EKReminder`
- Shows as tappable link in Reminders app
- Read/write

**Evidence from codebase:**
```swift
// scripts/ekreminder_probe.swift line 145
recurringReminder.url = URL(string: "https://example.com/recurring")
```

**Current Implementation:**
- `CommonTask` does NOT include `url` field
- `fetchReminders()` does NOT extract `reminder.url`
- URLs completely ignored

### Vikunja URL Support

**No dedicated URL field** in `models.Task`

Per `docs/common-schema.md` line 96:
> URL maps to `EKCalendarItem.url` ↔ `models.Task` (store in `description` or `links` if supported)

**Options:**
1. Embed URL in task description (recommended for MVP)
2. Use Vikunja attachments (requires research)
3. Store in sync metadata only

## Recommended Approach: Embed URL in Description

**Why this approach:**
- Works with current Vikunja API
- Simple to implement
- Reversible encoding

**Format with delimiters:**
```
---URL_START---
https://example.com
---URL_END---
[actual description/notes content]
```

## Required Changes

### 1. Add url to CommonTask

**File:** `Sources/VikunjaSyncLib/SyncLib.swift` (lines 25-53)

```swift
public struct CommonTask {
    // ... existing fields ...
    public let url: String?
}
```

### 2. Add URL helper functions

**File:** `Sources/VikunjaSyncLib/SyncLib.swift`

```swift
private let urlStartMarker = "---URL_START---"
private let urlEndMarker = "---URL_END---"

// Embed URL in description
public func embedUrlInDescription(description: String?, url: String?) -> String? {
    guard let url = url else { return description }
    let urlBlock = "\(urlStartMarker)\n\(url)\n\(urlEndMarker)"
    if let desc = description, !desc.isEmpty {
        return "\(urlBlock)\n\(desc)"
    }
    return urlBlock
}

// Extract URL from description
public func extractUrlFromDescription(_ description: String?) -> String? {
    guard let desc = description,
          let startRange = desc.range(of: urlStartMarker),
          let endRange = desc.range(of: urlEndMarker) else { return nil }

    let urlStart = desc.index(startRange.upperBound, offsetBy: 1)
    let urlEnd = desc.index(endRange.lowerBound, offsetBy: -1)
    guard urlStart < urlEnd else { return nil }

    return String(desc[urlStart...urlEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
}

// Remove URL block from description
public func stripUrlFromDescription(_ description: String?) -> String? {
    guard let desc = description else { return nil }
    guard let startRange = desc.range(of: urlStartMarker),
          let endRange = desc.range(of: urlEndMarker) else { return desc }

    var result = desc
    let fullRange = startRange.lowerBound..<desc.index(endRange.upperBound, offsetBy: 1, limitedBy: desc.endIndex) ?? endRange.upperBound
    result.removeSubrange(fullRange)
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

### 3. Extract URL in fetchReminders()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 192-205)

```swift
return CommonTask(
    // ... existing fields ...
    url: reminder.url?.absoluteString  // ADD
)
```

### 4. Extract URL in fetchVikunjaTasks()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 430-443)

```swift
let url = extractUrlFromDescription($0.description)
let cleanDescription = stripUrlFromDescription($0.description)

return CommonTask(
    // ... existing fields ...
    notes: cleanDescription,  // Use cleaned description
    url: url  // ADD extracted URL
)
```

Note: Requires adding `description: String?` to `VikunjaTask` struct first.

### 5. Send URL to Vikunja API

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift`

In `createVikunjaTask()` and `updateVikunjaTask()`:
```swift
let description = embedUrlInDescription(description: task.notes, url: task.url)
payload["description"] = description ?? ""
```

### 6. Set URL in EventKit

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift`

In `createReminder()` and `updateReminder()`:
```swift
if let urlString = task.url, let url = URL(string: urlString) {
    reminder.url = url
} else {
    reminder.url = nil
}
```

### 7. Include URL in diff detection

**File:** `Sources/VikunjaSyncLib/SyncLib.swift`

In `tasksDiffer()`:
```swift
let sameUrl = left.url == right.url
return !(sameTitle && sameDone && sameDue && sameAlarms && sameRecurrence && sameUrl)
```

In `conflictFieldDiffs()`:
```swift
addDiff(field: "url", reminders: reminders.url ?? "", vikunja: vikunja.url ?? "")
```

### 8. Update test helpers

**File:** `Tests/VikunjaSyncLibTests/SyncLibTests.swift`

Add `url: String? = nil` parameter to `makeTask()`.

## Dependency

This issue depends on **Issue 002 (Notes/Description)** being implemented first, since URL embedding uses the description field.

## Edge Cases

- Description already contains URL markers (escape or use unique markers)
- Invalid URL strings (validate before setting)
- Very long URLs (no practical limit in description)
- Multiple URLs (only first one syncs to Reminders URL field; others stay in description)

## Acceptance Criteria

- [ ] Reminders URL syncs to Vikunja (embedded in description)
- [ ] Vikunja URL (in description) syncs to Reminders URL field
- [ ] Round-trip preserves URL
- [ ] URL changes trigger sync updates
- [ ] Original description content not corrupted
- [ ] Unit tests for URL embedding/extraction
