import SwiftUI

struct AddProfileView: View {
    let onSave: (ProxyProfile) -> Void

    @State private var profile = ProxyProfile()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                generalSection
                serverSection
                protocolSection
                tlsSection
            }
            .formStyle(.grouped)
            .navigationTitle("Add Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(profile)
                        dismiss()
                    }
                    .disabled(profile.server.isEmpty)
                }
            }
        }
        .frame(width: 520, height: 640)
    }

    private var generalSection: some View {
        Section("General") {
            TextField("Name", text: $profile.name)
            Picker("Protocol", selection: $profile.protocol) {
                ForEach(ProxyProtocol.allCases, id: \.self) { proto in
                    Text(proto.displayName).tag(proto)
                }
            }
        }
    }

    private var serverSection: some View {
        Section("Server") {
            TextField("Host / IP", text: $profile.server)
            HStack {
                Text("Port")
                Spacer()
                TextField("443", value: $profile.port, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
            }
        }
    }

    @ViewBuilder
    private var protocolSection: some View {
        switch profile.protocol {
        case .shadowsocks:
            Section("Shadowsocks") {
                Picker("Method", selection: $profile.ssMethod) {
                    ForEach(ShadowsocksMethod.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                SecureField("Password", text: $profile.password)
            }
        case .vmess, .vless:
            Section(profile.protocol == .vmess ? "VMess" : "VLESS") {
                TextField("UUID", text: $profile.uuid)
                if profile.protocol == .vmess {
                    HStack {
                        Text("Alter ID")
                        Spacer()
                        TextField("0", value: $profile.alterId, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
                Picker("Network", selection: $profile.vmessNetwork) {
                    ForEach(VMessNetwork.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                if profile.vmessNetwork == .ws {
                    TextField("WS Path", text: $profile.wsPath)
                }
            }
        case .trojan:
            Section("Trojan") {
                SecureField("Password", text: $profile.trojanPassword)
            }
        case .socks5, .http:
            Section("Authentication (optional)") {
                TextField("Username", text: $profile.username)
                SecureField("Password", text: $profile.password)
            }
        }
    }

    @ViewBuilder
    private var tlsSection: some View {
        if profile.protocol.requiresEncryption {
            Section("TLS") {
                Toggle("Enable TLS", isOn: $profile.tls)
                if profile.tls {
                    TextField("SNI (optional)", text: $profile.sni)
                    Toggle("Skip Certificate Verification", isOn: $profile.skipCertVerify)
                    TextField("uTLS Fingerprint (optional)", text: $profile.fingerprint)
                }
            }
        }
    }
}
