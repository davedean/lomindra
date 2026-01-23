# Issue 015: Intelligent Sync Scheduling

**Severity:** Low
**Status:** Open
**Reported:** 2026-01-23

## Summary

Currently background sync runs at a fixed interval regardless of context. Smarter scheduling could reduce unnecessary syncs (saving battery) while still catching changes promptly when needed.

## Current Behavior

- Fixed interval (user-configurable: 15min to 6hr)
- Syncs at same frequency day and night
- Always does full sync (fetch both sides, compute diff, apply)
- No awareness of network conditions or recent activity

## Proposed Improvements

### 1. Quiet Hours

Skip or reduce sync frequency during sleeping hours:
- Default quiet period: midnight to 6am
- User configurable (or disabled)
- Could still sync once per quiet period to catch overnight agent changes

### 2. Quick Check Mode

Before doing a full sync, do a lightweight check:
- Fetch only timestamps/counts from Vikunja
- Check Reminders modification dates
- Skip full sync if nothing changed since last sync

This would make frequent polling much cheaper.

### 3. Activity-Based Frequency

Adjust frequency based on recent usage:
- More frequent (15min) after app was recently used
- Less frequent (2hr) when phone has been idle
- Triggered sync when app comes to foreground

### 4. Network Awareness

- Prefer WiFi for syncs
- Option to skip sync on cellular
- Handle offline gracefully (don't count as failure)

### 5. Change Detection Notifications

If Vikunja ever supports webhooks to mobile (via push relay):
- Instant sync when server changes
- Polling becomes backup only

## Implementation Notes

### Quick Check API

Would need a lightweight Vikunja endpoint or use existing:
```
GET /api/v1/projects/{id}/tasks?per_page=1&sort_by=updated&order_by=desc
```
Just check if latest `updated` timestamp is newer than last sync.

### iOS Limitations

- Background App Refresh timing is iOS-controlled
- Can't guarantee exact intervals
- These heuristics would help when we DO get execution time

## Priority

Low - current fixed interval works fine. This is optimization for battery/efficiency.

## Related

- Issue 012: Background sync improvements (frequency configuration - DONE)
