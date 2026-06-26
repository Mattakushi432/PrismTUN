import Foundation

struct Subscription: Identifiable, Codable, Sendable {
    var id: UUID
    var name: String
    var url: URL
    var updateInterval: TimeInterval  // seconds; 0 = manual only
    var lastUpdated: Date?
    var userAgent: String             // e.g. "clash.meta", "sing-box"
    var includeRegex: String          // filter server names (empty = accept all)
    var excludeRegex: String          // filter server names (empty = none excluded)
    var profileIDs: [UUID]            // profiles owned by this subscription

    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        updateInterval: TimeInterval = 0,
        lastUpdated: Date? = nil,
        userAgent: String = "clash.meta",
        includeRegex: String = "",
        excludeRegex: String = "",
        profileIDs: [UUID] = []
    ) {
        self.id             = id
        self.name           = name
        self.url            = url
        self.updateInterval = updateInterval
        self.lastUpdated    = lastUpdated
        self.userAgent      = userAgent
        self.includeRegex   = includeRegex
        self.excludeRegex   = excludeRegex
        self.profileIDs     = profileIDs
    }
}
