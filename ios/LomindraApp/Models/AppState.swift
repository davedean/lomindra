import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var settings: AppSettings
    @Published var token: String?
    @Published var statusMessage: String?
    @Published var cachedReminders: [RemindersList] = []
    @Published var cachedProjects: [VikunjaProject] = []

    private let settingsStore = SettingsStore()
    private let keychain = KeychainStore()

    init() {
        self.settings = settingsStore.load() ?? AppSettings.empty
        self.token = keychain.readToken()
    }

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        settingsStore.save(newSettings)
    }

    func saveToken(_ newToken: String) {
        token = newToken
        keychain.saveToken(newToken)
    }

    func clearToken() {
        token = nil
        keychain.deleteToken()
    }
}
