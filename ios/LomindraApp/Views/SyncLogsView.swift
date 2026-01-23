import SwiftUI

struct SyncLogsView: View {
    @State private var logURLs: [URL] = []
    @State private var shareItem: ShareItem?

    var body: some View {
        List {
            if logURLs.isEmpty {
                Text("No sync logs yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(logURLs, id: \.absoluteString) { url in
                    Button {
                        shareItem = ShareItem(url: url)
                    } label: {
                        LogRowView(url: url)
                    }
                }
            }
        }
        .navigationTitle("Sync Logs")
        .onAppear {
            logURLs = SyncLogStore.allLogURLs()
        }
        .onReceive(NotificationCenter.default.publisher(for: SyncLogStore.logUpdatedNotification)) { _ in
            logURLs = SyncLogStore.allLogURLs()
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
    }
}

struct LogRowView: View {
    let url: URL

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sourceText)
                    .font(.headline)
                Text(dateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(.accentColor)
        }
        .contentShape(Rectangle())
    }

    private var sourceText: String {
        if let parsed = SyncLogStore.parseLogFilename(url) {
            return parsed.source.capitalized + " sync"
        }
        return url.lastPathComponent
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        if let parsed = SyncLogStore.parseLogFilename(url) {
            return formatter.string(from: parsed.date)
        }

        // Fallback to file modification date
        if let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
            return formatter.string(from: modDate)
        }

        return "Unknown date"
    }
}
