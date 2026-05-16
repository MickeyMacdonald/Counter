import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Recovery View

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
    @State private var showWipeAlternateConfirm = false
    @State private var isReseeding = false
    @State private var showClearDataConfirm = false
    @State private var showForceRecoveryConfirm = false
    @State private var showForceRecoverySuccess = false

    // .cntrdb export/import state. Mirrors the JSON backup state above so
    // the two flows look the same to the user even though the underlying
    // formats differ.
    @State private var isExportingCntrdb = false
    @State private var isImportingCntrdb = false
    @State private var lastCntrdbExportURL: URL?
    @State private var showCntrdbImportPicker = false
    @State private var pendingCntrdbImportURL: URL?
    @State private var showCntrdbImportConfirm = false
    @State private var showCntrdbImportSuccess = false
    @State private var lastCntrdbImportSummary: String?

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
            cntrdbSection
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
        // .cntrdb file picker — uses UTType.folder because we have not yet
        // registered com.counter.cntrdb in Info.plist. Validation in
        // performCntrdbImport rejects folders that aren't actual packages.
        .fileImporter(
            isPresented: $showCntrdbImportPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                pendingCntrdbImportURL = url
                showCntrdbImportConfirm = true
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .alert("Import .cntrdb?", isPresented: $showCntrdbImportConfirm, presenting: pendingCntrdbImportURL) { url in
            Button("Cancel", role: .cancel) { pendingCntrdbImportURL = nil }
            Button("Replace All Data", role: .destructive) {
                Task { await performCntrdbImport(from: url) }
            }
        } message: { url in
            Text("\"\(url.lastPathComponent)\" will replace ALL current data — clients, pieces, sessions, images, and settings. A safety snapshot of the current state will be saved first so you can roll back from the Safety Snapshots section.")
        }
        .alert("Import Complete", isPresented: $showCntrdbImportSuccess) {
            Button("OK") { }
        } message: {
            Text(lastCntrdbImportSummary ?? "Import succeeded.")
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

    // MARK: - Cntrdb (SQLite Database) Section
    //
    // The `.cntrdb` format is a folder bundle containing a public SQLite
    // schema, image tree, and integrity manifest. Lives next to the JSON
    // backup pipeline (does not replace it) — the JSON path stays as the
    // automatic safety net while `.cntrdb` is the user-facing share format.

    private var cntrdbSection: some View {
        Section {
            // Export
            Button {
                Task { await performCntrdbExport() }
            } label: {
                HStack {
                    Label("Export to .cntrdb…", systemImage: "square.and.arrow.up.on.square")
                    Spacer()
                    if isExportingCntrdb { ProgressView() }
                }
            }
            .disabled(isExportingCntrdb || isImportingCntrdb || isBackingUp || isRestoring)

            // Share most recent export — ShareLink only appears once we
            // have a URL on disk, so it doesn't show until the first export.
            if let url = lastCntrdbExportURL {
                ShareLink(item: url) {
                    Label("Share Last Export", systemImage: "square.and.arrow.up")
                }
            }

            // Import
            Button {
                showCntrdbImportPicker = true
            } label: {
                HStack {
                    Label("Import from .cntrdb…", systemImage: "square.and.arrow.down.on.square")
                    Spacer()
                    if isImportingCntrdb { ProgressView() }
                }
            }
            .disabled(isExportingCntrdb || isImportingCntrdb || isBackingUp || isRestoring)
        } header: {
            Text("Database File (.cntrdb)")
        } footer: {
            Text(".cntrdb is a portable database file you can share, archive, or move between devices. Importing replaces all current data — a safety snapshot is taken first so you can roll back.")
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

            Button(role: .destructive) {
                showWipeAlternateConfirm = true
            } label: {
                Label("Load Dataset B (★ BETA)", systemImage: "b.circle.fill")
            }
            .disabled(isReseeding || isBackingUp || isRestoring)
            .alert("Load Dataset B?", isPresented: $showWipeAlternateConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Wipe & Load B", role: .destructive) {
                    isReseeding = true
                    SeedDataService.wipeAndReseedAlternate(context: modelContext)
                    isReseeding = false
                }
            } message: {
                Text("Wipes all data and loads a small, clearly different dataset (BETA — clients, ★ piece names) so you can verify backup/restore round-trips at a glance.")
            }

            Divider()

            Button(role: .destructive) {
                showClearDataConfirm = true
            } label: {
                Label("Clear All Data", systemImage: "trash.fill")
            }
            .disabled(isReseeding || isBackingUp || isRestoring)
            .alert("Clear All Data?", isPresented: $showClearDataConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Clear Everything", role: .destructive) {
                    SeedDataService.clearAllData(context: modelContext)
                }
            } message: {
                Text("Permanently deletes all clients, pieces, sessions, and settings. Counter returns to the first-launch setup screen immediately. This cannot be undone.")
            }

            Button(role: .destructive) {
                showForceRecoveryConfirm = true
            } label: {
                Label("Force Recovery Mode on Next Launch", systemImage: "exclamationmark.triangle.fill")
            }
            .disabled(isReseeding || isBackingUp || isRestoring)
            .alert("Corrupt Store for Testing?", isPresented: $showForceRecoveryConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Corrupt Store", role: .destructive) {
                    do {
                        try RecoveryStoreReset.corruptStoreForTesting()
                        showForceRecoverySuccess = true
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            } message: {
                Text("Overwrites the SQLite store header with garbage. Force-close Counter, then reopen it — Recovery Mode should appear instead of the normal app. Your backups are unaffected.")
            }
            .alert("Store Corrupted", isPresented: $showForceRecoverySuccess) {
                Button("OK") { }
            } message: {
                Text("Force-close Counter now (swipe up in the app switcher), then reopen it. Recovery Mode should appear. Use Settings → Recovery to restore your data afterward.")
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Dataset A = full rich seed (20 clients). Dataset B = minimal distinct seed (3 BETA clients, ★ piece names) for backup testing.\n\nClear All Data returns the app to first-launch state. Force Recovery corrupts the store so the next cold launch hits RecoveryModeView.")
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

    // MARK: - Cntrdb actions

    /// Writes a fresh `.cntrdb` package into Documents/Counter Exports/
    /// and stashes the URL so the ShareLink row can pick it up.
    /// Files-app-visible because UIFileSharingEnabled is set on the bundle.
    private func performCntrdbExport() async {
        isExportingCntrdb = true
        defer { isExportingCntrdb = false }

        do {
            let fm = FileManager.default
            guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw CntrdbError.exportFailed("Could not locate Documents directory.")
            }
            let exportsDir = docs.appendingPathComponent("Counter Exports")
            try fm.createDirectory(at: exportsDir, withIntermediateDirectories: true)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let name = "Counter_\(formatter.string(from: Date())).\(CntrdbPackage.fileExtension)"
            let url = exportsDir.appendingPathComponent(name)

            _ = try await CntrdbExporter.shared.exportAll(
                to: url,
                context: modelContext,
                sourceDevice: UIDevice.current.name,
                notes: nil
            )

            lastCntrdbExportURL = url
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// Validates the user-picked folder, asks the importer to do the
    /// destructive replace, and surfaces a summary to the user. The
    /// security-scoped resource handshake is required because
    /// `.fileImporter` URLs come from outside our sandbox.
    private func performCntrdbImport(from url: URL) async {
        isImportingCntrdb = true
        defer {
            isImportingCntrdb = false
            pendingCntrdbImportURL = nil
        }

        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        do {
            try CntrdbPackage.validateLayout(at: url)
            let manifest = try await CntrdbImporter.shared.importPackage(at: url, context: modelContext)
            lastCntrdbImportSummary = "Imported \(manifest.modelCount) records and \(manifest.imageCount) images. You may need to relaunch the app for all changes to take effect."
            showCntrdbImportSuccess = true
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
