import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(VPNManager.self)     private var vpnManager
    @Environment(ProfileManager.self) private var profileManager
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                DashboardContent(viewModel: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil else { return }
            let vm = DashboardViewModel(vpnManager: vpnManager, profileManager: profileManager)
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
            if !viewModel.hasProfiles {
                OnboardingPrompt()
            } else {
                connectedContent
            }
        }
    }

    @ViewBuilder
    private var connectedContent: some View {
        VStack(spacing: 16) {
            // ── Header: status + indicator ──
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.status.displayName)
                        .font(.title2.bold())
                    if viewModel.activeProfileID == nil {
                        Text("No profile selected")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    } else {
                        Text(viewModel.activeProfileName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.gray)
                    .frame(width: 14, height: 14)
                    .shadow(color: viewModel.isConnected ? .green : .clear, radius: 4)
            }

            // ── Profile picker ──
            ProfilePickerRow(viewModel: viewModel)

            if let err = viewModel.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // ── Mode selector ──
            HStack(spacing: 8) {
                ForEach(ConnectionMode.allCases, id: \.self) { mode in
                    ModeButton(
                        mode: mode,
                        isActive: viewModel.connectionMode == mode,
                        action: { Task { await viewModel.setMode(mode) } }
                    )
                }
            }

            // ── Connect / Disconnect ──
            connectButton
        }
        .padding(8)
    }

    @ViewBuilder
    private var connectButton: some View {
        switch viewModel.status {
        case .connecting:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(String(localized: "Connecting…")).foregroundStyle(.secondary)
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
            .disabled(viewModel.activeProfileID == nil)
        }
    }
}

// MARK: - Onboarding prompt (no profiles)

private struct OnboardingPrompt: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("No Proxy Profiles")
                    .font(.headline)
                Text("Add a profile to get started. You can create a SOCKS5, HTTP, Shadowsocks, VMess, VLESS, Trojan, or WireGuard proxy — or import a subscription link.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                Button {
                    NotificationCenter.default.post(name: .newProfileRequested, object: nil)
                } label: {
                    Label("Add Profile", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Tip: For a local proxy (e.g. sing-box, Clash, v2ray running on this Mac), use host 127.0.0.1 with the listening port.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Profile picker row

private struct ProfilePickerRow: View {
    let viewModel: DashboardViewModel

    private var pickerBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.activeProfileID },
            set: { id in
                guard let id else { return }
                Task { await viewModel.setActiveProfile(id: id) }
            }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "server.rack")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Picker("Profile", selection: pickerBinding) {
                Text("Select a profile…").tag(Optional<UUID>.none)
                ForEach(viewModel.profiles) { profile in
                    Text(profile.name.isEmpty ? "\(profile.protocol.displayName) · \(profile.server):\(profile.port)" : profile.name)
                        .tag(Optional(profile.id))
                }
            }
            .labelsHidden()
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
                .foregroundStyle(isActive ? .white : (mode.isAvailable ? .primary : .secondary))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!mode.isAvailable)
        .help(mode.isAvailable ? mode.description : mode.description)
        .opacity(mode.isAvailable ? 1 : 0.5)
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
