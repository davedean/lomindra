# Sync Issues

Tracking issues identified during sync testing.

## Open Issues

### Core Field Sync (High Priority)

| # | Issue | Severity | Complexity | Status |
|---|-------|----------|------------|--------|
| 001 | [Add missing fields (priority, notes, flags)](001-add-missing-fields-to-commontask.md) | Medium-High | Medium | Open |

### Sync Behavior Bugs

| # | Issue | Severity | Complexity | Status |
|---|-------|----------|------------|--------|
| 003 | [Vikunja reminders to alerts](003-vikunja-reminders-to-alerts.md) | Medium | Low | **Resolved** |
| 004 | [Recurrence not syncing](004-recurrence-not-syncing.md) | Medium | Low | **Resolved** |
| 005 | [Spurious start_date added](005-spurious-start-date.md) | Low | Low | Open |

### Feature Gaps (Lower Priority)

| # | Issue | Severity | Complexity | Status |
|---|-------|----------|------------|--------|
| 006 | [Tags/Labels not syncing](006-tags-labels-not-syncing.md) | Medium | Medium-High | Open |
| 008 | [URLs not syncing](008-urls-not-syncing.md) | Medium | Low-Medium | Open |
| 009 | [Locations not syncing](009-locations-not-syncing.md) | Low | High | Open |
| 010 | [Attachments not syncing](010-attachments-not-syncing.md) | Medium | High | Open (Research) |

## Summary

**Quick wins (Low complexity):**
- ~~Issue 004: Recurrence - one guard condition fix~~ **DONE**
- Issue 005: Spurious start_date - match create pattern in update
- ~~Issue 003: Alerts - save-fetch-modify-save pattern~~ **DONE**

**Medium effort:**
- Issue 001: Add missing fields - adds priority, notes, flags, completedAt to CommonTask (~12 locations)
- Issue 008: URLs - add field, embed in description

**Needs design decision:**
- Issue 006: Tags/Labels - different models between systems (hashtag encoding recommended)
- Issue 009: Locations - fundamental feature gap (metadata preservation recommended)
- Issue 010: Attachments - requires research into EventKit attachment APIs

## Dependencies

```
Issue 001 (notes field)
    ├── Issue 006 (labels use notes for hashtags)
    └── Issue 008 (URLs embed in description/notes)
```

Complete Issue 001 before starting 006 or 008.

## Not Filed

- **Completed tasks not synced** - Intentional behavior
- **Assignees** - Vikunja supports, Reminders doesn't; skip
- **Smart lists** - Out of scope (complex Reminders feature)

## Source

- Original testing report: `../sync-tool-issues.md`
- User notes: `../TODO.md`
