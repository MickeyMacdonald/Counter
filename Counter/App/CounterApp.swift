import SwiftUI
import SwiftData

@main
struct CounterApp: App {
    /// Result of trying to open the SwiftData store at launch.
    ///
    /// We deliberately do NOT call `fatalError` when the container fails
    /// to open. A bricked launch on a real artist's iPad — with real
    /// client data on disk — is the single worst trust event Counter can
    /// have. Instead, we capture the error and route the user to
    /// `RecoveryModeView`, which can list backups, surface the error, and
    /// offer a guided reset → relaunch → restore loop.
    ///
    /// See `docs/internal/VERSIONING.md` (Migration Safety Rule) and
    /// `docs/internal/VERSION_HISTORY.md` (0.8.x section).
    enum LaunchState {
        case ready(ModelContainer)
        case recoveryMode(Error)
    }

    let launchState: LaunchState
    @State private var lockManager = BusinessLockManager()

    init() {
        do {
            // V1 is a no-op wrapper around the existing 18-model schema.
            // It exists so future schema changes can ship as
            // `MigrationStage`s in `CounterMigrationPlan` instead of
            // relying on SwiftData's silent lightweight migration.
            let schema = Schema(versionedSchema: CounterSchemaV1.self)
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: CounterMigrationPlan.self,
                configurations: [config]
            )
            launchState = .ready(container)
        } catch {
            launchState = .recoveryMode(error)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch launchState {
            case .ready(let container):
                ContentView()
                    .environment(lockManager)
                    .onAppear {
                        SeedDataService.seedIfNeeded(context: container.mainContext)
                    }
                    .modelContainer(container)
            case .recoveryMode(let error):
                RecoveryModeView(launchError: error)
            }
        }
    }
}
