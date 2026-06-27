import Foundation
import Observation

@Observable
@MainActor
final class ConnectionsViewModel {
    private let vpnManager: VPNManager
    var searchText: String = ""

    init(vpnManager: VPNManager) {
        self.vpnManager = vpnManager
    }

    var isConnected: Bool { vpnManager.isConnected }

    var filtered: [ActiveConnection] {
        let q = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        let all = vpnManager.connectionStore.connections
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.displayHost.lowercased().contains(q) ||
            $0.displayProcess.lowercased().contains(q)
        }
    }

    func closeConnection(id: String) {
        Task { await vpnManager.closeConnection(id: id) }
    }

    func closeAll() {
        Task { await vpnManager.closeAllConnections() }
    }
}
