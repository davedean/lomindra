import Foundation

struct BackgroundSyncStatus: Codable {
    let lastRun: Date
    let success: Bool
    let summary: String?
    let errorMessage: String?
    let reportPath: String?
}
