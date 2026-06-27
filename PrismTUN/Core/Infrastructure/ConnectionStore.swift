import Foundation
import Observation

@Observable
@MainActor
final class ConnectionStore {
    private(set) var connections: [ActiveConnection] = []

    func update(_ newConnections: [ActiveConnection]) {
        connections = newConnections
    }

    func clear() {
        connections = []
    }
}
