import Foundation

struct ConnectionMetadata: Codable, Sendable {
    let network: String
    let type: String?
    let sourceIP: String?
    let destinationPort: String?
    let host: String?
    let sniffHost: String?
    let process: String?
    let processPath: String?
}

struct ActiveConnection: Identifiable, Sendable {
    let id: String
    let metadata: ConnectionMetadata
    let upload: Int
    let download: Int
    let start: Date
    let chains: [String]
    let rule: String
    let rulePayload: String
}

extension ActiveConnection: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, metadata, upload, download, start, chains, rule, rulePayload
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(String.self, forKey: .id)
        metadata = try c.decode(ConnectionMetadata.self, forKey: .metadata)
        upload   = try c.decode(Int.self, forKey: .upload)
        download = try c.decode(Int.self, forKey: .download)
        chains   = try c.decode([String].self, forKey: .chains)
        rule         = try c.decodeIfPresent(String.self, forKey: .rule)        ?? ""
        rulePayload  = try c.decodeIfPresent(String.self, forKey: .rulePayload) ?? ""

        let raw = try c.decode(String.self, forKey: .start)
        // sing-box may emit nanoseconds (9 digits) — try fractional first, fall back to plain.
        let fmtFrac = ISO8601DateFormatter()
        fmtFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fmtPlain = ISO8601DateFormatter()
        fmtPlain.formatOptions = [.withInternetDateTime]
        start = fmtFrac.date(from: raw) ?? fmtPlain.date(from: raw) ?? Date()
    }
}

extension ActiveConnection {
    var displayHost: String {
        let h = metadata.host ?? ""
        if !h.isEmpty { return h }
        let sniff = metadata.sniffHost ?? ""
        return sniff.isEmpty ? (metadata.destinationPort ?? "") : sniff
    }

    var displayProcess: String {
        if let p = metadata.process, !p.isEmpty { return p }
        if let path = metadata.processPath, !path.isEmpty {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return ""
    }

    var displayNetwork: String { metadata.network }

    var ruleMatched: String {
        rulePayload.isEmpty ? rule : "\(rule) → \(rulePayload)"
    }

    var duration: TimeInterval { Date().timeIntervalSince(start) }
}

struct ConnectionsPayload: Codable, Sendable {
    let connections: [ActiveConnection]?
    let downloadTotal: Int?
    let uploadTotal: Int?
}
