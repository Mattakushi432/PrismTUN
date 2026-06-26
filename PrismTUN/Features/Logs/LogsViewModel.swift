import Foundation
import Observation

@Observable
@MainActor
final class LogsViewModel {
    var filterLevel: LogLevel = .debug
    var searchText: String = ""

    private let store: LogStore

    init(store: LogStore) {
        self.store = store
    }

    var filtered: [LogEntry] {
        store.entries.filter { entry in
            entry.level >= filterLevel &&
            (searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText))
        }
    }

    func clear() { store.clear() }

    func exportText() -> String { store.exportText() }
}
