#if !canImport(EventKit)
import Foundation

public enum ConflictResolution: String {
    case none
    case reminders
    case vikunja
    case lastWriteWins = "last-write-wins"
}

public struct ConflictKey: Hashable {
    public let remindersId: String
    public let vikunjaId: String

    public init(remindersId: String, vikunjaId: String) {
        self.remindersId = remindersId
        self.vikunjaId = vikunjaId
    }
}

public struct SyncProgress {
    public let message: String
    public let listTitle: String?

    public init(message: String, listTitle: String? = nil) {
        self.message = message
        self.listTitle = listTitle
    }
}

public typealias SyncProgressHandler = (SyncProgress) -> Void

public struct SyncOptions {
    public let apply: Bool
    public let allowConflicts: Bool
    public let conflictReportPath: String?
    public let resolveConflicts: ConflictResolution
    public let progress: SyncProgressHandler?
    public let conflictResolutions: [ConflictKey: ConflictResolution]

    public init(apply: Bool, allowConflicts: Bool, conflictReportPath: String?, resolveConflicts: ConflictResolution, progress: SyncProgressHandler? = nil, conflictResolutions: [ConflictKey: ConflictResolution] = [:]) {
        self.apply = apply
        self.allowConflicts = allowConflicts
        self.conflictReportPath = conflictReportPath
        self.resolveConflicts = resolveConflicts
        self.progress = progress
        self.conflictResolutions = conflictResolutions
    }
}

public struct SyncSummary {
    public let listsProcessed: Int
    public let createdInVikunja: Int
    public let createdInReminders: Int
    public let updatedVikunja: Int
    public let updatedReminders: Int
    public let deletedVikunja: Int
    public let deletedReminders: Int
    public let conflicts: Int

    public init(listsProcessed: Int, createdInVikunja: Int, createdInReminders: Int, updatedVikunja: Int, updatedReminders: Int, deletedVikunja: Int, deletedReminders: Int, conflicts: Int) {
        self.listsProcessed = listsProcessed
        self.createdInVikunja = createdInVikunja
        self.createdInReminders = createdInReminders
        self.updatedVikunja = updatedVikunja
        self.updatedReminders = updatedReminders
        self.deletedVikunja = deletedVikunja
        self.deletedReminders = deletedReminders
        self.conflicts = conflicts
    }
}

private func parseBool(_ value: String?) -> Bool {
    guard let value = value else { return false }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized == "true" || normalized == "1" || normalized == "yes"
}

public func loadConfigFromFiles(applePath: String = "apple_details.txt", vikunjaPath: String = "vikunja_details.txt", environment: [String: String] = ProcessInfo.processInfo.environment) throws -> Config {
    let apple = try loadKeyValueFile(applePath)
    let vikunja = try loadKeyValueFile(vikunjaPath)

    guard let apiBase = vikunja["api_base"] else {
        throw NSError(domain: "config", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing api_base in vikunja_details.txt"])
    }
    guard let token = vikunja["token"] else {
        throw NSError(domain: "config", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing token in vikunja_details.txt"])
    }
    let remindersListId = apple["reminders_list_id"] ?? apple["sync-list"]
    let projectId = vikunja["project_id"].flatMap { Int($0) }
    var listMapPath = apple["list_map_path"] ?? "list_map.txt"
    if let envListMap = environment["LIST_MAP_PATH"], !envListMap.isEmpty {
        listMapPath = envListMap
    }
    var syncAllLists = parseBool(apple["sync_all_lists"])
    if let envSyncAll = environment["SYNC_ALL_LISTS"] {
        syncAllLists = parseBool(envSyncAll)
    }
    var syncDbPath = apple["sync_db_path"] ?? "sync.db"
    if let envDbPath = environment["SYNC_DB_PATH"], !envDbPath.isEmpty {
        syncDbPath = envDbPath
    }
    let hasListMap = FileManager.default.fileExists(atPath: listMapPath)

    if !hasListMap && !syncAllLists {
        guard remindersListId != nil else {
            throw NSError(domain: "config", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing reminders_list_id in apple_details.txt"])
        }
        guard projectId != nil else {
            throw NSError(domain: "config", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing project_id in vikunja_details.txt"])
        }
    }

    return Config(
        remindersListId: remindersListId,
        vikunjaApiBase: apiBase,
        vikunjaToken: token,
        vikunjaProjectId: projectId,
        syncDbPath: syncDbPath,
        listMapPath: hasListMap ? listMapPath : nil,
        syncAllLists: syncAllLists
    )
}

public func runSync(config: Config, options: SyncOptions) throws -> SyncSummary {
    throw NSError(
        domain: "sync",
        code: 99,
        userInfo: [NSLocalizedDescriptionKey: "Sync requires EventKit, which is unavailable on this platform."]
    )
}
#endif
