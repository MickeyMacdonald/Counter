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
            CounterSchemaV2.self,
            CounterSchemaV3.self
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
            ),

            // V2 → V3: PieceImage → WorkImage rename with new fields.
            // This is a custom stage because we're transforming existing
            // rows: every PieceImage record is copied into a new WorkImage
            // record with defaults for the added fields (title, isPortfolio,
            // healingStage, source, client). PieceImage rows are deleted
            // after the copy completes.
            //
            // willMigrate takes a RecoveryService backup BEFORE any rows
            // are touched. If the backup throws, the migration aborts
            // entirely — no partial state, no data loss.
            .custom(
                fromVersion: CounterSchemaV2.self,
                toVersion: CounterSchemaV3.self,
                willMigrate: { context in
                    // Synchronous bridge into the async RecoveryService actor.
                    // SwiftData calls willMigrate on a background thread; we
                    // dispatch-and-wait so the backup completes before any
                    // rows are touched. If this throws, the migration aborts.
                    let semaphore = DispatchSemaphore(value: 0)
                    var backupError: Error?
                    Task {
                        do {
                            try await RecoveryService.shared.performBackup(context: context)
                        } catch {
                            backupError = error
                        }
                        semaphore.signal()
                    }
                    semaphore.wait()
                    if let err = backupError { throw err }
                },
                didMigrate: { context in
                    // Copy every legacy PieceImage into a new WorkImage with
                    // sensible defaults for the new fields.
                    let legacyImages = try context.fetch(FetchDescriptor<PieceImage>())
                    for old in legacyImages {
                        let img = WorkImage(
                            filePath: old.filePath,
                            fileName: old.fileName,
                            notes: old.notes,
                            capturedAt: old.capturedAt,
                            sortOrder: old.sortOrder,
                            isPrimary: old.isPrimary,
                            category: {
                                switch old.category {
                                case .inspiration: return .inspiration
                                case .reference:   return .reference
                                case nil:          return .progress
                                }
                            }(),
                            source: .photoLibrary,
                            tags: old.tags
                        )
                        img.piece = old.piece
                        img.sessionProgress = old.sessionProgress
                        context.insert(img)
                        context.delete(old)
                    }
                    try context.save()
                }
            )
        ]
    }
}
