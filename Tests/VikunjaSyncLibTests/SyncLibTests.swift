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
        startIsDateOnly: Bool? = nil
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
            startIsDateOnly: startIsDateOnly
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
}
