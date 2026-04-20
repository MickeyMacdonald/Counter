import Foundation
import SwiftData

@Model
final class SessionProgress {
    var stage: ImageStage
    var notes: String
    var timeSpentMinutes: Int
    var createdAt: Date

    // Relationships
    var piece: Piece?       // Kept temporarily during migration
    var session: Session?  // New: session owns work photo groups

    @Relationship(deleteRule: .cascade, inverse: \PieceImage.sessionProgress)
    var images: [PieceImage] = []

    var timeSpentFormatted: String {
        let hours = timeSpentMinutes / 60
        let mins = timeSpentMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    init(
        stage: ImageStage = .sketch,
        notes: String = "",
        timeSpentMinutes: Int = 0
    ) {
        self.stage = stage
        self.notes = notes
        self.timeSpentMinutes = timeSpentMinutes
        self.createdAt = Date()
    }
}

/// Work stages for session progress photos.
/// Inspiration/reference images are now handled by PieceImageCategory on direct PieceImages.
enum ImageStage: String, Codable, CaseIterable {
    case sketch = "Sketch"
    case lineart = "Lineart"
    case shading = "Shading"
    case color = "Color"
    case stencil = "Stencil"
    case freshlyTattooed = "Freshly Tattooed"
    case healed = "Healed"
    case finalResult = "Final Result"

    var sortOrder: Int {
        switch self {
        case .sketch: 0
        case .lineart: 1
        case .shading: 2
        case .color: 3
        case .stencil: 4
        case .freshlyTattooed: 5
        case .healed: 6
        case .finalResult: 7
        }
    }

    /// Stages safe to show to clients (finished/presentable work only)
    var isClientSafe: Bool {
        switch self {
        case .lineart, .shading, .color, .freshlyTattooed, .healed, .finalResult:
            true
        case .sketch, .stencil:
            false
        }
    }

    var systemImage: String {
        switch self {
        case .sketch: "pencil.tip"
        case .lineart: "pencil.and.outline"
        case .shading: "circle.lefthalf.filled"
        case .color: "paintpalette"
        case .stencil: "doc.on.doc"
        case .freshlyTattooed: "camera"
        case .healed: "heart.circle"
        case .finalResult: "star.circle"
        }
    }
}
