import Foundation

struct ProxyProfile: Identifiable, Codable, Sendable, Hashable {
    var id: UUID
    var name: String
    var `protocol`: ProxyProtocol
    var server: String
    var port: Int
    var createdAt: Date
    var subscriptionID: UUID?

    // MARK: - Latency testing (persisted; not sensitive)
    var lastLatencyMs: Int?
    var lastTestedAt: Date?

    // MARK: - Shared credentials (Keychain — NOT serialised to JSON)
    var password: String    // ss password · hysteria2 auth · tuic token
    var username: String

    // MARK: - Shadowsocks
    var ssMethod: ShadowsocksMethod

    // MARK: - VMess / VLESS
    var uuid: String
    var alterId: Int
    var vmessNetwork: VMessNetwork
    var wsPath: String

    // MARK: - Reality (VLESS)
    var realityPublicKey: String
    var realityShortId: String

    // MARK: - Common TLS
    var tls: Bool
    var sni: String
    var skipCertVerify: Bool
    var fingerprint: String

    // MARK: - Trojan (Keychain — NOT serialised to JSON)
    var trojanPassword: String

    // MARK: - Hysteria2
    var hysteria2UpMbps: Int
    var hysteria2DownMbps: Int

    // MARK: - TUIC
    var tuicCongestionControl: String
    var tuicUdpRelayMode: String

    // MARK: - WireGuard (private/preshared keys in Keychain — NOT serialised to JSON)
    var wgPeerPublicKey: String
    var wgLocalAddress: String
    var wgMTU: Int
    var wgPrivateKey: String
    var wgPresharedKey: String

    // password, trojanPassword, wgPrivateKey, wgPresharedKey are absent from CodingKeys
    // so they are never written to plaintext JSON. ProfileStore populates them from Keychain.
    private enum CodingKeys: String, CodingKey {
        case id, name, `protocol`, server, port, createdAt, subscriptionID
        case lastLatencyMs, lastTestedAt
        case username, ssMethod, uuid, alterId, vmessNetwork, wsPath
        case realityPublicKey, realityShortId
        case tls, sni, skipCertVerify, fingerprint
        case hysteria2UpMbps, hysteria2DownMbps
        case tuicCongestionControl, tuicUdpRelayMode
        case wgPeerPublicKey, wgLocalAddress, wgMTU
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(UUID.self,              forKey: .id)
        name         = try c.decode(String.self,            forKey: .name)
        `protocol`   = try c.decode(ProxyProtocol.self,     forKey: .protocol)
        server       = try c.decode(String.self,            forKey: .server)
        port         = try c.decode(Int.self,               forKey: .port)
        createdAt    = try c.decode(Date.self,              forKey: .createdAt)
        username     = try c.decode(String.self,            forKey: .username)
        ssMethod     = try c.decode(ShadowsocksMethod.self, forKey: .ssMethod)
        uuid         = try c.decode(String.self,            forKey: .uuid)
        alterId      = try c.decode(Int.self,               forKey: .alterId)
        vmessNetwork = try c.decode(VMessNetwork.self,      forKey: .vmessNetwork)
        wsPath       = try c.decode(String.self,            forKey: .wsPath)
        tls          = try c.decode(Bool.self,              forKey: .tls)
        sni          = try c.decode(String.self,            forKey: .sni)
        skipCertVerify = try c.decode(Bool.self,            forKey: .skipCertVerify)
        fingerprint  = try c.decode(String.self,            forKey: .fingerprint)
        // New fields — decodeIfPresent keeps existing profile JSON compatible
        realityPublicKey      = try c.decodeIfPresent(String.self, forKey: .realityPublicKey)      ?? ""
        realityShortId        = try c.decodeIfPresent(String.self, forKey: .realityShortId)        ?? ""
        hysteria2UpMbps       = try c.decodeIfPresent(Int.self,    forKey: .hysteria2UpMbps)       ?? 0
        hysteria2DownMbps     = try c.decodeIfPresent(Int.self,    forKey: .hysteria2DownMbps)     ?? 0
        tuicCongestionControl = try c.decodeIfPresent(String.self, forKey: .tuicCongestionControl) ?? "bbr"
        tuicUdpRelayMode      = try c.decodeIfPresent(String.self, forKey: .tuicUdpRelayMode)      ?? "native"
        wgPeerPublicKey       = try c.decodeIfPresent(String.self, forKey: .wgPeerPublicKey)       ?? ""
        wgLocalAddress        = try c.decodeIfPresent(String.self, forKey: .wgLocalAddress)        ?? ""
        wgMTU                 = try c.decodeIfPresent(Int.self,    forKey: .wgMTU)                 ?? 1420
        subscriptionID        = try c.decodeIfPresent(UUID.self,   forKey: .subscriptionID)
        lastLatencyMs         = try c.decodeIfPresent(Int.self,    forKey: .lastLatencyMs)
        lastTestedAt          = try c.decodeIfPresent(Date.self,   forKey: .lastTestedAt)
        // Populated from Keychain by ProfileStore after decoding
        password       = ""
        trojanPassword = ""
        wgPrivateKey   = ""
        wgPresharedKey = ""
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        protocol: ProxyProtocol = .shadowsocks,
        server: String = "",
        port: Int = 443,
        createdAt: Date = Date(),
        subscriptionID: UUID? = nil
    ) {
        self.id                    = id
        self.name                  = name
        self.protocol              = `protocol`
        self.server                = server
        self.port                  = port
        self.createdAt             = createdAt
        self.subscriptionID        = subscriptionID
        self.lastLatencyMs         = nil
        self.lastTestedAt          = nil
        self.password              = ""
        self.username              = ""
        self.ssMethod              = .aes256gcm
        self.uuid                  = UUID().uuidString
        self.alterId               = 0
        self.vmessNetwork          = .tcp
        self.wsPath                = "/"
        self.realityPublicKey      = ""
        self.realityShortId        = ""
        self.tls                   = true
        self.sni                   = ""
        self.skipCertVerify        = false
        self.fingerprint           = ""
        self.trojanPassword        = ""
        self.hysteria2UpMbps       = 0
        self.hysteria2DownMbps     = 0
        self.tuicCongestionControl = "bbr"
        self.tuicUdpRelayMode      = "native"
        self.wgPeerPublicKey       = ""
        self.wgLocalAddress        = ""
        self.wgMTU                 = 1420
        self.wgPrivateKey          = ""
        self.wgPresharedKey        = ""
    }
}

// MARK: - Supporting enums

enum ShadowsocksMethod: String, Codable, CaseIterable, Sendable {
    case aes128gcm = "aes-128-gcm"
    case aes256gcm = "aes-256-gcm"
    case chacha20  = "chacha20-ietf-poly1305"
    case xchacha20 = "xchacha20-ietf-poly1305"
    case none2022  = "2022-blake3-aes-256-gcm"

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
        let s = uri.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("ss://")        { return parseShadowsocks(s) }
        if s.hasPrefix("vmess://")     { return parseVMess(s) }
        if s.hasPrefix("vless://")     { return parseVLESS(s) }
        if s.hasPrefix("trojan://")    { return parseTrojan(s) }
        if s.hasPrefix("hysteria2://") { return parseHysteria2(s) }
        if s.hasPrefix("tuic://")      { return parseTUIC(s) }
        if s.hasPrefix("wireguard://") { return parseWireGuard(s) }
        return nil
    }

    /// Splits text on newlines and parses each non-empty line as a URI.
    static func batchParse(text: String) -> [ProxyProfile] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { parse(uri: $0) }
    }

    // MARK: Shadowsocks — SIP002: ss://BASE64(method:password)@host:port[#name]

    private static func parseShadowsocks(_ uri: String) -> ProxyProfile? {
        guard let comps = URLComponents(string: uri),
              let host = comps.host, let port = comps.port
        else { return nil }
        guard let userInfo = comps.user, let decoded = base64Decode(userInfo) else { return nil }
        let parts = decoded.components(separatedBy: ":")
        guard parts.count >= 2 else { return nil }
        var p = ProxyProfile(protocol: .shadowsocks, server: host, port: port)
        p.name     = comps.fragment?.removingPercentEncoding ?? host
        p.ssMethod = ShadowsocksMethod(rawValue: parts[0]) ?? .aes256gcm
        p.password = parts.dropFirst().joined(separator: ":")
        return p
    }

    // MARK: VMess — base64-JSON or query-params fallback

    private static func parseVMess(_ uri: String) -> ProxyProfile? {
        let b64 = uri.replacingOccurrences(of: "vmess://", with: "")
        if let decoded = base64Decode(b64),
           let data = decoded.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parseVMessFromJSON(json)
        }
        if let comps = URLComponents(string: uri), let host = comps.host, let port = comps.port {
            return parseVMessFromComponents(comps, host: host, port: port)
        }
        return nil
    }

    private static func parseVMessFromJSON(_ json: [String: Any]) -> ProxyProfile? {
        let host = json["add"] as? String ?? ""
        let port = Int(json["port"] as? String ?? "443") ?? (json["port"] as? Int ?? 443)
        guard !host.isEmpty else { return nil }
        var p = ProxyProfile(protocol: .vmess, server: host, port: port)
        p.name         = json["ps"]   as? String ?? host
        p.uuid         = json["id"]   as? String ?? ""
        p.alterId      = Int(json["aid"] as? String ?? "0") ?? (json["aid"] as? Int ?? 0)
        p.vmessNetwork = VMessNetwork(rawValue: json["net"] as? String ?? "tcp") ?? .tcp
        p.wsPath       = json["path"] as? String ?? "/"
        p.tls          = (json["tls"] as? String) == "tls"
        p.sni          = json["sni"]  as? String ?? ""
        return p
    }

    private static func parseVMessFromComponents(
        _ comps: URLComponents, host: String, port: Int
    ) -> ProxyProfile? {
        var p = ProxyProfile(protocol: .vmess, server: host, port: port)
        p.name         = comps.fragment?.removingPercentEncoding ?? host
        p.uuid         = comps.user ?? ""
        let q          = queryDict(comps)
        p.alterId      = Int(q["aid"] ?? "0") ?? 0
        p.vmessNetwork = VMessNetwork(rawValue: q["network"] ?? q["net"] ?? "tcp") ?? .tcp
        p.wsPath       = q["path"] ?? "/"
        p.tls          = q["tls"] == "1" || q["security"] == "tls"
        p.sni          = q["sni"] ?? ""
        return p
    }

    // MARK: VLESS — includes Reality (security=reality, pbk, sid)

    private static func parseVLESS(_ uri: String) -> ProxyProfile? {
        guard let comps = URLComponents(string: uri),
              let host = comps.host, let port = comps.port
        else { return nil }
        var p = ProxyProfile(protocol: .vless, server: host, port: port)
        p.name = comps.fragment?.removingPercentEncoding ?? host
        p.uuid = comps.user ?? ""
        let q  = queryDict(comps)
        let security = q["security"] ?? ""
        p.tls         = security == "tls" || security == "reality"
        p.sni         = q["sni"] ?? q["serverName"] ?? ""
        p.fingerprint = q["fp"] ?? ""
        p.wsPath      = q["path"] ?? "/"
        p.vmessNetwork = VMessNetwork(rawValue: q["type"] ?? "tcp") ?? .tcp
        if security == "reality" {
            p.realityPublicKey = q["pbk"] ?? ""
            p.realityShortId   = q["sid"] ?? ""
        }
        return p
    }

    // MARK: Trojan

    private static func parseTrojan(_ uri: String) -> ProxyProfile? {
        guard let comps = URLComponents(string: uri),
              let host = comps.host, let port = comps.port
        else { return nil }
        var p = ProxyProfile(protocol: .trojan, server: host, port: port)
        p.name           = comps.fragment?.removingPercentEncoding ?? host
        p.trojanPassword = comps.user ?? ""
        p.tls            = true
        let q            = queryDict(comps)
        p.sni            = q["sni"] ?? q["peer"] ?? ""
        p.skipCertVerify = q["allowInsecure"] == "1"
        return p
    }

    // MARK: Hysteria2 — hysteria2://[auth@]host:port[?up=&down=&sni=&insecure=][#name]

    private static func parseHysteria2(_ uri: String) -> ProxyProfile? {
        guard let comps = URLComponents(string: uri),
              let host = comps.host, let port = comps.port
        else { return nil }
        var p = ProxyProfile(protocol: .hysteria2, server: host, port: port)
        p.name           = comps.fragment?.removingPercentEncoding ?? host
        p.password       = comps.user?.removingPercentEncoding ?? ""
        p.tls            = true
        let q            = queryDict(comps)
        p.sni            = q["sni"] ?? q["server_name"] ?? ""
        p.skipCertVerify = q["insecure"] == "1"
        p.hysteria2UpMbps   = Int(q["up"]   ?? "0") ?? 0
        p.hysteria2DownMbps = Int(q["down"] ?? "0") ?? 0
        return p
    }

    // MARK: TUIC — tuic://uuid:token@host:port[?congestion_control=&udp_relay_mode=&sni=][#name]

    private static func parseTUIC(_ uri: String) -> ProxyProfile? {
        guard let comps = URLComponents(string: uri),
              let host = comps.host, let port = comps.port
        else { return nil }
        var p = ProxyProfile(protocol: .tuic, server: host, port: port)
        p.name     = comps.fragment?.removingPercentEncoding ?? host
        p.uuid     = comps.user ?? ""
        p.password = comps.password?.removingPercentEncoding ?? ""
        p.tls      = true
        let q      = queryDict(comps)
        p.tuicCongestionControl = q["congestion_control"] ?? "bbr"
        p.tuicUdpRelayMode      = q["udp_relay_mode"]     ?? "native"
        p.sni                   = q["sni"] ?? ""
        p.skipCertVerify        = q["allow_insecure"] == "1"
        return p
    }

    // MARK: WireGuard — wireguard://BASE64(json)[#name]

    private static func parseWireGuard(_ uri: String) -> ProxyProfile? {
        var remainder = String(uri.dropFirst("wireguard://".count))
        var profileName = ""
        if let hashIdx = remainder.firstIndex(of: "#") {
            profileName = String(remainder[remainder.index(after: hashIdx)...])
                .removingPercentEncoding ?? ""
            remainder = String(remainder[..<hashIdx])
        }
        guard let jsonString = base64Decode(remainder),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let server = json["server"] as? String ?? ""
        let port   = json["server_port"] as? Int ?? 0
        guard !server.isEmpty, port > 0 else { return nil }
        var p = ProxyProfile(protocol: .wireguard, server: server, port: port)
        p.name            = profileName.isEmpty ? server : profileName
        p.wgPrivateKey    = json["private_key"]    as? String ?? ""
        p.wgPeerPublicKey = json["peer_public_key"] as? String ?? ""
        p.wgPresharedKey  = json["pre_shared_key"] as? String ?? ""
        p.wgMTU           = json["mtu"] as? Int ?? 1420
        if let addrs = json["local_address"] as? [String] {
            p.wgLocalAddress = addrs.joined(separator: ", ")
        }
        return p
    }

    // MARK: Helpers

    private static func queryDict(_ comps: URLComponents) -> [String: String] {
        (comps.queryItems ?? []).reduce(into: [:]) { $0[$1.name] = $1.value ?? "" }
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

// MARK: - URI Export

extension ProxyProfile {
    /// Returns the canonical URI for this profile, nil for socks5/http or missing credentials.
    func toURI() -> String? {
        switch `protocol` {
        case .shadowsocks:   return shadowsocksURI()
        case .vmess:         return vmessURI()
        case .vless:         return vlessURI()
        case .trojan:        return trojanURI()
        case .hysteria2:     return hysteria2URI()
        case .tuic:          return tuicURI()
        case .wireguard:     return wireguardURI()
        case .socks5, .http: return nil
        }
    }

    private func shadowsocksURI() -> String? {
        guard !password.isEmpty else { return nil }
        let creds   = "\(ssMethod.rawValue):\(password)"
        let encoded = Data(creds.utf8).base64EncodedString()
        return "ss://\(encoded)@\(server):\(port)\(uriFragment)"
    }

    private func vmessURI() -> String? {
        let obj: [String: Any] = [
            "v": "2", "ps": name, "add": server, "port": port,
            "id": uuid, "aid": alterId,
            "net": vmessNetwork.rawValue, "path": wsPath,
            "tls": tls ? "tls" : "", "sni": sni
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let str  = String(data: data, encoding: .utf8)
        else { return nil }
        let b64 = Data(str.utf8).base64EncodedString()
        return "vmess://\(b64)"
    }

    private func vlessURI() -> String? {
        guard !uuid.isEmpty else { return nil }
        var params: [String] = ["type=\(vmessNetwork.rawValue)"]
        if !realityPublicKey.isEmpty {
            params += ["security=reality", "pbk=\(realityPublicKey)"]
            if !realityShortId.isEmpty { params.append("sid=\(realityShortId)") }
        } else if tls {
            params.append("security=tls")
        }
        if !sni.isEmpty         { params.append("sni=\(sni.uriEncoded)") }
        if !fingerprint.isEmpty { params.append("fp=\(fingerprint)") }
        if vmessNetwork == .ws  { params.append("path=\(wsPath.uriEncoded)") }
        return "vless://\(uuid)@\(server):\(port)?\(params.joined(separator: "&"))\(uriFragment)"
    }

    private func trojanURI() -> String? {
        guard !trojanPassword.isEmpty else { return nil }
        let enc = trojanPassword.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed)
            ?? trojanPassword
        var params: [String] = []
        if !sni.isEmpty   { params.append("sni=\(sni.uriEncoded)") }
        if skipCertVerify { params.append("allowInsecure=1") }
        let qs = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
        return "trojan://\(enc)@\(server):\(port)\(qs)\(uriFragment)"
    }

    private func hysteria2URI() -> String? {
        let authPart = password.isEmpty ? "" : "\(password.uriEncoded)@"
        var params: [String] = []
        if !sni.isEmpty           { params.append("sni=\(sni.uriEncoded)") }
        if skipCertVerify         { params.append("insecure=1") }
        if hysteria2UpMbps > 0   { params.append("up=\(hysteria2UpMbps)") }
        if hysteria2DownMbps > 0 { params.append("down=\(hysteria2DownMbps)") }
        let qs = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
        return "hysteria2://\(authPart)\(server):\(port)\(qs)\(uriFragment)"
    }

    private func tuicURI() -> String? {
        guard !uuid.isEmpty else { return nil }
        let tokenPart = password.isEmpty ? "" : ":\(password.uriEncoded)"
        var params: [String] = []
        if !tuicCongestionControl.isEmpty { params.append("congestion_control=\(tuicCongestionControl)") }
        if !tuicUdpRelayMode.isEmpty      { params.append("udp_relay_mode=\(tuicUdpRelayMode)") }
        if !sni.isEmpty                   { params.append("sni=\(sni.uriEncoded)") }
        if skipCertVerify                 { params.append("allow_insecure=1") }
        let qs = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
        return "tuic://\(uuid)\(tokenPart)@\(server):\(port)\(qs)\(uriFragment)"
    }

    private func wireguardURI() -> String? {
        guard !wgPeerPublicKey.isEmpty else { return nil }
        var dict: [String: Any] = [
            "server": server, "server_port": port,
            "peer_public_key": wgPeerPublicKey, "mtu": wgMTU
        ]
        if !wgPrivateKey.isEmpty   { dict["private_key"]    = wgPrivateKey }
        if !wgPresharedKey.isEmpty { dict["pre_shared_key"] = wgPresharedKey }
        if !wgLocalAddress.isEmpty {
            dict["local_address"] = wgLocalAddress
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys),
              let str  = String(data: data, encoding: .utf8)
        else { return nil }
        var b64 = Data(str.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        while b64.hasSuffix("=") { b64.removeLast() }
        return "wireguard://\(b64)\(uriFragment)"
    }

    private var uriFragment: String {
        guard !name.isEmpty else { return "" }
        let enc = name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? name
        return "#\(enc)"
    }
}

private extension String {
    var uriEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
