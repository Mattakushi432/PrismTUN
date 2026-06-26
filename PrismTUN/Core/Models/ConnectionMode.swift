import Foundation

enum ConnectionMode: String, Codable, CaseIterable, Sendable {
    case systemProxy = "systemProxy"
    case direct      = "direct"
    case global      = "global"

    var displayName: String {
        switch self {
        case .systemProxy: "System Proxy"
        case .direct:      "Direct"
        case .global:      "Global"
        }
    }

    var description: String {
        switch self {
        case .systemProxy: "Routes traffic matching rules through the proxy"
        case .direct:      "All traffic goes directly, bypassing proxy"
        case .global:      "All traffic goes through the proxy"
        }
    }
}
