import EventKit
import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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

// MARK: - Config Loading

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

// MARK: - EventKit / Reminders

func authorizedRemindersStore() throws -> EKEventStore {
    let store = EKEventStore()
    let semaphore = DispatchSemaphore(value: 0)

    if #available(iOS 17.0, macOS 14.0, *) {
        store.requestFullAccessToReminders { _, _ in semaphore.signal() }
    } else {
        store.requestAccess(to: .reminder) { _, _ in semaphore.signal() }
    }
    semaphore.wait()

    let status = EKEventStore.authorizationStatus(for: .reminder)
    if #available(iOS 17.0, macOS 14.0, *) {
        guard status == .fullAccess || status == .writeOnly else {
            throw NSError(domain: "reminders", code: 2, userInfo: [NSLocalizedDescriptionKey: "Reminders access not authorized"])
        }
    } else {
        guard status == .authorized else {
            throw NSError(domain: "reminders", code: 2, userInfo: [NSLocalizedDescriptionKey: "Reminders access not authorized"])
        }
    }
    return store
}

func fetchReminders(calendar: EKCalendar, store: EKEventStore) throws -> [CommonTask] {
    let predicate = store.predicateForReminders(in: [calendar])
    let fetchSemaphore = DispatchSemaphore(value: 0)
    var items: [EKReminder] = []
    store.fetchReminders(matching: predicate) { reminders in
        items = reminders ?? []
        fetchSemaphore.signal()
    }
    fetchSemaphore.wait()

    return items.map { reminder in
        var alarms: [CommonAlarm] = []
        if let reminderAlarms = reminder.alarms {
            for alarm in reminderAlarms {
                if let abs = alarm.absoluteDate {
                    alarms.append(CommonAlarm(type: "absolute", absolute: isoDate(abs), relativeSeconds: nil, relativeTo: nil))
                } else {
                    let relative = Int(alarm.relativeOffset)
                    let base: String? = reminder.dueDateComponents != nil ? "due" : (reminder.startDateComponents != nil ? "start" : "due")
                    alarms.append(CommonAlarm(type: "relative", absolute: nil, relativeSeconds: relative, relativeTo: base))
                }
            }
        }
        var recurrence: CommonRecurrence?
        if let rule = reminder.recurrenceRules?.first {
            let freq: String
            switch rule.frequency {
            case .daily: freq = "daily"
            case .weekly: freq = "weekly"
            case .monthly: freq = "monthly"
            case .yearly: freq = "yearly"
            @unknown default: freq = "custom"
            }
            recurrence = CommonRecurrence(frequency: freq, interval: rule.interval)
        }
        return CommonTask(
            source: "reminders",
            id: reminder.calendarItemIdentifier,
            listId: calendar.calendarIdentifier,
            title: reminder.title ?? "(untitled)",
            isCompleted: reminder.isCompleted,
            due: dateComponentsToISO(reminder.dueDateComponents),
            start: dateComponentsToISO(reminder.startDateComponents),
            updatedAt: isoDate(reminder.lastModifiedDate),
            alarms: alarms,
            recurrence: recurrence,
            dueIsDateOnly: dateComponentsIsDateOnly(reminder.dueDateComponents),
            startIsDateOnly: dateComponentsIsDateOnly(reminder.startDateComponents)
        )
    }
}

// MARK: - Vikunja API

final class InsecureSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

struct VikunjaTask: Decodable {
    let id: Int
    let title: String
    let done: Bool?
    let due_date: String?
    let start_date: String?
    let updated: String?
    let reminders: [VikunjaReminder]?
    let repeat_after: Int?
    let repeat_mode: Int?
}

struct VikunjaReminder: Decodable {
    let reminder: String?
    let relative_period: Int?
    let relative_to: String?
}

struct VikunjaProject: Decodable {
    let id: Int
    let title: String
}

func vikunjaRequest(apiBase: String, token: String, method: String, path: String, body: [String: Any]?) throws -> Data {
    let policy = VikunjaRetryPolicy()
    let delegate = InsecureSessionDelegate()
    let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    var lastError: Error?

    for attempt in 1...policy.maxAttempts {
        do {
            return try vikunjaRequestOnce(
                session: session,
                apiBase: apiBase,
                token: token,
                method: method,
                path: path,
                body: body
            )
        } catch {
            lastError = error
            if attempt < policy.maxAttempts, shouldRetryVikunjaRequest(error: error) {
                let delay = policy.delay(forAttempt: attempt)
                Thread.sleep(forTimeInterval: delay)
                continue
            }
            throw error
        }
    }

    throw lastError ?? NSError(domain: "vikunja", code: 1, userInfo: [NSLocalizedDescriptionKey: "Request failed after retries"])
}

private func vikunjaRequestOnce(session: URLSession,
                                apiBase: String,
                                token: String,
                                method: String,
                                path: String,
                                body: [String: Any]?) throws -> Data {
    let url = URL(string: "\(apiBase)\(path)")!
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    if let body = body {
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
    }
    let semaphore = DispatchSemaphore(value: 0)
    var result: Result<Data, Error> = .failure(NSError(domain: "vikunja", code: 1))
    let task = session.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        if let error = error {
            result = .failure(error)
            return
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let safeBody = redactSensitive(bodyText, token: token)
            result = .failure(NSError(domain: "vikunja", code: code, userInfo: [NSLocalizedDescriptionKey: "Bad response: \(safeBody)"]))
            return
        }
        result = .success(data ?? Data())
    }
    task.resume()
    semaphore.wait()
    switch result {
    case .success(let data):
        return data
    case .failure(let error):
        throw error
    }
}

func fetchVikunjaTasks(apiBase: String, token: String, projectId: Int) throws -> [CommonTask] {
    let data = try vikunjaRequest(apiBase: apiBase, token: token, method: "GET", path: "/projects/\(projectId)/tasks", body: nil)
    let tasks = try JSONDecoder().decode([VikunjaTask].self, from: data)
    return tasks.map {
        let alarms: [CommonAlarm] = ($0.reminders ?? []).map { reminder in
            if let abs = reminder.reminder {
                return CommonAlarm(type: "absolute", absolute: abs, relativeSeconds: nil, relativeTo: nil)
            }
            return CommonAlarm(type: "relative", absolute: nil, relativeSeconds: reminder.relative_period, relativeTo: reminder.relative_to)
        }
        var recurrence: CommonRecurrence?
        if let repeatAfter = $0.repeat_after, let repeatMode = $0.repeat_mode {
            if repeatMode == 1 {
                recurrence = CommonRecurrence(frequency: "monthly", interval: 1)
            } else if repeatMode == 0, repeatAfter > 0 {
                if repeatAfter % 604800 == 0 {
                    recurrence = CommonRecurrence(frequency: "weekly", interval: repeatAfter / 604800)
                } else if repeatAfter % 86400 == 0 {
                    recurrence = CommonRecurrence(frequency: "daily", interval: repeatAfter / 86400)
                }
            }
        }
        return CommonTask(
            source: "vikunja",
            id: String($0.id),
            listId: String(projectId),
            title: $0.title,
            isCompleted: $0.done ?? false,
            due: $0.due_date,
            start: $0.start_date,
            updatedAt: $0.updated,
            alarms: alarms,
            recurrence: recurrence,
            dueIsDateOnly: isDateOnlyString($0.due_date),
            startIsDateOnly: isDateOnlyString($0.start_date)
        )
    }
}

func fetchVikunjaProjects(apiBase: String, token: String) throws -> [VikunjaProject] {
    let data = try vikunjaRequest(apiBase: apiBase, token: token, method: "GET", path: "/projects", body: nil)
    return try JSONDecoder().decode([VikunjaProject].self, from: data)
}

func createVikunjaProject(apiBase: String, token: String, title: String) throws -> VikunjaProject {
    let payload: [String: Any] = ["title": title]
    let data = try vikunjaRequest(apiBase: apiBase, token: token, method: "PUT", path: "/projects", body: payload)
    return try JSONDecoder().decode(VikunjaProject.self, from: data)
}

// MARK: - SQLite Operations

func openSyncDb(path: String) throws -> OpaquePointer? {
    var db: OpaquePointer?
    if sqlite3_open(path, &db) != SQLITE_OK {
        defer { sqlite3_close(db) }
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Open failed: \(message)"])
    }
    let createSql = """
    CREATE TABLE IF NOT EXISTS task_sync_map (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      reminders_id TEXT NOT NULL,
      vikunja_id INTEGER NOT NULL,
      list_reminders_id TEXT,
      project_id INTEGER,
      date_only_due INTEGER DEFAULT 0,
      date_only_start INTEGER DEFAULT 0,
      inferred_due INTEGER DEFAULT 0,
      relative_alarm_base_json TEXT,
      last_synced_at TEXT,
      last_seen_modified_reminders TEXT,
      last_seen_modified_vikunja TEXT,
      sync_version INTEGER NOT NULL DEFAULT 1
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_task_map_reminders
      ON task_sync_map (reminders_id);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_task_map_vikunja
      ON task_sync_map (vikunja_id);
    CREATE INDEX IF NOT EXISTS idx_task_map_list
      ON task_sync_map (list_reminders_id);
    CREATE INDEX IF NOT EXISTS idx_task_map_project
      ON task_sync_map (project_id);
    CREATE TABLE IF NOT EXISTS task_conflicts (
      reminders_id TEXT NOT NULL,
      vikunja_id INTEGER NOT NULL,
      list_reminders_id TEXT,
      project_id INTEGER,
      detected_at TEXT NOT NULL,
      reminders_json TEXT NOT NULL,
      vikunja_json TEXT NOT NULL,
      diffs_json TEXT NOT NULL,
      PRIMARY KEY (reminders_id, vikunja_id)
    );
    CREATE INDEX IF NOT EXISTS idx_conflicts_list
      ON task_conflicts (list_reminders_id);
    CREATE INDEX IF NOT EXISTS idx_conflicts_project
      ON task_conflicts (project_id);
    """
    let createRc = sqlite3_exec(db, createSql, nil, nil, nil)
    if createRc != SQLITE_OK {
        defer { sqlite3_close(db) }
        let errMsg = String(cString: sqlite3_errmsg(db))
        let errStr = String(cString: sqlite3_errstr(createRc))
        throw NSError(domain: "sqlite", code: Int(createRc), userInfo: [NSLocalizedDescriptionKey: "Create table failed (rc=\(createRc) \(errStr)): \(errMsg)"])
    }
    if !columnExists(db: db, table: "task_sync_map", column: "inferred_due") {
        let alterInferred = "ALTER TABLE task_sync_map ADD COLUMN inferred_due INTEGER DEFAULT 0;"
        _ = sqlite3_exec(db, alterInferred, nil, nil, nil)
    }
    return db
}

func columnExists(db: OpaquePointer?, table: String, column: String) -> Bool {
    let sql = "PRAGMA table_info(\(table));"
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
        return false
    }
    defer { sqlite3_finalize(stmt) }
    while sqlite3_step(stmt) == SQLITE_ROW {
        if let name = sqlite3_column_text(stmt, 1) {
            let columnName = String(cString: name)
            if columnName == column {
                return true
            }
        }
    }
    return false
}

func loadSyncRecords(db: OpaquePointer?, listId: String?, projectId: Int?) throws -> [String: SyncRecord] {
    var records: [String: SyncRecord] = [:]
    var query = """
    SELECT reminders_id, vikunja_id, list_reminders_id, project_id, last_seen_modified_reminders, last_seen_modified_vikunja, date_only_due, date_only_start, inferred_due
    FROM task_sync_map
    """
    var bindListId = false
    var bindProjectId = false
    if listId != nil {
        query += " WHERE list_reminders_id = ?"
        bindListId = true
        if projectId != nil {
            query += " AND project_id = ?"
            bindProjectId = true
        }
    } else if projectId != nil {
        query += " WHERE project_id = ?"
        bindProjectId = true
    }
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, query, -1, &stmt, nil) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 3, userInfo: [NSLocalizedDescriptionKey: "Prepare failed: \(message)"])
    }
    defer { sqlite3_finalize(stmt) }
    var bindIndex: Int32 = 1
    if bindListId, let listId = listId {
        sqlite3_bind_text(stmt, bindIndex, listId, -1, SQLITE_TRANSIENT)
        bindIndex += 1
    }
    if bindProjectId, let projectId = projectId {
        sqlite3_bind_int(stmt, bindIndex, Int32(projectId))
    }
    while sqlite3_step(stmt) == SQLITE_ROW {
        if let remId = sqlite3_column_text(stmt, 0) {
            let remindersId = String(cString: remId)
            let vikunjaId = sqlite3_column_int(stmt, 1)
            let listRemindersId = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let projectIdValue = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 3))
            let lastRem = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let lastVik = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let dateOnlyDue = sqlite3_column_int(stmt, 6) != 0
            let dateOnlyStart = sqlite3_column_int(stmt, 7) != 0
            let inferredDue = sqlite3_column_int(stmt, 8) != 0
            let record = SyncRecord(
                remindersId: remindersId,
                vikunjaId: String(vikunjaId),
                listRemindersId: listRemindersId,
                projectId: projectIdValue,
                lastSeenReminders: lastRem,
                lastSeenVikunja: lastVik,
                dateOnlyDue: dateOnlyDue,
                dateOnlyStart: dateOnlyStart,
                inferredDue: inferredDue
            )
            records[remindersId] = record
        }
    }
    return records
}

func jsonValue(_ value: Any?) -> Any {
    return value ?? NSNull()
}

func commonAlarmPayloads(_ alarms: [CommonAlarm]) -> [[String: Any]] {
    return alarms.map { alarm in
        return [
            "type": alarm.type,
            "absolute": jsonValue(alarm.absolute),
            "relative_seconds": jsonValue(alarm.relativeSeconds),
            "relative_to": jsonValue(alarm.relativeTo)
        ]
    }
}

func commonRecurrencePayload(_ recurrence: CommonRecurrence?) -> [String: Any]? {
    guard let recurrence = recurrence else { return nil }
    return [
        "frequency": recurrence.frequency,
        "interval": recurrence.interval
    ]
}

func commonTaskPayload(_ task: CommonTask) -> [String: Any] {
    return [
        "id": task.id,
        "list_id": task.listId,
        "title": task.title,
        "completed": task.isCompleted,
        "due": jsonValue(task.due),
        "start": jsonValue(task.start),
        "updated_at": jsonValue(task.updatedAt),
        "due_date_only": jsonValue(task.dueIsDateOnly),
        "start_date_only": jsonValue(task.startIsDateOnly),
        "alarms": commonAlarmPayloads(task.alarms),
        "recurrence": jsonValue(commonRecurrencePayload(task.recurrence))
    ]
}

func conflictDiffPayloads(_ diffs: [ConflictFieldDiff]) -> [[String: String]] {
    return diffs.map { diff in
        [
            "field": diff.field,
            "reminders": diff.reminders,
            "vikunja": diff.vikunja
        ]
    }
}

func clearConflicts(db: OpaquePointer?, listId: String?, projectId: Int?) throws {
    var sql = "DELETE FROM task_conflicts"
    if listId != nil || projectId != nil {
        sql += " WHERE"
        if let _ = listId {
            sql += " list_reminders_id = ?"
        } else {
            sql += " list_reminders_id IS NULL"
        }
        if let _ = projectId {
            sql += " AND project_id = ?"
        } else {
            sql += " AND project_id IS NULL"
        }
    }
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 6, userInfo: [NSLocalizedDescriptionKey: "Prepare delete conflicts failed: \(message)"])
    }
    defer { sqlite3_finalize(stmt) }
    var bindIndex: Int32 = 1
    if let listId = listId {
        sqlite3_bind_text(stmt, bindIndex, listId, -1, SQLITE_TRANSIENT)
        bindIndex += 1
    }
    if let projectId = projectId {
        sqlite3_bind_int(stmt, bindIndex, Int32(projectId))
    }
    if sqlite3_step(stmt) != SQLITE_DONE {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 7, userInfo: [NSLocalizedDescriptionKey: "Delete conflicts failed: \(message)"])
    }
}

func upsertConflict(db: OpaquePointer?, listId: String?, projectId: Int?, pair: TaskPair, detectedAt: String) throws {
    let diffs = conflictFieldDiffs(reminders: pair.reminders, vikunja: pair.vikunja)
    let remindersPayload = commonTaskPayload(pair.reminders)
    let vikunjaPayload = commonTaskPayload(pair.vikunja)
    let diffsPayload = conflictDiffPayloads(diffs)
    let remindersData = try JSONSerialization.data(withJSONObject: remindersPayload, options: [.sortedKeys])
    let vikunjaData = try JSONSerialization.data(withJSONObject: vikunjaPayload, options: [.sortedKeys])
    let diffsData = try JSONSerialization.data(withJSONObject: diffsPayload, options: [.sortedKeys])
    let remindersJson = String(data: remindersData, encoding: .utf8) ?? "{}"
    let vikunjaJson = String(data: vikunjaData, encoding: .utf8) ?? "{}"
    let diffsJson = String(data: diffsData, encoding: .utf8) ?? "[]"

    let sql = """
    INSERT OR REPLACE INTO task_conflicts
      (reminders_id, vikunja_id, list_reminders_id, project_id, detected_at, reminders_json, vikunja_json, diffs_json)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    """
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 8, userInfo: [NSLocalizedDescriptionKey: "Prepare insert conflict failed: \(message)"])
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, pair.reminders.id, -1, SQLITE_TRANSIENT)
    if let vikId = Int(pair.vikunja.id) {
        sqlite3_bind_int(stmt, 2, Int32(vikId))
    } else {
        sqlite3_bind_text(stmt, 2, pair.vikunja.id, -1, SQLITE_TRANSIENT)
    }
    if let listId = listId {
        sqlite3_bind_text(stmt, 3, listId, -1, SQLITE_TRANSIENT)
    } else {
        sqlite3_bind_null(stmt, 3)
    }
    if let projectId = projectId {
        sqlite3_bind_int(stmt, 4, Int32(projectId))
    } else {
        sqlite3_bind_null(stmt, 4)
    }
    sqlite3_bind_text(stmt, 5, detectedAt, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 6, remindersJson, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 7, vikunjaJson, -1, SQLITE_TRANSIENT)
    sqlite3_bind_text(stmt, 8, diffsJson, -1, SQLITE_TRANSIENT)
    if sqlite3_step(stmt) != SQLITE_DONE {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 9, userInfo: [NSLocalizedDescriptionKey: "Insert conflict failed: \(message)"])
    }
}

func syncConflicts(db: OpaquePointer?, listId: String?, projectId: Int?, conflicts: [TaskPair]) throws {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let detectedAt = formatter.string(from: Date())
    try clearConflicts(db: db, listId: listId, projectId: projectId)
    for pair in conflicts {
        try upsertConflict(db: db, listId: listId, projectId: projectId, pair: pair, detectedAt: detectedAt)
    }
}

func migrateNullListFields(db: OpaquePointer?, listId: String, projectId: Int) throws {
    let sql = """
    UPDATE task_sync_map
    SET list_reminders_id = COALESCE(list_reminders_id, ?),
        project_id = COALESCE(project_id, ?)
    WHERE list_reminders_id IS NULL OR project_id IS NULL;
    """
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 14, userInfo: [NSLocalizedDescriptionKey: "Prepare migrate failed: \(message)"])
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, listId, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int(stmt, 2, Int32(projectId))
    if sqlite3_step(stmt) != SQLITE_DONE {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 15, userInfo: [NSLocalizedDescriptionKey: "Migrate failed: \(message)"])
    }
}

func insertMapping(
    db: OpaquePointer?,
    remindersId: String,
    vikunjaId: Int,
    listId: String,
    projectId: Int,
    dateOnlyDue: Bool = false,
    dateOnlyStart: Bool = false,
    inferredDue: Bool = false
) throws {
    let sql = """
    INSERT OR REPLACE INTO task_sync_map
    (reminders_id, vikunja_id, list_reminders_id, project_id, sync_version, last_seen_modified_reminders, last_seen_modified_vikunja, last_synced_at, date_only_due, date_only_start, inferred_due)
    VALUES (?, ?, ?, ?, 1, NULL, NULL, NULL, ?, ?, ?);
    """
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 4, userInfo: [NSLocalizedDescriptionKey: "Prepare insert failed: \(message)"])
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, remindersId, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int(stmt, 2, Int32(vikunjaId))
    sqlite3_bind_text(stmt, 3, listId, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int(stmt, 4, Int32(projectId))
    sqlite3_bind_int(stmt, 5, dateOnlyDue ? 1 : 0)
    sqlite3_bind_int(stmt, 6, dateOnlyStart ? 1 : 0)
    sqlite3_bind_int(stmt, 7, inferredDue ? 1 : 0)
    if sqlite3_step(stmt) != SQLITE_DONE {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 5, userInfo: [NSLocalizedDescriptionKey: "Insert failed: \(message)"])
    }
}

func updateDateOnlyFlags(
    db: OpaquePointer?,
    remindersId: String,
    vikunjaId: Int,
    dateOnlyDue: Bool,
    dateOnlyStart: Bool,
    inferredDue: Bool
) throws {
    let sql = """
    UPDATE task_sync_map
    SET date_only_due = ?, date_only_start = ?, inferred_due = ?
    WHERE reminders_id = ? AND vikunja_id = ?;
    """
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 12, userInfo: [NSLocalizedDescriptionKey: "Prepare update failed: \(message)"])
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_int(stmt, 1, dateOnlyDue ? 1 : 0)
    sqlite3_bind_int(stmt, 2, dateOnlyStart ? 1 : 0)
    sqlite3_bind_int(stmt, 3, inferredDue ? 1 : 0)
    sqlite3_bind_text(stmt, 4, remindersId, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int(stmt, 5, Int32(vikunjaId))
    if sqlite3_step(stmt) != SQLITE_DONE {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 13, userInfo: [NSLocalizedDescriptionKey: "Update failed: \(message)"])
    }
}

func updateSyncTimestamps(
    db: OpaquePointer?,
    remindersId: String,
    vikunjaId: Int,
    lastSeenReminders: String?,
    lastSeenVikunja: String?
) throws {
    let sql = """
    UPDATE task_sync_map
    SET last_seen_modified_reminders = ?,
        last_seen_modified_vikunja = ?,
        last_synced_at = ?
    WHERE reminders_id = ? AND vikunja_id = ?;
    """
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 10, userInfo: [NSLocalizedDescriptionKey: "Prepare update failed: \(message)"])
    }
    defer { sqlite3_finalize(stmt) }
    let now = isoDate(Date())
    if let rem = lastSeenReminders {
        sqlite3_bind_text(stmt, 1, rem, -1, SQLITE_TRANSIENT)
    } else {
        sqlite3_bind_null(stmt, 1)
    }
    if let vik = lastSeenVikunja {
        sqlite3_bind_text(stmt, 2, vik, -1, SQLITE_TRANSIENT)
    } else {
        sqlite3_bind_null(stmt, 2)
    }
    if let now = now {
        sqlite3_bind_text(stmt, 3, now, -1, SQLITE_TRANSIENT)
    } else {
        sqlite3_bind_null(stmt, 3)
    }
    sqlite3_bind_text(stmt, 4, remindersId, -1, SQLITE_TRANSIENT)
    sqlite3_bind_int(stmt, 5, Int32(vikunjaId))
    if sqlite3_step(stmt) != SQLITE_DONE {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 11, userInfo: [NSLocalizedDescriptionKey: "Update failed: \(message)"])
    }
}

func deleteMappingByRemindersId(db: OpaquePointer?, remindersId: String) throws {
    let sql = "DELETE FROM task_sync_map WHERE reminders_id = ?"
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 6, userInfo: [NSLocalizedDescriptionKey: "Prepare delete failed: \(message)"])
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, remindersId, -1, SQLITE_TRANSIENT)
    if sqlite3_step(stmt) != SQLITE_DONE {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 7, userInfo: [NSLocalizedDescriptionKey: "Delete failed: \(message)"])
    }
}

func deleteMappingByVikunjaId(db: OpaquePointer?, vikunjaId: Int) throws {
    let sql = "DELETE FROM task_sync_map WHERE vikunja_id = ?"
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 8, userInfo: [NSLocalizedDescriptionKey: "Prepare delete failed: \(message)"])
    }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_int(stmt, 1, Int32(vikunjaId))
    if sqlite3_step(stmt) != SQLITE_DONE {
        let message = String(cString: sqlite3_errmsg(db))
        throw NSError(domain: "sqlite", code: 9, userInfo: [NSLocalizedDescriptionKey: "Delete failed: \(message)"])
    }
}

struct ListMapping {
    let remindersListId: String
    let remindersListTitle: String
    let vikunjaProjectId: Int?
    let vikunjaProjectTitle: String
}

func loadListMap(path: String?) throws -> [String: String] {
    guard let path = path, FileManager.default.fileExists(atPath: path) else {
        return [:]
    }
    return try loadKeyValueFile(path)
}

func resolveListMappings(config: Config, calendars: [EKCalendar], listMap: [String: String], apply: Bool) throws -> [ListMapping] {
    func normalizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.precomposedStringWithCanonicalMapping.lowercased()
        var scalars: [UnicodeScalar] = []
        scalars.reserveCapacity(normalized.unicodeScalars.count)
        var lastWasSpace = false
        for scalar in normalized.unicodeScalars {
            if scalar.properties.isWhitespace {
                if !lastWasSpace {
                    scalars.append(" ")
                    lastWasSpace = true
                }
            } else {
                scalars.append(scalar)
                lastWasSpace = false
            }
        }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let debugListMatch = ProcessInfo.processInfo.environment["VIKUNJA_DEBUG_LIST_MATCH"] == "1"

    let useMap = !listMap.isEmpty
    if !config.syncAllLists && !useMap {
        guard let listId = config.remindersListId else {
            throw NSError(domain: "config", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing reminders_list_id for single-list sync"])
        }
        guard let projectId = config.vikunjaProjectId else {
            throw NSError(domain: "config", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing project_id for single-list sync"])
        }
        guard let calendar = calendars.first(where: { $0.calendarIdentifier == listId }) else {
            throw NSError(domain: "reminders", code: 3, userInfo: [NSLocalizedDescriptionKey: "Reminders list not found: \(listId)"])
        }
        return [ListMapping(remindersListId: listId, remindersListTitle: calendar.title, vikunjaProjectId: projectId, vikunjaProjectTitle: "Project \(projectId)")]
    }

    let projects = try fetchVikunjaProjects(apiBase: config.vikunjaApiBase, token: config.vikunjaToken)
    let projectsById = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
    let projectsByTitle = Dictionary(grouping: projects, by: { normalizedTitle($0.title) })
    let calendarsById = Dictionary(uniqueKeysWithValues: calendars.map { ($0.calendarIdentifier, $0) })

    func mapValue(for calendar: EKCalendar) -> String? {
        if let value = listMap[calendar.calendarIdentifier] {
            return value
        }
        let normalizedCalendar = normalizedTitle(calendar.title)
        let match = listMap.first { normalizedTitle($0.key) == normalizedCalendar }
        return match?.value
    }

    var targets: [EKCalendar] = []
    if config.syncAllLists {
        targets = calendars
    } else {
        for key in listMap.keys.sorted() {
            if let calendar = calendarsById[key] {
                targets.append(calendar)
            } else if let match = calendars.first(where: { $0.title.caseInsensitiveCompare(key) == .orderedSame }) {
                targets.append(match)
            } else {
                print("Warning: Reminders list not found for mapping key '\(key)'")
            }
        }
    }

    var mappings: [ListMapping] = []
    for calendar in targets {
        let rawValue = mapValue(for: calendar)?.trimmingCharacters(in: .whitespacesAndNewlines)
        var projectId: Int?
        var projectTitle = calendar.title
        if let rawValue = rawValue, !rawValue.isEmpty {
            if let parsed = Int(rawValue) {
                projectId = parsed
                projectTitle = projectsById[parsed]?.title ?? "Project \(parsed)"
            } else {
                projectTitle = rawValue
            }
        }
        if projectId == nil {
            let normalizedProjectTitle = normalizedTitle(projectTitle)
            let candidates = projectsByTitle[normalizedProjectTitle] ?? []
            if let existing = candidates.first {
                if candidates.count > 1 {
                    print("Warning: Multiple projects named '\(projectTitle)'; using id \(existing.id)")
                }
                projectId = existing.id
            } else if apply {
                let created = try createVikunjaProject(apiBase: config.vikunjaApiBase, token: config.vikunjaToken, title: projectTitle)
                projectId = created.id
                projectTitle = created.title
                print("Created Vikunja project '\(projectTitle)' -> \(created.id)")
            } else {
                if debugListMatch {
                    print("Debug: No project match for '\(projectTitle)' (normalized='\(normalizedProjectTitle)').")
                    let sample = projects.prefix(12).map { project in
                        "'\(project.title)' -> '\(normalizedTitle(project.title))'"
                    }
                    if !sample.isEmpty {
                        print("Debug: Sample project titles: \(sample.joined(separator: ", "))")
                    } else {
                        print("Debug: No projects returned to match.")
                    }
                }
                print("Note: Missing Vikunja project for '\(projectTitle)'; will create on apply")
            }
        }
        mappings.append(ListMapping(
            remindersListId: calendar.calendarIdentifier,
            remindersListTitle: calendar.title,
            vikunjaProjectId: projectId,
            vikunjaProjectTitle: projectTitle
        ))
    }
    return mappings
}

// MARK: - Sync Runner

public func runSync(config: Config, options: SyncOptions) throws -> SyncSummary {
    let apply = options.apply
    let allowConflicts = options.allowConflicts
    let conflictReportPath = options.conflictReportPath
    let resolveConflicts = options.resolveConflicts
    let progress = options.progress
    let conflictResolutions = options.conflictResolutions
    let db = try openSyncDb(path: config.syncDbPath)
    let store = try authorizedRemindersStore()
    let calendars = store.calendars(for: .reminder)
    let calendarById = Dictionary(uniqueKeysWithValues: calendars.map { ($0.calendarIdentifier, $0) })
    let listMap = try loadListMap(path: config.listMapPath)
    let mappings = try resolveListMappings(config: config, calendars: calendars, listMap: listMap, apply: apply)
    var conflictReportItems: [[String: Any]] = []
    var summary = SyncSummary(
        listsProcessed: 0,
        createdInVikunja: 0,
        createdInReminders: 0,
        updatedVikunja: 0,
        updatedReminders: 0,
        deletedVikunja: 0,
        deletedReminders: 0,
        conflicts: 0
    )

    if mappings.count == 1, let projectId = mappings[0].vikunjaProjectId {
        try migrateNullListFields(db: db, listId: mappings[0].remindersListId, projectId: projectId)
    }

    progress?(SyncProgress(message: "Starting sync", listTitle: nil))

    for mapping in mappings {
        guard let calendar = calendarById[mapping.remindersListId] else {
            print("Warning: Skipping missing Reminders list \(mapping.remindersListId)")
            continue
        }
        progress?(SyncProgress(message: "Syncing list", listTitle: mapping.remindersListTitle))
        summary = SyncSummary(
            listsProcessed: summary.listsProcessed + 1,
            createdInVikunja: summary.createdInVikunja,
            createdInReminders: summary.createdInReminders,
            updatedVikunja: summary.updatedVikunja,
            updatedReminders: summary.updatedReminders,
            deletedVikunja: summary.deletedVikunja,
            deletedReminders: summary.deletedReminders,
            conflicts: summary.conflicts
        )
        print("Syncing list '\(mapping.remindersListTitle)' -> '\(mapping.vikunjaProjectTitle)'")
        let records = try loadSyncRecords(db: db, listId: mapping.remindersListId, projectId: mapping.vikunjaProjectId)
        let remindersTasks = try fetchReminders(calendar: calendar, store: store)
        let vikunjaTasks = mapping.vikunjaProjectId == nil
            ? []
            : try fetchVikunjaTasks(apiBase: config.vikunjaApiBase, token: config.vikunjaToken, projectId: mapping.vikunjaProjectId!)
        let plan = diffTasks(reminders: remindersTasks, vikunja: vikunjaTasks, records: records)
        try syncConflicts(db: db, listId: mapping.remindersListId, projectId: mapping.vikunjaProjectId, conflicts: plan.conflicts)
        progress?(SyncProgress(message: "Computed plan", listTitle: mapping.remindersListTitle))

        func conflictResolution(for pair: TaskPair) -> ConflictResolution {
            let key = ConflictKey(remindersId: pair.reminders.id, vikunjaId: pair.vikunja.id)
            return conflictResolutions[key] ?? .none
        }

        if conflictReportPath != nil && !plan.conflicts.isEmpty {
            let shouldFilterResolved = !conflictResolutions.isEmpty
            for pair in plan.conflicts {
                let resolution = conflictResolution(for: pair)
                if shouldFilterResolved && (resolution != .none || resolveConflicts != .none) {
                    continue
                }
                let diffs = conflictFieldDiffs(reminders: pair.reminders, vikunja: pair.vikunja)
                let item: [String: Any] = [
                    "reminders_list_id": mapping.remindersListId,
                    "reminders_list_title": mapping.remindersListTitle,
                    "vikunja_project_id": jsonValue(mapping.vikunjaProjectId),
                    "vikunja_project_title": jsonValue(mapping.vikunjaProjectTitle),
                    "reminders": commonTaskPayload(pair.reminders),
                    "vikunja": commonTaskPayload(pair.vikunja),
                    "diffs": conflictDiffPayloads(diffs)
                ]
                conflictReportItems.append(item)
            }
        }

        var conflictUpdatesToVikunja: [TaskPair] = []
        var conflictUpdatesToReminders: [TaskPair] = []
        if resolveConflicts != .none || !conflictResolutions.isEmpty {
            for pair in plan.conflicts {
                let resolution = conflictResolution(for: pair)
                let decision = resolution == .none ? resolveConflicts : resolution
                switch decision {
                case .reminders:
                    conflictUpdatesToVikunja.append(pair)
                case .vikunja:
                    conflictUpdatesToReminders.append(pair)
                case .lastWriteWins:
                    let remUpdated = parseISODate(pair.reminders.updatedAt)
                    let vikUpdated = parseISODate(pair.vikunja.updatedAt)
                    if let remDate = remUpdated, let vikDate = vikUpdated {
                        if remDate >= vikDate {
                            conflictUpdatesToVikunja.append(pair)
                        } else {
                            conflictUpdatesToReminders.append(pair)
                        }
                    }
                case .none:
                    break
                }
            }
        }
        let updateVikunjaPairs = plan.toUpdateVikunja + conflictUpdatesToVikunja
        let updateRemindersPairs = plan.toUpdateReminders + conflictUpdatesToReminders
        summary = SyncSummary(
            listsProcessed: summary.listsProcessed,
            createdInVikunja: summary.createdInVikunja + plan.toCreateInVikunja.count,
            createdInReminders: summary.createdInReminders + plan.toCreateInReminders.count,
            updatedVikunja: summary.updatedVikunja + updateVikunjaPairs.count,
            updatedReminders: summary.updatedReminders + updateRemindersPairs.count,
            deletedVikunja: summary.deletedVikunja + plan.toDeleteInVikunja.count,
            deletedReminders: summary.deletedReminders + plan.toDeleteInReminders.count,
            conflicts: summary.conflicts + plan.conflicts.count
        )

        if apply {
            let unresolvedConflicts = plan.conflicts.filter { conflictResolution(for: $0) == .none }
            if !unresolvedConflicts.isEmpty && !allowConflicts && resolveConflicts == .none {
                throw NSError(domain: "sync", code: 3, userInfo: [NSLocalizedDescriptionKey: "Conflicts detected (\(plan.conflicts.count)). Re-run with --allow-conflicts or --resolve-conflicts=reminders|vikunja|last-write-wins."])
            }
            guard let projectId = mapping.vikunjaProjectId else {
                throw NSError(domain: "vikunja", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing project id for list \(mapping.remindersListTitle)"])
            }

            func createVikunjaTask(from task: CommonTask) throws -> Int {
                var payload: [String: Any] = [
                    "title": task.title,
                    "done": task.isCompleted
                ]
                if let due = vikunjaDateString(from: task.due) {
                    payload["due_date"] = due
                }
                if let start = vikunjaDateString(from: task.start) {
                    payload["start_date"] = start
                }
                if !task.alarms.isEmpty {
                    let reminders = task.alarms.map { alarm -> [String: Any] in
                        if alarm.type == "absolute", let abs = alarm.absolute {
                            return ["reminder": abs]
                        }
                        return [
                            "relative_period": alarm.relativeSeconds ?? 0,
                            "relative_to": relativeToForVikunja(alarm.relativeTo)
                        ]
                    }
                    payload["reminders"] = reminders
                }
                if let recurrence = task.recurrence {
                    switch recurrence.frequency {
                    case "daily":
                        payload["repeat_after"] = recurrence.interval * 86400
                        payload["repeat_mode"] = 0
                    case "weekly":
                        payload["repeat_after"] = recurrence.interval * 604800
                        payload["repeat_mode"] = 0
                    case "monthly":
                        payload["repeat_after"] = 0
                        payload["repeat_mode"] = 1
                    default:
                        break
                    }
                }
                let data = try vikunjaRequest(apiBase: config.vikunjaApiBase, token: config.vikunjaToken, method: "PUT", path: "/projects/\(projectId)/tasks", body: payload)
                let created = try JSONDecoder().decode(VikunjaTask.self, from: data)
                return created.id
            }

            func updateVikunjaTask(id: String, from task: CommonTask, inferredDue: Bool) throws {
                var payload: [String: Any] = [
                    "title": task.title,
                    "done": task.isCompleted
                ]
                if !inferredDue, let due = vikunjaDateString(from: task.due) {
                    payload["due_date"] = due
                } else {
                    payload["due_date"] = nil
                }
                if let start = vikunjaDateString(from: task.start) {
                    payload["start_date"] = start
                } else {
                    payload["start_date"] = nil
                }
                if !task.alarms.isEmpty {
                    let reminders = task.alarms.map { alarm -> [String: Any] in
                        if alarm.type == "absolute", let abs = alarm.absolute {
                            return ["reminder": abs]
                        }
                        return [
                            "relative_period": alarm.relativeSeconds ?? 0,
                            "relative_to": relativeToForVikunja(alarm.relativeTo)
                        ]
                    }
                    payload["reminders"] = reminders
                }
                if let recurrence = task.recurrence {
                    switch recurrence.frequency {
                    case "daily":
                        payload["repeat_after"] = recurrence.interval * 86400
                        payload["repeat_mode"] = 0
                    case "weekly":
                        payload["repeat_after"] = recurrence.interval * 604800
                        payload["repeat_mode"] = 0
                    case "monthly":
                        payload["repeat_after"] = 0
                        payload["repeat_mode"] = 1
                    default:
                        break
                    }
                }
                _ = try vikunjaRequest(apiBase: config.vikunjaApiBase, token: config.vikunjaToken, method: "POST", path: "/tasks/\(id)", body: payload)
            }

            func deleteVikunjaTask(id: String) throws {
                do {
                    _ = try vikunjaRequest(apiBase: config.vikunjaApiBase, token: config.vikunjaToken, method: "DELETE", path: "/tasks/\(id)", body: nil)
                } catch {
                    let nsError = error as NSError
                    if nsError.domain == "vikunja", nsError.code == 404 {
                        fputs("Warning: Vikunja task \(id) already deleted.\n", stderr)
                        return
                    }
                    throw error
                }
            }

            func createReminder(from task: CommonTask) throws -> (String, Bool) {
                let reminder = EKReminder(eventStore: store)
                reminder.calendar = calendar
                reminder.title = task.title
                reminder.isCompleted = task.isCompleted
                if let due = dateComponentsFromISO(task.due, dateOnly: isDateOnlyString(task.due)) {
                    reminder.dueDateComponents = due
                }
                if let start = dateComponentsFromISO(task.start, dateOnly: isDateOnlyString(task.start)) {
                    reminder.startDateComponents = start
                }
                var inferredDue = false
                if task.recurrence != nil && reminder.dueDateComponents == nil {
                    let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                    reminder.dueDateComponents = today
                    inferredDue = true
                }
                if !task.alarms.isEmpty {
                    for alarm in task.alarms {
                        if alarm.type == "absolute", let abs = alarm.absolute, let date = parseISODate(abs) {
                            reminder.addAlarm(EKAlarm(absoluteDate: date))
                        } else if alarm.type == "relative", let offset = alarm.relativeSeconds {
                            reminder.addAlarm(EKAlarm(relativeOffset: TimeInterval(offset)))
                        }
                    }
                }
                if let recurrence = task.recurrence {
                    let frequency: EKRecurrenceFrequency
                    switch recurrence.frequency {
                    case "daily": frequency = .daily
                    case "weekly": frequency = .weekly
                    case "monthly": frequency = .monthly
                    case "yearly": frequency = .yearly
                    default: frequency = .daily
                    }
                    reminder.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: frequency, interval: recurrence.interval, end: nil))
                }
                try store.save(reminder, commit: true)
                return (reminder.calendarItemIdentifier, inferredDue)
            }

            func updateReminder(id: String, from task: CommonTask, dateOnlyDue: Bool, dateOnlyStart: Bool) throws -> Bool {
                guard let item = store.calendarItem(withIdentifier: id) as? EKReminder else {
                    throw NSError(domain: "reminders", code: 4, userInfo: [NSLocalizedDescriptionKey: "Reminder not found: \(id)"])
                }
                item.title = task.title
                item.isCompleted = task.isCompleted
                item.dueDateComponents = dateComponentsFromISO(task.due, dateOnly: dateOnlyDue)
                item.startDateComponents = dateComponentsFromISO(task.start, dateOnly: dateOnlyStart)
                var inferredDue = false
                if task.recurrence != nil && item.dueDateComponents == nil {
                    let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                    item.dueDateComponents = today
                    inferredDue = true
                }
                if let existingAlarms = item.alarms {
                    for alarm in existingAlarms {
                        item.removeAlarm(alarm)
                    }
                }
                if !task.alarms.isEmpty {
                    for alarm in task.alarms {
                        if alarm.type == "absolute", let abs = alarm.absolute, let date = parseISODate(abs) {
                            item.addAlarm(EKAlarm(absoluteDate: date))
                        } else if alarm.type == "relative", let offset = alarm.relativeSeconds {
                            item.addAlarm(EKAlarm(relativeOffset: TimeInterval(offset)))
                        }
                    }
                }
                if let existingRules = item.recurrenceRules {
                    for rule in existingRules {
                        item.removeRecurrenceRule(rule)
                    }
                }
                if let recurrence = task.recurrence {
                    let frequency: EKRecurrenceFrequency
                    switch recurrence.frequency {
                    case "daily": frequency = .daily
                    case "weekly": frequency = .weekly
                    case "monthly": frequency = .monthly
                    case "yearly": frequency = .yearly
                    default: frequency = .daily
                    }
                    item.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: frequency, interval: recurrence.interval, end: nil))
                }
                try store.save(item, commit: true)
                return inferredDue
            }

            func deleteReminder(id: String) throws {
                guard let item = store.calendarItem(withIdentifier: id) as? EKReminder else {
                    return
                }
                try store.remove(item, commit: true)
            }

            for pair in plan.autoMatched {
                if let vikId = Int(pair.vikunja.id) {
                    let dateOnlyDue = pair.reminders.dueIsDateOnly ?? false
                    let dateOnlyStart = pair.reminders.startIsDateOnly ?? false
                    try insertMapping(
                        db: db,
                        remindersId: pair.reminders.id,
                        vikunjaId: vikId,
                        listId: mapping.remindersListId,
                        projectId: projectId,
                        dateOnlyDue: dateOnlyDue,
                        dateOnlyStart: dateOnlyStart,
                        inferredDue: false
                    )
                    try updateSyncTimestamps(
                        db: db,
                        remindersId: pair.reminders.id,
                        vikunjaId: vikId,
                        lastSeenReminders: pair.reminders.updatedAt,
                        lastSeenVikunja: pair.vikunja.updatedAt
                    )
                }
            }

            for task in plan.toCreateInVikunja {
                let newId = try createVikunjaTask(from: task)
                let dateOnlyDue = task.dueIsDateOnly ?? false
                let dateOnlyStart = task.startIsDateOnly ?? false
                try insertMapping(
                    db: db,
                    remindersId: task.id,
                    vikunjaId: newId,
                    listId: mapping.remindersListId,
                    projectId: projectId,
                    dateOnlyDue: dateOnlyDue,
                    dateOnlyStart: dateOnlyStart,
                    inferredDue: false
                )
                try updateSyncTimestamps(
                    db: db,
                    remindersId: task.id,
                    vikunjaId: newId,
                    lastSeenReminders: task.updatedAt,
                    lastSeenVikunja: nil
                )
                print("Created in Vikunja: \(task.title) -> \(newId)")
            }

            for task in plan.toCreateInReminders {
                let (newId, inferredDue) = try createReminder(from: task)
                if let vikId = Int(task.id) {
                    let dateOnlyDue = task.dueIsDateOnly ?? false
                    let dateOnlyStart = task.startIsDateOnly ?? false
                    try insertMapping(
                        db: db,
                        remindersId: newId,
                        vikunjaId: vikId,
                        listId: mapping.remindersListId,
                        projectId: projectId,
                        dateOnlyDue: dateOnlyDue,
                        dateOnlyStart: dateOnlyStart,
                        inferredDue: inferredDue
                    )
                    let reminderUpdated = isoDate(Date())
                    try updateSyncTimestamps(
                        db: db,
                        remindersId: newId,
                        vikunjaId: vikId,
                        lastSeenReminders: reminderUpdated,
                        lastSeenVikunja: task.updatedAt
                    )
                }
                print("Created in Reminders: \(task.title) -> \(newId)")
            }

            for pair in updateVikunjaPairs {
                let record = records[pair.reminders.id]
                let inferredDue = record?.inferredDue ?? false
                try updateVikunjaTask(id: pair.vikunja.id, from: pair.reminders, inferredDue: inferredDue)
                if let vikId = Int(pair.vikunja.id) {
                    let dateOnlyDue = pair.reminders.dueIsDateOnly ?? false
                    let dateOnlyStart = pair.reminders.startIsDateOnly ?? false
                    try insertMapping(
                        db: db,
                        remindersId: pair.reminders.id,
                        vikunjaId: vikId,
                        listId: mapping.remindersListId,
                        projectId: projectId,
                        dateOnlyDue: dateOnlyDue,
                        dateOnlyStart: dateOnlyStart,
                        inferredDue: inferredDue
                    )
                    try updateDateOnlyFlags(
                        db: db,
                        remindersId: pair.reminders.id,
                        vikunjaId: vikId,
                        dateOnlyDue: dateOnlyDue,
                        dateOnlyStart: dateOnlyStart,
                        inferredDue: inferredDue
                    )
                    try updateSyncTimestamps(
                        db: db,
                        remindersId: pair.reminders.id,
                        vikunjaId: vikId,
                        lastSeenReminders: pair.reminders.updatedAt,
                        lastSeenVikunja: pair.vikunja.updatedAt
                    )
                }
                print("Updated Vikunja: \(pair.vikunja.title)")
            }

            for pair in updateRemindersPairs {
                let record = records[pair.reminders.id]
                let dateOnlyDue = record?.dateOnlyDue ?? false
                let dateOnlyStart = record?.dateOnlyStart ?? false
                let inferredDue = try updateReminder(id: pair.reminders.id, from: pair.vikunja, dateOnlyDue: dateOnlyDue, dateOnlyStart: dateOnlyStart)
                if let vikId = Int(pair.vikunja.id) {
                    try insertMapping(
                        db: db,
                        remindersId: pair.reminders.id,
                        vikunjaId: vikId,
                        listId: mapping.remindersListId,
                        projectId: projectId,
                        dateOnlyDue: dateOnlyDue,
                        dateOnlyStart: dateOnlyStart,
                        inferredDue: inferredDue
                    )
                    let reminderUpdated = isoDate(Date())
                    try updateSyncTimestamps(
                        db: db,
                        remindersId: pair.reminders.id,
                        vikunjaId: vikId,
                        lastSeenReminders: reminderUpdated,
                        lastSeenVikunja: pair.vikunja.updatedAt
                    )
                    try updateDateOnlyFlags(
                        db: db,
                        remindersId: pair.reminders.id,
                        vikunjaId: vikId,
                        dateOnlyDue: dateOnlyDue,
                        dateOnlyStart: dateOnlyStart,
                        inferredDue: inferredDue
                    )
                }
                print("Updated Reminders: \(pair.reminders.title)")
            }

            for pair in plan.mappedPairs {
                if let vikId = Int(pair.vikunja.id) {
                    try updateSyncTimestamps(
                        db: db,
                        remindersId: pair.reminders.id,
                        vikunjaId: vikId,
                        lastSeenReminders: pair.reminders.updatedAt,
                        lastSeenVikunja: pair.vikunja.updatedAt
                    )
                }
            }

            for vikId in plan.toDeleteInVikunja {
                try deleteVikunjaTask(id: vikId)
                if let vikIdInt = Int(vikId) {
                    try deleteMappingByVikunjaId(db: db, vikunjaId: vikIdInt)
                }
                print("Deleted in Vikunja: \(vikId)")
            }

            for remId in plan.toDeleteInReminders {
                try deleteReminder(id: remId)
                try deleteMappingByRemindersId(db: db, remindersId: remId)
                print("Deleted in Reminders: \(remId)")
            }
            progress?(SyncProgress(message: "Applied changes", listTitle: mapping.remindersListTitle))
        }
    }

    if let conflictReportPath = conflictReportPath {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let report: [String: Any] = [
            "generated_at": formatter.string(from: Date()),
            "conflict_count": conflictReportItems.count,
            "conflicts": conflictReportItems
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let url = URL(fileURLWithPath: conflictReportPath)
        try data.write(to: url)
        progress?(SyncProgress(message: "Wrote conflict report", listTitle: nil))
    }
    progress?(SyncProgress(message: "Sync complete", listTitle: nil))
    return summary
}
