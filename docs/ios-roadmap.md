# iOS integration roadmap

## Goals
- Ship an iOS wrapper around the sync engine with minimal manual setup.
- Provide safe list selection and conflict visibility.
- Store credentials securely and support background sync.

## MVP milestones
1. Authentication
   - Prompt for Vikunja server URL + username/password.
   - `POST /api/v1/login` → JWT, `PUT /api/v1/tokens` → API token.
   - Store token in Keychain; store server URL + settings in app config.
2. List selection UI
   - Load Reminders lists via EventKit.
   - Load Vikunja projects; map by name or allow manual selection.
   - Support "All lists" toggle with explicit confirmation.
3. Sync controls
   - Manual sync button with progress + summary.
   - Dry-run preview in UI for safety.
4. Conflict review
   - Surface conflicts from `task_conflicts` table or JSON report.
   - Allow "pick Reminders" / "pick Vikunja" resolution per conflict.
5. Background sync
   - Use BGAppRefreshTask / BGProcessingTask where allowed.
   - Respect iOS background limits and user-selected sync interval.
   - Status: BGAppRefreshTask scheduling + debug controls implemented; device scheduling validated. Simulator BGTaskScheduler can be unreliable.

## Settings & storage
- Settings stored in app config (UserDefaults or local DB).
- Secrets (Vikunja token) stored in Keychain.
- Sync DB stored in app documents container.

## Open risks
- EventKit authorization (full access vs write-only on newer macOS/iOS).
- Background sync time limits; may require user-initiated sync for reliability.
- Token expiration policy; may need refresh/login fallback.

## Future enhancements
- Push/notification-triggered sync if supported by server/webhooks.
- Conflict diff viewer with per-field merge.
- Optional analytics or logging export for debugging.
