import SwiftUI

struct ContentView: View {
    @Environment(VPNManager.self) private var vpnManager
    @State private var selectedTab: Tab = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            switch selectedTab {
            case .dashboard: DashboardView()
            case .profiles:  ProfileListView()
            case .routing:   RoutingView()
            case .logs:      LogsView()
            case .settings:  SettingsView()
            }
        }
        .navigationTitle("PrismTUN")
    }

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case profiles  = "Profiles"
        case routing   = "Routing"
        case logs      = "Logs"
        case settings  = "Settings"

        var icon: String {
            switch self {
            case .dashboard: "gauge.with.dots.needle.67percent"
            case .profiles:  "server.rack"
            case .routing:   "arrow.triangle.branch"
            case .logs:      "doc.text"
            case .settings:  "gear"
            }
        }
    }
}

private struct SidebarView: View {
    @Binding var selectedTab: ContentView.Tab
    @Environment(VPNManager.self) private var vpnManager

    var body: some View {
        List(ContentView.Tab.allCases, id: \.self, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
        .safeAreaInset(edge: .bottom) {
            ConnectionBadge()
                .padding()
        }
    }
}

private struct ConnectionBadge: View {
    @Environment(VPNManager.self) private var vpnManager

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(vpnManager.isConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(vpnManager.status.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
