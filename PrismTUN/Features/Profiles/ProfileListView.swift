import SwiftUI
import CoreImage
import AppKit
import UniformTypeIdentifiers

struct ProfileListView: View {
    @Environment(ProfileManager.self) private var profileManager
    @Environment(VPNManager.self) private var vpnManager
    @State private var viewModel: ProfilesViewModel?
    @State private var showAdd = false
    @State private var importURI = ""
    @State private var showImport = false

    var body: some View {
        Group {
            if let vm = viewModel {
                ProfileListContent(viewModel: vm, showAdd: $showAdd, showImport: $showImport, importURI: $importURI)
            }
        }
        .task {
            let vm = ProfilesViewModel(profileManager: profileManager)
            viewModel = vm
        }
        .navigationTitle("Profiles")
    }
}

// MARK: - ProfileListContent

private struct ProfileListContent: View {
    let viewModel: ProfilesViewModel
    @Binding var showAdd: Bool
    @Binding var showImport: Bool
    @Binding var importURI: String
    @State private var showQRScan = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if viewModel.profiles.isEmpty {
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
    }

    private var toolbar: some View {
        HStack {
            Button { showImport = true } label: {
                Label("Import URI", systemImage: "link.badge.plus")
            }
            Button { showQRScan = true } label: {
                Label("Scan QR", systemImage: "qrcode.viewfinder")
            }
            Spacer()
            Button { showAdd = true } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Profiles",
            systemImage: "server.rack",
            description: Text("Add a proxy profile or import a URI to get started")
        )
    }

    private var profileList: some View {
        List {
            ForEach(viewModel.profiles) { profile in
                ProfileRow(
                    profile: profile,
                    isActive: viewModel.activeProfileID == profile.id,
                    onSelect: { Task { await viewModel.setActive(id: profile.id) } },
                    onDelete: { Task { await viewModel.delete(id: profile.id) } }
                )
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - ProfileRow

private struct ProfileRow: View {
    let profile: ProxyProfile
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

            if profile.toURI() != nil {
                Button { showQR.toggle() } label: {
                    Image(systemName: "qrcode")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Show QR / copy URI")
                .popover(isPresented: $showQR, arrowEdge: .trailing) {
                    QRPopoverView(profile: profile)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Select", action: onSelect)
            if let uri = profile.toURI() {
                Button("Copy URI") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(uri, forType: .string)
                }
            }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
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
                Text("No URI export for this protocol")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .padding(20)
        .frame(width: 240)
    }
}

// MARK: - URIImportView (multi-line, live parse count, clipboard paste)

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
                Text("Import Proxy URIs").font(.headline)
                Spacer()
                Button {
                    if let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty {
                        uri = clip
                    }
                } label: {
                    Label("Paste Clipboard", systemImage: "clipboard")
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
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Import") {
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

// MARK: - QRScanView (file picker → CIDetector)

private struct QRScanView: View {
    let onImport: ([String]) -> Void
    @State private var detectedURIs: [String] = []
    @State private var selectedURIs: Set<String> = []
    @State private var scanned = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Scan QR Code").font(.headline)

            if !scanned {
                VStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Select an image file containing one or more proxy QR codes.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Choose Image File…") {
                        scanFromFile()
                    }
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
                    Text("No proxy URIs detected in the image.")
                        .foregroundStyle(.secondary)
                    Button("Try Another File") {
                        scanned = false
                        errorMessage = nil
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected \(detectedURIs.count) URI(s) — select rows to import only those:")
                        .font(.subheadline)
                    List(detectedURIs, id: \.self, selection: $selectedURIs) { uri in
                        Text(uri)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(2)
                    }
                    .frame(height: min(CGFloat(detectedURIs.count) * 52 + 8, 200))
                    .border(.separator)
                    Text("Leave all unselected to import everything.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                if scanned && !detectedURIs.isEmpty {
                    Button(selectedURIs.isEmpty
                           ? "Import All (\(detectedURIs.count))"
                           : "Import Selected (\(selectedURIs.count))") {
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
        panel.message = "Select an image containing a QR code"
        panel.prompt  = "Scan"
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
