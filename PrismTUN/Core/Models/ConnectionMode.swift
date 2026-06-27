import Foundation

enum ConnectionMode: String, Codable, CaseIterable, Sendable {
    case systemProxy = "systemProxy"
    case direct      = "direct"
    case global      = "global"
    case tun         = "tun"

    var displayName: String {
        switch self {
        case .systemProxy: "System Proxy"
        case .direct:      "Direct"
        case .global:      "Global"
        case .tun:         "TUN"
        }
    }

    var description: String {
        switch self {
        case .systemProxy: "Routes traffic matching rules through the proxy"
        case .direct:      "All traffic goes directly, bypassing proxy"
        case .global:      "All traffic goes through the proxy"
        case .tun:         "Routes all traffic via a virtual TUN interface (requires Developer ID signing)"
        }
    }
}
