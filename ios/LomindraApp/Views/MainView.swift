import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    @State private var showLogs = false

    private var isSignedIn: Bool {
        appState.token?.isEmpty == false
    }

    private var requiresBlockingLogin: Binding<Bool> {
        Binding(
            get: { !isSignedIn },
            set: { _ in }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                if isSignedIn {
                    ListSelectionView(showLogin: $showLogin)
                    SyncView(showLogin: $showLogin)
                } else {
                    Section {
                        Text("Your session has expired or you are signed out.")
                            .foregroundColor(.secondary)
                        Text("Please sign in to continue.")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                }
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
                LoginView(allowsDismiss: true)
            }
        }
        .fullScreenCover(isPresented: requiresBlockingLogin) {
            NavigationView {
                LoginView(allowsDismiss: false)
            }
        }
        .sheet(isPresented: $showLogs) {
            NavigationView {
                SyncLogsView()
            }
        }
        .onAppear {
            appState.reloadTokenFromKeychain()
        }
        .onChange(of: appState.token) { token in
            if let token = token, !token.isEmpty {
                showLogin = false
            }
        }
    }
}
