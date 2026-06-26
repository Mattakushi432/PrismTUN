import Foundation
import Observation

@Observable
@MainActor
final class LogsViewModel {
    private(set) var entries: [LogEntry] = []
    var filterLevel: LogLevel = .debug
    var searchText: String = ""

    var filtered: [LogEntry] {
        entries.filter { entry in
            entry.level >= filterLevel &&
            (searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText))
        }
    }

    func append(_ entry: LogEntry) {
        entries.append(entry)
        if entries.count > 2000 { entries.removeFirst(entries.count - 2000) }
    }

    func clear() { entries.removeAll() }
}
