import Foundation
import SwiftData

enum CounterSchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)

    // Same model set as V5. V6 adds eventTags: [String] to Session —
    // a new column with default [], no row transforms needed.
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
