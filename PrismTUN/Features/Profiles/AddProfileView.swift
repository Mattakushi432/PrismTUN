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
        .frame(width: 520, height: 680)
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

        case .hysteria2:
            Section("Hysteria2") {
                SecureField("Auth Password (optional)", text: $profile.password)
                HStack {
                    Text("Upload (Mbps)")
                    Spacer()
                    TextField("0", value: $profile.hysteria2UpMbps, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                HStack {
                    Text("Download (Mbps)")
                    Spacer()
                    TextField("0", value: $profile.hysteria2DownMbps, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
            }

        case .tuic:
            Section("TUIC") {
                TextField("UUID", text: $profile.uuid)
                SecureField("Token", text: $profile.password)
                Picker("Congestion Control", selection: $profile.tuicCongestionControl) {
                    Text("BBR").tag("bbr")
                    Text("Cubic").tag("cubic")
                    Text("New Reno").tag("new_reno")
                }
                Picker("UDP Relay Mode", selection: $profile.tuicUdpRelayMode) {
                    Text("Native").tag("native")
                    Text("QUIC").tag("quic")
                }
            }

        case .wireguard:
            Section("WireGuard") {
                SecureField("Private Key", text: $profile.wgPrivateKey)
                TextField("Peer Public Key", text: $profile.wgPeerPublicKey)
                SecureField("Preshared Key (optional)", text: $profile.wgPresharedKey)
                TextField("Local Address (e.g. 10.0.0.1/32)", text: $profile.wgLocalAddress)
                HStack {
                    Text("MTU")
                    Spacer()
                    TextField("1420", value: $profile.wgMTU, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
            }
        }
    }

    @ViewBuilder
    private var tlsSection: some View {
        // hysteria2 and tuic always use TLS — no toggle needed
        let alwaysTLS  = profile.protocol == .hysteria2 || profile.protocol == .tuic
        let hasReality = profile.protocol == .vless

        if profile.protocol.requiresEncryption {
            Section("TLS") {
                if !alwaysTLS {
                    Toggle("Enable TLS", isOn: $profile.tls)
                }
                let tlsActive = profile.tls || alwaysTLS
                if tlsActive {
                    TextField("SNI (optional)", text: $profile.sni)
                    Toggle("Skip Certificate Verification", isOn: $profile.skipCertVerify)
                    if profile.skipCertVerify {
                        Label(
                            "Warning: disabling certificate verification exposes your connection to man-in-the-middle attacks. Only use this for testing.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                    if !alwaysTLS {
                        TextField("uTLS Fingerprint (optional)", text: $profile.fingerprint)
                    }
                }
            }

            if hasReality && profile.tls {
                Section("Reality") {
                    TextField("Public Key (pbk)", text: $profile.realityPublicKey)
                    TextField("Short ID (sid, optional)", text: $profile.realityShortId)
                }
            }
        }
    }
}
