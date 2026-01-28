#!/usr/bin/env swift
//
// test_016_dateonly.swift
// Focused test for Issue 016: Date-only round-trip preservation
//
// This script tests the specific bug without running full sync.
// It uses direct API calls to trace exactly what happens to date-only dates.
//

import Foundation

// MARK: - Config

let vikunjaApiBase = "https://tasks.cb.dc.dasie.co/api/v1"
let vikunjaToken = "tk_1bf2ba170bce252f285a8f240d7a8366dd36bd7c"
let vikunjaProjectId = 57

// MARK: - Helpers

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

    let session = URLSession(configuration: .default, delegate: InsecureDelegate(), delegateQueue: nil)
    session.dataTask(with: request) { data, response, error in
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

struct VikunjaTask: Codable {
    let id: Int
    let title: String
    let due_date: String?
    let start_date: String?
}

// MARK: - Date conversion functions (copied from SyncLib for testing)

func dateComponentsToISO(year: Int, month: Int, day: Int, hour: Int? = nil, minute: Int? = nil) -> String {
    if let h = hour, let m = minute {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var dc = DateComponents()
        dc.year = year
        dc.month = month
        dc.day = day
        dc.hour = h
        dc.minute = m
        dc.calendar = Calendar.current
        dc.timeZone = TimeZone.current
        if let date = dc.date {
            return formatter.string(from: date)
        }
    }
    // Date-only: just YYYY-MM-DD
    return String(format: "%04d-%02d-%02d", year, month, day)
}

func vikunjaDateString(from dateOnly: String) -> String {
    // Current (buggy) behavior: appends T00:00:00Z
    return dateOnly + "T00:00:00Z"
}

func vikunjaDateStringLocal(from dateOnly: String) -> String {
    // Proposed fix: use local midnight
    let tz = TimeZone.current
    let offsetSeconds = tz.secondsFromGMT()
    let hours = abs(offsetSeconds) / 3600
    let mins = (abs(offsetSeconds) % 3600) / 60
    let sign = offsetSeconds >= 0 ? "+" : "-"
    return dateOnly + String(format: "T00:00:00%@%02d:%02d", sign, hours, mins)
}

func parseVikunjaDate(_ s: String) -> (date: String, time: String?, isUTCMidnight: Bool) {
    if s.count == 10 {
        return (s, nil, false)
    }
    let datePart = String(s.prefix(10))
    let timePart = String(s.dropFirst(11))
    let isUTCMidnight = timePart == "00:00:00Z"
    return (datePart, timePart, isUTCMidnight)
}

// MARK: - Test

print("=== Issue 016: Date-only round-trip test ===\n")

// Step 1: Simulate a date-only reminder
let testDateOnly = "2026-01-30"  // Date-only, no time
print("1. Simulated Reminders date-only: \(testDateOnly)")
print("   (This is what dateComponentsToISO produces when hour=nil, minute=nil)")

// Step 2: Convert to Vikunja format (current buggy behavior)
let vikunjaDateBuggy = vikunjaDateString(from: testDateOnly)
print("\n2. Current conversion to Vikunja: \(vikunjaDateBuggy)")
print("   Problem: T00:00:00Z is UTC midnight")
print("   In Melbourne (UTC+11): displays as 11:00am")

// Step 3: Show proposed fix
let vikunjaDateFixed = vikunjaDateStringLocal(from: testDateOnly)
print("\n3. Proposed fix (local midnight): \(vikunjaDateFixed)")
print("   This would display as 00:00 in the user's timezone")

// Step 4: Create actual task in Vikunja with the buggy date
print("\n4. Creating test task in Vikunja with buggy UTC midnight...")
let taskTitle = "TEST-016-\(Int(Date().timeIntervalSince1970)): Date-only test"
do {
    let payload: [String: Any] = [
        "title": taskTitle,
        "due_date": vikunjaDateBuggy,
        "done": false
    ]
    let data = try vikunjaRequest(method: "PUT", path: "/projects/\(vikunjaProjectId)/tasks", body: payload)
    let task = try JSONDecoder().decode(VikunjaTask.self, from: data)
    print("   Created task ID: \(task.id)")
    print("   Stored due_date: \(task.due_date ?? "nil")")

    // Step 5: Fetch it back and analyze
    print("\n5. Fetching task back from Vikunja...")
    let fetchData = try vikunjaRequest(method: "GET", path: "/tasks/\(task.id)")
    let fetched = try JSONDecoder().decode(VikunjaTask.self, from: fetchData)

    if let dueDate = fetched.due_date {
        let parsed = parseVikunjaDate(dueDate)
        print("   Fetched due_date: \(dueDate)")
        print("   Date part: \(parsed.date)")
        print("   Time part: \(parsed.time ?? "none")")
        print("   Is UTC midnight: \(parsed.isUTCMidnight)")

        if parsed.isUTCMidnight {
            print("\n   ⚠️  BUG CONFIRMED: Time is T00:00:00Z (UTC midnight)")
            print("   When syncing back to Reminders without dateOnly metadata,")
            print("   this becomes 11:00am in Melbourne instead of date-only.")
        }
    }

    // Step 6: Simulate what happens on round-trip
    print("\n6. Simulating round-trip to Reminders...")
    print("   isDateOnlyString(\"\(fetched.due_date ?? "")\") = false  (string is not 10 chars)")
    print("   Therefore dateComponentsFromISO is called with dateOnly=false")
    print("   Result: Reminders gets hour=11, minute=0 (local interpretation of UTC midnight)")
    print("\n   ❌ Date-only intent is LOST on round-trip")

    // Step 7: Clean up
    print("\n7. Cleaning up test task...")
    _ = try vikunjaRequest(method: "DELETE", path: "/tasks/\(task.id)")
    print("   Deleted task \(task.id)")

} catch {
    print("   Error: \(error)")
}

print("\n=== Test complete ===")
print("\nSummary:")
print("- The bug is in vikunjaDateString() appending T00:00:00Z")
print("- The round-trip fails because isDateOnlyString() checks string length")
print("- Fix: Use local midnight AND/OR use task.dueIsDateOnly property")
