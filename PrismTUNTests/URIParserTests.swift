import XCTest

final class URIParserTests: XCTestCase {

    // MARK: - Shadowsocks

    func testShadowsocksSIP002() {
        let uri = makeShadowsocksURI(method: "aes-256-gcm", password: "test-password-123",
                                     host: "example.com", port: 8388, name: "MyServer")
        guard let p = ProxyProfile.parse(uri: uri) else {
            XCTFail("Failed to parse Shadowsocks URI"); return
        }
        XCTAssertEqual(p.protocol, .shadowsocks)
        XCTAssertEqual(p.server, "example.com")
        XCTAssertEqual(p.port, 8388)
        XCTAssertEqual(p.ssMethod, .aes256gcm)
        XCTAssertEqual(p.password, "test-password-123")
        XCTAssertEqual(p.name, "MyServer")
    }

    func testShadowsocksChacha20() {
        let uri = makeShadowsocksURI(method: "chacha20-ietf-poly1305", password: "secret",
                                     host: "192.168.1.1", port: 443, name: "")
        guard let p = ProxyProfile.parse(uri: uri) else {
            XCTFail("Failed to parse Shadowsocks URI without fragment"); return
        }
        XCTAssertEqual(p.server, "192.168.1.1")
        XCTAssertEqual(p.port, 443)
        XCTAssertEqual(p.ssMethod, .chacha20)
    }

    func testShadowsocksPasswordWithColon() {
        let uri = makeShadowsocksURI(method: "aes-256-gcm", password: "pass:with:colons",
                                     host: "ss.example.com", port: 8388, name: "ColonPw")
        guard let p = ProxyProfile.parse(uri: uri) else {
            XCTFail("Failed to parse Shadowsocks URI with colon in password"); return
        }
        XCTAssertEqual(p.password, "pass:with:colons")
    }

    // MARK: - VMess

    func testVMessBase64JSON() {
        let json: [String: Any] = [
            "v": "2", "ps": "TestVMess",
            "add": "vmess.example.com", "port": "443",
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "aid": "0", "net": "ws", "path": "/ws",
            "tls": "tls", "sni": "vmess.example.com"
        ]
        let uri = vmessURI(from: json)
        guard let p = ProxyProfile.parse(uri: uri) else {
            XCTFail("Failed to parse VMess base64 URI"); return
        }
        XCTAssertEqual(p.protocol, .vmess)
        XCTAssertEqual(p.server, "vmess.example.com")
        XCTAssertEqual(p.port, 443)
        XCTAssertEqual(p.name, "TestVMess")
        XCTAssertEqual(p.uuid, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(p.vmessNetwork, .ws)
        XCTAssertEqual(p.wsPath, "/ws")
        XCTAssertTrue(p.tls)
    }

    func testVMessTCPNoTLS() {
        let json: [String: Any] = [
            "v": "2", "ps": "TCPServer",
            "add": "tcp.example.com", "port": 8080,
            "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            "aid": 0, "net": "tcp", "tls": ""
        ]
        let uri = vmessURI(from: json)
        guard let p = ProxyProfile.parse(uri: uri) else {
            XCTFail("Failed to parse VMess TCP URI"); return
        }
        XCTAssertEqual(p.vmessNetwork, .tcp)
        XCTAssertFalse(p.tls)
    }

    // MARK: - VLESS + Reality

    func testVLESSReality() {
        let uuid = "550e8400-e29b-41d4-a716-446655440001"
        let uri  = "vless://\(uuid)@reality.example.com:443?security=reality&pbk=abcdef1234567890&sid=abc123&type=tcp&sni=example.com&fp=chrome#Reality%20Server"
        guard let p = ProxyProfile.parse(uri: uri) else {
            XCTFail("Failed to parse VLESS+Reality URI"); return
        }
        XCTAssertEqual(p.protocol, .vless)
        XCTAssertEqual(p.server, "reality.example.com")
        XCTAssertEqual(p.port, 443)
        XCTAssertEqual(p.uuid, uuid)
        XCTAssertTrue(p.tls)
        XCTAssertEqual(p.realityPublicKey, "abcdef1234567890")
        XCTAssertEqual(p.realityShortId, "abc123")
        XCTAssertEqual(p.sni, "example.com")
        XCTAssertEqual(p.fingerprint, "chrome")
        XCTAssertEqual(p.name, "Reality Server")
    }

    func testVLESSTLSWebSocket() {
        let uuid = "550e8400-e29b-41d4-a716-446655440002"
        let uri  = "vless://\(uuid)@tls.example.com:8443?security=tls&type=ws&path=/path&sni=tls.example.com#VLESS%20WS"
        guard let p = ProxyProfile.parse(uri: uri) else {
            XCTFail("Failed to parse VLESS+TLS+WS URI"); return
        }
        XCTAssertTrue(p.tls)
        XCTAssertTrue(p.realityPublicKey.isEmpty)
        XCTAssertEqual(p.vmessNetwork, .ws)
        XCTAssertEqual(p.wsPath, "/path")
        XCTAssertEqual(p.name, "VLESS WS")
    }

    func testVLESSNoSecurity() {
        let uuid = "550e8400-e29b-41d4-a716-446655440003"
        let uri  = "vless://\(uuid)@plain.example.com:80?type=tcp"
        guard let p = ProxyProfile.parse(uri: uri) else {
            XCTFail("Failed to parse plain VLESS URI"); return
        }
        XCTAssertFalse(p.tls)
    }

    // MARK: - Trojan

    func testTrojan() {
        let uri = "trojan://mysecretpassword@trojan.example.com:443?sni=trojan.example.com&allowInsecure=0#TrojanServer"
        guard let p = ProxyProfile.parse(uri: uri) else {
            XCTFail("Failed to parse Trojan URI"); return
        }
        XCTAssertEqual(p.protocol, .trojan)
        XCTAssertEqual(p.server, "trojan.example.com")
        XCTAssertEqual(p.port, 443)
        XCTAssertEqual(p.trojanPassword, "mysecretpassword")
        XCTAssertTrue(p.tls)
        XCTAssertEqual(p.sni, "trojan.example.com")
        XCTAssertFalse(p.skipCertVerify)
        XCTAssertEqual(p.name, "TrojanServer")
    }

    func testTrojanInsecure() {
        let uri = "trojan://pass@example.com:443?allowInsecure=1"
        guard let p = ProxyProfile.parse(uri: uri) else { XCTFail(); return }
        XCTAssertTrue(p.skipCertVerify)
    }

    func testTrojanNoFragment() {
        let uri = "trojan://pass@example.com:443"
        guard let p = ProxyProfile.parse(uri: uri) else { XCTFail(); return }
        XCTAssertEqual(p.server, "example.com")
    }

    // MARK: - Hysteria2

    func testHysteria2Full() {
        let uri = "hysteria2://authtoken@hy2.example.com:443?up=100&down=200&sni=hy2.example.com&insecure=0#HY2Server"
        guard let p = ProxyProfile.parse(uri: uri) else {
            XCTFail("Failed to parse Hysteria2 URI"); return
        }
        XCTAssertEqual(p.protocol, .hysteria2)
        XCTAssertEqual(p.server, "hy2.example.com")
        XCTAssertEqual(p.port, 443)
        XCTAssertEqual(p.password, "authtoken")
        XCTAssertTrue(p.tls)
        XCTAssertEqual(p.sni, "hy2.example.com")
        XCTAssertEqual(p.hysteria2UpMbps, 100)
        XCTAssertEqual(p.hysteria2DownMbps, 200)
        XCTAssertFalse(p.skipCertVerify)
        XCTAssertEqual(p.name, "HY2Server")
    }

    func testHysteria2NoAuth() {
        let uri = "hysteria2://hy2.example.com:443?insecure=1"
        guard let p = ProxyProfile.parse(uri: uri) else { XCTFail(); return }
        XCTAssertEqual(p.protocol, .hysteria2)
        XCTAssertTrue(p.password.isEmpty)
        XCTAssertTrue(p.skipCertVerify)
        XCTAssertEqual(p.hysteria2UpMbps, 0)
        XCTAssertEqual(p.hysteria2DownMbps, 0)
    }

    // MARK: - TUIC

    func testTUIC() {
        let uuid = "550e8400-e29b-41d4-a716-446655440004"
        let uri  = "tuic://\(uuid):mytoken@tuic.example.com:443?congestion_control=bbr&udp_relay_mode=native&sni=tuic.example.com#TUICServer"
        guard let p = ProxyProfile.parse(uri: uri) else {
            XCTFail("Failed to parse TUIC URI"); return
        }
        XCTAssertEqual(p.protocol, .tuic)
        XCTAssertEqual(p.server, "tuic.example.com")
        XCTAssertEqual(p.port, 443)
        XCTAssertEqual(p.uuid, uuid)
        XCTAssertEqual(p.password, "mytoken")
        XCTAssertTrue(p.tls)
        XCTAssertEqual(p.tuicCongestionControl, "bbr")
        XCTAssertEqual(p.tuicUdpRelayMode, "native")
        XCTAssertEqual(p.sni, "tuic.example.com")
        XCTAssertEqual(p.name, "TUICServer")
    }

    func testTUICInsecure() {
        let uuid = "550e8400-e29b-41d4-a716-446655440005"
        let uri  = "tuic://\(uuid):token@tuic.example.com:443?allow_insecure=1"
        guard let p = ProxyProfile.parse(uri: uri) else { XCTFail(); return }
        XCTAssertTrue(p.skipCertVerify)
    }

    // MARK: - WireGuard

    func testWireGuard() {
        let wgJSON: [String: Any] = [
            "server": "wg.example.com",
            "server_port": 51820,
            "private_key": "privkey123",
            "peer_public_key": "pubkey456",
            "local_address": ["10.0.0.2/32"],
            "mtu": 1420
        ]
        let uri = "wireguard://\(wireGuardBase64(wgJSON))#WGServer"
        guard let p = ProxyProfile.parse(uri: uri) else {
            XCTFail("Failed to parse WireGuard URI"); return
        }
        XCTAssertEqual(p.protocol, .wireguard)
        XCTAssertEqual(p.server, "wg.example.com")
        XCTAssertEqual(p.port, 51820)
        XCTAssertEqual(p.wgPrivateKey, "privkey123")
        XCTAssertEqual(p.wgPeerPublicKey, "pubkey456")
        XCTAssertEqual(p.wgMTU, 1420)
        XCTAssertEqual(p.name, "WGServer")
    }

    func testWireGuardInvalidBase64() {
        XCTAssertNil(ProxyProfile.parse(uri: "wireguard://@@@notvalidbase64@@@"))
    }

    func testWireGuardMissingServerField() {
        // JSON present but missing required "server" field
        let wgJSON: [String: Any] = ["peer_public_key": "key"]
        XCTAssertNil(ProxyProfile.parse(uri: "wireguard://\(wireGuardBase64(wgJSON))#BadWG"))
    }

    // MARK: - Unknown / unsupported schemes

    func testUnknownSchemeReturnsNil() {
        XCTAssertNil(ProxyProfile.parse(uri: "socks5://user:pass@host:1080"))
        XCTAssertNil(ProxyProfile.parse(uri: "http://proxy.example.com:8080"))
        XCTAssertNil(ProxyProfile.parse(uri: ""))
        XCTAssertNil(ProxyProfile.parse(uri: "not a uri at all"))
    }

    // MARK: - Batch parse

    func testBatchParseFiltersInvalidLines() {
        let ssURI     = makeShadowsocksURI(method: "aes-256-gcm", password: "pw",
                                           host: "host1.com", port: 8388, name: "Server1")
        let trojanURI = "trojan://pw@host2.com:443#Server2"
        let text      = [ssURI, "", "invalid line", trojanURI, "   "].joined(separator: "\n")

        let profiles = ProxyProfile.batchParse(text: text)
        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles[0].server, "host1.com")
        XCTAssertEqual(profiles[1].server, "host2.com")
    }

    func testBatchParseEmptyText() {
        XCTAssertTrue(ProxyProfile.batchParse(text: "").isEmpty)
        XCTAssertTrue(ProxyProfile.batchParse(text: "   \n  \n  ").isEmpty)
    }

    // MARK: - URI export roundtrip

    func testShadowsocksRoundtrip() {
        let uri = makeShadowsocksURI(method: "aes-256-gcm", password: "roundtrip-pass",
                                     host: "ss.example.com", port: 8388, name: "SSRoundtrip")
        guard let p1 = ProxyProfile.parse(uri: uri)      else { XCTFail(); return }
        guard let exported = p1.toURI()                  else { XCTFail("toURI nil"); return }
        guard let p2 = ProxyProfile.parse(uri: exported) else { XCTFail("re-parse failed"); return }
        XCTAssertEqual(p2.server,   p1.server)
        XCTAssertEqual(p2.port,     p1.port)
        XCTAssertEqual(p2.ssMethod, p1.ssMethod)
        XCTAssertEqual(p2.password, p1.password)
    }

    func testHysteria2Roundtrip() {
        let uri = "hysteria2://token@hy2.example.com:443?up=50&down=100&sni=example.com#HY2"
        guard let p1 = ProxyProfile.parse(uri: uri)      else { XCTFail(); return }
        guard let exported = p1.toURI()                  else { XCTFail("toURI nil"); return }
        guard let p2 = ProxyProfile.parse(uri: exported) else { XCTFail("re-parse failed"); return }
        XCTAssertEqual(p2.server,            p1.server)
        XCTAssertEqual(p2.password,          p1.password)
        XCTAssertEqual(p2.hysteria2UpMbps,   p1.hysteria2UpMbps)
        XCTAssertEqual(p2.hysteria2DownMbps, p1.hysteria2DownMbps)
    }

    func testVLESSRoundtrip() {
        let uuid = "550e8400-e29b-41d4-a716-446655440099"
        var p1   = ProxyProfile(protocol: .vless, server: "vless.example.com", port: 443)
        p1.uuid  = uuid
        p1.tls   = true
        p1.sni   = "vless.example.com"
        p1.name  = "VLESSTest"
        guard let exported = p1.toURI()                  else { XCTFail("toURI nil"); return }
        guard let p2 = ProxyProfile.parse(uri: exported) else { XCTFail("re-parse failed"); return }
        XCTAssertEqual(p2.uuid, uuid)
        XCTAssertTrue(p2.tls)
    }

    // MARK: - Helpers

    private func makeShadowsocksURI(method: String, password: String,
                                    host: String, port: Int, name: String) -> String {
        let creds = "\(method):\(password)"
        let b64   = Data(creds.utf8).base64EncodedString()
        let frag  = name.isEmpty ? "" : "#\(name)"
        return "ss://\(b64)@\(host):\(port)\(frag)"
    }

    private func vmessURI(from json: [String: Any]) -> String {
        guard let data    = try? JSONSerialization.data(withJSONObject: json),
              let jsonStr = String(data: data, encoding: .utf8)
        else { return "vmess://" }
        return "vmess://\(Data(jsonStr.utf8).base64EncodedString())"
    }

    private func wireGuardBase64(_ json: [String: Any]) -> String {
        guard let data    = try? JSONSerialization.data(withJSONObject: json),
              let jsonStr = String(data: data, encoding: .utf8)
        else { return "" }
        return Data(jsonStr.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
