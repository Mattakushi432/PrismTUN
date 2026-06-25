import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let vpnManager: VPNManager

    init(vpnManager: VPNManager) {
        self.vpnManager = vpnManager
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "PrismTUN")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        statusItem = item
        updateIcon()
    }

    func updateIcon() {
        let name = vpnManager.isConnected ? "network.badge.shield.half.filled" : "network"
        statusItem?.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "PrismTUN")
        statusItem?.button?.image?.isTemplate = true
    }

    @objc private func statusItemClicked() {
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let title = vpnManager.isConnected
            ? "Connected — \(vpnManager.profileManager.activeProfile?.name ?? "")"
            : "Disconnected"
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(.separator())

        if vpnManager.isConnected {
            let disconnectItem = NSMenuItem(title: "Disconnect", action: #selector(disconnect), keyEquivalent: "")
            disconnectItem.target = self
            menu.addItem(disconnectItem)
        } else {
            let connectItem = NSMenuItem(title: "Connect", action: #selector(connect), keyEquivalent: "")
            connectItem.target = self
            menu.addItem(connectItem)
        }

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open PrismTUN", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func connect() {
        Task { await vpnManager.connect() }
    }

    @objc private func disconnect() {
        Task { await vpnManager.disconnect() }
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}
