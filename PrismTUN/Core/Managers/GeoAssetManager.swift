import Foundation

struct GeoAssetStatus: Sendable {
    var version: String?
    var updatedAt: Date?
    var fileSize: Int64?

    var isDownloaded: Bool { (fileSize ?? 0) > 0 }
}

actor GeoAssetManager {
    static let shared = GeoAssetManager()

    static let geoDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("PrismTUN/geo", isDirectory: true)
    }()

    nonisolated var geoipURL: URL   { Self.geoDirectory.appendingPathComponent("geoip.db") }
    nonisolated var geositeURL: URL { Self.geoDirectory.appendingPathComponent("geosite.db") }

    private(set) var geoipStatus: GeoAssetStatus   = GeoAssetStatus()
    private(set) var geositeStatus: GeoAssetStatus = GeoAssetStatus()
    private(set) var isUpdating: Bool               = false

    private init() {}

    // MARK: - Status

    func loadStatus() {
        geoipStatus   = readStatus(for: "geoip",  at: geoipURL)
        geositeStatus = readStatus(for: "geosite", at: geositeURL)
    }

    func geoPaths() -> GeoPaths? {
        guard geoipStatus.isDownloaded, geositeStatus.isDownloaded else { return nil }
        return GeoPaths(geoip: geoipURL.path, geosite: geositeURL.path)
    }

    // MARK: - Update

    func update() async throws {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        try FileManager.default.createDirectory(at: Self.geoDirectory, withIntermediateDirectories: true)

        async let ipTagTask   = fetchLatestTag(repo: "SagerNet/sing-geoip")
        async let siteTagTask = fetchLatestTag(repo: "SagerNet/sing-geosite")
        let (ipTag, siteTag)  = try await (ipTagTask, siteTagTask)

        let ipDownloadURL   = URL(string: "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db")!
        let siteDownloadURL = URL(string: "https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db")!

        try await downloadFile(from: ipDownloadURL,   to: geoipURL)
        try await downloadFile(from: siteDownloadURL, to: geositeURL)

        let now = Date()
        persistStatus(key: "geoip",   version: ipTag,   date: now)
        persistStatus(key: "geosite", version: siteTag, date: now)

        geoipStatus   = readStatus(for: "geoip",  at: geoipURL)
        geositeStatus = readStatus(for: "geosite", at: geositeURL)
    }

    func updateIfNeeded() async {
        loadStatus()
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        guard let lastUpdate = geoipStatus.updatedAt, lastUpdate >= weekAgo else {
            try? await update()
            return
        }
    }

    // MARK: - Private

    private func fetchLatestTag(repo: String) async throws -> String {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String
        else { return "unknown" }
        return tag
    }

    private func downloadFile(from source: URL, to destination: URL) async throws {
        let (tempURL, _) = try await URLSession.shared.download(from: source)
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: tempURL, to: destination)
    }

    private func readStatus(for key: String, at url: URL) -> GeoAssetStatus {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size  = attrs?[.size] as? Int64
        return GeoAssetStatus(
            version:   UserDefaults.standard.string(forKey: "geo.\(key).version"),
            updatedAt: UserDefaults.standard.object(forKey: "geo.\(key).updatedAt") as? Date,
            fileSize:  size
        )
    }

    private func persistStatus(key: String, version: String, date: Date) {
        UserDefaults.standard.set(version, forKey: "geo.\(key).version")
        UserDefaults.standard.set(date,    forKey: "geo.\(key).updatedAt")
    }
}
