import Foundation
import SwiftData

@Model
final class SessionType {
    var uuid: UUID
    var name: String
    var isChargeable: Bool
    var sortOrder: Int
    var createdAt: Date

    init(name: String = "New Session", isChargeable: Bool = false, sortOrder: Int = 0) {
        self.uuid = UUID()
        self.name = name
        self.isChargeable = isChargeable
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
