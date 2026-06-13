import SwiftData
@testable import Counter

enum TestContainerFactory {

    /// An in-memory SwiftData container running the full V4 schema + migration plan.
    /// Safe to call from multiple tests — each call returns an independent container.
    @MainActor
    static func makeInMemory() throws -> ModelContainer {
        let schema = Schema(versionedSchema: CounterSchemaV4.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: CounterMigrationPlan.self,
            configurations: [config]
        )
    }

    /// An on-disk container written to `url`. The caller is responsible for
    /// deleting the file after use.
    @MainActor
    static func makeOnDisk(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: CounterSchemaV4.self)
        let config = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(
            for: schema,
            migrationPlan: CounterMigrationPlan.self,
            configurations: [config]
        )
    }
}
