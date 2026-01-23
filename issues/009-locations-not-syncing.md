# Issue 009: Locations not syncing

**Severity:** Low
**Status:** Resolved
**Reported:** 2026-01-23
**Resolved:** 2026-01-23

## Resolution

**Approach: Preserve location-based alarms during sync (don't overwrite them)**

Instead of complex metadata storage and rehydration, we simply don't touch location-based alarms when syncing from Vikunja back to Reminders.

**Implementation:** In `SyncRunner.swift`, when updating a reminder's alarms, we now skip alarms that have `structuredLocation` set:

```swift
// Remove only time-based alarms; preserve location-based alarms
// (Vikunja doesn't support locations, so we keep them untouched)
if let existingAlarms = item.alarms {
    for alarm in existingAlarms {
        if alarm.structuredLocation == nil {
            item.removeAlarm(alarm)
        }
    }
}
```

**Behavior:**
- Location triggers remain on reminders after syncing
- Time-based alarms sync normally between systems
- Vikunja doesn't see location data (it can't store it anyway)
- Round-trip: Reminder with location → sync to Vikunja → sync back → location still intact

## Problem

Location-based reminders in Apple Reminders were having their location triggers removed during sync.

**Reminders → Vikunja:**
- Reminder with location trigger → Vikunja has no location data (expected - Vikunja doesn't support locations)

**Vikunja → Reminders:**
- When syncing back, all alarms were replaced, removing location triggers (bug)

## Root Cause

The `updateReminder()` function was removing ALL alarms before adding back the synced time-based alarms:

```swift
// Old behavior - removed ALL alarms including location
if let existingAlarms = item.alarms {
    for alarm in existingAlarms {
        item.removeAlarm(alarm)  // ← This killed location alarms!
    }
}
```

## EventKit Location APIs (Reference)

Apple Reminders has sophisticated location-based triggering through `EKAlarm`:

**EKAlarm properties:**
- `proximity` (EKAlarmProximity enum):
  - `.none` - no geofence
  - `.enter` - trigger on arrival
  - `.leave` - trigger on departure

- `structuredLocation` (EKStructuredLocation):
  - `title` (String?) - friendly name ("Home", "Work")
  - `geoLocation` (CLLocationCoordinate2D) - latitude/longitude
  - `radius` (CLLocationDistance) - geofence radius in meters

## Vikunja Location Support

**Vikunja has NO native location support.**

The API only supports time-based reminders:
- `reminder` - absolute timestamp
- `relative_period` - relative offset in seconds
- `relative_to` - base date reference

No location fields, geofence properties, or proximity concepts exist.

## Why This Approach

The simpler "preserve existing location alarms" approach was chosen over metadata storage because:

1. **Much simpler** - One guard condition vs. database schema changes + serialization
2. **No data migration** - No need to add columns to sync database
3. **Same result** - Location triggers preserved through round-trip
4. **Less code to maintain** - No location extraction/restoration logic needed

The tradeoff is that locations created in Reminders stay in Reminders only - we can't create location reminders from Vikunja. But since Vikunja has no location concept, this isn't a loss.

## Acceptance Criteria

- [x] Location reminders preserve their location trigger after sync
- [x] Time-based alarms sync normally
- [x] No errors when syncing reminders with location triggers
- [x] Tests pass
