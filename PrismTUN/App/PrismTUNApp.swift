import AppKit
import SwiftUI

@main
struct PrismTUNApp: App {
    @State private var profileManager:      ProfileManager
    @State private var vpnManager:          VPNManager
    @State private var subscriptionManager: SubscriptionManager
    @State private var routingViewModel:    RoutingViewModel
    @State private var dnsViewModel:        DNSViewModel
    @State private var geoAssetViewModel:   GeoAssetViewModel
    @State private var menuBarController:   MenuBarController?

    @AppStorage("appColorScheme") private var colorSchemeRaw = "system"
    @AppStorage("showInDock")     private var showInDock     = false

    init() {
        // Apply saved language preference before any localized strings load
        let savedLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        if savedLang != "system" {
            UserDefaults.standard.set([savedLang], forKey: "AppleLanguages")
        }

        let pm = ProfileManager()
        let vm = VPNManager(profileManager: pm)
        let sm = SubscriptionManager(profileManager: pm)
        let rv = RoutingViewModel(vpnManager: vm)
        let dv = DNSViewModel(vpnManager: vm)
        let gv = GeoAssetViewModel()
        _profileManager      = State(initialValue: pm)
        _vpnManager          = State(initialValue: vm)
        _subscriptionManager = State(initialValue: sm)
        _routingViewModel    = State(initialValue: rv)
        _dnsViewModel        = State(initialValue: dv)
        _geoAssetViewModel   = State(initialValue: gv)
        _menuBarController   = State(initialValue: MenuBarController(vpnManager: vm))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(profileManager)
                .environment(vpnManager)
                .environment(subscriptionManager)
                .environment(routingViewModel)
                .environment(dnsViewModel)
                .environment(geoAssetViewModel)
                .frame(minWidth: 800, minHeight: 560)
                .preferredColorScheme(resolvedColorScheme)
                .task {
                    // Restore dock icon visibility from saved preference (LSUIElement starts app as .accessory)
                    NSApp.setActivationPolicy(showInDock ? .regular : .accessory)

                    await profileManager.load()
                    await subscriptionManager.load()
                    await routingViewModel.load()
                    await dnsViewModel.load()

                    if UserDefaults.standard.bool(forKey: "geoAutoUpdate") {
                        await geoAssetViewModel.updateIfNeeded()
                    } else {
                        await geoAssetViewModel.load()
                    }

                    if UserDefaults.standard.bool(forKey: "autoConnect") {
                        await vpnManager.connect()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            NavigationStack {
                SettingsView()
            }
            .environment(profileManager)
            .environment(vpnManager)
            .environment(subscriptionManager)
            .environment(routingViewModel)
            .environment(dnsViewModel)
            .environment(geoAssetViewModel)
            .preferredColorScheme(resolvedColorScheme)
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}
