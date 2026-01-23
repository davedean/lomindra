# Issue 009: Locations not syncing

**Severity:** Low
**Status:** Open
**Reported:** 2026-01-23

## Problem

Location-based reminders in Apple Reminders are not synced to Vikunja.

**Reminders → Vikunja:**
- Reminder with location trigger → Vikunja has no location data

**Vikunja → Reminders:**
- Vikunja has no location concept to sync back

## Root Cause Analysis

### EventKit Location APIs

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

**Current Implementation:**
Only handles time-based alarms:
```swift
if alarm.type == "absolute" { ... }
else if alarm.type == "relative" { ... }
// Location alarms completely ignored
```

### Vikunja Location Support

**Vikunja has NO native location support.**

The API only supports time-based reminders:
- `reminder` - absolute timestamp
- `relative_period` - relative offset in seconds
- `relative_to` - base date reference

No location fields, geofence properties, or proximity concepts exist.

## Recommended Approach: Metadata Preservation

**Why metadata preservation:**
- Maintains full round-trip fidelity
- No data loss for power users
- Transparent about Vikunja's limitations
- Location data restored when syncing back to Reminders

**User-Facing Behavior:**
1. Location reminders sync to Vikunja as time-based (keep due date or alarm time)
2. Location metadata stored in sync database
3. When syncing back, location trigger restored from metadata
4. User informed that location not visible/usable in Vikunja

## Required Changes

### 1. Add CommonLocation struct

**File:** `Sources/VikunjaSyncLib/SyncLib.swift`

```swift
public struct CommonLocation: Codable, Equatable {
    public let title: String?
    public let latitude: Double?
    public let longitude: Double?
    public let radius: Double?  // meters
    public let proximity: String?  // "enter", "leave", or "none"

    public init(title: String?, latitude: Double?, longitude: Double?,
                radius: Double?, proximity: String?) {
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.proximity = proximity
    }
}
```

### 2. Add location to CommonTask (optional)

**File:** `Sources/VikunjaSyncLib/SyncLib.swift`

```swift
public struct CommonTask {
    // ... existing fields ...
    public let location: CommonLocation?
}
```

### 3. Extend sync database schema

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (SQLite schema)

```sql
ALTER TABLE task_sync_map ADD COLUMN location_data_json TEXT;
```

**Location JSON format:**
```json
{
  "title": "Home",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "radius": 100,
  "proximity": "enter"
}
```

### 4. Add location extraction helper

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift`

```swift
import CoreLocation  // Required for CLLocationCoordinate2D

func extractLocationFromReminder(_ reminder: EKReminder) -> CommonLocation? {
    guard let alarms = reminder.alarms else { return nil }

    for alarm in alarms {
        if let location = alarm.structuredLocation {
            return CommonLocation(
                title: location.title,
                latitude: location.geoLocation?.latitude,
                longitude: location.geoLocation?.longitude,
                radius: location.radius,
                proximity: proximityToString(alarm.proximity)
            )
        }
    }
    return nil
}

private func proximityToString(_ proximity: EKAlarmProximity) -> String {
    switch proximity {
    case .none: return "none"
    case .enter: return "enter"
    case .leave: return "leave"
    @unknown default: return "none"
    }
}

private func stringToProximity(_ str: String?) -> EKAlarmProximity {
    switch str {
    case "enter": return .enter
    case "leave": return .leave
    default: return .none
    }
}
```

### 5. Add location restoration helper

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift`

```swift
func applyLocationToReminder(_ reminder: EKReminder, location: CommonLocation?) {
    // Remove existing location alarms
    if let alarms = reminder.alarms {
        for alarm in alarms where alarm.structuredLocation != nil {
            reminder.removeAlarm(alarm)
        }
    }

    guard let location = location else { return }

    let ekLocation = EKStructuredLocation(title: location.title ?? "Location")
    if let lat = location.latitude, let lon = location.longitude {
        ekLocation.geoLocation = CLLocation(latitude: lat, longitude: lon)
    }
    if let radius = location.radius {
        ekLocation.radius = radius
    }

    let alarm = EKAlarm()
    alarm.structuredLocation = ekLocation
    alarm.proximity = stringToProximity(location.proximity)
    reminder.addAlarm(alarm)
}
```

### 6. Update fetchReminders()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift` (lines 157-207)

Extract and store location:
```swift
let location = extractLocationFromReminder(reminder)
// Store location in sync record metadata
```

### 7. Update createReminder() / updateReminder()

**File:** `Sources/VikunjaSyncLib/SyncRunner.swift`

Restore location from metadata if present:
```swift
if let locationJson = syncRecord.locationDataJson,
   let location = try? JSONDecoder().decode(CommonLocation.self, from: locationJson.data(using: .utf8)!) {
    applyLocationToReminder(reminder, location: location)
}
```

## Alternative Approaches (Not Recommended)

### Option A: Text Representation
- Serialize as: "📍 Home (50m, arrive)"
- Store in task notes
- **Con:** Cannot recreate geofence on round-trip

### Option C: Skip Entirely
- Document as unsupported
- **Con:** Silent data loss

## Framework Import Note

Location code requires:
```swift
import EventKit
import CoreLocation  // For CLLocationCoordinate2D, CLLocation
```

## Acceptance Criteria

- [ ] Location reminders extracted from EventKit without errors
- [ ] Location metadata stored in sync database
- [ ] Location reminders round-trip correctly (Reminders → sync DB → Reminders)
- [ ] Location triggers don't cause sync errors
- [ ] Vikunja syncs (without location) work normally
- [ ] Documentation updated with location limitations
- [ ] Unit tests for location serialization/deserialization
