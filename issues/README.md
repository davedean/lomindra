# Sync Issues

Tracking issues identified during sync testing.

## Open Issues

### Core Field Sync (High Priority)

| # | Issue | Severity | Complexity | Status |
|---|-------|----------|------------|--------|
| 001 | [Add missing fields (priority, notes, flags)](001-add-missing-fields-to-commontask.md) | Medium-High | Medium | **Complete** (flagged: API limit) |

### Sync Behavior Bugs

| # | Issue | Severity | Complexity | Status |
|---|-------|----------|------------|--------|
| 003 | [Vikunja reminders to alerts](003-vikunja-reminders-to-alerts.md) | Medium | Low | **Resolved** |
| 004 | [Recurrence not syncing](004-recurrence-not-syncing.md) | Medium | Low | **Resolved** |
| 005 | [Spurious start_date added](005-spurious-start-date.md) | Low | Low | **Resolved** |

### Feature Gaps (Lower Priority)

| # | Issue | Severity | Complexity | Status |
|---|-------|----------|------------|--------|
| 006 | [Tags/Labels not syncing](006-tags-labels-not-syncing.md) | Medium | Low | **Open** (opt-in feature) |
| 008 | [URLs not syncing](008-urls-not-syncing.md) | Medium | N/A | **Cannot Fix** (API limit) |
| 009 | [Locations not syncing](009-locations-not-syncing.md) | Low | Low | **Resolved** |
| 010 | [Attachments not syncing](010-attachments-not-syncing.md) | Medium | N/A | **Cannot Fix** (API limit) |

### App Polish / UX

| # | Issue | Severity | Complexity | Status |
|---|-------|----------|------------|--------|
| 011 | [Vikunja Cloud easy onboarding](011-vikunja-cloud-onboarding.md) | Low | Low-Medium | Open (Pending feedback) |
| 012 | [Background sync improvements](012-background-sync-improvements.md) | High | Medium | **Partial** (frequency done) |
| 013 | [Dev mode vs release mode](013-dev-mode-release-mode.md) | Medium | Low | Open |
| 014 | [UI polish and settings](014-ui-polish-settings.md) | Medium | Medium | Open |
| 015 | [Intelligent sync scheduling](015-intelligent-sync-scheduling.md) | Low | Medium | Open |

## Summary

**Quick wins (Low complexity):**
- ~~Issue 004: Recurrence - one guard condition fix~~ **DONE**
- ~~Issue 005: Spurious start_date - match create pattern in update~~ **DONE**
- ~~Issue 003: Alerts - save-fetch-modify-save pattern~~ **DONE**

**Medium effort:**
- ~~Issue 001: Add missing fields~~ **DONE** (flagged status not exposed by EventKit API)

**Recently resolved:**
- ~~Issue 009: Locations~~ **DONE** - preserve location alarms during sync (don't overwrite)

**Opt-in features (workarounds for API limitations):**
- Issue 006: Tags/Labels - Vikunja labels ↔ hashtags in notes/title (opt-in)

**Cannot fix (EventKit API limitations):**
- ~~Issue 008: URLs~~ - `EKReminder.url` is broken (writes invisible in UI, UI writes unreadable)
- ~~Issue 010: Attachments~~ - EventKit has no attachment API for reminders

## Dependencies

```
Issue 001 (notes field) ✅ DONE
    └── Issue 006 (labels use notes for hashtags) - ready to implement
```

## Not Filed

- **Completed tasks not synced** - Intentional behavior
- **Assignees** - Vikunja supports, Reminders doesn't; skip
- **Smart lists** - Out of scope (complex Reminders feature)

## Source

- Original testing report: `../sync-tool-issues.md`
- User notes: `../TODO.md`
