import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let token = appState.token, !token.isEmpty {
                MainView()
            } else {
                LoginView()
            }
        }
    }
}
