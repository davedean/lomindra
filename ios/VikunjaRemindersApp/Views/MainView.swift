import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            Form {
                ListSelectionView()
                SyncView()
            }
            .navigationTitle("Vikunja Sync")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        appState.clearToken()
                    }
                }
            }
        }
    }
}
