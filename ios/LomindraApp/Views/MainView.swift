import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    @State private var showLogs = false

    private var isSignedIn: Bool {
        appState.token?.isEmpty == false
    }

    var body: some View {
        NavigationView {
            Form {
                if !isSignedIn {
                    Section {
                        Text("Sign in to Vikunja to sync projects and tasks.")
                            .foregroundColor(.secondary)
                        Button("Sign In") {
                            showLogin = true
                        }
                    }
                }
                ListSelectionView(showLogin: $showLogin)
                SyncView(showLogin: $showLogin)
            }
            .navigationTitle("Lomindra")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if isSignedIn {
                            Button("Sign Out", role: .destructive) {
                                appState.clearToken()
                            }
                        } else {
                            Button("Sign In") {
                                showLogin = true
                            }
                        }
                        Divider()
                        Button("View Sync Logs") {
                            showLogs = true
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            NavigationView {
                LoginView()
            }
        }
        .sheet(isPresented: $showLogs) {
            NavigationView {
                SyncLogsView()
            }
        }
        .onChange(of: appState.token) { token in
            if let token = token, !token.isEmpty {
                showLogin = false
            }
        }
    }
}
