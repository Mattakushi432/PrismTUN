import Foundation

actor DNSStore {
    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("PrismTUN")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("dns.json")
    }

    func load() throws -> DNSConfig {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .default }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(DNSConfig.self, from: data)
    }

    func save(_ config: DNSConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: .atomic)
    }
}
