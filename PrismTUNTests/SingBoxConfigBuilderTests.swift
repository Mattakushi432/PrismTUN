import XCTest

final class SingBoxConfigBuilderTests: XCTestCase {

    // MARK: - Shadowsocks

    func testShadowsocksOutbound() {
        var p      = ProxyProfile(protocol: .shadowsocks, server: "ss.example.com", port: 8388)
        p.ssMethod = .aes256gcm
        p.password = "secret"

        let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)

        XCTAssertEqual(out["type"] as? String,      "shadowsocks")
        XCTAssertEqual(out["server"] as? String,    "ss.example.com")
        XCTAssertEqual(out["server_port"] as? Int,  8388)
        XCTAssertEqual(out["method"] as? String,    "aes-256-gcm")
        XCTAssertEqual(out["password"] as? String,  "secret")
        XCTAssertEqual(out["tag"] as? String,       "proxy")
    }

    func testShadowsocksXChacha20Method() {
        var p      = ProxyProfile(protocol: .shadowsocks, server: "ss.example.com", port: 8388)
        p.ssMethod = .xchacha20
        p.password = "pw"
        let out    = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
        XCTAssertEqual(out["method"] as? String, "xchacha20-ietf-poly1305")
    }

    // MARK: - VMess

    func testVMessTCPNoTLS() {
        var p          = ProxyProfile(protocol: .vmess, server: "vmess.example.com", port: 443)
        p.uuid         = "test-uuid"
        p.alterId      = 0
        p.vmessNetwork = .tcp
        p.tls          = false

        let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)

        XCTAssertEqual(out["type"] as? String,      "vmess")
        XCTAssertEqual(out["uuid"] as? String,      "test-uuid")
        XCTAssertEqual(out["alter_id"] as? Int,     0)
        XCTAssertNil(out["transport"])
        XCTAssertNil(out["tls"])
    }

    func testVMessWSWithTLS() {
        var p          = ProxyProfile(protocol: .vmess, server: "vmess.example.com", port: 443)
        p.uuid         = "test-uuid"
        p.vmessNetwork = .ws
        p.wsPath       = "/ws"
        p.tls          = true
        p.sni          = "vmess.example.com"

        let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)

        let transport = out["transport"] as? [String: Any]
        XCTAssertEqual(transport?["type"] as? String, "ws")
        XCTAssertEqual(transport?["path"] as? String, "/ws")

        let tls = out["tls"] as? [String: Any]
        XCTAssertEqual(tls?["enabled"] as? Bool,        true)
        XCTAssertEqual(tls?["server_name"] as? String,  "vmess.example.com")
    }

    func testVMessTCPHasNoTransport() {
        var p          = ProxyProfile(protocol: .vmess, server: "example.com", port: 1080)
        p.vmessNetwork = .tcp
        let out        = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
        XCTAssertNil(out["transport"])
    }

    // MARK: - VLESS

    func testVLESSOutbound() {
        var p  = ProxyProfile(protocol: .vless, server: "vless.example.com", port: 443)
        p.uuid = "vless-uuid"
        p.tls  = true
        p.sni  = "vless.example.com"

        let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)

        XCTAssertEqual(out["type"] as? String, "vless")
        XCTAssertEqual(out["uuid"] as? String, "vless-uuid")
        let tls = out["tls"] as? [String: Any]
        XCTAssertEqual(tls?["enabled"] as? Bool,       true)
        XCTAssertEqual(tls?["server_name"] as? String, "vless.example.com")
    }

    func testVLESSWSTransport() {
        var p          = ProxyProfile(protocol: .vless, server: "vless.example.com", port: 443)
        p.uuid         = "vless-uuid"
        p.vmessNetwork = .ws
        p.wsPath       = "/vless-path"

        let out       = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
        let transport = out["transport"] as? [String: Any]
        XCTAssertEqual(transport?["type"] as? String, "ws")
        XCTAssertEqual(transport?["path"] as? String, "/vless-path")
    }

    // MARK: - Trojan

    func testTrojanOutbound() {
        var p            = ProxyProfile(protocol: .trojan, server: "trojan.example.com", port: 443)
        p.trojanPassword = "trojan-pass"
        p.sni            = "trojan.example.com"

        let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)

        XCTAssertEqual(out["type"] as? String,     "trojan")
        XCTAssertEqual(out["password"] as? String, "trojan-pass")
        let tls = out["tls"] as? [String: Any]
        XCTAssertNotNil(tls)
        XCTAssertEqual(tls?["server_name"] as? String, "trojan.example.com")
    }

    func testTrojanAlwaysHasTLSBlock() {
        var p            = ProxyProfile(protocol: .trojan, server: "example.com", port: 443)
        p.trojanPassword = "pw"
        let out          = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
        XCTAssertNotNil(out["tls"])
    }

    // MARK: - Hysteria2

    func testHysteria2Outbound() {
        var p               = ProxyProfile(protocol: .hysteria2, server: "hy2.example.com", port: 443)
        p.password          = "hy2-token"
        p.hysteria2UpMbps   = 100
        p.hysteria2DownMbps = 200
        p.tls               = true

        let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)

        XCTAssertEqual(out["type"] as? String,     "hysteria2")
        XCTAssertEqual(out["password"] as? String, "hy2-token")
        XCTAssertEqual(out["up_mbps"] as? Int,     100)
        XCTAssertEqual(out["down_mbps"] as? Int,   200)
        XCTAssertNotNil(out["tls"])
    }

    func testHysteria2OmitsSpeedWhenZero() {
        var p               = ProxyProfile(protocol: .hysteria2, server: "hy2.example.com", port: 443)
        p.hysteria2UpMbps   = 0
        p.hysteria2DownMbps = 0
        let out             = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
        XCTAssertNil(out["up_mbps"])
        XCTAssertNil(out["down_mbps"])
    }

    // MARK: - TUIC

    func testTUICOutbound() {
        var p                   = ProxyProfile(protocol: .tuic, server: "tuic.example.com", port: 443)
        p.uuid                  = "tuic-uuid"
        p.password              = "tuic-token"
        p.tuicCongestionControl = "bbr"
        p.tuicUdpRelayMode      = "native"
        p.tls                   = true

        let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)

        XCTAssertEqual(out["type"] as? String,               "tuic")
        XCTAssertEqual(out["uuid"] as? String,               "tuic-uuid")
        XCTAssertEqual(out["password"] as? String,           "tuic-token")
        XCTAssertEqual(out["congestion_control"] as? String, "bbr")
        XCTAssertEqual(out["udp_relay_mode"] as? String,     "native")
        XCTAssertNotNil(out["tls"])
    }

    // MARK: - WireGuard

    func testWireGuardOutbound() {
        var p             = ProxyProfile(protocol: .wireguard, server: "wg.example.com", port: 51820)
        p.wgPrivateKey    = "privkey"
        p.wgPeerPublicKey = "pubkey"
        p.wgLocalAddress  = "10.0.0.2/32, ::2/128"
        p.wgMTU           = 1420

        let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)

        XCTAssertEqual(out["type"] as? String,            "wireguard")
        XCTAssertEqual(out["private_key"] as? String,     "privkey")
        XCTAssertEqual(out["peer_public_key"] as? String, "pubkey")
        XCTAssertEqual(out["mtu"] as? Int,                1420)
        XCTAssertEqual(out["local_address"] as? [String], ["10.0.0.2/32", "::2/128"])
    }

    func testWireGuardIncludesPresharedKey() {
        var p             = ProxyProfile(protocol: .wireguard, server: "wg.example.com", port: 51820)
        p.wgPeerPublicKey = "pubkey"
        p.wgPresharedKey  = "psk123"
        let out           = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
        XCTAssertEqual(out["pre_shared_key"] as? String, "psk123")
    }

    func testWireGuardOmitsPresharedKeyWhenEmpty() {
        var p             = ProxyProfile(protocol: .wireguard, server: "wg.example.com", port: 51820)
        p.wgPeerPublicKey = "pubkey"
        p.wgPresharedKey  = ""
        let out           = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
        XCTAssertNil(out["pre_shared_key"])
    }

    func testWireGuardOmitsLocalAddressWhenEmpty() {
        var p             = ProxyProfile(protocol: .wireguard, server: "wg.example.com", port: 51820)
        p.wgPeerPublicKey = "pubkey"
        p.wgLocalAddress  = ""
        let out           = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
        XCTAssertNil(out["local_address"])
    }

    // MARK: - SOCKS5

    func testSocks5WithAuth() {
        var p      = ProxyProfile(protocol: .socks5, server: "socks.example.com", port: 1080)
        p.username = "user"
        p.password = "pass"

        let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)

        XCTAssertEqual(out["type"] as? String,     "socks")
        XCTAssertEqual(out["version"] as? String,  "5")
        XCTAssertEqual(out["username"] as? String, "user")
        XCTAssertEqual(out["password"] as? String, "pass")
    }

    func testSocks5AnonymousOmitsCredentials() {
        let p   = ProxyProfile(protocol: .socks5, server: "socks.example.com", port: 1080)
        let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
        XCTAssertNil(out["username"])
        XCTAssertNil(out["password"])
    }

    // MARK: - HTTP

    func testHTTPOutbound() {
        var p      = ProxyProfile(protocol: .http, server: "http.example.com", port: 8080)
        p.username = "admin"
        p.password = "adminpass"

        let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)

        XCTAssertEqual(out["type"] as? String,     "http")
        XCTAssertEqual(out["username"] as? String, "admin")
        XCTAssertEqual(out["password"] as? String, "adminpass")
    }

    // MARK: - TLS details

    func testTLSWithUTLSFingerprint() {
        var p            = ProxyProfile(protocol: .trojan, server: "example.com", port: 443)
        p.trojanPassword = "pass"
        p.fingerprint    = "chrome"
        p.sni            = "example.com"

        let out  = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
        let tls  = out["tls"] as? [String: Any]
        let utls = tls?["utls"] as? [String: Any]
        XCTAssertEqual(utls?["fingerprint"] as? String, "chrome")
        XCTAssertEqual(utls?["enabled"] as? Bool,       true)
    }

    func testTLSSkipCertVerify() {
        var p            = ProxyProfile(protocol: .trojan, server: "example.com", port: 443)
        p.trojanPassword = "pass"
        p.skipCertVerify = true

        let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
        let tls = out["tls"] as? [String: Any]
        XCTAssertEqual(tls?["insecure"] as? Bool, true)
    }

    func testTLSOmitsServerNameWhenEmpty() {
        var p            = ProxyProfile(protocol: .trojan, server: "example.com", port: 443)
        p.trojanPassword = "pass"
        p.sni            = ""
        let out          = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
        let tls          = out["tls"] as? [String: Any]
        XCTAssertNil(tls?["server_name"])
    }

    // MARK: - Shared outbound fields present for all protocols

    func testAllOutboundsHaveTagServerAndPort() {
        let cases: [(ProxyProtocol, (inout ProxyProfile) -> Void)] = [
            (.shadowsocks, { $0.ssMethod = .aes256gcm; $0.password = "pw" }),
            (.vmess,       { $0.uuid = "uid" }),
            (.vless,       { $0.uuid = "uid" }),
            (.trojan,      { $0.trojanPassword = "pw" }),
            (.hysteria2,   { $0.password = "pw" }),
            (.tuic,        { $0.uuid = "uid"; $0.password = "pw" }),
            (.wireguard,   { $0.wgPeerPublicKey = "key" }),
            (.socks5,      { _ in }),
            (.http,        { _ in })
        ]
        for (proto, configure) in cases {
            var p = ProxyProfile(protocol: proto, server: "host.com", port: 1234)
            configure(&p)
            let out = SingBoxConfigBuilder.buildProxyOutbound(profile: p)
            XCTAssertEqual(out["tag"] as? String,      "proxy",    "tag missing for \(proto)")
            XCTAssertEqual(out["server"] as? String,   "host.com", "server missing for \(proto)")
            XCTAssertEqual(out["server_port"] as? Int, 1234,       "port missing for \(proto)")
        }
    }
}
