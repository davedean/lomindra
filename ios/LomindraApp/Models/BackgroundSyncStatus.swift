import Foundation

struct BackgroundSyncStatus: Codable {
    let lastRun: Date
    let success: Bool
    let summary: String?
    let errorMessage: String?
    let reportPath: String?
    let requiresReauth: Bool

    init(lastRun: Date,
         success: Bool,
         summary: String?,
         errorMessage: String?,
         reportPath: String?,
         requiresReauth: Bool = false) {
        self.lastRun = lastRun
        self.success = success
        self.summary = summary
        self.errorMessage = errorMessage
        self.reportPath = reportPath
        self.requiresReauth = requiresReauth
    }

    private enum CodingKeys: String, CodingKey {
        case lastRun
        case success
        case summary
        case errorMessage
        case reportPath
        case requiresReauth
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastRun = try container.decode(Date.self, forKey: .lastRun)
        success = try container.decode(Bool.self, forKey: .success)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        reportPath = try container.decodeIfPresent(String.self, forKey: .reportPath)
        requiresReauth = try container.decodeIfPresent(Bool.self, forKey: .requiresReauth) ?? false
    }
}
