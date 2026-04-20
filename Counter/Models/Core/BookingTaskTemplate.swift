import Foundation
import SwiftData

@Model
final class BookingTaskTemplate {
    var label: String
    var bookingType: BookingType
    var sortOrder: Int
    var isEnabled: Bool
    var createdAt: Date

    init(label: String, bookingType: BookingType, sortOrder: Int = 0, isEnabled: Bool = true) {
        self.label = label
        self.bookingType = bookingType
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.createdAt = Date()
    }
}
