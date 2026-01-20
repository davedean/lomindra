import Foundation
import SwiftUI
import VikunjaSyncLib

enum ConflictChoice: String, CaseIterable, Identifiable {
    case reminders
    case leave
    case vikunja

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reminders: return "Reminders"
        case .leave: return "Leave"
        case .vikunja: return "Vikunja"
        }
    }

    var resolution: ConflictResolution? {
        switch self {
        case .reminders: return .reminders
        case .vikunja: return .vikunja
        case .leave: return nil
        }
    }
}

struct ConflictReportView: View {
    let reportPath: String

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let syncCoordinator = SyncCoordinator()

    @State private var report: ConflictReport?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isApplying = false
    @State private var selections: [ConflictKey: ConflictChoice] = [:]

    var body: some View {
        List {
            if let statusMessage = statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundColor(.secondary)
                }
            }
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            if !isSignedIn {
                Section {
                    Text("Sign in to apply conflict resolutions.")
                        .foregroundColor(.secondary)
                }
            }
            if isApplying {
                Section {
                    ProgressView("Applying resolutions...")
                }
            }
            if let report = report {
                if report.conflicts.isEmpty {
                    Text("No conflicts in report.")
                        .foregroundColor(.secondary)
                }
                ForEach(report.conflicts) { conflict in
                    Section(header: Text(conflict.headerTitle)) {
                        conflictRow(conflict)
                    }
                }
            } else if errorMessage == nil {
                Text("Loading report...")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Conflicts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Apply") {
                    applySelections()
                }
                .disabled(!canApply)
            }
        }
        .onAppear {
            loadReport()
        }
    }

    private var isSignedIn: Bool {
        appState.token?.isEmpty == false
    }

    private var canSync: Bool {
        guard isSignedIn else { return false }
        let apiBase = appState.settings.apiBase.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiBase.isEmpty { return false }
        return !appState.settings.selectedRemindersIds.isEmpty
    }

    private var canApply: Bool {
        guard canSync, !isApplying else { return false }
        return selections.values.contains { $0 != .leave }
    }

    @ViewBuilder
    private func conflictRow(_ conflict: ConflictItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conflict.remindersTitle)
                        .font(.headline)
                    if conflict.remindersTitle != conflict.vikunjaTitle {
                        Text("Vikunja: \(conflict.vikunjaTitle)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Same title in both lists.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Picker("Resolution", selection: selectionBinding(for: conflict)) {
                    ForEach(ConflictChoice.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
                .disabled(conflict.conflictKey == nil)
            }
            if !conflict.diffs.isEmpty {
                DisclosureGroup("Differences") {
                    ForEach(conflict.diffs, id: \.self) { diff in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(diff.field)
                                .font(.subheadline)
                            Text("Reminders: \(diff.reminders)")
                                .font(.caption)
                            Text("Vikunja: \(diff.vikunja)")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private func selectionBinding(for conflict: ConflictItem) -> Binding<ConflictChoice> {
        guard let key = conflict.conflictKey else {
            return .constant(.leave)
        }
        return Binding(
            get: { selections[key] ?? .leave },
            set: { selections[key] = $0 }
        )
    }

    private func loadReport() {
        do {
            let url = URL(fileURLWithPath: reportPath)
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ConflictReport.self, from: data)
            report = decoded
            errorMessage = nil
            updateSelections(for: decoded)
        } catch {
            errorMessage = "Failed to load report: \(ErrorPresenter.userMessage(error))"
        }
    }

    private func updateSelections(for report: ConflictReport) {
        var nextSelections: [ConflictKey: ConflictChoice] = [:]
        for conflict in report.conflicts {
            guard let key = conflict.conflictKey else { continue }
            nextSelections[key] = selections[key] ?? .leave
        }
        selections = nextSelections
    }

    private func applySelections() {
        guard !isApplying else { return }
        guard canSync else {
            errorMessage = "Sign in and select lists before applying conflict resolutions."
            return
        }
        var resolutions: [ConflictKey: ConflictResolution] = [:]
        for (key, choice) in selections {
            if let resolution = choice.resolution {
                resolutions[key] = resolution
            }
        }
        guard !resolutions.isEmpty else {
            statusMessage = "Select at least one conflict to resolve."
            return
        }
        guard let token = appState.token, !token.isEmpty else {
            errorMessage = "Missing API token."
            return
        }
        isApplying = true
        errorMessage = nil
        statusMessage = "Applying selected resolutions..."
        Task {
            do {
                _ = try await syncCoordinator.runSync(
                    settings: appState.settings,
                    token: token,
                    mode: .apply,
                    allowConflicts: true,
                    conflictReportPath: reportPath,
                    conflictResolutions: resolutions,
                    progress: nil
                )
                await MainActor.run {
                    isApplying = false
                    statusMessage = "Applied selected resolutions."
                    loadReport()
                    if report?.conflicts.isEmpty == true {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isApplying = false
                    errorMessage = "Failed to apply resolutions: \(ErrorPresenter.userMessage(error))"
                }
            }
        }
    }
}

struct ConflictReport: Decodable {
    let generatedAt: String?
    let conflictCount: Int?
    let conflicts: [ConflictItem]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case conflictCount = "conflict_count"
        case conflicts
    }
}

struct ConflictItem: Identifiable, Decodable {
    let id = UUID()
    let remindersListTitle: String?
    let vikunjaProjectTitle: String?
    let reminders: ConflictTaskSnapshot?
    let vikunja: ConflictTaskSnapshot?
    let diffs: [ConflictDiff]

    enum CodingKeys: String, CodingKey {
        case remindersListTitle = "reminders_list_title"
        case vikunjaProjectTitle = "vikunja_project_title"
        case reminders
        case vikunja
        case diffs
    }

    var headerTitle: String {
        let reminders = remindersListTitle ?? "Reminders"
        let vikunja = vikunjaProjectTitle ?? "Vikunja"
        return "\(reminders) -> \(vikunja)"
    }

    var remindersTitle: String {
        reminders?.title ?? "Reminders task"
    }

    var vikunjaTitle: String {
        vikunja?.title ?? "Vikunja task"
    }

    var conflictKey: ConflictKey? {
        guard let remindersId = reminders?.id, let vikunjaId = vikunja?.id else { return nil }
        return ConflictKey(remindersId: remindersId, vikunjaId: vikunjaId)
    }
}

struct ConflictTaskSnapshot: Decodable, Hashable {
    let id: String
    let listId: String?
    let title: String
    let completed: Bool
    let due: String?
    let start: String?
    let updatedAt: String?
    let dueDateOnly: Bool?
    let startDateOnly: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case title
        case completed
        case due
        case start
        case updatedAt = "updated_at"
        case dueDateOnly = "due_date_only"
        case startDateOnly = "start_date_only"
    }
}

struct ConflictDiff: Decodable, Hashable {
    let field: String
    let reminders: String
    let vikunja: String
}
