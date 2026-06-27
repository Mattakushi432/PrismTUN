import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let vpnManager: VPNManager

    // Connecting animation
    private var connectingTimer: Timer?
    private var connectingFrame = 0

    // Tracks when the current session started (for elapsed time display)
    private var connectedAt: Date?

    private static let connectingIcons = [
        "network",
        "arrow.triangle.2.circlepath",
        "network.slash",
        "arrow.triangle.2.circlepath",
    ]

    init(vpnManager: VPNManager) {
        self.vpnManager = vpnManager
        super.init()
        setupStatusItem()
        startObserving()
    }

    deinit {
        connectingTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "PrismTUN")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        statusItem = item
        syncIcon()
    }

    // MARK: - Observation (withObservationTracking recursive pattern)

    private func startObserving() {
        withObservationTracking {
            _ = vpnManager.status
            _ = vpnManager.stats
            _ = vpnManager.connectionMode
        } onChange: {
            Task { @MainActor [weak self] in
                self?.syncIcon()
                self?.startObserving()
            }
        }
    }

    // MARK: - Icon

    private func syncIcon() {
        switch vpnManager.status {
        case .connecting:
            startConnectingAnimation()
        case .connected:
            stopConnectingAnimation()
            if connectedAt == nil { connectedAt = Date() }
            let name = vpnManager.connectionMode == .tun
                ? "bolt.shield.fill"
                : "network.badge.shield.half.filled"
            setIcon(name)
        case .disconnected:
            stopConnectingAnimation()
            connectedAt = nil
            setIcon("network")
        case .failed:
            stopConnectingAnimation()
            connectedAt = nil
            setIcon("network.slash")
        }
        updateTooltip()
    }

    private func setIcon(_ symbolName: String) {
        guard let button = statusItem?.button else { return }
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "PrismTUN")
        img?.isTemplate = true
        button.image = img
    }

    private func updateTooltip() {
        let tip: String
        switch vpnManager.status {
        case .disconnected:
            tip = "PrismTUN — Disconnected"
        case .connecting:
            tip = "PrismTUN — Connecting…"
        case .connected:
            let name = vpnManager.profileManager.activeProfile?.name ?? ""
            let mode = vpnManager.connectionMode.displayName
            tip = "PrismTUN — \(name) · \(mode)"
        case .failed:
            tip = "PrismTUN — Connection failed"
        }
        statusItem?.button?.toolTip = tip
    }

    // MARK: - Connecting animation

    private func startConnectingAnimation() {
        guard connectingTimer == nil else { return }
        connectingFrame = 0
        let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let frames = Self.connectingIcons
                self.setIcon(frames[self.connectingFrame % frames.count])
                self.connectingFrame += 1
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        connectingTimer = timer
        setIcon(Self.connectingIcons[0])
    }

    private func stopConnectingAnimation() {
        connectingTimer?.invalidate()
        connectingTimer = nil
        connectingFrame = 0
    }

    // MARK: - Menu

    @objc private func statusItemClicked() {
        statusItem?.menu = buildMenu()
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(statusHeaderItem())
        menu.addItem(.separator())

        if vpnManager.isConnected {
            trafficItems().forEach { menu.addItem($0) }
            menu.addItem(.separator())
        }

        menu.addItem(connectDisconnectItem())
        menu.addItem(.separator())

        menu.addItem(modeMenuItem())
        if let profileMenu = profileMenuItem() {
            menu.addItem(profileMenu)
        }

        menu.addItem(.separator())

        let open = NSMenuItem(title: "Open PrismTUN", action: #selector(openMainWindow), keyEquivalent: "o")
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    // MARK: - Menu item builders

    private func statusHeaderItem() -> NSMenuItem {
        let profileName = vpnManager.profileManager.activeProfile?.name ?? "No Profile"
        let dot = statusDot()
        let label = "\(dot) \(profileName)"

        let boldFont = NSFontManager.shared.convert(
            NSFont.menuFont(ofSize: 0), toHaveTrait: .boldFontMask
        )
        let smallFont = NSFont.menuFont(ofSize: max(NSFont.menuFont(ofSize: 0).pointSize - 1, 10))

        let text = NSMutableAttributedString(
            string: label,
            attributes: [.font: boldFont, .foregroundColor: NSColor.labelColor]
        )
        let statusLine = "\n\(vpnManager.status.displayName)"
        text.append(NSAttributedString(
            string: statusLine,
            attributes: [.font: smallFont, .foregroundColor: NSColor.secondaryLabelColor]
        ))

        let item = NSMenuItem()
        item.attributedTitle = text
        item.isEnabled = false
        return item
    }

    private func statusDot() -> String {
        switch vpnManager.status {
        case .connected:    return "🟢"
        case .connecting:   return "🟡"
        case .disconnected: return "⚫"
        case .failed:       return "🔴"
        }
    }

    private func trafficItems() -> [NSMenuItem] {
        let stats = vpnManager.stats
        var items: [NSMenuItem] = [
            makeInfoItem("↑ \(stats.uploadSpeedFormatted)   total: \(stats.uploadFormatted)"),
            makeInfoItem("↓ \(stats.downloadSpeedFormatted)   total: \(stats.downloadFormatted)"),
        ]
        if let since = connectedAt {
            let elapsed = Int(-since.timeIntervalSinceNow)
            let h = elapsed / 3600
            let m = (elapsed % 3600) / 60
            let s = elapsed % 60
            let time = h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%d:%02d", m, s)
            items.append(makeInfoItem("⏱ \(time)"))
        }
        return items
    }

    private func connectDisconnectItem() -> NSMenuItem {
        if vpnManager.isConnected {
            let item = NSMenuItem(title: "Disconnect", action: #selector(disconnect), keyEquivalent: "d")
            item.target = self
            return item
        } else {
            let item = NSMenuItem(title: "Connect", action: #selector(connect), keyEquivalent: "c")
            item.target = self
            return item
        }
    }

    private func modeMenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "Mode")
        for mode in ConnectionMode.allCases {
            let item = NSMenuItem(title: mode.displayName, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = vpnManager.connectionMode == mode ? .on : .off
            item.toolTip = mode.description
            sub.addItem(item)
        }
        parent.submenu = sub
        return parent
    }

    private func profileMenuItem() -> NSMenuItem? {
        let profiles = vpnManager.profileManager.profiles
        guard !profiles.isEmpty else { return nil }

        let parent = NSMenuItem(title: "Profile", action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "Profile")
        for profile in profiles {
            let item = NSMenuItem(title: profile.name, action: #selector(selectProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile.id.uuidString
            item.state = vpnManager.profileManager.activeProfileID == profile.id ? .on : .off
            if let ms = profile.lastLatencyMs {
                item.toolTip = "\(ms) ms"
            }
            sub.addItem(item)
        }
        parent.submenu = sub
        return parent
    }

    private func makeInfoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: - Actions

    @objc private func connect() {
        Task { await vpnManager.connect(mode: vpnManager.connectionMode) }
    }

    @objc private func disconnect() {
        Task { await vpnManager.disconnect() }
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = ConnectionMode(rawValue: raw) else { return }
        Task { await vpnManager.setMode(mode) }
    }

    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let idStr = sender.representedObject as? String,
              let id = UUID(uuidString: idStr) else { return }
        Task {
            await vpnManager.profileManager.setActive(id: id)
            if vpnManager.isConnected {
                await vpnManager.disconnect()
                await vpnManager.connect(mode: vpnManager.connectionMode)
            }
        }
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}
