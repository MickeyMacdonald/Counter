import XCTest
import SwiftData
@testable import Counter

/// Tests the recovery-mode launch path: the guarantee that a corrupted or
/// missing SwiftData store never crashes the app, but instead routes to
/// RecoveryModeView via LaunchState.recoveryMode.
///
/// Tests use a temporary on-disk store so they never touch the app's real store.
@MainActor
final class LaunchStateTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CounterLaunch_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - Baseline: valid store opens successfully

    func testValidSchema_opensWithoutError() throws {
        // An in-memory container is the simplest proxy for a valid launch path.
        let schema = Schema(versionedSchema: CounterSchemaV4.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        XCTAssertNoThrow(
            try ModelContainer(
                for: schema,
                migrationPlan: CounterMigrationPlan.self,
                configurations: [config]
            )
        )
    }

    func testOnDiskStore_opensAndPersists() throws {
        let storeURL = tempDir.appendingPathComponent("test.store")
        let container = try TestContainerFactory.makeOnDisk(at: storeURL)
        _ = container.mainContext   // force the store file to materialise
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
    }

    // MARK: - Corrupted store triggers failure

    func testCorruptedStore_causesModelContainerToThrow() throws {
        let storeURL = tempDir.appendingPathComponent("corrupt.store")

        // Step 1: create a valid on-disk store and let it initialise fully
        let container = try TestContainerFactory.makeOnDisk(at: storeURL)
        _ = container.mainContext   // write the SQLite header to disk

        // Step 2: overwrite the SQLite magic header with garbage (same technique
        // as RecoveryStoreReset.corruptStoreForTesting)
        let garbage = Data(repeating: 0xFF, count: 128)
        try garbage.write(to: storeURL)

        // Step 3: attempting to re-open the corrupted file must throw
        let schema = Schema(versionedSchema: CounterSchemaV4.self)
        let config = ModelConfiguration(schema: schema, url: storeURL)
        XCTAssertThrowsError(
            try ModelContainer(
                for: schema,
                migrationPlan: CounterMigrationPlan.self,
                configurations: [config]
            ),
            "A corrupted SQLite store must cause ModelContainer init to throw"
        )
    }

    func testCorruptedStore_thrownError_isNotFatal() throws {
        // Mirrors CounterApp.init(): the error should be catchable, not a crash.
        let storeURL = tempDir.appendingPathComponent("corrupt2.store")

        let container = try TestContainerFactory.makeOnDisk(at: storeURL)
        _ = container.mainContext

        let garbage = Data(repeating: 0xFF, count: 128)
        try garbage.write(to: storeURL)

        let schema = Schema(versionedSchema: CounterSchemaV4.self)
        let config = ModelConfiguration(schema: schema, url: storeURL)

        var launchState: CounterApp.LaunchState
        do {
            let c = try ModelContainer(
                for: schema,
                migrationPlan: CounterMigrationPlan.self,
                configurations: [config]
            )
            launchState = .ready(c)
        } catch {
            launchState = .recoveryMode(error)
        }

        if case .recoveryMode = launchState {
            // expected
        } else {
            XCTFail("A corrupted store should produce LaunchState.recoveryMode, not .ready")
        }
    }

    // MARK: - LaunchState enum contracts

    func testLaunchState_ready_holdsContainer() throws {
        let schema = Schema(versionedSchema: CounterSchemaV4.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: CounterMigrationPlan.self,
            configurations: [config]
        )
        let state = CounterApp.LaunchState.ready(container)
        if case .ready(let c) = state {
            XCTAssertNotNil(c)
        } else {
            XCTFail("Expected .ready")
        }
    }

    func testLaunchState_recoveryMode_holdsError() {
        struct TestError: Error {}
        let state = CounterApp.LaunchState.recoveryMode(TestError())
        if case .recoveryMode(let e) = state {
            XCTAssertTrue(e is TestError)
        } else {
            XCTFail("Expected .recoveryMode")
        }
    }

    // MARK: - RecoveryStoreReset helpers

    func testDeleteSwiftDataStore_whenNoStoreExists_throwsNoStoreFound() {
        // In a test sandbox the default.store may not exist — the helper should
        // surface a descriptive error rather than silently doing nothing.
        // NOTE: this test is environment-sensitive; skip it when the production
        // app store IS present (e.g., device running full app).
        guard !FileManager.default.fileExists(
            atPath: applicationSupportURL()
                .appendingPathComponent("default.store").path
        ) else {
            throw XCTSkip("Production store exists — skipping destructive test")
        }

        XCTAssertThrowsError(try RecoveryStoreReset.deleteSwiftDataStore()) { error in
            guard let resetError = error as? RecoveryStoreReset.ResetError else {
                XCTFail("Wrong error type: \(error)")
                return
            }
            XCTAssertEqual(resetError, .noStoreFound)
        }
    }

    // MARK: - Helpers

    private func applicationSupportURL() -> URL {
        (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )) ?? URL(fileURLWithPath: "/dev/null")
    }
}

extension RecoveryStoreReset.ResetError: Equatable {
    public static func == (lhs: RecoveryStoreReset.ResetError, rhs: RecoveryStoreReset.ResetError) -> Bool {
        switch (lhs, rhs) {
        case (.applicationSupportUnavailable, .applicationSupportUnavailable): return true
        case (.noStoreFound, .noStoreFound): return true
        default: return false
        }
    }
}
