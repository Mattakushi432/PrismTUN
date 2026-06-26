import SwiftUI

struct AddSubscriptionView: View {
    let onCreate: (Subscription) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name          = ""
    @State private var urlText       = ""
    @State private var userAgent     = "clash.meta"
    @State private var intervalIndex = 0
    @State private var includeRegex  = ""
    @State private var excludeRegex  = ""
    @State private var showAdvanced  = false

    private let intervals: [(label: String, seconds: TimeInterval)] = [
        ("Manual",   0),
        ("1 hour",   3_600),
        ("6 hours",  21_600),
        ("12 hours", 43_200),
        ("Daily",    86_400),
    ]

    private var parsedURL: URL? {
        let t = urlText.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: t),
              url.scheme == "http" || url.scheme == "https"
        else { return nil }
        return url
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedURL != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider()
            ScrollView {
                formContent
                    .padding(24)
            }
            Divider()
            footerRow
        }
        .frame(width: 480)
    }

    // MARK: - Sub-views

    private var headerRow: some View {
        HStack {
            Text(String(localized: "Add Subscription"))
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            SubLabeledField(label: String(localized: "Name")) {
                TextField(String(localized: "My Subscription"), text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            SubLabeledField(label: String(localized: "URL")) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("https://example.com/sub", text: $urlText)
                        .textFieldStyle(.roundedBorder)
                    if !urlText.isEmpty && parsedURL == nil {
                        Text(String(localized: "Enter a valid http:// or https:// URL"))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            SubLabeledField(label: String(localized: "User-Agent")) {
                TextField("clash.meta", text: $userAgent)
                    .textFieldStyle(.roundedBorder)
            }

            SubLabeledField(label: String(localized: "Auto-Update")) {
                Picker("", selection: $intervalIndex) {
                    ForEach(intervals.indices, id: \.self) { i in
                        Text(intervals[i].label).tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            DisclosureGroup(String(localized: "Advanced Filters"), isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 12) {
                    SubLabeledField(label: String(localized: "Include regex")) {
                        TextField(String(localized: "e.g. HK|SG"), text: $includeRegex)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    SubLabeledField(label: String(localized: "Exclude regex")) {
                        TextField(String(localized: "e.g. Trial|Expire"), text: $excludeRegex)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    Text(String(localized: "Leave empty to import all servers"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
        }
    }

    private var footerRow: some View {
        HStack {
            Button(String(localized: "Cancel")) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button(String(localized: "Add")) {
                guard let url = parsedURL else { return }
                let ua = userAgent.trimmingCharacters(in: .whitespaces)
                let sub = Subscription(
                    name: name.trimmingCharacters(in: .whitespaces),
                    url: url,
                    updateInterval: intervals[intervalIndex].seconds,
                    userAgent: ua.isEmpty ? "clash.meta" : ua,
                    includeRegex: includeRegex.trimmingCharacters(in: .whitespaces),
                    excludeRegex: excludeRegex.trimmingCharacters(in: .whitespaces)
                )
                onCreate(sub)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!isValid)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}

// MARK: - Helpers

private struct SubLabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
