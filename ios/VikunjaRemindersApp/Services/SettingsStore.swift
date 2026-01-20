import Foundation

final class SettingsStore {
    private let settingsKey = "vikunja.app.settings"

    func load() -> AppSettings? {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }
}
