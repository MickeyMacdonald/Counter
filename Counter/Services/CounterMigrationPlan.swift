//
//  CounterMigrationPlan.swift
//  Counter
//
//  The single SchemaMigrationPlan for Counter. Lists every shipped
//  `VersionedSchema` in chronological order and the `MigrationStage`s
//  that move data between them.
//
//  ## Current state
//
//  - V1: the Alpha 0.8 baseline. 18 models.
//  - V2: V1 + `Discount`. Additive-only. Lands in 0.8.x.
//
//  ## V1 → V2 is `.lightweight` — and that is a load-bearing decision
//
//  V1 → V2 adds `Discount` as a new entity. No existing model
//  changes, no relationship changes, no transformations. SwiftData
//  handles this case via lightweight migration: it sees the new entity
//  in the V2 schema, creates the corresponding table, and moves on
//  without touching any existing rows.
//
//  Because the migration cannot transform existing data (it only adds
//  an empty new table), the failure modes are:
//
//    1. SwiftData accepts the V2 schema and the migration completes
//       silently. This is the expected path.
//    2. SwiftData rejects the V2 schema for some unrelated reason and
//       the `ModelContainer` init throws. `CounterApp.swift` catches
//       this and routes to `RecoveryModeView` per the 0.8.x foundation
//       slice. No data has been touched at this point.
//
//  There is no third path where the migration runs partially and
//  corrupts existing data, so the willMigrate auto-backup hook is NOT
//  required for THIS stage. The user's last automatic backup (taken on
//  the prior V1 launch) is still present in `Counter Recovery/` and
//  remains the safety net of last resort.
//
//  ## The next migration MUST add the willMigrate hook
//
//  The next stage to land — currently planned as the formal
//  `Drafting → initialDrafting` consolidation and the `piece.sessionProgress`
//  cleanup — is a **transforming** migration. It rewrites existing
//  rows. That stage MUST be `.custom` and MUST take a fresh backup in
//  `willMigrate` before any rows are touched. See the commented
//  template at the bottom of this file for the shape.
//
//  ## Append-only — once a version ships, its position is permanent
//
//  Do NOT reorder, remove, or edit existing entries in `schemas` or
//  `stages`. Adding a new version means appending to both. See
//  `docs/internal/VERSIONING.md` for the Migration Safety Rule that
//  this file is the load-bearing implementation of.
//

import Foundation
import SwiftData

enum CounterMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            CounterSchemaV1.self,
            CounterSchemaV2.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            // V1 → V2: additive. Adds `Discount` as a new entity.
            // Lightweight is correct here because no existing rows are
            // transformed. See the long comment at the top of this file
            // for why the willMigrate auto-backup hook is intentionally
            // NOT on this stage.
            .lightweight(
                fromVersion: CounterSchemaV1.self,
                toVersion: CounterSchemaV2.self
            )

            // Template for the next stage (the first transforming
            // migration), kept here as a reminder. When this gets
            // uncommented and pointed at V3, the willMigrate closure
            // is the load-bearing piece — it MUST succeed or the
            // migration must abort.
            //
            // .custom(
            //     fromVersion: CounterSchemaV2.self,
            //     toVersion:   CounterSchemaV3.self,
            //     willMigrate: { context in
            //         // Take a fresh backup of the V2 state BEFORE
            //         // any rows are transformed. If this throws,
            //         // throw out of willMigrate so SwiftData aborts
            //         // the migration entirely. Do NOT swallow the
            //         // error — a corrupt half-migration with no
            //         // backup is the worst possible outcome.
            //         //
            //         // Implementation note: `RecoveryService.shared`
            //         // is an actor and `performBackup` is async, so
            //         // wrapping in a semaphore or hop-to-main is
            //         // required since willMigrate is sync.
            //     },
            //     didMigrate: { context in
            //         // Post-migration verification goes here. Sanity
            //         // checks, count comparisons, anything that can
            //         // detect a partial migration.
            //     }
            // )
        ]
    }
}
