import SwiftUI
import CoreImage
import AppKit
import UniformTypeIdentifiers

struct ProfileListView: View {
    @Environment(ProfileManager.self)      private var profileManager
    @Environment(VPNManager.self)          private var vpnManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var viewModel:  ProfilesViewModel?
    @State private var showAdd     = false
    @State private var importURI   = ""
    @State private var showImport  = false

    var body: some View {
        Group {
            if let vm = viewModel {
                ProfileListContent(
                    viewModel: vm,
                    showAdd: $showAdd,
                    showImport: $showImport,
                    importURI: $importURI
                )
            }
        }
        .task {
            let vm = ProfilesViewModel(profileManager: profileManager)
            viewModel = vm
        }
        .onReceive(NotificationCenter.default.publisher(for: .newProfileRequested)) { _ in
            showAdd = true
        }
        .navigationTitle(String(localized: "Profiles"))
    }
}

// MARK: - Main content

private struct ProfileListContent: View {
    let viewModel: ProfilesViewModel
    @Binding var showAdd:    Bool
    @Binding var showImport: Bool
    @Binding var importURI:  String

    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var showQRScan    = false
    @State private var showAddSub    = false
    @State private var deletingSubID: UUID?

    // MARK: Helpers

    private func profiles(forSubscription id: UUID) -> [ProxyProfile] {
        viewModel.sorted(viewModel.profiles.filter { $0.subscriptionID == id })
    }

    private var manualProfiles: [ProxyProfile] {
        viewModel.sorted(viewModel.profiles.filter { $0.subscriptionID == nil })
    }

    private var isEmpty: Bool {
        viewModel.profiles.isEmpty && subscriptionManager.subscriptions.isEmpty
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if isEmpty {
                emptyState
            } else {
                profileList
            }
        }
        .sheet(isPresented: $showAdd) {
            AddProfileView { profile in
                Task { await viewModel.add(profile) }
            }
        }
        .sheet(isPresented: $showImport) {
            URIImportView(uri: $importURI) { text in
                Task { await viewModel.importFromURI(text) }
            }
        }
        .sheet(isPresented: $showQRScan) {
            QRScanView { uris in
                Task { await viewModel.importFromURI(uris.joined(separator: "\n")) }
            }
        }
        .sheet(isPresented: $showAddSub) {
            AddSubscriptionView { sub in
                Task { await subscriptionManager.add(sub) }
            }
        }
        .alert(
            String(localized: "Remove Subscription"),
            isPresented: Binding(
                get: { deletingSubID != nil },
                set: { if !$0 { deletingSubID = nil } }
            )
        ) {
            Button(String(localized: "Remove"), role: .destructive) {
                if let id = deletingSubID {
                    Task { await subscriptionManager.remove(id: id) }
                }
                deletingSubID = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) { deletingSubID = nil }
        } message: {
            Text(String(localized: "This will also delete all profiles from this subscription."))
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button { showImport = true } label: {
                Label(String(localized: "Import URI"), systemImage: "link.badge.plus")
            }
            Button { showQRScan = true } label: {
                Label(String(localized: "Scan QR"), systemImage: "qrcode.viewfinder")
            }
            if subscriptionManager.isUpdating {
                ProgressView().controlSize(.small)
            } else if !subscriptionManager.subscriptions.isEmpty {
                Button {
                    Task { await subscriptionManager.updateAll() }
                } label: {
                    Label(String(localized: "Update All"), systemImage: "arrow.clockwise")
                }
            }

            Divider().frame(height: 16)

            // Latency test controls
            if viewModel.isTesting {
                ProgressView().controlSize(.small)
                Button { viewModel.cancelTest() } label: {
                    Label(String(localized: "Stop"), systemImage: "stop.circle")
                }
            } else if !viewModel.profiles.isEmpty {
                Button { viewModel.testAll() } label: {
                    Label(String(localized: "Test All"), systemImage: "bolt.horizontal")
                }
                .help(String(localized: "TCP-ping all servers and show latency"))
            }

            // Sort toggle
            if !viewModel.profiles.isEmpty {
                Toggle(isOn: Binding(
                    get: { viewModel.sortByLatency },
                    set: { viewModel.sortByLatency = $0 }
                )) {
                    Image(systemName: viewModel.sortByLatency
                          ? "arrow.up.arrow.down.circle.fill"
                          : "arrow.up.arrow.down.circle")
                }
                .toggleStyle(.button)
                .help(String(localized: viewModel.sortByLatency
                             ? "Currently sorted by latency — click to reset"
                             : "Sort by latency"))
            }

            Spacer()
            Button { showAddSub = true } label: {
                Label(String(localized: "Add Subscription"), systemImage: "plus.rectangle.on.folder")
            }
            Button { showAdd = true } label: {
                Label(String(localized: "Add"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label(String(localized: "No Profiles"), systemImage: "server.rack")
        } description: {
            Text(String(localized: "Add a proxy profile, import a URI, or add a subscription to get started."))
        } actions: {
            Button(String(localized: "Add Subscription")) { showAddSub = true }
                .buttonStyle(.borderedProminent)
            Button(String(localized: "Add Profile")) { showAdd = true }
                .buttonStyle(.bordered)
        }
    }

    // MARK: List with sections

    private var profileList: some View {
        List {
            ForEach(subscriptionManager.subscriptions) { sub in
                Section {
                    let subProfiles = profiles(forSubscription: sub.id)
                    if subProfiles.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise.circle")
                                .foregroundStyle(.secondary)
                            Text(String(localized: "No profiles — tap Update to fetch"))
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(subProfiles) { profile in
                            ProfileRow(
                                profile: profile,
                                isActive: viewModel.activeProfileID == profile.id,
                                onSelect: { Task { await viewModel.setActive(id: profile.id) } },
                                onDelete: { Task { await viewModel.delete(id: profile.id) } }
                            )
                        }
                    }
                } header: {
                    SubscriptionSectionHeader(
                        subscription: sub,
                        isUpdating: subscriptionManager.isUpdating,
                        onUpdate: { Task { await subscriptionManager.update(id: sub.id) } },
                        onRemove: { deletingSubID = sub.id }
                    )
                }
            }

            if !manualProfiles.isEmpty {
                Section(String(localized: "Manual")) {
                    ForEach(manualProfiles) { profile in
                        ProfileRow(
                            profile: profile,
                            isActive: viewModel.activeProfileID == profile.id,
                            onSelect: { Task { await viewModel.setActive(id: profile.id) } },
                            onDelete: { Task { await viewModel.delete(id: profile.id) } }
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Subscription section header

private struct SubscriptionSectionHeader: View {
    let subscription: Subscription
    let isUpdating:   Bool
    let onUpdate:     () -> Void
    let onRemove:     () -> Void

    private var lastUpdatedText: String {
        guard let date = subscription.lastUpdated else {
            return String(localized: "Never updated")
        }
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "cloud")
                .foregroundStyle(.secondary)
                .font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(subscription.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("\(subscription.profileIDs.count) servers · \(lastUpdatedText)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if isUpdating {
                ProgressView().controlSize(.mini)
            } else {
                Button(action: onUpdate) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Update subscription"))

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Remove subscription"))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - ProfileRow

private struct ProfileRow: View {
    let profile:  ProxyProfile
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var showQR = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .onTapGesture { onSelect() }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name.isEmpty ? profile.server : profile.name)
                    .fontWeight(isActive ? .semibold : .regular)
                HStack(spacing: 6) {
                    Text(profile.protocol.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                    Text("\(profile.server):\(profile.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            LatencyBadge(profile: profile)

            if profile.toURI() != nil {
                Button { showQR.toggle() } label: {
                    Image(systemName: "qrcode")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Show QR / copy URI"))
                .popover(isPresented: $showQR, arrowEdge: .trailing) {
                    QRPopoverView(profile: profile)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
        }
        .contextMenu {
            Button(String(localized: "Select"), action: onSelect)
            if let uri = profile.toURI() {
                Button(String(localized: "Copy URI")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(uri, forType: .string)
                }
            }
            Divider()
            Button(String(localized: "Delete"), role: .destructive, action: onDelete)
        }
    }
}

// MARK: - LatencyBadge

private struct LatencyBadge: View {
    let profile: ProxyProfile

    var body: some View {
        if profile.lastTestedAt != nil {
            if let ms = profile.lastLatencyMs {
                Text("\(ms)ms")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(color(ms))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(color(ms).opacity(0.12))
                    .clipShape(Capsule())
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
    }

    private func color(_ ms: Int) -> Color {
        ms < 100 ? .green : ms < 300 ? .yellow : .red
    }
}

// MARK: - QRPopoverView

private struct QRPopoverView: View {
    let profile: ProxyProfile
    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            if let uri = profile.toURI() {
                if let img = makeQRCode(from: uri) {
                    Image(nsImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                }
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(uri, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    Label(
                        copied ? String(localized: "Copied!") : String(localized: "Copy URI"),
                        systemImage: copied ? "checkmark" : "doc.on.doc"
                    )
                }
                .buttonStyle(.borderless)
            } else {
                Text(String(localized: "No URI export for this protocol"))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .padding(20)
        .frame(width: 240)
    }
}

// MARK: - URIImportView

private struct URIImportView: View {
    @Binding var uri: String
    let onImport: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var parsableCount: Int {
        ProxyProfile.batchParse(text: uri).count
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(String(localized: "Import Proxy URIs")).font(.headline)
                Spacer()
                Button {
                    if let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty {
                        uri = clip
                    }
                } label: {
                    Label(String(localized: "Paste Clipboard"), systemImage: "clipboard")
                }
                .buttonStyle(.borderless)
            }

            TextEditor(text: $uri)
                .font(.system(.body, design: .monospaced))
                .frame(height: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))

            if !uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: parsableCount > 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(parsableCount > 0 ? .green : .red)
                    Text(parsableCount > 0
                         ? String(localized: "\(parsableCount) profile(s) ready to import")
                         : String(localized: "No valid proxy URIs detected"))
                        .font(.caption)
                        .foregroundStyle(parsableCount > 0 ? .primary : .secondary)
                    Spacer()
                }
            }

            HStack {
                Button(String(localized: "Cancel")) { dismiss() }
                Spacer()
                Button(String(localized: "Import")) {
                    onImport(uri)
                    uri = ""
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsableCount == 0)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

// MARK: - QRScanView

private struct QRScanView: View {
    let onImport: ([String]) -> Void
    @State private var detectedURIs: [String] = []
    @State private var selectedURIs: Set<String> = []
    @State private var scanned = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "Scan QR Code")).font(.headline)

            if !scanned {
                VStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Select an image file containing one or more proxy QR codes."))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(String(localized: "Choose Image File…")) { scanFromFile() }
                        .buttonStyle(.borderedProminent)
                    if let err = errorMessage {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
                // TODO(phase-9): add screen-capture path via ScreenCaptureKit (macOS 14.4+)
            } else if detectedURIs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(String(localized: "No proxy URIs detected in the image."))
                        .foregroundStyle(.secondary)
                    Button(String(localized: "Try Another File")) {
                        scanned = false
                        errorMessage = nil
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Detected \(detectedURIs.count) URI(s) — select rows to import only those:"))
                        .font(.subheadline)
                    List(detectedURIs, id: \.self, selection: $selectedURIs) { uri in
                        Text(uri)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(2)
                    }
                    .frame(height: min(CGFloat(detectedURIs.count) * 52 + 8, 200))
                    .border(.separator)
                    Text(String(localized: "Leave all unselected to import everything."))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack {
                Button(String(localized: "Cancel")) { dismiss() }
                Spacer()
                if scanned && !detectedURIs.isEmpty {
                    Button(selectedURIs.isEmpty
                           ? String(localized: "Import All (\(detectedURIs.count))")
                           : String(localized: "Import Selected (\(selectedURIs.count))")) {
                        let toImport = selectedURIs.isEmpty ? detectedURIs : Array(selectedURIs)
                        onImport(toImport)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func scanFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Select an image containing a QR code")
        panel.prompt  = String(localized: "Scan")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            errorMessage = String(localized: "Could not load image")
            return
        }

        let ci = CIImage(cgImage: cgImage)
        guard let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh as Any]
        ) else {
            errorMessage = String(localized: "QR detector unavailable")
            return
        }

        let found = detector.features(in: ci)
            .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
            .filter { ProxyProfile.parse(uri: $0) != nil }

        detectedURIs = found
        scanned = true
        if found.isEmpty { errorMessage = nil }
    }
}

// MARK: - QR code generation

private func makeQRCode(from string: String) -> NSImage? {
    guard let data   = string.data(using: .utf8),
          let filter = CIFilter(name: "CIQRCodeGenerator")
    else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("M",  forKey: "inputCorrectionLevel")
    guard let ciOutput = filter.outputImage else { return nil }
    let scaled = ciOutput.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    let rep    = NSCIImageRep(ciImage: scaled)
    let image  = NSImage(size: rep.size)
    image.addRepresentation(rep)
    return image
}
