# Lomindra

Two-way sync between Apple Reminders and Vikunja, with:
- Swift Package core sync engine
- macOS CLI utilities and probes
- iOS SwiftUI wrapper app

This repo is intended for local, user-driven sync (not a server daemon).

## Project layout
- `Sources/` and `Tests/`: core sync engine (Swift Package)
- `scripts/`: MVP sync CLI + EventKit probes
- `ios/`: SwiftUI app + XcodeGen project
- `docs/`: design notes and API references

## Quick start (Swift Package)
Build:
```bash
swift build
```

Run tests:
```bash
swift test
```

Run sync (dry-run):
```bash
swift run mvp_sync
```

Run sync (apply):
```bash
swift run mvp_sync --apply
```

## iOS app
Open the Xcode project:
```bash
open ios/LomindraApp.xcodeproj
```

Notes:
- The app handles login, list selection, and manual sync.
- Background sync uses BGTaskScheduler; device testing is more reliable than Simulator.

## Local config and secrets
These files are local-only and ignored by git:
- `vikunja_details.txt` (token + server settings)
- `apple_details.txt`

Do not commit real tokens or URLs with embedded credentials.

## Troubleshooting
- If background scheduling behaves oddly in Simulator, validate on a real device.
- If login fails, try the probe:
  ```bash
  VIKUNJA_API_BASE="https://your-host" \
  VIKUNJA_USERNAME="user" \
  VIKUNJA_PASSWORD="pass" \
  swift scripts/login_probe.swift
  ```

## Docs
Start with:
- `docs/ios-setup.md`
- `docs/settings-format.md`
- `docs/ios-roadmap.md`
