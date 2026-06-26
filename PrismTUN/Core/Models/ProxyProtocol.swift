import Foundation

enum ProxyProtocol: String, Codable, CaseIterable, Sendable {
    case shadowsocks = "shadowsocks"
    case vmess       = "vmess"
    case vless       = "vless"
    case trojan      = "trojan"
    case socks5      = "socks5"
    case http        = "http"
    case hysteria2   = "hysteria2"
    case tuic        = "tuic"
    case wireguard   = "wireguard"

    var displayName: String {
        switch self {
        case .shadowsocks: "Shadowsocks"
        case .vmess:       "VMess"
        case .vless:       "VLESS"
        case .trojan:      "Trojan"
        case .socks5:      "SOCKS5"
        case .http:        "HTTP"
        case .hysteria2:   "Hysteria2"
        case .tuic:        "TUIC"
        case .wireguard:   "WireGuard"
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
        case .hysteria2:   "hysteria2"
        case .tuic:        "tuic"
        case .wireguard:   "wireguard"
        }
    }

    // Hysteria2 and TUIC always use TLS; WireGuard has its own built-in crypto.
    var requiresEncryption: Bool {
        switch self {
        case .shadowsocks, .vmess, .vless, .trojan, .hysteria2, .tuic: true
        case .socks5, .http, .wireguard: false
        }
    }
}
