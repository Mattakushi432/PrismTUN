import Foundation

// MARK: - DNS Server

struct DNSServer: Identifiable, Codable, Sendable, Hashable {
    var id: UUID
    var tag: String
    var address: String
    var detour: String

    init(id: UUID = UUID(), tag: String, address: String, detour: String = "") {
        self.id      = id
        self.tag     = tag
        self.address = address
        self.detour  = detour
    }

    var serverType: DNSServerType { DNSServerType(address: address) }
}

// MARK: - DNS Server Type

enum DNSServerType: String, Sendable {
    case plain  = "Plain"
    case doh    = "DoH"
    case dot    = "DoT"
    case doq    = "DoQ"
    case dhcp   = "DHCP"
    case local  = "Local"
    case fakeip = "FakeIP"

    init(address: String) {
        if address == "local" || address == "localhost" {
            self = .local
        } else if address == "fakeip" {
            self = .fakeip
        } else if address.hasPrefix("https://") {
            self = .doh
        } else if address.hasPrefix("tls://") {
            self = .dot
        } else if address.hasPrefix("quic://") {
            self = .doq
        } else if address.hasPrefix("dhcp://") {
            self = .dhcp
        } else {
            self = .plain
        }
    }

    var iconName: String {
        switch self {
        case .plain:  "network"
        case .doh:    "lock.shield"
        case .dot:    "lock"
        case .doq:    "bolt.shield"
        case .dhcp:   "wifi"
        case .local:  "house"
        case .fakeip: "wand.and.stars"
        }
    }
}

// MARK: - DNS Rule Type

enum DNSRuleType: String, Codable, Sendable, CaseIterable {
    case geosite = "geosite"
    case geoip   = "geoip"
    case domain  = "domain"
    case ipCidr  = "ip_cidr"

    var displayName: String {
        switch self {
        case .geosite: "GeoSite"
        case .geoip:   "GeoIP"
        case .domain:  "Domain"
        case .ipCidr:  "IP CIDR"
        }
    }
}

// MARK: - DNS Rule

struct DNSRule: Identifiable, Codable, Sendable, Hashable {
    var id: UUID
    var ruleType: DNSRuleType
    var value: String
    var serverTag: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        ruleType: DNSRuleType,
        value: String,
        serverTag: String,
        isEnabled: Bool = true
    ) {
        self.id        = id
        self.ruleType  = ruleType
        self.value     = value
        self.serverTag = serverTag
        self.isEnabled = isEnabled
    }
}

// MARK: - DNS Strategy

enum DNSStrategy: String, Codable, Sendable, CaseIterable {
    case preferIPv4 = "prefer_ipv4"
    case preferIPv6 = "prefer_ipv6"
    case ipv4Only   = "ipv4_only"
    case ipv6Only   = "ipv6_only"

    var displayName: String {
        switch self {
        case .preferIPv4: String(localized: "Prefer IPv4")
        case .preferIPv6: String(localized: "Prefer IPv6")
        case .ipv4Only:   String(localized: "IPv4 Only")
        case .ipv6Only:   String(localized: "IPv6 Only")
        }
    }
}

// MARK: - FakeIP Config

struct FakeIPConfig: Codable, Sendable, Hashable {
    var isEnabled: Bool
    var inet4Range: String
    var inet6Range: String

    init(isEnabled: Bool = false, inet4Range: String = "198.18.0.0/15", inet6Range: String = "fc00::/18") {
        self.isEnabled  = isEnabled
        self.inet4Range = inet4Range
        self.inet6Range = inet6Range
    }
}

// MARK: - DNS Config

struct DNSConfig: Codable, Sendable, Hashable {
    var servers: [DNSServer]
    var rules: [DNSRule]
    var strategy: DNSStrategy
    var finalServer: String
    var fakeIP: FakeIPConfig

    init(
        servers: [DNSServer]   = DNSConfig.defaultServers,
        rules: [DNSRule]       = DNSConfig.defaultRules,
        strategy: DNSStrategy  = .preferIPv4,
        finalServer: String    = "google",
        fakeIP: FakeIPConfig   = FakeIPConfig()
    ) {
        self.servers     = servers
        self.rules       = rules
        self.strategy    = strategy
        self.finalServer = finalServer
        self.fakeIP      = fakeIP
    }

    static let `default` = DNSConfig()

    static let defaultServers: [DNSServer] = [
        DNSServer(tag: "google", address: "8.8.8.8"),
        DNSServer(tag: "local",  address: "local", detour: "direct")
    ]

    static let defaultRules: [DNSRule] = [
        DNSRule(ruleType: .geosite, value: "cn", serverTag: "local")
    ]
}
