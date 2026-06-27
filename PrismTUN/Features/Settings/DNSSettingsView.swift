import SwiftUI

// MARK: - DNS Settings View

struct DNSSettingsView: View {
    @Environment(DNSViewModel.self) private var dnsVM
    @State private var serverSheetState: ServerSheetState?
    @State private var ruleSheetState: RuleSheetState?

    var body: some View {
        Form {
            serversSection
            rulesSection
            generalSection
            fakeIPSection
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "DNS"))
        .sheet(item: $serverSheetState) { state in
            DNSServerEditorView(existing: state.server, serverTags: serverTags) { server in
                Task {
                    if state.server != nil {
                        await dnsVM.updateServer(server)
                    } else {
                        await dnsVM.addServer(server)
                    }
                }
            }
        }
        .sheet(item: $ruleSheetState) { state in
            DNSRuleEditorView(existing: state.rule, serverTags: serverTags) { rule in
                Task {
                    if state.rule != nil {
                        await dnsVM.updateRule(rule)
                    } else {
                        await dnsVM.addRule(rule)
                    }
                }
            }
        }
        .alert(
            String(localized: "Error"),
            isPresented: Binding(
                get: { dnsVM.errorMessage != nil },
                set: { if !$0 { dnsVM.clearError() } }
            ),
            presenting: dnsVM.errorMessage
        ) { _ in
            Button(String(localized: "OK")) { dnsVM.clearError() }
        } message: { msg in
            Text(msg)
        }
    }

    private var serverTags: [String] { dnsVM.config.servers.map(\.tag) }

    // MARK: - Servers Section

    private var serversSection: some View {
        Section {
            ForEach(dnsVM.config.servers) { server in
                DNSServerRow(server: server) {
                    serverSheetState = .edit(server)
                }
                .contextMenu {
                    Button(String(localized: "Edit")) { serverSheetState = .edit(server) }
                    Divider()
                    Button(String(localized: "Delete"), role: .destructive) {
                        guard let idx = dnsVM.config.servers.firstIndex(where: { $0.id == server.id }) else { return }
                        Task { await dnsVM.deleteServers(at: IndexSet(integer: idx)) }
                    }
                }
            }
            .onDelete { offsets in Task { await dnsVM.deleteServers(at: offsets) } }
            Button(String(localized: "Add Server"), systemImage: "plus") {
                serverSheetState = .add
            }
        } header: {
            Text(String(localized: "DNS Servers"))
        } footer: {
            Text(String(localized: "Supports plain (IP), DoH (https://), DoT (tls://), DoQ (quic://), DHCP (dhcp://), local, and fakeip."))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Rules Section

    private var rulesSection: some View {
        Section {
            ForEach(dnsVM.config.rules) { rule in
                DNSRuleRow(rule: rule) {
                    ruleSheetState = .edit(rule)
                } onToggle: {
                    Task { await dnsVM.toggleRule(rule) }
                }
                .contextMenu {
                    Button(String(localized: "Edit")) { ruleSheetState = .edit(rule) }
                    Divider()
                    Button(String(localized: "Delete"), role: .destructive) {
                        guard let idx = dnsVM.config.rules.firstIndex(where: { $0.id == rule.id }) else { return }
                        Task { await dnsVM.deleteRules(at: IndexSet(integer: idx)) }
                    }
                }
            }
            .onDelete { offsets in Task { await dnsVM.deleteRules(at: offsets) } }
            Button(String(localized: "Add Rule"), systemImage: "plus") {
                ruleSheetState = .add
            }
        } header: {
            Text(String(localized: "DNS Rules"))
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section(String(localized: "General")) {
            Picker(String(localized: "Strategy"), selection: Binding(
                get: { dnsVM.config.strategy },
                set: { s in Task { await dnsVM.updateStrategy(s) } }
            )) {
                ForEach(DNSStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.displayName).tag(strategy)
                }
            }
            Picker(String(localized: "Final Server"), selection: Binding(
                get: { dnsVM.config.finalServer },
                set: { tag in Task { await dnsVM.updateFinalServer(tag) } }
            )) {
                ForEach(serverTags, id: \.self) { tag in
                    Text(tag).tag(tag)
                }
                if !serverTags.contains(dnsVM.config.finalServer) {
                    Text(dnsVM.config.finalServer).tag(dnsVM.config.finalServer)
                }
            }
        }
    }

    // MARK: - FakeIP Section

    private var fakeIPSection: some View {
        Section {
            Toggle(String(localized: "Enable FakeIP"), isOn: Binding(
                get: { dnsVM.config.fakeIP.isEnabled },
                set: { enabled in
                    var fakeIP = dnsVM.config.fakeIP
                    fakeIP.isEnabled = enabled
                    Task { await dnsVM.updateFakeIP(fakeIP) }
                }
            ))
            if dnsVM.config.fakeIP.isEnabled {
                LabeledContent(String(localized: "IPv4 Range")) {
                    TextField(
                        "198.18.0.0/15",
                        text: Binding(
                            get: { dnsVM.config.fakeIP.inet4Range },
                            set: { v in
                                var fakeIP = dnsVM.config.fakeIP
                                fakeIP.inet4Range = v
                                Task { await dnsVM.updateFakeIP(fakeIP) }
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                LabeledContent(String(localized: "IPv6 Range")) {
                    TextField(
                        "fc00::/18",
                        text: Binding(
                            get: { dnsVM.config.fakeIP.inet6Range },
                            set: { v in
                                var fakeIP = dnsVM.config.fakeIP
                                fakeIP.inet6Range = v
                                Task { await dnsVM.updateFakeIP(fakeIP) }
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
            }
        } header: {
            Text(String(localized: "FakeIP"))
        } footer: {
            Text(String(localized: "FakeIP assigns fake addresses to domain lookups, enabling transparent proxy without DNS leaks."))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Sheet State

private enum ServerSheetState: Identifiable {
    case add
    case edit(DNSServer)

    var id: String {
        switch self {
        case .add:         "add-server"
        case .edit(let s): s.id.uuidString
        }
    }

    var server: DNSServer? {
        if case .edit(let s) = self { return s }
        return nil
    }
}

private enum RuleSheetState: Identifiable {
    case add
    case edit(DNSRule)

    var id: String {
        switch self {
        case .add:         "add-rule"
        case .edit(let r): r.id.uuidString
        }
    }

    var rule: DNSRule? {
        if case .edit(let r) = self { return r }
        return nil
    }
}

// MARK: - Server Row

private struct DNSServerRow: View {
    let server: DNSServer
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: server.serverType.iconName)
                .foregroundStyle(typeColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.tag)
                    .fontWeight(.medium)
                Text(server.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !server.detour.isEmpty {
                Text(server.detour)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(server.serverType.rawValue)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(Capsule())
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onEdit() }
    }

    private var typeColor: Color {
        switch server.serverType {
        case .doh:    .green
        case .dot:    .blue
        case .doq:    .purple
        case .dhcp:   .orange
        case .fakeip: .pink
        default:      .secondary
        }
    }
}

// MARK: - Rule Row

private struct DNSRuleRow: View {
    let rule: DNSRule
    let onEdit: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(rule.ruleType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                    Text(rule.value)
                        .fontWeight(.medium)
                }
                Text("→ \(rule.serverTag)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onEdit() }
    }
}

// MARK: - Server Editor

struct DNSServerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let existing: DNSServer?
    let serverTags: [String]
    let onSave: (DNSServer) -> Void

    @State private var tag: String
    @State private var address: String
    @State private var detour: String

    init(existing: DNSServer?, serverTags: [String], onSave: @escaping (DNSServer) -> Void) {
        self.existing   = existing
        self.serverTags = serverTags
        self.onSave     = onSave
        _tag     = State(initialValue: existing?.tag     ?? "")
        _address = State(initialValue: existing?.address ?? "")
        _detour  = State(initialValue: existing?.detour  ?? "")
    }

    private var detectedType: DNSServerType { DNSServerType(address: address) }
    private var isValid: Bool {
        !tag.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Server Info")) {
                    LabeledContent(String(localized: "Tag")) {
                        TextField(String(localized: "e.g. google"), text: $tag)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent(String(localized: "Address")) {
                        TextField(String(localized: "8.8.8.8 or https://dns.google/dns-query"), text: $address)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent(String(localized: "Detour")) {
                        TextField(String(localized: "direct (optional)"), text: $detour)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                Section {
                    LabeledContent(String(localized: "Detected Type")) {
                        HStack(spacing: 6) {
                            Image(systemName: detectedType.iconName)
                            Text(detectedType.rawValue)
                        }
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "Type Detection"))
                } footer: {
                    Text(String(localized: "Inferred from prefix: https:// → DoH, tls:// → DoT, quic:// → DoQ, dhcp:// → DHCP, local → Local, fakeip → FakeIP."))
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existing == nil
                ? String(localized: "Add DNS Server")
                : String(localized: "Edit DNS Server"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        let server = DNSServer(
                            id:      existing?.id ?? UUID(),
                            tag:     tag.trimmingCharacters(in: .whitespaces),
                            address: address.trimmingCharacters(in: .whitespaces),
                            detour:  detour.trimmingCharacters(in: .whitespaces)
                        )
                        onSave(server)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 300)
    }
}

// MARK: - Rule Editor

struct DNSRuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let existing: DNSRule?
    let serverTags: [String]
    let onSave: (DNSRule) -> Void

    @State private var ruleType: DNSRuleType
    @State private var value: String
    @State private var serverTag: String
    @State private var isEnabled: Bool

    init(existing: DNSRule?, serverTags: [String], onSave: @escaping (DNSRule) -> Void) {
        self.existing   = existing
        self.serverTags = serverTags
        self.onSave     = onSave
        _ruleType  = State(initialValue: existing?.ruleType  ?? .geosite)
        _value     = State(initialValue: existing?.value     ?? "")
        _serverTag = State(initialValue: existing?.serverTag ?? serverTags.first ?? "")
        _isEnabled = State(initialValue: existing?.isEnabled ?? true)
    }

    private var isValid: Bool {
        !value.trimmingCharacters(in: .whitespaces).isEmpty && !serverTag.isEmpty
    }

    private var valuePlaceholder: String {
        switch ruleType {
        case .geosite: "cn"
        case .geoip:   "cn"
        case .domain:  "example.com"
        case .ipCidr:  "192.168.0.0/16"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Rule")) {
                    Picker(String(localized: "Type"), selection: $ruleType) {
                        ForEach(DNSRuleType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    LabeledContent(String(localized: "Value")) {
                        TextField(valuePlaceholder, text: $value)
                            .textFieldStyle(.roundedBorder)
                    }
                    if serverTags.isEmpty {
                        Text(String(localized: "Add a DNS server first."))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        Picker(String(localized: "Server"), selection: $serverTag) {
                            ForEach(serverTags, id: \.self) { tag in
                                Text(tag).tag(tag)
                            }
                        }
                    }
                    Toggle(String(localized: "Enabled"), isOn: $isEnabled)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existing == nil
                ? String(localized: "Add DNS Rule")
                : String(localized: "Edit DNS Rule"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        let rule = DNSRule(
                            id:        existing?.id ?? UUID(),
                            ruleType:  ruleType,
                            value:     value.trimmingCharacters(in: .whitespaces),
                            serverTag: serverTag,
                            isEnabled: isEnabled
                        )
                        onSave(rule)
                        dismiss()
                    }
                    .disabled(!isValid || serverTag.isEmpty)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 260)
    }
}
