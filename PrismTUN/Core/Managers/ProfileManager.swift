import Foundation

@Observable
@MainActor
final class ProfileManager {
    private(set) var profiles: [ProxyProfile] = []
    private(set) var activeProfileID: UUID?
    private(set) var lastError: Error?

    private let store = ProfileStore()

    var activeProfile: ProxyProfile? {
        profiles.first { $0.id == activeProfileID }
    }

    func load() async {
        do {
            profiles = try await store.load()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    func add(_ profile: ProxyProfile) async {
        profiles.append(profile)
        await persist()
    }

    func update(_ profile: ProxyProfile) async {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
        }
        await persist()
    }

    func delete(id: UUID) async {
        profiles.removeAll { $0.id == id }
        if activeProfileID == id { activeProfileID = nil }
        KeychainStore.delete(key: "\(id.uuidString).password")
        KeychainStore.delete(key: "\(id.uuidString).trojanPassword")
        KeychainStore.delete(key: "\(id.uuidString).wgPrivateKey")
        KeychainStore.delete(key: "\(id.uuidString).wgPresharedKey")
        await persist()
    }

    func setActive(id: UUID?) async {
        activeProfileID = id
    }

    func bulkAdd(_ newProfiles: [ProxyProfile]) async {
        profiles.append(contentsOf: newProfiles)
        await persist()
    }

    func bulkDelete(ids: Set<UUID>) async {
        profiles.removeAll { ids.contains($0.id) }
        if let active = activeProfileID, ids.contains(active) {
            activeProfileID = nil
        }
        for id in ids {
            KeychainStore.delete(key: "\(id.uuidString).password")
            KeychainStore.delete(key: "\(id.uuidString).trojanPassword")
            KeychainStore.delete(key: "\(id.uuidString).wgPrivateKey")
            KeychainStore.delete(key: "\(id.uuidString).wgPresharedKey")
        }
        await persist()
    }

    private func persist() async {
        let snapshot = profiles
        do {
            try await store.save(snapshot)
            lastError = nil
        } catch {
            lastError = error
        }
    }
}
