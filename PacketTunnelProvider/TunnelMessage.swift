import Foundation

/// Key used in the options dict passed to NETunnelProviderSession.startTunnel(options:).
let TunnelMessageKey = "config"

/// Serialized over the XPC channel from the main app to PacketTunnelProvider via
/// NETunnelProviderSession.startTunnel(options:).
///
/// ProxyProfile deliberately excludes sensitive credentials from its CodingKeys to prevent
/// plaintext JSON leakage; those fields are carried here explicitly so the provider has
/// everything needed to build the sing-box config.
struct TunnelMessage: Codable, Sendable {
    var profile: ProxyProfile
    var password: String        // ss/hysteria2/tuic auth
    var trojanPassword: String
    var wgPrivateKey: String
    var wgPresharedKey: String
    var rules: [RoutingRule]
    var dnsConfig: DNSConfig
    var apiSecret: String
}

extension TunnelMessage {
    /// Returns a copy of the profile with credentials reattached from the explicit fields.
    var profileWithCredentials: ProxyProfile {
        var p = profile
        p.password       = password
        p.trojanPassword = trojanPassword
        p.wgPrivateKey   = wgPrivateKey
        p.wgPresharedKey = wgPresharedKey
        return p
    }
}
