import SwiftUI

@main
struct PrismTUNApp: App {
    @State private var profileManager:      ProfileManager
    @State private var vpnManager:          VPNManager
    @State private var subscriptionManager: SubscriptionManager
    @State private var routingViewModel:    RoutingViewModel
    @State private var menuBarController:   MenuBarController?

    init() {
        let pm = ProfileManager()
        let vm = VPNManager(profileManager: pm)
        let sm = SubscriptionManager(profileManager: pm)
        let rv = RoutingViewModel(vpnManager: vm)
        _profileManager      = State(initialValue: pm)
        _vpnManager          = State(initialValue: vm)
        _subscriptionManager = State(initialValue: sm)
        _routingViewModel    = State(initialValue: rv)
        _menuBarController   = State(initialValue: MenuBarController(vpnManager: vm))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(profileManager)
                .environment(vpnManager)
                .environment(subscriptionManager)
                .environment(routingViewModel)
                .frame(minWidth: 800, minHeight: 560)
                .task {
                    await profileManager.load()
                    await subscriptionManager.load()
                    await routingViewModel.load()
                }
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
                .environment(profileManager)
                .environment(vpnManager)
                .environment(subscriptionManager)
                .environment(routingViewModel)
        }
    }
}
