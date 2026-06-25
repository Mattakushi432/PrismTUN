import SwiftUI

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

private struct ProfileListContent: View {
    let viewModel: ProfilesViewModel
    @Binding var showAdd: Bool
    @Binding var showImport: Bool
    @Binding var importURI: String

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
            URIImportView(uri: $importURI) { uri in
                Task { await viewModel.importFromURI(uri) }
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Button { showImport = true } label: {
                Label("Import URI", systemImage: "link.badge.plus")
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
            description: Text("Add a proxy profile to get started")
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

private struct ProfileRow: View {
    let profile: ProxyProfile
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? .accentColor : .secondary)
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
                        .foregroundStyle(.accentColor)
                        .clipShape(Capsule())
                    Text("\(profile.server):\(profile.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Select", action: onSelect)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

private struct URIImportView: View {
    @Binding var uri: String
    let onImport: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Import from URI").font(.headline)
            TextEditor(text: $uri)
                .font(.system(.body, design: .monospaced))
                .frame(height: 100)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Import") {
                    onImport(uri)
                    uri = ""
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
