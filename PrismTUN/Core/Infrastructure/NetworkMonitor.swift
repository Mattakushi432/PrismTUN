import Foundation
import Network

@Observable
final class NetworkMonitor: @unchecked Sendable {
    private(set) var isConnected: Bool = true
    private(set) var connectionType: ConnectionType = .unknown

    private let monitor: NWPathMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.prismtun.network-monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = ConnectionType(path: path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }

    enum ConnectionType: Sendable {
        case wifi, cellular, ethernet, unknown

        init(path: NWPath) {
            if path.usesInterfaceType(.wifi)     { self = .wifi }
            else if path.usesInterfaceType(.cellular) { self = .cellular }
            else if path.usesInterfaceType(.wiredEthernet) { self = .ethernet }
            else { self = .unknown }
        }
    }
}
