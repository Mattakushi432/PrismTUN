import SwiftUI

extension Notification.Name {
    static let showAbout         = Notification.Name("PrismTUN.showAbout")
    static let newProfileRequested = Notification.Name("PrismTUN.newProfileRequested")
}

struct ContentView: View {
    @Environment(VPNManager.self) private var vpnManager
    @Environment(\.openWindow) private var openWindow
    @State private var selectedTab: Tab = .dashboard
    @State private var showAddProfileSheet = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            switch selectedTab {
            case .dashboard:    DashboardView()
            case .profiles:     ProfileListView(openAddSheet: $showAddProfileSheet)
            case .routing:      RoutingView()
            case .connections:  ConnectionsView()
            case .logs:         LogsView()
            case .settings:
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .navigationTitle("PrismTUN")
        .background(keyboardShortcuts)
        .onReceive(NotificationCenter.default.publisher(for: .showAbout)) { _ in
            openWindow(id: "about")
        }
        .onReceive(NotificationCenter.default.publisher(for: .newProfileRequested)) { _ in
            selectedTab = .profiles
            showAddProfileSheet = true
        }
    }

    private var keyboardShortcuts: some View {
        Group {
            ForEach(Array(ContentView.Tab.allCases.enumerated()), id: \.offset) { idx, tab in
                Button("") { selectedTab = tab }
                    .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")), modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
            }
            Button("") {
                if vpnManager.isConnected {
                    Task { await vpnManager.disconnect() }
                } else {
                    Task { await vpnManager.connect() }
                }
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
        }
    }

    enum Tab: String, CaseIterable {
        case dashboard   = "Dashboard"
        case profiles    = "Profiles"
        case routing     = "Routing"
        case connections = "Connections"
        case logs        = "Logs"
        case settings    = "Settings"

        var icon: String {
            switch self {
            case .dashboard:   "gauge.with.dots.needle.67percent"
            case .profiles:    "server.rack"
            case .routing:     "arrow.triangle.branch"
            case .connections: "network"
            case .logs:        "doc.text"
            case .settings:    "gear"
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
