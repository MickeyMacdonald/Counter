import Foundation
@testable import Counter

// MARK: - Test Data Factories

enum BackupFixtures {

    /// A stable reference date used across all fixtures to keep assertions deterministic.
    static let referenceDate = Date(timeIntervalSince1970: 1_728_432_000) // 2024-10-09 00:00:00 UTC

    // MARK: - RecoveryBackup

    /// Minimal valid backup: one client, all other arrays empty.
    /// `totalModelCount` == 1, so restore won't reject it.
    static func minimalBackup(clientID: UUID = UUID()) -> RecoveryBackup {
        RecoveryBackup(
            version: RecoveryBackup.currentVersion,
            createdAt: referenceDate,
            appVersion: "0.9.0 (9000)",
            clients: [makeClientBackup(id: clientID)],
            pieces: [],
            sessions: [],
            sessionProgress: [],
            workImages: [],
            pieceImages: nil,
            inspirationImages: nil,
            bookings: [],
            agreements: [],
            communicationLogs: [],
            payments: [],
            profiles: [],
            customSessionTypes: [],
            customEmailTemplates: [],
            availabilitySlots: [],
            availabilityOverrides: [],
            sessionRateConfigs: [],
            flashPriceTiers: [],
            customGalleryGroups: [],
            customDiscounts: [],
            userDefaults: emptyUserDefaultsBackup()
        )
    }

    /// Backup with Client → Piece → Session chain to exercise relationship restoration.
    static func relationalBackup() -> RecoveryBackup {
        let clientID = UUID()
        let pieceID  = UUID()
        let sessionID = UUID()
        return RecoveryBackup(
            version: RecoveryBackup.currentVersion,
            createdAt: referenceDate,
            appVersion: "0.9.0 (9000)",
            clients: [makeClientBackup(id: clientID)],
            pieces: [makePieceBackup(id: pieceID, clientID: clientID)],
            sessions: [makeSessionBackup(id: sessionID, pieceID: pieceID)],
            sessionProgress: [],
            workImages: [],
            pieceImages: nil,
            inspirationImages: nil,
            bookings: [],
            agreements: [],
            communicationLogs: [],
            payments: [makePaymentBackup(clientID: clientID, pieceID: pieceID)],
            profiles: [],
            customSessionTypes: [],
            customEmailTemplates: [],
            availabilitySlots: [],
            availabilityOverrides: [],
            sessionRateConfigs: [],
            flashPriceTiers: [],
            customGalleryGroups: [],
            customDiscounts: [],
            userDefaults: emptyUserDefaultsBackup()
        )
    }

    /// Backup where every array is empty — should be rejected by `refuseEmptyRestore`.
    static func emptyBackup() -> RecoveryBackup {
        RecoveryBackup(
            version: RecoveryBackup.currentVersion,
            createdAt: referenceDate,
            appVersion: "0.9.0 (9000)",
            clients: [],
            pieces: [],
            sessions: [],
            sessionProgress: [],
            workImages: nil,
            pieceImages: nil,
            inspirationImages: nil,
            bookings: [],
            agreements: [],
            communicationLogs: [],
            payments: [],
            profiles: [],
            customSessionTypes: [],
            customEmailTemplates: [],
            availabilitySlots: [],
            availabilityOverrides: [],
            sessionRateConfigs: [],
            flashPriceTiers: [],
            customGalleryGroups: [],
            customDiscounts: nil,
            userDefaults: emptyUserDefaultsBackup()
        )
    }

    /// Backup whose `version` field is set to a future value — should trigger `versionMismatch`.
    static func futureVersionBackup() -> RecoveryBackup {
        RecoveryBackup(
            version: 99,
            createdAt: referenceDate,
            appVersion: "99.0.0",
            clients: [makeClientBackup()],
            pieces: [],
            sessions: [],
            sessionProgress: [],
            workImages: [],
            pieceImages: nil,
            inspirationImages: nil,
            bookings: [],
            agreements: [],
            communicationLogs: [],
            payments: [],
            profiles: [],
            customSessionTypes: [],
            customEmailTemplates: [],
            availabilitySlots: [],
            availabilityOverrides: [],
            sessionRateConfigs: [],
            flashPriceTiers: [],
            customGalleryGroups: [],
            customDiscounts: [],
            userDefaults: emptyUserDefaultsBackup()
        )
    }

    // MARK: - Individual Backup Structs

    static func makeClientBackup(
        id: UUID = UUID(),
        firstName: String = "Alice",
        lastName: String = "Smith",
        email: String = "alice@example.com"
    ) -> ClientBackup {
        ClientBackup(
            backupID: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: "555-0100",
            notes: "",
            pronouns: "she/her",
            birthdate: nil,
            allergyNotes: "",
            streetAddress: "100 Main St",
            city: "Toronto",
            state: "ON",
            zipCode: "M1A 1A1",
            profilePhotoPath: nil,
            emailOptIn: true,
            isFlashPortfolioClient: false,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            isStarred: false,
            isArchived: false,
            isBlacklisted: false,
            blacklistNote: ""
        )
    }

    static func makePieceBackup(
        id: UUID = UUID(),
        clientID: UUID? = nil,
        title: String = "Dragon Sleeve"
    ) -> PieceBackup {
        PieceBackup(
            backupID: id,
            clientBackupID: clientID,
            title: title,
            bodyPlacement: "Left Arm",
            descriptionText: "Full sleeve, blackwork",
            status: "inProgress",
            pieceType: "custom",
            tags: ["blackwork", "dragon"],
            primaryImagePath: nil,
            rating: nil,
            size: nil,
            sizeDimensions: nil,
            hourlyRate: 150,
            flatRate: nil,
            depositAmount: 100,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            completedAt: nil
        )
    }

    static func makeSessionBackup(
        id: UUID = UUID(),
        pieceID: UUID? = nil
    ) -> SessionBackup {
        SessionBackup(
            backupID: id,
            pieceBackupID: pieceID,
            date: referenceDate,
            startTime: referenceDate,
            endTime: referenceDate.addingTimeInterval(3600),
            breakMinutes: 0,
            sessionType: "tattoo",
            hourlyRateAtTime: 150,
            flashRate: 0,
            manualHoursOverride: nil,
            isNoShow: false,
            noShowFee: nil,
            notes: "",
            eventTags: []
        )
    }

    static func makePaymentBackup(
        clientID: UUID? = nil,
        pieceID: UUID? = nil
    ) -> PaymentBackup {
        PaymentBackup(
            backupID: UUID(),
            clientBackupID: clientID,
            pieceBackupID: pieceID,
            amount: 150,
            paymentDate: referenceDate,
            paymentMethod: "cash",
            paymentType: "sessionPayment",
            notes: "",
            createdAt: referenceDate
        )
    }

    // MARK: - UserDefaults

    static func emptyUserDefaultsBackup() -> UserDefaultsBackup {
        UserDefaultsBackup(
            businessLockEnabled: nil,
            businessLockPIN: nil,
            todoDismissedIDs: nil,
            pieceSizeMode: nil,
            dimensionUnit: nil,
            hasSeededDataV2: nil,
            hasSeededPayments: nil,
            hasSeededFlashPortfolio: nil
        )
    }

    // MARK: - JSON Encoding

    static func encode(_ backup: RecoveryBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func makeMetadata(
        for jsonData: Data,
        folderName: String,
        imageCount: Int = 0,
        withChecksum: Bool = true
    ) -> BackupMetadata {
        BackupMetadata(
            id: UUID(),
            createdAt: referenceDate,
            appVersion: "0.9.0 (9000)",
            modelCount: 1,
            imageCount: imageCount,
            jsonSizeBytes: UInt64(jsonData.count),
            imageSizeBytes: 0,
            folderName: folderName,
            jsonChecksum: withChecksum ? RecoveryService.sha256Hex(jsonData) : nil,
            kind: .userBackup
        )
    }

    /// Writes a complete backup folder (backup.json + metadata.json) to `containerURL/{folderName}/`.
    /// Returns the metadata that describes it.
    @discardableResult
    static func writeBackupFolder(
        backup: RecoveryBackup,
        folderName: String,
        containerURL: URL,
        imageCount: Int = 0,
        withChecksum: Bool = true
    ) throws -> BackupMetadata {
        let jsonData = try encode(backup)
        let backupDir = containerURL.appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        try jsonData.write(to: backupDir.appendingPathComponent("backup.json"))

        let metadata = makeMetadata(
            for: jsonData,
            folderName: folderName,
            imageCount: imageCount,
            withChecksum: withChecksum
        )
        let metaEncoder = JSONEncoder()
        metaEncoder.dateEncodingStrategy = .iso8601
        let metaData = try metaEncoder.encode(metadata)
        try metaData.write(to: backupDir.appendingPathComponent("metadata.json"))
        return metadata
    }
}
