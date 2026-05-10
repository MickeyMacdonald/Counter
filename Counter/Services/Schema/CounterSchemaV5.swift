import Foundation
import SwiftData

enum CounterSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    // Same model set as V4. V5 adds isStarred, isArchived, isBlacklisted,
    // and blacklistNote to Client — new columns with defaults, no row transforms.
    static var models: [any PersistentModel.Type] {
        [
            Client.self,
            Piece.self,
            SessionProgress.self,
            WorkImage.self,
            Session.self,
            Agreement.self,
            CommunicationLog.self,
            UserProfile.self,
            Booking.self,
            AvailabilitySlot.self,
            Payment.self,
            SavedEmailTemplate.self,
            AvailabilityOverride.self,
            SessionCategory.self,
            FlashPriceTier.self,
            SessionRateConfig.self,
            GalleryGroup.self,
            Discount.self,
            BookingTaskTemplate.self
        ]
    }
}
