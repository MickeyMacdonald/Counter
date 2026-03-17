import Foundation
import SwiftData

/// A user-defined gallery grouping that collects pieces by matching tags.
@Model
final class CustomGalleryGroup {
    var name: String
    var tags: [String]
    var sortIndex: Int
    var createdAt: Date

    init(name: String, tags: [String] = [], sortIndex: Int = 0) {
        self.name = name
        self.tags = tags
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }
}
