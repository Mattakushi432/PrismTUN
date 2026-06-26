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
        ContentUnavailableView(
            String(localized: "No Routing Rules"),
            systemImage: "arrow.triangle.branch",
            description: Text(String(localized: "Add rules to control how traffic is routed through the proxy."))
        )
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
