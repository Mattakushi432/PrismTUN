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
    private(set) var routingRules: [RoutingRule] = []

    let profileManager: ProfileManager
    private let singBox  = SingBoxManager()
    private let sysProxy = SystemProxyManager()
    private var statsTask: Task<Void, Never>?

    init(profileManager: ProfileManager) {
        self.profileManager = profileManager
    }

    func updateRoutingRules(_ rules: [RoutingRule]) {
        routingRules = rules
    }

    func connect(mode: ConnectionMode = .systemProxy) async {
        guard let profile = profileManager.activeProfile else {
            errorMessage = "No active profile selected"
            return
        }
        status = .connecting
        errorMessage = nil

        let apiSecret = UUID().uuidString

        do {
            try await singBox.start(profile: profile, mode: mode, rules: routingRules, apiSecret: apiSecret)
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

        // Run both cleanup steps unconditionally and surface any failure to the UI
        var errors: [Error] = []
        do { try await sysProxy.disable() } catch { errors.append(error) }
        do { try await singBox.stop()     } catch { errors.append(error) }

        isConnected = false
        if errors.isEmpty {
            status       = .disconnected
            errorMessage = nil
        } else {
            status       = .failed
            errorMessage = errors.map(\.localizedDescription).joined(separator: "; ")
        }
        stats = .zero
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
            var prev: TrafficPayload?
            while !Task.isCancelled {
                if let payload = await singBox.fetchTraffic() {
                    let upload    = payload.up
                    let download  = payload.down
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
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch is CancellationError {
                    break
                } catch {}
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
