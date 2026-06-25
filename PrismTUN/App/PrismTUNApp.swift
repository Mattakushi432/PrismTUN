import SwiftUI

@main
struct PrismTUNApp: App {
    @State private var profileManager = ProfileManager()
    @State private var vpnManager: VPNManager
    @State private var menuBarController: MenuBarController?

    init() {
        let pm = ProfileManager()
        let vm = VPNManager(profileManager: pm)
        _profileManager = State(initialValue: pm)
        _vpnManager     = State(initialValue: vm)
    }

    var body: some Scene {
        // Main panel window (hidden from Dock via LSUIElement = YES in Info.plist)
        WindowGroup {
            ContentView()
                .environment(profileManager)
                .environment(vpnManager)
                .frame(minWidth: 800, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)

        // Settings window
        Settings {
            SettingsView()
                .environment(profileManager)
                .environment(vpnManager)
        }
    }
}
