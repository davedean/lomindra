# Multi-list configuration

See `docs/settings-format.md` for the full settings file format and overrides.
Auth notes (login + token creation) are in `docs/settings-format.md` and `docs/api-notes.md`.

## Config keys
- `sync_all_lists`: `true` to sync every Reminders list (default: false).
- `list_map_path`: path to a mapping file (default: `list_map.txt` if present).

## Mapping file format
Use `key: value` pairs (colon-separated) so values can include spaces.

- Key: Reminders list identifier or list title (case-insensitive match).
- Value: Vikunja project id (numeric) or project title.

Example:
```
BA7C6D2C-1234-5678-ABCD-1A2B3C4D5E6F: 12
Work: Work Projects
```

## Auto-create behavior
- When a project name is provided or inferred and no project exists, the project
  is created on `--apply`.
- For dry-runs, missing projects are reported and treated as empty on the Vikunja side.
