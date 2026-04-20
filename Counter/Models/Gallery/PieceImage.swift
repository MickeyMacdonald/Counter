import Foundation
import SwiftData

@Model
final class PieceImage {
    // Path relative to app's documents directory
    var filePath: String
    var fileName: String
    var notes: String
    var capturedAt: Date
    var sortOrder: Int
    var isPrimary: Bool

    // Category for direct piece images (inspiration/reference)
    var category: PieceImageCategory?

    // Descriptive tags (e.g. "blackwork", "floral", "geometric")
    var tags: [String] = []

    // Relationships
    var sessionProgress: SessionProgress?  // For session work photos (kept temporarily)
    var piece: Piece?            // For direct piece images (inspiration/reference)

    /// Full URL to the image file on disk
    var fileURL: URL? {
        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return nil }
        return documentsURL.appendingPathComponent(filePath)
    }

    init(
        filePath: String,
        fileName: String = "",
        notes: String = "",
        capturedAt: Date = Date(),
        sortOrder: Int = 0,
        isPrimary: Bool = false,
        category: PieceImageCategory? = nil,
        tags: [String] = []
    ) {
        self.filePath = filePath
        self.fileName = fileName
        self.notes = notes
        self.capturedAt = capturedAt
        self.sortOrder = sortOrder
        self.isPrimary = isPrimary
        self.category = category
        self.tags = tags
    }
}

/// Category for images directly owned by a Piece (not via SessionProgress/Session)
enum PieceImageCategory: String, Codable, CaseIterable {
    case inspiration = "Inspiration"
    case reference = "Reference"

    var systemImage: String {
        switch self {
        case .inspiration: "sparkles"
        case .reference: "photo.on.rectangle"
        }
    }
}

