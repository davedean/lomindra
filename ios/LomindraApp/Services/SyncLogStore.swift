import Foundation

struct SyncLogStore {
    static let logUpdatedNotification = Notification.Name("SyncLogStoreUpdated")
    private static let logDirectoryName = "sync-logs"
    private static let logQueue = DispatchQueue(label: "lomindra.sync.log")

    static func startLog(mode: SyncRunMode, settings: AppSettings, source: String) -> URL? {
        guard let directory = logDirectoryURL() else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "sync-\(source)-\(stamp).log"
        let url = directory.appendingPathComponent(filename)
        let header = headerText(mode: mode, settings: settings, source: source)
        do {
            try header.write(to: url, atomically: true, encoding: .utf8)
            notifyUpdated()
            return url
        } catch {
            return nil
        }
    }

    static func append(_ message: String, to url: URL?) {
        guard let url = url else { return }
        logQueue.async {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let stamp = formatter.string(from: Date())
            let redacted = SafeLog.redact(message)
            let line = "[\(stamp)] \(redacted)\n"
            do {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                if let data = line.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
            } catch {
                // Best effort; ignore logging failures.
            }
        }
    }

    static func latestLogURL() -> URL? {
        guard let directory = logDirectoryURL(),
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        let candidates = files.filter { $0.pathExtension == "log" }
        return candidates.sorted { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return leftDate > rightDate
        }.first
    }

    private static func headerText(mode: SyncRunMode, settings: AppSettings, source: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let stamp = formatter.string(from: Date())
        let syncAll = settings.syncAllLists ? "yes" : "no"
        let overridesCount = settings.projectOverrides.count
        let listCount = settings.selectedRemindersIds.count
        return """
        Lomindra Sync Log
        Timestamp: \(stamp)
        Source: \(source)
        Mode: \(mode.label) (apply=\(mode.isApply))
        Sync all lists: \(syncAll)
        Selected lists: \(listCount)
        Project overrides: \(overridesCount)

        """
    }

    private static func logDirectoryURL() -> URL? {
        guard let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = base.appendingPathComponent(logDirectoryName)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            return directory
        } catch {
            return nil
        }
    }

    static func notifyUpdated() {
        NotificationCenter.default.post(name: logUpdatedNotification, object: nil)
    }
}
