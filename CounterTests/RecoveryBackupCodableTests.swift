import XCTest
@testable import Counter

/// Tests the JSON encoding / decoding layer for every backup struct.
///
/// These are pure Codable tests — no SwiftData, no file system.
/// They cover:
///   - Full round-trip (encode → decode → fields match)
///   - Backwards compatibility for every schema-version addition that used
///     `decodeIfPresent` to stay readable on old backup files
final class RecoveryBackupCodableTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Full round-trip

    func testFullBackup_encodesAndDecodes_withoutDataLoss() throws {
        let original = BackupFixtures.minimalBackup()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(RecoveryBackup.self, from: data)

        XCTAssertEqual(decoded.version, original.version)
        XCTAssertEqual(decoded.appVersion, original.appVersion)
        XCTAssertEqual(decoded.clients.count, 1)
        XCTAssertEqual(decoded.clients[0].firstName, "Alice")
        XCTAssertEqual(decoded.clients[0].lastName, "Smith")
        XCTAssertEqual(decoded.clients[0].email, "alice@example.com")
    }

    func testRelationalBackup_encodesAndDecodes_preservingIDs() throws {
        let original = BackupFixtures.relationalBackup()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(RecoveryBackup.self, from: data)

        XCTAssertEqual(decoded.clients.count, 1)
        XCTAssertEqual(decoded.pieces.count, 1)
        XCTAssertEqual(decoded.sessions.count, 1)
        XCTAssertEqual(decoded.payments.count, 1)

        let clientID = decoded.clients[0].backupID
        let pieceID  = decoded.pieces[0].backupID
        XCTAssertEqual(decoded.pieces[0].clientBackupID, clientID,
                       "piece should reference the client by backupID")
        XCTAssertEqual(decoded.sessions[0].pieceBackupID, pieceID,
                       "session should reference the piece by backupID")
        XCTAssertEqual(decoded.payments[0].clientBackupID, clientID,
                       "payment should reference the client by backupID")
        XCTAssertEqual(decoded.payments[0].pieceBackupID, pieceID,
                       "payment should reference the piece by backupID")
    }

    func testEmptyBackup_encodesAndDecodes() throws {
        let original = BackupFixtures.emptyBackup()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(RecoveryBackup.self, from: data)

        XCTAssertEqual(decoded.clients.count, 0)
        XCTAssertEqual(decoded.pieces.count, 0)
        XCTAssertNil(decoded.workImages)
        XCTAssertNil(decoded.customDiscounts)
    }

    // MARK: - BackupMetadata backwards compatibility

    func testBackupMetadata_nilJsonChecksum_decodesCleanly() throws {
        let json = """
        {
          "id": "12345678-1234-1234-1234-123456789012",
          "createdAt": "2024-10-09T00:00:00Z",
          "appVersion": "0.8.0 (8000)",
          "modelCount": 5,
          "imageCount": 0,
          "jsonSizeBytes": 1024,
          "imageSizeBytes": 0,
          "folderName": "counter_recovery_2024-10-09_120000"
        }
        """.data(using: .utf8)!

        let meta = try decoder.decode(BackupMetadata.self, from: json)
        XCTAssertNil(meta.jsonChecksum, "pre-checksum backups must decode with nil checksum")
    }

    func testBackupMetadata_nilKind_effectiveKindIsUserBackup() throws {
        let json = """
        {
          "id": "12345678-1234-1234-1234-123456789012",
          "createdAt": "2024-10-09T00:00:00Z",
          "appVersion": "0.8.0 (8000)",
          "modelCount": 5,
          "imageCount": 0,
          "jsonSizeBytes": 1024,
          "imageSizeBytes": 0,
          "folderName": "counter_recovery_2024-10-09_120000"
        }
        """.data(using: .utf8)!

        let meta = try decoder.decode(BackupMetadata.self, from: json)
        XCTAssertNil(meta.kind, "kind field should be absent")
        XCTAssertEqual(meta.effectiveKind, .userBackup,
                       "nil kind must be treated as .userBackup for backwards compat")
    }

    // MARK: - ClientBackup: V5 field defaults (isStarred / isArchived / isBlacklisted)

    func testClientBackup_preV5_missingFlagsDefaultToFalse() throws {
        // A ClientBackup JSON written before the V5 schema bump — no starred/blacklist fields.
        let json = """
        {
          "backupID": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
          "firstName": "Bob",
          "lastName": "Jones",
          "email": "bob@example.com",
          "phone": "555-0200",
          "notes": "",
          "pronouns": "",
          "allergyNotes": "",
          "streetAddress": "",
          "city": "",
          "state": "",
          "zipCode": "",
          "emailOptIn": false,
          "isFlashPortfolioClient": false,
          "createdAt": "2024-10-09T00:00:00Z",
          "updatedAt": "2024-10-09T00:00:00Z"
        }
        """.data(using: .utf8)!

        let backup = try decoder.decode(ClientBackup.self, from: json)
        XCTAssertFalse(backup.isStarred,     "isStarred must default to false on pre-V5 backups")
        XCTAssertFalse(backup.isArchived,    "isArchived must default to false on pre-V5 backups")
        XCTAssertFalse(backup.isBlacklisted, "isBlacklisted must default to false on pre-V5 backups")
        XCTAssertEqual(backup.blacklistNote, "", "blacklistNote must default to empty string")
        XCTAssertEqual(backup.firstName, "Bob")
    }

    func testClientBackup_v5Fields_roundTrip() throws {
        let original = BackupFixtures.makeClientBackup()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ClientBackup.self, from: data)
        XCTAssertEqual(decoded.isStarred, original.isStarred)
        XCTAssertEqual(decoded.isArchived, original.isArchived)
        XCTAssertEqual(decoded.isBlacklisted, original.isBlacklisted)
        XCTAssertEqual(decoded.blacklistNote, original.blacklistNote)
    }

    // MARK: - SessionBackup: V6 field defaults (eventTags)

    func testSessionBackup_preV6_missingEventTagsDefaultsToEmpty() throws {
        let json = """
        {
          "backupID": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
          "date": "2024-10-09T00:00:00Z",
          "startTime": "2024-10-09T10:00:00Z",
          "breakMinutes": 0,
          "sessionType": "tattoo",
          "hourlyRateAtTime": 150,
          "flashRate": 0,
          "isNoShow": false,
          "notes": ""
        }
        """.data(using: .utf8)!

        let backup = try decoder.decode(SessionBackup.self, from: json)
        XCTAssertEqual(backup.eventTags, [], "eventTags must default to [] on pre-V6 backups")
        XCTAssertEqual(backup.sessionType, "tattoo")
    }

    func testSessionBackup_eventTags_roundTrip() throws {
        var original = BackupFixtures.makeSessionBackup()
        // Re-create with eventTags populated
        original = SessionBackup(
            backupID: original.backupID,
            pieceBackupID: original.pieceBackupID,
            date: original.date,
            startTime: original.startTime,
            endTime: original.endTime,
            breakMinutes: original.breakMinutes,
            sessionType: original.sessionType,
            hourlyRateAtTime: original.hourlyRateAtTime,
            flashRate: original.flashRate,
            manualHoursOverride: original.manualHoursOverride,
            isNoShow: original.isNoShow,
            noShowFee: original.noShowFee,
            notes: original.notes,
            eventTags: ["convention", "guest-spot"]
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SessionBackup.self, from: data)
        XCTAssertEqual(decoded.eventTags, ["convention", "guest-spot"])
    }

    // MARK: - RecoveryBackup: V2 optional customDiscounts

    func testRecoveryBackup_preV2_missingCustomDiscountsDecodesAsNil() throws {
        // Build a full valid backup JSON and strip the customDiscounts key to simulate a pre-V2 file.
        let backup = BackupFixtures.minimalBackup()
        var dict = try JSONSerialization.jsonObject(with: try encoder.encode(backup)) as! [String: Any]
        dict.removeValue(forKey: "customDiscounts")
        let strippedData = try JSONSerialization.data(withJSONObject: dict)

        let decoded = try decoder.decode(RecoveryBackup.self, from: strippedData)
        XCTAssertNil(decoded.customDiscounts,
                     "pre-V2 backups without customDiscounts must decode with nil, not an error")
    }

    // MARK: - RecoveryBackup: V3 optional workImages / legacy pieceImages

    func testRecoveryBackup_preV3_pieceImagesFieldDecodesCleanly() throws {
        let backup = BackupFixtures.minimalBackup()
        var dict = try JSONSerialization.jsonObject(with: try encoder.encode(backup)) as! [String: Any]
        // Remove workImages and inject a legacy pieceImages array
        dict.removeValue(forKey: "workImages")
        dict["pieceImages"] = [[
            "backupID": "cccccccc-cccc-cccc-cccc-cccccccccccc",
            "filePath": "CounterImages/foo.jpg",
            "fileName": "foo.jpg",
            "notes": "",
            "capturedAt": "2024-10-09T00:00:00Z"
        ]]
        let jsonData = try JSONSerialization.data(withJSONObject: dict)

        let decoded = try decoder.decode(RecoveryBackup.self, from: jsonData)
        XCTAssertNil(decoded.workImages, "workImages should be nil for a pre-V3 backup")
        XCTAssertEqual(decoded.pieceImages?.count, 1, "legacy pieceImages should decode")
        XCTAssertEqual(decoded.pieceImages?.first?.fileName, "foo.jpg")
    }

    // MARK: - PieceImageBackup legacy field defaults

    func testPieceImageBackup_legacyFormat_missingFieldsUseDefaults() throws {
        // Very old PieceImageBackup JSON: missing sortOrder, isPrimary, category, tags
        let json = """
        {
          "backupID": "dddddddd-dddd-dddd-dddd-dddddddddddd",
          "filePath": "CounterImages/old.jpg",
          "fileName": "old.jpg",
          "notes": "old note",
          "capturedAt": "2024-10-09T00:00:00Z"
        }
        """.data(using: .utf8)!

        let backup = try decoder.decode(PieceImageBackup.self, from: json)
        XCTAssertEqual(backup.sortOrder, 0,     "sortOrder must default to 0")
        XCTAssertFalse(backup.isPrimary,        "isPrimary must default to false")
        XCTAssertNil(backup.category,           "category must default to nil")
        XCTAssertEqual(backup.tags, [],         "tags must default to []")
        XCTAssertEqual(backup.notes, "old note")
    }

    // MARK: - RecoveryError descriptions

    func testRecoveryErrors_allHaveNonEmptyDescriptions() {
        let errors: [RecoveryError] = [
            .serializationFailed("test"),
            .deserializationFailed("test"),
            .backupNotFound,
            .imageCopyFailed("test"),
            .restoreFailed("test"),
            .versionMismatch(found: 2, expected: 1),
            .checksumMismatch(expected: "abc", actual: "def"),
            .refuseEmptyRestore,
            .imageCountMismatch(expected: 3, actual: 1),
            .preRestoreSnapshotFailed("test")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) must have a description")
        }
    }
}
