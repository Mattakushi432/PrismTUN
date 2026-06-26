import Foundation

struct RoutingRule: Identifiable, Codable, Sendable, Hashable {
    var id: UUID
    var name: String
    var notes: String
    var type: RuleType
    var value: String
    var outbound: RuleOutbound
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        type: RuleType,
        value: String,
        outbound: RuleOutbound,
        isEnabled: Bool = true
    ) {
        self.id       = id
        self.name     = name
        self.notes    = notes
        self.type     = type
        self.value    = value
        self.outbound = outbound
        self.isEnabled = isEnabled
    }

    // Custom decoder so older JSON missing `notes` or `isEnabled` still loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,         forKey: .id)
        name      = try c.decode(String.self,       forKey: .name)
        notes     = (try? c.decode(String.self,     forKey: .notes))    ?? ""
        type      = try c.decode(RuleType.self,     forKey: .type)
        value     = try c.decode(String.self,       forKey: .value)
        outbound  = try c.decode(RuleOutbound.self, forKey: .outbound)
        isEnabled = (try? c.decode(Bool.self,       forKey: .isEnabled)) ?? true
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, notes, type, value, outbound, isEnabled
    }
}

enum RuleType: String, Codable, CaseIterable, Sendable {
    case domain        = "domain"
    case domainSuffix  = "domain_suffix"
    case domainKeyword = "domain_keyword"
    case domainRegex   = "domain_regex"
    case ipCidr        = "ip_cidr"
    case port          = "port"
    case portRange     = "port_range"
    case processName   = "process_name"
    case processPath   = "process_path"
    case network       = "network"
    case geosite       = "geosite"
    case geoip         = "geoip"
    case sourceIpCidr  = "source_ip_cidr"
    case user          = "user"
    case clashMode     = "clash_mode"

    var displayName: String {
        switch self {
        case .domain:        "Domain"
        case .domainSuffix:  "Domain Suffix"
        case .domainKeyword: "Domain Keyword"
        case .domainRegex:   "Domain Regex"
        case .ipCidr:        "IP CIDR"
        case .port:          "Port"
        case .portRange:     "Port Range"
        case .processName:   "Process Name"
        case .processPath:   "Process Path"
        case .network:       "Network"
        case .geosite:       "GeoSite"
        case .geoip:         "GeoIP"
        case .sourceIpCidr:  "Source IP CIDR"
        case .user:          "User"
        case .clashMode:     "Clash Mode"
        }
    }

    var placeholder: String {
        switch self {
        case .domain:        "example.com"
        case .domainSuffix:  ".example.com"
        case .domainKeyword: "example"
        case .domainRegex:   #"^.*\.example\.com$"#
        case .ipCidr:        "192.168.1.0/24"
        case .port:          "443"
        case .portRange:     "8000:9000"
        case .processName:   "curl"
        case .processPath:   "/usr/local/bin/curl"
        case .network:       "tcp"
        case .geosite:       "cn"
        case .geoip:         "cn"
        case .sourceIpCidr:  "10.0.0.0/8"
        case .user:          "username"
        case .clashMode:     "global"
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
