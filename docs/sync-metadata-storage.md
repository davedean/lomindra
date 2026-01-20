# Sync Metadata Storage

Recommended: SQLite (local file).

## Why SQLite
- Stronger consistency for two-way sync than JSON files.
- Easy indexed lookups by reminder ID, Vikunja ID, and list/project ID.
- Supports concurrent reads and safe updates during sync loops.
- Migration-friendly via versioned schema.

## Proposed Schema (MVP)

```
-- One row per synced task mapping.
CREATE TABLE IF NOT EXISTS task_sync_map (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reminders_id TEXT NOT NULL,
  vikunja_id INTEGER NOT NULL,
  list_reminders_id TEXT NOT NULL,
  project_id INTEGER NOT NULL,
  date_only_due INTEGER DEFAULT 0,
  date_only_start INTEGER DEFAULT 0,
  relative_alarm_base_json TEXT,
  last_synced_at TEXT,
  last_seen_modified_reminders TEXT,
  last_seen_modified_vikunja TEXT,
  sync_version INTEGER NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_task_map_reminders
  ON task_sync_map (reminders_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_task_map_vikunja
  ON task_sync_map (vikunja_id);

CREATE INDEX IF NOT EXISTS idx_task_map_list
  ON task_sync_map (list_reminders_id);

CREATE INDEX IF NOT EXISTS idx_task_map_project
  ON task_sync_map (project_id);
```

## Notes
- `relative_alarm_base_json` stores a small JSON object keyed by alarm hash.
- Timestamps are stored as ISO-8601 strings for portability.
- `sync_version` allows forward-compatible migrations.

