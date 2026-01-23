# Worklog

## Session Summary
- Created a full MVP two-way sync CLI (`scripts/mvp_sync.swift`) for a single Reminders list and Vikunja project.
- Added a deterministic seed harness (`scripts/seed_test_data.swift` + `scripts/seed_tasks.json`) to create repeatable test data.
- Captured platform behavior in docs and refined mapping/compatibility rules across Reminders and Vikunja.
- Implemented conflict handling, mapping persistence, and safety rules around deletes and completed items.

## Key Changes
- Added data-model docs: `docs/apple-reminders-model.md`, `docs/vikunja-model.md`, `docs/common-schema.md`, and `docs/translation-rules.md`.
- Implemented sync metadata storage design in `docs/sync-metadata-storage.md`.
- Built EventKit probe scripts and list helpers in `scripts/`.
- Added `AGENTS.md` contributor guide and updated `PROJECT_PLAN.md` with MVP scope.

## MVP Sync Features
- Two-way create/update/delete with dry-run and apply mode.
- SQLite mapping (`sync.db`) with last-seen timestamps, date-only flags, and inferred due handling.
- Alarms and basic recurrence support in both directions.
- Conflict detection based on last-seen timestamps.
- Delete policy: only delete unmapped missing items if uncompleted; completed items are preserved.

## Test Harness
- `scripts/seed_test_data.swift` seeds both systems from `scripts/seed_tasks.json`.
- `--reset` cleans existing `seed:` data in both systems before reseeding.
- Dry-run/Apply flow verified end-to-end.

## Current State
- Dry-run shows clean sync after apply for seeded datasets.
- Remaining optional enhancements: seed-only filter, richer recurrence support, conflict detail output options.

## Latest Updates
- Added iOS app scaffolding in `ios/LomindraApp` with login, list selection, and sync UI.
- Implemented Vikunja login fallbacks for token creation and response decoding in the iOS client.
- Filtered Reminders lists to standard, writable lists and added per-list sync toggles with project mapping.
- Added `scripts/login_probe.swift` for API login checks using env vars.
- Updated `PROJECT_PLAN.md` to mark iOS app startup and login progress; added build-validation note in `AGENTS.md`.

## 2026-01-23: Issue Tracking & Bug Fixes
- Created `issues/` directory with 8 tracked issues from sync testing
- Performed comprehensive field audit (`issues/000-field-audit.md`)
- **Fixed Issue 004: Recurrence not syncing**
  - Root cause: Guard required both `repeat_after` AND `repeat_mode` to be non-nil
  - Vikunja often returns `repeat_mode: null` for time-based recurrence
  - Added `parseVikunjaRecurrence()` function to `SyncLib.swift` with nil-defaulting to 0
  - Added 8 unit tests covering all recurrence scenarios
  - Updated `SyncRunner.swift` to use the new function
- **Fixed Issue 003: Alerts not syncing to Reminders**
  - Root cause: EventKit may discard alarms added before first save
  - Implemented save-fetch-modify-save pattern in `createReminder()`
  - Save reminder first, re-fetch by ID, add alarms, save again
- **Fixed Issue 005: Spurious start_date added on sync**
  - Root cause: Unconditional assignment in `updateReminder()` didn't properly clear nil dates
  - Changed to explicit guarded assignments with nil clearing
- **Implemented Issue 001 (partial): Missing fields in CommonTask**
  - Added priority, notes, completedAt fields to CommonTask
  - Priority mapping: Reminders (0/1/5/9) ↔ Vikunja (0-3)
  - Notes: EKReminder.notes ↔ Task.description
  - CompletedAt: EKReminder.completionDate ↔ Task.done_at
  - isFlagged: Vikunja→Reminders works; Reminders→Vikunja hardcoded false (API research needed)
  - Added unit tests for priority mapping and diff detection
- **Removed legacy scripts**
  - Deleted `scripts/sync_lib.swift`, `scripts/mvp_sync.swift`, `scripts/sync_tests.swift`
  - Swift Package (`Sources/`) is now the only sync implementation
  - Updated CLAUDE.md, AGENTS.md, and issue files to remove legacy references
- **Resolved Issue 001: isFlagged API limitation**
  - Verified Apple Reminders "flagged" status is NOT exposed via EventKit API
  - Checked macOS SDK headers - no `isFlagged` property on `EKReminder` or `EKCalendarItem`
  - Documented limitation: Vikunja `is_favorite` cannot sync to/from Reminders flags
  - Issue 001 marked complete (3/4 fields working; 1 blocked by Apple API)
- **Fixed Issue 008: URLs not syncing**
  - Added `url: String?` field to CommonTask
  - URLs embedded in Vikunja description using `---URL_START---`/`---URL_END---` markers
  - Extract URL from description on fetch, embed on create/update
  - EKReminder.url property used for Reminders side
  - Added 16 unit tests for URL embedding/extraction and diff detection
- **Integration test enhancements & nil vs empty string fix**
  - Ran full integration test using `scripts/run_seed_tests.sh`
  - Enhanced `seed_tasks.json` with priority, notes, and URL test cases (9 new tasks)
  - Updated `seed_test_data.swift` to support priority, notes, url fields
  - Discovered sync instability: 4 tasks needed spurious updates post-apply
  - Root cause: `tasksDiffer()` compared `nil` to `""` (empty string) as different
  - Fix: Normalize empty strings to nil before comparing notes and url fields
  - Fix: `stripUrlFromDescription()` now returns nil for empty/whitespace strings
  - Integration test now reaches steady state (0 updates post-apply)
