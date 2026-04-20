import Foundation
import SwiftData

@Model
final class WorkImage {
    // Path relative to app's documents directory
    var filePath: String
    var fileName: String
    var title: String
    var notes: String
    var capturedAt: Date
    var sortOrder: Int
    var isPrimary: Bool
    var isPortfolio: Bool

    var category: ImageCategory
    var healingStage: HealingStage?
    var source: ImageSource

    // Descriptive tags (e.g. "blackwork", "floral", "geometric")
    var tags: [String] = []

    // Relationships
    var piece: Piece?
    var sessionProgress: SessionProgress?
    var client: Client?

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
        title: String = "",
        notes: String = "",
        capturedAt: Date = Date(),
        sortOrder: Int = 0,
        isPrimary: Bool = false,
        isPortfolio: Bool = false,
        category: ImageCategory = .progress,
        healingStage: HealingStage? = nil,
        source: ImageSource = .photoLibrary,
        tags: [String] = []
    ) {
        self.filePath = filePath
        self.fileName = fileName
        self.title = title
        self.notes = notes
        self.capturedAt = capturedAt
        self.sortOrder = sortOrder
        self.isPrimary = isPrimary
        self.isPortfolio = isPortfolio
        self.category = category
        self.healingStage = healingStage
        self.source = source
        self.tags = tags
    }
}

/// Category for WorkImage — what role the image plays
enum ImageCategory: String, Codable, CaseIterable {
    case inspiration = "Inspiration"
    case reference   = "Reference"
    case progress    = "Progress"
    case healed      = "Healed"
    case portfolio   = "Portfolio"
    case profile     = "Profile"

    var systemImage: String {
        switch self {
        case .inspiration: "sparkles"
        case .reference:   "photo.on.rectangle"
        case .progress:    "camera"
        case .healed:      "heart.circle"
        case .portfolio:   "rectangle.stack.badge.play"
        case .profile:     "person.crop.circle"
        }
    }
}

/// Healing state for tattoo result photos
enum HealingStage: String, Codable, CaseIterable {
    case fresh    = "Fresh"
    case healed   = "Healed"
    case touchUp  = "Touch-Up"

    var systemImage: String {
        switch self {
        case .fresh:   "bandage"
        case .healed:  "checkmark.seal"
        case .touchUp: "wand.and.stars"
        }
    }
}

/// How the image was acquired
enum ImageSource: String, Codable, CaseIterable {
    case camera       = "Camera"
    case photoLibrary = "Photo Library"
    case imported     = "Imported"

    var systemImage: String {
        switch self {
        case .camera:       "camera"
        case .photoLibrary: "photo.on.rectangle.angled"
        case .imported:     "square.and.arrow.down"
        }
    }
}
