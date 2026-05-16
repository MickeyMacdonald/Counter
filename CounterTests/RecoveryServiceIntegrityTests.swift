import XCTest
import SwiftData
@testable import Counter

/// Tests the restore() preflight validation pipeline: every guard that fires
/// BEFORE any destructive action touches the live store.
///
/// Each test writes controlled JSON to a temp directory, sets
/// `testContainerOverride` so RecoveryService reads from that directory,
/// then asserts the correct RecoveryError is thrown.
final class RecoveryServiceIntegrityTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CounterTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        await RecoveryService.shared.testContainerOverride = tempDir
    }

    override func tearDown() async throws {
        await RecoveryService.shared.testContainerOverride = nil
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - SHA-256 helper

    func testSHA256_knownVector_emptyInput() {
        // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        let result = RecoveryService.sha256Hex(Data())
        XCTAssertEqual(result, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testSHA256_knownVector_helloString() {
        // SHA-256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
        let data = "hello".data(using: .utf8)!
        let result = RecoveryService.sha256Hex(data)
        XCTAssertEqual(result, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    func testSHA256_isDeterministic() {
        let data = "counter backup data".data(using: .utf8)!
        XCTAssertEqual(RecoveryService.sha256Hex(data), RecoveryService.sha256Hex(data))
    }

    func testSHA256_differentInputsProduceDifferentHashes() {
        let a = RecoveryService.sha256Hex("hello".data(using: .utf8)!)
        let b = RecoveryService.sha256Hex("world".data(using: .utf8)!)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - restore() — missing backup file

    func testRestore_missingBackupFile_throwsBackupNotFound() async throws {
        let container = try await MainActor.run { try TestContainerFactory.makeInMemory() }
        let context   = await container.mainContext

        // Metadata pointing to a folder that doesn't exist
        let metadata = BackupFixtures.makeMetadata(
            for: Data(),
            folderName: "counter_recovery_nonexistent",
            withChecksum: false
        )

        await assertThrows(RecoveryError.backupNotFound) {
            try await RecoveryService.shared.restore(from: metadata, context: context)
        }
    }

    // MARK: - restore() — checksum mismatch

    func testRestore_tamperedJSON_throwsChecksumMismatch() async throws {
        let container = try await MainActor.run { try TestContainerFactory.makeInMemory() }
        let context   = await container.mainContext

        // Write a valid backup
        let folderName = "counter_recovery_tampered"
        let backup = BackupFixtures.minimalBackup()
        let originalJSON = try BackupFixtures.encode(backup)

        // Write metadata with the correct checksum of the ORIGINAL JSON
        let metadata = BackupFixtures.makeMetadata(
            for: originalJSON,
            folderName: folderName,
            withChecksum: true
        )
        let backupDir = tempDir.appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        // Write TAMPERED JSON (append a space)
        let tamperedJSON = originalJSON + " ".data(using: .utf8)!
        try tamperedJSON.write(to: backupDir.appendingPathComponent("backup.json"))

        let metaEncoder = JSONEncoder()
        metaEncoder.dateEncodingStrategy = .iso8601
        try metaEncoder.encode(metadata)
            .write(to: backupDir.appendingPathComponent("metadata.json"))

        do {
            try await RecoveryService.shared.restore(from: metadata, context: context)
            XCTFail("Expected checksumMismatch error")
        } catch RecoveryError.checksumMismatch {
            // expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - restore() — wrong version

    func testRestore_futureVersion_throwsVersionMismatch() async throws {
        let container = try await MainActor.run { try TestContainerFactory.makeInMemory() }
        let context   = await container.mainContext

        let folderName = "counter_recovery_version99"
        let backup = BackupFixtures.futureVersionBackup()
        let metadata = try BackupFixtures.writeBackupFolder(
            backup: backup,
            folderName: folderName,
            containerURL: tempDir,
            withChecksum: true
        )

        do {
            try await RecoveryService.shared.restore(from: metadata, context: context)
            XCTFail("Expected versionMismatch error")
        } catch RecoveryError.versionMismatch(let found, let expected) {
            XCTAssertEqual(found, 99)
            XCTAssertEqual(expected, RecoveryBackup.currentVersion)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - restore() — empty backup

    func testRestore_emptyBackup_throwsRefuseEmptyRestore() async throws {
        let container = try await MainActor.run { try TestContainerFactory.makeInMemory() }
        let context   = await container.mainContext

        let folderName = "counter_recovery_empty"
        let backup = BackupFixtures.emptyBackup()
        let metadata = try BackupFixtures.writeBackupFolder(
            backup: backup,
            folderName: folderName,
            containerURL: tempDir,
            withChecksum: true
        )

        await assertThrows(RecoveryError.refuseEmptyRestore) {
            try await RecoveryService.shared.restore(from: metadata, context: context)
        }
    }

    // MARK: - restore() — corrupted JSON

    func testRestore_corruptedJSON_throwsDeserializationFailed() async throws {
        let container = try await MainActor.run { try TestContainerFactory.makeInMemory() }
        let context   = await container.mainContext

        let folderName = "counter_recovery_corrupt"
        let backupDir  = tempDir.appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        // Write garbage bytes
        let garbage = Data(repeating: 0xFF, count: 256)
        try garbage.write(to: backupDir.appendingPathComponent("backup.json"))

        // Metadata with NO checksum so the integrity check is skipped
        // and we hit the JSON decode step
        let metadata = BackupFixtures.makeMetadata(
            for: garbage,
            folderName: folderName,
            withChecksum: false
        )
        let metaEncoder = JSONEncoder()
        metaEncoder.dateEncodingStrategy = .iso8601
        try metaEncoder.encode(metadata)
            .write(to: backupDir.appendingPathComponent("metadata.json"))

        do {
            try await RecoveryService.shared.restore(from: metadata, context: context)
            XCTFail("Expected deserializationFailed error")
        } catch RecoveryError.deserializationFailed {
            // expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - restore() — image count mismatch (Images folder missing)

    func testRestore_imagesFolderMissing_throwsImageCountMismatch() async throws {
        let container = try await MainActor.run { try TestContainerFactory.makeInMemory() }
        let context   = await container.mainContext

        let folderName = "counter_recovery_noimages"

        // Write a valid backup with 1 client so the empty-check passes
        var metadata = try BackupFixtures.writeBackupFolder(
            backup: BackupFixtures.minimalBackup(),
            folderName: folderName,
            containerURL: tempDir,
            imageCount: 0,     // start with 0
            withChecksum: true
        )

        // Rebuild metadata claiming 3 images (but the Images folder doesn't exist)
        metadata = BackupMetadata(
            id: metadata.id,
            createdAt: metadata.createdAt,
            appVersion: metadata.appVersion,
            modelCount: metadata.modelCount,
            imageCount: 3,             // claim 3 images
            jsonSizeBytes: metadata.jsonSizeBytes,
            imageSizeBytes: 0,
            folderName: folderName,
            jsonChecksum: metadata.jsonChecksum,
            kind: .userBackup
        )
        // Overwrite metadata.json with the updated claim
        let metaEncoder = JSONEncoder()
        metaEncoder.dateEncodingStrategy = .iso8601
        let metaData = try metaEncoder.encode(metadata)
        let backupDir = tempDir.appendingPathComponent(folderName)
        try metaData.write(to: backupDir.appendingPathComponent("metadata.json"))

        do {
            try await RecoveryService.shared.restore(from: metadata, context: context)
            XCTFail("Expected imageCountMismatch error")
        } catch RecoveryError.imageCountMismatch(let expected, let actual) {
            XCTAssertEqual(expected, 3)
            XCTAssertEqual(actual, 0)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - restore() — truncated JSON

    func testRestore_truncatedJSON_throwsDeserializationFailed() async throws {
        let container = try await MainActor.run { try TestContainerFactory.makeInMemory() }
        let context   = await container.mainContext

        let folderName = "counter_recovery_truncated"
        let backupDir  = tempDir.appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        // Write a partial JSON string (cut off mid-object)
        let partial = """
        {
          "version": 1,
          "createdAt": "2024-10-09T00:00:00Z",
          "appVersion": "0.9.0",
          "clients": [
        """.data(using: .utf8)!
        try partial.write(to: backupDir.appendingPathComponent("backup.json"))

        let metadata = BackupFixtures.makeMetadata(
            for: partial,
            folderName: folderName,
            withChecksum: false
        )
        let metaEncoder = JSONEncoder()
        metaEncoder.dateEncodingStrategy = .iso8601
        try metaEncoder.encode(metadata)
            .write(to: backupDir.appendingPathComponent("metadata.json"))

        do {
            try await RecoveryService.shared.restore(from: metadata, context: context)
            XCTFail("Expected deserializationFailed error")
        } catch RecoveryError.deserializationFailed {
            // expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}

// MARK: - Assertion helpers

extension XCTestCase {
    /// Asserts that the async throwing closure throws a specific `RecoveryError` case.
    /// Uses pattern-matching so associated values don't need to be specified.
    func assertThrows<E: Error>(
        _ expected: E,
        _ block: () async throws -> Void,
        file: StaticString = #file,
        line: UInt = #line
    ) async where E: Equatable {
        do {
            try await block()
            XCTFail("Expected \(expected) to be thrown", file: file, line: line)
        } catch let e as E where e == expected {
            // pass
        } catch {
            XCTFail("Wrong error: \(error)", file: file, line: line)
        }
    }
}

extension RecoveryError: Equatable {
    public static func == (lhs: RecoveryError, rhs: RecoveryError) -> Bool {
        switch (lhs, rhs) {
        case (.backupNotFound, .backupNotFound):             return true
        case (.refuseEmptyRestore, .refuseEmptyRestore):    return true
        case (.serializationFailed, .serializationFailed):  return true
        case (.deserializationFailed, .deserializationFailed): return true
        case (.imageCopyFailed, .imageCopyFailed):          return true
        case (.restoreFailed, .restoreFailed):              return true
        case (.versionMismatch, .versionMismatch):          return true
        case (.checksumMismatch, .checksumMismatch):        return true
        case (.imageCountMismatch, .imageCountMismatch):    return true
        case (.preRestoreSnapshotFailed, .preRestoreSnapshotFailed): return true
        default: return false
        }
    }
}
