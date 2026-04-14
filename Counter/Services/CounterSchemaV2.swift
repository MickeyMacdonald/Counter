//
//  CounterSchemaV2.swift
//  Counter
//
//  V2 of Counter's persisted schema. The only difference from V1 is the
//  formal addition of `CustomDiscount`, which existed as a `@Model` file
//  under `Counter/Models/` since 0.7 but was never registered in the
//  schema. The view layer (`SettingsViewFinancial`) was already inserting
//  and querying `CustomDiscount` records, which meant pre-V2 the data was
//  living in an undefined corner of SwiftData — possibly persisted,
//  possibly ephemeral, definitely never backed up.
//
//  V1 → V2 is therefore an additive-only migration: no existing field
//  changes, no relationship changes, no transformations. SwiftData
//  handles it via `MigrationStage.lightweight` in `CounterMigrationPlan`.
//
//  Why this is a separate VersionedSchema (rather than a silent edit to
//  V1):
//
//    1. Once a `VersionedSchema` ships, its model list is permanent. V1
//       was the first cut — even the omission was permanent the moment
//       the 0.8.x foundation slice landed. Editing V1 now would mean
//       lying about what shipped.
//    2. The Migration Safety Rule (`docs/internal/VERSIONING.md`) says
//       every schema change is a versioned step. "Adding a model that
//       was always supposed to be there" is still a schema change.
//    3. Future migrations (the formal `Drafting → initialDrafting` and
//       `piece.imageGroups` stages) will ride on this same V1 → V2 →
//       V3 → … chain. V2 is the entry point for that chain.
//
//  See `docs/internal/VERSION_HISTORY.md` (0.8.x section) for context.
//

import Foundation
import SwiftData

enum CounterSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            // All 18 V1 models, unchanged. Order matches V1 for diffability.
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
            CustomGalleryGroup.self,
            // New in V2: the model that should have been in V1 from day one.
            CustomDiscount.self
        ]
    }
}
