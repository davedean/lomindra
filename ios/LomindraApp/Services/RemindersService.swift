import EventKit
import Foundation

struct RemindersList: Identifiable, Hashable {
    let id: String
    let title: String
}

final class RemindersService {
    private let store = EKEventStore()

    func requestAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(iOS 17.0, *) {
            if status == .fullAccess || status == .writeOnly {
                return
            }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                store.requestFullAccessToReminders { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if granted {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: NSError(domain: "reminders", code: 1, userInfo: [NSLocalizedDescriptionKey: "Reminders access denied"]))
                    }
                }
            }
        } else {
            if status == .authorized {
                return
            }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                store.requestAccess(to: .reminder) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if granted {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: NSError(domain: "reminders", code: 1, userInfo: [NSLocalizedDescriptionKey: "Reminders access denied"]))
                    }
                }
            }
        }
    }

    func fetchLists() async throws -> [RemindersList] {
        try await requestAccess()
        return store.calendars(for: .reminder)
            .filter { $0.allowsContentModifications && !$0.isSubscribed }
            .map { calendar in
                RemindersList(id: calendar.calendarIdentifier, title: calendar.title)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
