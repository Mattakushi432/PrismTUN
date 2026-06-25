import Foundation

struct LogEntry: Identifiable, Sendable {
    let id: UUID = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
}

enum LogLevel: String, Sendable, Comparable {
    case debug   = "debug"
    case info    = "info"
    case warning = "warn"
    case error   = "error"

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.severity < rhs.severity
    }

    private var severity: Int {
        switch self {
        case .debug:   0
        case .info:    1
        case .warning: 2
        case .error:   3
        }
    }

    var displayName: String {
        switch self {
        case .debug:   "DEBUG"
        case .info:    "INFO"
        case .warning: "WARN"
        case .error:   "ERROR"
        }
    }

    var color: String {
        switch self {
        case .debug:   "gray"
        case .info:    "primary"
        case .warning: "orange"
        case .error:   "red"
        }
    }
}

// Decodable from sing-box /logs SSE JSON
struct LogPayload: Decodable {
    let type: String
    let payload: String

    var level: LogLevel { LogLevel(rawValue: type) ?? .info }
}
