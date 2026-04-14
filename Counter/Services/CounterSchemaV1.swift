//
//  CounterSchemaV1.swift
//  Counter
//
//  The first formally versioned schema for Counter.
//
//  This wraps the existing 18-model schema as a `VersionedSchema` so that
//  future schema changes can be expressed as `MigrationStage`s in
//  `CounterMigrationPlan` instead of being silently lightweight-migrated
//  by SwiftData (or, in the worst case, crashing the app on launch).
//
//  V1 is intentionally a no-op wrapper around what already shipped in
//  Alpha 0.8 — it does not change the on-disk schema. Its purpose is to
//  give every later version a known-good baseline to migrate from.
//
//  See `docs/internal/VERSIONING.md` for the Migration Safety Rule that
//  this file is the foundation of.
//

import Foundation
import SwiftData

enum CounterSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Client.self,
            Piece.self,
            ImageGroup.self,
            PieceImage.self,
            TattooSession.self,
            Agreement.self,
            CommunicationLog.self,
            UserProfile.self,
            Booking.self,
            AvailabilitySlot.self,
            InspirationImage.self,
            Payment.self,
            CustomEmailTemplate.self,
            AvailabilityOverride.self,
            CustomSessionType.self,
            FlashPriceTier.self,
            SessionRateConfig.self,
            CustomGalleryGroup.self
            // NOTE: `CustomDiscount` exists as a model file under Counter/Models/
            // but was never registered in the original schema. Adding it here
            // would itself constitute a schema change. Tracked separately.
        ]
    }
}
