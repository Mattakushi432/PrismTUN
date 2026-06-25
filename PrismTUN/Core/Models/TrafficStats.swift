import Foundation

struct TrafficStats: Sendable {
    var uploadBytes: Int64
    var downloadBytes: Int64
    var uploadSpeed: Int64    // bytes/s
    var downloadSpeed: Int64  // bytes/s

    static let zero = TrafficStats(uploadBytes: 0, downloadBytes: 0, uploadSpeed: 0, downloadSpeed: 0)

    var uploadFormatted: String        { formatBytes(uploadBytes) }
    var downloadFormatted: String      { formatBytes(downloadBytes) }
    var uploadSpeedFormatted: String   { "\(formatBytes(uploadSpeed))/s" }
    var downloadSpeedFormatted: String { "\(formatBytes(downloadSpeed))/s" }

    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1_024
        let mb = kb / 1_024
        let gb = mb / 1_024
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        if mb >= 1 { return String(format: "%.2f MB", mb) }
        if kb >= 1 { return String(format: "%.1f KB", kb) }
        return "\(bytes) B"
    }
}

/// Decodable from sing-box /traffic SSE JSON: {"up": N, "down": N}
struct TrafficPayload: Decodable {
    let up: Int64
    let down: Int64
}
