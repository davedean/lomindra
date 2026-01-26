import XCTest
@testable import VikunjaSyncLib

final class SyncLibTests: XCTestCase {

    // MARK: - Test Helpers

    func makeTask(
        source: String = "reminders",
        id: String = "test-id",
        title: String = "Test Task",
        isCompleted: Bool = false,
        due: String? = nil,
        start: String? = nil,
        updatedAt: String? = nil,
        alarms: [CommonAlarm] = [],
        recurrence: CommonRecurrence? = nil,
        dueIsDateOnly: Bool? = nil,
        startIsDateOnly: Bool? = nil,
        priority: Int? = nil,
        notes: String? = nil,
        isFlagged: Bool = false,
        completedAt: String? = nil
    ) -> CommonTask {
        return CommonTask(
            source: source,
            id: id,
            listId: "list",
            title: title,
            isCompleted: isCompleted,
            due: due,
            start: start,
            updatedAt: updatedAt,
            alarms: alarms,
            recurrence: recurrence,
            dueIsDateOnly: dueIsDateOnly,
            startIsDateOnly: startIsDateOnly,
            priority: priority,
            notes: notes,
            isFlagged: isFlagged,
            completedAt: completedAt
        )
    }

    func makeRecord(
        remindersId: String,
        vikunjaId: String,
        lastSeenReminders: String? = nil,
        lastSeenVikunja: String? = nil,
        dateOnlyDue: Bool = false,
        dateOnlyStart: Bool = false,
        inferredDue: Bool = false
    ) -> SyncRecord {
        return SyncRecord(
            remindersId: remindersId,
            vikunjaId: vikunjaId,
            listRemindersId: "list",
            projectId: 1,
            lastSeenReminders: lastSeenReminders,
            lastSeenVikunja: lastSeenVikunja,
            dateOnlyDue: dateOnlyDue,
            dateOnlyStart: dateOnlyStart,
            inferredDue: inferredDue
        )
    }

    // MARK: - parseKeyValueString Tests

    func testParseKeyValueStringColonSeparated() {
        let input = "key1: value1\nkey2: value2"
        let result = parseKeyValueString(input)
        XCTAssertEqual(result["key1"], "value1")
        XCTAssertEqual(result["key2"], "value2")
    }

    func testParseKeyValueStringSpaceSeparated() {
        let input = "key1 value1\nkey2 value2"
        let result = parseKeyValueString(input)
        XCTAssertEqual(result["key1"], "value1")
        XCTAssertEqual(result["key2"], "value2")
    }

    func testParseKeyValueStringIgnoresComments() {
        let input = "# comment\nkey1: value1\n\nkey2: value2"
        let result = parseKeyValueString(input)
        XCTAssertEqual(result.count, 2)
    }

    func testParseKeyValueStringHandlesValuesWithColons() {
        let input = "url: https://example.com:8080/path"
        let result = parseKeyValueString(input)
        XCTAssertEqual(result["url"], "https://example.com:8080/path")
    }

    // MARK: - normalizeDue Tests

    func testNormalizeDueReturnsNoneForNil() {
        XCTAssertEqual(normalizeDue(nil), "none")
    }

    func testNormalizeDueReturnsNoneForEmpty() {
        XCTAssertEqual(normalizeDue(""), "none")
    }

    func testNormalizeDueReturnsNoneForZeroDate() {
        XCTAssertEqual(normalizeDue("0001-01-01T00:00:00Z"), "none")
    }

    func testNormalizeDueReturnsValidDate() {
        XCTAssertEqual(normalizeDue("2026-01-20"), "2026-01-20")
    }

    // MARK: - normalizeDueForMatch Tests

    func testNormalizeDueForMatchReturnsNoneForNil() {
        XCTAssertEqual(normalizeDueForMatch(nil), "none")
    }

    func testNormalizeDueForMatchStripsTimeFromMidnight() {
        XCTAssertEqual(normalizeDueForMatch("2026-01-20T00:00:00Z"), "2026-01-20")
    }

    func testNormalizeDueForMatchPreservesDateOnly() {
        XCTAssertEqual(normalizeDueForMatch("2026-01-20"), "2026-01-20")
    }

    // MARK: - isDateOnlyString Tests

    func testIsDateOnlyStringReturnsTrueForDateOnly() {
        XCTAssertTrue(isDateOnlyString("2026-01-20"))
    }

    func testIsDateOnlyStringReturnsFalseForDatetime() {
        XCTAssertFalse(isDateOnlyString("2026-01-20T10:30:00Z"))
    }

    func testIsDateOnlyStringReturnsFalseForNil() {
        XCTAssertFalse(isDateOnlyString(nil))
    }

    // MARK: - normalizeRelativeTo Tests

    func testNormalizeRelativeToNormalizesDue() {
        XCTAssertEqual(normalizeRelativeTo("due"), "due_date")
        XCTAssertEqual(normalizeRelativeTo("due_date"), "due_date")
    }

    func testNormalizeRelativeToNormalizesStart() {
        XCTAssertEqual(normalizeRelativeTo("start"), "start_date")
    }

    func testNormalizeRelativeToNormalizesEnd() {
        XCTAssertEqual(normalizeRelativeTo("end"), "end_date")
    }

    func testNormalizeRelativeToReturnsNoneForUnknown() {
        XCTAssertEqual(normalizeRelativeTo(nil), "none")
        XCTAssertEqual(normalizeRelativeTo("unknown"), "none")
    }

    // MARK: - relativeToForVikunja Tests

    func testRelativeToForVikunjaReturnsDueDateForNil() {
        XCTAssertEqual(relativeToForVikunja(nil), "due_date")
    }

    func testRelativeToForVikunjaReturnsNormalizedValue() {
        XCTAssertEqual(relativeToForVikunja("start"), "start_date")
    }

    // MARK: - vikunjaDateString Tests

    func testVikunjaDateStringReturnsNilForNone() {
        XCTAssertNil(vikunjaDateString(from: nil))
        XCTAssertNil(vikunjaDateString(from: "0001-01-01T00:00:00Z"))
    }

    func testVikunjaDateStringAppendsTimeToDateOnly() {
        XCTAssertEqual(vikunjaDateString(from: "2026-01-20"), "2026-01-20T00:00:00Z")
    }

    func testVikunjaDateStringPreservesDatetime() {
        XCTAssertEqual(vikunjaDateString(from: "2026-01-20T10:30:00Z"), "2026-01-20T10:30:00Z")
    }

    // MARK: - recurrenceSignature Tests

    func testRecurrenceSignatureReturnsNoneForNil() {
        XCTAssertEqual(recurrenceSignature(nil), "none")
    }

    func testRecurrenceSignatureReturnsFrequencyInterval() {
        let daily = CommonRecurrence(frequency: "daily", interval: 1)
        XCTAssertEqual(recurrenceSignature(daily), "daily|1")
    }

    // MARK: - matchKey Tests

    func testMatchKeyCreatesConsistentKey() {
        let task = makeTask(title: "Test Task", isCompleted: false, due: "2026-01-20")
        let key = matchKey(task)
        XCTAssertEqual(key, "test task|0|2026-01-20")
    }

    func testMatchKeyNormalizesCase() {
        let task1 = makeTask(title: "Test Task")
        let task2 = makeTask(title: "TEST TASK")
        XCTAssertEqual(matchKey(task1), matchKey(task2))
    }

    func testMatchKeyIncludesCompletionStatus() {
        let incomplete = makeTask(title: "Task", isCompleted: false)
        let complete = makeTask(title: "Task", isCompleted: true)
        XCTAssertNotEqual(matchKey(incomplete), matchKey(complete))
    }

    // MARK: - tasksDiffer Tests

    func testTasksDifferReturnsFalseForIdentical() {
        let task1 = makeTask(title: "Test", isCompleted: false, due: "2026-01-20")
        let task2 = makeTask(title: "Test", isCompleted: false, due: "2026-01-20")
        XCTAssertFalse(tasksDiffer(task1, task2))
    }

    func testTasksDifferReturnsTrueForDifferentTitles() {
        let task1 = makeTask(title: "Test 1")
        let task2 = makeTask(title: "Test 2")
        XCTAssertTrue(tasksDiffer(task1, task2))
    }

    func testTasksDifferReturnsTrueForDifferentCompletion() {
        let task1 = makeTask(isCompleted: false)
        let task2 = makeTask(isCompleted: true)
        XCTAssertTrue(tasksDiffer(task1, task2))
    }

    func testTasksDifferReturnsTrueForDifferentDue() {
        let task1 = makeTask(due: "2026-01-20")
        let task2 = makeTask(due: "2026-01-21")
        XCTAssertTrue(tasksDiffer(task1, task2))
    }

    func testTasksDifferIgnoresDueWhenFlagged() {
        let task1 = makeTask(title: "Test", due: "2026-01-20")
        let task2 = makeTask(title: "Test", due: "2026-01-21")
        XCTAssertFalse(tasksDiffer(task1, task2, ignoreDue: true))
    }

    func testTasksDifferReturnsTrueForDifferentRecurrence() {
        let task1 = makeTask(recurrence: CommonRecurrence(frequency: "daily", interval: 1))
        let task2 = makeTask(recurrence: CommonRecurrence(frequency: "weekly", interval: 1))
        XCTAssertTrue(tasksDiffer(task1, task2))
    }

    // MARK: - diffTasks Tests

    func testDiffTasksCreatesInVikunjaForNewReminders() {
        let reminders = [makeTask(source: "reminders", id: "rem-1", title: "New Task")]
        let vikunja: [CommonTask] = []
        let records: [String: SyncRecord] = [:]

        let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

        XCTAssertEqual(plan.toCreateInVikunja.count, 1)
        XCTAssertEqual(plan.toCreateInVikunja.first?.title, "New Task")
    }

    func testDiffTasksCreatesInRemindersForNewVikunja() {
        let reminders: [CommonTask] = []
        let vikunja = [makeTask(source: "vikunja", id: "vik-1", title: "New Task")]
        let records: [String: SyncRecord] = [:]

        let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

        XCTAssertEqual(plan.toCreateInReminders.count, 1)
        XCTAssertEqual(plan.toCreateInReminders.first?.title, "New Task")
    }

    func testDiffTasksAutoMatchesWithSameSignature() {
        let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Task", isCompleted: false, due: "2026-01-20", updatedAt: "2026-01-19T10:00:00Z")]
        let vikunja = [makeTask(source: "vikunja", id: "1", title: "Task", isCompleted: false, due: "2026-01-20", updatedAt: "2026-01-19T09:00:00Z")]
        let records: [String: SyncRecord] = [:]

        let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

        XCTAssertEqual(plan.autoMatched.count, 1)
        XCTAssertEqual(plan.toCreateInVikunja.count, 0)
        XCTAssertEqual(plan.toCreateInReminders.count, 0)
    }

    func testDiffTasksReportsAmbiguousMatches() {
        let reminders = [
            makeTask(source: "reminders", id: "rem-1", title: "Task", due: "2026-01-20"),
            makeTask(source: "reminders", id: "rem-2", title: "Task", due: "2026-01-20")
        ]
        let vikunja = [
            makeTask(source: "vikunja", id: "1", title: "Task", due: "2026-01-20"),
            makeTask(source: "vikunja", id: "2", title: "Task", due: "2026-01-20")
        ]
        let records: [String: SyncRecord] = [:]

        let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

        XCTAssertEqual(plan.ambiguousMatches.count, 1)
        XCTAssertEqual(plan.autoMatched.count, 0)
    }

    func testDiffTasksUpdatesVikunjaWhenRemindersNewer() {
        let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Updated Title", updatedAt: "2026-01-20T10:00:00Z")]
        let vikunja = [makeTask(source: "vikunja", id: "1", title: "Old Title", updatedAt: "2026-01-19T10:00:00Z")]
        let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1")]

        let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

        XCTAssertEqual(plan.toUpdateVikunja.count, 1)
        XCTAssertEqual(plan.toUpdateReminders.count, 0)
    }

    func testDiffTasksUpdatesRemindersWhenVikunjaNewer() {
        let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Old Title", updatedAt: "2026-01-19T10:00:00Z")]
        let vikunja = [makeTask(source: "vikunja", id: "1", title: "Updated Title", updatedAt: "2026-01-20T10:00:00Z")]
        let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1")]

        let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

        XCTAssertEqual(plan.toUpdateReminders.count, 1)
        XCTAssertEqual(plan.toUpdateVikunja.count, 0)
    }

    func testDiffTasksDoesNotUpdateIdenticalTasks() {
        let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Same Title", updatedAt: "2026-01-20T10:00:00Z")]
        let vikunja = [makeTask(source: "vikunja", id: "1", title: "Same Title", updatedAt: "2026-01-19T10:00:00Z")]
        let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1")]

        let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

        XCTAssertEqual(plan.toUpdateVikunja.count, 0)
        XCTAssertEqual(plan.toUpdateReminders.count, 0)
    }

    func testDiffTasksDeletesFromVikunjaWhenMissingInReminders() {
        let reminders: [CommonTask] = []
        let vikunja = [makeTask(source: "vikunja", id: "1", title: "Task", isCompleted: false)]
        let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1")]

        let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

        XCTAssertEqual(plan.toDeleteInVikunja.count, 1)
        XCTAssertEqual(plan.toDeleteInVikunja.first, "1")
    }

    func testDiffTasksDeletesFromRemindersWhenMissingInVikunja() {
        let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Task", isCompleted: false)]
        let vikunja: [CommonTask] = []
        let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1")]

        let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

        XCTAssertEqual(plan.toDeleteInReminders.count, 1)
        XCTAssertEqual(plan.toDeleteInReminders.first, "rem-1")
    }

    func testDiffTasksIgnoresMissingCompletedTasks() {
        let reminders: [CommonTask] = []
        let vikunja = [makeTask(source: "vikunja", id: "1", title: "Task", isCompleted: true)]
        let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1")]

        let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

        XCTAssertEqual(plan.toDeleteInVikunja.count, 0)
        XCTAssertEqual(plan.ignoredMissingCompleted.count, 1)
    }

    func testDiffTasksDetectsConflicts() {
        let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Rem Update", updatedAt: "2026-01-20T12:00:00Z")]
        let vikunja = [makeTask(source: "vikunja", id: "1", title: "Vik Update", updatedAt: "2026-01-20T11:00:00Z")]
        let records = ["rem-1": makeRecord(
            remindersId: "rem-1",
            vikunjaId: "1",
            lastSeenReminders: "2026-01-19T10:00:00Z",
            lastSeenVikunja: "2026-01-19T10:00:00Z"
        )]

        let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

        XCTAssertEqual(plan.conflicts.count, 1)
        XCTAssertEqual(plan.toUpdateVikunja.count, 0)
        XCTAssertEqual(plan.toUpdateReminders.count, 0)
    }

    func testConflictFieldDiffsCaptureChangedFields() {
        let reminders = makeTask(
            source: "reminders",
            id: "rem-1",
            title: "Rem Title",
            isCompleted: false,
            due: "2026-01-20",
            updatedAt: "2026-01-20T12:00:00Z",
            alarms: [CommonAlarm(type: "absolute", absolute: "2026-01-20T08:00:00Z", relativeSeconds: nil, relativeTo: nil)],
            recurrence: CommonRecurrence(frequency: "daily", interval: 1),
            dueIsDateOnly: true
        )
        let vikunja = makeTask(
            source: "vikunja",
            id: "1",
            title: "Vik Title",
            isCompleted: true,
            due: "2026-01-21T00:00:00Z",
            updatedAt: "2026-01-20T11:00:00Z",
            alarms: [],
            recurrence: nil,
            dueIsDateOnly: false
        )

        let diffs = conflictFieldDiffs(reminders: reminders, vikunja: vikunja)
        let fields = Set(diffs.map { $0.field })

        XCTAssertTrue(fields.contains("title"))
        XCTAssertTrue(fields.contains("completed"))
        XCTAssertTrue(fields.contains("due"))
        XCTAssertTrue(fields.contains("dueDateOnly"))
        XCTAssertTrue(fields.contains("alarms"))
        XCTAssertTrue(fields.contains("recurrence"))
        XCTAssertTrue(fields.contains("updatedAt"))
        XCTAssertFalse(fields.contains("start"))
    }

    func testDiffTasksIgnoresDueWhenInferred() {
        let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Task", due: "2026-01-20", updatedAt: "2026-01-20T10:00:00Z")]
        let vikunja = [makeTask(source: "vikunja", id: "1", title: "Task", due: nil, updatedAt: "2026-01-19T10:00:00Z")]
        let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1", inferredDue: true)]

        let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

        XCTAssertEqual(plan.toUpdateVikunja.count, 0)
        XCTAssertEqual(plan.toUpdateReminders.count, 0)
    }

    // MARK: - retry/redaction Tests

    func testRedactSensitiveRemovesTokenAndBearer() {
        let token = "abc123"
        let input = "Bearer abc123 and token abc123 in response"
        let output = redactSensitive(input, token: token)
        XCTAssertFalse(output.contains(token))
        XCTAssertTrue(output.contains("Bearer [redacted]"))
    }

    func testRedactSensitiveRedactsJSONTokenFields() {
        let input = "{\"token\":\"secret\",\"jwt\":\"secret2\"}"
        let output = redactSensitive(input, token: "")
        XCTAssertEqual(output, "{\"token\":\"[redacted]\",\"jwt\":\"[redacted]\"}")
    }

    func testShouldRetryVikunjaRequestForHTTP500() {
        let error = NSError(domain: "vikunja", code: 500, userInfo: nil)
        XCTAssertTrue(shouldRetryVikunjaRequest(error: error))
    }

    func testShouldRetryVikunjaRequestForURLErrorTimedOut() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        XCTAssertTrue(shouldRetryVikunjaRequest(error: error))
    }

    func testShouldRetryVikunjaRequestFalseForAuthError() {
        let error = NSError(domain: "vikunja", code: 401, userInfo: nil)
        XCTAssertFalse(shouldRetryVikunjaRequest(error: error))
    }

    // MARK: - parseVikunjaRecurrence Tests

    func testParseVikunjaRecurrenceReturnsNilWhenNoRepeatAfter() {
        XCTAssertNil(parseVikunjaRecurrence(repeatAfter: nil, repeatMode: nil))
        XCTAssertNil(parseVikunjaRecurrence(repeatAfter: nil, repeatMode: 0))
    }

    func testParseVikunjaRecurrenceDailyWithRepeatModeZero() {
        let result = parseVikunjaRecurrence(repeatAfter: 86400, repeatMode: 0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.frequency, "daily")
        XCTAssertEqual(result?.interval, 1)
    }

    func testParseVikunjaRecurrenceDailyWithRepeatModeNil() {
        // BUG TEST: This should work but fails with current code
        // Vikunja often returns repeat_mode as null for time-based recurrence
        let result = parseVikunjaRecurrence(repeatAfter: 86400, repeatMode: nil)
        XCTAssertNotNil(result, "Daily recurrence should work when repeat_mode is nil")
        XCTAssertEqual(result?.frequency, "daily")
        XCTAssertEqual(result?.interval, 1)
    }

    func testParseVikunjaRecurrenceWeeklyWithRepeatModeNil() {
        // BUG TEST: This should work but fails with current code
        let result = parseVikunjaRecurrence(repeatAfter: 604800, repeatMode: nil)
        XCTAssertNotNil(result, "Weekly recurrence should work when repeat_mode is nil")
        XCTAssertEqual(result?.frequency, "weekly")
        XCTAssertEqual(result?.interval, 1)
    }

    func testParseVikunjaRecurrenceWeeklyWithRepeatModeZero() {
        let result = parseVikunjaRecurrence(repeatAfter: 604800, repeatMode: 0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.frequency, "weekly")
        XCTAssertEqual(result?.interval, 1)
    }

    func testParseVikunjaRecurrenceMonthly() {
        let result = parseVikunjaRecurrence(repeatAfter: 0, repeatMode: 1)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.frequency, "monthly")
        XCTAssertEqual(result?.interval, 1)
    }

    func testParseVikunjaRecurrenceMultiDayInterval() {
        // Every 3 days
        let result = parseVikunjaRecurrence(repeatAfter: 259200, repeatMode: 0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.frequency, "daily")
        XCTAssertEqual(result?.interval, 3)
    }

    func testParseVikunjaRecurrenceBiweekly() {
        // Every 2 weeks
        let result = parseVikunjaRecurrence(repeatAfter: 1209600, repeatMode: nil)
        XCTAssertNotNil(result, "Bi-weekly should work when repeat_mode is nil")
        XCTAssertEqual(result?.frequency, "weekly")
        XCTAssertEqual(result?.interval, 2)
    }

    // MARK: - Priority Mapping Tests

    func testRemindersPriorityToVikunja() {
        XCTAssertEqual(remindersPriorityToVikunja(1), 3)   // high
        XCTAssertEqual(remindersPriorityToVikunja(5), 2)   // medium
        XCTAssertEqual(remindersPriorityToVikunja(9), 1)   // low
        XCTAssertEqual(remindersPriorityToVikunja(0), 0)   // none
        XCTAssertEqual(remindersPriorityToVikunja(nil), 0) // nil
    }

    func testVikunjaPriorityToReminders() {
        XCTAssertEqual(vikunjaPriorityToReminders(0), 0)   // none
        XCTAssertEqual(vikunjaPriorityToReminders(1), 9)   // low
        XCTAssertEqual(vikunjaPriorityToReminders(2), 5)   // medium
        XCTAssertEqual(vikunjaPriorityToReminders(3), 1)   // high
        XCTAssertEqual(vikunjaPriorityToReminders(5), 1)   // high (clamped)
        XCTAssertEqual(vikunjaPriorityToReminders(nil), 0) // nil
    }

    // MARK: - New Field Diff Detection Tests

    func testTasksDifferDetectsPriorityChange() {
        let task1 = makeTask(priority: 1)
        let task2 = makeTask(priority: 5)
        XCTAssertTrue(tasksDiffer(task1, task2))
    }

    func testTasksDifferDetectsNotesChange() {
        let task1 = makeTask(notes: "Original notes")
        let task2 = makeTask(notes: "Updated notes")
        XCTAssertTrue(tasksDiffer(task1, task2))
    }

    func testTasksDifferDetectsFlagChange() {
        let task1 = makeTask(isFlagged: false)
        let task2 = makeTask(isFlagged: true)
        XCTAssertTrue(tasksDiffer(task1, task2))
    }

    func testTasksDifferReturnsFalseWhenAllFieldsMatch() {
        let task1 = makeTask(priority: 1, notes: "Test", isFlagged: true)
        let task2 = makeTask(priority: 1, notes: "Test", isFlagged: true)
        XCTAssertFalse(tasksDiffer(task1, task2))
    }

    // MARK: - Hashtag Extraction Tests

    func testExtractTagsFromTextBasic() {
        let text = "Buy groceries #shopping #errands"
        let tags = extractTagsFromText(text)
        XCTAssertEqual(tags, ["shopping", "errands"])
    }

    func testExtractTagsFromTextWithHyphensAndUnderscores() {
        let text = "Work task #work-project #next_action"
        let tags = extractTagsFromText(text)
        XCTAssertEqual(tags, ["work-project", "next_action"])
    }

    func testExtractTagsFromTextIgnoresDuplicates() {
        let text = "#urgent Do this #urgent thing #URGENT"
        let tags = extractTagsFromText(text)
        XCTAssertEqual(tags, ["urgent"]) // Case-insensitive dedup, keeps first
    }

    func testExtractTagsFromTextReturnsEmptyForNil() {
        let tags = extractTagsFromText(nil)
        XCTAssertEqual(tags, [])
    }

    func testExtractTagsFromTextReturnsEmptyForNoTags() {
        let text = "Just a plain task"
        let tags = extractTagsFromText(text)
        XCTAssertEqual(tags, [])
    }

    func testExtractTagsFromTextHandlesTagsAtStartMiddleEnd() {
        let text = "#start middle #middle end #end"
        let tags = extractTagsFromText(text)
        XCTAssertEqual(tags, ["start", "middle", "end"])
    }

    func testExtractTagsFromTextIgnoresInvalidPatterns() {
        let text = "Price is $50 and email is test@example.com #valid"
        let tags = extractTagsFromText(text)
        XCTAssertEqual(tags, ["valid"])
    }

    // MARK: - Strip Tags Tests

    func testStripTagsFromTextBasic() {
        let text = "Buy groceries #shopping #errands"
        let stripped = stripTagsFromText(text)
        XCTAssertEqual(stripped, "Buy groceries")
    }

    func testStripTagsFromTextNormalizesWhitespace() {
        let text = "Task   #tag1   #tag2   description"
        let stripped = stripTagsFromText(text)
        XCTAssertEqual(stripped, "Task description")
    }

    func testStripTagsFromTextReturnsEmptyForNil() {
        let stripped = stripTagsFromText(nil)
        XCTAssertEqual(stripped, "")
    }

    func testStripTagsFromTextHandlesOnlyTags() {
        let text = "#tag1 #tag2 #tag3"
        let stripped = stripTagsFromText(text)
        XCTAssertEqual(stripped, "")
    }

    // MARK: - Embed Tags Tests

    func testEmbedTagsInTextAppendsToExisting() {
        let text = "My task"
        let result = embedTagsInText(text, tags: ["urgent", "work"])
        XCTAssertEqual(result, "My task\n\n#urgent #work")
    }

    func testEmbedTagsInTextHandlesNilText() {
        let result = embedTagsInText(nil, tags: ["urgent"])
        XCTAssertEqual(result, "#urgent")
    }

    func testEmbedTagsInTextHandlesEmptyTags() {
        let result = embedTagsInText("My task", tags: [])
        XCTAssertEqual(result, "My task")
    }

    func testEmbedTagsInTextFiltersEmptyTagStrings() {
        let result = embedTagsInText("Task", tags: ["valid", "", "also-valid"])
        XCTAssertEqual(result, "Task\n\n#valid #also-valid")
    }

    // MARK: - Tag Placement Tests

    func testEmbedTagsWithPlacementPutsInTitleWhenNoNotes() {
        let result = embedTagsWithPlacement(title: "My task", notes: nil, tags: ["urgent"])
        XCTAssertEqual(result.title, "My task #urgent")
        XCTAssertNil(result.notes)
    }

    func testEmbedTagsWithPlacementPutsInNotesWhenNotesExist() {
        let result = embedTagsWithPlacement(title: "My task", notes: "Some notes", tags: ["urgent"])
        XCTAssertEqual(result.title, "My task")
        XCTAssertEqual(result.notes, "Some notes\n\n#urgent")
    }

    func testEmbedTagsWithPlacementTreatsEmptyNotesAsNil() {
        let result = embedTagsWithPlacement(title: "My task", notes: "   ", tags: ["urgent"])
        XCTAssertEqual(result.title, "My task #urgent")
        XCTAssertNil(result.notes)
    }

    func testEmbedTagsWithPlacementNoChangeWhenNoTags() {
        let result = embedTagsWithPlacement(title: "My task", notes: "Notes", tags: [])
        XCTAssertEqual(result.title, "My task")
        XCTAssertEqual(result.notes, "Notes")
    }

    // MARK: - Extract from Task Tests

    func testExtractTagsFromTaskCombinesTitleAndNotes() {
        let tags = extractTagsFromTask(title: "Task #work", notes: "Details #urgent")
        XCTAssertEqual(tags, ["work", "urgent"])
    }

    func testExtractTagsFromTaskDeduplicatesAcrossFields() {
        let tags = extractTagsFromTask(title: "Task #urgent", notes: "Also #urgent")
        XCTAssertEqual(tags, ["urgent"])
    }

    func testExtractTagsFromTaskHandlesNilNotes() {
        let tags = extractTagsFromTask(title: "Task #work #home", notes: nil)
        XCTAssertEqual(tags, ["work", "home"])
    }

    // MARK: - Strip from Task Tests

    func testStripTagsFromTaskStripsFromBoth() {
        let result = stripTagsFromTask(title: "Task #work", notes: "Notes #urgent")
        XCTAssertEqual(result.title, "Task")
        XCTAssertEqual(result.notes, "Notes")
    }

    func testStripTagsFromTaskPreservesTitleIfOnlyTags() {
        let result = stripTagsFromTask(title: "#work", notes: nil)
        XCTAssertEqual(result.title, "#work") // Keeps original if stripped would be empty
        XCTAssertNil(result.notes)
    }

    func testStripTagsFromTaskHandlesNilNotes() {
        let result = stripTagsFromTask(title: "Task #tag", notes: nil)
        XCTAssertEqual(result.title, "Task")
        XCTAssertNil(result.notes)
    }

    // MARK: - Round-trip Tests

    func testHashtagRoundTripInTitle() {
        let original = "Buy groceries"
        let tags = ["shopping", "errands"]

        // Embed tags in title (no notes)
        let embedded = embedTagsWithPlacement(title: original, notes: nil, tags: tags)
        XCTAssertEqual(embedded.title, "Buy groceries #shopping #errands")

        // Extract and verify
        let extractedTags = extractTagsFromTask(title: embedded.title, notes: embedded.notes)
        XCTAssertEqual(extractedTags, tags)

        // Strip and verify original is recovered
        let stripped = stripTagsFromTask(title: embedded.title, notes: embedded.notes)
        XCTAssertEqual(stripped.title, original)
    }

    func testHashtagRoundTripInNotes() {
        let originalTitle = "Work meeting"
        let originalNotes = "Discuss project status"
        let tags = ["work", "meeting"]

        // Embed tags in notes
        let embedded = embedTagsWithPlacement(title: originalTitle, notes: originalNotes, tags: tags)
        XCTAssertEqual(embedded.title, originalTitle)
        XCTAssertEqual(embedded.notes, "Discuss project status\n\n#work #meeting")

        // Extract and verify
        let extractedTags = extractTagsFromTask(title: embedded.title, notes: embedded.notes)
        XCTAssertEqual(extractedTags, tags)

        // Strip and verify originals are recovered
        let stripped = stripTagsFromTask(title: embedded.title, notes: embedded.notes)
        XCTAssertEqual(stripped.title, originalTitle)
        XCTAssertEqual(stripped.notes, originalNotes)
    }
}
