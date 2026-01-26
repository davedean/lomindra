import Foundation

struct AppSettings: Codable {
    var apiBase: String
    var syncAllLists: Bool
    var remindersListId: String?
    var vikunjaProjectId: Int?
    var selectedRemindersIds: [String]
    var projectOverrides: [String: Int]
    var backgroundSyncEnabled: Bool
    var syncFrequencyMinutes: Int
    var syncTagsEnabled: Bool

    /// Available sync frequency options (in minutes)
    static let frequencyOptions: [(label: String, minutes: Int)] = [
        ("Every 1 minute (testing)", 1),
        ("Every 5 minutes (testing)", 5),
        ("Every 15 minutes", 15),
        ("Every 30 minutes", 30),
        ("Every hour", 60),
        ("Every 2 hours", 120),
        ("Every 6 hours", 360),
    ]

    /// Default sync frequency in minutes (1 hour)
    static let defaultFrequencyMinutes = 60

    enum CodingKeys: String, CodingKey {
        case apiBase
        case syncAllLists
        case remindersListId
        case vikunjaProjectId
        case selectedRemindersIds
        case projectOverrides
        case backgroundSyncEnabled
        case syncFrequencyMinutes
        case syncTagsEnabled
    }

    init(apiBase: String, syncAllLists: Bool, remindersListId: String?, vikunjaProjectId: Int?, selectedRemindersIds: [String], projectOverrides: [String: Int], backgroundSyncEnabled: Bool, syncFrequencyMinutes: Int = AppSettings.defaultFrequencyMinutes, syncTagsEnabled: Bool = false) {
        self.apiBase = apiBase
        self.syncAllLists = syncAllLists
        self.remindersListId = remindersListId
        self.vikunjaProjectId = vikunjaProjectId
        self.selectedRemindersIds = selectedRemindersIds
        self.projectOverrides = projectOverrides
        self.backgroundSyncEnabled = backgroundSyncEnabled
        self.syncFrequencyMinutes = syncFrequencyMinutes
        self.syncTagsEnabled = syncTagsEnabled
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
        syncFrequencyMinutes = (try? container.decode(Int.self, forKey: .syncFrequencyMinutes)) ?? AppSettings.defaultFrequencyMinutes
        syncTagsEnabled = (try? container.decode(Bool.self, forKey: .syncTagsEnabled)) ?? false
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
        try container.encode(syncFrequencyMinutes, forKey: .syncFrequencyMinutes)
        try container.encode(syncTagsEnabled, forKey: .syncTagsEnabled)
    }

    static let empty = AppSettings(
        apiBase: "",
        syncAllLists: false,
        remindersListId: nil,
        vikunjaProjectId: nil,
        selectedRemindersIds: [],
        projectOverrides: [:],
        backgroundSyncEnabled: false,
        syncFrequencyMinutes: defaultFrequencyMinutes,
        syncTagsEnabled: false
    )
}
