import XCTest

final class RoutingRuleTests: XCTestCase {

    // MARK: - RuleType raw values

    func testRuleTypeRawValues() {
        XCTAssertEqual(RuleType.domain.rawValue,        "domain")
        XCTAssertEqual(RuleType.domainSuffix.rawValue,  "domain_suffix")
        XCTAssertEqual(RuleType.domainKeyword.rawValue, "domain_keyword")
        XCTAssertEqual(RuleType.domainRegex.rawValue,   "domain_regex")
        XCTAssertEqual(RuleType.ipCidr.rawValue,        "ip_cidr")
        XCTAssertEqual(RuleType.port.rawValue,          "port")
        XCTAssertEqual(RuleType.portRange.rawValue,     "port_range")
        XCTAssertEqual(RuleType.processName.rawValue,   "process_name")
        XCTAssertEqual(RuleType.processPath.rawValue,   "process_path")
        XCTAssertEqual(RuleType.network.rawValue,       "network")
        XCTAssertEqual(RuleType.geosite.rawValue,       "geosite")
        XCTAssertEqual(RuleType.geoip.rawValue,         "geoip")
        XCTAssertEqual(RuleType.sourceIpCidr.rawValue,  "source_ip_cidr")
        XCTAssertEqual(RuleType.user.rawValue,          "user")
        XCTAssertEqual(RuleType.clashMode.rawValue,     "clash_mode")
    }

    func testRuleTypeAllCasesCount() {
        XCTAssertEqual(RuleType.allCases.count, 15)
    }

    func testRuleTypeCodableRoundtrip() throws {
        for ruleType in RuleType.allCases {
            let data    = try JSONEncoder().encode(ruleType)
            let decoded = try JSONDecoder().decode(RuleType.self, from: data)
            XCTAssertEqual(decoded, ruleType, "Codable roundtrip failed for \(ruleType)")
        }
    }

    // MARK: - RuleOutbound raw values

    func testRuleOutboundRawValues() {
        XCTAssertEqual(RuleOutbound.proxy.rawValue,  "proxy")
        XCTAssertEqual(RuleOutbound.direct.rawValue, "direct")
        XCTAssertEqual(RuleOutbound.block.rawValue,  "block")
    }

    func testRuleOutboundAllCasesCount() {
        XCTAssertEqual(RuleOutbound.allCases.count, 3)
    }

    // MARK: - RoutingRule init

    func testRoutingRuleInit() {
        let id   = UUID()
        let rule = RoutingRule(
            id: id,
            name: "Block Ads",
            notes: "Blocks ad domains",
            type: .geosite,
            value: "category-ads-all",
            outbound: .block,
            isEnabled: true
        )
        XCTAssertEqual(rule.id,       id)
        XCTAssertEqual(rule.name,     "Block Ads")
        XCTAssertEqual(rule.notes,    "Blocks ad domains")
        XCTAssertEqual(rule.type,     .geosite)
        XCTAssertEqual(rule.value,    "category-ads-all")
        XCTAssertEqual(rule.outbound, .block)
        XCTAssertTrue(rule.isEnabled)
    }

    func testRoutingRuleDefaultsEnabledWithEmptyNotes() {
        let rule = RoutingRule(name: "Test", type: .domain, value: "example.com", outbound: .proxy)
        XCTAssertTrue(rule.isEnabled)
        XCTAssertTrue(rule.notes.isEmpty)
    }

    func testRoutingRuleDisabledInit() {
        let rule = RoutingRule(name: "Off", type: .domain, value: "test.com",
                               outbound: .direct, isEnabled: false)
        XCTAssertFalse(rule.isEnabled)
    }

    // MARK: - Codable roundtrip

    func testRoutingRuleCodableRoundtrip() throws {
        let original = RoutingRule(
            name: "CN Bypass",
            notes: "Bypass Chinese domains",
            type: .geoip,
            value: "cn",
            outbound: .direct,
            isEnabled: true
        )
        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RoutingRule.self, from: data)

        XCTAssertEqual(decoded.id,        original.id)
        XCTAssertEqual(decoded.name,      original.name)
        XCTAssertEqual(decoded.notes,     original.notes)
        XCTAssertEqual(decoded.type,      original.type)
        XCTAssertEqual(decoded.value,     original.value)
        XCTAssertEqual(decoded.outbound,  original.outbound)
        XCTAssertEqual(decoded.isEnabled, original.isEnabled)
    }

    func testRoutingRuleDecoderDefaultsForLegacyJSON() throws {
        // Old JSON missing `notes` and `isEnabled` — custom decoder provides defaults
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name": "Old Rule",
            "type": "domain",
            "value": "example.com",
            "outbound": "proxy"
        }
        """
        let rule = try JSONDecoder().decode(RoutingRule.self, from: Data(json.utf8))
        XCTAssertEqual(rule.name,    "Old Rule")
        XCTAssertEqual(rule.notes,   "")    // default
        XCTAssertTrue(rule.isEnabled)       // default
        XCTAssertEqual(rule.type,    .domain)
        XCTAssertEqual(rule.outbound, .proxy)
    }

    func testRoutingRuleDisabledIsPersistedInJSON() throws {
        let rule    = RoutingRule(name: "Disabled", type: .domain,
                                  value: "example.com", outbound: .block, isEnabled: false)
        let data    = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(RoutingRule.self, from: data)
        XCTAssertFalse(decoded.isEnabled)
    }

    func testAllRuleTypesRoundtripThroughJSON() throws {
        for type_ in RuleType.allCases {
            let rule    = RoutingRule(name: "r", type: type_, value: "v", outbound: .proxy)
            let data    = try JSONEncoder().encode(rule)
            let decoded = try JSONDecoder().decode(RoutingRule.self, from: data)
            XCTAssertEqual(decoded.type, type_, "JSON roundtrip failed for RuleType.\(type_)")
        }
    }

    func testAllOutboundValuesRoundtripThroughJSON() throws {
        for outbound in RuleOutbound.allCases {
            let rule    = RoutingRule(name: "r", type: .domain, value: "v", outbound: outbound)
            let data    = try JSONEncoder().encode(rule)
            let decoded = try JSONDecoder().decode(RoutingRule.self, from: data)
            XCTAssertEqual(decoded.outbound, outbound,
                           "JSON roundtrip failed for RuleOutbound.\(outbound)")
        }
    }

    // MARK: - Hashable / Equatable

    func testEqualWhenSameUUIDAndFields() {
        let id = UUID()
        let r1 = RoutingRule(id: id, name: "Same", type: .domain, value: "a.com", outbound: .proxy)
        let r2 = RoutingRule(id: id, name: "Same", type: .domain, value: "a.com", outbound: .proxy)
        XCTAssertEqual(r1, r2)
    }

    func testNotEqualWhenDifferentUUID() {
        let r1 = RoutingRule(name: "Rule", type: .domain, value: "example.com", outbound: .proxy)
        let r2 = RoutingRule(name: "Rule", type: .domain, value: "example.com", outbound: .proxy)
        XCTAssertNotEqual(r1, r2)
    }

    func testCanBeUsedInSet() {
        let id = UUID()
        let r1 = RoutingRule(id: id, name: "R", type: .domain,  value: "a.com", outbound: .proxy)
        let r2 = RoutingRule(id: id, name: "R", type: .domain,  value: "a.com", outbound: .proxy)
        let r3 = RoutingRule(name: "Other",      type: .geoip,  value: "cn",    outbound: .direct)
        let set = Set([r1, r2, r3])
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Sendable conformance (compile-time verification)

    func testSendableConformance() {
        let rule: Sendable = RoutingRule(name: "T", type: .domain, value: "a.com", outbound: .proxy)
        XCTAssertNotNil(rule)
    }
}
