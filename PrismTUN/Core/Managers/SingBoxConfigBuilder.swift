import Foundation

/// Generates a sing-box JSON configuration from a proxy profile.
enum SingBoxConfigBuilder {
    static let mixedPort: Int = 2080
    static let apiPort: Int   = 9090

    static func build(
        profile: ProxyProfile,
        mode: ConnectionMode,
        rules: [RoutingRule],
        dnsConfig: DNSConfig = .default,
        apiSecret: String
    ) -> [String: Any] {
        let config: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true
            ],
            "experimental": [
                "clash_api": [
                    "external_controller":         "127.0.0.1:\(apiPort)",
                    "secret":                      apiSecret,
                    "access_control_allow_origin": ["http://127.0.0.1:\(apiPort)"]
                ]
            ],
            "dns": buildDNS(config: dnsConfig),
            "inbounds": buildInbounds(mode: mode),
            "outbounds": buildOutbounds(profile: profile, mode: mode),
            "route": buildRoute(mode: mode, rules: rules)
        ]
        return config
    }

    // MARK: - Private

    private static func buildDNS(config: DNSConfig) -> [String: Any] {
        var servers: [[String: Any]] = config.servers.map { server in
            var entry: [String: Any] = ["tag": server.tag, "address": server.address]
            if !server.detour.isEmpty { entry["detour"] = server.detour }
            return entry
        }

        // Inject fakeip server entry when FakeIP is enabled and not already declared
        if config.fakeIP.isEnabled && !config.servers.contains(where: { $0.address == "fakeip" }) {
            servers.append(["tag": "fakeip", "address": "fakeip"])
        }

        let dnsRules: [[String: Any]] = config.rules.compactMap { rule -> [String: Any]? in
            guard rule.isEnabled else { return nil }
            switch rule.ruleType {
            case .geosite: return ["geosite": rule.value,   "server": rule.serverTag]
            case .geoip:   return ["geoip":   rule.value,   "server": rule.serverTag]
            case .domain:  return ["domain":  [rule.value], "server": rule.serverTag]
            case .ipCidr:  return ["ip_cidr": [rule.value], "server": rule.serverTag]
            }
        }

        var dns: [String: Any] = [
            "servers":  servers,
            "rules":    dnsRules,
            "final":    config.finalServer,
            "strategy": config.strategy.rawValue
        ]

        if config.fakeIP.isEnabled {
            dns["fakeip"] = [
                "enabled":     true,
                "inet4_range": config.fakeIP.inet4Range,
                "inet6_range": config.fakeIP.inet6Range
            ]
        }

        return dns
    }

    private static func buildInbounds(mode: ConnectionMode) -> [[String: Any]] {
        var inbounds: [[String: Any]] = []

        if mode == .tun {
            // TUN interface for full-traffic capture (auto_route handles system routing)
            inbounds.append([
                "type": "tun",
                "tag": "tun-in",
                "interface_name": "utun123",
                "inet4_address": "172.19.0.1/30",
                "auto_route": true,
                "strict_route": true,
                "sniff": true
            ])
        }

        inbounds.append([
            "type": "mixed",
            "tag": "mixed-in",
            "listen": "127.0.0.1",
            "listen_port": mixedPort,
            "sniff": true
        ])

        return inbounds
    }

    private static func buildOutbounds(profile: ProxyProfile, mode: ConnectionMode) -> [[String: Any]] {
        var outbounds: [[String: Any]] = []

        let proxyOutbound = buildProxyOutbound(profile: profile)
        outbounds.append(proxyOutbound)
        outbounds.append(["type": "direct", "tag": "direct"])
        outbounds.append(["type": "block",  "tag": "block"])
        outbounds.append(["type": "dns",    "tag": "dns-out"])

        let finalTag: String
        switch mode {
        case .systemProxy: finalTag = "proxy"
        case .global:      finalTag = "proxy"
        case .tun:         finalTag = "proxy"
        case .direct:      finalTag = "direct"
        }

        outbounds.insert([
            "type": "selector",
            "tag": "select",
            "outbounds": ["proxy", "direct"],
            "default": finalTag
        ], at: 0)

        return outbounds
    }

    static func buildProxyOutbound(profile: ProxyProfile) -> [String: Any] {
        var out: [String: Any] = [
            "tag": "proxy",
            "server": profile.server,
            "server_port": profile.port
        ]

        switch profile.protocol {
        case .shadowsocks:
            out["type"] = "shadowsocks"
            out["method"] = profile.ssMethod.rawValue
            out["password"] = profile.password

        case .vmess:
            out["type"] = "vmess"
            out["uuid"] = profile.uuid
            out["alter_id"] = profile.alterId
            if profile.vmessNetwork == .ws {
                out["transport"] = [
                    "type": "ws",
                    "path": profile.wsPath
                ]
            }
            if profile.tls {
                out["tls"] = buildTLS(profile: profile)
            }

        case .vless:
            out["type"] = "vless"
            out["uuid"] = profile.uuid
            if profile.vmessNetwork == .ws {
                out["transport"] = [
                    "type": "ws",
                    "path": profile.wsPath
                ]
            }
            if profile.tls {
                out["tls"] = buildTLS(profile: profile)
            }

        case .trojan:
            out["type"] = "trojan"
            out["password"] = profile.trojanPassword
            out["tls"] = buildTLS(profile: profile)

        case .socks5:
            out["type"] = "socks"
            out["version"] = "5"
            if !profile.username.isEmpty {
                out["username"] = profile.username
                out["password"] = profile.password
            }

        case .http:
            out["type"] = "http"
            if !profile.username.isEmpty {
                out["username"] = profile.username
                out["password"] = profile.password
            }

        case .hysteria2:
            out["type"] = "hysteria2"
            out["password"] = profile.password
            if profile.hysteria2UpMbps > 0   { out["up_mbps"]   = profile.hysteria2UpMbps }
            if profile.hysteria2DownMbps > 0 { out["down_mbps"] = profile.hysteria2DownMbps }
            out["tls"] = buildTLS(profile: profile)

        case .tuic:
            out["type"] = "tuic"
            out["uuid"] = profile.uuid
            out["password"] = profile.password
            out["congestion_control"] = profile.tuicCongestionControl
            out["udp_relay_mode"] = profile.tuicUdpRelayMode
            out["tls"] = buildTLS(profile: profile)

        case .wireguard:
            out["type"] = "wireguard"
            out["private_key"] = profile.wgPrivateKey
            out["peer_public_key"] = profile.wgPeerPublicKey
            if !profile.wgPresharedKey.isEmpty { out["pre_shared_key"] = profile.wgPresharedKey }
            if !profile.wgLocalAddress.isEmpty {
                out["local_address"] = profile.wgLocalAddress
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
            out["mtu"] = profile.wgMTU
        }

        return out
    }

    private static func buildTLS(profile: ProxyProfile) -> [String: Any] {
        var tls: [String: Any] = ["enabled": true]
        if !profile.sni.isEmpty         { tls["server_name"] = profile.sni }
        if profile.skipCertVerify       { tls["insecure"] = true }
        if !profile.fingerprint.isEmpty { tls["utls"] = ["enabled": true, "fingerprint": profile.fingerprint] }
        return tls
    }

    private static func buildRoute(mode: ConnectionMode, rules: [RoutingRule]) -> [String: Any] {
        var routeRules: [[String: Any]] = [
            ["protocol": "dns", "outbound": "dns-out"]
        ]

        // User-defined rules
        for rule in rules where rule.isEnabled {
            var r: [String: Any] = ["outbound": rule.outbound.rawValue]
            switch rule.type {
            case .domain:        r["domain"]        = [rule.value]
            case .domainSuffix:  r["domain_suffix"] = [rule.value]
            case .domainKeyword: r["domain_keyword"] = [rule.value]
            case .domainRegex:   r["domain_regex"]  = [rule.value]
            case .ipCidr:        r["ip_cidr"]        = [rule.value]
            case .port:          r["port"]            = rule.value
            case .portRange:     r["port_range"]      = rule.value
            case .processName:   r["process_name"]  = [rule.value]
            case .processPath:   r["process_path"]  = [rule.value]
            case .network:       r["network"]         = rule.value
            case .geosite:       r["geosite"]         = rule.value
            case .geoip:         r["geoip"]           = rule.value
            case .sourceIpCidr:  r["source_ip_cidr"] = [rule.value]
            case .user:          r["user"]            = [rule.value]
            case .clashMode:     r["clash_mode"]      = rule.value
            }
            routeRules.append(r)
        }

        // Built-in block / bypass rules
        routeRules.append(contentsOf: [
            ["geosite": "category-ads-all", "outbound": "block"],
            ["geosite": "cn", "outbound": "direct"],
            ["geoip": "cn",   "outbound": "direct"],
            ["geoip": "private", "outbound": "direct"]
        ])

        let finalOutbound: String
        switch mode {
        case .systemProxy, .global, .tun: finalOutbound = "proxy"
        case .direct:                     finalOutbound = "direct"
        }

        return [
            "rules": routeRules,
            "final": finalOutbound,
            "auto_detect_interface": true
        ]
    }
}
