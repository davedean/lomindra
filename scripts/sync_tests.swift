import Foundation

// Compile with: swiftc -o /tmp/sync_tests scripts/sync_lib.swift scripts/sync_tests.swift
// Run with: /tmp/sync_tests

// MARK: - Test Harness

var testsPassed = 0
var testsFailed = 0
var currentTestName = ""

func describe(_ name: String, _ block: () -> Void) {
    print("\n\(name)")
    block()
}

func it(_ name: String, _ block: () -> Void) {
    currentTestName = name
    block()
}

func expect<T: Equatable>(_ actual: T, toEqual expected: T, file: String = #file, line: Int = #line) {
    if actual == expected {
        testsPassed += 1
        print("  ✓ \(currentTestName)")
    } else {
        testsFailed += 1
        print("  ✗ \(currentTestName)")
        print("    Expected: \(expected)")
        print("    Actual:   \(actual)")
    }
}

func expectTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    if condition {
        testsPassed += 1
        print("  ✓ \(currentTestName)")
    } else {
        testsFailed += 1
        print("  ✗ \(currentTestName)")
        if !message.isEmpty {
            print("    \(message)")
        }
    }
}

func expectFalse(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    expectTrue(!condition, message, file: file, line: line)
}

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

// MARK: - Test Definitions

func testParseKeyValueString() {
    describe("parseKeyValueString") {
        it("parses colon-separated key-value pairs") {
            let input = "key1: value1\nkey2: value2"
            let result = parseKeyValueString(input)
            expect(result["key1"], toEqual: "value1")
        }

        it("parses space-separated key-value pairs") {
            let input = "key1 value1\nkey2 value2"
            let result = parseKeyValueString(input)
            expect(result["key1"], toEqual: "value1")
        }

        it("ignores comments and empty lines") {
            let input = "# comment\nkey1: value1\n\nkey2: value2"
            let result = parseKeyValueString(input)
            expect(result.count, toEqual: 2)
        }

        it("handles values with colons") {
            let input = "url: https://example.com:8080/path"
            let result = parseKeyValueString(input)
            expect(result["url"], toEqual: "https://example.com:8080/path")
        }
    }
}

func testNormalizeDue() {
    describe("normalizeDue") {
        it("returns 'none' for nil") {
            expect(normalizeDue(nil), toEqual: "none")
        }

        it("returns 'none' for empty string") {
            expect(normalizeDue(""), toEqual: "none")
        }

        it("returns 'none' for zero date") {
            expect(normalizeDue("0001-01-01T00:00:00Z"), toEqual: "none")
        }

        it("returns the date string for valid dates") {
            expect(normalizeDue("2026-01-20"), toEqual: "2026-01-20")
        }
    }
}

func testNormalizeDueForMatch() {
    describe("normalizeDueForMatch") {
        it("returns 'none' for nil") {
            expect(normalizeDueForMatch(nil), toEqual: "none")
        }

        it("strips time from midnight UTC dates") {
            expect(normalizeDueForMatch("2026-01-20T00:00:00Z"), toEqual: "2026-01-20")
        }

        it("preserves date-only strings") {
            expect(normalizeDueForMatch("2026-01-20"), toEqual: "2026-01-20")
        }
    }
}

func testIsDateOnlyString() {
    describe("isDateOnlyString") {
        it("returns true for date-only strings") {
            expectTrue(isDateOnlyString("2026-01-20"))
        }

        it("returns false for datetime strings") {
            expectFalse(isDateOnlyString("2026-01-20T10:30:00Z"))
        }

        it("returns false for nil") {
            expectFalse(isDateOnlyString(nil))
        }
    }
}

func testNormalizeRelativeTo() {
    describe("normalizeRelativeTo") {
        it("normalizes 'due' to 'due_date'") {
            expect(normalizeRelativeTo("due"), toEqual: "due_date")
        }

        it("normalizes 'start' to 'start_date'") {
            expect(normalizeRelativeTo("start"), toEqual: "start_date")
        }

        it("normalizes 'end' to 'end_date'") {
            expect(normalizeRelativeTo("end"), toEqual: "end_date")
        }

        it("returns 'none' for unknown values") {
            expect(normalizeRelativeTo(nil), toEqual: "none")
        }
    }
}

func testRelativeToForVikunja() {
    describe("relativeToForVikunja") {
        it("returns 'due_date' for nil or 'none'") {
            expect(relativeToForVikunja(nil), toEqual: "due_date")
        }

        it("returns normalized value for valid inputs") {
            expect(relativeToForVikunja("start"), toEqual: "start_date")
        }
    }
}

func testVikunjaDateString() {
    describe("vikunjaDateString") {
        it("returns nil for 'none' dates") {
            expect(vikunjaDateString(from: nil) == nil, toEqual: true)
        }

        it("appends T00:00:00Z to date-only strings") {
            expect(vikunjaDateString(from: "2026-01-20"), toEqual: "2026-01-20T00:00:00Z")
        }

        it("preserves datetime strings") {
            expect(vikunjaDateString(from: "2026-01-20T10:30:00Z"), toEqual: "2026-01-20T10:30:00Z")
        }
    }
}

func testRecurrenceSignature() {
    describe("recurrenceSignature") {
        it("returns 'none' for nil") {
            expect(recurrenceSignature(nil), toEqual: "none")
        }

        it("returns frequency|interval format") {
            let daily = CommonRecurrence(frequency: "daily", interval: 1)
            expect(recurrenceSignature(daily), toEqual: "daily|1")
        }
    }
}

func testMatchKey() {
    describe("matchKey") {
        it("creates consistent key from task properties") {
            let task = makeTask(title: "Test Task", isCompleted: false, due: "2026-01-20")
            let key = matchKey(task)
            expect(key, toEqual: "test task|0|2026-01-20")
        }

        it("normalizes title case") {
            let task1 = makeTask(title: "Test Task")
            let task2 = makeTask(title: "TEST TASK")
            expect(matchKey(task1), toEqual: matchKey(task2))
        }

        it("includes completion status") {
            let incomplete = makeTask(title: "Task", isCompleted: false)
            let complete = makeTask(title: "Task", isCompleted: true)
            expectFalse(matchKey(incomplete) == matchKey(complete))
        }
    }
}

func testTasksDiffer() {
    describe("tasksDiffer") {
        it("returns false for identical tasks") {
            let task1 = makeTask(title: "Test", isCompleted: false, due: "2026-01-20")
            let task2 = makeTask(title: "Test", isCompleted: false, due: "2026-01-20")
            expectFalse(tasksDiffer(task1, task2))
        }

        it("returns true for different titles") {
            let task1 = makeTask(title: "Test 1")
            let task2 = makeTask(title: "Test 2")
            expectTrue(tasksDiffer(task1, task2))
        }

        it("returns true for different completion status") {
            let task1 = makeTask(isCompleted: false)
            let task2 = makeTask(isCompleted: true)
            expectTrue(tasksDiffer(task1, task2))
        }

        it("returns true for different due dates") {
            let task1 = makeTask(due: "2026-01-20")
            let task2 = makeTask(due: "2026-01-21")
            expectTrue(tasksDiffer(task1, task2))
        }

        it("ignores due date when ignoreDue is true") {
            let task1 = makeTask(title: "Test", due: "2026-01-20")
            let task2 = makeTask(title: "Test", due: "2026-01-21")
            expectFalse(tasksDiffer(task1, task2, ignoreDue: true))
        }

        it("returns true for different recurrence") {
            let task1 = makeTask(recurrence: CommonRecurrence(frequency: "daily", interval: 1))
            let task2 = makeTask(recurrence: CommonRecurrence(frequency: "weekly", interval: 1))
            expectTrue(tasksDiffer(task1, task2))
        }
    }
}

func testDiffTasksCreate() {
    describe("diffTasks - create operations") {
        it("creates in Vikunja for tasks only in Reminders") {
            let reminders = [makeTask(source: "reminders", id: "rem-1", title: "New Task")]
            let vikunja: [CommonTask] = []
            let records: [String: SyncRecord] = [:]

            let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

            expect(plan.toCreateInVikunja.count, toEqual: 1)
        }

        it("creates in Reminders for tasks only in Vikunja") {
            let reminders: [CommonTask] = []
            let vikunja = [makeTask(source: "vikunja", id: "vik-1", title: "New Task")]
            let records: [String: SyncRecord] = [:]

            let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

            expect(plan.toCreateInReminders.count, toEqual: 1)
        }
    }
}

func testDiffTasksAutoMatch() {
    describe("diffTasks - auto-matching") {
        it("auto-matches unmapped tasks with same signature") {
            let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Task", isCompleted: false, due: "2026-01-20", updatedAt: "2026-01-19T10:00:00Z")]
            let vikunja = [makeTask(source: "vikunja", id: "1", title: "Task", isCompleted: false, due: "2026-01-20", updatedAt: "2026-01-19T09:00:00Z")]
            let records: [String: SyncRecord] = [:]

            let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

            expect(plan.autoMatched.count, toEqual: 1)
        }

        it("reports ambiguous matches when multiple tasks have same signature") {
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

            expect(plan.ambiguousMatches.count, toEqual: 1)
        }
    }
}

func testDiffTasksUpdate() {
    describe("diffTasks - update operations") {
        it("updates Vikunja when Reminders is newer") {
            let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Updated Title", updatedAt: "2026-01-20T10:00:00Z")]
            let vikunja = [makeTask(source: "vikunja", id: "1", title: "Old Title", updatedAt: "2026-01-19T10:00:00Z")]
            let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1")]

            let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

            expect(plan.toUpdateVikunja.count, toEqual: 1)
        }

        it("updates Reminders when Vikunja is newer") {
            let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Old Title", updatedAt: "2026-01-19T10:00:00Z")]
            let vikunja = [makeTask(source: "vikunja", id: "1", title: "Updated Title", updatedAt: "2026-01-20T10:00:00Z")]
            let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1")]

            let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

            expect(plan.toUpdateReminders.count, toEqual: 1)
        }

        it("does not update when tasks are identical") {
            let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Same Title", updatedAt: "2026-01-20T10:00:00Z")]
            let vikunja = [makeTask(source: "vikunja", id: "1", title: "Same Title", updatedAt: "2026-01-19T10:00:00Z")]
            let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1")]

            let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

            expect(plan.toUpdateVikunja.count, toEqual: 0)
        }
    }
}

func testDiffTasksDelete() {
    describe("diffTasks - delete operations") {
        it("deletes from Vikunja when mapped task missing from Reminders") {
            let reminders: [CommonTask] = []
            let vikunja = [makeTask(source: "vikunja", id: "1", title: "Task", isCompleted: false)]
            let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1")]

            let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

            expect(plan.toDeleteInVikunja.count, toEqual: 1)
        }

        it("deletes from Reminders when mapped task missing from Vikunja") {
            let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Task", isCompleted: false)]
            let vikunja: [CommonTask] = []
            let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1")]

            let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

            expect(plan.toDeleteInReminders.count, toEqual: 1)
        }

        it("ignores missing completed tasks instead of deleting") {
            let reminders: [CommonTask] = []
            let vikunja = [makeTask(source: "vikunja", id: "1", title: "Task", isCompleted: true)]
            let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1")]

            let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

            expect(plan.toDeleteInVikunja.count, toEqual: 0)
        }
    }
}

func testDiffTasksConflict() {
    describe("diffTasks - conflict detection") {
        it("detects conflicts when both sides changed since last sync") {
            let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Rem Update", updatedAt: "2026-01-20T12:00:00Z")]
            let vikunja = [makeTask(source: "vikunja", id: "1", title: "Vik Update", updatedAt: "2026-01-20T11:00:00Z")]
            let records = ["rem-1": makeRecord(
                remindersId: "rem-1",
                vikunjaId: "1",
                lastSeenReminders: "2026-01-19T10:00:00Z",
                lastSeenVikunja: "2026-01-19T10:00:00Z"
            )]

            let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

            expect(plan.conflicts.count, toEqual: 1)
        }
    }
}

func testConflictFieldDiffs() {
    describe("conflictFieldDiffs") {
        it("captures fields that differ between reminders and vikunja") {
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

            expectTrue(fields.contains("title"))
            expectTrue(fields.contains("completed"))
            expectTrue(fields.contains("due"))
            expectTrue(fields.contains("dueDateOnly"))
            expectTrue(fields.contains("alarms"))
            expectTrue(fields.contains("recurrence"))
            expectTrue(fields.contains("updatedAt"))
            expectFalse(fields.contains("start"))
        }
    }
}

func testDiffTasksInferredDue() {
    describe("diffTasks - inferred due handling") {
        it("ignores due date differences when inferredDue is set") {
            let reminders = [makeTask(source: "reminders", id: "rem-1", title: "Task", due: "2026-01-20", updatedAt: "2026-01-20T10:00:00Z")]
            let vikunja = [makeTask(source: "vikunja", id: "1", title: "Task", due: nil, updatedAt: "2026-01-19T10:00:00Z")]
            let records = ["rem-1": makeRecord(remindersId: "rem-1", vikunjaId: "1", inferredDue: true)]

            let plan = diffTasks(reminders: reminders, vikunja: vikunja, records: records, verbose: false)

            expect(plan.toUpdateVikunja.count, toEqual: 0)
        }
    }
}

// MARK: - Run All Tests

func runAllTests() {
    testParseKeyValueString()
    testNormalizeDue()
    testNormalizeDueForMatch()
    testIsDateOnlyString()
    testNormalizeRelativeTo()
    testRelativeToForVikunja()
    testVikunjaDateString()
    testRecurrenceSignature()
    testMatchKey()
    testTasksDiffer()
    testDiffTasksCreate()
    testDiffTasksAutoMatch()
    testDiffTasksUpdate()
    testDiffTasksDelete()
    testDiffTasksConflict()
    testConflictFieldDiffs()
    testDiffTasksInferredDue()

    // Print results
    print("\n" + String(repeating: "=", count: 50))
    print("Test Results")
    print(String(repeating: "=", count: 50))
    print("Passed: \(testsPassed)")
    print("Failed: \(testsFailed)")
    print(String(repeating: "=", count: 50))

    if testsFailed > 0 {
        exit(1)
    }
}

// MARK: - Entry Point

@main
struct TestRunner {
    static func main() {
        runAllTests()
    }
}
