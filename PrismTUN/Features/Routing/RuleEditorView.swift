import SwiftUI

struct RuleEditorView: View {
    let existingRule: RoutingRule?
    let onSave: (RoutingRule) -> Void

    @State private var name: String
    @State private var notes: String
    @State private var type: RuleType
    @State private var value: String
    @State private var outbound: RuleOutbound
    @State private var validationError: String?

    @Environment(\.dismiss) private var dismiss

    init(existingRule: RoutingRule?, onSave: @escaping (RoutingRule) -> Void) {
        self.existingRule = existingRule
        self.onSave = onSave
        _name     = State(initialValue: existingRule?.name     ?? "")
        _notes    = State(initialValue: existingRule?.notes    ?? "")
        _type     = State(initialValue: existingRule?.type     ?? .domain)
        _value    = State(initialValue: existingRule?.value    ?? "")
        _outbound = State(initialValue: existingRule?.outbound ?? .proxy)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rule") {
                    TextField("Name (optional)", text: $name)

                    Picker("Type", selection: $type) {
                        ForEach(RuleType.allCases, id: \.self) { ruleType in
                            Text(ruleType.displayName).tag(ruleType)
                        }
                    }
                    .onChange(of: type) { _, _ in
                        validationError = nil
                        value = ""
                    }

                    TextField(type.placeholder, text: $value)
                        .fontDesign(.monospaced)
                }

                Section("Action") {
                    Picker("Outbound", selection: $outbound) {
                        ForEach(RuleOutbound.allCases, id: \.self) { o in
                            Text(o.displayName).tag(o)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notes") {
                    TextField("Optional description", text: $notes)
                }

                if let error = validationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(existingRule == nil ? String(localized: "Add Rule") : String(localized: "Edit Rule"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { save() }
                        .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 380)
    }

    private func save() {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            validationError = String(localized: "Value cannot be empty.")
            return
        }
        if let error = validate(type: type, value: trimmed) {
            validationError = error
            return
        }
        let rule = RoutingRule(
            id:        existingRule?.id ?? UUID(),
            name:      name.trimmingCharacters(in: .whitespaces),
            notes:     notes.trimmingCharacters(in: .whitespaces),
            type:      type,
            value:     trimmed,
            outbound:  outbound,
            isEnabled: existingRule?.isEnabled ?? true
        )
        onSave(rule)
        dismiss()
    }

    private func validate(type: RuleType, value: String) -> String? {
        switch type {
        case .ipCidr, .sourceIpCidr:
            guard value.contains("/") else {
                return String(localized: "IP CIDR must use slash notation, e.g. 192.168.0.0/16")
            }
        case .port:
            guard let n = Int(value), (1...65535).contains(n) else {
                return String(localized: "Port must be a number between 1 and 65535.")
            }
        case .portRange:
            let parts = value.components(separatedBy: ":")
            guard parts.count == 2,
                  let start = Int(parts[0]), let end = Int(parts[1]),
                  (1...65535).contains(start), (1...65535).contains(end),
                  start <= end else {
                return String(localized: "Port range must be start:end, e.g. 8000:9000")
            }
        default:
            break
        }
        return nil
    }
}
