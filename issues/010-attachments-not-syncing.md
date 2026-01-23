# Issue 010: Attachments not syncing

**Severity:** Medium
**Status:** Open (Research Needed)
**Reported:** 2026-01-23

## Problem

Attachments on tasks are not synced between systems.

**Reminders → Vikunja:**
- Reminder with image/file attachment → Vikunja has no attachments

**Vikunja → Reminders:**
- Task with attachments → Reminders has no attachments

## Analysis

### Apple Reminders Attachments

**Support:** Partial, OS-dependent

- Attachments added in iOS 13+ / macOS Catalina+
- EventKit support unclear - may require newer APIs
- Not tested in current `ekreminder_probe.swift`

**Research needed:**
- What EventKit API exposes attachments on EKReminder?
- Are attachments readable/writable via EventKit?
- What file types are supported?

### Vikunja Attachments

**Support:** Full API support via separate endpoints

From `docs/vikunja-model.md`:
```
models.TaskAttachment:
- id (integer)
- task_id (integer)
- created (string, timestamp)
- created_by (user.User)
- file (files.File)
```

**Key points:**
- Attachments are read-only in task response
- Require separate endpoints to upload/download
- Files are stored on Vikunja server

### Complexity

**High** - This is not a simple field mapping:

1. **File transfer required** - Need to download from one system, upload to other
2. **Storage differences** - Reminders uses iCloud, Vikunja uses its own storage
3. **API complexity** - Separate endpoints, multipart uploads
4. **Size limits** - Both systems may have different limits
5. **File type support** - May differ between systems

## Possible Approaches

### Option A: Full bidirectional sync
- Download attachments from source system
- Upload to target system
- Track attachment mappings in sync database
- **Pro:** Complete feature parity
- **Con:** Complex, bandwidth-heavy, storage duplication

### Option B: Link-only sync
- Store Vikunja attachment URLs in Reminders notes
- Store Reminders attachment references in Vikunja description
- **Pro:** Simple, no file transfer
- **Con:** Links may not work across systems, not true attachments

### Option C: Metadata preservation only
- Store attachment metadata in sync database
- Restore when syncing back to original system
- Don't transfer files between systems
- **Pro:** Round-trip safe, no bandwidth
- **Con:** Attachments only visible in original system

### Option D: Skip for MVP
- Document as unsupported
- **Pro:** Simplest
- **Con:** Feature gap

## Research Tasks

Before implementing, need to investigate:

1. [ ] Test EventKit attachment APIs on recent macOS
2. [ ] Determine if EKReminder exposes attachments
3. [ ] Test Vikunja attachment upload/download endpoints
4. [ ] Measure typical attachment sizes
5. [ ] Evaluate bandwidth/storage implications

## Required Changes (if implementing Option A)

### 1. Add CommonAttachment struct

**File:** `Sources/VikunjaSyncLib/SyncLib.swift`

```swift
public struct CommonAttachment: Codable, Equatable {
    public let id: String
    public let filename: String
    public let mimeType: String?
    public let size: Int?
    public let url: String?  // For download
    public let localPath: String?  // For upload
}
```

### 2. Add attachments to CommonTask

```swift
public struct CommonTask {
    // ... existing fields ...
    public let attachments: [CommonAttachment]
}
```

### 3. Implement attachment transfer functions

```swift
func downloadVikunjaAttachment(taskId: Int, attachmentId: Int) -> Data?
func uploadVikunjaAttachment(taskId: Int, filename: String, data: Data) -> Int?
func downloadRemindersAttachment(reminder: EKReminder, attachmentId: String) -> Data?
func addRemindersAttachment(reminder: EKReminder, filename: String, data: Data) -> Bool
```

### 4. Add attachment sync logic

- During sync, compare attachment lists
- Download missing attachments from source
- Upload to target system
- Track mappings in sync database

## Acceptance Criteria (if implementing)

- [ ] EventKit attachment API researched and documented
- [ ] Vikunja attachment endpoints tested
- [ ] Attachments sync from Reminders to Vikunja
- [ ] Attachments sync from Vikunja to Reminders
- [ ] Round-trip preserves attachments
- [ ] Large attachments handled gracefully (or rejected with warning)
- [ ] Duplicate attachments not created on re-sync

## Recommendation

**Start with Option D (Skip) or Option C (Metadata preservation)** until:
1. EventKit attachment support is confirmed
2. There's user demand for this feature
3. Bandwidth/storage implications are understood

This is a "nice to have" feature, not critical for core sync functionality.
