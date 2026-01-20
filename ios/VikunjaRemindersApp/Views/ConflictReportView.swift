import Foundation
import SwiftUI

struct ConflictReportView: View {
    let reportPath: String

    @State private var report: ConflictReport?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let report = report {
                if report.conflicts.isEmpty {
                    Text("No conflicts in report.")
                        .foregroundColor(.secondary)
                }
                ForEach(report.conflicts) { conflict in
                    Section(header: Text(conflict.headerTitle)) {
                        ForEach(conflict.diffs, id: \.self) { diff in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(diff.field)
                                    .font(.headline)
                                Text("Reminders: \(diff.reminders)")
                                    .font(.subheadline)
                                Text("Vikunja: \(diff.vikunja)")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else {
                Text("Loading report...")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Conflicts")
        .onAppear {
            loadReport()
        }
    }

    private func loadReport() {
        do {
            let url = URL(fileURLWithPath: reportPath)
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ConflictReport.self, from: data)
            report = decoded
        } catch {
            errorMessage = "Failed to load report: \(error.localizedDescription)"
        }
    }
}

struct ConflictReport: Decodable {
    let generatedAt: String?
    let conflictCount: Int?
    let conflicts: [ConflictItem]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case conflictCount = "conflict_count"
        case conflicts
    }
}

struct ConflictItem: Identifiable, Decodable {
    let id = UUID()
    let remindersListTitle: String?
    let vikunjaProjectTitle: String?
    let diffs: [ConflictDiff]

    enum CodingKeys: String, CodingKey {
        case remindersListTitle = "reminders_list_title"
        case vikunjaProjectTitle = "vikunja_project_title"
        case diffs
    }

    var headerTitle: String {
        let reminders = remindersListTitle ?? "Reminders"
        let vikunja = vikunjaProjectTitle ?? "Vikunja"
        return "\(reminders) → \(vikunja)"
    }
}

struct ConflictDiff: Decodable, Hashable {
    let field: String
    let reminders: String
    let vikunja: String
}
