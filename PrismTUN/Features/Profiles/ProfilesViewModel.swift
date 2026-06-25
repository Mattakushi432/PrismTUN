import Foundation
import Observation

@Observable
@MainActor
final class ProfilesViewModel {
    let profileManager: ProfileManager
    var showAddSheet: Bool = false
    var editingProfile: ProxyProfile? = nil
    var pendingDeleteID: UUID? = nil

    init(profileManager: ProfileManager) {
        self.profileManager = profileManager
    }

    var profiles: [ProxyProfile] { profileManager.profiles }
    var activeProfileID: UUID?   { profileManager.activeProfileID }

    func add(_ profile: ProxyProfile) async {
        await profileManager.add(profile)
    }

    func update(_ profile: ProxyProfile) async {
        await profileManager.update(profile)
    }

    func delete(id: UUID) async {
        await profileManager.delete(id: id)
    }

    func setActive(id: UUID) async {
        await profileManager.setActive(id: id)
    }

    func importFromURI(_ uri: String) async {
        guard let profile = ProxyProfile.parse(uri: uri) else { return }
        await profileManager.add(profile)
    }
}
