import Foundation
import Observation

@Observable
@MainActor
final class LogStore {
    private static let maxEntries = 5_000

    private(set) var entries: [LogEntry] = []

    func append(_ entry: LogEntry) {
        entries.append(entry)
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }

    func exportText() -> String {
        let formatter = ISO8601DateFormatter()
        return entries
            .map { "[\(formatter.string(from: $0.timestamp))] [\($0.level.displayName)] \($0.message)" }
            .joined(separator: "\n")
    }
}
