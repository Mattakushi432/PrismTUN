import Foundation
import Observation

@Observable
@MainActor
final class VPNManager {
    private(set) var isConnected: Bool = false
    private(set) var connectionMode: ConnectionMode = .systemProxy
    private(set) var status: ConnectionStatus = .disconnected
    private(set) var stats: TrafficStats = .zero
    private(set) var errorMessage: String?

    let profileManager: ProfileManager
    private let singBox   = SingBoxManager()
    private let sysProxy  = SystemProxyManager()
    private var statsTask: Task<Void, Never>?

    init(profileManager: ProfileManager) {
        self.profileManager = profileManager
    }

    func connect(mode: ConnectionMode = .systemProxy, rules: [RoutingRule] = []) async {
        guard let profile = profileManager.activeProfile else {
            errorMessage = "No active profile selected"
            return
        }
        status = .connecting
        errorMessage = nil

        do {
            try await singBox.start(profile: profile, mode: mode, rules: rules)
            if mode == .systemProxy || mode == .global {
                try await sysProxy.enable()
            }
            connectionMode = mode
            isConnected    = true
            status         = .connected
            startStatsPolling()
        } catch {
            status       = .failed
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        statsTask?.cancel()
        statsTask = nil

        do {
            try await sysProxy.disable()
            try await singBox.stop()
        } catch {
            print("[VPNManager] disconnect error: \(error)")
        }

        isConnected = false
        status      = .disconnected
        stats       = .zero
    }

    func setMode(_ mode: ConnectionMode) async {
        if isConnected {
            await disconnect()
            await connect(mode: mode)
        } else {
            connectionMode = mode
        }
    }

    // MARK: - Stats Polling

    private func startStatsPolling() {
        statsTask = Task {
            var prev: TrafficPayload? = nil
            while !Task.isCancelled {
                if let payload = await singBox.fetchTraffic() {
                    let upload   = payload.up
                    let download = payload.down
                    let upSpeed   = prev.map { max(0, upload   - $0.up)   } ?? 0
                    let downSpeed = prev.map { max(0, download - $0.down) } ?? 0
                    stats = TrafficStats(
                        uploadBytes:   upload,
                        downloadBytes: download,
                        uploadSpeed:   upSpeed,
                        downloadSpeed: downSpeed
                    )
                    prev = payload
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

enum ConnectionStatus: Sendable {
    case disconnected
    case connecting
    case connected
    case failed

    var displayName: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting:   "Connecting…"
        case .connected:    "Connected"
        case .failed:       "Failed"
        }
    }
}
