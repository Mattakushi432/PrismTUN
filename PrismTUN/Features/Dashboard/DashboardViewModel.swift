import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    var speedHistory: [(upload: Double, download: Double)] = Array(repeating: (0, 0), count: 60)

    private let vpnManager: VPNManager
    private let profileManager: ProfileManager
    private var updateTask: Task<Void, Never>?

    init(vpnManager: VPNManager, profileManager: ProfileManager) {
        self.vpnManager = vpnManager
        self.profileManager = profileManager
    }

    var stats: TrafficStats { vpnManager.stats }
    var isConnected: Bool   { vpnManager.isConnected }
    var status: ConnectionStatus { vpnManager.status }
    var activeProfileName: String { profileManager.activeProfile?.name ?? "None" }
    var errorMessage: String?     { vpnManager.errorMessage }
    var connectionMode: ConnectionMode { vpnManager.connectionMode }

    var profiles: [ProxyProfile] { profileManager.profiles }
    var hasProfiles: Bool        { !profileManager.profiles.isEmpty }
    var activeProfileID: UUID?   { profileManager.activeProfileID }

    func setActiveProfile(id: UUID) async { await profileManager.setActive(id: id) }
    func connect() async { await vpnManager.connect() }
    func disconnect() async { await vpnManager.disconnect() }
    func setMode(_ mode: ConnectionMode) async { await vpnManager.setMode(mode) }

    func startUpdating() {
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let up   = Double(self.stats.uploadSpeed)
                let down = Double(self.stats.downloadSpeed)
                self.speedHistory.removeFirst()
                self.speedHistory.append((up, down))
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopUpdating() { updateTask?.cancel() }
}
