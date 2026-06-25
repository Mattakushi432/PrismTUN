import Foundation

struct ProxyProfile: Identifiable, Codable, Sendable, Hashable {
    var id: UUID
    var name: String
    var `protocol`: ProxyProtocol
    var server: String
    var port: Int
    var createdAt: Date

    // Shared credentials
    var password: String
    var username: String

    // Shadowsocks
    var ssMethod: ShadowsocksMethod

    // VMess / VLESS
    var uuid: String
    var alterId: Int
    var vmessNetwork: VMessNetwork
    var wsPath: String

    // Common TLS
    var tls: Bool
    var sni: String
    var skipCertVerify: Bool
    var fingerprint: String

    // Trojan
    var trojanPassword: String

    init(
        id: UUID = UUID(),
        name: String = "",
        protocol: ProxyProtocol = .shadowsocks,
        server: String = "",
        port: Int = 443,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.protocol = `protocol`
        self.server = server
        self.port = port
        self.createdAt = createdAt
        self.password = ""
        self.username = ""
        self.ssMethod = .aes256gcm
        self.uuid = UUID().uuidString
        self.alterId = 0
        self.vmessNetwork = .tcp
        self.wsPath = "/"
        self.tls = true
        self.sni = ""
        self.skipCertVerify = false
        self.fingerprint = ""
        self.trojanPassword = ""
    }
}

enum ShadowsocksMethod: String, Codable, CaseIterable, Sendable {
    case aes128gcm  = "aes-128-gcm"
    case aes256gcm  = "aes-256-gcm"
    case chacha20   = "chacha20-ietf-poly1305"
    case xchacha20  = "xchacha20-ietf-poly1305"
    case none2022   = "2022-blake3-aes-256-gcm"

    var displayName: String { rawValue }
}

enum VMessNetwork: String, Codable, CaseIterable, Sendable {
    case tcp = "tcp"
    case ws  = "ws"
    case h2  = "h2"

    var displayName: String {
        switch self {
        case .tcp: "TCP"
        case .ws:  "WebSocket"
        case .h2:  "HTTP/2"
        }
    }
}

// MARK: - URI Parsing

extension ProxyProfile {
    static func parse(uri: String) -> ProxyProfile? {
        if uri.hasPrefix("ss://")     { return parseShadowsocks(uri) }
        if uri.hasPrefix("vmess://")  { return parseVMess(uri) }
        if uri.hasPrefix("vless://")  { return parseVLESS(uri) }
        if uri.hasPrefix("trojan://") { return parseTrojan(uri) }
        return nil
    }

    private static func parseShadowsocks(_ uri: String) -> ProxyProfile? {
        guard let components = URLComponents(string: uri),
              let host = components.host, let port = components.port
        else { return nil }

        var profile = ProxyProfile(protocol: .shadowsocks, server: host, port: port)
        profile.name = components.fragment.flatMap { $0.removingPercentEncoding } ?? host

        if let userInfo = components.user,
           let decoded = base64Decode(userInfo) {
            let parts = decoded.components(separatedBy: ":")
            if parts.count >= 2 {
                profile.ssMethod = ShadowsocksMethod(rawValue: parts[0]) ?? .aes256gcm
                profile.password = parts.dropFirst().joined(separator: ":")
                return profile
            }
        }
        return profile
    }

    private static func parseVMess(_ uri: String) -> ProxyProfile? {
        let b64 = uri.replacingOccurrences(of: "vmess://", with: "")
        guard let decoded = base64Decode(b64),
              let data = decoded.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let host = json["add"] as? String ?? ""
        let port = Int(json["port"] as? String ?? "443") ?? (json["port"] as? Int ?? 443)

        var profile = ProxyProfile(protocol: .vmess, server: host, port: port)
        profile.name   = json["ps"]   as? String ?? host
        profile.uuid   = json["id"]   as? String ?? ""
        profile.alterId = Int(json["aid"] as? String ?? "0") ?? (json["aid"] as? Int ?? 0)
        profile.vmessNetwork = VMessNetwork(rawValue: json["net"] as? String ?? "tcp") ?? .tcp
        profile.wsPath = json["path"] as? String ?? "/"
        profile.tls    = (json["tls"] as? String) == "tls"
        profile.sni    = json["sni"]  as? String ?? ""
        return profile
    }

    private static func parseVLESS(_ uri: String) -> ProxyProfile? {
        guard let components = URLComponents(string: uri),
              let host = components.host, let port = components.port
        else { return nil }

        var profile = ProxyProfile(protocol: .vless, server: host, port: port)
        profile.name = components.fragment?.removingPercentEncoding ?? host
        profile.uuid = components.user ?? ""

        let params = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
        profile.tls         = params["security"] == "tls" || params["security"] == "reality"
        profile.sni         = params["sni"] ?? params["serverName"] ?? ""
        profile.fingerprint = params["fp"] ?? ""
        profile.wsPath      = params["path"] ?? "/"
        profile.vmessNetwork = VMessNetwork(rawValue: params["type"] ?? "tcp") ?? .tcp
        return profile
    }

    private static func parseTrojan(_ uri: String) -> ProxyProfile? {
        guard let components = URLComponents(string: uri),
              let host = components.host, let port = components.port
        else { return nil }

        var profile = ProxyProfile(protocol: .trojan, server: host, port: port)
        profile.name            = components.fragment?.removingPercentEncoding ?? host
        profile.trojanPassword  = components.user ?? ""
        profile.tls             = true

        let params = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
        profile.sni            = params["sni"] ?? params["peer"] ?? ""
        profile.skipCertVerify = params["allowInsecure"] == "1"
        return profile
    }

    private static func base64Decode(_ string: String) -> String? {
        var padded = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded += "=" }
        guard let data = Data(base64Encoded: padded) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
