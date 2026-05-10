import Foundation
import SwiftData

enum CounterSchemaV8: VersionedSchema {
    static var versionIdentifier = Schema.Version(8, 0, 0)

    // Same model set as V7. V8 adds `notificationID: UUID` to Booking so
    // the notification service has a stable, addressable string ID for each
    // booking's scheduled UNNotificationRequests — independent of SwiftData's
    // internal PersistentIdentifier type.
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
