# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Two-way sync between Apple Reminders (macOS EventKit) and Vikunja (open-source task manager). Currently in Phase 4 (MVP) - single list sync is functional.

## Build and Run Commands

### Swift Package (preferred)
```bash
# Build
swift build

# Run tests
swift test

# Run the sync CLI (dry-run)
swift run mvp_sync

# Run the sync CLI (apply changes)
swift run mvp_sync --apply
```

### Utility scripts
```bash
# List Reminders lists to find identifiers
swiftc -o /tmp/list_reminders_lists scripts/list_reminders_lists.swift && /tmp/list_reminders_lists

# Seed deterministic test data (use --reset to clear existing)
swiftc -o /tmp/seed_test_data scripts/seed_test_data.swift && /tmp/seed_test_data --reset

# Run EventKit behavior probe
bash scripts/run_reminders_probe.sh && /tmp/RemindersProbe.app/Contents/MacOS/RemindersProbe
```

## Architecture

**Data flow**: Reminders ↔ CommonTask ↔ Vikunja

The sync uses a neutral `CommonTask` schema to translate between systems. All transformations go through this intermediate representation.

**Code organization** (Swift Package):
- `Sources/VikunjaSyncLib/` - Pure functions and data models (testable, no I/O)
- `Sources/mvp_sync/` - EventKit, Vikunja API, SQLite operations, CLI entry point
- `Tests/VikunjaSyncLibTests/` - XCTest unit tests
- `scripts/` - Utility scripts (list helpers, test data seeding, probes)

**Key components in `SyncLib.swift`**:
- `CommonTask`, `CommonAlarm`, `CommonRecurrence` - neutral data structures
- `SyncRecord` - mapping metadata between Reminders ID and Vikunja ID
- `SyncPlan` - computed diff (creates, updates, deletes, conflicts)
- `diffTasks()` - core sync logic that computes the sync plan

**Key components in `SyncRunner.swift`**:
- `fetchReminders()` - EventKit API integration
- `fetchVikunjaTasks()` - Vikunja HTTP API calls
- SQLite functions for mapping persistence
- Apply functions (create/update/delete in both systems)

**SQLite mapping (`sync.db`)**: Stores ID mappings, last-seen timestamps, and metadata flags (date-only, inferred due) for conflict detection and round-trip preservation.

**Translation rules** (see `docs/translation-rules.md`):
- Priority: Reminders (1/5/9/0) ↔ Vikunja (3/2/1/0)
- Date-only: Stored as 00:00 in Vikunja, with `dateOnly` flag in metadata
- Alarms: Absolute and relative supported; relative defaults to `due` base
- Recurrence: Daily/weekly/monthly supported; complex rules stored in notes

## Configuration Files

- `apple_details.txt` - contains `reminders_list_id`
- `vikunja_details.txt` - contains `api_base`, `token`, `project_id`, `username`

These contain secrets - do not commit changes with real tokens.

## Key Design Decisions

- **Swift required**: EventKit is macOS-only
- **Last-write-wins**: Initial conflict policy based on `lastModifiedDate`
- **Delete safety**: Only deletes unmapped missing items if uncompleted; completed items preserved
- **Self-signed cert**: Vikunja instance uses self-signed cert; scripts accept it explicitly
