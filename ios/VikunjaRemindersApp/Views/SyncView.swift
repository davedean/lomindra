import BackgroundTasks
import Foundation
import SwiftUI
import VikunjaSyncLib

struct SyncView: View {
    @EnvironmentObject var appState: AppState

    private let syncCoordinator = SyncCoordinator()
    private let backgroundStatusStore = BackgroundSyncStatusStore()

    @State private var statusMessage: String = "Ready to sync."
    @State private var errorMessage: String?
    @State private var lastReportPath: String?
    @State private var isWorking = false
    @State private var showCreateConfirm = false
    @State private var pendingApply = false
    @State private var createListTitles: [String] = []
    @State private var currentRunId = UUID()
    @State private var finishedRunId: UUID?
    @State private var backgroundStatus: BackgroundSyncStatus?
    @State private var pendingRequestsCount: Int?

    var body: some View {
        Group {
            Section(header: Text("Sync")) {
                Text(statusMessage)
                    .foregroundColor(.secondary)
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                if let lastReportPath = lastReportPath {
                    Text("Conflict report: \(lastReportPath)")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                    NavigationLink("View Conflicts") {
                        ConflictReportView(reportPath: lastReportPath)
                    }
                }
                Button("Dry Run") {
                    statusMessage = "Dry run tapped (apply=false)"
                    Task { await runSync(mode: .dryRun) }
                }
                .buttonStyle(.bordered)
                .disabled(isWorking || !canSync)
                Button("Apply") {
                    statusMessage = "Apply tapped (apply=true)"
                    prepareApply()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking || !canSync)
            }
            Section(header: Text("Background")) {
                Toggle("Enable background sync", isOn: backgroundSyncBinding)
#if DEBUG
                Button("Schedule Background Refresh") {
                    BackgroundSyncManager.shared.scheduleAppRefresh {
                        backgroundStatus = backgroundStatusStore.load()
                        refreshPendingCount()
                    }
                }
                Button("Run Background Sync Now") {
                    Task {
                        await BackgroundSyncManager.shared.runSyncNow()
                        backgroundStatus = backgroundStatusStore.load()
                        refreshPendingCount()
                    }
                }
                Button("Clear Background Tasks") {
                    BackgroundSyncManager.shared.clearAllTaskRequests()
                    backgroundStatus = backgroundStatusStore.load()
                    refreshPendingCount()
                }
#endif
                Text(pendingRequestsText)
                    .foregroundColor(.secondary)
                    .font(.footnote)
                if let backgroundStatus = backgroundStatus {
                    Text(backgroundStatusText(backgroundStatus))
                        .foregroundColor(backgroundStatus.success ? .secondary : .red)
                        .font(.footnote)
                    if let reportPath = backgroundStatus.reportPath {
                        Text("Last conflict report: \(reportPath)")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                } else {
                    Text("No background sync history yet.")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }
        }
        .onAppear {
            backgroundStatus = backgroundStatusStore.load()
            refreshPendingCount()
        }
        .alert("Create missing projects?", isPresented: $showCreateConfirm) {
            Button("Create", role: .destructive) {
                if pendingApply {
                    Task { await runSync(mode: .apply) }
                }
                pendingApply = false
            }
            Button("Cancel", role: .cancel) {
                pendingApply = false
            }
        } message: {
            Text(confirmMessage())
        }
    }

    private var canSync: Bool {
        guard let token = appState.token, !token.isEmpty else { return false }
        let apiBase = appState.settings.apiBase.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiBase.isEmpty { return false }
        return !appState.settings.selectedRemindersIds.isEmpty
    }

    private func runSync(mode: SyncRunMode) async {
        let runId = UUID()
        currentRunId = runId
        finishedRunId = nil
        isWorking = true
        errorMessage = nil
        lastReportPath = nil
        statusMessage = "\(mode.label) in progress (apply=\(mode.isApply))..."
        do {
            guard let token = appState.token, !token.isEmpty else {
                throw NSError(domain: "sync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing API token"])
            }
            let reportPath = mode.isApply ? nil : SyncCoordinator.conflictReportPath()
            let result = try await syncCoordinator.runSync(
                settings: appState.settings,
                token: token,
                mode: mode,
                allowConflicts: false,
                conflictReportPath: reportPath,
                progress: { progress in
                    Task { @MainActor in
                        guard currentRunId == runId, finishedRunId != runId else { return }
                        if let listTitle = progress.listTitle {
                            statusMessage = "\(progress.message): \(listTitle)"
                        } else {
                            statusMessage = progress.message
                        }
                    }
                }
            )
            await MainActor.run {
                guard currentRunId == runId else { return }
                statusMessage = summaryText(result.summary, modeLabel: mode.label, apply: mode.isApply)
                lastReportPath = result.reportPath
                finishedRunId = runId
            }
        } catch {
            await MainActor.run {
                guard currentRunId == runId else { return }
                errorMessage = "Sync failed: \(error.localizedDescription)"
                statusMessage = "Sync failed."
                finishedRunId = runId
            }
        }
        await MainActor.run {
            if currentRunId == runId {
                isWorking = false
            }
        }
    }

    private func summaryText(_ summary: SyncSummary, modeLabel: String, apply: Bool) -> String {
        return "\(modeLabel) (apply=\(apply)): lists=\(summary.listsProcessed), createVikunja=\(summary.createdInVikunja), createReminders=\(summary.createdInReminders), updateVikunja=\(summary.updatedVikunja), updateReminders=\(summary.updatedReminders), deleteVikunja=\(summary.deletedVikunja), deleteReminders=\(summary.deletedReminders), conflicts=\(summary.conflicts)"
    }

    private func prepareApply() {
        guard !isWorking else { return }
        let missing = missingProjectTitles()
        if missing.isEmpty {
            Task { await runSync(mode: .apply) }
            return
        }
        createListTitles = missing
        pendingApply = true
        showCreateConfirm = true
    }

    private func missingProjectTitles() -> [String] {
        let projects = appState.cachedProjects
        let reminders = appState.cachedReminders
        let overrides = appState.settings.projectOverrides
        var missing: [String] = []
        for listId in appState.settings.selectedRemindersIds {
            if overrides[listId] != nil {
                continue
            }
            guard let list = reminders.first(where: { $0.id == listId }) else {
                continue
            }
            let hasMatch = projects.contains { $0.title.caseInsensitiveCompare(list.title) == .orderedSame }
            if !hasMatch {
                missing.append(list.title)
            }
        }
        return missing
    }

    private func confirmMessage() -> String {
        if createListTitles.isEmpty {
            return "One or more projects are missing. Create them now?"
        }
        let preview = createListTitles.prefix(5).joined(separator: ", ")
        if createListTitles.count > 5 {
            return "Create projects for: \(preview) (+\(createListTitles.count - 5) more)?"
        }
        return "Create projects for: \(preview)?"
    }

    private var backgroundSyncBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.backgroundSyncEnabled },
            set: { enabled in
                let updated = AppSettings(
                    apiBase: appState.settings.apiBase,
                    syncAllLists: appState.settings.syncAllLists,
                    remindersListId: appState.settings.remindersListId,
                    vikunjaProjectId: appState.settings.vikunjaProjectId,
                    selectedRemindersIds: appState.settings.selectedRemindersIds,
                    projectOverrides: appState.settings.projectOverrides,
                    backgroundSyncEnabled: enabled
                )
                appState.updateSettings(updated)
                if enabled {
                    BackgroundSyncManager.shared.scheduleAppRefresh {
                        backgroundStatus = backgroundStatusStore.load()
                        refreshPendingCount()
                    }
                } else {
                    BackgroundSyncManager.shared.cancelPendingRefresh()
                }
                if !enabled {
                    backgroundStatus = backgroundStatusStore.load()
                    refreshPendingCount()
                }
            }
        )
    }

    private var pendingRequestsText: String {
        if let count = pendingRequestsCount {
            return "Pending background requests: \(count)"
        }
        return "Pending background requests: unknown"
    }

    private func refreshPendingCount() {
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            DispatchQueue.main.async {
                pendingRequestsCount = requests.count
            }
        }
    }

    private func backgroundStatusText(_ status: BackgroundSyncStatus) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let stamp = formatter.string(from: status.lastRun)
        if status.success, let summary = status.summary {
            return "Last run \(stamp): \(summary)"
        }
        if let error = status.errorMessage {
            return "Last run \(stamp) failed: \(error)"
        }
        return "Last run \(stamp): unknown result"
    }
}
