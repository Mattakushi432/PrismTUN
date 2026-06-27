import Foundation
import Observation

@Observable
@MainActor
final class SubscriptionManager {
    private(set) var subscriptions: [Subscription] = []
    private(set) var lastError: Error?
    private(set) var isUpdating: Bool = false

    private let store = SubscriptionStore()
    private let profileManager: ProfileManager
    private var autoUpdateTasks: [UUID: Task<Void, Never>] = [:]

    init(profileManager: ProfileManager) {
        self.profileManager = profileManager
    }

    // MARK: - Lifecycle

    func load() async {
        do {
            subscriptions = try await store.load()
            lastError = nil
            restartAllAutoUpdates()
        } catch {
            lastError = error
        }
    }

    // MARK: - CRUD

    func add(_ subscription: Subscription) async {
        subscriptions.append(subscription)
        await persist()
        scheduleAutoUpdate(for: subscription)
    }

    func remove(id: UUID) async {
        guard let sub = subscriptions.first(where: { $0.id == id }) else { return }
        let oldIDs = Set(sub.profileIDs)
        subscriptions.removeAll { $0.id == id }
        cancelAutoUpdate(id: id)
        await persist()
        await profileManager.bulkDelete(ids: oldIDs)
    }

    // MARK: - Fetch & update

    func update(id: UUID) async {
        isUpdating = true
        await performUpdate(id: id)
        isUpdating = false
    }

    func updateAll() async {
        isUpdating = true
        for sub in subscriptions {
            await performUpdate(id: sub.id)
        }
        isUpdating = false
    }

    // MARK: - Private implementation

    private func performUpdate(id: UUID) async {
        guard let idx = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        var sub = subscriptions[idx]
        do {
            let profiles = try await fetchProfiles(for: sub)
            let oldIDs   = Set(sub.profileIDs)
            await profileManager.bulkDelete(ids: oldIDs)
            let tagged = profiles.map { profile -> ProxyProfile in
                var p = profile
                p.subscriptionID = sub.id
                return p
            }
            let newIDs = tagged.map(\.id)
            await profileManager.bulkAdd(tagged)
            sub.profileIDs = newIDs
            sub.lastUpdated = Date()
            subscriptions[idx] = sub
            await persist()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    private func fetchProfiles(for subscription: Subscription) async throws -> [ProxyProfile] {
        var request = URLRequest(url: subscription.url, timeoutInterval: 30)
        let ua = subscription.userAgent.isEmpty ? "clash.meta" : subscription.userAgent
        request.setValue(ua, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        return parse(data: data, subscription: subscription)
    }

    private func parse(data: Data, subscription: Subscription) -> [ProxyProfile] {
        SubscriptionParser.parse(
            data: data,
            includeRegex: subscription.includeRegex,
            excludeRegex: subscription.excludeRegex
        )
    }

    // MARK: - Auto-update scheduling

    private func restartAllAutoUpdates() {
        for (id, task) in autoUpdateTasks { task.cancel(); autoUpdateTasks.removeValue(forKey: id) }
        for sub in subscriptions { scheduleAutoUpdate(for: sub) }
    }

    private func scheduleAutoUpdate(for subscription: Subscription) {
        guard subscription.updateInterval > 0 else { return }
        let id       = subscription.id
        let interval = subscription.updateInterval
        autoUpdateTasks[id]?.cancel()
        autoUpdateTasks[id] = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.update(id: id)
            }
        }
    }

    private func cancelAutoUpdate(id: UUID) {
        autoUpdateTasks[id]?.cancel()
        autoUpdateTasks.removeValue(forKey: id)
    }

    private func persist() async {
        do {
            try await store.save(subscriptions)
        } catch {
            lastError = error
        }
    }
}
