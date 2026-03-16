import Foundation
import SwiftData

/// Standalone inspiration/reference image not tied to any client or piece.
/// Used as a personal study library for non-tattoo imagery.
@Model
final class InspirationImage {
    var filePath: String
    var fileName: String
    var tags: [String]
    var notes: String
    var capturedAt: Date

    var fileURL: URL? {
        guard let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        return docs.appendingPathComponent(filePath)
    }

    init(
        filePath: String,
        fileName: String = "",
        tags: [String] = [],
        notes: String = ""
    ) {
        self.filePath = filePath
        self.fileName = fileName
        self.tags = tags
        self.notes = notes
        self.capturedAt = Date()
    }
}
