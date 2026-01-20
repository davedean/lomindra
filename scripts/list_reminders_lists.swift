import EventKit
import Foundation

let store = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)

if #available(macOS 14.0, *) {
    store.requestFullAccessToReminders { granted, error in
        if let error = error {
            print("Access error: \(error)")
        }
        if !granted {
            print("Access not granted.")
        }
        semaphore.signal()
    }
} else {
    store.requestAccess(to: .reminder) { granted, error in
        if let error = error {
            print("Access error: \(error)")
        }
        if !granted {
            print("Access not granted.")
        }
        semaphore.signal()
    }
}
semaphore.wait()

let status = EKEventStore.authorizationStatus(for: .reminder)
if #available(macOS 14.0, *) {
    guard status == .fullAccess || status == .writeOnly else {
        print("Reminders access not authorized: \(status.rawValue)")
        exit(1)
    }
} else {
    guard status == .authorized else {
        print("Reminders access not authorized.")
        exit(1)
    }
}

let calendars = store.calendars(for: .reminder)
if calendars.isEmpty {
    print("No reminder lists found.")
    exit(0)
}

for cal in calendars.sorted(by: { ($0.title) < ($1.title) }) {
    print("\(cal.title)\t\(cal.calendarIdentifier)")
}
