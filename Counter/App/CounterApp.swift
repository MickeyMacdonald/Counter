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
            // V2 adds `CustomDiscount` to the schema. The V1 → V2 jump
            // is a lightweight migration declared in
            // `CounterMigrationPlan`. For users on V1, SwiftData will
            // create the new `CustomDiscount` table on first launch
            // and leave every other row untouched. For fresh
            // installs, V2 is the starting schema.
            let schema = Schema(versionedSchema: CounterSchemaV2.self)
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
