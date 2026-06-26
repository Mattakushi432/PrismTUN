import Foundation
import Observation

@Observable
@MainActor
final class RoutingViewModel {
    private(set) var rules: [RoutingRule] = []
    var errorMessage: String?

    private let store = RoutingStore()
    private let vpnManager: VPNManager

    init(vpnManager: VPNManager) {
        self.vpnManager = vpnManager
    }

    func load() async {
        do {
            rules = try await store.load()
            vpnManager.updateRoutingRules(rules)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addRule(_ rule: RoutingRule) async {
        rules.append(rule)
        await persist()
    }

    func updateRule(_ rule: RoutingRule) async {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[idx] = rule
        await persist()
    }

    func deleteRules(at offsets: IndexSet) async {
        rules.remove(atOffsets: offsets)
        await persist()
    }

    func moveRules(from source: IndexSet, to destination: Int) async {
        rules.move(fromOffsets: source, toOffset: destination)
        await persist()
    }

    func toggleRule(_ rule: RoutingRule) async {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[idx].isEnabled.toggle()
        await persist()
    }

    func addPreset(_ preset: [RoutingRule]) async {
        rules.append(contentsOf: preset)
        await persist()
    }

    func clearError() {
        errorMessage = nil
    }

    private func persist() async {
        do {
            try await store.save(rules)
            vpnManager.updateRoutingRules(rules)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
