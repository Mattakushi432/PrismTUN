@preconcurrency import NetworkExtension
import Foundation

/// NEPacketTunnelProvider implementation.
///
/// Receives a TunnelMessage via startTunnel(options:), launches sing-box with a TUN inbound,
/// and configures NEPacketTunnelNetworkSettings so the OS shows the VPN as connected.
/// sing-box owns routing via auto_route + strict_route; this provider acts as a lifecycle manager.
///
/// NOTE: Full TUN mode requires Developer ID signing and a provisioning profile with the
/// com.apple.developer.networking.networkextension (packet-tunnel-provider) capability.
/// Ad-hoc builds can run the code but the OS will refuse to activate the VPN configuration.
// @unchecked Sendable: mutable state is guarded by nonisolated(unsafe); NE provider is a singleton.
final class PacketTunnelProvider: NEPacketTunnelProvider, @unchecked Sendable {

    // nonisolated(unsafe): provider is a singleton; startTunnel and stopTunnel are not concurrent.
    nonisolated(unsafe) private var singBoxProcess: Process?
    nonisolated(unsafe) private var configURL: URL?
    // Stored so Task can capture self (Sendable) instead of the non-@Sendable callback directly.
    nonisolated(unsafe) private var pendingStart: ((Error?) -> Void)?

    // MARK: - Lifecycle

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let msgData = options?[TunnelMessageKey] as? Data,
              let message = try? JSONDecoder().decode(TunnelMessage.self, from: msgData)
        else {
            completionHandler(providerError("Missing or malformed tunnel configuration"))
            return
        }

        pendingStart = completionHandler
        Task {
            do {
                try await launchSingBox(message: message)
                let settings = makeTunnelNetworkSettings()
                try await applyNetworkSettings(settings)
                pendingStart?(nil)
            } catch {
                pendingStart?(error)
            }
            pendingStart = nil
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        singBoxProcess?.terminate()
        singBoxProcess = nil
        if let url = configURL {
            try? FileManager.default.removeItem(at: url)
            configURL = nil
        }
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(nil)
    }

    // MARK: - sing-box lifecycle

    private func launchSingBox(message: TunnelMessage) async throws {
        let binaryURL = try findBinary()
        await clearQuarantine(url: binaryURL)

        let config = SingBoxConfigBuilder.build(
            profile: message.profileWithCredentials,
            mode: .tun,
            rules: message.rules,
            dnsConfig: message.dnsConfig,
            apiSecret: message.apiSecret
        )

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("prismtun-ext-\(UUID().uuidString).json")
        let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try data.write(to: tmp, options: .atomic)
        // Restrict to owner-read/write — proxy credentials are embedded
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmp.path)
        configURL = tmp

        let task = Process()
        task.executableURL  = binaryURL
        task.arguments      = ["run", "-c", tmp.path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError  = FileHandle.nullDevice
        try task.run()
        singBoxProcess = task

        try await waitForAPI(apiSecret: message.apiSecret)
    }

    // MARK: - Network settings

    private func makeTunnelNetworkSettings() -> NEPacketTunnelNetworkSettings {
        // sing-box TUN inbound uses inet4_address 172.19.0.1/30 with auto_route.
        // We declare a matching interface address here so the OS considers the VPN active.
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        let ipv4 = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        settings.mtu = 1500
        return settings
    }

    private func applyNetworkSettings(_ settings: NEPacketTunnelNetworkSettings) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            setTunnelNetworkSettings(settings) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
    }

    // MARK: - Helpers

    /// Locates the sing-box binary: first in this bundle, then in the host app bundle.
    private func findBinary() throws -> URL {
        if let url = Bundle.main.url(forResource: "sing-box", withExtension: nil) {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            return url
        }
        // Extension bundle: .../PrismTUN.app/Contents/PlugIns/PacketTunnelProvider.appex
        // Navigate up two levels to reach .../PrismTUN.app/Contents
        let appContents = Bundle.main.bundleURL
            .deletingLastPathComponent()  // PlugIns
            .deletingLastPathComponent()  // Contents
            .appendingPathComponent("Contents")
        let candidate = appContents.appendingPathComponent("Resources/sing-box")
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw ProviderError.binaryNotFound
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: candidate.path)
        return candidate
    }

    private func clearQuarantine(url: URL) async {
        let task = Process()
        task.executableURL  = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments      = ["-d", "com.apple.quarantine", url.path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError  = FileHandle.nullDevice
        do { try task.run() } catch { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            task.terminationHandler = { _ in cont.resume() }
        }
    }

    private func waitForAPI(apiSecret: String, timeout: TimeInterval = 8) async throws {
        let url = URL(string: "http://127.0.0.1:\(SingBoxConfigBuilder.apiPort)/version")!
        var req = URLRequest(url: url)
        if !apiSecret.isEmpty {
            req.setValue("Bearer \(apiSecret)", forHTTPHeaderField: "Authorization")
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (try? await URLSession.shared.data(for: req)) != nil { return }
            try await Task.sleep(for: .milliseconds(300))
        }
        throw ProviderError.apiTimeout
    }

    private func providerError(_ description: String) -> NSError {
        NSError(
            domain: NEVPNErrorDomain,
            code: NEVPNError.Code.configurationInvalid.rawValue,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}

// MARK: - Error types

enum ProviderError: LocalizedError {
    case binaryNotFound
    case apiTimeout

    var errorDescription: String? {
        switch self {
        case .binaryNotFound: "sing-box binary not found in app bundle"
        case .apiTimeout:     "sing-box API did not become available within the timeout period"
        }
    }
}
