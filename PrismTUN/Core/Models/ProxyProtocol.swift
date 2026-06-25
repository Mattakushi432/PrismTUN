import Foundation

enum ProxyProtocol: String, Codable, CaseIterable, Sendable {
    case shadowsocks = "shadowsocks"
    case vmess       = "vmess"
    case vless       = "vless"
    case trojan      = "trojan"
    case socks5      = "socks5"
    case http        = "http"

    var displayName: String {
        switch self {
        case .shadowsocks: "Shadowsocks"
        case .vmess:       "VMess"
        case .vless:       "VLESS"
        case .trojan:      "Trojan"
        case .socks5:      "SOCKS5"
        case .http:        "HTTP"
        }
    }

    var uriScheme: String {
        switch self {
        case .shadowsocks: "ss"
        case .vmess:       "vmess"
        case .vless:       "vless"
        case .trojan:      "trojan"
        case .socks5:      "socks5"
        case .http:        "http"
        }
    }

    var requiresEncryption: Bool {
        switch self {
        case .shadowsocks, .vmess, .vless, .trojan: true
        case .socks5, .http: false
        }
    }
}
