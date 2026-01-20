import EventKit
import Foundation

func iso(_ date: Date?) -> String {
    guard let date = date else { return "nil" }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

func dcString(_ dc: DateComponents?) -> String {
    guard let dc = dc else { return "nil" }
    var parts: [String] = []
    if let cal = dc.calendar { parts.append("cal=\(cal.identifier)") }
    if let y = dc.year { parts.append("y=\(y)") }
    if let m = dc.month { parts.append("m=\(m)") }
    if let d = dc.day { parts.append("d=\(d)") }
    if let h = dc.hour { parts.append("h=\(h)") }
    if let min = dc.minute { parts.append("min=\(min)") }
    if let s = dc.second { parts.append("s=\(s)") }
    if let tz = dc.timeZone { parts.append("tz=\(tz.identifier)") }
    return parts.joined(separator: " ")
}

func makeDateComponents(year: Int, month: Int, day: Int, hour: Int? = nil, minute: Int? = nil) -> DateComponents {
    var dc = DateComponents()
    dc.calendar = Calendar.current
    dc.timeZone = TimeZone.current
    dc.year = year
    dc.month = month
    dc.day = day
    if let hour = hour { dc.hour = hour }
    if let minute = minute { dc.minute = minute }
    return dc
}

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

let calendar = EKCalendar(for: .reminder, eventStore: store)
calendar.title = "Vikunja Sync POC (temp)"
if let defaultSource = store.defaultCalendarForNewReminders()?.source {
    calendar.source = defaultSource
} else if let localSource = store.sources.first(where: { $0.sourceType == .local }) {
    calendar.source = localSource
} else if let anySource = store.sources.first {
    calendar.source = anySource
} else {
    print("No calendar sources available.")
    exit(1)
}

do {
    try store.saveCalendar(calendar, commit: true)
    print("Created calendar: \(calendar.title) id=\(calendar.calendarIdentifier)")
} catch {
    print("Failed to save calendar: \(error)")
    exit(1)
}

func printState(_ label: String, _ item: EKReminder) {
    print("---- \(label) ----")
    print("title: \(item.title ?? "nil")")
    print("calendarItemIdentifier: \(item.calendarItemIdentifier)")
    print("calendarItemExternalIdentifier: \(String(describing: item.calendarItemExternalIdentifier))")
    print("creationDate: \(iso(item.creationDate))")
    print("lastModifiedDate: \(iso(item.lastModifiedDate))")
    print("startDateComponents: \(dcString(item.startDateComponents))")
    print("dueDateComponents: \(dcString(item.dueDateComponents))")
    print("isCompleted: \(item.isCompleted)")
    print("completionDate: \(iso(item.completionDate))")
    print("priority: \(item.priority)")
    if let alarms = item.alarms {
        for (idx, alarm) in alarms.enumerated() {
            print("alarm[\(idx)]: absoluteDate=\(iso(alarm.absoluteDate)) relativeOffset=\(alarm.relativeOffset) type=\(alarm.type.rawValue)")
        }
    } else {
        print("alarms: nil")
    }
    if let rules = item.recurrenceRules {
        for (idx, rule) in rules.enumerated() {
            print("recurrence[\(idx)]: freq=\(rule.frequency.rawValue) interval=\(rule.interval) endDate=\(iso(rule.recurrenceEnd?.endDate)) count=\(String(describing: rule.recurrenceEnd?.occurrenceCount))")
        }
    } else {
        print("recurrenceRules: nil")
    }
}

func saveReminder(_ reminder: EKReminder, label: String) {
    do {
        try store.save(reminder, commit: true)
        print("Created reminder (\(label)) id=\(reminder.calendarItemIdentifier) external=\(String(describing: reminder.calendarItemExternalIdentifier))")
    } catch {
        print("Failed to save reminder (\(label)): \(error)")
        exit(1)
    }
}

func fetchReminder(_ identifier: String) -> EKReminder? {
    return store.calendarItem(withIdentifier: identifier) as? EKReminder
}

var createdReminders: [EKReminder] = []

let recurringReminder = EKReminder(eventStore: store)
recurringReminder.calendar = calendar
recurringReminder.title = "POC Recurring (start+due)"
recurringReminder.notes = "Notes for recurring reminder."
recurringReminder.url = URL(string: "https://example.com/recurring")
recurringReminder.priority = 1
recurringReminder.startDateComponents = makeDateComponents(year: 2025, month: 3, day: 1, hour: 9, minute: 30)
recurringReminder.dueDateComponents = makeDateComponents(year: 2025, month: 3, day: 2)
let recurringAbsoluteAlarmDate = Calendar.current.date(from: recurringReminder.dueDateComponents!)!.addingTimeInterval(-1800)
recurringReminder.addAlarm(EKAlarm(absoluteDate: recurringAbsoluteAlarmDate))
recurringReminder.addAlarm(EKAlarm(relativeOffset: -3600))
recurringReminder.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil))
saveReminder(recurringReminder, label: "recurring")
createdReminders.append(recurringReminder)

let dueOnlyReminder = EKReminder(eventStore: store)
dueOnlyReminder.calendar = calendar
dueOnlyReminder.title = "POC Due Only"
dueOnlyReminder.dueDateComponents = makeDateComponents(year: 2025, month: 3, day: 5)
dueOnlyReminder.addAlarm(EKAlarm(relativeOffset: -7200))
saveReminder(dueOnlyReminder, label: "due-only")
createdReminders.append(dueOnlyReminder)

let startOnlyReminder = EKReminder(eventStore: store)
startOnlyReminder.calendar = calendar
startOnlyReminder.title = "POC Start Only"
startOnlyReminder.startDateComponents = makeDateComponents(year: 2025, month: 3, day: 6, hour: 8, minute: 15)
startOnlyReminder.addAlarm(EKAlarm(relativeOffset: -900))
saveReminder(startOnlyReminder, label: "start-only")
createdReminders.append(startOnlyReminder)

let oneOffReminder = EKReminder(eventStore: store)
oneOffReminder.calendar = calendar
oneOffReminder.title = "POC One-Off (start+due)"
oneOffReminder.startDateComponents = makeDateComponents(year: 2025, month: 3, day: 7, hour: 10, minute: 0)
oneOffReminder.dueDateComponents = makeDateComponents(year: 2025, month: 3, day: 7, hour: 12, minute: 0)
oneOffReminder.addAlarm(EKAlarm(relativeOffset: -1800))
saveReminder(oneOffReminder, label: "one-off")
createdReminders.append(oneOffReminder)

if let fetched = fetchReminder(recurringReminder.calendarItemIdentifier) {
    printState("Recurring initial fetch", fetched)
}
if let fetched = fetchReminder(dueOnlyReminder.calendarItemIdentifier) {
    printState("Due-only initial fetch", fetched)
}
if let fetched = fetchReminder(startOnlyReminder.calendarItemIdentifier) {
    printState("Start-only initial fetch", fetched)
}
if let fetched = fetchReminder(oneOffReminder.calendarItemIdentifier) {
    printState("One-off initial fetch", fetched)
}

if let initial = fetchReminder(oneOffReminder.calendarItemIdentifier) {
    let initialExternal = String(describing: initial.calendarItemExternalIdentifier)
    oneOffReminder.title = "POC One-Off (edited)"
    do {
        try store.save(oneOffReminder, commit: true)
        print("Edited one-off reminder saved.")
    } catch {
        print("Failed to edit one-off reminder: \(error)")
    }
    if let edited = fetchReminder(oneOffReminder.calendarItemIdentifier) {
        let editedExternal = String(describing: edited.calendarItemExternalIdentifier)
        print("One-off external identifier stable: \(initialExternal == editedExternal)")
        printState("One-off after edit", edited)
    }
}

if let fetched = fetchReminder(oneOffReminder.calendarItemIdentifier) {
    fetched.isCompleted = true
    fetched.completionDate = Date()
    do {
        try store.save(fetched, commit: true)
        print("Marked one-off completed.")
    } catch {
        print("Failed to complete one-off reminder: \(error)")
    }
    if let completed = fetchReminder(oneOffReminder.calendarItemIdentifier) {
        printState("One-off after complete", completed)
    }
}

if let fetched = fetchReminder(recurringReminder.calendarItemIdentifier) {
    fetched.isCompleted = true
    fetched.completionDate = Date()
    do {
        try store.save(fetched, commit: true)
        print("Marked recurring completed.")
    } catch {
        print("Failed to complete recurring reminder: \(error)")
    }
    if let completed = fetchReminder(recurringReminder.calendarItemIdentifier) {
        printState("Recurring after complete", completed)
    }
}

do {
    for reminder in createdReminders {
        try store.remove(reminder, commit: false)
    }
    try store.removeCalendar(calendar, commit: true)
    print("Cleaned up reminders and calendar.")
} catch {
    print("Cleanup failed: \(error)")
}
