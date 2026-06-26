import Foundation

enum RulePresets {
    static var bypassChina: [RoutingRule] {
        [
            RoutingRule(name: "GeoSite: CN", type: .geosite, value: "cn",  outbound: .direct),
            RoutingRule(name: "GeoIP: CN",   type: .geoip,   value: "cn",  outbound: .direct),
        ]
    }

    static var bypassLAN: [RoutingRule] {
        [
            RoutingRule(name: "LAN 192.168.x.x",   type: .ipCidr, value: "192.168.0.0/16", outbound: .direct),
            RoutingRule(name: "LAN 10.x.x.x",      type: .ipCidr, value: "10.0.0.0/8",     outbound: .direct),
            RoutingRule(name: "LAN 172.16-31.x.x", type: .ipCidr, value: "172.16.0.0/12",  outbound: .direct),
            RoutingRule(name: "Loopback",           type: .ipCidr, value: "127.0.0.0/8",    outbound: .direct),
        ]
    }

    static var blockAds: [RoutingRule] {
        [
            RoutingRule(name: "Block Ads (category-ads-all)", type: .geosite, value: "category-ads-all", outbound: .block),
        ]
    }
}
