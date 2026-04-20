import Foundation
import SwiftData
import CryptoKit

// MARK: - Recovery Service (Alpha Safety Net)
// Temporary auto-backup service for alpha testers. Will be retired at release.

actor RecoveryService {
    static let shared = RecoveryService()

    private let maxBackupCount = 3
    private let maxPreRestoreSnapshotCount = 3
    private let backupFolderName = "Counter Recovery"
    private let imagesFolderName = "Images"
    private let userBackupPrefix = "counter_recovery_"
    private let preRestorePrefix = "counter_pre_restore_"
    private let fileManager = FileManager.default

    // Observable state for the UI
    var lastBackupDate: Date?
    var lastBackupError: String?

    // Debounce: skip backup if one happened recently
    private let minimumBackupInterval: TimeInterval = 60

    // MARK: - Version & Integrity Helpers

    /// Marketing version string sourced from the bundle so backups never lie
    /// about which build wrote them. Replaces the previous hardcoded
    /// `"Pre-Alpha 0.2"` literal that drifted as soon as the in-app About
    /// screen was bumped.
    static var currentAppVersion: String {
        let short = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        return "\(short) (\(build))"
    }

    /// SHA-256 hex digest used to detect accidental corruption (truncated
    /// writes, partial iCloud sync, bit rot). This is NOT an adversarial
    /// integrity guarantee — `metadata.json` itself is not signed — but it
    /// catches the failure modes that matter for a single-user offline app.
    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Public API

    @discardableResult
    func performBackup(context: ModelContext) async throws -> BackupMetadata {
        // Debounce — only applies to user-initiated backups. Pre-restore
        // snapshots bypass this entirely via `performPreRestoreSnapshot`.
        if let last = lastBackupDate, Date().timeIntervalSince(last) < minimumBackupInterval {
            throw RecoveryError.serializationFailed("Backup skipped — too soon since last backup.")
        }

        let metadata = try await performBackupInternal(
            context: context,
            kind: .userBackup,
            folderPrefix: userBackupPrefix
        )

        // Prune *user* backups only — pre-restore snapshots have their own budget.
        try pruneOldBackups()

        lastBackupDate = Date()
        lastBackupError = nil

        return metadata
    }

    /// Captures the *current* state of the store as a `.preRestoreSnapshot`
    /// so a subsequent `restore(from:)` is one-tap-rollback-safe. Bypasses
    /// the user-backup debounce and uses a dedicated retention budget so it
    /// never pushes a real user backup out of rotation.
    @discardableResult
    func performPreRestoreSnapshot(context: ModelContext) async throws -> BackupMetadata {
        let metadata = try await performBackupInternal(
            context: context,
            kind: .preRestoreSnapshot,
            folderPrefix: preRestorePrefix
        )
        try prunePreRestoreSnapshots()
        return metadata
    }

    /// Shared backup pipeline used by both user-initiated backups and
    /// pre-restore snapshots. The only differences between the two callers
    /// are the folder prefix, the `BackupKind` recorded in metadata, and
    /// the retention budget — handled by the wrappers above.
    private func performBackupInternal(
        context: ModelContext,
        kind: BackupKind,
        folderPrefix: String
    ) async throws -> BackupMetadata {
        // 1. Serialize all models on the main actor (ModelContext requirement)
        let backup = try await MainActor.run {
            try serializeAllModels(context: context)
        }

        // 2. Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(backup)

        // 3. Compute SHA-256 over the encoded payload BEFORE it touches disk.
        //    The checksum captures the bytes the decoder will see, so any
        //    mid-write truncation or sync-conflict garbling will fail the
        //    check on restore.
        let checksum = Self.sha256Hex(jsonData)

        // 4. Create backup folder
        let containerURL = try backupContainerURL()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let folderName = "\(folderPrefix)\(formatter.string(from: Date()))"
        let backupURL = containerURL.appendingPathComponent(folderName)
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)

        // 5. Write JSON
        let jsonURL = backupURL.appendingPathComponent("backup.json")
        try jsonData.write(to: jsonURL)

        // 6. Copy images
        let imageCount = try copyImages(to: backupURL)

        // 7. Calculate sizes
        let imageSizeBytes = directorySize(at: backupURL.appendingPathComponent(imagesFolderName))

        // 8. Write metadata
        let metadata = BackupMetadata(
            id: UUID(),
            createdAt: Date(),
            appVersion: Self.currentAppVersion,
            modelCount: totalModelCount(backup),
            imageCount: imageCount,
            jsonSizeBytes: UInt64(jsonData.count),
            imageSizeBytes: imageSizeBytes,
            folderName: folderName,
            jsonChecksum: checksum,
            kind: kind
        )
        let metaEncoder = JSONEncoder()
        metaEncoder.dateEncodingStrategy = .iso8601
        metaEncoder.outputFormatting = .prettyPrinted
        let metaData = try metaEncoder.encode(metadata)
        try metaData.write(to: backupURL.appendingPathComponent("metadata.json"))

        // 9. Mirror JSON + metadata + images to local Documents (Files-app
        //    visible, beta safety net). Images are now included so the
        //    mirror is fully self-contained — accepted filesystem cost for
        //    the beta cycle, will be revisited in 1.1.x.
        try mirrorToLocalDocuments(
            backupURL: backupURL,
            jsonData: jsonData,
            metaData: metaData,
            includeImages: true
        )

        return metadata
    }

    func listBackups() throws -> [BackupMetadata] {
        let containerURL = try backupContainerURL()
        let contents = try fileManager.contentsOfDirectory(
            at: containerURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var backups: [BackupMetadata] = []
        for folder in contents {
            let metaURL = folder.appendingPathComponent("metadata.json")
            guard fileManager.fileExists(atPath: metaURL.path) else { continue }
            if let data = try? Data(contentsOf: metaURL),
               let meta = try? decoder.decode(BackupMetadata.self, from: data) {
                backups.append(meta)
            }
        }

        return backups.sorted { $0.createdAt > $1.createdAt }
    }

    func restore(from metadata: BackupMetadata, context: ModelContext) async throws {
        let containerURL = try backupContainerURL()
        let backupURL = containerURL.appendingPathComponent(metadata.folderName)
        let jsonURL = backupURL.appendingPathComponent("backup.json")

        guard fileManager.fileExists(atPath: jsonURL.path) else {
            throw RecoveryError.backupNotFound
        }

        // 1. Read the backup payload off disk.
        //    Everything from here through step 7 is *non-destructive* — we
        //    only touch the live store after every preflight check passes.
        let jsonData = try Data(contentsOf: jsonURL)

        // 2. Integrity check. Backups written before checksums shipped have
        //    `jsonChecksum == nil` and skip this — they're grandfathered in,
        //    not silently trusted forever. The UI can flag them separately.
        if let expected = metadata.jsonChecksum {
            let actual = Self.sha256Hex(jsonData)
            guard expected == actual else {
                throw RecoveryError.checksumMismatch(expected: expected, actual: actual)
            }
        }

        // 3. Decode the payload.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: RecoveryBackup
        do {
            backup = try decoder.decode(RecoveryBackup.self, from: jsonData)
        } catch {
            throw RecoveryError.deserializationFailed(error.localizedDescription)
        }

        // 4. Schema version check. Forward-migration of backups across
        //    schema versions lands as part of pillar 1 (0.9.0). For now,
        //    a mismatch is a hard reject.
        guard backup.version == RecoveryBackup.currentVersion else {
            throw RecoveryError.versionMismatch(
                found: backup.version,
                expected: RecoveryBackup.currentVersion
            )
        }

        // 5. Refuse empty restores. A backup with zero records cannot
        //    silently destroy a populated store. If a user genuinely wants
        //    an empty database, they can use Recovery Mode → Reset.
        let totalRecords = totalModelCount(backup)
        guard totalRecords > 0 else {
            throw RecoveryError.refuseEmptyRestore
        }

        // 6. Pre-flight image check. If the metadata claims this backup
        //    has images but the Images folder is missing, fail loudly
        //    BEFORE touching the live store.
        if metadata.imageCount > 0 {
            let sourceBase = backupURL.appendingPathComponent(imagesFolderName)
            if !fileManager.fileExists(atPath: sourceBase.path) {
                throw RecoveryError.imageCountMismatch(
                    expected: metadata.imageCount,
                    actual: 0
                )
            }
        }

        // 7. Pre-restore snapshot of the CURRENT state. This is the
        //    one-tap rollback point. If we can't take it, we refuse to
        //    proceed — the cost of being wrong here is the user's data.
        do {
            _ = try await performPreRestoreSnapshot(context: context)
        } catch {
            throw RecoveryError.preRestoreSnapshotFailed(error.localizedDescription)
        }

        // 8. Wipe existing data, then insert from backup (on main actor
        //    for ModelContext). If this throws, the pre-restore snapshot
        //    from step 7 still exists and the user can re-run restore
        //    against it from Settings → Recovery.
        try await MainActor.run {
            try wipeAllData(context: context)
            try deserializeAndInsert(backup, context: context)
            try context.save()
        }

        // 9. Restore images and verify the post-copy file count matches
        //    what the metadata claimed. A mismatch means the destination
        //    is in a partially-populated state — surface that to the user
        //    so they can re-run restore against the pre-restore snapshot.
        try restoreImages(from: backupURL, expectedCount: metadata.imageCount)

        // 10. Restore UserDefaults (last, because it's the cheapest to
        //     re-do and the least likely to fail catastrophically).
        restoreUserDefaults(backup.userDefaults)
    }

    func deleteBackup(_ metadata: BackupMetadata) throws {
        let containerURL = try backupContainerURL()
        let backupURL = containerURL.appendingPathComponent(metadata.folderName)
        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }
    }

    func totalBackupStorageBytes() throws -> UInt64 {
        let containerURL = try backupContainerURL()
        return directorySize(at: containerURL)
    }

    var isICloudAvailable: Bool {
        fileManager.ubiquityIdentityToken != nil
    }

    // MARK: - Backup Container

    private func backupContainerURL() throws -> URL {
        // Try iCloud Documents first
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            let documentsURL = iCloudURL
                .appendingPathComponent("Documents")
                .appendingPathComponent(backupFolderName)
            try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            return documentsURL
        }

        // Fallback: local Documents (visible in Files if UIFileSharingEnabled is set)
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw RecoveryError.serializationFailed("Could not locate Documents directory.")
        }
        let localURL = docs.appendingPathComponent(backupFolderName)
        try fileManager.createDirectory(at: localURL, withIntermediateDirectories: true)
        return localURL
    }

    // MARK: - Serialization

    @MainActor
    private func serializeAllModels(context: ModelContext) throws -> RecoveryBackup {
        // Fetch all records
        let clients = try context.fetch(FetchDescriptor<Client>())
        let pieces = try context.fetch(FetchDescriptor<Piece>())
        let sessions = try context.fetch(FetchDescriptor<Session>())
        let sessionProgress = try context.fetch(FetchDescriptor<SessionProgress>())
        let pieceImages = try context.fetch(FetchDescriptor<PieceImage>())
        let inspirationImages = try context.fetch(FetchDescriptor<PieceImage>())
        let bookings = try context.fetch(FetchDescriptor<Booking>())
        let agreements = try context.fetch(FetchDescriptor<Agreement>())
        let commLogs = try context.fetch(FetchDescriptor<CommunicationLog>())
        let payments = try context.fetch(FetchDescriptor<Payment>())
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let customSessionTypes = try context.fetch(FetchDescriptor<SessionType>())
        let customEmailTemplates = try context.fetch(FetchDescriptor<EmailTemplate>())
        let availabilitySlots = try context.fetch(FetchDescriptor<AvailabilitySlot>())
        let availabilityOverrides = try context.fetch(FetchDescriptor<AvailabilityOverride>())
        let sessionRateConfigs = try context.fetch(FetchDescriptor<SessionRateConfig>())
        let flashPriceTiers = try context.fetch(FetchDescriptor<FlashPriceTier>())
        let customGalleryGroups = try context.fetch(FetchDescriptor<GalleryGroup>())
        let customDiscounts = try context.fetch(FetchDescriptor<Discount>())

        // Build ID lookup tables: object identity → UUID
        var clientIDs: [ObjectIdentifier: UUID] = [:]
        var pieceIDs: [ObjectIdentifier: UUID] = [:]
        var sessionIDs: [ObjectIdentifier: UUID] = [:]
        var imageGroupIDs: [ObjectIdentifier: UUID] = [:]

        for c in clients { clientIDs[ObjectIdentifier(c)] = UUID() }
        for p in pieces { pieceIDs[ObjectIdentifier(p)] = UUID() }
        for s in sessions { sessionIDs[ObjectIdentifier(s)] = UUID() }
        for ig in sessionProgress { imageGroupIDs[ObjectIdentifier(ig)] = UUID() }

        // Serialize each model
        let clientBackups = clients.map { c in
            let id = clientIDs[ObjectIdentifier(c)]!
            return ClientBackup(
                backupID: id,
                firstName: c.firstName, lastName: c.lastName,
                email: c.email, phone: c.phone, notes: c.notes,
                pronouns: c.pronouns, birthdate: c.birthdate,
                allergyNotes: c.allergyNotes,
                streetAddress: c.streetAddress, city: c.city,
                state: c.state, zipCode: c.zipCode,
                profilePhotoPath: c.profilePhotoPath,
                emailOptIn: c.emailOptIn,
                isFlashPortfolioClient: c.isFlashPortfolioClient,
                createdAt: c.createdAt, updatedAt: c.updatedAt
            )
        }

        let pieceBackups = pieces.map { p in
            let id = pieceIDs[ObjectIdentifier(p)]!
            let clientID = p.client.flatMap { clientIDs[ObjectIdentifier($0)] }
            return PieceBackup(
                backupID: id, clientBackupID: clientID,
                title: p.title, bodyPlacement: p.bodyPlacement,
                descriptionText: p.descriptionText,
                status: p.status.rawValue, pieceType: p.pieceType.rawValue,
                tags: p.tags, primaryImagePath: p.primaryImagePath,
                rating: p.rating, size: p.size?.rawValue,
                sizeDimensions: p.sizeDimensions,
                hourlyRate: p.hourlyRate, flatRate: p.flatRate,
                depositAmount: p.depositAmount,
                createdAt: p.createdAt, updatedAt: p.updatedAt,
                completedAt: p.completedAt
            )
        }

        let sessionBackups = sessions.map { s in
            let id = sessionIDs[ObjectIdentifier(s)]!
            let pieceID = s.piece.flatMap { pieceIDs[ObjectIdentifier($0)] }
            return SessionBackup(
                backupID: id, pieceBackupID: pieceID,
                date: s.date, startTime: s.startTime, endTime: s.endTime,
                breakMinutes: s.breakMinutes,
                sessionType: s.sessionType.rawValue,
                hourlyRateAtTime: s.hourlyRateAtTime, flashRate: s.flashRate,
                manualHoursOverride: s.manualHoursOverride,
                isNoShow: s.isNoShow, noShowFee: s.noShowFee,
                notes: s.notes
            )
        }

        let imageGroupBackups = sessionProgress.map { ig in
            let id = imageGroupIDs[ObjectIdentifier(ig)]!
            let pieceID = ig.piece.flatMap { pieceIDs[ObjectIdentifier($0)] }
            let sessionID = ig.session.flatMap { sessionIDs[ObjectIdentifier($0)] }
            return SessionProgressBackup(
                backupID: id, pieceBackupID: pieceID, sessionBackupID: sessionID,
                stage: ig.stage.rawValue, notes: ig.notes,
                timeSpentMinutes: ig.timeSpentMinutes, createdAt: ig.createdAt
            )
        }

        let pieceImageBackups = pieceImages.map { pi in
            let igID = pi.sessionProgress.flatMap { imageGroupIDs[ObjectIdentifier($0)] }
            let pieceID = pi.piece.flatMap { pieceIDs[ObjectIdentifier($0)] }
            return PieceImageBackup(
                backupID: UUID(), imageGroupBackupID: igID, pieceBackupID: pieceID,
                filePath: pi.filePath, fileName: pi.fileName,
                notes: pi.notes, capturedAt: pi.capturedAt,
                sortOrder: pi.sortOrder, isPrimary: pi.isPrimary,
                category: pi.category?.rawValue, tags: pi.tags
            )
        }

        let inspirationBackups = inspirationImages.map { img in
            PieceImageBackup(
                backupID: UUID(),
                filePath: img.filePath, fileName: img.fileName,
                tags: img.tags, notes: img.notes, capturedAt: img.capturedAt
            )
        }

        let bookingBackups = bookings.map { b in
            let clientID = b.client.flatMap { clientIDs[ObjectIdentifier($0)] }
            let pieceID = b.piece.flatMap { pieceIDs[ObjectIdentifier($0)] }
            return BookingBackup(
                backupID: UUID(), clientBackupID: clientID, pieceBackupID: pieceID,
                date: b.date, startTime: b.startTime, endTime: b.endTime,
                status: b.status.rawValue, bookingType: b.bookingType.rawValue,
                notes: b.notes, depositPaid: b.depositPaid,
                reminderSent: b.reminderSent,
                checklistOverrides: b.checklistOverrides,
                customChecklistItems: b.customChecklistItems,
                createdAt: b.createdAt, updatedAt: b.updatedAt
            )
        }

        let agreementBackups = agreements.map { a in
            let clientID = a.client.flatMap { clientIDs[ObjectIdentifier($0)] }
            return AgreementBackup(
                backupID: UUID(), clientBackupID: clientID,
                title: a.title, agreementType: a.agreementType.rawValue,
                bodyText: a.bodyText, isSigned: a.isSigned,
                signedAt: a.signedAt, signatureImagePath: a.signatureImagePath,
                createdAt: a.createdAt
            )
        }

        let commLogBackups = commLogs.map { cl in
            let clientID = cl.client.flatMap { clientIDs[ObjectIdentifier($0)] }
            return CommunicationLogBackup(
                backupID: UUID(), clientBackupID: clientID,
                commType: cl.commType.rawValue, subject: cl.subject,
                bodyText: cl.bodyText, sentAt: cl.sentAt,
                wasAutoGenerated: cl.wasAutoGenerated
            )
        }

        let paymentBackups = payments.map { pay in
            let clientID = pay.client.flatMap { clientIDs[ObjectIdentifier($0)] }
            let pieceID = pay.piece.flatMap { pieceIDs[ObjectIdentifier($0)] }
            return PaymentBackup(
                backupID: UUID(), clientBackupID: clientID, pieceBackupID: pieceID,
                amount: pay.amount, paymentDate: pay.paymentDate,
                paymentMethod: pay.paymentMethod.rawValue,
                paymentType: pay.paymentType.rawValue,
                notes: pay.notes, createdAt: pay.createdAt
            )
        }

        let profileBackups = profiles.map { p in
            UserProfileBackup(
                backupID: UUID(),
                firstName: p.firstName, lastName: p.lastName,
                businessName: p.businessName,
                email: p.email, phone: p.phone,
                profession: p.profession.rawValue,
                profilePhotoPath: p.profilePhotoPath,
                defaultHourlyRate: p.defaultHourlyRate, currency: p.currency,
                depositFlat: p.depositFlat, depositPercentage: p.depositPercentage,
                friendsFamilyDiscount: p.friendsFamilyDiscount,
                preferredClientDiscount: p.preferredClientDiscount,
                holidayDiscount: p.holidayDiscount,
                conventionDiscount: p.conventionDiscount,
                noShowFee: p.noShowFee, revisionFee: p.revisionFee,
                administrativeFee: p.administrativeFee,
                flashPricingModeRaw: p.flashPricingModeRaw,
                chargeableSessionTypes: p.chargeableSessionTypes,
                statusColorNames: p.statusColorNames,
                shopAddressLine1: p.shopAddressLine1,
                shopAddressLine2: p.shopAddressLine2,
                shopCity: p.shopCity, shopState: p.shopState,
                shopPostalCode: p.shopPostalCode, shopCountry: p.shopCountry,
                billingAddressLine1: p.billingAddressLine1,
                billingAddressLine2: p.billingAddressLine2,
                billingCity: p.billingCity, billingState: p.billingState,
                billingPostalCode: p.billingPostalCode, billingCountry: p.billingCountry,
                createdAt: p.createdAt, updatedAt: p.updatedAt
            )
        }

        let cstBackups = customSessionTypes.map { cst in
            SessionTypeBackup(
                backupID: UUID(), uuid: cst.uuid,
                name: cst.name, isChargeable: cst.isChargeable,
                sortOrder: cst.sortOrder, createdAt: cst.createdAt
            )
        }

        let cetBackups = customEmailTemplates.map { cet in
            EmailTemplateBackup(
                backupID: UUID(), name: cet.name,
                subject: cet.subject, body: cet.body,
                categoryRaw: cet.categoryRaw,
                createdAt: cet.createdAt, updatedAt: cet.updatedAt
            )
        }

        let slotBackups = availabilitySlots.map { s in
            AvailabilitySlotBackup(
                backupID: UUID(), dayOfWeek: s.dayOfWeek,
                startTime: s.startTime, endTime: s.endTime,
                slotTypeRaw: s.slotTypeRaw, isFlashOnly: s.isFlashOnly,
                isActive: s.isActive
            )
        }

        let overrideBackups = availabilityOverrides.map { o in
            AvailabilityOverrideBackup(
                backupID: UUID(), startDate: o.startDate,
                endDate: o.endDate, reason: o.reason,
                isUnavailable: o.isUnavailable
            )
        }

        let srcBackups = sessionRateConfigs.map { src in
            SessionRateConfigBackup(
                backupID: UUID(), sessionTypeRaw: src.sessionTypeRaw,
                rateModeRaw: src.rateModeRaw, rateValue: src.rateValue,
                depositModeRaw: src.depositModeRaw,
                discountTypeRaw: src.discountTypeRaw,
                feeTypeRaw: src.feeTypeRaw,
                flashPricingModeRaw: src.flashPricingModeRaw
            )
        }

        let fptBackups = flashPriceTiers.map { fpt in
            FlashPriceTierBackup(
                backupID: UUID(), uuid: fpt.uuid,
                label: fpt.label,
                widthInches: fpt.widthInches, heightInches: fpt.heightInches,
                price: fpt.price, sortOrder: fpt.sortOrder
            )
        }

        let cggBackups = customGalleryGroups.map { cgg in
            GalleryGroupBackup(
                backupID: UUID(), name: cgg.name,
                tags: cgg.tags, sortIndex: cgg.sortIndex,
                createdAt: cgg.createdAt
            )
        }

        let cdBackups = customDiscounts.map { cd in
            DiscountBackup(
                backupID: UUID(),
                name: cd.name,
                percentage: cd.percentage,
                sortOrder: cd.sortOrder
            )
        }

        // UserDefaults snapshot
        let defaults = UserDefaults.standard
        let udBackup = UserDefaultsBackup(
            businessLockEnabled: defaults.object(forKey: "businessLockEnabled") as? Bool,
            businessLockPIN: defaults.string(forKey: "businessLockPIN"),
            todoDismissedIDs: defaults.string(forKey: "todo.dismissedIDs"),
            pieceSizeMode: defaults.string(forKey: "pieceSizeMode"),
            dimensionUnit: defaults.string(forKey: "dimensionUnit"),
            hasSeededDataV2: defaults.object(forKey: "com.counter.hasSeededData.v2") as? Bool,
            hasSeededPayments: defaults.object(forKey: "com.counter.hasSeededPayments") as? Bool,
            hasSeededFlashPortfolio: defaults.object(forKey: "com.counter.hasSeededFlashPortfolio") as? Bool
        )

        return RecoveryBackup(
            version: RecoveryBackup.currentVersion,
            createdAt: Date(),
            appVersion: RecoveryService.currentAppVersion,
            clients: clientBackups, pieces: pieceBackups,
            sessions: sessionBackups, sessionProgress: imageGroupBackups,
            pieceImages: pieceImageBackups, inspirationImages: inspirationBackups,
            bookings: bookingBackups, agreements: agreementBackups,
            communicationLogs: commLogBackups, payments: paymentBackups,
            profiles: profileBackups, customSessionTypes: cstBackups,
            customEmailTemplates: cetBackups, availabilitySlots: slotBackups,
            availabilityOverrides: overrideBackups, sessionRateConfigs: srcBackups,
            flashPriceTiers: fptBackups, customGalleryGroups: cggBackups,
            customDiscounts: cdBackups,
            userDefaults: udBackup
        )
    }

    // MARK: - Image Copy

    private func copyImages(to backupURL: URL) throws -> Int {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return 0 }
        let sourceBase = docs.appendingPathComponent("CounterImages")
        let destBase = backupURL.appendingPathComponent(imagesFolderName)

        guard fileManager.fileExists(atPath: sourceBase.path) else { return 0 }

        var count = 0
        guard let enumerator = fileManager.enumerator(
            at: sourceBase,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        ) else { return 0 }

        while let fileURL = enumerator.nextObject() as? URL {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: sourceBase.path, with: "")
            let destURL = destBase.appendingPathComponent(relativePath)

            // Skip if already exists (images are write-once with UUID names)
            if fileManager.fileExists(atPath: destURL.path) { continue }

            let destDir = destURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
            try fileManager.copyItem(at: fileURL, to: destURL)
            count += 1
        }
        return count
    }

    // MARK: - Restore: Wipe

    @MainActor
    private func wipeAllData(context: ModelContext) throws {
        try context.delete(model: PieceImage.self)
        try context.delete(model: SessionProgress.self)
        try context.delete(model: Session.self)
        try context.delete(model: Booking.self)
        try context.delete(model: Payment.self)
        try context.delete(model: Agreement.self)
        try context.delete(model: CommunicationLog.self)
        try context.delete(model: Piece.self)
        try context.delete(model: Client.self)
        try context.delete(model: PieceImage.self)
        try context.delete(model: UserProfile.self)
        try context.delete(model: SessionType.self)
        try context.delete(model: EmailTemplate.self)
        try context.delete(model: AvailabilitySlot.self)
        try context.delete(model: AvailabilityOverride.self)
        try context.delete(model: SessionRateConfig.self)
        try context.delete(model: FlashPriceTier.self)
        try context.delete(model: GalleryGroup.self)
        try context.delete(model: Discount.self)
    }

    // MARK: - Restore: Deserialize & Insert

    @MainActor
    private func deserializeAndInsert(_ backup: RecoveryBackup, context: ModelContext) throws {
        // Phase 1: Independent models (no relationships)
        for p in backup.profiles {
            let profile = UserProfile(
                firstName: p.firstName, lastName: p.lastName,
                businessName: p.businessName,
                profession: Profession(rawValue: p.profession) ?? .tattooer
            )
            profile.email = p.email
            profile.phone = p.phone
            profile.profilePhotoPath = p.profilePhotoPath
            profile.defaultHourlyRate = p.defaultHourlyRate
            profile.currency = p.currency
            profile.depositFlat = p.depositFlat
            profile.depositPercentage = p.depositPercentage
            profile.friendsFamilyDiscount = p.friendsFamilyDiscount
            profile.preferredClientDiscount = p.preferredClientDiscount
            profile.holidayDiscount = p.holidayDiscount
            profile.conventionDiscount = p.conventionDiscount
            profile.noShowFee = p.noShowFee
            profile.revisionFee = p.revisionFee
            profile.administrativeFee = p.administrativeFee
            profile.flashPricingModeRaw = p.flashPricingModeRaw
            profile.chargeableSessionTypes = p.chargeableSessionTypes
            profile.statusColorNames = p.statusColorNames
            profile.shopAddressLine1 = p.shopAddressLine1
            profile.shopAddressLine2 = p.shopAddressLine2
            profile.shopCity = p.shopCity
            profile.shopState = p.shopState
            profile.shopPostalCode = p.shopPostalCode
            profile.shopCountry = p.shopCountry
            profile.billingAddressLine1 = p.billingAddressLine1
            profile.billingAddressLine2 = p.billingAddressLine2
            profile.billingCity = p.billingCity
            profile.billingState = p.billingState
            profile.billingPostalCode = p.billingPostalCode
            profile.billingCountry = p.billingCountry
            context.insert(profile)
        }

        for cst in backup.customSessionTypes {
            let obj = SessionType(name: cst.name, isChargeable: cst.isChargeable, sortOrder: cst.sortOrder)
            obj.uuid = cst.uuid
            obj.createdAt = cst.createdAt
            context.insert(obj)
        }

        for cet in backup.customEmailTemplates {
            let obj = EmailTemplate(name: cet.name, subject: cet.subject, body: cet.body, category: EmailTemplate.TemplateCategory(rawValue: cet.categoryRaw) ?? .custom)
            obj.createdAt = cet.createdAt
            obj.updatedAt = cet.updatedAt
            context.insert(obj)
        }

        for s in backup.availabilitySlots {
            let obj = AvailabilitySlot(dayOfWeek: s.dayOfWeek, startTime: s.startTime, endTime: s.endTime, slotType: AvailabilitySlot.SlotType(rawValue: s.slotTypeRaw) ?? .available, isFlashOnly: s.isFlashOnly)
            obj.isActive = s.isActive
            context.insert(obj)
        }

        for o in backup.availabilityOverrides {
            let obj = AvailabilityOverride(startDate: o.startDate, endDate: o.endDate, reason: o.reason, isUnavailable: o.isUnavailable)
            context.insert(obj)
        }

        for src in backup.sessionRateConfigs {
            let obj = SessionRateConfig(sessionTypeRaw: src.sessionTypeRaw)
            obj.rateModeRaw = src.rateModeRaw
            obj.rateValue = src.rateValue
            obj.depositModeRaw = src.depositModeRaw
            obj.discountTypeRaw = src.discountTypeRaw
            obj.feeTypeRaw = src.feeTypeRaw
            obj.flashPricingModeRaw = src.flashPricingModeRaw
            context.insert(obj)
        }

        for fpt in backup.flashPriceTiers {
            let obj = FlashPriceTier(label: fpt.label, widthInches: fpt.widthInches, heightInches: fpt.heightInches, price: fpt.price, sortOrder: fpt.sortOrder)
            obj.uuid = fpt.uuid
            context.insert(obj)
        }

        for cgg in backup.customGalleryGroups {
            let obj = GalleryGroup(name: cgg.name, tags: cgg.tags, sortIndex: cgg.sortIndex)
            obj.createdAt = cgg.createdAt
            context.insert(obj)
        }

        // Discounts: optional field on the backup struct so that
        // pre-V2 backups (which don't carry this array at all) decode
        // cleanly. `nil` here means "the backup file predates V2", not
        // "the user had zero discounts".
        for cd in backup.customDiscounts ?? [] {
            let obj = Discount(
                name: cd.name,
                percentage: cd.percentage,
                sortOrder: cd.sortOrder
            )
            context.insert(obj)
        }

        for img in backup.inspirationImages {
            let obj = PieceImage(filePath: img.filePath, fileName: img.fileName, tags: img.tags, notes: img.notes)
            obj.capturedAt = img.capturedAt
            context.insert(obj)
        }

        // Phase 2: Clients (no parent deps)
        var clientMap: [UUID: Client] = [:]
        for cb in backup.clients {
            let client = Client(
                firstName: cb.firstName, lastName: cb.lastName,
                email: cb.email, phone: cb.phone,
                notes: cb.notes, pronouns: cb.pronouns,
                birthdate: cb.birthdate, allergyNotes: cb.allergyNotes,
                streetAddress: cb.streetAddress, city: cb.city,
                state: cb.state, zipCode: cb.zipCode
            )
            client.profilePhotoPath = cb.profilePhotoPath
            client.emailOptIn = cb.emailOptIn
            client.isFlashPortfolioClient = cb.isFlashPortfolioClient
            client.createdAt = cb.createdAt
            client.updatedAt = cb.updatedAt
            context.insert(client)
            clientMap[cb.backupID] = client
        }

        // Phase 3: Pieces (→ Client)
        var pieceMap: [UUID: Piece] = [:]
        for pb in backup.pieces {
            let piece = Piece(
                title: pb.title, bodyPlacement: pb.bodyPlacement,
                descriptionText: pb.descriptionText,
                status: PieceStatus(rawValue: pb.status) ?? .concept,
                pieceType: PieceType(rawValue: pb.pieceType) ?? .custom,
                tags: pb.tags, hourlyRate: pb.hourlyRate,
                flatRate: pb.flatRate, depositAmount: pb.depositAmount
            )
            piece.primaryImagePath = pb.primaryImagePath
            piece.rating = pb.rating
            piece.size = pb.size.flatMap { TattooSize(rawValue: $0) }
            piece.sizeDimensions = pb.sizeDimensions
            piece.createdAt = pb.createdAt
            piece.updatedAt = pb.updatedAt
            piece.completedAt = pb.completedAt
            piece.client = pb.clientBackupID.flatMap { clientMap[$0] }
            context.insert(piece)
            pieceMap[pb.backupID] = piece
        }

        // Phase 4: Sessions (→ Piece)
        var sessionMap: [UUID: Session] = [:]
        for sb in backup.sessions {
            let session = Session(
                date: sb.date, startTime: sb.startTime,
                sessionType: SessionType(rawValue: sb.sessionType) ?? .consultation,
                hourlyRateAtTime: sb.hourlyRateAtTime
            )
            session.endTime = sb.endTime
            session.breakMinutes = sb.breakMinutes
            session.flashRate = sb.flashRate
            session.manualHoursOverride = sb.manualHoursOverride
            session.isNoShow = sb.isNoShow
            session.noShowFee = sb.noShowFee
            session.notes = sb.notes
            session.piece = sb.pieceBackupID.flatMap { pieceMap[$0] }
            context.insert(session)
            sessionMap[sb.backupID] = session
        }

        // Phase 5: SessionProgresss (→ Piece, Session)
        var imageGroupMap: [UUID: SessionProgress] = [:]
        for igb in backup.sessionProgress {
            let ig = SessionProgress(
                stage: ImageStage(rawValue: igb.stage) ?? .sketch,
                notes: igb.notes, timeSpentMinutes: igb.timeSpentMinutes
            )
            ig.createdAt = igb.createdAt
            ig.piece = igb.pieceBackupID.flatMap { pieceMap[$0] }
            ig.session = igb.sessionBackupID.flatMap { sessionMap[$0] }
            context.insert(ig)
            imageGroupMap[igb.backupID] = ig
        }

        // Phase 6: PieceImages (→ SessionProgress, Piece)
        for pib in backup.pieceImages {
            let pi = PieceImage(
                filePath: pib.filePath, fileName: pib.fileName,
                notes: pib.notes, capturedAt: pib.capturedAt,
                sortOrder: pib.sortOrder, isPrimary: pib.isPrimary,
                category: pib.category.flatMap { PieceImageCategory(rawValue: $0) }
            )
            pi.tags = pib.tags
            pi.sessionProgress = pib.sessionProgressBackupID.flatMap { imageGroupMap[$0] }
            pi.piece = pib.pieceBackupID.flatMap { pieceMap[$0] }
            context.insert(pi)
        }

        // Phase 7: Agreements, CommunicationLogs (→ Client)
        for ab in backup.agreements {
            let a = Agreement(
                title: ab.title,
                agreementType: AgreementType(rawValue: ab.agreementType) ?? .custom,
                bodyText: ab.bodyText
            )
            a.isSigned = ab.isSigned
            a.signedAt = ab.signedAt
            a.signatureImagePath = ab.signatureImagePath
            a.createdAt = ab.createdAt
            a.client = ab.clientBackupID.flatMap { clientMap[$0] }
            context.insert(a)
        }

        for clb in backup.communicationLogs {
            let cl = CommunicationLog(
                commType: CommunicationType(rawValue: clb.commType) ?? .note,
                subject: clb.subject, bodyText: clb.bodyText,
                sentAt: clb.sentAt
            )
            cl.wasAutoGenerated = clb.wasAutoGenerated
            cl.client = clb.clientBackupID.flatMap { clientMap[$0] }
            context.insert(cl)
        }

        // Phase 8: Payments (→ Client, Piece)
        for pb in backup.payments {
            let payment = Payment(
                amount: pb.amount, paymentDate: pb.paymentDate,
                paymentMethod: PaymentMethod(rawValue: pb.paymentMethod) ?? .other,
                paymentType: PaymentType(rawValue: pb.paymentType) ?? .sessionPayment,
                notes: pb.notes
            )
            payment.createdAt = pb.createdAt
            payment.client = pb.clientBackupID.flatMap { clientMap[$0] }
            payment.piece = pb.pieceBackupID.flatMap { pieceMap[$0] }
            context.insert(payment)
        }

        // Phase 9: Bookings (→ Client, Piece)
        for bb in backup.bookings {
            let booking = Booking(
                date: bb.date, startTime: bb.startTime, endTime: bb.endTime,
                status: BookingStatus(rawValue: bb.status) ?? .requested,
                bookingType: BookingType(rawValue: bb.bookingType) ?? .session,
                notes: bb.notes
            )
            booking.depositPaid = bb.depositPaid
            booking.reminderSent = bb.reminderSent
            booking.checklistOverrides = bb.checklistOverrides
            booking.customChecklistItems = bb.customChecklistItems
            booking.createdAt = bb.createdAt
            booking.updatedAt = bb.updatedAt
            booking.client = bb.clientBackupID.flatMap { clientMap[$0] }
            booking.piece = bb.pieceBackupID.flatMap { pieceMap[$0] }
            context.insert(booking)
        }
    }

    // MARK: - Restore: Images

    /// Replaces `Documents/CounterImages` with the image tree from the
    /// given backup folder, then verifies the resulting file count matches
    /// `expectedCount` (sourced from `BackupMetadata.imageCount`).
    ///
    /// Failures here propagate by design — silently producing a populated
    /// store that references missing image files is the worst possible
    /// outcome for a tattoo artist whose entire portfolio is the data.
    private func restoreImages(from backupURL: URL, expectedCount: Int) throws {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // No Documents directory at all is a hard failure if the
            // backup actually contains images.
            if expectedCount > 0 {
                throw RecoveryError.imageCopyFailed("Could not locate Documents directory.")
            }
            return
        }
        let destBase = docs.appendingPathComponent("CounterImages")
        let sourceBase = backupURL.appendingPathComponent(imagesFolderName)

        if !fileManager.fileExists(atPath: sourceBase.path) {
            if expectedCount > 0 {
                throw RecoveryError.imageCopyFailed(
                    "Backup metadata reported \(expectedCount) images but the Images folder is missing from the backup."
                )
            }
            return
        }

        // Remove existing images and replace with backup
        if fileManager.fileExists(atPath: destBase.path) {
            try fileManager.removeItem(at: destBase)
        }
        try fileManager.copyItem(at: sourceBase, to: destBase)

        // Post-copy verification — if the copy produced fewer files than
        // the metadata claimed, the destination is in a partially-populated
        // state. Surface that loudly; the user still has the pre-restore
        // snapshot from step 7 of `restore()` to fall back on.
        if expectedCount > 0 {
            let actualCount = recursiveFileCount(at: destBase)
            if actualCount != expectedCount {
                throw RecoveryError.imageCountMismatch(
                    expected: expectedCount,
                    actual: actualCount
                )
            }
        }
    }

    /// Recursive count of regular files under `url`. Used to verify image
    /// restore completeness against the metadata's `imageCount`.
    private func recursiveFileCount(at url: URL) -> Int {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        ) else { return 0 }

        var count = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                count += 1
            }
        }
        return count
    }

    // MARK: - Restore: UserDefaults

    private func restoreUserDefaults(_ ud: UserDefaultsBackup) {
        let defaults = UserDefaults.standard
        if let v = ud.businessLockEnabled { defaults.set(v, forKey: "businessLockEnabled") }
        if let v = ud.businessLockPIN { defaults.set(v, forKey: "businessLockPIN") }
        if let v = ud.todoDismissedIDs { defaults.set(v, forKey: "todo.dismissedIDs") }
        if let v = ud.pieceSizeMode { defaults.set(v, forKey: "pieceSizeMode") }
        if let v = ud.dimensionUnit { defaults.set(v, forKey: "dimensionUnit") }
        if let v = ud.hasSeededDataV2 { defaults.set(v, forKey: "com.counter.hasSeededData.v2") }
        if let v = ud.hasSeededPayments { defaults.set(v, forKey: "com.counter.hasSeededPayments") }
        if let v = ud.hasSeededFlashPortfolio { defaults.set(v, forKey: "com.counter.hasSeededFlashPortfolio") }
    }

    // MARK: - Local Documents Mirror (Beta Safety Net)

    /// Returns the local-Documents backup container, always — regardless of iCloud availability.
    /// This folder is visible in the Files app when UIFileSharingEnabled is set in Info.plist.
    private func localDocumentsContainerURL() throws -> URL {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw RecoveryError.serializationFailed("Could not locate local Documents directory.")
        }
        let url = docs.appendingPathComponent(backupFolderName)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Copies backup.json, metadata.json, and (when `includeImages` is set)
    /// the entire Images tree into a matching folder under local Documents.
    ///
    /// Mirrors are written for every backup, regardless of which container
    /// is the primary destination. Including images makes the mirror fully
    /// self-contained — accepted filesystem cost for the beta cycle.
    private func mirrorToLocalDocuments(
        backupURL: URL,
        jsonData: Data,
        metaData: Data,
        includeImages: Bool
    ) throws {
        let localContainer = try localDocumentsContainerURL()
        let folderName = backupURL.lastPathComponent
        let mirrorURL = localContainer.appendingPathComponent(folderName)

        // Skip if this is already the primary backup destination (iCloud unavailable)
        if mirrorURL.path == backupURL.path { return }

        try fileManager.createDirectory(at: mirrorURL, withIntermediateDirectories: true)
        try jsonData.write(to: mirrorURL.appendingPathComponent("backup.json"))
        try metaData.write(to: mirrorURL.appendingPathComponent("metadata.json"))

        if includeImages {
            let sourceImagesURL = backupURL.appendingPathComponent(imagesFolderName)
            let destImagesURL = mirrorURL.appendingPathComponent(imagesFolderName)
            if fileManager.fileExists(atPath: sourceImagesURL.path)
                && !fileManager.fileExists(atPath: destImagesURL.path) {
                try fileManager.copyItem(at: sourceImagesURL, to: destImagesURL)
            }
        }

        // Prune the local mirror with the same kind-aware budget as the
        // primary container.
        try pruneLocalMirror(container: localContainer)
    }

    /// Kind-aware prune for the local-Documents mirror. Mirrors the
    /// behaviour of `pruneOldBackups` + `prunePreRestoreSnapshots` so that
    /// a flurry of pre-restore snapshots can't push real user backups out
    /// of mirror retention. Folders without a readable `metadata.json` are
    /// treated as legacy `userBackup` entries.
    private func pruneLocalMirror(container: URL) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: container,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
            options: .skipsHiddenFiles
        )
        let folders = try contents.filter {
            try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct MirrorEntry {
            let url: URL
            let createdAt: Date
            let kind: BackupKind
        }

        var entries: [MirrorEntry] = []
        for folder in folders {
            let metaURL = folder.appendingPathComponent("metadata.json")
            var createdAt = (try? folder.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            var kind: BackupKind = .userBackup
            if let data = try? Data(contentsOf: metaURL),
               let meta = try? decoder.decode(BackupMetadata.self, from: data) {
                createdAt = meta.createdAt
                kind = meta.effectiveKind
            }
            entries.append(MirrorEntry(url: folder, createdAt: createdAt, kind: kind))
        }

        let userMirrors = entries
            .filter { $0.kind == .userBackup }
            .sorted { $0.createdAt > $1.createdAt }
        let snapshotMirrors = entries
            .filter { $0.kind == .preRestoreSnapshot }
            .sorted { $0.createdAt > $1.createdAt }

        if userMirrors.count > maxBackupCount {
            for entry in userMirrors.suffix(from: maxBackupCount) {
                try fileManager.removeItem(at: entry.url)
            }
        }
        if snapshotMirrors.count > maxPreRestoreSnapshotCount {
            for entry in snapshotMirrors.suffix(from: maxPreRestoreSnapshotCount) {
                try fileManager.removeItem(at: entry.url)
            }
        }
    }

    // MARK: - Pruning

    /// Prunes only `.userBackup` entries to `maxBackupCount`. Pre-restore
    /// snapshots are retained on a separate budget so a flurry of restores
    /// can't push real user backups out of rotation.
    private func pruneOldBackups() throws {
        let userBackups = try listBackups()
            .filter { $0.effectiveKind == .userBackup }
        guard userBackups.count > maxBackupCount else { return }
        let toDelete = userBackups.suffix(from: maxBackupCount)
        for backup in toDelete {
            try deleteBackup(backup)
        }
    }

    /// Prunes only `.preRestoreSnapshot` entries to
    /// `maxPreRestoreSnapshotCount`. Run after every snapshot, not after
    /// every restore — the snapshot is the thing that just landed.
    private func prunePreRestoreSnapshots() throws {
        let snapshots = try listBackups()
            .filter { $0.effectiveKind == .preRestoreSnapshot }
        guard snapshots.count > maxPreRestoreSnapshotCount else { return }
        let toDelete = snapshots.suffix(from: maxPreRestoreSnapshotCount)
        for backup in toDelete {
            try deleteBackup(backup)
        }
    }

    // MARK: - Helpers

    private func totalModelCount(_ backup: RecoveryBackup) -> Int {
        backup.clients.count + backup.pieces.count + backup.sessions.count +
        backup.sessionProgress.count + backup.pieceImages.count +
        backup.inspirationImages.count + backup.bookings.count +
        backup.agreements.count + backup.communicationLogs.count +
        backup.payments.count + backup.profiles.count +
        backup.customSessionTypes.count + backup.customEmailTemplates.count +
        backup.availabilitySlots.count + backup.availabilityOverrides.count +
        backup.sessionRateConfigs.count + backup.flashPriceTiers.count +
        backup.customGalleryGroups.count +
        (backup.customDiscounts?.count ?? 0)
    }

    private func directorySize(at url: URL) -> UInt64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return 0 }

        var total: UInt64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        return total
    }
}
