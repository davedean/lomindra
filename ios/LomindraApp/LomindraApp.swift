import SwiftUI

@main
struct LomindraApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()

    init() {
        BackgroundSyncManager.shared.register()
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
