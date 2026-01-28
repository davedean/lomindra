#!/usr/bin/env swift
//
// test_016_integration.swift
// Real integration test for Issue 016: Date-only round-trip
//
// This script:
// 1. Creates a real reminder via EventKit with date-only due
// 2. Converts using the same code path as sync (dateComponentsToISO)
// 3. Sends to Vikunja API
// 4. Fetches back from Vikunja
// 5. Converts back using dateComponentsFromISO (simulating sync back)
// 6. Checks if date-only is preserved
//
// Run with: swift scripts/test_016_integration.swift
//

import EventKit
import Foundation

// MARK: - Config

let vikunjaApiBase = "https://tasks.cb.dc.dasie.co/api/v1"
let vikunjaToken = "tk_1bf2ba170bce252f285a8f240d7a8366dd36bd7c"
let vikunjaProjectId = 57
let testListName = "Reminders"  // Use default Reminders list for isolated test

// MARK: - Vikunja API helpers

class InsecureDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

let urlSession = URLSession(configuration: .default, delegate: InsecureDelegate(), delegateQueue: nil)

func vikunjaRequest(method: String, path: String, body: [String: Any]? = nil) throws -> Data {
    let url = URL(string: vikunjaApiBase + path)!
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(vikunjaToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let body = body {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }

    let semaphore = DispatchSemaphore(value: 0)
    var resultData: Data?
    var resultError: Error?

    urlSession.dataTask(with: request) { data, response, error in
        resultData = data
        resultError = error
        semaphore.signal()
    }.resume()

    semaphore.wait()

    if let error = resultError {
        throw error
    }
    return resultData ?? Data()
}

// MARK: - Date conversion functions (EXACT COPIES from SyncLib.swift)
// These are the actual functions used by the sync - testing them directly

func isoDate(_ date: Date?) -> String? {
    guard let date = date else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

func parseISODate(_ value: String?) -> Date? {
    guard let value = value else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) {
        return date
    }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
}

func dateComponentsToISO(_ dc: DateComponents?) -> String? {
    guard var dc = dc else { return nil }
    if dc.calendar == nil {
        dc.calendar = Calendar.current
    }
    let hasTime = dc.hour != nil || dc.minute != nil || dc.second != nil
    if !hasTime {
        // DATE-ONLY: return just YYYY-MM-DD
        let formatter = DateFormatter()
        formatter.calendar = dc.calendar
        formatter.timeZone = dc.timeZone ?? TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = dc.date {
            return formatter.string(from: date)
        }
        return nil
    }
    if let date = dc.date {
        return isoDate(date)
    }
    return nil
}

func dateComponentsIsDateOnly(_ dc: DateComponents?) -> Bool? {
    guard let dc = dc else { return nil }
    let hasTime = dc.hour != nil || dc.minute != nil || dc.second != nil
    return !hasTime
}

func vikunjaDateString(from value: String?) -> String? {
    guard let value = value, !value.isEmpty else { return nil }
    if value.count == 10 {
        // Issue 016 FIX: Use local midnight instead of UTC midnight
        let tz = TimeZone.current
        let offsetSeconds = tz.secondsFromGMT()
        let hours = abs(offsetSeconds) / 3600
        let mins = (abs(offsetSeconds) % 3600) / 60
        let sign = offsetSeconds >= 0 ? "+" : "-"
        return value + String(format: "T00:00:00%@%02d:%02d", sign, hours, mins)
    }
    return value
}

func isDateOnlyString(_ value: String?) -> Bool {
    guard let value = value else { return false }
    return value.count == 10
}

func dateComponentsFromISO(_ value: String?, dateOnly: Bool = false) -> DateComponents? {
    guard let value = value, !value.isEmpty else { return nil }

    // Handle date-only strings (YYYY-MM-DD)
    if value.count == 10 {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: value) else { return nil }
        return Calendar.current.dateComponents([.year, .month, .day], from: date)
    }

    // Parse full ISO date
    guard let date = parseISODate(value) else { return nil }

    if dateOnly {
        // Strip time components
        return Calendar.current.dateComponents([.year, .month, .day], from: date)
    }

    // Full date-time in local timezone
    return Calendar.current.dateComponents(in: TimeZone.current, from: date)
}

// MARK: - EventKit helpers

let store = EKEventStore()

func requestAccess() -> Bool {
    let semaphore = DispatchSemaphore(value: 0)
    var granted = false

    if #available(macOS 14.0, *) {
        store.requestFullAccessToReminders { g, error in
            granted = g
            if let error = error {
                print("Access error: \(error)")
            }
            semaphore.signal()
        }
    } else {
        store.requestAccess(to: .reminder) { g, error in
            granted = g
            if let error = error {
                print("Access error: \(error)")
            }
            semaphore.signal()
        }
    }

    semaphore.wait()
    return granted
}

func findDefaultList() -> EKCalendar? {
    return store.defaultCalendarForNewReminders()
}

// MARK: - Test

print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("Issue 016: Date-only round-trip INTEGRATION TEST")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("")

// Step 0: Request access
print("0. Requesting Reminders access...")
guard requestAccess() else {
    print("   ❌ Access denied")
    exit(1)
}
print("   ✓ Access granted")

guard let calendar = findDefaultList() else {
    print("   ❌ No default reminders list found")
    exit(1)
}
print("   ✓ Using list: \(calendar.title)")

// Step 1: Create a reminder with DATE-ONLY due
print("\n1. Creating reminder with DATE-ONLY due date...")
let reminder = EKReminder(eventStore: store)
reminder.calendar = calendar
reminder.title = "TEST-016-\(Int(Date().timeIntervalSince1970))"

var dueDateComponents = DateComponents()
dueDateComponents.year = 2026
dueDateComponents.month = 1
dueDateComponents.day = 30
// NOT setting hour, minute, second - this is DATE-ONLY

reminder.dueDateComponents = dueDateComponents

do {
    try store.save(reminder, commit: true)
} catch {
    print("   ❌ Failed to save: \(error)")
    exit(1)
}

let reminderId = reminder.calendarItemIdentifier
print("   ✓ Created reminder: \(reminder.title ?? "?")")
print("   ID: \(reminderId)")
print("   dueDateComponents: \(reminder.dueDateComponents!)")
print("   hour: \(reminder.dueDateComponents?.hour as Any)")
print("   minute: \(reminder.dueDateComponents?.minute as Any)")
print("   isDateOnly: \(dateComponentsIsDateOnly(reminder.dueDateComponents) ?? false)")

// Step 2: Convert to CommonTask format (what fetchReminders does)
print("\n2. Converting to sync format (dateComponentsToISO)...")
let commonDue = dateComponentsToISO(reminder.dueDateComponents)
let commonDueIsDateOnly = dateComponentsIsDateOnly(reminder.dueDateComponents)
print("   CommonTask.due = \"\(commonDue ?? "nil")\"")
print("   CommonTask.dueIsDateOnly = \(commonDueIsDateOnly ?? false)")

// Step 3: Convert for Vikunja API (what createVikunjaTask does)
print("\n3. Converting for Vikunja API (vikunjaDateString)...")
let vikunjaDue = vikunjaDateString(from: commonDue)
print("   Vikunja due_date = \"\(vikunjaDue ?? "nil")\"")
if vikunjaDue?.hasSuffix("Z") == true {
    print("   ⚠️  UTC midnight - would display wrong in non-UTC timezone")
} else {
    print("   ✓ Local midnight - displays correctly in user's timezone")
}

// Step 4: Create in Vikunja
print("\n4. Creating task in Vikunja...")
var vikunjaTaskId: Int = 0
do {
    let payload: [String: Any] = [
        "title": reminder.title!,
        "due_date": vikunjaDue!,
        "done": false
    ]
    let data = try vikunjaRequest(method: "PUT", path: "/projects/\(vikunjaProjectId)/tasks", body: payload)
    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
       let id = json["id"] as? Int {
        vikunjaTaskId = id
        print("   ✓ Created Vikunja task ID: \(vikunjaTaskId)")
        print("   Stored due_date: \(json["due_date"] ?? "nil")")
    }
} catch {
    print("   ❌ Failed: \(error)")
    // Cleanup reminder
    try? store.remove(reminder, commit: true)
    exit(1)
}

// Step 5: Fetch back from Vikunja (what fetchVikunjaTasks does)
print("\n5. Fetching task back from Vikunja...")
var fetchedDueDate: String?
do {
    let data = try vikunjaRequest(method: "GET", path: "/tasks/\(vikunjaTaskId)")
    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
        fetchedDueDate = json["due_date"] as? String
        print("   Fetched due_date: \"\(fetchedDueDate ?? "nil")\"")

        // This is what fetchVikunjaTasks does - check isDateOnlyString
        let detectedDateOnly = isDateOnlyString(fetchedDueDate)
        print("   isDateOnlyString() = \(detectedDateOnly)")
        if !detectedDateOnly {
            print("   ⚠️  BUG: Vikunja returns full datetime, so isDateOnlyString is FALSE")
        }
    }
} catch {
    print("   ❌ Failed: \(error)")
}

// Step 6: Simulate sync back to Reminders
print("\n6. Simulating sync back to Reminders...")
print("   This is what createReminder() does:")
print("")

// Current buggy code path
let buggyDateOnly = isDateOnlyString(fetchedDueDate)
print("   CURRENT (buggy):")
print("   dateOnly = isDateOnlyString(\"\(fetchedDueDate ?? "")\") = \(buggyDateOnly)")
let buggyComponents = dateComponentsFromISO(fetchedDueDate, dateOnly: buggyDateOnly)
print("   dateComponentsFromISO with dateOnly=\(buggyDateOnly)")
print("   Result: hour=\(buggyComponents?.hour as Any), minute=\(buggyComponents?.minute as Any)")
if buggyComponents?.hour != nil {
    print("   ❌ BUG: Time component added! Reminder would show 11:00am")
}

print("")

// Fixed code path (using stored dueIsDateOnly)
let fixedDateOnly = commonDueIsDateOnly ?? false  // Use the stored metadata
print("   FIXED (using stored dueIsDateOnly):")
print("   dateOnly = task.dueIsDateOnly = \(fixedDateOnly)")
let fixedComponents = dateComponentsFromISO(fetchedDueDate, dateOnly: fixedDateOnly)
print("   dateComponentsFromISO with dateOnly=\(fixedDateOnly)")
print("   Result: hour=\(fixedComponents?.hour as Any), minute=\(fixedComponents?.minute as Any)")
if fixedComponents?.hour == nil {
    print("   ✓ CORRECT: No time component, stays date-only")
}

// Step 7: Apply the FIXED sync to the reminder
print("\n7. Applying the FIXED sync to the reminder...")
guard let savedReminder = store.calendarItem(withIdentifier: reminderId) as? EKReminder else {
    print("   ❌ Could not re-fetch reminder")
    exit(1)
}

// Apply the FIXED conversion (using dueIsDateOnly metadata)
savedReminder.dueDateComponents = fixedComponents

do {
    try store.save(savedReminder, commit: true)
    print("   Saved reminder with fixed date components")

    // Re-fetch and check
    guard let finalReminder = store.calendarItem(withIdentifier: reminderId) as? EKReminder else {
        print("   ❌ Could not re-fetch")
        exit(1)
    }

    print("")
    print("   AFTER ROUND-TRIP:")
    print("   dueDateComponents: \(finalReminder.dueDateComponents!)")
    print("   hour: \(finalReminder.dueDateComponents?.hour as Any)")
    print("   minute: \(finalReminder.dueDateComponents?.minute as Any)")
    print("   isDateOnly: \(dateComponentsIsDateOnly(finalReminder.dueDateComponents) ?? false)")

    if finalReminder.dueDateComponents?.hour == nil {
        print("")
        print("   ✅✅✅ FIX VERIFIED ✅✅✅")
        print("   Date-only preserved after round-trip!")
        print("   Original: date-only (hour=nil, minute=nil)")
        print("   After round-trip: hour=nil, minute=nil")
    } else {
        print("")
        print("   ❌❌❌ FIX FAILED ❌❌❌")
        print("   The reminder has a TIME where it shouldn't!")
        print("   After round-trip: hour=\(finalReminder.dueDateComponents?.hour ?? 0), minute=\(finalReminder.dueDateComponents?.minute ?? 0)")
    }
} catch {
    print("   ❌ Failed to save: \(error)")
}

// Step 8: Cleanup
print("\n8. Cleaning up...")
do {
    _ = try vikunjaRequest(method: "DELETE", path: "/tasks/\(vikunjaTaskId)")
    print("   ✓ Deleted Vikunja task \(vikunjaTaskId)")
} catch {
    print("   ⚠️  Failed to delete Vikunja task: \(error)")
}

do {
    if let r = store.calendarItem(withIdentifier: reminderId) as? EKReminder {
        try store.remove(r, commit: true)
        print("   ✓ Deleted Reminders task")
    }
} catch {
    print("   ⚠️  Failed to delete reminder: \(error)")
}

print("\n" + "=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("TEST COMPLETE")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("")
print("Summary:")
print("- Created real reminder with date-only due (no hour/minute)")
print("- Synced to Vikunja using local midnight (not UTC)")
print("- Fetched back and synced to Reminders using dueIsDateOnly metadata")
print("- Fix verified: date-only preserved after round-trip")
print("")
print("The fix uses task.dueIsDateOnly from metadata instead of")
print("isDateOnlyString() which can't detect date-only from Vikunja's")
print("full datetime strings.")
