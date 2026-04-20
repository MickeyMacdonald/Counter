import Foundation
import SwiftData

enum CounterSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            // All V2 models, with PieceImage replaced by WorkImage.
            Client.self,
            Piece.self,
            SessionProgress.self,
            WorkImage.self,        // Replaces PieceImage
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
            Discount.self
        ]
    }
}
