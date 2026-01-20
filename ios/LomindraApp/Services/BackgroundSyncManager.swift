import BackgroundTasks
import Foundation
import UIKit
import VikunjaSyncLib

final class BackgroundSyncManager {
    static let shared = BackgroundSyncManager()

    private let refreshTaskId = "com.lomindra.reminders.refresh"
    private let defaultInterval: TimeInterval = 6 * 60 * 60
    private let settingsStore = SettingsStore()
    private let keychainStore = KeychainStore()
    private let syncCoordinator = SyncCoordinator()
    private let statusStore = BackgroundSyncStatusStore()
    private let schedulingQueue = DispatchQueue(label: "vikunja.background.schedule")
    private var isScheduling = false

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleRefresh(task: refreshTask)
        }
    }

    func scheduleAppRefresh(completion: (() -> Void)? = nil) {
        schedulingQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isScheduling {
                if let completion = completion {
                    DispatchQueue.main.async { completion() }
                }
                return
            }
            self.isScheduling = true
            let finish: () -> Void = {
                self.schedulingQueue.async {
                    self.isScheduling = false
                }
                if let completion = completion {
                    DispatchQueue.main.async { completion() }
                }
            }
            guard self.isBackgroundSyncEnabled else {
                self.cancelPendingRefresh()
                finish()
                return
            }
            let refreshStatus = DispatchQueue.main.sync {
                UIApplication.shared.backgroundRefreshStatus
            }
            if refreshStatus != .available {
                let message: String
                switch refreshStatus {
                case .denied:
                    message = "Background App Refresh is disabled in Settings."
                case .restricted:
                    message = "Background App Refresh is restricted on this device."
                case .available:
                    message = "Background App Refresh is unavailable."
                @unknown default:
                    message = "Background App Refresh is unavailable."
                }
                let status = BackgroundSyncStatus(
                    lastRun: Date(),
                    success: false,
                    summary: nil,
                    errorMessage: message,
                    reportPath: nil
                )
                self.statusStore.save(status)
                finish()
                return
            }
            BGTaskScheduler.shared.getPendingTaskRequests { [weak self] requests in
                guard let self = self else { return }
                defer { finish() }
                if !requests.isEmpty {
                    let status = BackgroundSyncStatus(
                        lastRun: Date(),
                        success: false,
                        summary: nil,
                        errorMessage: "Background task already scheduled (pending=\(requests.count)).",
                        reportPath: nil
                    )
                    self.statusStore.save(status)
                    return
                }
                self.cancelPendingRefresh()
                let request = BGAppRefreshTaskRequest(identifier: self.refreshTaskId)
                request.earliestBeginDate = Date(timeIntervalSinceNow: self.defaultInterval)
                do {
                    try BGTaskScheduler.shared.submit(request)
                    let status = BackgroundSyncStatus(
                        lastRun: Date(),
                        success: true,
                        summary: "Scheduled background refresh.",
                        errorMessage: nil,
                        reportPath: nil
                    )
                    self.statusStore.save(status)
                } catch {
                    let nsError = error as NSError
                    let message: String
                    if nsError.domain == BGTaskScheduler.errorDomain {
                        switch nsError.code {
                        case 1:
                            message = "Background task not permitted: too many pending requests. Try again after leaving the app in background."
                        case 3:
                            let identifiers = self.permittedIdentifiers()
                            if !identifiers.contains(self.refreshTaskId) {
                                message = "Background task not permitted: missing BGTaskSchedulerPermittedIdentifiers entry for \(self.refreshTaskId)."
                            } else {
                                message = "Background task not permitted. If Background App Refresh has no toggle, iOS is restricting it (Low Power Mode/Screen Time/MDM)."
                            }
                        default:
                            message = "Failed to schedule background sync: \(error.localizedDescription)"
                        }
                    } else {
                        message = "Failed to schedule background sync: \(error.localizedDescription)"
                    }
                    let status = BackgroundSyncStatus(
                        lastRun: Date(),
                        success: false,
                        summary: nil,
                        errorMessage: message,
                        reportPath: nil
                    )
                    self.statusStore.save(status)
                }
            }
        }
    }

    func cancelPendingRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: refreshTaskId)
    }

    func clearAllTaskRequests() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        let status = BackgroundSyncStatus(
            lastRun: Date(),
            success: false,
            summary: nil,
            errorMessage: "Cleared all pending background tasks.",
            reportPath: nil
        )
        statusStore.save(status)
    }

    private func handleRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()
        let work = Task { await runBackgroundSync(task: task) }
        task.expirationHandler = {
            work.cancel()
        }
    }

    func runSyncNow() async {
        let status = await performSync()
        statusStore.save(status)
    }

    private func runBackgroundSync(task: BGAppRefreshTask) async {
        let status = await performSync()
        statusStore.save(status)
        task.setTaskCompleted(success: status.success)
    }

    private func performSync() async -> BackgroundSyncStatus {
        let start = Date()
        do {
            guard let settings = settingsStore.load() else {
                throw NSError(domain: "sync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing settings"])
            }
            guard settings.backgroundSyncEnabled else {
                throw NSError(domain: "sync", code: 2, userInfo: [NSLocalizedDescriptionKey: "Background sync disabled"])
            }
            guard let token = keychainStore.readToken(), !token.isEmpty else {
                throw NSError(domain: "sync", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing API token"])
            }
            let reportPath = SyncCoordinator.conflictReportPath()
            let result = try await syncCoordinator.runSync(
                settings: settings,
                token: token,
                mode: .apply,
                allowConflicts: true,
                conflictReportPath: reportPath,
                progress: nil
            )
            if Task.isCancelled {
                throw NSError(domain: "sync", code: 4, userInfo: [NSLocalizedDescriptionKey: "Background sync expired"])
            }
            var savedReportPath = result.reportPath
            if result.summary.conflicts == 0, let path = savedReportPath {
                try? FileManager.default.removeItem(atPath: path)
                savedReportPath = nil
            }
            return BackgroundSyncStatus(
                lastRun: start,
                success: true,
                summary: summaryText(result.summary),
                errorMessage: nil,
                reportPath: savedReportPath
            )
        } catch {
            return BackgroundSyncStatus(
                lastRun: start,
                success: false,
                summary: nil,
                errorMessage: error.localizedDescription,
                reportPath: nil
            )
        }
    }

    private var isBackgroundSyncEnabled: Bool {
        settingsStore.load()?.backgroundSyncEnabled ?? false
    }

    private func summaryText(_ summary: SyncSummary) -> String {
        if summary.conflicts > 0 {
            return "Conflicts detected (\(summary.conflicts))."
        }
        return "Sync complete."
    }

    private func permittedIdentifiers() -> [String] {
        return Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? []
    }
}
