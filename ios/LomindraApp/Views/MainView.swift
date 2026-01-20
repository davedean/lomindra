import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    @State private var latestLogURL: URL?
    @State private var shareItem: ShareItem?

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
                        if let latestLogURL = latestLogURL {
                            Button("Download Sync Log") {
                                shareItem = ShareItem(url: latestLogURL)
                            }
                        } else {
                            Button("No Sync Logs Yet") {}
                                .disabled(true)
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
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .onChange(of: appState.token) { token in
            if let token = token, !token.isEmpty {
                showLogin = false
            }
        }
        .onAppear {
            refreshLatestLog()
        }
        .onReceive(NotificationCenter.default.publisher(for: SyncLogStore.logUpdatedNotification)) { _ in
            refreshLatestLog()
        }
    }

    private func refreshLatestLog() {
        latestLogURL = SyncLogStore.latestLogURL()
    }
}
