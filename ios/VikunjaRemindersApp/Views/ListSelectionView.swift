import SwiftUI

struct ListSelectionView: View {
    @EnvironmentObject var appState: AppState

    @State private var remindersLists: [RemindersList] = []
    @State private var projects: [VikunjaProject] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var projectError: String?
    @State private var selectedReminders: Set<String> = []
    @State private var projectOverrides: [String: Int] = [:]
    @State private var activeProjectPicker: RemindersList?

    private let remindersService = RemindersService()

    var body: some View {
        Section(header: Text("Lists")) {
            ForEach(remindersLists) { list in
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(list.title, isOn: selectionBinding(for: list))
                    if selectedReminders.contains(list.id) {
                        Text(mappingText(for: list))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button("Choose project") {
                            activeProjectPicker = list
                        }
                        .font(.footnote)
                    }
                }
            }

            if isLoading {
                Text("Loading lists...")
                    .foregroundColor(.secondary)
            }
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            if let projectError = projectError {
                Text(projectError)
                    .foregroundColor(.red)
                    .font(.footnote)
            } else if appState.token == nil || (appState.token?.isEmpty ?? true) {
                Text("Sign in to load Vikunja projects.")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            } else if appState.settings.apiBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Missing server URL. Sign out and sign in again.")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            } else if !isLoading && projects.isEmpty {
                Text("No Vikunja projects returned yet.")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
            Button("Reload Lists") {
                Task { await loadLists() }
            }
        }
        .onAppear {
            selectedReminders = Set(appState.settings.selectedRemindersIds)
            projectOverrides = appState.settings.projectOverrides
            Task { await loadLists() }
        }
        .sheet(item: $activeProjectPicker) { list in
            ProjectPickerView(
                list: list,
                projects: projects,
                selectedProjectId: projectOverrides[list.id]
            ) { selection in
                if let selection = selection {
                    projectOverrides[list.id] = selection
                } else {
                    projectOverrides.removeValue(forKey: list.id)
                }
                updateSettings()
            }
        }
    }

    private func selectionBinding(for list: RemindersList) -> Binding<Bool> {
        Binding(
            get: { selectedReminders.contains(list.id) },
            set: { isSelected in
                if isSelected {
                    selectedReminders.insert(list.id)
                } else {
                    selectedReminders.remove(list.id)
                    projectOverrides.removeValue(forKey: list.id)
                }
                updateSettings()
            }
        )
    }

    private func loadLists() async {
        isLoading = true
        errorMessage = nil
        projectError = nil
        do {
            remindersLists = try await remindersService.fetchLists()
        } catch {
            errorMessage = "Failed to load Reminders lists: \(error.localizedDescription)"
        }
        if let apiBase = nonEmpty(appState.settings.apiBase), let token = appState.token, !token.isEmpty {
            do {
                let api = VikunjaAPI(apiBase: apiBase)
                projects = try await api.fetchProjects(token: token)
            } catch {
                projects = []
                projectError = "Failed to load Vikunja projects: \(error.localizedDescription)"
            }
        } else if appState.token != nil && !(appState.token?.isEmpty ?? true) {
            projectError = "Missing server URL for Vikunja projects."
            projects = []
        } else {
            projects = []
        }
        appState.cachedReminders = remindersLists
        appState.cachedProjects = projects
        isLoading = false
    }

    private func updateSettings() {
        let newSettings = AppSettings(
            apiBase: appState.settings.apiBase,
            syncAllLists: false,
            remindersListId: nil,
            vikunjaProjectId: nil,
            selectedRemindersIds: Array(selectedReminders).sorted(),
            projectOverrides: projectOverrides,
            backgroundSyncEnabled: appState.settings.backgroundSyncEnabled
        )
        appState.updateSettings(newSettings)
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func mappingText(for list: RemindersList) -> String {
        if let overrideId = projectOverrides[list.id] {
            if let project = projects.first(where: { $0.id == overrideId }) {
                return "Mapped to: \(project.title) (manual)"
            }
            return "Mapped to: Project \(overrideId) (manual)"
        }
        if projects.isEmpty {
            return "Projects not loaded; reload lists to match."
        }
        if let match = projects.first(where: { $0.title.caseInsensitiveCompare(list.title) == .orderedSame }) {
            return "Auto-match: \(match.title)"
        }
        return "No match; will create project on apply."
    }
}

private struct ProjectPickerView: View {
    let list: RemindersList
    let projects: [VikunjaProject]
    let selectedProjectId: Int?
    let onSelect: (Int?) -> Void

    var body: some View {
        NavigationView {
            List {
                Button("Use auto-match") {
                    onSelect(nil)
                }
                if projects.isEmpty {
                    Text("No projects available.")
                        .foregroundColor(.secondary)
                }
                ForEach(projects, id: \.id) { project in
                    Button {
                        onSelect(project.id)
                    } label: {
                        HStack {
                            Text(project.title)
                            Spacer()
                            if project.id == selectedProjectId {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Project")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
