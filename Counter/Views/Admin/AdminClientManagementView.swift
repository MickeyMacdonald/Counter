import SwiftUI
import SwiftData

struct AdminClientManagementView: View {
    @Query private var clients: [Client]
    @Environment(\.modelContext) private var modelContext
    @State private var clientPendingDelete: Client?

    private var archivedClients: [Client] {
        clients
            .filter { $0.isArchived && !$0.isBlacklisted && !$0.isFlashPortfolioClient }
            .sorted { $0.fullName < $1.fullName }
    }

    private var blacklistedClients: [Client] {
        clients
            .filter { $0.isBlacklisted && !$0.isFlashPortfolioClient }
            .sorted { $0.fullName < $1.fullName }
    }

    private var blacklistExportText: String {
        let date = Date().formatted(date: .long, time: .omitted)
        var lines = ["COUNTER — CLIENT BLACKLIST", "Exported \(date)", ""]
        for (i, client) in blacklistedClients.enumerated() {
            var entry = "\(i + 1). \(client.fullName)"
            if !client.phone.isEmpty { entry += " — \(client.phone)" }
            if !client.email.isEmpty { entry += " — \(client.email)" }
            lines.append(entry)
            if !client.blacklistNote.isEmpty {
                lines.append("   Reason: \(client.blacklistNote)")
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        List {
            archivedSection
            blacklistSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Client Records")
        .confirmationDialog(
            "Permanently delete \(clientPendingDelete?.fullName ?? "this client")?",
            isPresented: Binding(
                get: { clientPendingDelete != nil },
                set: { if !$0 { clientPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                if let client = clientPendingDelete {
                    modelContext.delete(client)
                }
                clientPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                clientPendingDelete = nil
            }
        } message: {
            Text("All pieces, payments, agreements, and history for this client will be deleted. This cannot be undone.")
        }
    }

    // MARK: - Archived Section

    private var archivedSection: some View {
        Section {
            if archivedClients.isEmpty {
                Text("No archived clients")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(archivedClients) { client in
                    archivedRow(client)
                }
            }
        } header: {
            Text("Archived (\(archivedClients.count))")
        } footer: {
            if !archivedClients.isEmpty {
                Text("Archived clients are hidden from the main client list. Restore to make them active again.")
            }
        }
    }

    private func archivedRow(_ client: Client) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(client.fullName)
                    .font(.body.weight(.medium))
                if !client.email.isEmpty {
                    Text(client.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Restore") {
                    client.isArchived = false
                    client.updatedAt = Date()
                }
                .buttonStyle(.bordered)
                .tint(.green)
                .controlSize(.small)

                Button(role: .destructive) {
                    clientPendingDelete = client
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Blacklist Section

    private var blacklistSection: some View {
        Section {
            if blacklistedClients.isEmpty {
                Text("No blacklisted clients")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(blacklistedClients) { client in
                    blacklistRow(client)
                }
            }
        } header: {
            HStack {
                Text("Blacklist (\(blacklistedClients.count))")
                Spacer()
                if !blacklistedClients.isEmpty {
                    ShareLink(
                        item: blacklistExportText,
                        subject: Text("Counter Client Blacklist"),
                        message: Text("Exported from Counter")
                    ) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.medium))
                    }
                }
            }
        } footer: {
            if !blacklistedClients.isEmpty {
                Text("Use Export to share the blacklist with other artists or studios.")
            }
        }
    }

    private func blacklistRow(_ client: Client) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(client.fullName)
                    .font(.body.weight(.medium))
                if !client.phone.isEmpty {
                    Text(client.phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !client.blacklistNote.isEmpty {
                    Text(client.blacklistNote)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.top, 2)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Remove") {
                    client.isBlacklisted = false
                    client.blacklistNote = ""
                    client.updatedAt = Date()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.small)

                Button(role: .destructive) {
                    clientPendingDelete = client
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        AdminClientManagementView()
    }
    .modelContainer(PreviewContainer.shared.container)
}
