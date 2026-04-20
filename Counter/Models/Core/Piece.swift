import Foundation
import SwiftData

@Model
final class Piece {
    var title: String
    var bodyPlacement: String
    var descriptionText: String
    var status: PieceStatus
    var pieceType: PieceType
    var tags: [String]

    // Primary photo path for thumbnail display
    var primaryImagePath: String?

    // Internal artist rating (1–5), nil if not yet rated
    var rating: Int?

    // Size — one of two representations depending on the global PieceSizeMode setting.
    // Categorical: stored in `size`; dimensional: stored in `sizeDimensions` (width/height in inches).
    var size: TattooSize?
    var sizeDimensions: PieceDimensions?

    // Fee structure
    var hourlyRate: Decimal
    var flatRate: Decimal?
    var depositAmount: Decimal

    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    // Relationships
    var client: Client?

    @Relationship(deleteRule: .cascade, inverse: \ImageGroup.piece)
    var imageGroups: [ImageGroup] = []  // Kept temporarily during migration

    @Relationship(deleteRule: .cascade, inverse: \TattooSession.piece)
    var sessions: [TattooSession] = []

    @Relationship(deleteRule: .cascade, inverse: \Payment.piece)
    var payments: [Payment] = []

    /// Direct images owned by the piece (inspiration & reference)
    @Relationship(deleteRule: .cascade, inverse: \PieceImage.piece)
    var directImages: [PieceImage] = []

    // MARK: - Direct Image Filters

    var inspirationImages: [PieceImage] {
        directImages
            .filter { $0.category == .inspiration }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var referenceImages: [PieceImage] {
        directImages
            .filter { $0.category == .reference }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// All images across both direct ownership and session image groups
    var allImages: [PieceImage] {
        let sessionImages = sessions
            .flatMap { $0.imageGroups }
            .flatMap { $0.images }
        return directImages + sessionImages
    }

    var totalHours: Double {
        sessions.reduce(0) { $0 + $1.durationHours }
    }

    var totalCost: Decimal {
        let base: Decimal
        if let flat = flatRate {
            base = flat
        } else {
            base = Decimal(totalHours) * hourlyRate
        }
        let noShowFees = sessions.reduce(Decimal.zero) { $0 + ($1.noShowFee ?? 0) }
        return base + noShowFees
    }

    func chargeableHours(using chargeableTypes: [String]) -> Double {
        sessions
            .filter { chargeableTypes.contains($0.sessionType.rawValue) }
            .reduce(0) { $0 + $1.durationHours }
    }

    func chargeableCost(using chargeableTypes: [String]) -> Decimal {
        let chargeableSessions = sessions.filter {
            chargeableTypes.contains($0.sessionType.rawValue)
        }
        let base: Decimal
        if let flat = flatRate {
            base = flat
        } else {
            let hours = chargeableSessions.reduce(0.0) { $0 + $1.durationHours }
            base = Decimal(hours) * hourlyRate
        }
        let noShowFees = chargeableSessions.reduce(Decimal.zero) { $0 + ($1.noShowFee ?? 0) }
        return base + noShowFees
    }

    var totalPaymentsReceived: Decimal {
        payments.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var outstandingBalance: Decimal {
        totalCost - totalPaymentsReceived
    }

    var isFullyPaid: Bool {
        outstandingBalance <= 0
    }

    var depositReceived: Decimal {
        payments
            .filter { $0.paymentType == .deposit }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    var sortedImageGroups: [ImageGroup] {
        imageGroups.sorted { $0.stage.sortOrder < $1.stage.sortOrder }
    }

    init(
        title: String = "",
        bodyPlacement: String = "",
        descriptionText: String = "",
        status: PieceStatus = .concept,
        pieceType: PieceType = .custom,
        tags: [String] = [],
        rating: Int? = nil,
        hourlyRate: Decimal = 150,
        flatRate: Decimal? = nil,
        depositAmount: Decimal = 0
    ) {
        self.title = title
        self.bodyPlacement = bodyPlacement
        self.descriptionText = descriptionText
        self.status = status
        self.pieceType = pieceType
        self.tags = tags
        self.rating = rating
        self.hourlyRate = hourlyRate
        self.flatRate = flatRate
        self.depositAmount = depositAmount
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum TattooSize: String, Codable, CaseIterable {
    case tiny       = "Tiny"         // e.g. finger, behind-ear
    case small      = "Small"        // e.g. < 2 in
    case medium     = "Medium"       // e.g. 2–4 in
    case large      = "Large"        // e.g. 4–6 in
    case extraLarge = "Extra Large"  // e.g. > 6 in
    case halfSleeve = "Half Sleeve"
    case sleeve     = "Sleeve"
    case backpiece  = "Back Piece"

    var systemImage: String {
        switch self {
        case .tiny:       "circle"
        case .small:      "s.circle.fill"
        case .medium:     "m.circle.fill"
        case .large:      "l.circle.fill"
        case .extraLarge: "xl.circle.fill"
        case .halfSleeve: "hand.raised.fill"
        case .sleeve:     "hand.wave.fill"
        case .backpiece:  "figure.arms.open"
        }
    }
}

/// Exact piece dimensions, always stored in inches for consistency.
struct PieceDimensions: Codable, Hashable {
    var widthInches: Double
    var heightInches: Double

    /// Returns a display string formatted for the given unit.
    func displayString(unit: DimensionUnit) -> String {
        switch unit {
        case .inches:
            return String(format: "%.1f\" × %.1f\"", widthInches, heightInches)
        case .centimeters:
            return String(format: "%.0f × %.0f cm", widthInches * 2.54, heightInches * 2.54)
        }
    }
}

/// How piece sizes are expressed across the app — set once globally in Settings.
enum PieceSizeMode: String {
    case categorical = "categorical"
    case dimensional = "dimensional"
}

/// Unit system used when displaying / entering dimensional measurements.
enum DimensionUnit: String {
    case inches      = "in"
    case centimeters = "cm"

    var label: String {
        switch self {
        case .inches:      "Inches"
        case .centimeters: "Centimeters"
        }
    }

    var symbol: String { rawValue }
}

enum PieceType: String, Codable, CaseIterable {
    case custom = "Custom"
    case walkIn = "Walk In"
    case flash = "Flash"

    var systemImage: String {
        switch self {
        case .custom: "paintbrush.pointed"
        case .walkIn: "figure.walk"
        case .flash: "bolt.fill"
        }
    }
}

enum PieceStatus: String, Codable, CaseIterable {
    case concept = "Concept"
    case designInProgress = "Design in Progress"
    case approved = "Approved"
    case scheduled = "Scheduled"
    case inProgress = "In Progress"
    case completed = "Completed"
    case touchUp = "Touch-Up Needed"
    case healed = "Healed"
    case archived = "Archived"

    var systemImage: String {
        switch self {
        case .concept: "lightbulb"
        case .designInProgress: "pencil.and.outline"
        case .approved: "checkmark.seal"
        case .scheduled: "calendar.badge.clock"
        case .inProgress: "flame"
        case .completed: "checkmark.circle"
        case .touchUp: "bandage"
        case .healed: "heart.circle"
        case .archived: "archivebox"
        }
    }
}
