# API notes

## Auth / tokens (Vikunja)
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
