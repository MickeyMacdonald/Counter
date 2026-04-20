//
//  RecoveryModeView.swift
//  Counter
//
//  Shown when `CounterApp` cannot open the SwiftData ModelContainer on
//  launch — typically because a schema change defeated SwiftData's
//  automatic lightweight migration.
//
//  This view's job is to make sure the user is never bricked. It does
//  three things, in order of importance:
//
//    1. Tell them, in plain language, that their data is most likely
//       still on the device (because Counter never deletes the data
//       store on its own).
//    2. List the recovery backups that already exist on disk so they
//       can verify their data is recoverable.
//    3. Offer a clearly-labelled "Reset" action that deletes the
//       broken SwiftData store, after which a relaunch will create a
//       fresh empty store and the user can use the existing
//       Settings → Recovery flow to restore from a backup.
//
//  This is the first cut. A future version (0.9.x) will add a one-tap
//  "Reset & Restore" flow that creates a fresh container in-process.
//  For now, the explicit reset → relaunch → restore loop is the safest
//  thing because it never tries to construct a second ModelContainer
//  inside the same process as the failed first one.
//
//  See `docs/internal/VERSION_HISTORY.md` (0.8.x section) for context.
//

import SwiftUI

struct RecoveryModeView: View {
    let launchError: Error

    @State private var backups: [BackupMetadata] = []
    @State private var listError: String?
    @State private var isLoading = true
    @State private var showResetConfirmation = false
    @State private var showErrorDetails = false
    @State private var resetResult: ResetResult?

    fileprivate enum ResetResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    reassurance
                    backupsSection
                    actionsSection
                    errorDetailsSection
                    footer
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationTitle("Counter Recovery")
            .task { await loadBackups() }
            .alert("Reset Counter's data store?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { performReset() }
            } message: {
                Text(
                    """
                    This deletes Counter's broken data store. Your photos and \
                    your recovery backups are NOT touched. After resetting, \
                    quit and reopen Counter. It will launch fresh and empty, \
                    and you can restore from a backup using Settings → Recovery.
                    """
                )
            }
            .alert(item: resetResultBinding) { item in
                switch item.result {
                case .success:
                    return Alert(
                        title: Text("Reset complete"),
                        message: Text("Quit Counter and reopen it. The app will start fresh, and you can restore from a backup using Settings → Recovery."),
                        dismissButton: .default(Text("OK"))
                    )
                case .failure(let message):
                    return Alert(
                        title: Text("Reset failed"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }

        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Counter couldn't open your data")
                .font(.title)
                .fontWeight(.bold)
            Text("This usually means an app update changed how data is stored. Your information is most likely still on this device — Counter never deletes it on its own.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var reassurance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What this screen is", systemImage: "info.circle")
                .font(.headline)
            Text("Counter is in **Recovery Mode**. You're seeing this because the app couldn't load its data store on launch. Nothing has been changed or deleted. You have time to choose how to proceed — there is no rush.")
                .font(.subheadline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var backupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recovery backups", systemImage: "externaldrive.badge.checkmark")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.small)
                }
            }

            if let listError {
                Text(listError)
                    .font(.callout)
                    .foregroundStyle(.red)
            } else if !isLoading && backups.isEmpty {
                Text("No automatic backups were found on this device. If you have an iCloud-synced backup folder, it should appear here once iCloud has finished downloading. Otherwise, your most recent option is to reset and start fresh.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(backups) { backup in
                    backupRow(backup)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func backupRow(_ backup: BackupMetadata) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .fontWeight(.semibold)
            HStack(spacing: 12) {
                Label("\(backup.modelCount) records", systemImage: "tray.full")
                Label("\(backup.imageCount) images", systemImage: "photo.on.rectangle")
                Label(formatBytes(backup.jsonSizeBytes + backup.imageSizeBytes), systemImage: "internaldrive")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("Built with \(backup.appVersion)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recovery actions", systemImage: "wrench.and.screwdriver")
                .font(.headline)

            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Counter's data store").fontWeight(.semibold)
                        Text("Deletes the broken store. Your backups and photos are NOT touched.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var errorDetailsSection: some View {
        DisclosureGroup(isExpanded: $showErrorDetails) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(describing: launchError))
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.top, 8)
                Text("If you contact support, please copy the text above so the cause can be identified.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label("Technical details", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Need help?")
                .font(.headline)
            Text("Email mickey@thecounterapp.ca with the technical details above and we'll figure out what happened together. Don't reset until you've copied the error text — it helps diagnose the cause.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func loadBackups() async {
        isLoading = true
        defer { isLoading = false }
        do {
            backups = try await RecoveryService.shared.listBackups()
        } catch {
            listError = "Could not list backups: \(error.localizedDescription)"
        }
    }

    private func performReset() {
        do {
            try RecoveryStoreReset.deleteSwiftDataStore()
            resetResult = .success
        } catch {
            resetResult = .failure(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private var resetResultBinding: Binding<ResetResultIdentifiable?> {
        Binding(
            get: { resetResult.map(ResetResultIdentifiable.init) },
            set: { newValue in
                if newValue == nil { resetResult = nil }
            }
        )
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Identifiable shim for .alert(item:)

private struct ResetResultIdentifiable: Identifiable {
    let id = UUID()
    let result: RecoveryModeView.ResetResult

    init(_ result: RecoveryModeView.ResetResult) { self.result = result }
}

// MARK: - Store Reset Helper

/// Locates and deletes SwiftData's default on-disk store files so that
/// the next launch creates a fresh, empty container.
///
/// SwiftData stores three files alongside each other when no explicit
/// URL is provided: `default.store`, `default.store-shm`, and
/// `default.store-wal`. All three must be removed for a clean reset.
///
/// This helper deliberately does NOT touch:
///   - `Documents/Counter Recovery/` (the recovery backups)
///   - `Documents/CounterImages/` (the image binaries)
///
/// so that after the reset and a relaunch, the existing
/// Settings → Recovery flow can restore the previous state.
enum RecoveryStoreReset {
    enum ResetError: LocalizedError {
        case applicationSupportUnavailable
        case noStoreFound

        var errorDescription: String? {
            switch self {
            case .applicationSupportUnavailable:
                return "Could not locate the Application Support directory."
            case .noStoreFound:
                return "No SwiftData store files were found to delete. The reset may not have been needed, or the store is at an unexpected location."
            }
        }
    }

    static func deleteSwiftDataStore() throws {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            throw ResetError.applicationSupportUnavailable
        }

        // SwiftData's default store name is "default.store" with two
        // sidecar files. Older or future versions may use a different
        // base name, so we also sweep for any *.store / *.store-shm /
        // *.store-wal files in Application Support to be thorough.
        let candidateExtensions = [".store", ".store-shm", ".store-wal"]
        var deletedAny = false

        let contents = (try? fileManager.contentsOfDirectory(
            at: appSupport,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        for url in contents where candidateExtensions.contains(where: { url.lastPathComponent.hasSuffix($0) }) {
            do {
                try fileManager.removeItem(at: url)
                deletedAny = true
            } catch {
                // Swallow per-file failures; we'll surface a single
                // error if literally nothing was deleted.
                continue
            }
        }

        if !deletedAny {
            throw ResetError.noStoreFound
        }
    }
}
