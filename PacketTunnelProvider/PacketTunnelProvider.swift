import NetworkExtension

/// Phase-2 TUN mode provider.
/// Requires entitlement: com.apple.developer.networking.networkextension.packet-tunnel
final class PacketTunnelProvider: NEPacketTunnelProvider {

    private var singBoxProcess: Process?

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        // 1. Read saved profile from shared UserDefaults (App Group)
        // 2. Generate sing-box config with tun inbound
        // 3. Launch sing-box binary from bundle
        // 4. Configure tunnel network settings
        completionHandler(nil)
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        singBoxProcess?.terminate()
        singBoxProcess = nil
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(nil)
    }

    // MARK: - Helpers

    private func makeTunnelNetworkSettings(tunAddress: String) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        let ipv4 = NEIPv4Settings(addresses: [tunAddress], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        settings.mtu = 1500
        return settings
    }
}
