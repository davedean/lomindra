# Lomindra

⚠️ **DANGER: THIS IS PRE-ALPHA SOFTWARE** ⚠️

**IF YOU USE THIS SOFTWARE, YOU SHOULD ASSUME IT WILL:**
- Fail to do what you want
- Destroy your existing data in both Apple Reminders and Vikunja
- Brick your devices or otherwise cause irreparable harm
- Lose your data permanently

**This is early development software with NO safety guarantees.** Run at your own risk. Do not use this on production data or critical tasks. Back up everything before attempting to use it.

---

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

## Screenshot

<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-01-20 at 18 19 40" src="https://github.com/user-attachments/assets/932175d5-45fe-4f2e-97c7-33768cff9df3" />


## Docs
Start with:
- `docs/ios-setup.md`
- `docs/settings-format.md`
- `docs/ios-roadmap.md`
