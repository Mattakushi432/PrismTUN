import SwiftUI

struct AboutView: View {
    @State private var singBoxVersion: String = "…"

    private let appVersion: String = {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 4) {
                Text("PrismTUN")
                    .font(.title.bold())
                Text(String(localized: "Version \(appVersion)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: String(localized: "sing-box"), value: singBoxVersion)
                InfoRow(label: "macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
            }

            Link(String(localized: "View on GitHub"),
                 destination: URL(string: "https://github.com/Mattakushi432/PrismTUN")!)
                .font(.callout)

            Text(String(localized: "© 2024–2026 PrismTUN contributors. MIT License."))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 340)
        .task { singBoxVersion = await fetchSingBoxVersion() }
    }

    private func fetchSingBoxVersion() async -> String {
        guard let binaryURL = Bundle.main.url(forResource: "sing-box", withExtension: nil) else {
            return "N/A"
        }
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = binaryURL
            task.arguments = ["version"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                // Output: "sing-box version 1.11.0\n..."
                let version = output.components(separatedBy: "\n").first?
                    .components(separatedBy: " ").last ?? "N/A"
                continuation.resume(returning: version.isEmpty ? "N/A" : version)
            }
            do {
                try task.run()
            } catch {
                continuation.resume(returning: "N/A")
            }
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}
