import Foundation
import VikunjaSyncLib

enum SyncRunMode {
    case dryRun
    case apply

    var isApply: Bool {
        switch self {
        case .dryRun: return false
        case .apply: return true
        }
    }

    var label: String {
        switch self {
        case .dryRun: return "Dry run"
        case .apply: return "Applied"
        }
    }
}

struct SyncRunResult {
    let summary: SyncSummary
    let reportPath: String?
}

final class SyncCoordinator {
    func runSync(settings: AppSettings,
                 token: String,
                 mode: SyncRunMode,
                 allowConflicts: Bool,
                 conflictReportPath: String?,
                 conflictResolutions: [ConflictKey: ConflictResolution] = [:],
                 progress: SyncProgressHandler?) async throws -> SyncRunResult {
        let listMapPath = try Self.writeListMap(settings: settings)
        let config = try Self.buildConfig(settings: settings, token: token, listMapPath: listMapPath)
        let options = SyncOptions(
            apply: mode.isApply,
            allowConflicts: allowConflicts,
            conflictReportPath: conflictReportPath,
            resolveConflicts: .none,
            progress: progress,
            conflictResolutions: conflictResolutions
        )
        let task = Task.detached {
            try VikunjaSyncLib.runSync(config: config, options: options)
        }
        let summary = try await task.value
        return SyncRunResult(summary: summary, reportPath: conflictReportPath)
    }

    static func buildConfig(settings: AppSettings, token: String, listMapPath: String) throws -> Config {
        let apiBase = settings.apiBase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiBase.isEmpty else {
            throw NSError(domain: "sync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing API base URL"])
        }
        guard !token.isEmpty else {
            throw NSError(domain: "sync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing API token"])
        }
        let dbPath = try syncDbPath()
        return Config(
            remindersListId: nil,
            vikunjaApiBase: apiBase,
            vikunjaToken: token,
            vikunjaProjectId: nil,
            syncDbPath: dbPath,
            listMapPath: listMapPath,
            syncAllLists: settings.syncAllLists,
            syncTagsEnabled: settings.syncTagsEnabled
        )
    }

    static func writeListMap(settings: AppSettings) throws -> String {
        let listIds = settings.selectedRemindersIds
        guard !listIds.isEmpty else {
            throw NSError(domain: "sync", code: 2, userInfo: [NSLocalizedDescriptionKey: "No lists selected"])
        }
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "sync", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing documents directory"])
        }
        let path = url.appendingPathComponent("list_map.txt")
        var lines: [String] = []
        for listId in listIds.sorted() {
            if let overrideId = settings.projectOverrides[listId] {
                lines.append("\(listId): \(overrideId)")
            } else {
                lines.append("\(listId):")
            }
        }
        try lines.joined(separator: "\n").write(to: path, atomically: true, encoding: .utf8)
        return path.path
    }

    static func syncDbPath() throws -> String {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "sync", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing documents directory"])
        }
        return url.appendingPathComponent("sync.db").path
    }

    static func conflictReportPath() -> String? {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return url.appendingPathComponent("conflicts-\(stamp).json").path
    }
}
