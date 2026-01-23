import SwiftUI

@main
struct LomindraApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()

    init() {
        BackgroundSyncManager.shared.register()
        // Migrate existing token to new accessibility level (allows reading when device is locked)
        KeychainStore().migrateTokenAccessibility()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                BackgroundSyncManager.shared.scheduleAppRefresh()
            }
        }
    }
}
