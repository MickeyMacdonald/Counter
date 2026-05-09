import Foundation
import SwiftData

// MARK: - Cntrdb Importer
//
// Reads a `.cntrdb` package and replaces the contents of the SwiftData
// store with what it finds. Mirrors the staging of
// `RecoveryService.restore(from:)` so behaviour is consistent across the
// two formats:
//
//   1. Validate package layout
//   2. Read manifest + version checks
//   3. Verify SQLite checksum (catches mid-copy corruption)
//   4. Refuse empty imports
//   5. Verify image folder presence vs. manifest count
//   6. Take a pre-restore JSON snapshot (rollback point — uses RecoveryService)
//   7. Wipe live store, then phased insert from SQLite
//   8. Restore images by replacing Documents/CounterImages
//   9. Restore UserDefaults from `_user_defaults`
//
// The destructive steps (7–9) only begin once every preflight check passes.

actor CntrdbImporter {

    static let shared = CntrdbImporter()

    private let fileManager = FileManager.default
    private let imagesDestDirName = "CounterImages"

    // MARK: - Public API

    @discardableResult
    func importPackage(at url: URL, context: ModelContext) async throws -> CntrdbManifest {

        // 1. Layout sanity check.
        try CntrdbPackage.validateLayout(at: url)
        let pkg = CntrdbPackage(url: url)

        // 2. Read manifest.
        let manifest: CntrdbManifest
        do {
            let data = try Data(contentsOf: pkg.manifestURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            manifest = try decoder.decode(CntrdbManifest.self, from: data)
        } catch {
            throw CntrdbError.manifestUnreadable(error.localizedDescription)
        }

        // 3. Version gates. We do NOT attempt forward-migration in v1 —
        //    a future build that bumps schemaVersion to 2 will land a
        //    migration step here.
        guard manifest.formatVersion <= CntrdbPackage.currentFormatVersion else {
            throw CntrdbError.formatVersionUnsupported(
                found: manifest.formatVersion,
                expected: CntrdbPackage.currentFormatVersion
            )
        }
        guard manifest.schemaVersion <= CntrdbSchema.currentVersion else {
            throw CntrdbError.schemaVersionUnsupported(
                found: manifest.schemaVersion,
                expected: CntrdbSchema.currentVersion
            )
        }

        // 4. Checksum the database file BEFORE opening it. A mismatch is a
        //    hard fail — opening a partially-copied SQLite would still
        //    "work" but yield silently truncated rows.
        let actualChecksum = try CntrdbManifest.sha256HexOfFile(at: pkg.databaseURL)
        guard manifest.databaseChecksum == actualChecksum else {
            throw CntrdbError.databaseChecksumMismatch(
                expected: manifest.databaseChecksum,
                actual: actualChecksum
            )
        }

        // 5. Open the SQLite (read-only path uses RW open so we can't
        //    accidentally write — we never call exec, only SELECT).
        let db = try SQLiteConnection(openAt: pkg.databaseURL, create: false)
        defer { db.close() }

        // 6. Refuse empty imports — an all-zero file would silently destroy
        //    the user's live store. Match RecoveryService's behaviour.
        let totalRows = try countTotalRows(db: db)
        guard totalRows > 0 else {
            throw CntrdbError.refuseEmptyImport
        }

        // 7. Image folder preflight. Manifest is the source of truth for
        //    image count; we don't trust the live folder enumeration.
        if manifest.imageCount > 0 {
            guard fileManager.fileExists(atPath: pkg.imagesURL.path) else {
                throw CntrdbError.imagesFolderMissing
            }
        }

        // 8. Pre-restore JSON snapshot via RecoveryService — re-uses the
        //    existing rollback infrastructure so users have a single
        //    "undo last restore" mechanism regardless of which format
        //    they imported from.
        do {
            _ = try await RecoveryService.shared.performPreRestoreSnapshot(context: context)
        } catch {
            throw CntrdbError.preRestoreSnapshotFailed(error.localizedDescription)
        }

        // 9. Destructive phase. Read all rows from SQLite into Swift
        //    structs first (so we can do the wipe + insert on the main
        //    actor in one shot), then wipe and insert.
        let payload = try readAllRows(db: db)

        try await MainActor.run {
            try wipeAllData(context: context)
            try insertAll(payload, context: context)
            try context.save()
        }

        // 10. Replace Documents/CounterImages with the package's Images/.
        try restoreImages(from: pkg.imagesURL, expectedCount: manifest.imageCount)

        // 11. Restore UserDefaults from `_user_defaults`.
        try restoreUserDefaults(db: db)

        return manifest
    }

    // MARK: - Row counting

    private func countTotalRows(db: SQLiteConnection) throws -> Int {
        let tables = [
            "clients", "pieces", "sessions", "session_progress", "work_images",
            "bookings", "agreements", "communication_logs", "payments",
            "user_profiles", "session_categories", "email_templates",
            "availability_slots", "availability_overrides",
            "session_rate_configs", "flash_price_tiers",
            "gallery_groups", "discounts"
        ]
        var total = 0
        for t in tables {
            let stmt = try db.prepare("SELECT COUNT(*) FROM \(t)")
            try stmt.forEachRow { row in total += row.int(0) }
            stmt.finalize()
        }
        return total
    }

    // MARK: - Read

    /// Plain-Swift mirror of every table. We materialise everything before
    /// the wipe so we can hand the destructive phase a complete picture
    /// and fail loudly if SQLite trips up before we touch SwiftData.
    private struct Payload {
        var clients:               [ClientRow]               = []
        var pieces:                [PieceRow]                = []
        var sessions:              [SessionRow]              = []
        var sessionProgress:       [SessionProgressRow]      = []
        var workImages:            [WorkImageRow]            = []
        var bookings:              [BookingRow]              = []
        var agreements:            [AgreementRow]            = []
        var communicationLogs:     [CommunicationLogRow]     = []
        var payments:              [PaymentRow]              = []
        var profiles:              [UserProfileRow]          = []
        var sessionCategories:     [SessionCategoryRow]      = []
        var emailTemplates:        [EmailTemplateRow]        = []
        var availabilitySlots:     [AvailabilitySlotRow]     = []
        var availabilityOverrides: [AvailabilityOverrideRow] = []
        var sessionRateConfigs:    [SessionRateConfigRow]    = []
        var flashPriceTiers:       [FlashPriceTierRow]       = []
        var galleryGroups:         [GalleryGroupRow]         = []
        var discounts:             [DiscountRow]             = []
    }

    private func readAllRows(db: SQLiteConnection) throws -> Payload {
        var p = Payload()
        try readClients(db: db, into: &p)
        try readPieces(db: db, into: &p)
        try readSessions(db: db, into: &p)
        try readSessionProgress(db: db, into: &p)
        try readWorkImages(db: db, into: &p)
        try readBookings(db: db, into: &p)
        try readAgreements(db: db, into: &p)
        try readCommunicationLogs(db: db, into: &p)
        try readPayments(db: db, into: &p)
        try readUserProfiles(db: db, into: &p)
        try readSessionCategories(db: db, into: &p)
        try readEmailTemplates(db: db, into: &p)
        try readAvailabilitySlots(db: db, into: &p)
        try readAvailabilityOverrides(db: db, into: &p)
        try readSessionRateConfigs(db: db, into: &p)
        try readFlashPriceTiers(db: db, into: &p)
        try readGalleryGroups(db: db, into: &p)
        try readDiscounts(db: db, into: &p)
        return p
    }

    // MARK: Row structs (Swift mirrors of SQLite rows)
    //
    // These exist so the read phase produces something that can travel
    // across the actor hop into the MainActor for inserts. Using SwiftData
    // model objects directly here would require initialising them off the
    // main actor, which SwiftData does not allow.

    private struct ClientRow {
        let id: UUID
        let firstName, lastName, email, phone, notes, pronouns: String
        let birthdate: Date?
        let allergyNotes, streetAddress, city, state, zipCode: String
        let profilePhotoPath: String?
        let emailOptIn, isFlashPortfolioClient: Bool
        let createdAt, updatedAt: Date
    }
    private struct PieceRow {
        let id: UUID
        let clientID: UUID?
        let title, bodyPlacement, descriptionText, status, pieceType: String
        let tags: [String]
        let primaryImagePath: String?
        let rating: Int?
        let size: String?
        let sizeDimensions: PieceDimensions?
        let hourlyRate: Decimal
        let flatRate: Decimal?
        let depositAmount: Decimal
        let createdAt, updatedAt: Date
        let completedAt: Date?
    }
    private struct SessionRow {
        let id: UUID
        let pieceID: UUID?
        let date, startTime: Date
        let endTime: Date?
        let breakMinutes: Int
        let sessionType: String
        let hourlyRateAtTime, flashRate: Decimal
        let manualHoursOverride: Double?
        let isNoShow: Bool
        let noShowFee: Decimal?
        let notes: String
    }
    private struct SessionProgressRow {
        let id: UUID
        let pieceID, sessionID: UUID?
        let stage, notes: String
        let timeSpentMinutes: Int
        let createdAt: Date
    }
    private struct WorkImageRow {
        let id: UUID
        let sessionProgressID, pieceID, clientID: UUID?
        let filePath, fileName, title, notes: String
        let capturedAt: Date
        let sortOrder: Int
        let isPrimary, isPortfolio: Bool
        let category: String
        let healingStage: String?
        let source: String
        let tags: [String]
    }
    private struct BookingRow {
        let id: UUID
        let clientID, pieceID: UUID?
        let date, startTime, endTime: Date
        let status, bookingType, notes: String
        let depositPaid, reminderSent: Bool
        let checklistOverrides: [String]
        let customChecklistItems: [BookingCustomTask]
        let createdAt, updatedAt: Date
    }
    private struct AgreementRow {
        let id: UUID
        let clientID: UUID?
        let title, agreementType, bodyText: String
        let isSigned: Bool
        let signedAt: Date?
        let signatureImagePath: String?
        let createdAt: Date
    }
    private struct CommunicationLogRow {
        let id: UUID
        let clientID: UUID?
        let commType, subject, bodyText: String
        let sentAt: Date
        let wasAutoGenerated: Bool
    }
    private struct PaymentRow {
        let id: UUID
        let clientID, pieceID: UUID?
        let amount: Decimal
        let paymentDate: Date
        let paymentMethod, paymentType, notes: String
        let createdAt: Date
    }
    private struct UserProfileRow {
        let firstName, lastName, businessName, email, phone, profession: String
        let profilePhotoPath: String?
        let defaultHourlyRate: Decimal
        let currency: String
        let depositFlat, depositPercentage: Decimal
        let friendsFamilyDiscount, preferredClientDiscount, holidayDiscount, conventionDiscount: Decimal
        let noShowFee, revisionFee, administrativeFee: Decimal
        let flashPricingModeRaw: String
        let chargeableSessionTypes: [String]
        let statusColorNames: [String: String]
        let shopAddressLine1, shopAddressLine2, shopCity, shopState, shopPostalCode, shopCountry: String
        let billingAddressLine1, billingAddressLine2, billingCity, billingState, billingPostalCode, billingCountry: String
        let createdAt, updatedAt: Date
    }
    private struct SessionCategoryRow {
        let uuid: UUID
        let name: String
        let isChargeable: Bool
        let sortOrder: Int
        let createdAt: Date
    }
    private struct EmailTemplateRow {
        let name, subject, body, categoryRaw: String
        let createdAt, updatedAt: Date
    }
    private struct AvailabilitySlotRow {
        let dayOfWeek: Int
        let startTime, endTime: Date
        let slotTypeRaw: String
        let isFlashOnly, isActive: Bool
    }
    private struct AvailabilityOverrideRow {
        let startDate, endDate: Date
        let reason: String
        let isUnavailable: Bool
    }
    private struct SessionRateConfigRow {
        let sessionTypeRaw, rateModeRaw: String
        let rateValue: Decimal
        let depositModeRaw, discountTypeRaw, feeTypeRaw, flashPricingModeRaw: String
    }
    private struct FlashPriceTierRow {
        let uuid: UUID
        let label: String
        let widthInches, heightInches: Double
        let price: Decimal
        let sortOrder: Int
    }
    private struct GalleryGroupRow {
        let name: String
        let tags: [String]
        let sortIndex: Int
        let createdAt: Date
    }
    private struct DiscountRow {
        let name: String
        let percentage: Decimal
        let sortOrder: Int
    }

    // MARK: Per-table readers
    //
    // Column ORDER below matches CntrdbSchema.ddl exactly. If you change
    // either side, change both — there is no name lookup.

    private func readClients(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("""
            SELECT id, first_name, last_name, email, phone, notes, pronouns, birthdate,
                   allergy_notes, street_address, city, state, zip_code,
                   profile_photo_path, email_opt_in, is_flash_portfolio_client,
                   created_at, updated_at
            FROM clients
            """)
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let id = r.uuid(0),
                  let createdAt = r.date(16),
                  let updatedAt = r.date(17)
            else { return }
            p.clients.append(ClientRow(
                id: id,
                firstName: r.text(1), lastName: r.text(2),
                email: r.text(3), phone: r.text(4),
                notes: r.text(5), pronouns: r.text(6),
                birthdate: r.date(7),
                allergyNotes: r.text(8),
                streetAddress: r.text(9), city: r.text(10),
                state: r.text(11), zipCode: r.text(12),
                profilePhotoPath: r.textOrNil(13),
                emailOptIn: r.bool(14),
                isFlashPortfolioClient: r.bool(15),
                createdAt: createdAt, updatedAt: updatedAt
            ))
        }
    }

    private func readPieces(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("""
            SELECT id, client_id, title, body_placement, description_text,
                   status, piece_type, tags, primary_image_path, rating,
                   size, size_dimensions, hourly_rate, flat_rate, deposit_amount,
                   created_at, updated_at, completed_at
            FROM pieces
            """)
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let id = r.uuid(0),
                  let hourly = r.decimal(12),
                  let deposit = r.decimal(14),
                  let createdAt = r.date(15),
                  let updatedAt = r.date(16)
            else { return }
            p.pieces.append(PieceRow(
                id: id,
                clientID: r.uuid(1),
                title: r.text(2), bodyPlacement: r.text(3), descriptionText: r.text(4),
                status: r.text(5), pieceType: r.text(6),
                tags: r.json(7, as: [String].self) ?? [],
                primaryImagePath: r.textOrNil(8),
                rating: r.intOrNil(9),
                size: r.textOrNil(10),
                sizeDimensions: r.json(11, as: PieceDimensions.self),
                hourlyRate: hourly,
                flatRate: r.decimal(13),
                depositAmount: deposit,
                createdAt: createdAt, updatedAt: updatedAt,
                completedAt: r.date(17)
            ))
        }
    }

    private func readSessions(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("""
            SELECT id, piece_id, date, start_time, end_time, break_minutes,
                   session_type, hourly_rate_at_time, flash_rate, manual_hours_override,
                   is_no_show, no_show_fee, notes
            FROM sessions
            """)
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let id = r.uuid(0),
                  let date = r.date(2),
                  let start = r.date(3),
                  let hourly = r.decimal(7),
                  let flash = r.decimal(8)
            else { return }
            p.sessions.append(SessionRow(
                id: id,
                pieceID: r.uuid(1),
                date: date, startTime: start, endTime: r.date(4),
                breakMinutes: r.int(5),
                sessionType: r.text(6),
                hourlyRateAtTime: hourly, flashRate: flash,
                manualHoursOverride: r.doubleOrNil(9),
                isNoShow: r.bool(10),
                noShowFee: r.decimal(11),
                notes: r.text(12)
            ))
        }
    }

    private func readSessionProgress(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("""
            SELECT id, piece_id, session_id, stage, notes, time_spent_minutes, created_at
            FROM session_progress
            """)
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let id = r.uuid(0), let createdAt = r.date(6) else { return }
            p.sessionProgress.append(SessionProgressRow(
                id: id,
                pieceID: r.uuid(1), sessionID: r.uuid(2),
                stage: r.text(3),
                notes: r.text(4),
                timeSpentMinutes: r.int(5),
                createdAt: createdAt
            ))
        }
    }

    private func readWorkImages(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("""
            SELECT id, session_progress_id, piece_id, client_id,
                   file_path, file_name, title, notes, captured_at,
                   sort_order, is_primary, is_portfolio,
                   category, healing_stage, source, tags
            FROM work_images
            """)
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let id = r.uuid(0), let captured = r.date(8) else { return }
            p.workImages.append(WorkImageRow(
                id: id,
                sessionProgressID: r.uuid(1),
                pieceID: r.uuid(2),
                clientID: r.uuid(3),
                filePath: r.text(4),
                fileName: r.text(5),
                title: r.text(6),
                notes: r.text(7),
                capturedAt: captured,
                sortOrder: r.int(9),
                isPrimary: r.bool(10),
                isPortfolio: r.bool(11),
                category: r.text(12),
                healingStage: r.textOrNil(13),
                source: r.text(14),
                tags: r.json(15, as: [String].self) ?? []
            ))
        }
    }

    private func readBookings(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("""
            SELECT id, client_id, piece_id, date, start_time, end_time,
                   status, booking_type, notes, deposit_paid, reminder_sent,
                   checklist_overrides, custom_checklist_items, created_at, updated_at
            FROM bookings
            """)
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let id = r.uuid(0),
                  let date = r.date(3),
                  let start = r.date(4),
                  let end = r.date(5),
                  let createdAt = r.date(13),
                  let updatedAt = r.date(14)
            else { return }
            p.bookings.append(BookingRow(
                id: id,
                clientID: r.uuid(1), pieceID: r.uuid(2),
                date: date, startTime: start, endTime: end,
                status: r.text(6), bookingType: r.text(7),
                notes: r.text(8),
                depositPaid: r.bool(9), reminderSent: r.bool(10),
                checklistOverrides: r.json(11, as: [String].self) ?? [],
                customChecklistItems: r.json(12, as: [BookingCustomTask].self) ?? [],
                createdAt: createdAt, updatedAt: updatedAt
            ))
        }
    }

    private func readAgreements(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("""
            SELECT id, client_id, title, agreement_type, body_text,
                   is_signed, signed_at, signature_image_path, created_at
            FROM agreements
            """)
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let id = r.uuid(0), let createdAt = r.date(8) else { return }
            p.agreements.append(AgreementRow(
                id: id,
                clientID: r.uuid(1),
                title: r.text(2), agreementType: r.text(3),
                bodyText: r.text(4),
                isSigned: r.bool(5),
                signedAt: r.date(6),
                signatureImagePath: r.textOrNil(7),
                createdAt: createdAt
            ))
        }
    }

    private func readCommunicationLogs(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("""
            SELECT id, client_id, comm_type, subject, body_text, sent_at, was_auto_generated
            FROM communication_logs
            """)
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let id = r.uuid(0), let sentAt = r.date(5) else { return }
            p.communicationLogs.append(CommunicationLogRow(
                id: id,
                clientID: r.uuid(1),
                commType: r.text(2),
                subject: r.text(3), bodyText: r.text(4),
                sentAt: sentAt,
                wasAutoGenerated: r.bool(6)
            ))
        }
    }

    private func readPayments(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("""
            SELECT id, client_id, piece_id, amount, payment_date,
                   payment_method, payment_type, notes, created_at
            FROM payments
            """)
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let id = r.uuid(0),
                  let amount = r.decimal(3),
                  let paymentDate = r.date(4),
                  let createdAt = r.date(8)
            else { return }
            p.payments.append(PaymentRow(
                id: id,
                clientID: r.uuid(1), pieceID: r.uuid(2),
                amount: amount,
                paymentDate: paymentDate,
                paymentMethod: r.text(5),
                paymentType: r.text(6),
                notes: r.text(7),
                createdAt: createdAt
            ))
        }
    }

    private func readUserProfiles(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("""
            SELECT first_name, last_name, business_name, email, phone, profession,
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
            FROM user_profiles
            """)
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let dHr = r.decimal(7),
                  let dF = r.decimal(9), let dP = r.decimal(10),
                  let ff = r.decimal(11), let pc = r.decimal(12),
                  let h = r.decimal(13), let cv = r.decimal(14),
                  let nsf = r.decimal(15), let rf = r.decimal(16), let af = r.decimal(17),
                  let createdAt = r.date(33), let updatedAt = r.date(34)
            else { return }
            p.profiles.append(UserProfileRow(
                firstName: r.text(0), lastName: r.text(1), businessName: r.text(2),
                email: r.text(3), phone: r.text(4),
                profession: r.text(5),
                profilePhotoPath: r.textOrNil(6),
                defaultHourlyRate: dHr,
                currency: r.text(8),
                depositFlat: dF, depositPercentage: dP,
                friendsFamilyDiscount: ff, preferredClientDiscount: pc,
                holidayDiscount: h, conventionDiscount: cv,
                noShowFee: nsf, revisionFee: rf, administrativeFee: af,
                flashPricingModeRaw: r.text(18),
                chargeableSessionTypes: r.json(19, as: [String].self) ?? [],
                statusColorNames: r.json(20, as: [String: String].self) ?? [:],
                shopAddressLine1: r.text(21), shopAddressLine2: r.text(22),
                shopCity: r.text(23), shopState: r.text(24),
                shopPostalCode: r.text(25), shopCountry: r.text(26),
                billingAddressLine1: r.text(27), billingAddressLine2: r.text(28),
                billingCity: r.text(29), billingState: r.text(30),
                billingPostalCode: r.text(31), billingCountry: r.text(32),
                createdAt: createdAt, updatedAt: updatedAt
            ))
        }
    }

    private func readSessionCategories(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("SELECT uuid, name, is_chargeable, sort_order, created_at FROM session_categories")
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let uuid = r.uuid(0), let createdAt = r.date(4) else { return }
            p.sessionCategories.append(SessionCategoryRow(
                uuid: uuid, name: r.text(1),
                isChargeable: r.bool(2), sortOrder: r.int(3),
                createdAt: createdAt
            ))
        }
    }

    private func readEmailTemplates(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("SELECT name, subject, body, category_raw, created_at, updated_at FROM email_templates")
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let createdAt = r.date(4), let updatedAt = r.date(5) else { return }
            p.emailTemplates.append(EmailTemplateRow(
                name: r.text(0), subject: r.text(1), body: r.text(2),
                categoryRaw: r.text(3),
                createdAt: createdAt, updatedAt: updatedAt
            ))
        }
    }

    private func readAvailabilitySlots(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("SELECT day_of_week, start_time, end_time, slot_type_raw, is_flash_only, is_active FROM availability_slots")
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let start = r.date(1), let end = r.date(2) else { return }
            p.availabilitySlots.append(AvailabilitySlotRow(
                dayOfWeek: r.int(0),
                startTime: start, endTime: end,
                slotTypeRaw: r.text(3),
                isFlashOnly: r.bool(4),
                isActive: r.bool(5)
            ))
        }
    }

    private func readAvailabilityOverrides(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("SELECT start_date, end_date, reason, is_unavailable FROM availability_overrides")
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let start = r.date(0), let end = r.date(1) else { return }
            p.availabilityOverrides.append(AvailabilityOverrideRow(
                startDate: start, endDate: end,
                reason: r.text(2),
                isUnavailable: r.bool(3)
            ))
        }
    }

    private func readSessionRateConfigs(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("""
            SELECT session_type_raw, rate_mode_raw, rate_value,
                   deposit_mode_raw, discount_type_raw, fee_type_raw, flash_pricing_mode_raw
            FROM session_rate_configs
            """)
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let rate = r.decimal(2) else { return }
            p.sessionRateConfigs.append(SessionRateConfigRow(
                sessionTypeRaw: r.text(0),
                rateModeRaw: r.text(1),
                rateValue: rate,
                depositModeRaw: r.text(3),
                discountTypeRaw: r.text(4),
                feeTypeRaw: r.text(5),
                flashPricingModeRaw: r.text(6)
            ))
        }
    }

    private func readFlashPriceTiers(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("SELECT uuid, label, width_inches, height_inches, price, sort_order FROM flash_price_tiers")
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let uuid = r.uuid(0), let price = r.decimal(4) else { return }
            p.flashPriceTiers.append(FlashPriceTierRow(
                uuid: uuid, label: r.text(1),
                widthInches: r.double(2), heightInches: r.double(3),
                price: price,
                sortOrder: r.int(5)
            ))
        }
    }

    private func readGalleryGroups(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("SELECT name, tags, sort_index, created_at FROM gallery_groups")
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let createdAt = r.date(3) else { return }
            p.galleryGroups.append(GalleryGroupRow(
                name: r.text(0),
                tags: r.json(1, as: [String].self) ?? [],
                sortIndex: r.int(2),
                createdAt: createdAt
            ))
        }
    }

    private func readDiscounts(db: SQLiteConnection, into p: inout Payload) throws {
        let stmt = try db.prepare("SELECT name, percentage, sort_order FROM discounts")
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            guard let pct = r.decimal(1) else { return }
            p.discounts.append(DiscountRow(
                name: r.text(0),
                percentage: pct,
                sortOrder: r.int(2)
            ))
        }
    }

    // MARK: - Wipe (parallels RecoveryService.wipeAllData)

    @MainActor
    private func wipeAllData(context: ModelContext) throws {
        // Per-instance deletion (not batch) so SwiftData cascade rules
        // run normally. Same ordering rationale as RecoveryService:
        // leaves first, then their parents.
        func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
            try context.fetch(FetchDescriptor<T>()).forEach { context.delete($0) }
        }
        try deleteAll(WorkImage.self)
        try deleteAll(SessionProgress.self)
        try deleteAll(Session.self)
        try deleteAll(Booking.self)
        try deleteAll(Payment.self)
        try deleteAll(Agreement.self)
        try deleteAll(CommunicationLog.self)
        try deleteAll(Piece.self)
        try deleteAll(Client.self)
        try deleteAll(UserProfile.self)
        try deleteAll(SessionCategory.self)
        try deleteAll(SavedEmailTemplate.self)
        try deleteAll(AvailabilitySlot.self)
        try deleteAll(AvailabilityOverride.self)
        try deleteAll(SessionRateConfig.self)
        try deleteAll(FlashPriceTier.self)
        try deleteAll(GalleryGroup.self)
        try deleteAll(Discount.self)
    }

    // MARK: - Insert into SwiftData (parallels RecoveryService.deserializeAndInsert)

    @MainActor
    private func insertAll(_ p: Payload, context: ModelContext) throws {

        // Phase 1 — independents
        for r in p.profiles {
            let profile = UserProfile(
                firstName: r.firstName, lastName: r.lastName,
                businessName: r.businessName,
                profession: Profession(rawValue: r.profession) ?? .tattooer
            )
            profile.email = r.email
            profile.phone = r.phone
            profile.profilePhotoPath = r.profilePhotoPath
            profile.defaultHourlyRate = r.defaultHourlyRate
            profile.currency = r.currency
            profile.depositFlat = r.depositFlat
            profile.depositPercentage = r.depositPercentage
            profile.friendsFamilyDiscount = r.friendsFamilyDiscount
            profile.preferredClientDiscount = r.preferredClientDiscount
            profile.holidayDiscount = r.holidayDiscount
            profile.conventionDiscount = r.conventionDiscount
            profile.noShowFee = r.noShowFee
            profile.revisionFee = r.revisionFee
            profile.administrativeFee = r.administrativeFee
            profile.flashPricingModeRaw = r.flashPricingModeRaw
            profile.chargeableSessionTypes = r.chargeableSessionTypes
            profile.statusColorNames = r.statusColorNames
            profile.shopAddressLine1 = r.shopAddressLine1
            profile.shopAddressLine2 = r.shopAddressLine2
            profile.shopCity = r.shopCity
            profile.shopState = r.shopState
            profile.shopPostalCode = r.shopPostalCode
            profile.shopCountry = r.shopCountry
            profile.billingAddressLine1 = r.billingAddressLine1
            profile.billingAddressLine2 = r.billingAddressLine2
            profile.billingCity = r.billingCity
            profile.billingState = r.billingState
            profile.billingPostalCode = r.billingPostalCode
            profile.billingCountry = r.billingCountry
            context.insert(profile)
        }

        for r in p.sessionCategories {
            let obj = SessionCategory(name: r.name, isChargeable: r.isChargeable, sortOrder: r.sortOrder)
            obj.uuid = r.uuid
            obj.createdAt = r.createdAt
            context.insert(obj)
        }

        for r in p.emailTemplates {
            let obj = SavedEmailTemplate(
                name: r.name, subject: r.subject, body: r.body,
                category: EmailTemplate.TemplateCategory(rawValue: r.categoryRaw) ?? .custom
            )
            obj.createdAt = r.createdAt
            obj.updatedAt = r.updatedAt
            context.insert(obj)
        }

        for r in p.availabilitySlots {
            let obj = AvailabilitySlot(
                dayOfWeek: r.dayOfWeek, startTime: r.startTime, endTime: r.endTime,
                slotType: AvailabilitySlot.SlotType(rawValue: r.slotTypeRaw) ?? .available,
                isFlashOnly: r.isFlashOnly
            )
            obj.isActive = r.isActive
            context.insert(obj)
        }

        for r in p.availabilityOverrides {
            let obj = AvailabilityOverride(
                startDate: r.startDate, endDate: r.endDate,
                reason: r.reason, isUnavailable: r.isUnavailable
            )
            context.insert(obj)
        }

        for r in p.sessionRateConfigs {
            let obj = SessionRateConfig(sessionTypeRaw: r.sessionTypeRaw)
            obj.rateModeRaw = r.rateModeRaw
            obj.rateValue = r.rateValue
            obj.depositModeRaw = r.depositModeRaw
            obj.discountTypeRaw = r.discountTypeRaw
            obj.feeTypeRaw = r.feeTypeRaw
            obj.flashPricingModeRaw = r.flashPricingModeRaw
            context.insert(obj)
        }

        for r in p.flashPriceTiers {
            let obj = FlashPriceTier(
                label: r.label,
                widthInches: r.widthInches, heightInches: r.heightInches,
                price: r.price, sortOrder: r.sortOrder
            )
            obj.uuid = r.uuid
            context.insert(obj)
        }

        for r in p.galleryGroups {
            let obj = GalleryGroup(name: r.name, tags: r.tags, sortIndex: r.sortIndex)
            obj.createdAt = r.createdAt
            context.insert(obj)
        }

        for r in p.discounts {
            context.insert(Discount(name: r.name, percentage: r.percentage, sortOrder: r.sortOrder))
        }

        // Phase 2 — Clients
        var clientByID: [UUID: Client] = [:]
        for r in p.clients {
            let c = Client(
                firstName: r.firstName, lastName: r.lastName,
                email: r.email, phone: r.phone,
                notes: r.notes, pronouns: r.pronouns,
                birthdate: r.birthdate, allergyNotes: r.allergyNotes,
                streetAddress: r.streetAddress, city: r.city,
                state: r.state, zipCode: r.zipCode
            )
            c.profilePhotoPath = r.profilePhotoPath
            c.emailOptIn = r.emailOptIn
            c.isFlashPortfolioClient = r.isFlashPortfolioClient
            c.createdAt = r.createdAt
            c.updatedAt = r.updatedAt
            context.insert(c)
            clientByID[r.id] = c
        }

        // Phase 3 — Pieces (→ Client)
        var pieceByID: [UUID: Piece] = [:]
        for r in p.pieces {
            let pc = Piece(
                title: r.title, bodyPlacement: r.bodyPlacement,
                descriptionText: r.descriptionText,
                status: PieceStatus(rawValue: r.status) ?? .concept,
                pieceType: PieceType(rawValue: r.pieceType) ?? .custom,
                tags: r.tags,
                hourlyRate: r.hourlyRate,
                flatRate: r.flatRate,
                depositAmount: r.depositAmount
            )
            pc.primaryImagePath = r.primaryImagePath
            pc.rating = r.rating
            pc.size = r.size.flatMap { TattooSize(rawValue: $0) }
            pc.sizeDimensions = r.sizeDimensions
            pc.createdAt = r.createdAt
            pc.updatedAt = r.updatedAt
            pc.completedAt = r.completedAt
            pc.client = r.clientID.flatMap { clientByID[$0] }
            context.insert(pc)
            pieceByID[r.id] = pc
        }

        // Phase 4 — Sessions (→ Piece)
        var sessionByID: [UUID: Session] = [:]
        for r in p.sessions {
            let s = Session(
                date: r.date, startTime: r.startTime,
                sessionType: SessionType(rawValue: r.sessionType) ?? .consultation,
                hourlyRateAtTime: r.hourlyRateAtTime
            )
            s.endTime = r.endTime
            s.breakMinutes = r.breakMinutes
            s.flashRate = r.flashRate
            s.manualHoursOverride = r.manualHoursOverride
            s.isNoShow = r.isNoShow
            s.noShowFee = r.noShowFee
            s.notes = r.notes
            s.piece = r.pieceID.flatMap { pieceByID[$0] }
            context.insert(s)
            sessionByID[r.id] = s
        }

        // Phase 5 — SessionProgress (→ Piece, Session)
        var progressByID: [UUID: SessionProgress] = [:]
        for r in p.sessionProgress {
            let sp = SessionProgress(
                stage: ImageStage(rawValue: r.stage) ?? .sketch,
                notes: r.notes, timeSpentMinutes: r.timeSpentMinutes
            )
            sp.createdAt = r.createdAt
            sp.piece = r.pieceID.flatMap { pieceByID[$0] }
            sp.session = r.sessionID.flatMap { sessionByID[$0] }
            context.insert(sp)
            progressByID[r.id] = sp
        }

        // Phase 6 — WorkImages
        for r in p.workImages {
            let img = WorkImage(
                filePath: r.filePath, fileName: r.fileName,
                title: r.title, notes: r.notes,
                capturedAt: r.capturedAt,
                sortOrder: r.sortOrder,
                isPrimary: r.isPrimary, isPortfolio: r.isPortfolio,
                category: ImageCategory(rawValue: r.category) ?? .progress,
                healingStage: r.healingStage.flatMap { HealingStage(rawValue: $0) },
                source: ImageSource(rawValue: r.source) ?? .photoLibrary,
                tags: r.tags
            )
            img.sessionProgress = r.sessionProgressID.flatMap { progressByID[$0] }
            img.piece  = r.pieceID.flatMap  { pieceByID[$0] }
            img.client = r.clientID.flatMap { clientByID[$0] }
            context.insert(img)
        }

        // Phase 7 — Agreements, CommunicationLogs (→ Client)
        for r in p.agreements {
            let a = Agreement(
                title: r.title,
                agreementType: AgreementType(rawValue: r.agreementType) ?? .custom,
                bodyText: r.bodyText
            )
            a.isSigned = r.isSigned
            a.signedAt = r.signedAt
            a.signatureImagePath = r.signatureImagePath
            a.createdAt = r.createdAt
            a.client = r.clientID.flatMap { clientByID[$0] }
            context.insert(a)
        }

        for r in p.communicationLogs {
            let cl = CommunicationLog(
                commType: CommunicationType(rawValue: r.commType) ?? .note,
                subject: r.subject, bodyText: r.bodyText,
                sentAt: r.sentAt
            )
            cl.wasAutoGenerated = r.wasAutoGenerated
            cl.client = r.clientID.flatMap { clientByID[$0] }
            context.insert(cl)
        }

        // Phase 8 — Payments (→ Client, Piece)
        for r in p.payments {
            let pm = Payment(
                amount: r.amount, paymentDate: r.paymentDate,
                paymentMethod: PaymentMethod(rawValue: r.paymentMethod) ?? .other,
                paymentType: PaymentType(rawValue: r.paymentType) ?? .sessionPayment,
                notes: r.notes
            )
            pm.createdAt = r.createdAt
            pm.client = r.clientID.flatMap { clientByID[$0] }
            pm.piece  = r.pieceID.flatMap  { pieceByID[$0] }
            context.insert(pm)
        }

        // Phase 9 — Bookings (→ Client, Piece)
        for r in p.bookings {
            let bk = Booking(
                date: r.date, startTime: r.startTime, endTime: r.endTime,
                status: BookingStatus(rawValue: r.status) ?? .requested,
                bookingType: BookingType(rawValue: r.bookingType) ?? .session,
                notes: r.notes
            )
            bk.depositPaid = r.depositPaid
            bk.reminderSent = r.reminderSent
            bk.checklistOverrides = r.checklistOverrides
            bk.customChecklistItems = r.customChecklistItems
            bk.createdAt = r.createdAt
            bk.updatedAt = r.updatedAt
            bk.client = r.clientID.flatMap { clientByID[$0] }
            bk.piece  = r.pieceID.flatMap  { pieceByID[$0] }
            context.insert(bk)
        }
    }

    // MARK: - Image restore

    /// Replaces Documents/CounterImages with the package's Images folder
    /// and verifies the resulting file count matches the manifest.
    private func restoreImages(from sourceBase: URL, expectedCount: Int) throws {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            if expectedCount > 0 {
                throw CntrdbError.importFailed("Could not locate Documents directory.")
            }
            return
        }
        let destBase = docs.appendingPathComponent(imagesDestDirName)

        guard fileManager.fileExists(atPath: sourceBase.path) else {
            if expectedCount > 0 {
                throw CntrdbError.imagesFolderMissing
            }
            return
        }

        if fileManager.fileExists(atPath: destBase.path) {
            try fileManager.removeItem(at: destBase)
        }
        try fileManager.copyItem(at: sourceBase, to: destBase)

        if expectedCount > 0 {
            let actual = recursiveFileCount(at: destBase)
            if actual != expectedCount {
                throw CntrdbError.imageCountMismatch(expected: expectedCount, actual: actual)
            }
        }
    }

    private func recursiveFileCount(at url: URL) -> Int {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        ) else { return 0 }
        var n = 0
        while let f = enumerator.nextObject() as? URL {
            if (try? f.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true { n += 1 }
        }
        return n
    }

    // MARK: - UserDefaults restore

    private func restoreUserDefaults(db: SQLiteConnection) throws {
        let defaults = UserDefaults.standard
        let stmt = try db.prepare("SELECT key, value, value_type FROM _user_defaults")
        defer { stmt.finalize() }
        try stmt.forEachRow { r in
            let key = r.text(0)
            let value = r.text(1)
            let type = r.text(2)
            switch type {
            case "bool":   defaults.set(value == "1", forKey: key)
            case "int":    if let i = Int(value)    { defaults.set(i, forKey: key) }
            case "double": if let d = Double(value) { defaults.set(d, forKey: key) }
            case "string": defaults.set(value, forKey: key)
            default:       break
            }
        }
    }
}
