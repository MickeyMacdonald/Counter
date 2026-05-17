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
//  - V1: the 0.8.0 baseline. 17 models (no Discount, no PieceImage).
//  - V2: V1 + `Discount`. Additive-only.
//  - V3: PieceImage dropped, WorkImage added. Lightweight (no live PieceImage rows).
//  - V4–V8: additive-only lightweight stages.
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
            CounterSchemaV3.self,
            CounterSchemaV4.self,
            CounterSchemaV5.self,
            CounterSchemaV6.self,
            CounterSchemaV7.self,
            CounterSchemaV8.self
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

            // V2 → V3: PieceImage table dropped, WorkImage table added.
            // No PieceImage records exist in any live store (shipped pre-App Store),
            // so lightweight is safe: SwiftData drops the empty PieceImage table
            // and creates WorkImage without touching any existing rows.
            .lightweight(
                fromVersion: CounterSchemaV2.self,
                toVersion: CounterSchemaV3.self
            ),

            // V3 → V4: additive. Adds `BookingTaskTemplate` as a new entity.
            // Lightweight is correct: no existing rows are transformed.
            .lightweight(
                fromVersion: CounterSchemaV3.self,
                toVersion: CounterSchemaV4.self
            ),

            // V4 → V5: additive. Adds isStarred, isArchived, isBlacklisted, blacklistNote
            // to Client. Lightweight is correct: new columns with defaults, no row transforms.
            .lightweight(
                fromVersion: CounterSchemaV4.self,
                toVersion: CounterSchemaV5.self
            ),

            // V5 → V6: additive. Adds eventTags: [String] to Session.
            // Lightweight is correct: new column with default [], no row transforms.
            .lightweight(
                fromVersion: CounterSchemaV5.self,
                toVersion: CounterSchemaV6.self
            ),

            // V6 → V7: additive. Adds an explicit cascade relationship from
            // Client.bookings → Booking so SwiftData deletes a client's bookings
            // when the client is deleted. Previously Booking.client had the default
            // nullify rule, leaving orphaned booking rows that could fault-crash the
            // Sessions sidebar before the context saved. Lightweight is correct:
            // no new columns — this is a relationship behaviour change only.
            .lightweight(
                fromVersion: CounterSchemaV6.self,
                toVersion: CounterSchemaV7.self
            ),

            // V7 → V8: additive. Adds `notificationID: UUID` to Booking so that
            // NotificationService can address UNNotificationRequests with a stable
            // string ID independent of SwiftData's PersistentIdentifier type.
            // Lightweight is correct: new column with a default UUID(), no row transforms.
            .lightweight(
                fromVersion: CounterSchemaV7.self,
                toVersion: CounterSchemaV8.self
            )
        ]
    }
}
