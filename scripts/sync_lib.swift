import Foundation

// MARK: - Data Models

struct Config {
    let remindersListId: String?
    let vikunjaApiBase: String
    let vikunjaToken: String
    let vikunjaProjectId: Int?
    let syncDbPath: String
    let listMapPath: String?
    let syncAllLists: Bool
}

struct CommonTask {
    let source: String
    let id: String
    let listId: String
    let title: String
    let isCompleted: Bool
    let due: String?
    let start: String?
    let updatedAt: String?
    let alarms: [CommonAlarm]
    let recurrence: CommonRecurrence?
    let dueIsDateOnly: Bool?
    let startIsDateOnly: Bool?
}

struct CommonAlarm: Equatable {
    let type: String
    let absolute: String?
    let relativeSeconds: Int?
    let relativeTo: String?
}

struct CommonRecurrence: Equatable {
    let frequency: String
    let interval: Int
}

struct TaskPair {
    let reminders: CommonTask
    let vikunja: CommonTask
}

struct ConflictFieldDiff {
    let field: String
    let reminders: String
    let vikunja: String
}

struct SyncRecord {
    let remindersId: String
    let vikunjaId: String
    let listRemindersId: String?
    let projectId: Int?
    let lastSeenReminders: String?
    let lastSeenVikunja: String?
    let dateOnlyDue: Bool
    let dateOnlyStart: Bool
    let inferredDue: Bool
}

struct SyncPlan {
    let toCreateInVikunja: [CommonTask]
    let toCreateInReminders: [CommonTask]
    let toUpdateVikunja: [TaskPair]
    let toUpdateReminders: [TaskPair]
    let toDeleteInVikunja: [String]
    let toDeleteInReminders: [String]
    let ignoredMissingCompleted: [String]
    let conflicts: [TaskPair]
    let mappedPairs: [TaskPair]
    let autoMatched: [TaskPair]
    let ambiguousMatches: [String]
    let unknownDirection: [TaskPair]
}

// MARK: - Config Loading

func loadKeyValueFile(_ path: String) throws -> [String: String] {
    let contents = try String(contentsOfFile: path, encoding: .utf8)
    return parseKeyValueString(contents)
}

func parseKeyValueString(_ contents: String) -> [String: String] {
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

func isoDate(_ date: Date?) -> String? {
    guard let date = date else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

func parseISODate(_ value: String?) -> Date? {
    guard let value = value else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) {
        return date
    }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
}

func dateComponentsToISO(_ dc: DateComponents?) -> String? {
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

func dateComponentsIsDateOnly(_ dc: DateComponents?) -> Bool? {
    guard let dc = dc else { return nil }
    let hasTime = dc.hour != nil || dc.minute != nil || dc.second != nil
    return !hasTime
}

func dateComponentsFromISO(_ value: String?, dateOnly: Bool = false) -> DateComponents? {
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

func vikunjaDateString(from value: String?) -> String? {
    let normalized = normalizeDue(value)
    if normalized == "none" { return nil }
    if normalized.count == 10 {
        return normalized + "T00:00:00Z"
    }
    return normalized
}

func normalizeTimestampString(_ value: String?) -> String? {
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

func isDateOnlyString(_ value: String?) -> Bool {
    let normalized = normalizeDue(value)
    return normalized.count == 10
}

// MARK: - Normalization

func normalizeDue(_ due: String?) -> String {
    guard let due = due, !due.isEmpty else { return "none" }
    if due.hasPrefix("0001-01-01T00:00:00") {
        return "none"
    }
    return due
}

func normalizeDueForMatch(_ due: String?) -> String {
    let normalized = normalizeDue(due)
    if normalized == "none" { return normalized }
    if normalized.contains("T00:00:00") && normalized.hasSuffix("Z") {
        return String(normalized.prefix(10))
    }
    return normalizeTimestampString(normalized) ?? normalized
}

func normalizeRelativeTo(_ value: String?) -> String {
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

func relativeToForVikunja(_ value: String?) -> String {
    let normalized = normalizeRelativeTo(value)
    return normalized == "none" ? "due_date" : normalized
}

// MARK: - Signatures for Comparison

func signature(_ task: CommonTask) -> String {
    let title = task.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let completed = task.isCompleted ? "1" : "0"
    let due = normalizeDueForMatch(task.due)
    return "\(title)|\(completed)|\(due)"
}

func matchKey(_ task: CommonTask) -> String {
    let title = task.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let completed = task.isCompleted ? "1" : "0"
    let due = normalizeDueForMatch(task.due)
    return "\(title)|\(completed)|\(due)"
}

func alarmSignature(_ alarms: [CommonAlarm]) -> String {
    let parts = alarms.map { alarm in
        let base = alarm.type + "|" + normalizeRelativeTo(alarm.relativeTo)
        let abs = normalizeTimestampString(alarm.absolute) ?? "none"
        let rel = alarm.relativeSeconds != nil ? String(alarm.relativeSeconds!) : "none"
        return "\(base)|\(abs)|\(rel)"
    }
    return parts.sorted().joined(separator: ",")
}

func alarmComparableSet(task: CommonTask) -> Set<String> {
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

func recurrenceSignature(_ recurrence: CommonRecurrence?) -> String {
    guard let recurrence = recurrence else { return "none" }
    return "\(recurrence.frequency)|\(recurrence.interval)"
}

func conflictFieldDiffs(reminders: CommonTask, vikunja: CommonTask) -> [ConflictFieldDiff] {
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
    addDiff(field: "updatedAt", reminders: reminders.updatedAt ?? "nil", vikunja: vikunja.updatedAt ?? "nil")

    return diffs
}

// MARK: - Diff Logic

func tasksDiffer(_ left: CommonTask, _ right: CommonTask, ignoreDue: Bool = false) -> Bool {
    let sameTitle = left.title.caseInsensitiveCompare(right.title) == .orderedSame
    let sameDone = left.isCompleted == right.isCompleted
    let sameDue = ignoreDue || normalizeDueForMatch(left.due) == normalizeDueForMatch(right.due)
    let sameAlarms = alarmComparableSet(task: left) == alarmComparableSet(task: right)
    let sameRecurrence = recurrenceSignature(left.recurrence) == recurrenceSignature(right.recurrence)
    return !(sameTitle && sameDone && sameDue && sameAlarms && sameRecurrence)
}

func diffTasks(reminders: [CommonTask], vikunja: [CommonTask], records: [String: SyncRecord], verbose: Bool = true) -> SyncPlan {
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
            toCreateInVikunja.append(task)
        }
    }
    for key in onlyInVikunja {
        if let task = vikunjaMap[key]?.first {
            toCreateInReminders.append(task)
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
