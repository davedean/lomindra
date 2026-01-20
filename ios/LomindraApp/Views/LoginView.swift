import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var apiBase: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        Form {
            Section(header: Text("Vikunja Server")) {
                TextField("API base URL", text: $apiBase)
                    .autocapitalization(.none)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            Section(header: Text("Credentials")) {
                TextField("Username", text: $username)
                    .autocapitalization(.none)
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
            }
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            Section {
                Button(isWorking ? "Signing In..." : "Sign In") {
                    Task { await signIn() }
                }
                .disabled(isWorking || apiBase.isEmpty || username.isEmpty || password.isEmpty)
            }
        }
        .navigationTitle("Sign In")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .onAppear {
            apiBase = appState.settings.apiBase
        }
    }

    private func signIn() async {
        isWorking = true
        errorMessage = nil
        do {
            let trimmedBase = apiBase.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedBase.isEmpty, !trimmedUser.isEmpty, !trimmedPass.isEmpty else {
                throw NSError(domain: "login", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please enter a server URL, username, and password."])
            }
            let normalizedBase = VikunjaAPI.normalizeBase(trimmedBase)
            let api = VikunjaAPI(apiBase: normalizedBase)
            let jwt: String
            do {
                jwt = try await api.login(username: trimmedUser, password: trimmedPass)
            } catch {
                throw NSError(domain: "login", code: 2, userInfo: [NSLocalizedDescriptionKey: "Login failed: \(error.localizedDescription)"])
            }
            let token: String
            do {
                token = try await api.createAPIToken(jwt: jwt, title: "iOS Sync")
            } catch {
                throw NSError(domain: "login", code: 3, userInfo: [NSLocalizedDescriptionKey: "Token creation failed: \(error.localizedDescription)"])
            }
            let newSettings = AppSettings(
                apiBase: normalizedBase,
                syncAllLists: appState.settings.syncAllLists,
                remindersListId: appState.settings.remindersListId,
                vikunjaProjectId: appState.settings.vikunjaProjectId,
                selectedRemindersIds: appState.settings.selectedRemindersIds,
                projectOverrides: appState.settings.projectOverrides,
                backgroundSyncEnabled: appState.settings.backgroundSyncEnabled
            )
            appState.updateSettings(newSettings)
            appState.saveToken(token)
            password = ""
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }
        isWorking = false
    }
}
