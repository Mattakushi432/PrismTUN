import Foundation
import Observation
import SwiftUI

// MARK: - ViewModel

@Observable
@MainActor
final class GeoAssetViewModel {
    private(set) var geoipStatus: GeoAssetStatus   = GeoAssetStatus()
    private(set) var geositeStatus: GeoAssetStatus = GeoAssetStatus()
    private(set) var isUpdating: Bool               = false
    var errorMessage: String?

    func load() async {
        let manager = GeoAssetManager.shared
        await manager.loadStatus()
        geoipStatus   = await manager.geoipStatus
        geositeStatus = await manager.geositeStatus
        isUpdating    = await manager.isUpdating
    }

    func updateNow() async {
        isUpdating   = true
        errorMessage = nil
        do {
            try await GeoAssetManager.shared.update()
        } catch {
            errorMessage = error.localizedDescription
        }
        let manager = GeoAssetManager.shared
        geoipStatus   = await manager.geoipStatus
        geositeStatus = await manager.geositeStatus
        isUpdating    = await manager.isUpdating
    }

    func updateIfNeeded() async {
        await GeoAssetManager.shared.updateIfNeeded()
        let manager = GeoAssetManager.shared
        geoipStatus   = await manager.geoipStatus
        geositeStatus = await manager.geositeStatus
    }

    func clearError() { errorMessage = nil }
}

// MARK: - View

struct GeoSettingsView: View {
    @Environment(GeoAssetViewModel.self) private var geoVM
    @AppStorage("geoAutoUpdate") private var autoUpdate = true

    var body: some View {
        Form {
            assetsSection
            autoUpdateSection
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "Geo Assets"))
        .task { await geoVM.load() }
        .alert(
            String(localized: "Error"),
            isPresented: Binding(
                get: { geoVM.errorMessage != nil },
                set: { if !$0 { geoVM.clearError() } }
            ),
            presenting: geoVM.errorMessage
        ) { _ in
            Button(String(localized: "OK")) { geoVM.clearError() }
        } message: { msg in
            Text(msg)
        }
    }

    // MARK: - Sections

    private var assetsSection: some View {
        Section {
            GeoAssetRow(name: "geoip.db",   icon: "globe",                  status: geoVM.geoipStatus)
            GeoAssetRow(name: "geosite.db", icon: "list.bullet.rectangle",  status: geoVM.geositeStatus)
            Button {
                Task { await geoVM.updateNow() }
            } label: {
                HStack {
                    Label(
                        String(localized: "Update Now"),
                        systemImage: "arrow.down.circle"
                    )
                    Spacer()
                    if geoVM.isUpdating {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(geoVM.isUpdating)
        } header: {
            Text(String(localized: "Geo Databases"))
        } footer: {
            Text(String(localized: "geoip.db and geosite.db enable IP/domain routing rules. Stored in ~/Library/Application Support/PrismTUN/geo/."))
                .foregroundStyle(.secondary)
        }
    }

    private var autoUpdateSection: some View {
        Section {
            Toggle(String(localized: "Auto-Update Weekly"), isOn: $autoUpdate)
        } footer: {
            Text(String(localized: "When enabled, PrismTUN checks for updated geo databases on launch if more than 7 days have passed since the last update."))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Row

private struct GeoAssetRow: View {
    let name: String
    let icon: String
    let status: GeoAssetStatus

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(status.isDownloaded ? Color.green : Color.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(name).fontWeight(.medium)
                if let version = status.version {
                    Text(version).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "Not downloaded"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let size = status.fileSize {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let date = status.updatedAt {
                    Text(Self.dateFormatter.string(from: date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
