# Settings format

The sync CLI reads configuration from two local key/value files plus optional
environment overrides. These files are intentionally simple and should not be
committed with real tokens.

## File format
Each file uses `key: value` pairs (colon-separated). Values can include spaces.

Example:
```
reminders_list_id: BA7C6D2C-1234-5678-ABCD-1A2B3C4D5E6F
sync_all_lists: false
sync_db_path: sync.db
list_map_path: list_map.txt
```

## apple_details.txt
Location: project root.

Keys:
- `reminders_list_id`: Reminders list identifier for single-list mode.
- `sync_all_lists`: `true` to sync every list (default: false).
- `list_map_path`: path to list mapping file (default: `list_map.txt` if present).
- `sync_db_path`: path to the SQLite sync DB (default: `sync.db`).

## vikunja_details.txt
Location: project root.

Keys:
- `api_base`: Vikunja base URL (e.g., `https://vikunja.example/api/v1`).
- `token`: Vikunja API token.
- `project_id`: Project ID for single-list mode.

## App login flow (iOS)
Vikunja supports username/password login plus API token creation:
- `POST /api/v1/login` with `user.Login` payload returns `auth.Token` (JWT).
- `PUT /api/v1/tokens` with the JWT can create an API token (`models.APIToken`).
  The `token` value is only returned at creation time.

For iOS, the app can prompt for username/password, exchange for a JWT, create
an API token, and store that token in the app's secure storage for sync.

### Suggested token permissions
Token permissions are defined by the `/api/v1/routes` endpoint. For the current
sync implementation (projects + tasks CRUD), the API token should allow (as
returned by `/api/v1/routes` on our instance):
- `projects`: `read_all`, `create`, `update`, `delete` (if you want to allow project creation/deletion).
- `tasks`: `read_all`, `create`, `update`, `delete`.

Exact permission keys can be confirmed by calling `/api/v1/routes`.

## List mapping
If you are not using `sync_all_lists`, you can map specific Reminders lists to
Vikunja projects. See `docs/multi-list-config.md` for format and examples.

## Environment overrides
- `SYNC_ALL_LISTS`: overrides `sync_all_lists`.
- `LIST_MAP_PATH`: overrides `list_map_path`.
- `SYNC_DB_PATH`: overrides `sync_db_path`.

## Conflict handling options
These are CLI flags (not file settings):
- `--conflict-report <path>`: write a JSON report of conflicts.
- `--resolve-conflicts=reminders|vikunja|last-write-wins`: resolve conflicts during `--apply`.
