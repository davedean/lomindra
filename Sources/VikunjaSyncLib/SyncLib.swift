import Foundation

// MARK: - Data Models

public struct Config {
    public let remindersListId: String?
    public let vikunjaApiBase: String
    public let vikunjaToken: String
    public let vikunjaProjectId: Int?
    public let syncDbPath: String
    public let listMapPath: String?
    public let syncAllLists: Bool

    public init(remindersListId: String?, vikunjaApiBase: String, vikunjaToken: String, vikunjaProjectId: Int?, syncDbPath: String, listMapPath: String?, syncAllLists: Bool) {
        self.remindersListId = remindersListId
        self.vikunjaApiBase = vikunjaApiBase
        self.vikunjaToken = vikunjaToken
        self.vikunjaProjectId = vikunjaProjectId
        self.syncDbPath = syncDbPath
        self.listMapPath = listMapPath
        self.syncAllLists = syncAllLists
    }
}

public struct CommonTask {
    public let source: String
    public let id: String
    public let listId: String
    public let title: String
    public let isCompleted: Bool
    public let due: String?
    public let start: String?
    public let updatedAt: String?
    public let alarms: [CommonAlarm]
    public let recurrence: CommonRecurrence?
    public let dueIsDateOnly: Bool?
    public let startIsDateOnly: Bool?
    public let priority: Int?
    public let notes: String?
    public let isFlagged: Bool
    public let completedAt: String?

    public init(source: String, id: String, listId: String, title: String, isCompleted: Bool, due: String?, start: String?, updatedAt: String?, alarms: [CommonAlarm], recurrence: CommonRecurrence?, dueIsDateOnly: Bool?, startIsDateOnly: Bool?, priority: Int? = nil, notes: String? = nil, isFlagged: Bool = false, completedAt: String? = nil) {
        self.source = source
        self.id = id
        self.listId = listId
        self.title = title
        self.isCompleted = isCompleted
        self.due = due
        self.start = start
        self.updatedAt = updatedAt
        self.alarms = alarms
        self.recurrence = recurrence
        self.dueIsDateOnly = dueIsDateOnly
        self.startIsDateOnly = startIsDateOnly
        self.priority = priority
        self.notes = notes
        self.isFlagged = isFlagged
        self.completedAt = completedAt
    }
}

public struct CommonAlarm: Equatable {
    public let type: String
    public let absolute: String?
    public let relativeSeconds: Int?
    public let relativeTo: String?

    public init(type: String, absolute: String?, relativeSeconds: Int?, relativeTo: String?) {
        self.type = type
        self.absolute = absolute
        self.relativeSeconds = relativeSeconds
        self.relativeTo = relativeTo
    }
}

public struct CommonRecurrence: Equatable {
    public let frequency: String
    public let interval: Int

    public init(frequency: String, interval: Int) {
        self.frequency = frequency
        self.interval = interval
    }
}

public struct TaskPair {
    public let reminders: CommonTask
    public let vikunja: CommonTask

    public init(reminders: CommonTask, vikunja: CommonTask) {
        self.reminders = reminders
        self.vikunja = vikunja
    }
}

public struct ConflictFieldDiff {
    public let field: String
    public let reminders: String
    public let vikunja: String

    public init(field: String, reminders: String, vikunja: String) {
        self.field = field
        self.reminders = reminders
        self.vikunja = vikunja
    }
}

public struct SyncRecord {
    public let remindersId: String
    public let vikunjaId: String
    public let listRemindersId: String?
    public let projectId: Int?
    public let lastSeenReminders: String?
    public let lastSeenVikunja: String?
    public let dateOnlyDue: Bool
    public let dateOnlyStart: Bool
    public let inferredDue: Bool

    public init(remindersId: String, vikunjaId: String, listRemindersId: String?, projectId: Int?, lastSeenReminders: String?, lastSeenVikunja: String?, dateOnlyDue: Bool, dateOnlyStart: Bool, inferredDue: Bool) {
        self.remindersId = remindersId
        self.vikunjaId = vikunjaId
        self.listRemindersId = listRemindersId
        self.projectId = projectId
        self.lastSeenReminders = lastSeenReminders
        self.lastSeenVikunja = lastSeenVikunja
        self.dateOnlyDue = dateOnlyDue
        self.dateOnlyStart = dateOnlyStart
        self.inferredDue = inferredDue
    }
}

public struct SyncPlan {
    public let toCreateInVikunja: [CommonTask]
    public let toCreateInReminders: [CommonTask]
    public let toUpdateVikunja: [TaskPair]
    public let toUpdateReminders: [TaskPair]
    public let toDeleteInVikunja: [String]
    public let toDeleteInReminders: [String]
    public let ignoredMissingCompleted: [String]
    public let conflicts: [TaskPair]
    public let mappedPairs: [TaskPair]
    public let autoMatched: [TaskPair]
    public let ambiguousMatches: [String]
    public let unknownDirection: [TaskPair]

    public init(toCreateInVikunja: [CommonTask], toCreateInReminders: [CommonTask], toUpdateVikunja: [TaskPair], toUpdateReminders: [TaskPair], toDeleteInVikunja: [String], toDeleteInReminders: [String], ignoredMissingCompleted: [String], conflicts: [TaskPair], mappedPairs: [TaskPair], autoMatched: [TaskPair], ambiguousMatches: [String], unknownDirection: [TaskPair]) {
        self.toCreateInVikunja = toCreateInVikunja
        self.toCreateInReminders = toCreateInReminders
        self.toUpdateVikunja = toUpdateVikunja
        self.toUpdateReminders = toUpdateReminders
        self.toDeleteInVikunja = toDeleteInVikunja
        self.toDeleteInReminders = toDeleteInReminders
        self.ignoredMissingCompleted = ignoredMissingCompleted
        self.conflicts = conflicts
        self.mappedPairs = mappedPairs
        self.autoMatched = autoMatched
        self.ambiguousMatches = ambiguousMatches
        self.unknownDirection = unknownDirection
    }
}

// MARK: - Config Loading

public func loadKeyValueFile(_ path: String) throws -> [String: String] {
    let contents = try String(contentsOfFile: path, encoding: .utf8)
    return parseKeyValueString(contents)
}

public func parseKeyValueString(_ contents: String) -> [String: String] {
    var result: [String: String] = [:]
    for rawLine in contents.split(whereSeparator: \.isNewline) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty || line.hasPrefix("#") { continue }
        if let idx = line.firstIndex(of: ":") {
            let key = line[..<idx].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: idx)...].trimmingCharacters(in: .whitespaces)
            result[String(key)] = String(value)
        } else {
            let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            if parts.count == 2 {
                result[String(parts[0])] = String(parts[1])
            }
        }
    }
    return result
}

// MARK: - Date Utilities

public func isoDate(_ date: Date?) -> String? {
    guard let date = date else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

public func parseISODate(_ value: String?) -> Date? {
    guard let value = value else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) {
        return date
    }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
}

public func dateComponentsToISO(_ dc: DateComponents?) -> String? {
    guard var dc = dc else { return nil }
    if dc.calendar == nil {
        dc.calendar = Calendar.current
    }
    let hasTime = dc.hour != nil || dc.minute != nil || dc.second != nil
    if !hasTime {
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

public func dateComponentsIsDateOnly(_ dc: DateComponents?) -> Bool? {
    guard let dc = dc else { return nil }
    let hasTime = dc.hour != nil || dc.minute != nil || dc.second != nil
    return !hasTime
}

public func dateComponentsFromISO(_ value: String?, dateOnly: Bool = false) -> DateComponents? {
    let normalized = normalizeDue(value)
    if normalized == "none" { return nil }
    if normalized.count == 10 {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: normalized) else { return nil }
        return Calendar.current.dateComponents([.year, .month, .day], from: date)
    }
    guard let date = parseISODate(normalized) else { return nil }
    if dateOnly {
        return Calendar.current.dateComponents([.year, .month, .day], from: date)
    }
    return Calendar.current.dateComponents(in: TimeZone.current, from: date)
}

public func vikunjaDateString(from value: String?) -> String? {
    let normalized = normalizeDue(value)
    if normalized == "none" { return nil }
    if normalized.count == 10 {
        // Issue 016 fix: Use local midnight instead of UTC midnight
        // This ensures Vikunja displays the correct local date (00:00 in user's timezone)
        // rather than a misleading time (e.g., 11am in Melbourne for UTC midnight)
        let tz = TimeZone.current
        let offsetSeconds = tz.secondsFromGMT()
        let hours = abs(offsetSeconds) / 3600
        let mins = (abs(offsetSeconds) % 3600) / 60
        let sign = offsetSeconds >= 0 ? "+" : "-"
        return normalized + String(format: "T00:00:00%@%02d:%02d", sign, hours, mins)
    }
    return normalized
}

public func normalizeTimestampString(_ value: String?) -> String? {
    guard let value = value else { return nil }
    if value.count == 10 {
        return value
    }
    if let date = parseISODate(value) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
    return value
}

public func isDateOnlyString(_ value: String?) -> Bool {
    let normalized = normalizeDue(value)
    return normalized.count == 10
}

// MARK: - Normalization

public func normalizeDue(_ due: String?) -> String {
    guard let due = due, !due.isEmpty else { return "none" }
    if due.hasPrefix("0001-01-01T00:00:00") {
        return "none"
    }
    return due
}

public func normalizeDueForMatch(_ due: String?) -> String {
    let normalized = normalizeDue(due)
    if normalized == "none" { return normalized }
    if normalized.contains("T00:00:00") && normalized.hasSuffix("Z") {
        return String(normalized.prefix(10))
    }
    return normalizeTimestampString(normalized) ?? normalized
}

public func normalizeRelativeTo(_ value: String?) -> String {
    switch value {
    case "due", "due_date":
        return "due_date"
    case "start", "start_date":
        return "start_date"
    case "end", "end_date":
        return "end_date"
    default:
        return "none"
    }
}

public func relativeToForVikunja(_ value: String?) -> String {
    let normalized = normalizeRelativeTo(value)
    return normalized == "none" ? "due_date" : normalized
}

// MARK: - Priority Mapping

/// Convert Reminders priority (0/1/5/9) to Vikunja priority (0-3)
public func remindersPriorityToVikunja(_ priority: Int?) -> Int {
    guard let p = priority else { return 0 }
    switch p {
    case 1: return 3      // high
    case 5: return 2      // medium
    case 9: return 1      // low
    default: return 0     // none
    }
}

/// Convert Vikunja priority (0-5) to Reminders priority (0/1/5/9)
public func vikunjaPriorityToReminders(_ priority: Int?) -> Int {
    guard let p = priority else { return 0 }
    switch p {
    case 0: return 0      // none
    case 1: return 9      // low
    case 2: return 5      // medium
    case 3...: return 1   // high (3, 4, 5 all map to high)
    default: return 0
    }
}

// MARK: - Signatures for Comparison

public func signature(_ task: CommonTask) -> String {
    let title = task.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let completed = task.isCompleted ? "1" : "0"
    let due = normalizeDueForMatch(task.due)
    return "\(title)|\(completed)|\(due)"
}

public func matchKey(_ task: CommonTask) -> String {
    let title = task.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let completed = task.isCompleted ? "1" : "0"
    let due = normalizeDueForMatch(task.due)
    return "\(title)|\(completed)|\(due)"
}

public func alarmSignature(_ alarms: [CommonAlarm]) -> String {
    let parts = alarms.map { alarm in
        let base = alarm.type + "|" + normalizeRelativeTo(alarm.relativeTo)
        let abs = normalizeTimestampString(alarm.absolute) ?? "none"
        let rel = alarm.relativeSeconds != nil ? String(alarm.relativeSeconds!) : "none"
        return "\(base)|\(abs)|\(rel)"
    }
    return parts.sorted().joined(separator: ",")
}

public func alarmComparableSet(task: CommonTask) -> Set<String> {
    var results: Set<String> = []
    for alarm in task.alarms {
        if alarm.type == "absolute", let abs = normalizeTimestampString(alarm.absolute) {
            results.insert("abs|\(abs)")
            continue
        }
        if alarm.type == "relative", let offset = alarm.relativeSeconds {
            let relTo = normalizeRelativeTo(alarm.relativeTo)
            let baseDate: String?
            if relTo == "start_date" {
                baseDate = normalizeTimestampString(task.start)
            } else {
                baseDate = normalizeTimestampString(task.due)
            }
            if let base = baseDate, let baseParsed = parseISODate(base) {
                let computed = baseParsed.addingTimeInterval(TimeInterval(offset))
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                results.insert("abs|\(formatter.string(from: computed))")
            } else {
                results.insert("rel|\(relTo)|\(offset)")
            }
        }
    }
    return results
}

public func recurrenceSignature(_ recurrence: CommonRecurrence?) -> String {
    guard let recurrence = recurrence else { return "none" }
    return "\(recurrence.frequency)|\(recurrence.interval)"
}

/// Parse Vikunja repeat_after and repeat_mode into CommonRecurrence
/// - Parameters:
///   - repeatAfter: Seconds between repetitions (nil = no recurrence)
///   - repeatMode: 0 = time-based, 1 = monthly, 2 = from completion (nil defaults to 0)
/// - Returns: CommonRecurrence or nil if no valid recurrence
public func parseVikunjaRecurrence(repeatAfter: Int?, repeatMode: Int?) -> CommonRecurrence? {
    let mode = repeatMode ?? 0  // Default to time-based if nil

    // Mode 1 = monthly (ignore repeat_after)
    if mode == 1 {
        return CommonRecurrence(frequency: "monthly", interval: 1)
    }

    // Mode 0 (or nil) = time-based: need repeat_after
    guard let repeatAfter = repeatAfter, repeatAfter > 0 else {
        return nil
    }

    if repeatAfter % 604800 == 0 {
        return CommonRecurrence(frequency: "weekly", interval: repeatAfter / 604800)
    } else if repeatAfter % 86400 == 0 {
        return CommonRecurrence(frequency: "daily", interval: repeatAfter / 86400)
    }

    return nil
}

public func conflictFieldDiffs(reminders: CommonTask, vikunja: CommonTask) -> [ConflictFieldDiff] {
    var diffs: [ConflictFieldDiff] = []
    func addDiff(field: String, reminders: String, vikunja: String) {
        if reminders != vikunja {
            diffs.append(ConflictFieldDiff(field: field, reminders: reminders, vikunja: vikunja))
        }
    }

    addDiff(field: "title", reminders: reminders.title, vikunja: vikunja.title)
    addDiff(field: "completed", reminders: String(reminders.isCompleted), vikunja: String(vikunja.isCompleted))
    addDiff(field: "due", reminders: normalizeDue(reminders.due), vikunja: normalizeDue(vikunja.due))
    addDiff(field: "dueDateOnly", reminders: String(reminders.dueIsDateOnly ?? false), vikunja: String(vikunja.dueIsDateOnly ?? false))
    addDiff(field: "start", reminders: normalizeDue(reminders.start), vikunja: normalizeDue(vikunja.start))
    addDiff(field: "startDateOnly", reminders: String(reminders.startIsDateOnly ?? false), vikunja: String(vikunja.startIsDateOnly ?? false))
    addDiff(field: "alarms", reminders: alarmSignature(reminders.alarms), vikunja: alarmSignature(vikunja.alarms))
    addDiff(field: "recurrence", reminders: recurrenceSignature(reminders.recurrence), vikunja: recurrenceSignature(vikunja.recurrence))
    addDiff(field: "priority", reminders: String(reminders.priority ?? 0), vikunja: String(vikunja.priority ?? 0))
    addDiff(field: "notes", reminders: reminders.notes ?? "", vikunja: vikunja.notes ?? "")
    addDiff(field: "flagged", reminders: String(reminders.isFlagged), vikunja: String(vikunja.isFlagged))
    addDiff(field: "updatedAt", reminders: reminders.updatedAt ?? "nil", vikunja: vikunja.updatedAt ?? "nil")

    return diffs
}

// MARK: - Diff Logic

public func tasksDiffer(_ left: CommonTask, _ right: CommonTask, ignoreDue: Bool = false) -> Bool {
    let sameTitle = left.title.caseInsensitiveCompare(right.title) == .orderedSame
    let sameDone = left.isCompleted == right.isCompleted
    let sameDue = ignoreDue || normalizeDueForMatch(left.due) == normalizeDueForMatch(right.due)
    let sameAlarms = alarmComparableSet(task: left) == alarmComparableSet(task: right)
    let sameRecurrence = recurrenceSignature(left.recurrence) == recurrenceSignature(right.recurrence)
    let samePriority = (left.priority ?? 0) == (right.priority ?? 0)
    // Normalize nil and empty string as equivalent for notes
    let leftNotes = left.notes?.isEmpty == true ? nil : left.notes
    let rightNotes = right.notes?.isEmpty == true ? nil : right.notes
    let sameNotes = leftNotes == rightNotes
    let sameFlagged = left.isFlagged == right.isFlagged
    return !(sameTitle && sameDone && sameDue && sameAlarms && sameRecurrence && samePriority && sameNotes && sameFlagged)
}

public func diffTasks(reminders: [CommonTask], vikunja: [CommonTask], records: [String: SyncRecord], verbose: Bool = true) -> SyncPlan {
    let remindersById = Dictionary(uniqueKeysWithValues: reminders.map { ($0.id, $0) })
    let vikunjaById = Dictionary(uniqueKeysWithValues: vikunja.map { ($0.id, $0) })

    var matchedCount = 0
    var mismatchedPairs: [(CommonTask, CommonTask)] = []
    var missingInReminders: [(String, String)] = []
    var missingInVikunja: [(String, String)] = []
    var mappedPairs: [TaskPair] = []

    for (remId, record) in records {
        let vikId = record.vikunjaId
        if let rem = remindersById[remId], let vik = vikunjaById[vikId] {
            matchedCount += 1
            mappedPairs.append(TaskPair(reminders: rem, vikunja: vik))
            let sameTitle = rem.title.caseInsensitiveCompare(vik.title) == .orderedSame
            let sameDone = rem.isCompleted == vik.isCompleted
            let ignoreDue = record.inferredDue
            let sameDue = ignoreDue || normalizeDueForMatch(rem.due) == normalizeDueForMatch(vik.due)
            let sameAlarms = alarmComparableSet(task: rem) == alarmComparableSet(task: vik)
            let sameRecurrence = recurrenceSignature(rem.recurrence) == recurrenceSignature(vik.recurrence)
            if !(sameTitle && sameDone && sameDue && sameAlarms && sameRecurrence) {
                mismatchedPairs.append((rem, vik))
            }
        } else if remindersById[remId] == nil {
            missingInReminders.append((remId, vikId))
        } else {
            missingInVikunja.append((remId, vikId))
        }
    }

    let mappedReminderIds = Set(records.keys)
    let mappedVikunjaIds = Set(records.values.map { $0.vikunjaId })

    let unmatchedReminders = reminders.filter { !mappedReminderIds.contains($0.id) }
    let unmatchedVikunja = vikunja.filter { !mappedVikunjaIds.contains($0.id) }

    let remindersMap = Dictionary(grouping: unmatchedReminders, by: matchKey)
    let vikunjaMap = Dictionary(grouping: unmatchedVikunja, by: matchKey)

    let reminderKeys = Set(remindersMap.keys)
    let vikunjaKeys = Set(vikunjaMap.keys)

    let onlyInReminders = reminderKeys.subtracting(vikunjaKeys).sorted()
    let onlyInVikunja = vikunjaKeys.subtracting(reminderKeys).sorted()

    var autoMatched: [TaskPair] = []
    var ambiguousMatches: [String] = []
    for key in reminderKeys.intersection(vikunjaKeys) {
        let remGroup = remindersMap[key] ?? []
        let vikGroup = vikunjaMap[key] ?? []
        if remGroup.count == 1 && vikGroup.count == 1 {
            autoMatched.append(TaskPair(reminders: remGroup[0], vikunja: vikGroup[0]))
        } else {
            ambiguousMatches.append(key)
        }
    }

    var toCreateInVikunja: [CommonTask] = []
    var toCreateInReminders: [CommonTask] = []
    var toDeleteInVikunja: [String] = []
    var toDeleteInReminders: [String] = []
    var ignoredMissingCompleted: [String] = []
    var toUpdateVikunja: [TaskPair] = []
    var toUpdateReminders: [TaskPair] = []
    var unknownDirection: [TaskPair] = []
    var conflicts: [TaskPair] = []

    for pair in mappedPairs {
        let rem = pair.reminders
        let vik = pair.vikunja
        let remUpdated = parseISODate(rem.updatedAt)
        let vikUpdated = parseISODate(vik.updatedAt)
        let record = records[rem.id]
        let ignoreDue = record?.inferredDue ?? false
        let lastRem = parseISODate(record?.lastSeenReminders)
        let lastVik = parseISODate(record?.lastSeenVikunja)
        if lastRem == nil || lastVik == nil {
            if let remDate = remUpdated, let vikDate = vikUpdated {
                if remDate > vikDate {
                    if tasksDiffer(rem, vik, ignoreDue: ignoreDue) {
                        toUpdateVikunja.append(pair)
                    }
                } else if vikDate > remDate {
                    if tasksDiffer(rem, vik, ignoreDue: ignoreDue) {
                        toUpdateReminders.append(pair)
                    }
                }
            } else if remUpdated == nil && vikUpdated == nil {
                unknownDirection.append(pair)
            }
            continue
        }
        let remChanged = remUpdated != nil && remUpdated! > lastRem!
        let vikChanged = vikUpdated != nil && vikUpdated! > lastVik!
        if remChanged && vikChanged {
            conflicts.append(pair)
        } else if remChanged {
            if tasksDiffer(rem, vik, ignoreDue: ignoreDue) {
                toUpdateVikunja.append(pair)
            }
        } else if vikChanged {
            if tasksDiffer(rem, vik, ignoreDue: ignoreDue) {
                toUpdateReminders.append(pair)
            }
        }
    }

    for pair in autoMatched {
        let rem = pair.reminders
        let vik = pair.vikunja
        let remUpdated = parseISODate(rem.updatedAt)
        let vikUpdated = parseISODate(vik.updatedAt)
        if let remDate = remUpdated, let vikDate = vikUpdated {
            if remDate > vikDate {
                if tasksDiffer(rem, vik) {
                    toUpdateVikunja.append(pair)
                }
            } else if vikDate > remDate {
                if tasksDiffer(rem, vik) {
                    toUpdateReminders.append(pair)
                }
            }
        } else {
            unknownDirection.append(pair)
        }
    }

    for key in onlyInReminders {
        if let task = remindersMap[key]?.first {
            // Skip creating completed tasks that were never synced
            if !task.isCompleted {
                toCreateInVikunja.append(task)
            }
        }
    }
    for key in onlyInVikunja {
        if let task = vikunjaMap[key]?.first {
            // Skip creating completed tasks that were never synced
            if !task.isCompleted {
                toCreateInReminders.append(task)
            }
        }
    }

    for pair in missingInReminders {
        if let vik = vikunjaById[pair.1], vik.isCompleted {
            ignoredMissingCompleted.append(pair.1)
        } else {
            toDeleteInVikunja.append(pair.1)
        }
    }

    for pair in missingInVikunja {
        if let rem = remindersById[pair.0], rem.isCompleted {
            ignoredMissingCompleted.append(pair.0)
        } else {
            toDeleteInReminders.append(pair.0)
        }
    }

    if verbose {
        print("Dry-run diff summary")
        print("Reminders tasks: \(reminders.count)")
        print("Vikunja tasks: \(vikunja.count)")
        print("Mapped pairs: \(matchedCount)")
        print("Mapped mismatches: \(mismatchedPairs.count)")
        print("Missing in Reminders (mapped): \(missingInReminders.count)")
        print("Missing in Vikunja (mapped): \(missingInVikunja.count)")
        print("Auto-matched (unmapped): \(autoMatched.count)")
        print("Ambiguous matches: \(ambiguousMatches.count)")
        print("Create in Vikunja: \(toCreateInVikunja.count)")
        print("Create in Reminders: \(toCreateInReminders.count)")
        print("Update Vikunja: \(toUpdateVikunja.count)")
        print("Update Reminders: \(toUpdateReminders.count)")
        print("Delete in Vikunja: \(toDeleteInVikunja.count)")
        print("Delete in Reminders: \(toDeleteInReminders.count)")
        print("Ignored missing (completed): \(ignoredMissingCompleted.count)")
        print("Conflicts: \(conflicts.count)")
        print("Unknown direction: \(unknownDirection.count)")

        if !mismatchedPairs.isEmpty {
            print("Sample mapped mismatches:")
            for (rem, vik) in mismatchedPairs.prefix(5) {
                print("- Reminders: \(rem.title) (due=\(normalizeDueForMatch(rem.due)), completed=\(rem.isCompleted))")
                print("  Vikunja: \(vik.title) (due=\(normalizeDueForMatch(vik.due)), completed=\(vik.isCompleted))")
                print("  Reminders alarms: \(alarmSignature(rem.alarms))")
                print("  Vikunja alarms: \(alarmSignature(vik.alarms))")
                print("  Reminders alarm set: \(alarmComparableSet(task: rem))")
                print("  Vikunja alarm set: \(alarmComparableSet(task: vik))")
                print("  Reminders recurrence: \(recurrenceSignature(rem.recurrence))")
                print("  Vikunja recurrence: \(recurrenceSignature(vik.recurrence))")
            }
        }

        if !toCreateInVikunja.isEmpty {
            print("Sample create in Vikunja:")
            for task in toCreateInVikunja.prefix(10) {
                print("- \(task.title) (due=\(normalizeDue(task.due)), completed=\(task.isCompleted))")
                print("  Alarms: \(alarmSignature(task.alarms))")
                print("  Recurrence: \(recurrenceSignature(task.recurrence))")
            }
        }

        if !toCreateInReminders.isEmpty {
            print("Sample create in Reminders:")
            for task in toCreateInReminders.prefix(10) {
                print("- \(task.title) (due=\(normalizeDue(task.due)), completed=\(task.isCompleted))")
                print("  Alarms: \(alarmSignature(task.alarms))")
                print("  Recurrence: \(recurrenceSignature(task.recurrence))")
            }
        }

        if !unknownDirection.isEmpty {
            print("Sample unknown direction:")
            for pair in unknownDirection.prefix(5) {
                print("- Reminders: \(pair.reminders.title) updated=\(pair.reminders.updatedAt ?? "nil")")
                print("  Vikunja: \(pair.vikunja.title) updated=\(pair.vikunja.updatedAt ?? "nil")")
            }
        }

        if !conflicts.isEmpty {
            print("Sample conflicts:")
            for pair in conflicts.prefix(5) {
                print("- \(pair.reminders.title)")
                print("  Reminders list: \(pair.reminders.listId)")
                print("  Reminders updated: \(pair.reminders.updatedAt ?? "nil")")
                print("  Reminders due: \(normalizeDue(pair.reminders.due)) (dateOnly=\(pair.reminders.dueIsDateOnly ?? false))")
                print("  Reminders start: \(normalizeDue(pair.reminders.start)) (dateOnly=\(pair.reminders.startIsDateOnly ?? false))")
                print("  Reminders completed: \(pair.reminders.isCompleted)")
                print("  Reminders alarms: \(alarmSignature(pair.reminders.alarms))")
                print("  Reminders recurrence: \(recurrenceSignature(pair.reminders.recurrence))")
                print("  Vikunja project: \(pair.vikunja.listId)")
                print("  Vikunja updated: \(pair.vikunja.updatedAt ?? "nil")")
                print("  Vikunja due: \(normalizeDue(pair.vikunja.due)) (dateOnly=\(pair.vikunja.dueIsDateOnly ?? false))")
                print("  Vikunja start: \(normalizeDue(pair.vikunja.start)) (dateOnly=\(pair.vikunja.startIsDateOnly ?? false))")
                print("  Vikunja completed: \(pair.vikunja.isCompleted)")
                print("  Vikunja alarms: \(alarmSignature(pair.vikunja.alarms))")
                print("  Vikunja recurrence: \(recurrenceSignature(pair.vikunja.recurrence))")
                let diffs = conflictFieldDiffs(reminders: pair.reminders, vikunja: pair.vikunja)
                if !diffs.isEmpty {
                    print("  Conflict diffs:")
                    for diff in diffs {
                        print("  - \(diff.field): reminders=\(diff.reminders) vikunja=\(diff.vikunja)")
                    }
                }
            }
        }

        if !toUpdateReminders.isEmpty {
            print("Sample update Reminders:")
            for pair in toUpdateReminders.prefix(5) {
                print("- \(pair.reminders.title)")
                print("  Reminders alarms: \(alarmSignature(pair.reminders.alarms))")
                print("  Vikunja alarms: \(alarmSignature(pair.vikunja.alarms))")
                print("  Reminders recurrence: \(recurrenceSignature(pair.reminders.recurrence))")
                print("  Vikunja recurrence: \(recurrenceSignature(pair.vikunja.recurrence))")
            }
        }

        if !toUpdateVikunja.isEmpty {
            print("Sample update Vikunja:")
            for pair in toUpdateVikunja.prefix(5) {
                print("- \(pair.vikunja.title)")
                print("  Reminders alarms: \(alarmSignature(pair.reminders.alarms))")
                print("  Vikunja alarms: \(alarmSignature(pair.vikunja.alarms))")
                print("  Reminders recurrence: \(recurrenceSignature(pair.reminders.recurrence))")
                print("  Vikunja recurrence: \(recurrenceSignature(pair.vikunja.recurrence))")
            }
        }
    }

    return SyncPlan(
        toCreateInVikunja: toCreateInVikunja,
        toCreateInReminders: toCreateInReminders,
        toUpdateVikunja: toUpdateVikunja,
        toUpdateReminders: toUpdateReminders,
        toDeleteInVikunja: toDeleteInVikunja,
        toDeleteInReminders: toDeleteInReminders,
        ignoredMissingCompleted: ignoredMissingCompleted,
        conflicts: conflicts,
        mappedPairs: mappedPairs,
        autoMatched: autoMatched,
        ambiguousMatches: ambiguousMatches,
        unknownDirection: unknownDirection
    )
}
