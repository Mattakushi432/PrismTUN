import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LogsView: View {
    @Environment(VPNManager.self) private var vpnManager
    @State private var viewModel: LogsViewModel?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if let vm = viewModel {
                logList(vm: vm)
            } else {
                emptyState
            }
        }
        .navigationTitle(String(localized: "Logs"))
        .task {
            if viewModel == nil {
                viewModel = LogsViewModel(store: vpnManager.logStore)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            TextField(String(localized: "Search"), text: Binding(
                get: { viewModel?.searchText ?? "" },
                set: { viewModel?.searchText = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 260)
            .disabled(viewModel == nil)

            Picker(String(localized: "Level"), selection: Binding(
                get: { viewModel?.filterLevel ?? .debug },
                set: { viewModel?.filterLevel = $0 }
            )) {
                ForEach([LogLevel.debug, .info, .warning, .error], id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            .disabled(viewModel == nil)

            Spacer()

            Button(String(localized: "Export Logs")) { exportLogs() }
                .buttonStyle(.bordered)
                .disabled(viewModel?.filtered.isEmpty != false)

            Button(String(localized: "Clear")) { viewModel?.clear() }
                .buttonStyle(.bordered)
                .disabled(viewModel == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text(String(localized: "Connect to start streaming logs"))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func logList(vm: LogsViewModel) -> some View {
        ScrollViewReader { proxy in
            List(vm.filtered) { entry in
                LogRow(entry: entry)
                    .id(entry.id)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 1, leading: 12, bottom: 1, trailing: 12))
            }
            .listStyle(.plain)
            .font(.system(.caption, design: .monospaced))
            .onChange(of: vm.filtered.count) {
                if let last = vm.filtered.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func exportLogs() {
        guard let vm = viewModel else { return }
        let text = vm.exportText()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "prismtun-logs.txt"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

private struct LogRow: View {
    let entry: LogEntry

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Self.formatter.string(from: entry.timestamp))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(entry.level.displayName)
                .frame(width: 40, alignment: .leading)
                .foregroundStyle(levelColor)
                .fontWeight(.medium)

            Text(entry.message)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug:   .secondary
        case .info:    .primary
        case .warning: .orange
        case .error:   .red
        }
    }
}
