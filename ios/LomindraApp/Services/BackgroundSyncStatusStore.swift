import Foundation

final class BackgroundSyncStatusStore {
    private let statusKey = "vikunja.background.status"

    func load() -> BackgroundSyncStatus? {
        guard let data = UserDefaults.standard.data(forKey: statusKey) else {
            return nil
        }
        return try? JSONDecoder().decode(BackgroundSyncStatus.self, from: data)
    }

    func save(_ status: BackgroundSyncStatus) {
        guard let data = try? JSONEncoder().encode(status) else {
            return
        }
        UserDefaults.standard.set(data, forKey: statusKey)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: statusKey)
    }
}
