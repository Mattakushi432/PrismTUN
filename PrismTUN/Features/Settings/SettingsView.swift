import SwiftUI

struct SettingsView: View {
    @Environment(VPNManager.self) private var vpnManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoConnect")   private var autoConnect   = false
    @AppStorage("showInDock")    private var showInDock    = false
    @AppStorage("logLevel")      private var logLevel      = "info"

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                Toggle("Auto-Connect on Launch", isOn: $autoConnect)
                Toggle("Show in Dock", isOn: $showInDock)
            }

            Section("Proxy") {
                LabeledContent("Mixed Port") {
                    Text("\(SingBoxConfigBuilder.mixedPort)")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("API Port") {
                    Text("\(SingBoxConfigBuilder.apiPort)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("DNS") {
                NavigationLink(destination: DNSSettingsView()) {
                    Label(String(localized: "DNS Servers & Rules"), systemImage: "network.badge.shield.half.filled")
                }
            }

            Section("Logging") {
                Picker("Log Level", selection: $logLevel) {
                    ForEach(["debug", "info", "warn", "error"], id: \.self) {
                        Text($0.uppercased()).tag($0)
                    }
                }
            }

            Section("Danger Zone") {
                Button("Reset All Settings", role: .destructive) {
                    // TODO: clear UserDefaults domain
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 460, minHeight: 400)
    }
}
