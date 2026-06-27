import XCTest

final class SubscriptionParserTests: XCTestCase {

    // MARK: - Fixture URIs

    private var ssURI: String {
        let creds = "aes-256-gcm:testpassword"
        let b64   = Data(creds.utf8).base64EncodedString()
        return "ss://\(b64)@ss.example.com:8388#Server1"
    }

    private let trojanURI = "trojan://tpass@trojan.example.com:443#Server2"

    // MARK: - Plain-text input

    func testParsePlainURIList() {
        let text     = [ssURI, trojanURI].joined(separator: "\n")
        let profiles = SubscriptionParser.parse(data: Data(text.utf8))

        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles[0].protocol, .shadowsocks)
        XCTAssertEqual(profiles[1].protocol, .trojan)
    }

    func testParsePlainWithBlankLinesAndSpaces() {
        let text     = "\n\(ssURI)\n\n\(trojanURI)\n"
        let profiles = SubscriptionParser.parse(data: Data(text.utf8))
        XCTAssertEqual(profiles.count, 2)
    }

    func testParsePlainSingleURI() {
        let profiles = SubscriptionParser.parse(data: Data(trojanURI.utf8))
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles[0].server, "trojan.example.com")
    }

    // MARK: - Base64-encoded input

    func testParseBase64EncodedList() {
        let text     = [ssURI, trojanURI].joined(separator: "\n")
        let b64      = Data(text.utf8).base64EncodedString()
        let profiles = SubscriptionParser.parse(data: Data(b64.utf8))

        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles[0].server, "ss.example.com")
        XCTAssertEqual(profiles[1].server, "trojan.example.com")
    }

    func testParseBase64WithLineBreaks() {
        let text = [ssURI, trojanURI].joined(separator: "\n")
        var b64  = Data(text.utf8).base64EncodedString()
        if b64.count > 76 {
            b64.insert("\n", at: b64.index(b64.startIndex, offsetBy: 76))
        }
        let profiles = SubscriptionParser.parse(data: Data(b64.utf8))
        XCTAssertEqual(profiles.count, 2)
    }

    func testParseURLSafeBase64() {
        let text = [ssURI, trojanURI].joined(separator: "\n")
        let b64  = Data(text.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        let profiles = SubscriptionParser.parse(data: Data(b64.utf8))
        XCTAssertEqual(profiles.count, 2)
    }

    // MARK: - Regex filters

    func testIncludeRegexKeepsMatches() {
        let text     = [ssURI, trojanURI].joined(separator: "\n")
        let profiles = SubscriptionParser.parse(data: Data(text.utf8), includeRegex: "Server1")
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles[0].name, "Server1")
    }

    func testExcludeRegexRemovesMatches() {
        let text     = [ssURI, trojanURI].joined(separator: "\n")
        let profiles = SubscriptionParser.parse(data: Data(text.utf8), excludeRegex: "Server1")
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles[0].name, "Server2")
    }

    func testIncludeAndExcludeCombine() {
        let text     = [ssURI, trojanURI].joined(separator: "\n")
        let profiles = SubscriptionParser.parse(data: Data(text.utf8),
                                                includeRegex: "Server",
                                                excludeRegex: "Server2")
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles[0].name, "Server1")
    }

    func testIncludeRegexMatchingNone() {
        let text     = [ssURI, trojanURI].joined(separator: "\n")
        let profiles = SubscriptionParser.parse(data: Data(text.utf8), includeRegex: "NoMatch")
        XCTAssertTrue(profiles.isEmpty)
    }

    func testExcludeRegexMatchingAll() {
        let text     = [ssURI, trojanURI].joined(separator: "\n")
        let profiles = SubscriptionParser.parse(data: Data(text.utf8), excludeRegex: "Server")
        XCTAssertTrue(profiles.isEmpty)
    }

    // MARK: - Edge cases

    func testEmptyDataReturnsNoProfiles() {
        XCTAssertTrue(SubscriptionParser.parse(data: Data()).isEmpty)
    }

    func testInvalidUTF8ReturnsNoProfiles() {
        let invalidData = Data([0xFF, 0xFE, 0x00, 0x01])
        XCTAssertTrue(SubscriptionParser.parse(data: invalidData).isEmpty)
    }

    func testNoValidURIsReturnsNoProfiles() {
        let text = "not a uri\njust some text\n12345"
        XCTAssertTrue(SubscriptionParser.parse(data: Data(text.utf8)).isEmpty)
    }

    // MARK: - base64Decode helper

    func testBase64DecodeStandard() {
        let original = "Hello, World!"
        let b64      = Data(original.utf8).base64EncodedString()
        XCTAssertEqual(SubscriptionParser.base64Decode(b64), original)
    }

    func testBase64DecodeURLSafe() {
        let original = String(repeating: "abc", count: 8)
        let b64      = Data(original.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        XCTAssertEqual(SubscriptionParser.base64Decode(b64), original)
    }

    func testBase64DecodeStripsNewlines() {
        let original = "test data"
        var b64      = Data(original.utf8).base64EncodedString()
        b64.insert("\n", at: b64.index(b64.startIndex, offsetBy: min(4, b64.count)))
        XCTAssertEqual(SubscriptionParser.base64Decode(b64), original)
    }

    func testBase64DecodeNoPaddingRequired() {
        let original = "test"
        var b64      = Data(original.utf8).base64EncodedString()
        while b64.hasSuffix("=") { b64.removeLast() }
        XCTAssertEqual(SubscriptionParser.base64Decode(b64), original)
    }

    func testBase64DecodeInvalidReturnsNil() {
        XCTAssertNil(SubscriptionParser.base64Decode("@@@invalid@@@"))
    }

    func testBase64DecodeEmptyString() {
        let result = SubscriptionParser.base64Decode("")
        XCTAssertNotNil(result)
        XCTAssertEqual(result, "")
    }
}
