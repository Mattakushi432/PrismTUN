import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    // General
    @AppStorage("launchAtLogin")  private var launchAtLogin = false
    @AppStorage("autoConnect")    private var autoConnect   = false
    @AppStorage("showInDock")     private var showInDock    = false

    // Appearance
    @AppStorage("appColorScheme") private var colorSchemeRaw = "system"
    @AppStorage("appLanguage")    private var appLanguage    = "system"

    // Logging
    @AppStorage("logLevel")       private var logLevel = "info"

    // UI state
    @State private var showResetConfirmation   = false
    @State private var showLanguageRestartNote = false
    @State private var isCheckingUpdates       = false
    @State private var errorMessage: String?
    @State private var updateResult: UpdateResult?

    var body: some View {
        Form {
            generalSection
            appearanceSection
            proxySection
            dnsSection
            geoSection
            loggingSection
            updatesSection
            dangerZoneSection
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "Settings"))
        .frame(minWidth: 460, minHeight: 520)
        .onAppear { syncLaunchAtLogin() }
        .alert(
            String(localized: "Error"),
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button(String(localized: "OK")) { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .alert(
            updateResult?.title ?? "",
            isPresented: Binding(get: { updateResult != nil }, set: { if !$0 { updateResult = nil } })
        ) {
            if let url = updateResult?.releaseURL {
                Button(String(localized: "View Release")) {
                    NSWorkspace.shared.open(url)
                    updateResult = nil
                }
            }
            Button(String(localized: "OK")) { updateResult = nil }
        } message: {
            if let result = updateResult { Text(result.message) }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var generalSection: some View {
        Section(String(localized: "General")) {
            Toggle(
                String(localized: "Launch at Login"),
                isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        applyLaunchAtLogin(newValue)
                    }
                )
            )
            Toggle(String(localized: "Auto-Connect on Launch"), isOn: $autoConnect)
            Toggle(
                String(localized: "Show in Dock"),
                isOn: Binding(
                    get: { showInDock },
                    set: { newValue in
                        showInDock = newValue
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }
                )
            )
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        Section(String(localized: "Appearance")) {
            Picker(String(localized: "Theme"), selection: $colorSchemeRaw) {
                Text(String(localized: "System")).tag("system")
                Text(String(localized: "Light")).tag("light")
                Text(String(localized: "Dark")).tag("dark")
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 4) {
                Picker(String(localized: "Language"), selection: $appLanguage) {
                    Text(String(localized: "System Default")).tag("system")
                    Text("English").tag("en")
                    Text("Русский").tag("ru")
                }
                .onChange(of: appLanguage) { _, newValue in
                    applyLanguagePreference(newValue)
                    showLanguageRestartNote = true
                }
                if showLanguageRestartNote {
                    Text(String(localized: "Restart PrismTUN to apply the language change."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var proxySection: some View {
        Section(String(localized: "Proxy")) {
            LabeledContent(String(localized: "Mixed Port")) {
                Text("\(SingBoxConfigBuilder.mixedPort)")
                    .foregroundStyle(.secondary)
            }
            LabeledContent(String(localized: "API Port")) {
                Text("\(SingBoxConfigBuilder.apiPort)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var dnsSection: some View {
        Section(String(localized: "DNS")) {
            NavigationLink(destination: DNSSettingsView()) {
                Label(
                    String(localized: "DNS Servers & Rules"),
                    systemImage: "network.badge.shield.half.filled"
                )
            }
        }
    }

    @ViewBuilder
    private var geoSection: some View {
        Section(String(localized: "Geo Assets")) {
            NavigationLink(destination: GeoSettingsView()) {
                Label(
                    String(localized: "GeoIP & GeoSite Databases"),
                    systemImage: "map"
                )
            }
        }
    }

    @ViewBuilder
    private var loggingSection: some View {
        Section(String(localized: "Logging")) {
            Picker(String(localized: "Log Level"), selection: $logLevel) {
                ForEach(["debug", "info", "warn", "error"], id: \.self) { level in
                    Text(level.uppercased()).tag(level)
                }
            }
        }
    }

    @ViewBuilder
    private var updatesSection: some View {
        Section(String(localized: "Updates & Config")) {
            Button {
                Task { await performUpdateCheck() }
            } label: {
                HStack {
                    Label(
                        String(localized: "Check for Updates"),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    Spacer()
                    if isCheckingUpdates {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(isCheckingUpdates)

            Button {
                NSWorkspace.shared.open(ProfileStore.directoryURL)
            } label: {
                Label(String(localized: "Open Config Directory"), systemImage: "folder")
            }
        }
    }

    @ViewBuilder
    private var dangerZoneSection: some View {
        Section(String(localized: "Danger Zone")) {
            Button(String(localized: "Reset All Settings"), role: .destructive) {
                showResetConfirmation = true
            }
            .confirmationDialog(
                String(localized: "Reset All Settings?"),
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Reset"), role: .destructive) { performReset() }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "This clears all preferences. Profiles and routing rules are kept."))
            }
        }
    }

    // MARK: - Actions

    private func syncLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func applyLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert toggle to actual system state on failure
            launchAtLogin = SMAppService.mainApp.status == .enabled
            errorMessage = error.localizedDescription
        }
    }

    private func applyLanguagePreference(_ code: String) {
        if code == "system" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
    }

    private func performReset() {
        guard let domain = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        try? SMAppService.mainApp.unregister()
    }

    private func performUpdateCheck() async {
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }
        do {
            updateResult = try await UpdateChecker.shared.checkLatestRelease()
        } catch {
            updateResult = UpdateResult(
                title: String(localized: "Check Failed"),
                message: error.localizedDescription,
                releaseURL: nil
            )
        }
    }
}
