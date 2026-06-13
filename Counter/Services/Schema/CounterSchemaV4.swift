import Foundation
import SwiftData

/// Current `VersionedSchema` cap for Counter.
///
/// V4 is the last formally versioned step. Later additive changes — client
/// status flags (V5), session event tags (V6), booking cascade (V7),
/// booking notificationID (V8) — are on the live `@Model` classes with
/// inline defaults and are handled by SwiftData's automatic lightweight
/// migration without additional `VersionedSchema` entries.
enum CounterSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

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
