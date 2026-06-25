import SwiftUI

struct LogsView: View {
    @State private var viewModel = LogsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            logList
        }
        .navigationTitle("Logs")
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            TextField("Search", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)

            Picker("Level", selection: $viewModel.filterLevel) {
                ForEach([LogLevel.debug, .info, .warning, .error], id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            Spacer()

            Button("Clear") { viewModel.clear() }
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            List(viewModel.filtered) { entry in
                LogRow(entry: entry)
                    .id(entry.id)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 1, leading: 12, bottom: 1, trailing: 12))
            }
            .listStyle(.plain)
            .font(.system(.caption, design: .monospaced))
            .onChange(of: viewModel.filtered.count) {
                if let last = viewModel.filtered.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
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
