import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(VPNManager.self) private var vpnManager
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                DashboardContent(viewModel: vm)
            }
        }
        .task {
            guard viewModel == nil else { return }
            let vm = DashboardViewModel(vpnManager: vpnManager)
            viewModel = vm
            vm.startUpdating()
        }
        .onDisappear { viewModel?.stopUpdating() }
    }
}

private struct DashboardContent: View {
    let viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                StatusCard(viewModel: viewModel)
                StatsRow(stats: viewModel.stats)
                SpeedChart(history: viewModel.speedHistory)
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
    }
}

// MARK: - Status Card

private struct StatusCard: View {
    let viewModel: DashboardViewModel

    var body: some View {
        GroupBox {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.status.displayName)
                            .font(.title2.bold())
                        Text("Profile: \(viewModel.activeProfileName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.red)
                        .frame(width: 14, height: 14)
                        .shadow(color: viewModel.isConnected ? .green : .red, radius: 4)
                }

                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    ForEach(ConnectionMode.allCases, id: \.self) { mode in
                        ModeButton(
                            mode: mode,
                            isActive: viewModel.connectionMode == mode,
                            action: { Task { await viewModel.setMode(mode) } }
                        )
                    }
                }

                HStack(spacing: 12) {
                    switch viewModel.status {
                    case .connecting:
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(String(localized: "Connecting…"))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    case .connected:
                        Button(role: .destructive) {
                            Task { await viewModel.disconnect() }
                        } label: {
                            Label(String(localized: "Disconnect"), systemImage: "stop.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .buttonStyle(.bordered)
                    default:
                        Button {
                            Task { await viewModel.connect() }
                        } label: {
                            Label(String(localized: "Connect"), systemImage: "play.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(8)
        }
    }
}

private struct ModeButton: View {
    let mode: ConnectionMode
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(mode.displayName)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isActive ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats Row

private struct StatsRow: View {
    let stats: TrafficStats

    var body: some View {
        HStack(spacing: 16) {
            StatCell(title: "↑ Upload",   value: stats.uploadFormatted,       detail: stats.uploadSpeedFormatted)
            StatCell(title: "↓ Download", value: stats.downloadFormatted, detail: stats.downloadSpeedFormatted)
        }
    }
}

private struct StatCell: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        GroupBox(label: Text(title).font(.caption).foregroundStyle(.secondary)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.monospacedDigit().bold())
                Text(detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }
}

// MARK: - Speed Chart

private struct SpeedChart: View {
    let history: [(upload: Double, download: Double)]

    private var chartData: [ChartPoint] {
        history.enumerated().flatMap { i, pair in
            [ChartPoint(index: i, value: pair.upload,   kind: "Upload"),
             ChartPoint(index: i, value: pair.download, kind: "Download")]
        }
    }

    var body: some View {
        GroupBox("Speed (60s)") {
            Chart(chartData) { point in
                AreaMark(
                    x: .value("Time", point.index),
                    y: .value("Bytes/s", point.value)
                )
                .foregroundStyle(by: .value("Kind", point.kind))
                .opacity(0.6)
            }
            .chartForegroundStyleScale(["Upload": Color.orange, "Download": Color.blue])
            .chartLegend(position: .top, alignment: .trailing)
            .frame(height: 160)
            .padding(.top, 4)
        }
    }

    struct ChartPoint: Identifiable {
        let id = UUID()
        let index: Int
        let value: Double
        let kind: String
    }
}
