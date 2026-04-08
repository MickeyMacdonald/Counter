import Foundation
import SwiftData

// MARK: - Recovery Service (Alpha Safety Net)
// Temporary auto-backup service for alpha testers. Will be retired at release.

actor RecoveryService {
    static let shared = RecoveryService()

    private let maxBackupCount = 3
    private let backupFolderName = "Counter Recovery"
    private let imagesFolderName = "Images"
    private let fileManager = FileManager.default

    // Observable state for the UI
    var lastBackupDate: Date?
    var lastBackupError: String?

    // Debounce: skip backup if one happened recently
    private let minimumBackupInterval: TimeInterval = 60

    // MARK: - Public API

    @discardableResult
    func performBackup(context: ModelContext) async throws -> BackupMetadata {
        // Debounce
        if let last = lastBackupDate, Date().timeIntervalSince(last) < minimumBackupInterval {
            throw RecoveryError.serializationFailed("Backup skipped — too soon since last backup.")
        }

        // 1. Serialize all models on the main actor (ModelContext requirement)
        let backup = try await MainActor.run {
            try serializeAllModels(context: context)
        }

        // 2. Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(backup)

        // 3. Create backup folder
        let containerURL = try backupContainerURL()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let folderName = "counter_recovery_\(formatter.string(from: Date()))"
        let backupURL = containerURL.appendingPathComponent(folderName)
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)

        // 4. Write JSON
        let jsonURL = backupURL.appendingPathComponent("backup.json")
        try jsonData.write(to: jsonURL)

        // 5. Copy images
        let imageCount = try copyImages(to: backupURL)

        // 6. Calculate sizes
        let imageSizeBytes = directorySize(at: backupURL.appendingPathComponent(imagesFolderName))

        // 7. Write metadata
        let metadata = BackupMetadata(
            id: UUID(),
            createdAt: Date(),
            appVersion: "Pre-Alpha 0.2",
            modelCount: totalModelCount(backup),
            imageCount: imageCount,
            jsonSizeBytes: UInt64(jsonData.count),
            imageSizeBytes: imageSizeBytes,
            folderName: folderName
        )
        let metaEncoder = JSONEncoder()
        metaEncoder.dateEncodingStrategy = .iso8601
        metaEncoder.outputFormatting = .prettyPrinted
        let metaData = try metaEncoder.encode(metadata)
        try metaData.write(to: backupURL.appendingPathComponent("metadata.json"))

        // 8. Prune old backups
        try pruneOldBackups()

        // 9. Update state
        lastBackupDate = Date()
        lastBackupError = nil

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

        // 1. Parse the full backup into memory FIRST (safety: don't wipe until we know it's valid)
        let jsonData = try Data(contentsOf: jsonURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: RecoveryBackup
        do {
            backup = try decoder.decode(RecoveryBackup.self, from: jsonData)
        } catch {
            throw RecoveryError.deserializationFailed(error.localizedDescription)
        }

        guard backup.version == RecoveryBackup.currentVersion else {
            throw RecoveryError.versionMismatch(found: backup.version, expected: RecoveryBackup.currentVersion)
        }

        // 2. Wipe existing data, then insert from backup (on main actor for ModelContext)
        try await MainActor.run {
            try wipeAllData(context: context)
            try deserializeAndInsert(backup, context: context)
            try context.save()
        }

        // 3. Restore images
        try restoreImages(from: backupURL)

        // 4. Restore UserDefaults
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
        let sessions = try context.fetch(FetchDescriptor<TattooSession>())
        let imageGroups = try context.fetch(FetchDescriptor<ImageGroup>())
        let pieceImages = try context.fetch(FetchDescriptor<PieceImage>())
        let inspirationImages = try context.fetch(FetchDescriptor<InspirationImage>())
        let bookings = try context.fetch(FetchDescriptor<Booking>())
        let agreements = try context.fetch(FetchDescriptor<Agreement>())
        let commLogs = try context.fetch(FetchDescriptor<CommunicationLog>())
        let payments = try context.fetch(FetchDescriptor<Payment>())
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let customSessionTypes = try context.fetch(FetchDescriptor<CustomSessionType>())
        let customEmailTemplates = try context.fetch(FetchDescriptor<CustomEmailTemplate>())
        let availabilitySlots = try context.fetch(FetchDescriptor<AvailabilitySlot>())
        let availabilityOverrides = try context.fetch(FetchDescriptor<AvailabilityOverride>())
        let sessionRateConfigs = try context.fetch(FetchDescriptor<SessionRateConfig>())
        let flashPriceTiers = try context.fetch(FetchDescriptor<FlashPriceTier>())
        let customGalleryGroups = try context.fetch(FetchDescriptor<CustomGalleryGroup>())

        // Build ID lookup tables: object identity → UUID
        var clientIDs: [ObjectIdentifier: UUID] = [:]
        var pieceIDs: [ObjectIdentifier: UUID] = [:]
        var sessionIDs: [ObjectIdentifier: UUID] = [:]
        var imageGroupIDs: [ObjectIdentifier: UUID] = [:]

        for c in clients { clientIDs[ObjectIdentifier(c)] = UUID() }
        for p in pieces { pieceIDs[ObjectIdentifier(p)] = UUID() }
        for s in sessions { sessionIDs[ObjectIdentifier(s)] = UUID() }
        for ig in imageGroups { imageGroupIDs[ObjectIdentifier(ig)] = UUID() }

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

        let imageGroupBackups = imageGroups.map { ig in
            let id = imageGroupIDs[ObjectIdentifier(ig)]!
            let pieceID = ig.piece.flatMap { pieceIDs[ObjectIdentifier($0)] }
            let sessionID = ig.session.flatMap { sessionIDs[ObjectIdentifier($0)] }
            return ImageGroupBackup(
                backupID: id, pieceBackupID: pieceID, sessionBackupID: sessionID,
                stage: ig.stage.rawValue, notes: ig.notes,
                timeSpentMinutes: ig.timeSpentMinutes, createdAt: ig.createdAt
            )
        }

        let pieceImageBackups = pieceImages.map { pi in
            let igID = pi.imageGroup.flatMap { imageGroupIDs[ObjectIdentifier($0)] }
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
            InspirationImageBackup(
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
            CustomSessionTypeBackup(
                backupID: UUID(), uuid: cst.uuid,
                name: cst.name, isChargeable: cst.isChargeable,
                sortOrder: cst.sortOrder, createdAt: cst.createdAt
            )
        }

        let cetBackups = customEmailTemplates.map { cet in
            CustomEmailTemplateBackup(
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
            CustomGalleryGroupBackup(
                backupID: UUID(), name: cgg.name,
                tags: cgg.tags, sortIndex: cgg.sortIndex,
                createdAt: cgg.createdAt
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
            appVersion: "Pre-Alpha 0.2",
            clients: clientBackups, pieces: pieceBackups,
            sessions: sessionBackups, imageGroups: imageGroupBackups,
            pieceImages: pieceImageBackups, inspirationImages: inspirationBackups,
            bookings: bookingBackups, agreements: agreementBackups,
            communicationLogs: commLogBackups, payments: paymentBackups,
            profiles: profileBackups, customSessionTypes: cstBackups,
            customEmailTemplates: cetBackups, availabilitySlots: slotBackups,
            availabilityOverrides: overrideBackups, sessionRateConfigs: srcBackups,
            flashPriceTiers: fptBackups, customGalleryGroups: cggBackups,
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
        try context.delete(model: ImageGroup.self)
        try context.delete(model: TattooSession.self)
        try context.delete(model: Booking.self)
        try context.delete(model: Payment.self)
        try context.delete(model: Agreement.self)
        try context.delete(model: CommunicationLog.self)
        try context.delete(model: Piece.self)
        try context.delete(model: Client.self)
        try context.delete(model: InspirationImage.self)
        try context.delete(model: UserProfile.self)
        try context.delete(model: CustomSessionType.self)
        try context.delete(model: CustomEmailTemplate.self)
        try context.delete(model: AvailabilitySlot.self)
        try context.delete(model: AvailabilityOverride.self)
        try context.delete(model: SessionRateConfig.self)
        try context.delete(model: FlashPriceTier.self)
        try context.delete(model: CustomGalleryGroup.self)
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
            let obj = CustomSessionType(name: cst.name, isChargeable: cst.isChargeable, sortOrder: cst.sortOrder)
            obj.uuid = cst.uuid
            obj.createdAt = cst.createdAt
            context.insert(obj)
        }

        for cet in backup.customEmailTemplates {
            let obj = CustomEmailTemplate(name: cet.name, subject: cet.subject, body: cet.body, category: EmailTemplate.TemplateCategory(rawValue: cet.categoryRaw) ?? .custom)
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
            let obj = CustomGalleryGroup(name: cgg.name, tags: cgg.tags, sortIndex: cgg.sortIndex)
            obj.createdAt = cgg.createdAt
            context.insert(obj)
        }

        for img in backup.inspirationImages {
            let obj = InspirationImage(filePath: img.filePath, fileName: img.fileName, tags: img.tags, notes: img.notes)
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
        var sessionMap: [UUID: TattooSession] = [:]
        for sb in backup.sessions {
            let session = TattooSession(
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

        // Phase 5: ImageGroups (→ Piece, Session)
        var imageGroupMap: [UUID: ImageGroup] = [:]
        for igb in backup.imageGroups {
            let ig = ImageGroup(
                stage: ImageStage(rawValue: igb.stage) ?? .sketch,
                notes: igb.notes, timeSpentMinutes: igb.timeSpentMinutes
            )
            ig.createdAt = igb.createdAt
            ig.piece = igb.pieceBackupID.flatMap { pieceMap[$0] }
            ig.session = igb.sessionBackupID.flatMap { sessionMap[$0] }
            context.insert(ig)
            imageGroupMap[igb.backupID] = ig
        }

        // Phase 6: PieceImages (→ ImageGroup, Piece)
        for pib in backup.pieceImages {
            let pi = PieceImage(
                filePath: pib.filePath, fileName: pib.fileName,
                notes: pib.notes, capturedAt: pib.capturedAt,
                sortOrder: pib.sortOrder, isPrimary: pib.isPrimary,
                category: pib.category.flatMap { PieceImageCategory(rawValue: $0) }
            )
            pi.tags = pib.tags
            pi.imageGroup = pib.imageGroupBackupID.flatMap { imageGroupMap[$0] }
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

    private func restoreImages(from backupURL: URL) throws {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let destBase = docs.appendingPathComponent("CounterImages")
        let sourceBase = backupURL.appendingPathComponent(imagesFolderName)

        guard fileManager.fileExists(atPath: sourceBase.path) else { return }

        // Remove existing images and replace with backup
        if fileManager.fileExists(atPath: destBase.path) {
            try fileManager.removeItem(at: destBase)
        }
        try fileManager.copyItem(at: sourceBase, to: destBase)
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

    // MARK: - Pruning

    private func pruneOldBackups() throws {
        let backups = try listBackups()
        guard backups.count > maxBackupCount else { return }
        let toDelete = backups.suffix(from: maxBackupCount)
        for backup in toDelete {
            try deleteBackup(backup)
        }
    }

    // MARK: - Helpers

    private func totalModelCount(_ backup: RecoveryBackup) -> Int {
        backup.clients.count + backup.pieces.count + backup.sessions.count +
        backup.imageGroups.count + backup.pieceImages.count +
        backup.inspirationImages.count + backup.bookings.count +
        backup.agreements.count + backup.communicationLogs.count +
        backup.payments.count + backup.profiles.count +
        backup.customSessionTypes.count + backup.customEmailTemplates.count +
        backup.availabilitySlots.count + backup.availabilityOverrides.count +
        backup.sessionRateConfigs.count + backup.flashPriceTiers.count +
        backup.customGalleryGroups.count
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
