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

    /// Parses one or more newline-separated proxy URIs and adds them.
    /// Returns the number of successfully imported profiles.
    @discardableResult
    func importFromURI(_ text: String) async -> Int {
        let profiles = ProxyProfile.batchParse(text: text)
        for profile in profiles {
            await profileManager.add(profile)
        }
        return profiles.count
    }
}
