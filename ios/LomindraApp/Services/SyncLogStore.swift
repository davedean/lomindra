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
        return allLogURLs().first
    }

    /// Returns all sync log URLs, sorted by modification date (newest first)
    static func allLogURLs() -> [URL] {
        guard let directory = logDirectoryURL(),
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        let candidates = files.filter { $0.pathExtension == "log" }
        return candidates.sorted { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return leftDate > rightDate
        }
    }

    /// Parse log filename to extract source and timestamp
    static func parseLogFilename(_ url: URL) -> (source: String, date: Date)? {
        // Format: sync-{source}-{timestamp}.log
        // Example: sync-background-2026-01-23T08-44-46Z.log
        let filename = url.deletingPathExtension().lastPathComponent
        guard filename.hasPrefix("sync-") else { return nil }
        let parts = filename.dropFirst(5) // Remove "sync-"

        // Find the source (everything before the timestamp)
        // Timestamp starts with a digit after a hyphen
        var source = ""
        var timestampPart = ""
        var foundTimestamp = false

        for (index, char) in parts.enumerated() {
            if !foundTimestamp && char == "-" {
                let nextIndex = parts.index(parts.startIndex, offsetBy: index + 1, limitedBy: parts.endIndex)
                if let next = nextIndex, next < parts.endIndex {
                    let nextChar = parts[next]
                    if nextChar.isNumber {
                        foundTimestamp = true
                        timestampPart = String(parts[next...])
                        break
                    }
                }
                source += String(char)
            } else if !foundTimestamp {
                source += String(char)
            }
        }

        // Remove trailing hyphen from source
        if source.hasSuffix("-") {
            source = String(source.dropLast())
        }

        // Parse timestamp (format: 2026-01-23T08-44-46Z)
        let isoTimestamp = timestampPart.replacingOccurrences(of: "-", with: ":")
            .replacingOccurrences(of: "T:", with: "T")  // Fix the T: that appears after date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        // Try parsing with the corrected format
        if let date = formatter.date(from: isoTimestamp) {
            return (source, date)
        }

        // Fallback: use file modification date
        if let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
            return (source.isEmpty ? "unknown" : source, modDate)
        }

        return nil
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
