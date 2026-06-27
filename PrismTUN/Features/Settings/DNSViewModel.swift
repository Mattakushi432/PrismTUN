import Foundation
import Observation

@Observable
@MainActor
final class DNSViewModel {
    private(set) var config: DNSConfig = .default
    var errorMessage: String?

    private let store = DNSStore()
    private let vpnManager: VPNManager

    init(vpnManager: VPNManager) {
        self.vpnManager = vpnManager
    }

    func load() async {
        do {
            config = try await store.load()
            vpnManager.updateDNSConfig(config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addServer(_ server: DNSServer) async {
        config.servers.append(server)
        await persist()
    }

    func updateServer(_ server: DNSServer) async {
        guard let idx = config.servers.firstIndex(where: { $0.id == server.id }) else { return }
        config.servers[idx] = server
        await persist()
    }

    func deleteServers(at offsets: IndexSet) async {
        config.servers.remove(atOffsets: offsets)
        await persist()
    }

    func addRule(_ rule: DNSRule) async {
        config.rules.append(rule)
        await persist()
    }

    func updateRule(_ rule: DNSRule) async {
        guard let idx = config.rules.firstIndex(where: { $0.id == rule.id }) else { return }
        config.rules[idx] = rule
        await persist()
    }

    func deleteRules(at offsets: IndexSet) async {
        config.rules.remove(atOffsets: offsets)
        await persist()
    }

    func toggleRule(_ rule: DNSRule) async {
        guard let idx = config.rules.firstIndex(where: { $0.id == rule.id }) else { return }
        config.rules[idx].isEnabled.toggle()
        await persist()
    }

    func updateStrategy(_ strategy: DNSStrategy) async {
        config.strategy = strategy
        await persist()
    }

    func updateFinalServer(_ tag: String) async {
        config.finalServer = tag
        await persist()
    }

    func updateFakeIP(_ fakeIP: FakeIPConfig) async {
        config.fakeIP = fakeIP
        await persist()
    }

    func clearError() {
        errorMessage = nil
    }

    private func persist() async {
        do {
            try await store.save(config)
            vpnManager.updateDNSConfig(config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
