import EventKit
import Foundation

struct Config {
    let remindersListId: String
    let vikunjaApiBase: String
    let vikunjaToken: String
    let vikunjaProjectId: Int
}

struct SeedEnvPair: Codable {
    let remindersListId: String
    let remindersListTitle: String
    let vikunjaProjectId: Int
    let vikunjaProjectTitle: String
}

struct SeedEnvState: Codable {
    let listMapPath: String
    let pairs: [SeedEnvPair]
}

struct SeedAlarm: Decodable {
    let type: String
    let absolute: String?
    let relativeSeconds: Int?
    let relativeTo: String?
}

struct SeedRecurrence: Decodable {
    let frequency: String
    let interval: Int
}

struct SeedTask: Decodable {
    let title: String
    let side: String?
    let completed: Bool?
    let due: String?
    let start: String?
    let alarms: [SeedAlarm]?
    let recurrence: SeedRecurrence?
    let priority: Int?
    let notes: String?
    let url: String?
}

struct VikunjaTask: Decodable {
    let id: Int
    let title: String
}

struct VikunjaProject: Decodable {
    let id: Int
    let title: String
}

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

func loadKeyValueFile(_ path: String) throws -> [String: String] {
    let contents = try String(contentsOfFile: path, encoding: .utf8)
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

func loadConfig() throws -> Config {
    let apple = try loadKeyValueFile("apple_details.txt")
    let vikunja = try loadKeyValueFile("vikunja_details.txt")

    guard let remindersListId = apple["reminders_list_id"] ?? apple["sync-list"] else {
        throw NSError(domain: "config", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing reminders_list_id in apple_details.txt"])
    }
    guard let apiBase = vikunja["api_base"] else {
        throw NSError(domain: "config", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing api_base in vikunja_details.txt"])
    }
    guard let token = vikunja["token"] else {
        throw NSError(domain: "config", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing token in vikunja_details.txt"])
    }
    guard let projectIdRaw = vikunja["project_id"], let projectId = Int(projectIdRaw) else {
        throw NSError(domain: "config", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing project_id in vikunja_details.txt"])
    }

    return Config(
        remindersListId: remindersListId,
        vikunjaApiBase: apiBase,
        vikunjaToken: token,
        vikunjaProjectId: projectId
    )
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

func dateComponentsFromISO(_ value: String?) -> DateComponents? {
    guard let value = value else { return nil }
    if value.count == 10 {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: value) else { return nil }
        return Calendar.current.dateComponents([.year, .month, .day], from: date)
    }
    guard let date = parseISODate(value) else { return nil }
    return Calendar.current.dateComponents(in: TimeZone.current, from: date)
}

func vikunjaDateString(from value: String?) -> String? {
    guard let value = value else { return nil }
    if value.count == 10 {
        return value + "T00:00:00Z"
    }
    return value
}

func loadSeedTasks() throws -> [SeedTask] {
    let data = try Data(contentsOf: URL(fileURLWithPath: "scripts/seed_tasks.json"))
    return try JSONDecoder().decode([SeedTask].self, from: data)
}

func filterBySide(_ tasks: [SeedTask], side: String) -> [SeedTask] {
    return tasks.filter { task in
        let s = task.side ?? "both"
        return s == "both" || s == side
    }
}

func remindersAccess(store: EKEventStore) throws {
    let semaphore = DispatchSemaphore(value: 0)
    if #available(macOS 14.0, *) {
        store.requestFullAccessToReminders { _, _ in semaphore.signal() }
    } else {
        store.requestAccess(to: .reminder) { _, _ in semaphore.signal() }
    }
    semaphore.wait()

    let status = EKEventStore.authorizationStatus(for: .reminder)
    if #available(macOS 14.0, *) {
        guard status == .fullAccess || status == .writeOnly else {
            throw NSError(domain: "reminders", code: 2, userInfo: [NSLocalizedDescriptionKey: "Reminders access not authorized"])
        }
    } else {
        guard status == .authorized else {
            throw NSError(domain: "reminders", code: 2, userInfo: [NSLocalizedDescriptionKey: "Reminders access not authorized"])
        }
    }
}

func vikunjaRequest(config: Config, method: String, path: String, body: [String: Any]?) throws -> Data {
    let delegate = InsecureSessionDelegate()
    let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    let url = URL(string: "\(config.vikunjaApiBase)\(path)")!
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.addValue("Bearer \(config.vikunjaToken)", forHTTPHeaderField: "Authorization")
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
            result = .failure(NSError(domain: "vikunja", code: code, userInfo: [NSLocalizedDescriptionKey: "Bad response: \(bodyText)"]))
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

func deleteVikunjaSeedTasks(config: Config, projectId: Int) throws {
    let data = try vikunjaRequest(config: config, method: "GET", path: "/projects/\(projectId)/tasks", body: nil)
    let tasks = try JSONDecoder().decode([VikunjaTask].self, from: data)
    for task in tasks where task.title.hasPrefix("seed:") {
        _ = try vikunjaRequest(config: config, method: "DELETE", path: "/tasks/\(task.id)", body: nil)
        print("Deleted Vikunja task: \(task.title)")
    }
}

func deleteRemindersSeedTasks(store: EKEventStore, calendar: EKCalendar) throws {
    let predicate = store.predicateForReminders(in: [calendar])
    let semaphore = DispatchSemaphore(value: 0)
    var items: [EKReminder] = []
    store.fetchReminders(matching: predicate) { reminders in
        items = reminders ?? []
        semaphore.signal()
    }
    semaphore.wait()

    for reminder in items where (reminder.title ?? "").hasPrefix("seed:") {
        try store.remove(reminder, commit: true)
        print("Deleted Reminder: \(reminder.title ?? "(untitled)")")
    }
}

func fetchReminders(store: EKEventStore, calendar: EKCalendar) throws -> [EKReminder] {
    let predicate = store.predicateForReminders(in: [calendar])
    let semaphore = DispatchSemaphore(value: 0)
    var items: [EKReminder] = []
    store.fetchReminders(matching: predicate) { reminders in
        items = reminders ?? []
        semaphore.signal()
    }
    semaphore.wait()
    return items
}

func updateReminder(store: EKEventStore, calendar: EKCalendar, titlePrefix: String, newTitle: String?, newDue: String?) throws -> Bool {
    let items = try fetchReminders(store: store, calendar: calendar)
    guard let item = items.first(where: { ($0.title ?? "").hasPrefix(titlePrefix) }) else {
        return false
    }
    if let newTitle = newTitle {
        item.title = newTitle
    }
    if let newDue = newDue {
        item.dueDateComponents = dateComponentsFromISO(newDue)
    }
    try store.save(item, commit: true)
    return true
}

func updateVikunjaTask(config: Config, projectId: Int, titlePrefix: String, newTitle: String?, newDue: String?) throws -> Bool {
    let data = try vikunjaRequest(config: config, method: "GET", path: "/projects/\(projectId)/tasks", body: nil)
    let tasks = try JSONDecoder().decode([VikunjaTask].self, from: data)
    guard let task = tasks.first(where: { $0.title.hasPrefix(titlePrefix) }) else {
        return false
    }
    var payload: [String: Any] = [:]
    if let newTitle = newTitle {
        payload["title"] = newTitle
    }
    if let newDue = newDue {
        payload["due_date"] = vikunjaDateString(from: newDue)
    }
    if payload.isEmpty {
        return true
    }
    _ = try vikunjaRequest(config: config, method: "POST", path: "/tasks/\(task.id)", body: payload)
    return true
}

func mutateConflictTasks(config: Config, store: EKEventStore, calendar: EKCalendar, projectId: Int) throws {
    let titleChangedRem = try updateReminder(
        store: store,
        calendar: calendar,
        titlePrefix: "seed: conflict-title",
        newTitle: "seed: conflict-title (reminders)",
        newDue: nil
    )
    let titleChangedVik = try updateVikunjaTask(
        config: config,
        projectId: projectId,
        titlePrefix: "seed: conflict-title",
        newTitle: "seed: conflict-title (vikunja)",
        newDue: nil
    )
    let dueChangedRem = try updateReminder(
        store: store,
        calendar: calendar,
        titlePrefix: "seed: conflict-due",
        newTitle: nil,
        newDue: "2026-03-01"
    )
    let dueChangedVik = try updateVikunjaTask(
        config: config,
        projectId: projectId,
        titlePrefix: "seed: conflict-due",
        newTitle: nil,
        newDue: "2026-03-02"
    )

    if !titleChangedRem || !titleChangedVik {
        print("Warning: conflict-title task not found on one or both sides.")
    }
    if !dueChangedRem || !dueChangedVik {
        print("Warning: conflict-due task not found on one or both sides.")
    }
}

func createReminder(store: EKEventStore, calendar: EKCalendar, task: SeedTask) throws -> String {
    let reminder = EKReminder(eventStore: store)
    reminder.calendar = calendar
    reminder.title = task.title
    reminder.isCompleted = task.completed ?? false
    if let due = dateComponentsFromISO(task.due) {
        reminder.dueDateComponents = due
    }
    if let start = dateComponentsFromISO(task.start) {
        reminder.startDateComponents = start
    }
    if let alarms = task.alarms {
        for alarm in alarms {
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
    // Priority: Reminders uses 0 (none), 1 (high), 5 (medium), 9 (low)
    if let priority = task.priority {
        reminder.priority = priority
    }
    if let notes = task.notes {
        reminder.notes = notes
    }
    if let urlString = task.url, let url = URL(string: urlString) {
        reminder.url = url
    }
    try store.save(reminder, commit: true)
    return reminder.calendarItemIdentifier
}

/// Convert Reminders priority (0/1/5/9) to Vikunja priority (0-3)
func remindersPriorityToVikunja(_ priority: Int?) -> Int {
    guard let p = priority else { return 0 }
    switch p {
    case 1: return 3  // high
    case 5: return 2  // medium
    case 9: return 1  // low
    default: return 0 // none
    }
}

/// Embed URL in description using markers (matches sync logic)
func embedUrlInDescription(description: String?, url: String?) -> String? {
    guard let url = url, !url.isEmpty else { return description }
    let urlBlock = "[URL:\(url)]"
    if let desc = description, !desc.isEmpty {
        return urlBlock + "\n\n" + desc
    }
    return urlBlock
}

func createVikunjaTask(config: Config, projectId: Int, task: SeedTask) throws -> Int {
    var payload: [String: Any] = [
        "title": task.title,
        "done": task.completed ?? false
    ]
    if let due = vikunjaDateString(from: task.due) {
        payload["due_date"] = due
    }
    if let start = vikunjaDateString(from: task.start) {
        payload["start_date"] = start
    }
    if let alarms = task.alarms {
        let reminders = alarms.map { alarm -> [String: Any] in
            if alarm.type == "absolute", let abs = alarm.absolute {
                return ["reminder": abs]
            }
            let base = alarm.relativeTo == "due" ? "due_date" : (alarm.relativeTo == "start" ? "start_date" : alarm.relativeTo ?? "due_date")
            return [
                "relative_period": alarm.relativeSeconds ?? 0,
                "relative_to": base
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
    // Priority: convert from Reminders format to Vikunja format
    if let priority = task.priority {
        payload["priority"] = remindersPriorityToVikunja(priority)
    }
    // Description: notes with optional embedded URL
    let description = embedUrlInDescription(description: task.notes, url: task.url)
    if let desc = description, !desc.isEmpty {
        payload["description"] = desc
    }
    let data = try vikunjaRequest(config: config, method: "PUT", path: "/projects/\(projectId)/tasks", body: payload)
    let created = try JSONDecoder().decode(VikunjaTask.self, from: data)
    return created.id
}

func createVikunjaProject(config: Config, title: String) throws -> VikunjaProject {
    let payload: [String: Any] = ["title": title]
    let data = try vikunjaRequest(config: config, method: "PUT", path: "/projects", body: payload)
    return try JSONDecoder().decode(VikunjaProject.self, from: data)
}

func deleteVikunjaProject(config: Config, projectId: Int) throws {
    _ = try vikunjaRequest(config: config, method: "DELETE", path: "/projects/\(projectId)", body: nil)
}

func createRemindersList(store: EKEventStore, title: String) throws -> EKCalendar {
    let calendar = EKCalendar(for: .reminder, eventStore: store)
    if let defaultSource = store.defaultCalendarForNewReminders()?.source {
        calendar.source = defaultSource
    } else if let firstSource = store.sources.first(where: { $0.sourceType != .calDAV }) {
        calendar.source = firstSource
    } else if let fallback = store.sources.first {
        calendar.source = fallback
    }
    calendar.title = title
    try store.saveCalendar(calendar, commit: true)
    return calendar
}

func deleteRemindersList(store: EKEventStore, listId: String) throws {
    guard let calendar = store.calendar(withIdentifier: listId) else {
        return
    }
    try store.removeCalendar(calendar, commit: true)
}

func writeSeedState(_ state: SeedEnvState, path: String) throws {
    let data = try JSONEncoder().encode(state)
    try data.write(to: URL(fileURLWithPath: path))
}

func loadSeedState(path: String) throws -> SeedEnvState {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(SeedEnvState.self, from: data)
}

func writeListMap(pairs: [SeedEnvPair], path: String) throws {
    let lines = pairs.map { "\($0.remindersListId): \($0.vikunjaProjectId)" }
    let contents = lines.joined(separator: "\n") + "\n"
    try contents.write(toFile: path, atomically: true, encoding: .utf8)
}

func setupSeedEnv(config: Config, store: EKEventStore, count: Int, statePath: String) throws -> SeedEnvState {
    let timestamp = Int(Date().timeIntervalSince1970)
    var pairs: [SeedEnvPair] = []
    for index in 1...count {
        let listTitle = "seed-test-\(timestamp)-list-\(index)"
        let projectTitle = "seed-test-\(timestamp)-project-\(index)"
        let calendar = try createRemindersList(store: store, title: listTitle)
        let project = try createVikunjaProject(config: config, title: projectTitle)
        pairs.append(SeedEnvPair(
            remindersListId: calendar.calendarIdentifier,
            remindersListTitle: listTitle,
            vikunjaProjectId: project.id,
            vikunjaProjectTitle: project.title
        ))
    }
    let listMapPath = statePath + ".list_map.txt"
    try writeListMap(pairs: pairs, path: listMapPath)
    let state = SeedEnvState(listMapPath: listMapPath, pairs: pairs)
    try writeSeedState(state, path: statePath)
    return state
}

func cleanupSeedEnv(config: Config, store: EKEventStore, state: SeedEnvState) {
    for pair in state.pairs {
        do {
            try deleteRemindersList(store: store, listId: pair.remindersListId)
            print("Deleted Reminders list: \(pair.remindersListTitle)")
        } catch {
            print("Warning: failed to delete Reminders list \(pair.remindersListTitle): \(error)")
        }
        do {
            try deleteVikunjaProject(config: config, projectId: pair.vikunjaProjectId)
            print("Deleted Vikunja project: \(pair.vikunjaProjectTitle)")
        } catch {
            print("Warning: failed to delete Vikunja project \(pair.vikunjaProjectTitle): \(error)")
        }
    }
}

func argumentValue(flag: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: flag), index + 1 < CommandLine.arguments.count else {
        return nil
    }
    return CommandLine.arguments[index + 1]
}

do {
    let config = try loadConfig()
    let reset = CommandLine.arguments.contains("--reset")
    let force = CommandLine.arguments.contains("--force")
    let mutateConflicts = CommandLine.arguments.contains("--mutate-conflicts")
    let setupEnv = CommandLine.arguments.contains("--setup-env")
    let cleanupEnv = CommandLine.arguments.contains("--cleanup-env")
    let count = Int(argumentValue(flag: "--count") ?? "2") ?? 2
    let statePath = argumentValue(flag: "--state-path") ?? "/tmp/seed_env_state.json"
    let seedTasks = try loadSeedTasks()

    let store = EKEventStore()
    try remindersAccess(store: store)

    if setupEnv {
        let state = try setupSeedEnv(config: config, store: store, count: count, statePath: statePath)
        print("Created seed env with \(state.pairs.count) list/project pairs.")
        print("State: \(statePath)")
        print("List map: \(state.listMapPath)")
        exit(0)
    }

    if cleanupEnv {
        let state = try loadSeedState(path: statePath)
        cleanupSeedEnv(config: config, store: store, state: state)
        exit(0)
    }

    let state = try loadSeedState(path: statePath)
    let remindersTasks = filterBySide(seedTasks, side: "reminders")
    let vikunjaTasks = filterBySide(seedTasks, side: "vikunja")

    for pair in state.pairs {
        guard let calendar = store.calendar(withIdentifier: pair.remindersListId) else {
            print("Warning: Reminders list not found: \(pair.remindersListTitle)")
            continue
        }

        if mutateConflicts {
            try mutateConflictTasks(config: config, store: store, calendar: calendar, projectId: pair.vikunjaProjectId)
            continue
        }

        if reset {
            try deleteRemindersSeedTasks(store: store, calendar: calendar)
            try deleteVikunjaSeedTasks(config: config, projectId: pair.vikunjaProjectId)
        } else if !force {
            let items = try fetchReminders(store: store, calendar: calendar)
            let remindersSeedCount = items.filter { ($0.title ?? "").hasPrefix("seed:") }.count

            let data = try vikunjaRequest(config: config, method: "GET", path: "/projects/\(pair.vikunjaProjectId)/tasks", body: nil)
            let tasks = try JSONDecoder().decode([VikunjaTask].self, from: data)
            let vikunjaSeedCount = tasks.filter { $0.title.hasPrefix("seed:") }.count

            if remindersSeedCount > 0 || vikunjaSeedCount > 0 {
                fputs("Seed data already exists (Reminders: \(remindersSeedCount), Vikunja: \(vikunjaSeedCount)) for \(pair.remindersListTitle). Re-run with --reset or --force.\n", stderr)
                exit(2)
            }
        }

        for task in remindersTasks {
            let id = try createReminder(store: store, calendar: calendar, task: task)
            print("Created Reminder: \(task.title) -> \(id)")
        }

        for task in vikunjaTasks {
            let id = try createVikunjaTask(config: config, projectId: pair.vikunjaProjectId, task: task)
            print("Created Vikunja task: \(task.title) -> \(id)")
        }
    }
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
