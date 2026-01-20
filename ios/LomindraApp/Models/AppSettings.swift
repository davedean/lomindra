import Foundation

struct AppSettings: Codable {
    var apiBase: String
    var syncAllLists: Bool
    var remindersListId: String?
    var vikunjaProjectId: Int?
    var selectedRemindersIds: [String]
    var projectOverrides: [String: Int]
    var backgroundSyncEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case apiBase
        case syncAllLists
        case remindersListId
        case vikunjaProjectId
        case selectedRemindersIds
        case projectOverrides
        case backgroundSyncEnabled
    }

    init(apiBase: String, syncAllLists: Bool, remindersListId: String?, vikunjaProjectId: Int?, selectedRemindersIds: [String], projectOverrides: [String: Int], backgroundSyncEnabled: Bool) {
        self.apiBase = apiBase
        self.syncAllLists = syncAllLists
        self.remindersListId = remindersListId
        self.vikunjaProjectId = vikunjaProjectId
        self.selectedRemindersIds = selectedRemindersIds
        self.projectOverrides = projectOverrides
        self.backgroundSyncEnabled = backgroundSyncEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiBase = (try? container.decode(String.self, forKey: .apiBase)) ?? ""
        syncAllLists = (try? container.decode(Bool.self, forKey: .syncAllLists)) ?? false
        remindersListId = try? container.decode(String.self, forKey: .remindersListId)
        vikunjaProjectId = try? container.decode(Int.self, forKey: .vikunjaProjectId)
        selectedRemindersIds = (try? container.decode([String].self, forKey: .selectedRemindersIds)) ?? []
        projectOverrides = (try? container.decode([String: Int].self, forKey: .projectOverrides)) ?? [:]
        backgroundSyncEnabled = (try? container.decode(Bool.self, forKey: .backgroundSyncEnabled)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(apiBase, forKey: .apiBase)
        try container.encode(syncAllLists, forKey: .syncAllLists)
        try container.encodeIfPresent(remindersListId, forKey: .remindersListId)
        try container.encodeIfPresent(vikunjaProjectId, forKey: .vikunjaProjectId)
        try container.encode(selectedRemindersIds, forKey: .selectedRemindersIds)
        try container.encode(projectOverrides, forKey: .projectOverrides)
        try container.encode(backgroundSyncEnabled, forKey: .backgroundSyncEnabled)
    }

    static let empty = AppSettings(
        apiBase: "",
        syncAllLists: false,
        remindersListId: nil,
        vikunjaProjectId: nil,
        selectedRemindersIds: [],
        projectOverrides: [:],
        backgroundSyncEnabled: false
    )
}
