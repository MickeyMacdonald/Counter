import Foundation
import SwiftData

enum FlashPricingMode: String, Codable, CaseIterable {
    case hourly = "hourly"
    case sizeBased = "sizeBased"

    var label: String {
        switch self {
        case .hourly:    "Hourly"
        case .sizeBased: "Size Based"
        }
    }
}

@Model final class FlashPriceTier {
    var uuid: UUID
    var label: String
    var widthInches: Double
    var heightInches: Double
    var price: Decimal
    var sortOrder: Int

    init(label: String = "New Size", widthInches: Double = 4, heightInches: Double = 4, price: Decimal = 0, sortOrder: Int = 0) {
        self.uuid = UUID()
        self.label = label
        self.widthInches = widthInches
        self.heightInches = heightInches
        self.price = price
        self.sortOrder = sortOrder
    }
}
