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
//  - V1: the 0.8.0 baseline. 16 models (no Discount, no WorkImage).
//  - V2: V1 + `Discount`. Additive-only.
//  - V3: WorkImage added (PieceImage never shipped in live stores).
//  - V4: V3 + `BookingTaskTemplate`. Current `VersionedSchema` cap.
//
//  Additive model changes after V4 (client flags, session event tags,
//  booking cascade, notificationID) live on the `@Model` classes with
//  inline defaults and are migrated automatically by SwiftData — they
//  must NOT get new `VersionedSchema` entries with the same model list,
//  or SwiftData throws "Duplicate version checksums detected" at launch.
//
//  ## The next transforming migration MUST add the willMigrate hook
//
//  Any stage that rewrites existing rows MUST be `.custom` and MUST
//  call `RecoveryService.shared.performBackup` in `willMigrate` before
//  any rows are touched.
//
//  ## Append-only — once a version ships, its position is permanent
//
//  Do NOT reorder, remove, or edit existing entries in `schemas` or
//  `stages`. Adding a new version means appending to both — but only
//  when the schema checksum actually changes (new model type, or
//  version-specific nested models). See `docs/internal/VERSIONING.md`.
//

import Foundation
import SwiftData

enum CounterMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            CounterSchemaV1.self,
            CounterSchemaV2.self,
            CounterSchemaV3.self,
            CounterSchemaV4.self
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

            // V2 → V3: WorkImage table added.
            // No PieceImage records exist in any live store (shipped pre-App Store),
            // so lightweight is safe.
            .lightweight(
                fromVersion: CounterSchemaV2.self,
                toVersion: CounterSchemaV3.self
            ),

            // V3 → V4: additive. Adds `BookingTaskTemplate` as a new entity.
            // Lightweight is correct: no existing rows are transformed.
            .lightweight(
                fromVersion: CounterSchemaV3.self,
                toVersion: CounterSchemaV4.self
            )
        ]
    }
}
