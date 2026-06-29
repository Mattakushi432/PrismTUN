import SwiftUI

struct RoutingView: View {
    @Environment(RoutingViewModel.self) private var routingVM
    @State private var sheetState: SheetState?

    var body: some View {
        Group {
            if routingVM.rules.isEmpty {
                emptyState
            } else {
                rulesList
            }
        }
        .navigationTitle(String(localized: "Routing"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                PresetsMenuButton { preset in
                    Task { await routingVM.addPreset(preset) }
                }
                Button(String(localized: "Add Rule"), systemImage: "plus") {
                    sheetState = .add
                }
            }
        }
        .sheet(item: $sheetState) { state in
            RuleEditorView(existingRule: state.editingRule) { rule in
                Task {
                    if state.editingRule != nil {
                        await routingVM.updateRule(rule)
                    } else {
                        await routingVM.addRule(rule)
                    }
                }
            }
        }
        .alert(
            String(localized: "Error"),
            isPresented: Binding(
                get: { routingVM.errorMessage != nil },
                set: { if !$0 { routingVM.clearError() } }
            ),
            presenting: routingVM.errorMessage
        ) { _ in
            Button(String(localized: "OK")) { routingVM.clearError() }
        } message: { msg in
            Text(msg)
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                    .padding(.top, 32)

                VStack(spacing: 8) {
                    Text(String(localized: "No Routing Rules"))
                        .font(.title3.bold())
                    Text(String(localized: "Without rules, all traffic follows the mode you chose on the Dashboard (System Proxy, Global, etc.).\nRouting rules let you override this per domain or IP — send via Proxy, go Direct, or Block entirely."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 16) {
                    RoutingLegendItem(color: .blue,  icon: "arrow.up.forward.circle.fill", label: String(localized: "Proxy"),  detail: String(localized: "Goes through your proxy server"))
                    RoutingLegendItem(color: .green, icon: "arrow.right.circle.fill",      label: String(localized: "Direct"), detail: String(localized: "Bypasses proxy, goes direct"))
                    RoutingLegendItem(color: .red,   icon: "xmark.circle.fill",             label: String(localized: "Block"),  detail: String(localized: "Connection dropped"))
                }
                .padding(.horizontal, 8)

                VStack(spacing: 10) {
                    Text(String(localized: "Quick start with a preset:"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        PresetChip(title: String(localized: "Bypass China"), detail: String(localized: "Chinese sites go direct, rest via proxy")) {
                            Task { await routingVM.addPreset(RulePresets.bypassChina) }
                        }
                        PresetChip(title: String(localized: "Bypass LAN"),   detail: String(localized: "Local network always goes direct")) {
                            Task { await routingVM.addPreset(RulePresets.bypassLAN) }
                        }
                        PresetChip(title: String(localized: "Block Ads"),    detail: String(localized: "Block common ad domains")) {
                            Task { await routingVM.addPreset(RulePresets.blockAds) }
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 40)
        }
    }

    private var rulesList: some View {
        List {
            ForEach(routingVM.rules) { rule in
                RuleRow(rule: rule) {
                    sheetState = .edit(rule)
                } onToggle: {
                    Task { await routingVM.toggleRule(rule) }
                }
                .contextMenu {
                    Button(String(localized: "Edit")) { sheetState = .edit(rule) }
                    Divider()
                    Button(String(localized: "Delete"), role: .destructive) {
                        guard let idx = routingVM.rules.firstIndex(where: { $0.id == rule.id }) else { return }
                        Task { await routingVM.deleteRules(at: IndexSet(integer: idx)) }
                    }
                }
            }
            .onMove { from, to in Task { await routingVM.moveRules(from: from, to: to) } }
            .onDelete { offsets in Task { await routingVM.deleteRules(at: offsets) } }
        }
    }
}

// MARK: - Sheet State

extension RoutingView {
    enum SheetState: Identifiable {
        case add
        case edit(RoutingRule)

        var id: String {
            switch self {
            case .add:         "add"
            case .edit(let r): r.id.uuidString
            }
        }

        var editingRule: RoutingRule? {
            guard case .edit(let r) = self else { return nil }
            return r
        }
    }
}

// MARK: - Rule Row

private struct RuleRow: View {
    let rule: RoutingRule
    let onEdit: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle(
                isOn: Binding(get: { rule.isEnabled }, set: { _ in onToggle() }),
                label: { EmptyView() }
            )
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name.isEmpty ? "\(rule.type.displayName): \(rule.value)" : rule.name)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(rule.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !rule.name.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(rule.value)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            OutboundBadge(outbound: rule.outbound)
                .opacity(rule.isEnabled ? 1 : 0.4)

            Button(String(localized: "Edit"), action: onEdit)
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .font(.caption)
        }
        .padding(.vertical, 2)
        .opacity(rule.isEnabled ? 1 : 0.5)
    }
}

// MARK: - Outbound Badge

private struct OutboundBadge: View {
    let outbound: RuleOutbound

    var body: some View {
        Text(outbound.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch outbound {
        case .proxy:  .blue
        case .direct: .green
        case .block:  .red
        }
    }
}

// MARK: - Empty state helpers

private struct RoutingLegendItem: View {
    let color: Color
    let icon: String
    let label: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(label)
                .font(.caption.bold())
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct PresetChip: View {
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title).font(.caption.bold())
                Text(detail).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Presets Menu

private struct PresetsMenuButton: View {
    let onSelect: ([RoutingRule]) -> Void

    var body: some View {
        Menu {
            Button(String(localized: "Bypass China")) { onSelect(RulePresets.bypassChina) }
            Button(String(localized: "Bypass LAN"))   { onSelect(RulePresets.bypassLAN) }
            Button(String(localized: "Block Ads"))    { onSelect(RulePresets.blockAds) }
        } label: {
            Label(String(localized: "Presets"), systemImage: "wand.and.stars")
        }
    }
}
