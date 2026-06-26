import Foundation

struct RoutingRule: Identifiable, Codable, Sendable, Hashable {
    var id: UUID = UUID()
    var name: String
    var type: RuleType
    var value: String
    var outbound: RuleOutbound
    var isEnabled: Bool = true
}

enum RuleType: String, Codable, CaseIterable, Sendable {
    case domain     = "domain"
    case domainSuffix = "domain_suffix"
    case ipCidr     = "ip_cidr"
    case geosite    = "geosite"
    case geoip      = "geoip"
    case processName = "process_name"

    var displayName: String {
        switch self {
        case .domain:      "Domain"
        case .domainSuffix: "Domain Suffix"
        case .ipCidr:      "IP CIDR"
        case .geosite:     "GeoSite"
        case .geoip:       "GeoIP"
        case .processName: "Process"
        }
    }
}

enum RuleOutbound: String, Codable, CaseIterable, Sendable {
    case proxy  = "proxy"
    case direct = "direct"
    case block  = "block"

    var displayName: String {
        switch self {
        case .proxy:  "Proxy"
        case .direct: "Direct"
        case .block:  "Block"
        }
    }
}
