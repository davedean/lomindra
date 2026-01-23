# Issue 011: Support Vikunja Cloud Easy Onboarding

**Severity:** Low (UX improvement)
**Status:** Open (Pending developer feedback)
**Reported:** 2026-01-23

## Summary

Add streamlined onboarding for Vikunja Cloud users, including a toggle/checkbox to auto-configure the API base URL and optional username/password authentication flow to automatically generate an API token.

## Background

Vikunja Cloud uses the same API as self-hosted Vikunja instances. The only difference is the base URL:
- **Self-hosted:** User-provided (e.g., `https://tasks.example.com/api/v1`)
- **Vikunja Cloud:** `https://app.vikunja.cloud/api/v1`

Currently, users must manually:
1. Know/find the correct API base URL
2. Manually generate an API token in Vikunja's web UI
3. Copy the token into our configuration

This is error-prone, especially for non-technical users.

## Proposed Features

### Feature A: "Use Vikunja Cloud" Toggle

**Complexity:** Very Low

A simple checkbox/toggle that, when enabled:
- Auto-fills `api_base` to `https://app.vikunja.cloud/api/v1`
- Hides/disables the manual URL input field
- Clearly indicates the user is connecting to the official hosted service

**Benefits:**
- Eliminates URL typos
- Makes Cloud the easy default path
- Self-hosted users can uncheck and enter their URL

### Feature B: Username/Password Token Generation

**Complexity:** Medium

Instead of requiring users to manually create an API token, allow them to enter username/password and automatically generate a token.

**API Flow:**
```
1. POST /api/v1/login
   Body: { "username": "user", "password": "pass" }
   Response: { "token": "<JWT>" }

2. PUT /api/v1/tokens
   Header: Authorization: Bearer <JWT>
   Body: { "title": "Vikunja Sync App", "permissions": {...} }
   Response: { "token": "<API_TOKEN>" }  // Only returned at creation!

3. Store API token securely, discard JWT and credentials
```

**Security Considerations:**
- Credentials are never stored - only used once to obtain token
- JWT is ephemeral, discarded after token creation
- API token stored in secure storage (Keychain on macOS/iOS)
- Token should have minimal required permissions:
  - `projects`: `read_all`, `create`, `update`, `delete`
  - `tasks`: `read_all`, `create`, `update`, `delete`

**Benefits:**
- Users never need to navigate Vikunja's settings
- Familiar username/password flow
- Automatic permission scoping

### Feature C: Combined Flow (Recommended)

The ideal onboarding experience:

```
┌─────────────────────────────────────────┐
│  Connect to Vikunja                     │
├─────────────────────────────────────────┤
│  ☑ Use Vikunja Cloud                    │
│    (or enter custom URL below)          │
│                                         │
│  URL: [https://app.vikunja.cloud/api/v1]│
│       (disabled when Cloud checked)     │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  Username: [________________]           │
│  Password: [________________]           │
│                                         │
│  [Connect]                              │
│                                         │
│  ─── OR ───                             │
│                                         │
│  Have an API token?                     │
│  API Token: [________________]          │
│                                         │
│  [Connect with Token]                   │
└─────────────────────────────────────────┘
```

## Questions for Vikunja Developers

Before implementing, we should confirm with Vikunja developers:

1. **Is this workflow approved for Vikunja Cloud?**
   - Are third-party apps encouraged to use the login → token generation flow?
   - Any rate limits or abuse prevention we should be aware of?

2. **Token permissions:**
   - What's the recommended permission set for a sync app?
   - Should we request minimal permissions or broader access?

3. **Token naming convention:**
   - Should we use a specific title format (e.g., "Vikunja Sync - macOS")?
   - Is there a way to identify/revoke tokens created by our app?

4. **Cloud-specific considerations:**
   - Any differences in Cloud API behavior we should know about?
   - Is there a test/sandbox environment for development?

5. **OAuth consideration:**
   - Is OAuth supported/planned for Vikunja Cloud?
   - Would that be preferred over username/password flow?

## Implementation Notes

### Required Changes

1. **Configuration UI:**
   - Add Vikunja Cloud toggle
   - Conditional URL field
   - Username/password fields with "Connect" action
   - Alternative API token field

2. **New API Functions:**
   ```swift
   func loginVikunja(apiBase: String, username: String, password: String) throws -> String  // Returns JWT
   func createVikunjaToken(apiBase: String, jwt: String, title: String) throws -> String    // Returns API token
   ```

3. **Secure Storage:**
   - macOS: Keychain
   - iOS: Keychain (already planned per ios-roadmap.md)

4. **Error Handling:**
   - Invalid credentials
   - Account locked/2FA required
   - Token creation failed
   - Network errors

### Self-Hosted Compatibility

The same flow should work for self-hosted instances:
- Uncheck "Vikunja Cloud"
- Enter custom URL
- Use same username/password or token flow

## Acceptance Criteria

- [ ] "Use Vikunja Cloud" toggle auto-fills correct URL
- [ ] Username/password login successfully obtains JWT
- [ ] API token created with appropriate permissions
- [ ] Token stored securely (not in plain text config)
- [ ] Credentials not persisted after token generation
- [ ] Clear error messages for auth failures
- [ ] Flow works for both Cloud and self-hosted
- [ ] Unit tests for login/token creation
- [ ] Integration test against Vikunja Cloud (manual)

## Related

- `docs/api-notes.md` - Authentication flow documentation
- `docs/ios-roadmap.md` - iOS Keychain storage plans
- `docs/settings-format.md` - Current configuration format
