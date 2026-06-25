import Foundation

@Observable
final class ProfileManager: @unchecked Sendable {
    private(set) var profiles: [ProxyProfile] = []
    private(set) var activeProfileID: UUID?

    private let store = ProfileStore()

    var activeProfile: ProxyProfile? {
        profiles.first { $0.id == activeProfileID }
    }

    func load() async {
        do {
            let loaded = try await store.load()
            await MainActor.run { profiles = loaded }
        } catch {
            print("[ProfileManager] load error: \(error)")
        }
    }

    func add(_ profile: ProxyProfile) async {
        await MainActor.run { profiles.append(profile) }
        await persist()
    }

    func update(_ profile: ProxyProfile) async {
        await MainActor.run {
            if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[idx] = profile
            }
        }
        await persist()
    }

    func delete(id: UUID) async {
        await MainActor.run {
            profiles.removeAll { $0.id == id }
            if activeProfileID == id { activeProfileID = nil }
        }
        await persist()
    }

    func setActive(id: UUID?) async {
        await MainActor.run { activeProfileID = id }
    }

    private func persist() async {
        let snapshot = profiles
        do { try await store.save(snapshot) }
        catch { print("[ProfileManager] save error: \(error)") }
    }
}
