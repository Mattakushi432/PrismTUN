import Foundation

/// Pure parsing logic extracted from SubscriptionManager for independent testability.
enum SubscriptionParser {
    /// Parses proxy profiles from raw subscription data.
    /// Tries base64-decoded URI list first, then falls back to plain-text newline-separated URIs.
    static func parse(
        data: Data,
        includeRegex: String = "",
        excludeRegex: String = ""
    ) -> [ProxyProfile] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let decoded = base64Decode(trimmed) {
            let profiles = ProxyProfile.batchParse(text: decoded)
            if !profiles.isEmpty {
                return applyFilters(profiles, includeRegex: includeRegex, excludeRegex: excludeRegex)
            }
        }

        let profiles = ProxyProfile.batchParse(text: text)
        return applyFilters(profiles, includeRegex: includeRegex, excludeRegex: excludeRegex)
    }

    static func base64Decode(_ string: String) -> String? {
        var padded = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        while padded.count % 4 != 0 { padded += "=" }
        guard let d = Data(base64Encoded: padded) else { return nil }
        return String(data: d, encoding: .utf8)
    }

    private static func applyFilters(
        _ profiles: [ProxyProfile],
        includeRegex: String,
        excludeRegex: String
    ) -> [ProxyProfile] {
        var result = profiles
        if !includeRegex.isEmpty,
           let regex = try? NSRegularExpression(pattern: includeRegex) {
            result = result.filter {
                let range = NSRange($0.name.startIndex..., in: $0.name)
                return regex.firstMatch(in: $0.name, range: range) != nil
            }
        }
        if !excludeRegex.isEmpty,
           let regex = try? NSRegularExpression(pattern: excludeRegex) {
            result = result.filter {
                let range = NSRange($0.name.startIndex..., in: $0.name)
                return regex.firstMatch(in: $0.name, range: range) == nil
            }
        }
        return result
    }
}
