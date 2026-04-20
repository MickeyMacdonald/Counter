import Foundation
import SwiftData

@Model final class CustomDiscount {
    var name: String
    var percentage: Decimal
    var sortOrder: Int

    init(name: String = "New Discount", percentage: Decimal = 10, sortOrder: Int = 0) {
        self.name = name
        self.percentage = percentage
        self.sortOrder = sortOrder
    }
}
