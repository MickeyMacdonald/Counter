import Foundation
import SwiftData

enum CounterSchemaV7: VersionedSchema {
    static var versionIdentifier = Schema.Version(7, 0, 0)

    // Same model set as V6. V7 adds an explicit cascade relationship from
    // Client → Booking so that deleting a client also deletes their bookings.
    // Without this, bookings were left with a nullified client reference and
    // could cause crashes when the Sessions list accessed the pending-deletion
    // client object before the context saved.
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
