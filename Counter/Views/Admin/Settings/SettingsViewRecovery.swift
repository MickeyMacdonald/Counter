import SwiftUI
import SwiftData

// MARK: - Recovery Backup View (Alpha Safety Net)
// Temporary backup/restore UI for alpha testers. Will be retired at release.

struct SettingsViewRecovery: View {
    @Environment(\.modelContext) private var modelContext
    @State private var backups: [BackupMetadata] = []
    @State private var isBackingUp = false
    @State private var isRestoring = false
    @State private var lastBackupDate: Date?
    @State private var lastBackupError: String?
    @State private var storageUsed: UInt64 = 0
    @State private var isICloudAvailable = false
    @State private var selectedBackup: BackupMetadata?
    @State private var showRestoreConfirm = false
    @State private var showRestoreSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showWipeConfirm = false
    @State private var isReseeding = false

    private var userBackups: [BackupMetadata] {
        backups.filter { $0.effectiveKind == .userBackup }
    }

    private var snapshotBackups: [BackupMetadata] {
        backups.filter { $0.effectiveKind == .preRestoreSnapshot }
    }

    var body: some View {
        List {
            statusSection
            backupSection
            backupsListSection
            if !snapshotBackups.isEmpty {
                snapshotsListSection
            }
            developerSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Recovery")
        .task { await refresh() }
        .alert("Restore Backup?", isPresented: $showRestoreConfirm, presenting: selectedBackup) { backup in
            Button("Cancel", role: .cancel) { }
            Button("Replace All Data", role: .destructive) {
                Task { await performRestore(backup) }
            }
        } message: { backup in
            Text("This will replace ALL current data — clients, pieces, sessions, images, and settings — with the backup from \(backup.createdAt.formatted(date: .abbreviated, time: .shortened)). This cannot be undone.")
        }
        .alert("Restore Complete", isPresented: $showRestoreSuccess) {
            Button("OK") { }
        } message: {
            Text("All data has been restored successfully. You may need to relaunch the app for all changes to take effect.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section("Status") {
            LabeledContent("Last Backup") {
                if let date = lastBackupDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Never")
                        .foregroundStyle(.tertiary)
                }
            }

            LabeledContent("Location") {
                HStack(spacing: 4) {
                    Image(systemName: isICloudAvailable ? "icloud.fill" : "ipad")
                        .font(.caption)
                    Text(isICloudAvailable ? "iCloud Drive" : "On This iPad")
                }
                .foregroundStyle(.secondary)
            }

            LabeledContent("Storage Used") {
                Text(formatBytes(storageUsed))
                    .foregroundStyle(.secondary)
            }

            if let error = lastBackupError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Backup Button Section

    private var backupSection: some View {
        Section {
            Button {
                Task { await performBackup() }
            } label: {
                HStack {
                    Label("Back Up Now", systemImage: "arrow.clockwise.icloud")
                    Spacer()
                    if isBackingUp {
                        ProgressView()
                    }
                }
            }
            .disabled(isBackingUp || isRestoring)
        } footer: {
            Text("Backups are also created automatically when the app goes to the background. The last 3 manual backups and the last 3 pre-restore safety snapshots are kept.")
        }
    }

    // MARK: - Backups List Section

    private var backupsListSection: some View {
        Section("Available Backups") {
            if userBackups.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No backups yet")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                ForEach(userBackups) { backup in
                    backupRow(backup)
                }
            }

            if isRestoring {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Restoring…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Pre-restore safety snapshots are pruned on a separate budget from
    /// regular backups so they can't push real user backups out of
    /// rotation. They live in their own section so users can find them
    /// when they want to undo a restore but don't have to scroll past
    /// them in the normal flow.
    private var snapshotsListSection: some View {
        Section {
            ForEach(snapshotBackups) { backup in
                backupRow(backup)
            }
        } header: {
            Text("Safety Snapshots")
        } footer: {
            Text("Counter automatically saves a snapshot of your current data right before any restore. If a restore went the wrong way, you can roll back from here.")
        }
    }

    private func backupRow(_ backup: BackupMetadata) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.medium))
                Text("\(backup.modelCount) records, \(backup.imageCount) images")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatBytes(backup.jsonSizeBytes + backup.imageSizeBytes))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                selectedBackup = backup
                showRestoreConfirm = true
            } label: {
                Text("Restore")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(isBackingUp || isRestoring)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Developer Section

    private var developerSection: some View {
        Section {
            Button(role: .destructive) {
                showWipeConfirm = true
            } label: {
                HStack {
                    Label("Reset to Test Data", systemImage: "arrow.counterclockwise.circle.fill")
                    Spacer()
                    if isReseeding { ProgressView() }
                }
            }
            .disabled(isReseeding || isBackingUp || isRestoring)
            .alert("Reset to Test Data?", isPresented: $showWipeConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Wipe & Reseed", role: .destructive) {
                    isReseeding = true
                    SeedDataService.wipeAndReseed(context: modelContext)
                    isReseeding = false
                }
            } message: {
                Text("This will permanently delete ALL current data and replace it with 20 sample clients across 8 months of history. This cannot be undone.")
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Wipes the store completely and populates it with rich test data spanning multiple months, payment scenarios, and piece statuses.")
        }
    }

    // MARK: - Actions

    private func performBackup() async {
        isBackingUp = true
        defer { isBackingUp = false }

        do {
            try await RecoveryService.shared.performBackup(context: modelContext)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func performRestore(_ backup: BackupMetadata) async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await RecoveryService.shared.restore(from: backup, context: modelContext)
            showRestoreSuccess = true
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func refresh() async {
        isICloudAvailable = await RecoveryService.shared.isICloudAvailable
        lastBackupDate = await RecoveryService.shared.lastBackupDate
        lastBackupError = await RecoveryService.shared.lastBackupError
        backups = (try? await RecoveryService.shared.listBackups()) ?? []
        storageUsed = (try? await RecoveryService.shared.totalBackupStorageBytes()) ?? 0
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    NavigationStack {
        SettingsViewRecovery()
    }
    .modelContainer(PreviewContainer.shared.container)
}
