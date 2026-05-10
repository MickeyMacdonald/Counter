import Foundation
@preconcurrency import SwiftData

// MARK: - Cntrdb Exporter
//
// Writes a `.cntrdb` package: SQLite database + Images folder + manifest.json.
// Structurally parallels `RecoveryService.serializeAllModels` and
// `performBackupInternal` — keeping them in lockstep makes auditing easy
// when SwiftData models gain or lose fields.
//
// We mint a fresh UUID per object at export time (via ObjectIdentifier
// lookup) rather than tunnelling SwiftData's internal `persistentModelID`,
// because SwiftData IDs are not portable: they change on store rebuild and
// are not designed for cross-installation transfer. The exported UUIDs
// become the identity of those records inside the `.cntrdb`.

actor CntrdbExporter {

    static let shared = CntrdbExporter()

    private let fileManager = FileManager.default
    private let imagesSourceDirName = "CounterImages"

    // MARK: Public API

    /// Exports the entire SwiftData store to a `.cntrdb` package at `url`.
    /// `url` must NOT already exist — use a fresh path under a directory
    /// the caller will then share. Returns the manifest written to disk.
    @discardableResult
    func exportAll(
        to url: URL,
        context: ModelContext,
        sourceDevice: String? = nil,
        notes: String? = nil
    ) async throws -> CntrdbManifest {

        // 1. Create the package skeleton.
        let pkg = try CntrdbPackage.create(at: url)

        // 2. Open the SQLite, apply schema.
        let db: SQLiteConnection
        do {
            db = try SQLiteConnection(openAt: pkg.databaseURL, create: true)
            try db.exec(CntrdbSchema.ddl)
        } catch {
            // Best-effort cleanup on failure so we don't leave a half-built
            // package on disk for the user to wonder about.
            try? fileManager.removeItem(at: url)
            throw error
        }

        // 3. Snapshot + write everything inside one MainActor hop. Reading
        //    SwiftData and binding rows are interleaved — splitting them
        //    into separate hops would require a Sendable intermediate
        //    representation we don't actually need yet. Pattern matches
        //    RecoveryService.serializeAllModels (also @MainActor).
        let totalCount: Int
        do {
            totalCount = try await MainActor.run { [self] in
                let s = try Self.takeSnapshot(context: context)
                guard s.totalCount > 0 else {
                    throw CntrdbError.exportFailed("Store is empty — refusing to export an empty .cntrdb.")
                }
                try db.transaction {
                    try Self.writeMeta(db: db, sourceDevice: sourceDevice, notes: notes)
                    try Self.writeUserDefaults(db: db)
                    try self.writeAllModels(db: db, snapshot: s)
                }
                return s.totalCount
            }
            db.close()
        } catch {
            db.close()
            try? fileManager.removeItem(at: url)
            throw error
        }

        // 4. Copy images from Documents/CounterImages → Images/.
        //    Same write-once-by-UUID-name assumption as RecoveryService.
        let imageCount: Int
        let imageBytes: UInt64
        do {
            (imageCount, imageBytes) = try copyImages(to: pkg.imagesURL)
        } catch {
            try? fileManager.removeItem(at: url)
            throw error
        }

        // 5. Compute checksum + sizes, write manifest. Manifest is the LAST
        //    thing written so its presence indicates the package is complete.
        let dbBytes = (try? fileManager.attributesOfItem(atPath: pkg.databaseURL.path)[.size] as? UInt64) ?? 0
        let dbChecksum = try CntrdbManifest.sha256HexOfFile(at: pkg.databaseURL)

        let manifest = CntrdbManifest(
            formatVersion: CntrdbPackage.currentFormatVersion,
            schemaVersion: CntrdbSchema.currentVersion,
            appVersion: Self.currentAppVersion,
            createdAt: Date(),
            modelCount: totalCount,
            imageCount: imageCount,
            databaseSizeBytes: dbBytes,
            imageSizeBytes: imageBytes,
            databaseChecksum: dbChecksum,
            sourceDevice: sourceDevice,
            notes: notes
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: pkg.manifestURL)

        return manifest
    }

    // MARK: Snapshot

    /// Live snapshot of the store at export time. Holds direct references to
    /// SwiftData objects (so we can read computed-but-stored fields) plus
    /// minted UUID identity for use inside the SQLite payload.
    @MainActor
    private static func takeSnapshot(context: ModelContext) throws -> Snapshot {
        let s = Snapshot()

        s.clients               = try context.fetch(FetchDescriptor<Client>())
        s.pieces                = try context.fetch(FetchDescriptor<Piece>())
        s.sessions              = try context.fetch(FetchDescriptor<Session>())
        s.sessionProgress       = try context.fetch(FetchDescriptor<SessionProgress>())
        s.workImages            = try context.fetch(FetchDescriptor<WorkImage>())
        s.bookings              = try context.fetch(FetchDescriptor<Booking>())
        s.agreements            = try context.fetch(FetchDescriptor<Agreement>())
        s.communicationLogs     = try context.fetch(FetchDescriptor<CommunicationLog>())
        s.payments              = try context.fetch(FetchDescriptor<Payment>())
        s.profiles              = try context.fetch(FetchDescriptor<UserProfile>())
        s.sessionCategories     = try context.fetch(FetchDescriptor<SessionCategory>())
        s.emailTemplates        = try context.fetch(FetchDescriptor<SavedEmailTemplate>())
        s.availabilitySlots     = try context.fetch(FetchDescriptor<AvailabilitySlot>())
        s.availabilityOverrides = try context.fetch(FetchDescriptor<AvailabilityOverride>())
        s.sessionRateConfigs    = try context.fetch(FetchDescriptor<SessionRateConfig>())
        s.flashPriceTiers       = try context.fetch(FetchDescriptor<FlashPriceTier>())
        s.galleryGroups         = try context.fetch(FetchDescriptor<GalleryGroup>())
        s.discounts             = try context.fetch(FetchDescriptor<Discount>())

        // Mint stable UUIDs for every object whose identity we'll need to
        // reference via foreign keys. Standalone tables (profiles, slots,
        // templates, etc.) get IDs minted inline at write time — no FK
        // references to them.
        for c  in s.clients         { s.clientID[ObjectIdentifier(c)]  = UUID() }
        for p  in s.pieces          { s.pieceID[ObjectIdentifier(p)]   = UUID() }
        for ss in s.sessions        { s.sessionID[ObjectIdentifier(ss)] = UUID() }
        for sp in s.sessionProgress { s.sessionProgressID[ObjectIdentifier(sp)] = UUID() }

        return s
    }

    @MainActor
    private final class Snapshot {
        // Fetched models
        var clients: [Client] = []
        var pieces: [Piece] = []
        var sessions: [Session] = []
        var sessionProgress: [SessionProgress] = []
        var workImages: [WorkImage] = []
        var bookings: [Booking] = []
        var agreements: [Agreement] = []
        var communicationLogs: [CommunicationLog] = []
        var payments: [Payment] = []
        var profiles: [UserProfile] = []
        var sessionCategories: [SessionCategory] = []
        var emailTemplates: [SavedEmailTemplate] = []
        var availabilitySlots: [AvailabilitySlot] = []
        var availabilityOverrides: [AvailabilityOverride] = []
        var sessionRateConfigs: [SessionRateConfig] = []
        var flashPriceTiers: [FlashPriceTier] = []
        var galleryGroups: [GalleryGroup] = []
        var discounts: [Discount] = []

        // Identity → UUID lookup tables (for FK resolution)
        var clientID:           [ObjectIdentifier: UUID] = [:]
        var pieceID:            [ObjectIdentifier: UUID] = [:]
        var sessionID:          [ObjectIdentifier: UUID] = [:]
        var sessionProgressID:  [ObjectIdentifier: UUID] = [:]

        var totalCount: Int {
            clients.count + pieces.count + sessions.count + sessionProgress.count
            + workImages.count + bookings.count + agreements.count
            + communicationLogs.count + payments.count + profiles.count
            + sessionCategories.count + emailTemplates.count
            + availabilitySlots.count + availabilityOverrides.count
            + sessionRateConfigs.count + flashPriceTiers.count
            + galleryGroups.count + discounts.count
        }
    }

    // MARK: Writers
    //
    // Every model has its own `write…` method. Bind order MUST match the
    // schema column order in CntrdbSchema.ddl — that pairing is the
    // contract. Adding a column means: (a) bump CntrdbSchema.currentVersion,
    // (b) add to the DDL, (c) add the bind here, (d) add the read in
    // CntrdbImporter, (e) write a migration if the change is breaking.

    @MainActor
    private static func writeMeta(
        db: SQLiteConnection,
        sourceDevice: String?, notes: String?
    ) throws {
        try db.write(
            "INSERT INTO _meta (schema_version, app_version, exported_at, source_device, notes) VALUES (?, ?, ?, ?, ?)",
            [
                .int(CntrdbSchema.currentVersion),
                .text(Self.currentAppVersion),
                .date(Date()),
                .text(sourceDevice),
                .text(notes)
            ]
        )
    }

    @MainActor
    private static func writeUserDefaults(db: SQLiteConnection) throws {
        // Mirrors RecoveryService.UserDefaultsBackup. Keys not present in
        // UserDefaults are skipped entirely so import doesn't write nulls
        // back over later defaults.
        let d = UserDefaults.standard
        let sql = "INSERT INTO _user_defaults (key, value, value_type) VALUES (?, ?, ?)"

        if let v = d.object(forKey: "businessLockEnabled") as? Bool {
            try db.write(sql, [.text("businessLockEnabled"), .text(v ? "1" : "0"), .text("bool")])
        }
        if let v = d.string(forKey: "businessLockPIN") {
            try db.write(sql, [.text("businessLockPIN"), .text(v), .text("string")])
        }
        if let v = d.string(forKey: "todo.dismissedIDs") {
            try db.write(sql, [.text("todo.dismissedIDs"), .text(v), .text("string")])
        }
        if let v = d.string(forKey: "pieceSizeMode") {
            try db.write(sql, [.text("pieceSizeMode"), .text(v), .text("string")])
        }
        if let v = d.string(forKey: "dimensionUnit") {
            try db.write(sql, [.text("dimensionUnit"), .text(v), .text("string")])
        }
        if let v = d.object(forKey: "com.counter.hasSeededData.v2") as? Bool {
            try db.write(sql, [.text("com.counter.hasSeededData.v2"), .text(v ? "1" : "0"), .text("bool")])
        }
        if let v = d.object(forKey: "com.counter.hasSeededPayments") as? Bool {
            try db.write(sql, [.text("com.counter.hasSeededPayments"), .text(v ? "1" : "0"), .text("bool")])
        }
        if let v = d.object(forKey: "com.counter.hasSeededFlashPortfolio") as? Bool {
            try db.write(sql, [.text("com.counter.hasSeededFlashPortfolio"), .text(v ? "1" : "0"), .text("bool")])
        }
    }

    @MainActor
    private func writeAllModels(db: SQLiteConnection, snapshot s: Snapshot) throws {
        // The ordering here matches CntrdbSchema.importPhases (parents
        // before children). Foreign keys would actually let us do them in
        // any order with `PRAGMA foreign_keys = OFF`, but keeping the
        // export ordering parallel to the import keeps cognitive cost low.

        try writeUserProfiles(db: db, list: s.profiles)
        try writeSessionCategories(db: db, list: s.sessionCategories)
        try writeEmailTemplates(db: db, list: s.emailTemplates)
        try writeAvailabilitySlots(db: db, list: s.availabilitySlots)
        try writeAvailabilityOverrides(db: db, list: s.availabilityOverrides)
        try writeSessionRateConfigs(db: db, list: s.sessionRateConfigs)
        try writeFlashPriceTiers(db: db, list: s.flashPriceTiers)
        try writeGalleryGroups(db: db, list: s.galleryGroups)
        try writeDiscounts(db: db, list: s.discounts)

        try writeClients(db: db, snapshot: s)
        try writePieces(db: db, snapshot: s)
        try writeSessions(db: db, snapshot: s)
        try writeSessionProgress(db: db, snapshot: s)
        try writeWorkImages(db: db, snapshot: s)
        try writeAgreements(db: db, snapshot: s)
        try writeCommunicationLogs(db: db, snapshot: s)
        try writePayments(db: db, snapshot: s)
        try writeBookings(db: db, snapshot: s)
    }

    // MARK: - Per-model writers

    @MainActor
    private func writeClients(db: SQLiteConnection, snapshot s: Snapshot) throws {
        let sql = """
        INSERT INTO clients (
            id, first_name, last_name, email, phone, notes, pronouns, birthdate,
            allergy_notes, street_address, city, state, zip_code,
            profile_photo_path, email_opt_in, is_flash_portfolio_client,
            created_at, updated_at
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        for c in s.clients {
            let id = s.clientID[ObjectIdentifier(c)]!
            try db.write(sql, [
                .uuid(id),
                .text(c.firstName), .text(c.lastName),
                .text(c.email), .text(c.phone),
                .text(c.notes), .text(c.pronouns),
                .date(c.birthdate),
                .text(c.allergyNotes),
                .text(c.streetAddress), .text(c.city), .text(c.state), .text(c.zipCode),
                .text(c.profilePhotoPath),
                .bool(c.emailOptIn),
                .bool(c.isFlashPortfolioClient),
                .date(c.createdAt), .date(c.updatedAt)
            ])
        }
    }

    @MainActor
    private func writePieces(db: SQLiteConnection, snapshot s: Snapshot) throws {
        let sql = """
        INSERT INTO pieces (
            id, client_id, title, body_placement, description_text,
            status, piece_type, tags, primary_image_path, rating,
            size, size_dimensions, hourly_rate, flat_rate, deposit_amount,
            created_at, updated_at, completed_at
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        for p in s.pieces {
            let id = s.pieceID[ObjectIdentifier(p)]!
            let clientFK = p.client.flatMap { s.clientID[ObjectIdentifier($0)] }
            try db.write(sql, [
                .uuid(id),
                .uuid(clientFK),
                .text(p.title), .text(p.bodyPlacement), .text(p.descriptionText),
                .text(p.status.rawValue), .text(p.pieceType.rawValue),
                .json(p.tags),
                .text(p.primaryImagePath),
                .int(p.rating),
                .text(p.size?.rawValue),
                p.sizeDimensions.map { SQLiteValue.json($0) } ?? .null,
                .decimal(p.hourlyRate),
                .decimal(p.flatRate),
                .decimal(p.depositAmount),
                .date(p.createdAt), .date(p.updatedAt),
                .date(p.completedAt)
            ])
        }
    }

    @MainActor
    private func writeSessions(db: SQLiteConnection, snapshot s: Snapshot) throws {
        let sql = """
        INSERT INTO sessions (
            id, piece_id, date, start_time, end_time, break_minutes,
            session_type, hourly_rate_at_time, flash_rate, manual_hours_override,
            is_no_show, no_show_fee, notes
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        for ss in s.sessions {
            let id = s.sessionID[ObjectIdentifier(ss)]!
            let pieceFK = ss.piece.flatMap { s.pieceID[ObjectIdentifier($0)] }
            try db.write(sql, [
                .uuid(id),
                .uuid(pieceFK),
                .date(ss.date), .date(ss.startTime), .date(ss.endTime),
                .int(ss.breakMinutes),
                .text(ss.sessionType.rawValue),
                .decimal(ss.hourlyRateAtTime), .decimal(ss.flashRate),
                .real(ss.manualHoursOverride),
                .bool(ss.isNoShow),
                .decimal(ss.noShowFee),
                .text(ss.notes)
            ])
        }
    }

    @MainActor
    private func writeSessionProgress(db: SQLiteConnection, snapshot s: Snapshot) throws {
        let sql = """
        INSERT INTO session_progress (
            id, piece_id, session_id, stage, notes, time_spent_minutes, created_at
        ) VALUES (?,?,?,?,?,?,?)
        """
        for sp in s.sessionProgress {
            let id = s.sessionProgressID[ObjectIdentifier(sp)]!
            let pieceFK   = sp.piece.flatMap   { s.pieceID[ObjectIdentifier($0)] }
            let sessionFK = sp.session.flatMap { s.sessionID[ObjectIdentifier($0)] }
            try db.write(sql, [
                .uuid(id),
                .uuid(pieceFK),
                .uuid(sessionFK),
                .text(sp.stage.rawValue),
                .text(sp.notes),
                .int(sp.timeSpentMinutes),
                .date(sp.createdAt)
            ])
        }
    }

    @MainActor
    private func writeWorkImages(db: SQLiteConnection, snapshot s: Snapshot) throws {
        let sql = """
        INSERT INTO work_images (
            id, session_progress_id, piece_id, client_id,
            file_path, file_name, title, notes, captured_at,
            sort_order, is_primary, is_portfolio,
            category, healing_stage, source, tags
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        for w in s.workImages {
            let spFK = w.sessionProgress.flatMap { s.sessionProgressID[ObjectIdentifier($0)] }
            let pieceFK  = w.piece.flatMap  { s.pieceID[ObjectIdentifier($0)] }
            let clientFK = w.client.flatMap { s.clientID[ObjectIdentifier($0)] }
            try db.write(sql, [
                .uuid(UUID()),
                .uuid(spFK), .uuid(pieceFK), .uuid(clientFK),
                .text(w.filePath), .text(w.fileName),
                .text(w.title), .text(w.notes),
                .date(w.capturedAt),
                .int(w.sortOrder),
                .bool(w.isPrimary), .bool(w.isPortfolio),
                .text(w.category.rawValue),
                .text(w.healingStage?.rawValue),
                .text(w.source.rawValue),
                .json(w.tags)
            ])
        }
    }

    @MainActor
    private func writeAgreements(db: SQLiteConnection, snapshot s: Snapshot) throws {
        let sql = """
        INSERT INTO agreements (
            id, client_id, title, agreement_type, body_text,
            is_signed, signed_at, signature_image_path, created_at
        ) VALUES (?,?,?,?,?,?,?,?,?)
        """
        for a in s.agreements {
            let clientFK = a.client.flatMap { s.clientID[ObjectIdentifier($0)] }
            try db.write(sql, [
                .uuid(UUID()),
                .uuid(clientFK),
                .text(a.title), .text(a.agreementType.rawValue),
                .text(a.bodyText),
                .bool(a.isSigned),
                .date(a.signedAt),
                .text(a.signatureImagePath),
                .date(a.createdAt)
            ])
        }
    }

    @MainActor
    private func writeCommunicationLogs(db: SQLiteConnection, snapshot s: Snapshot) throws {
        let sql = """
        INSERT INTO communication_logs (
            id, client_id, comm_type, subject, body_text, sent_at, was_auto_generated
        ) VALUES (?,?,?,?,?,?,?)
        """
        for cl in s.communicationLogs {
            let clientFK = cl.client.flatMap { s.clientID[ObjectIdentifier($0)] }
            try db.write(sql, [
                .uuid(UUID()),
                .uuid(clientFK),
                .text(cl.commType.rawValue),
                .text(cl.subject), .text(cl.bodyText),
                .date(cl.sentAt),
                .bool(cl.wasAutoGenerated)
            ])
        }
    }

    @MainActor
    private func writePayments(db: SQLiteConnection, snapshot s: Snapshot) throws {
        let sql = """
        INSERT INTO payments (
            id, client_id, piece_id, amount, payment_date,
            payment_method, payment_type, notes, created_at
        ) VALUES (?,?,?,?,?,?,?,?,?)
        """
        for p in s.payments {
            let clientFK = p.client.flatMap { s.clientID[ObjectIdentifier($0)] }
            let pieceFK  = p.piece.flatMap  { s.pieceID[ObjectIdentifier($0)] }
            try db.write(sql, [
                .uuid(UUID()),
                .uuid(clientFK), .uuid(pieceFK),
                .decimal(p.amount),
                .date(p.paymentDate),
                .text(p.paymentMethod.rawValue),
                .text(p.paymentType.rawValue),
                .text(p.notes),
                .date(p.createdAt)
            ])
        }
    }

    @MainActor
    private func writeBookings(db: SQLiteConnection, snapshot s: Snapshot) throws {
        let sql = """
        INSERT INTO bookings (
            id, client_id, piece_id, date, start_time, end_time,
            status, booking_type, notes, deposit_paid, reminder_sent,
            checklist_overrides, custom_checklist_items, created_at, updated_at
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        for b in s.bookings {
            let clientFK = b.client.flatMap { s.clientID[ObjectIdentifier($0)] }
            let pieceFK  = b.piece.flatMap  { s.pieceID[ObjectIdentifier($0)] }
            try db.write(sql, [
                .uuid(UUID()),
                .uuid(clientFK), .uuid(pieceFK),
                .date(b.date), .date(b.startTime), .date(b.endTime),
                .text(b.status.rawValue),
                .text(b.bookingType.rawValue),
                .text(b.notes),
                .bool(b.depositPaid),
                .bool(b.reminderSent),
                .json(b.checklistOverrides),
                .json(b.customChecklistItems),
                .date(b.createdAt), .date(b.updatedAt)
            ])
        }
    }

    @MainActor
    private func writeUserProfiles(db: SQLiteConnection, list: [UserProfile]) throws {
        let sql = """
        INSERT INTO user_profiles (
            id, first_name, last_name, business_name, email, phone, profession,
            profile_photo_path, default_hourly_rate, currency,
            deposit_flat, deposit_percentage,
            friends_family_discount, preferred_client_discount,
            holiday_discount, convention_discount,
            no_show_fee, revision_fee, administrative_fee,
            flash_pricing_mode_raw, chargeable_session_types, status_color_names,
            shop_address_line1, shop_address_line2, shop_city, shop_state,
            shop_postal_code, shop_country,
            billing_address_line1, billing_address_line2, billing_city, billing_state,
            billing_postal_code, billing_country,
            created_at, updated_at
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        for p in list {
            try db.write(sql, [
                .uuid(UUID()),
                .text(p.firstName), .text(p.lastName), .text(p.businessName),
                .text(p.email), .text(p.phone),
                .text(p.profession.rawValue),
                .text(p.profilePhotoPath),
                .decimal(p.defaultHourlyRate), .text(p.currency),
                .decimal(p.depositFlat), .decimal(p.depositPercentage),
                .decimal(p.friendsFamilyDiscount),
                .decimal(p.preferredClientDiscount),
                .decimal(p.holidayDiscount),
                .decimal(p.conventionDiscount),
                .decimal(p.noShowFee), .decimal(p.revisionFee), .decimal(p.administrativeFee),
                .text(p.flashPricingModeRaw),
                .json(p.chargeableSessionTypes),
                .json(p.statusColorNames),
                .text(p.shopAddressLine1), .text(p.shopAddressLine2),
                .text(p.shopCity), .text(p.shopState),
                .text(p.shopPostalCode), .text(p.shopCountry),
                .text(p.billingAddressLine1), .text(p.billingAddressLine2),
                .text(p.billingCity), .text(p.billingState),
                .text(p.billingPostalCode), .text(p.billingCountry),
                .date(p.createdAt), .date(p.updatedAt)
            ])
        }
    }

    @MainActor
    private func writeSessionCategories(db: SQLiteConnection, list: [SessionCategory]) throws {
        let sql = "INSERT INTO session_categories (id, uuid, name, is_chargeable, sort_order, created_at) VALUES (?,?,?,?,?,?)"
        for c in list {
            try db.write(sql, [
                .uuid(UUID()),
                .uuid(c.uuid),
                .text(c.name),
                .bool(c.isChargeable),
                .int(c.sortOrder),
                .date(c.createdAt)
            ])
        }
    }

    @MainActor
    private func writeEmailTemplates(db: SQLiteConnection, list: [SavedEmailTemplate]) throws {
        let sql = "INSERT INTO email_templates (id, name, subject, body, category_raw, created_at, updated_at) VALUES (?,?,?,?,?,?,?)"
        for e in list {
            try db.write(sql, [
                .uuid(UUID()),
                .text(e.name), .text(e.subject), .text(e.body),
                .text(e.categoryRaw),
                .date(e.createdAt), .date(e.updatedAt)
            ])
        }
    }

    @MainActor
    private func writeAvailabilitySlots(db: SQLiteConnection, list: [AvailabilitySlot]) throws {
        let sql = "INSERT INTO availability_slots (id, day_of_week, start_time, end_time, slot_type_raw, is_flash_only, is_active) VALUES (?,?,?,?,?,?,?)"
        for s in list {
            try db.write(sql, [
                .uuid(UUID()),
                .int(s.dayOfWeek),
                .date(s.startTime), .date(s.endTime),
                .text(s.slotTypeRaw),
                .bool(s.isFlashOnly),
                .bool(s.isActive)
            ])
        }
    }

    @MainActor
    private func writeAvailabilityOverrides(db: SQLiteConnection, list: [AvailabilityOverride]) throws {
        let sql = "INSERT INTO availability_overrides (id, start_date, end_date, reason, is_unavailable) VALUES (?,?,?,?,?)"
        for o in list {
            try db.write(sql, [
                .uuid(UUID()),
                .date(o.startDate), .date(o.endDate),
                .text(o.reason),
                .bool(o.isUnavailable)
            ])
        }
    }

    @MainActor
    private func writeSessionRateConfigs(db: SQLiteConnection, list: [SessionRateConfig]) throws {
        let sql = """
        INSERT INTO session_rate_configs (
            id, session_type_raw, rate_mode_raw, rate_value,
            deposit_mode_raw, discount_type_raw, fee_type_raw, flash_pricing_mode_raw
        ) VALUES (?,?,?,?,?,?,?,?)
        """
        for c in list {
            try db.write(sql, [
                .uuid(UUID()),
                .text(c.sessionTypeRaw),
                .text(c.rateModeRaw), .decimal(c.rateValue),
                .text(c.depositModeRaw),
                .text(c.discountTypeRaw),
                .text(c.feeTypeRaw),
                .text(c.flashPricingModeRaw)
            ])
        }
    }

    @MainActor
    private func writeFlashPriceTiers(db: SQLiteConnection, list: [FlashPriceTier]) throws {
        let sql = "INSERT INTO flash_price_tiers (id, uuid, label, width_inches, height_inches, price, sort_order) VALUES (?,?,?,?,?,?,?)"
        for t in list {
            try db.write(sql, [
                .uuid(UUID()),
                .uuid(t.uuid),
                .text(t.label),
                .real(t.widthInches), .real(t.heightInches),
                .decimal(t.price),
                .int(t.sortOrder)
            ])
        }
    }

    @MainActor
    private func writeGalleryGroups(db: SQLiteConnection, list: [GalleryGroup]) throws {
        let sql = "INSERT INTO gallery_groups (id, name, tags, sort_index, created_at) VALUES (?,?,?,?,?)"
        for g in list {
            try db.write(sql, [
                .uuid(UUID()),
                .text(g.name),
                .json(g.tags),
                .int(g.sortIndex),
                .date(g.createdAt)
            ])
        }
    }

    @MainActor
    private func writeDiscounts(db: SQLiteConnection, list: [Discount]) throws {
        let sql = "INSERT INTO discounts (id, name, percentage, sort_order) VALUES (?,?,?,?)"
        for d in list {
            try db.write(sql, [
                .uuid(UUID()),
                .text(d.name),
                .decimal(d.percentage),
                .int(d.sortOrder)
            ])
        }
    }

    // MARK: - Image copy

    /// Mirrors Documents/CounterImages → <package>/Images. Returns the
    /// regular-file count and total bytes copied. Reuses the same
    /// "skip-if-exists" semantics as RecoveryService since image files are
    /// addressed by UUID and never overwritten.
    private func copyImages(to destBase: URL) throws -> (count: Int, bytes: UInt64) {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return (0, 0)
        }
        let sourceBase = docs.appendingPathComponent(imagesSourceDirName)
        guard fileManager.fileExists(atPath: sourceBase.path) else { return (0, 0) }

        try fileManager.createDirectory(at: destBase, withIntermediateDirectories: true)

        var count = 0
        var bytes: UInt64 = 0
        guard let enumerator = fileManager.enumerator(
            at: sourceBase,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return (0, 0) }

        while let fileURL = enumerator.nextObject() as? URL {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
            else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: sourceBase.path, with: "")
            let destURL = destBase.appendingPathComponent(relativePath)

            if fileManager.fileExists(atPath: destURL.path) { continue }

            try fileManager.createDirectory(
                at: destURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileManager.copyItem(at: fileURL, to: destURL)
            count += 1
            if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) {
                bytes += UInt64(size)
            }
        }
        return (count, bytes)
    }

    // MARK: Helpers

    /// Same source as RecoveryService.currentAppVersion so manifests and
    /// JSON backups agree on what shipped them.
    static var currentAppVersion: String {
        let short = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        return "\(short) (\(build))"
    }
}
