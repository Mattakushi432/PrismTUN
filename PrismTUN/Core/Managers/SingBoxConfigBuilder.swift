import Foundation

/// Generates a sing-box JSON configuration from a proxy profile.
enum SingBoxConfigBuilder {
    static let mixedPort: Int = 2080
    static let apiPort: Int   = 9090

    static func build(profile: ProxyProfile, mode: ConnectionMode, rules: [RoutingRule]) -> [String: Any] {
        var config: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true
            ],
            "experimental": [
                "clash_api": [
                    "external_controller": "127.0.0.1:\(apiPort)",
                    "access_control_allow_origin": ["*"]
                ]
            ],
            "dns": buildDNS(),
            "inbounds": buildInbounds(),
            "outbounds": buildOutbounds(profile: profile, mode: mode),
            "route": buildRoute(mode: mode, rules: rules)
        ]
        return config
    }

    // MARK: - Private

    private static func buildDNS() -> [String: Any] {
        [
            "servers": [
                ["tag": "google", "address": "8.8.8.8"],
                ["tag": "local",  "address": "local", "detour": "direct"]
            ],
            "rules": [
                ["geosite": "cn", "server": "local"]
            ],
            "final": "google"
        ]
    }

    private static func buildInbounds() -> [[String: Any]] {
        [[
            "type": "mixed",
            "tag": "mixed-in",
            "listen": "127.0.0.1",
            "listen_port": mixedPort,
            "sniff": true
        ]]
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

    private static func buildProxyOutbound(profile: ProxyProfile) -> [String: Any] {
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
            case .domain:      r["domain"] = [rule.value]
            case .domainSuffix: r["domain_suffix"] = [rule.value]
            case .ipCidr:      r["ip_cidr"] = [rule.value]
            case .geosite:     r["geosite"] = rule.value
            case .geoip:       r["geoip"] = rule.value
            case .processName: r["process_name"] = [rule.value]
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
        case .systemProxy, .global: finalOutbound = "proxy"
        case .direct:               finalOutbound = "direct"
        }

        return [
            "rules": routeRules,
            "final": finalOutbound,
            "auto_detect_interface": true
        ]
    }
}
