import Foundation
import Observation

@Observable
@MainActor
final class ProfilesViewModel {
    let profileManager: ProfileManager
    var showAddSheet: Bool = false
    var editingProfile: ProxyProfile? = nil
    var pendingDeleteID: UUID? = nil

    // MARK: - Latency testing state

    var isTesting: Bool = false
    var sortByLatency: Bool = false
    private var testTask: Task<Void, Never>?

    init(profileManager: ProfileManager) {
        self.profileManager = profileManager
    }

    var profiles: [ProxyProfile] { profileManager.profiles }
    var activeProfileID: UUID?   { profileManager.activeProfileID }

    // MARK: - Profile CRUD

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
        let parsed = ProxyProfile.batchParse(text: text)
        for profile in parsed {
            await profileManager.add(profile)
        }
        return parsed.count
    }

    // MARK: - Latency testing

    /// Starts a concurrent TCP-ping of all current profiles (concurrency = 5).
    /// Results stream back to `profileManager` in real time; disk write happens once at completion.
    func testAll() {
        guard !isTesting else { return }
        isTesting = true
        let snapshot = profiles
        testTask = Task { [weak self] in
            guard let self else { return }
            let stream = ServerTester.shared.batchTest(profiles: snapshot)
            for await (id, result) in stream {
                guard !Task.isCancelled else { break }
                switch result {
                case .success(let d):
                    profileManager.updateLatencyInMemory(id: id, latencyMs: d.milliseconds)
                case .failure:
                    profileManager.updateLatencyInMemory(id: id, latencyMs: nil)
                }
            }
            await profileManager.persistLatencies()
            self.isTesting = false
        }
    }

    /// Cancels an in-progress batch test immediately.
    func cancelTest() {
        testTask?.cancel()
        testTask = nil
        isTesting = false
    }

    // MARK: - Sorted helpers

    /// Returns `raw` sorted by ascending latency when `sortByLatency` is on.
    /// Tested profiles come before untested; among untested, original order is preserved.
    func sorted(_ raw: [ProxyProfile]) -> [ProxyProfile] {
        guard sortByLatency else { return raw }
        return raw.sorted {
            switch ($0.lastLatencyMs, $1.lastLatencyMs) {
            case let (a?, b?): return a < b
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return false
            }
        }
    }
}
