import Foundation
import VikunjaSyncLib

func argumentValue(_ name: String) -> String? {
    let args = CommandLine.arguments
    if let index = args.firstIndex(of: name), index + 1 < args.count {
        return args[index + 1]
    }
    let prefix = "\(name)="
    if let match = args.first(where: { $0.hasPrefix(prefix) }) {
        return String(match.dropFirst(prefix.count))
    }
    return nil
}

func conflictResolution(from value: String?) -> ConflictResolution {
    guard let value = value?.lowercased(), !value.isEmpty else {
        return .none
    }
    return ConflictResolution(rawValue: value) ?? .none
}

do {
    let config = try loadConfigFromFiles()
    let apply = CommandLine.arguments.contains("--apply")
    let allowConflicts = CommandLine.arguments.contains("--allow-conflicts")
    let conflictReportPath = argumentValue("--conflict-report")
    let resolveConflicts = conflictResolution(from: argumentValue("--resolve-conflicts"))
    let options = SyncOptions(
        apply: apply,
        allowConflicts: allowConflicts,
        conflictReportPath: conflictReportPath,
        resolveConflicts: resolveConflicts,
        progress: nil
    )
    let summary = try runSync(config: config, options: options)
    print("Summary: lists=\(summary.listsProcessed), createVikunja=\(summary.createdInVikunja), createReminders=\(summary.createdInReminders), updateVikunja=\(summary.updatedVikunja), updateReminders=\(summary.updatedReminders), deleteVikunja=\(summary.deletedVikunja), deleteReminders=\(summary.deletedReminders), conflicts=\(summary.conflicts)")
} catch {
    let nsError = error as NSError
    fputs("Error: \(nsError.localizedDescription)\n", stderr)
    if nsError.domain == "sync", nsError.code == 3 {
        exit(3)
    }
    exit(1)
}
