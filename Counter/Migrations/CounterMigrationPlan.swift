//
//  CounterMigrationPlan.swift
//  Counter
//
//  The single SchemaMigrationPlan for Counter. Lists every shipped
//  `VersionedSchema` in chronological order and the `MigrationStage`s
//  that move data between them.
//
//  Today this only knows about V1 and has zero stages — V1 is the
//  baseline, so there is nothing to migrate from. The first real stage
//  will land when the `Drafting → initialDrafting` and
//  `piece.imageGroups` shims are formalized as a V1 → V2 migration in
//  `0.9.0-beta` (see `docs/internal/VERSION_HISTORY.md`).
//
//  When that happens, append `CounterSchemaV2.self` to `schemas` and
//  add a `MigrationStage.custom(...)` entry to `stages`. Do not reorder
//  or remove existing entries — once a version has shipped, its
//  position in this plan is permanent.
//
//  See `docs/internal/VERSIONING.md` for the Migration Safety Rule.
//

import Foundation
import SwiftData

enum CounterMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            CounterSchemaV1.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            // No stages yet. V1 is the baseline.
            //
            // When V2 lands, add stages here in order, e.g.:
            //
            // .custom(
            //     fromVersion: CounterSchemaV1.self,
            //     toVersion:   CounterSchemaV2.self,
            //     willMigrate: { context in
            //         // pre-migration auto-backup goes here
            //     },
            //     didMigrate: { context in
            //         // post-migration verification goes here
            //     }
            // )
        ]
    }
}
