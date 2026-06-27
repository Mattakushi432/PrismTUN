import SwiftUI

struct ConnectionsView: View {
    @Environment(VPNManager.self) private var vpnManager
    @State private var viewModel: ConnectionsViewModel?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            contentArea
        }
        .navigationTitle(String(localized: "Connections"))
        .task {
            if viewModel == nil {
                viewModel = ConnectionsViewModel(vpnManager: vpnManager)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            TextField(String(localized: "Filter by host or process"), text: Binding(
                get: { viewModel?.searchText ?? "" },
                set: { viewModel?.searchText = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 300)
            .disabled(viewModel == nil)

            Spacer()

            Text(countLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(String(localized: "Close All")) { viewModel?.closeAll() }
                .buttonStyle(.bordered)
                .disabled(viewModel?.filtered.isEmpty != false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var countLabel: String {
        guard let vm = viewModel else { return "" }
        let total = vpnManager.connectionStore.connections.count
        let shown = vm.filtered.count
        return shown == total
            ? String(localized: "\(total) connection(s)")
            : String(localized: "\(shown) / \(total)")
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if let vm = viewModel {
            if !vpnManager.isConnected {
                emptyState(
                    icon: "network.slash",
                    message: String(localized: "Connect to see active connections")
                )
            } else if vm.filtered.isEmpty {
                emptyState(
                    icon: "checkmark.circle",
                    message: String(localized: "No active connections")
                )
            } else {
                connectionsTable(vm: vm)
            }
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Table

    private func connectionsTable(vm: ConnectionsViewModel) -> some View {
        Table(vm.filtered) {
            TableColumn(String(localized: "Host")) { conn in
                VStack(alignment: .leading, spacing: 2) {
                    Text(conn.displayHost)
                        .lineLimit(1)
                    if !conn.displayProcess.isEmpty {
                        Text(conn.displayProcess)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            TableColumn(String(localized: "Net")) { conn in
                NetworkBadge(network: conn.displayNetwork)
            }
            .width(50)

            TableColumn(String(localized: "Rule")) { conn in
                Text(conn.ruleMatched)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            TableColumn("↑") { conn in
                Text(Self.formatBytes(conn.upload))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(72)

            TableColumn("↓") { conn in
                Text(Self.formatBytes(conn.download))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(72)

            TableColumn(String(localized: "Duration")) { conn in
                Text(Self.formatDuration(conn.duration))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(72)

            TableColumn("") { conn in
                Button(String(localized: "Close")) {
                    vm.closeConnection(id: conn.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .width(56)
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
    }

    // MARK: - Formatters

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        f.allowsNonnumericFormatting = false
        return f
    }()

    private static func formatBytes(_ bytes: Int) -> String {
        byteFormatter.string(fromByteCount: Int64(bytes))
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let s = Int(duration)
        if s < 60   { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m\(s % 60)s" }
        return "\(s / 3600)h\(s % 3600 / 60)m"
    }
}

// MARK: - Network Badge

private struct NetworkBadge: View {
    let network: String

    private var isTCP: Bool { network.lowercased() == "tcp" }

    var body: some View {
        Text(network.uppercased())
            .font(.caption2.bold())
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(isTCP ? Color.blue.opacity(0.12) : Color.green.opacity(0.12))
            .foregroundStyle(isTCP ? Color.blue : Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
