import Foundation

actor ProfileStore {
    static var directoryURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("PrismTUN")
    }

    private let fileURL: URL

    init() {
        let dir = ProfileStore.directoryURL
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            // Directory creation failure propagated at first load/save call via fileURL being in a non-existent dir
        }
        fileURL = dir.appendingPathComponent("profiles.json")
    }

    func load() throws -> [ProxyProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var profiles = try decoder.decode([ProxyProfile].self, from: data)
        // Populate secrets from Keychain (not stored in plaintext JSON)
        for i in profiles.indices {
            let uid = profiles[i].id.uuidString
            profiles[i].password        = KeychainStore.load(key: "\(uid).password")        ?? ""
            profiles[i].trojanPassword  = KeychainStore.load(key: "\(uid).trojanPassword")  ?? ""
            profiles[i].wgPrivateKey    = KeychainStore.load(key: "\(uid).wgPrivateKey")    ?? ""
            profiles[i].wgPresharedKey  = KeychainStore.load(key: "\(uid).wgPresharedKey")  ?? ""
        }
        return profiles
    }

    func save(_ profiles: [ProxyProfile]) throws {
        // Persist secrets to Keychain before stripping them from JSON
        for profile in profiles {
            let uid = profile.id.uuidString
            if !profile.password.isEmpty       { KeychainStore.save(key: "\(uid).password",       secret: profile.password) }
            if !profile.trojanPassword.isEmpty { KeychainStore.save(key: "\(uid).trojanPassword", secret: profile.trojanPassword) }
            if !profile.wgPrivateKey.isEmpty   { KeychainStore.save(key: "\(uid).wgPrivateKey",   secret: profile.wgPrivateKey) }
            if !profile.wgPresharedKey.isEmpty { KeychainStore.save(key: "\(uid).wgPresharedKey", secret: profile.wgPresharedKey) }
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profiles)
        try data.write(to: fileURL, options: .atomic)
    }
}
