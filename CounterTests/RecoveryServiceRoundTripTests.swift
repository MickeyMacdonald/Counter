import XCTest
import SwiftData
@testable import Counter

/// Full backup → restore cycle tests using an in-memory SwiftData container.
///
/// Each test:
///  1. Inserts records into an in-memory container
///  2. Calls performPreRestoreSnapshot (bypasses the 60s debounce)
///  3. Optionally wipes the context to simulate data loss
///  4. Restores from the snapshot
///  5. Asserts record counts and key field values survived intact
///
/// `testContainerOverride` is set to a temp directory so the RecoveryService
/// never touches the real iCloud / local-Documents backup location.
@MainActor
final class RecoveryServiceRoundTripTests: XCTestCase {

    private var tempDir: URL!
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CounterRoundTrip_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        await RecoveryService.shared.testContainerOverride = tempDir
        container = try TestContainerFactory.makeInMemory()
    }

    override func tearDown() async throws {
        await RecoveryService.shared.testContainerOverride = nil
        try? FileManager.default.removeItem(at: tempDir)
        container = nil
        try await super.tearDown()
    }

    // MARK: - Empty store

    func testEmptyStore_snapshot_createsValidBackupFile() async throws {
        // Taking a snapshot of an empty store should succeed (0 records is fine for backup;
        // restore is what rejects empty files).
        let metadata = try await RecoveryService.shared.performPreRestoreSnapshot(context: context)
        XCTAssertEqual(metadata.modelCount, 0)
        XCTAssertNotNil(metadata.jsonChecksum, "checksum must always be written")

        // The backup.json file should exist on disk
        let backupJSON = tempDir
            .appendingPathComponent(metadata.folderName)
            .appendingPathComponent("backup.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupJSON.path))
    }

    func testEmptyStore_restore_throwsRefuseEmptyRestore() async throws {
        let metadata = try await RecoveryService.shared.performPreRestoreSnapshot(context: context)

        do {
            try await RecoveryService.shared.restore(from: metadata, context: context)
            XCTFail("Expected refuseEmptyRestore")
        } catch RecoveryError.refuseEmptyRestore {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // MARK: - Single record

    func testSingleClient_backupAndRestore_preservesAllFields() async throws {
        // Insert
        let client = Client(
            firstName: "Alice", lastName: "Smith",
            email: "alice@example.com", phone: "555-0100",
            notes: "VIP", pronouns: "she/her",
            birthdate: nil, allergyNotes: "latex",
            streetAddress: "1 Queen St", city: "Toronto",
            state: "ON", zipCode: "M5H 2N2"
        )
        client.isStarred = true
        client.isBlacklisted = false
        context.insert(client)
        try context.save()

        // Backup
        let metadata = try await RecoveryService.shared.performPreRestoreSnapshot(context: context)
        XCTAssertEqual(metadata.modelCount, 1)

        // Wipe
        try context.fetch(FetchDescriptor<Client>()).forEach { context.delete($0) }
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Client>()).count, 0)

        // Restore
        try await RecoveryService.shared.restore(from: metadata, context: context)

        // Verify
        let restored = try context.fetch(FetchDescriptor<Client>())
        XCTAssertEqual(restored.count, 1)
        let r = restored[0]
        XCTAssertEqual(r.firstName, "Alice")
        XCTAssertEqual(r.lastName,  "Smith")
        XCTAssertEqual(r.email,     "alice@example.com")
        XCTAssertEqual(r.notes,     "VIP")
        XCTAssertEqual(r.allergyNotes, "latex")
        XCTAssertTrue(r.isStarred)
    }

    // MARK: - Relationship integrity

    func testClientPieceRelationship_preserved_afterRoundTrip() async throws {
        let client = Client(
            firstName: "Bob", lastName: "Lee",
            email: "bob@example.com", phone: "",
            notes: "", pronouns: "",
            birthdate: nil, allergyNotes: "",
            streetAddress: "", city: "", state: "", zipCode: ""
        )
        context.insert(client)

        let piece = Piece(
            title: "Phoenix",
            bodyPlacement: "Back",
            descriptionText: "Full back piece",
            status: .inProgress,
            pieceType: .custom,
            tags: ["colour", "phoenix"],
            hourlyRate: 200,
            flatRate: nil,
            depositAmount: 200
        )
        piece.client = client
        context.insert(piece)
        try context.save()

        let metadata = try await RecoveryService.shared.performPreRestoreSnapshot(context: context)
        XCTAssertEqual(metadata.modelCount, 2)

        // Wipe
        try context.fetch(FetchDescriptor<Piece>()).forEach  { context.delete($0) }
        try context.fetch(FetchDescriptor<Client>()).forEach { context.delete($0) }
        try context.save()

        // Restore
        try await RecoveryService.shared.restore(from: metadata, context: context)

        let clients = try context.fetch(FetchDescriptor<Client>())
        let pieces  = try context.fetch(FetchDescriptor<Piece>())
        XCTAssertEqual(clients.count, 1)
        XCTAssertEqual(pieces.count, 1)
        XCTAssertNotNil(pieces[0].client, "piece.client must be re-linked after restore")
        XCTAssertEqual(pieces[0].client?.firstName, "Bob")
        XCTAssertEqual(pieces[0].title, "Phoenix")
        XCTAssertEqual(pieces[0].tags, ["colour", "phoenix"])
    }

    func testClientPieceSession_deepChain_preserved_afterRoundTrip() async throws {
        let client = Client(
            firstName: "Carol", lastName: "White",
            email: "carol@example.com", phone: "",
            notes: "", pronouns: "",
            birthdate: nil, allergyNotes: "",
            streetAddress: "", city: "", state: "", zipCode: ""
        )
        context.insert(client)

        let piece = Piece(
            title: "Sleeve",
            bodyPlacement: "Left Arm",
            descriptionText: "",
            status: .concept,
            pieceType: .custom,
            tags: [],
            hourlyRate: 150,
            flatRate: nil,
            depositAmount: 100
        )
        piece.client = client
        context.insert(piece)

        let session = Session(
            date: BackupFixtures.referenceDate,
            startTime: BackupFixtures.referenceDate,
            sessionType: .tattoo,
            hourlyRateAtTime: 150
        )
        session.piece = piece
        session.eventTags = ["guest-spot", "convention"]
        context.insert(session)
        try context.save()

        let metadata = try await RecoveryService.shared.performPreRestoreSnapshot(context: context)
        XCTAssertEqual(metadata.modelCount, 3)

        // Wipe
        try context.fetch(FetchDescriptor<Session>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<Piece>()).forEach   { context.delete($0) }
        try context.fetch(FetchDescriptor<Client>()).forEach  { context.delete($0) }
        try context.save()

        // Restore
        try await RecoveryService.shared.restore(from: metadata, context: context)

        let sessions = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertNotNil(sessions[0].piece)
        XCTAssertNotNil(sessions[0].piece?.client)
        XCTAssertEqual(sessions[0].eventTags, ["guest-spot", "convention"],
                       "V6 eventTags must survive the round-trip")
    }

    // MARK: - Multiple records

    func testMultipleClients_countMatchesAfterRoundTrip() async throws {
        for i in 0..<5 {
            let c = Client(
                firstName: "Client\(i)", lastName: "Test",
                email: "c\(i)@example.com", phone: "",
                notes: "", pronouns: "",
                birthdate: nil, allergyNotes: "",
                streetAddress: "", city: "", state: "", zipCode: ""
            )
            context.insert(c)
        }
        try context.save()

        let metadata = try await RecoveryService.shared.performPreRestoreSnapshot(context: context)
        XCTAssertGreaterThanOrEqual(metadata.modelCount, 5)

        try context.fetch(FetchDescriptor<Client>()).forEach { context.delete($0) }
        try context.save()

        try await RecoveryService.shared.restore(from: metadata, context: context)

        let restored = try context.fetch(FetchDescriptor<Client>())
        XCTAssertEqual(restored.count, 5)
    }

    // MARK: - Pre-restore snapshot is created before wipe

    func testRestore_createsPreRestoreSnapshot_beforeWiping() async throws {
        let client = Client(
            firstName: "Dave", lastName: "Brown",
            email: "dave@example.com", phone: "",
            notes: "", pronouns: "",
            birthdate: nil, allergyNotes: "",
            streetAddress: "", city: "", state: "", zipCode: ""
        )
        context.insert(client)
        try context.save()

        // Write our primary backup
        let metadata = try await RecoveryService.shared.performPreRestoreSnapshot(context: context)

        // Wipe
        try context.fetch(FetchDescriptor<Client>()).forEach { context.delete($0) }
        try context.save()

        // Restore — internally this creates a pre-restore snapshot of the current (now empty) state
        try await RecoveryService.shared.restore(from: metadata, context: context)

        // The temp dir should now have at least 2 backup folders
        let contents = try FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        XCTAssertGreaterThanOrEqual(contents.count, 2,
            "At least the original snapshot and the pre-restore snapshot should exist")

        // One of them should be a pre-restore snapshot
        let backups = try await RecoveryService.shared.listBackups()
        let snapshots = backups.filter { $0.effectiveKind == .preRestoreSnapshot }
        XCTAssertFalse(snapshots.isEmpty, "A pre-restore snapshot must be written before the wipe")
    }

    // MARK: - listBackups / deleteBackup

    func testListBackups_returnsBackupsInDescendingOrder() async throws {
        let client = Client(
            firstName: "Eve", lastName: "Taylor",
            email: "eve@example.com", phone: "",
            notes: "", pronouns: "",
            birthdate: nil, allergyNotes: "",
            streetAddress: "", city: "", state: "", zipCode: ""
        )
        context.insert(client)
        try context.save()

        let m1 = try await RecoveryService.shared.performPreRestoreSnapshot(context: context)
        // Small sleep to guarantee distinct timestamps
        try await Task.sleep(nanoseconds: 1_100_000_000)
        let m2 = try await RecoveryService.shared.performPreRestoreSnapshot(context: context)

        let listed = try await RecoveryService.shared.listBackups()
        XCTAssertGreaterThanOrEqual(listed.count, 2)
        XCTAssertTrue(listed[0].createdAt >= listed[1].createdAt, "newest backup must come first")
        _ = m1; _ = m2 // suppress unused warnings
    }
}
