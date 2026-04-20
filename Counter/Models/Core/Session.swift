import Foundation
import SwiftData

@Model
final class Session {
    var date: Date
    var startTime: Date
    var endTime: Date?
    var breakMinutes: Int
    var sessionType: SessionType
    var hourlyRateAtTime: Decimal
    var flashRate: Decimal
    var manualHoursOverride: Double?
    var isNoShow: Bool
    var noShowFee: Decimal?
    var notes: String

    // Relationships
    var piece: Piece?

    @Relationship(deleteRule: .cascade, inverse: \SessionProgress.session)
    var sessionProgress: [SessionProgress] = []

    var sortedSessionProgress: [SessionProgress] {
        sessionProgress.sorted { $0.stage.sortOrder < $1.stage.sortOrder }
    }

    var durationHours: Double {
        if let override = manualHoursOverride { return override }
        guard let end = endTime else { return 0 }
        let totalSeconds = end.timeIntervalSince(startTime)
        let breakSeconds = Double(breakMinutes) * 60
        return max(0, (totalSeconds - breakSeconds) / 3600)
    }

    var cost: Decimal {
        sessionType.isFlash ? flashRate : Decimal(durationHours) * hourlyRateAtTime
    }

    var durationFormatted: String {
        let hours = Int(durationHours)
        let mins = Int((durationHours - Double(hours)) * 60)
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    init(
        date: Date = Date(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        breakMinutes: Int = 0,
        sessionType: SessionType = .consultation,
        hourlyRateAtTime: Decimal = 150,
        flashRate: Decimal = 150,
        manualHoursOverride: Double? = nil,
        isNoShow: Bool = false,
        noShowFee: Decimal? = nil,
        notes: String = ""
    ) {
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.breakMinutes = breakMinutes
        self.sessionType = sessionType
        self.hourlyRateAtTime = hourlyRateAtTime
        self.flashRate = flashRate
        self.manualHoursOverride = manualHoursOverride
        self.isNoShow = isNoShow
        self.noShowFee = noShowFee
        self.notes = notes
    }
}

enum SessionType: String, CaseIterable {
    // Charged by default
    case linework        = "Linework"
    case shading         = "Shading"
    case colour          = "Colour"
    case flash           = "Flash"
    case revision        = "Revision"
    // Uncharged by default
    case consultation    = "Consultation"
    case initialDrafting = "Initial Drafting"
    case touchUp         = "Touch Up"
    case flashDesign     = "Flash Design"

    var systemImage: String {
        switch self {
        case .linework:        "pencil.and.outline"
        case .shading:         "circle.lefthalf.filled"
        case .colour:          "paintpalette"
        case .flash:           "bolt.fill"
        case .revision:        "arrow.counterclockwise"
        case .consultation:    "bubble.left.and.bubble.right"
        case .initialDrafting: "pencil.tip"
        case .touchUp:         "wand.and.stars"
        case .flashDesign:     "sparkles"
        }
    }

    var isFlash: Bool { self == .flash }

    var defaultChargeable: Bool {
        switch self {
        case .linework, .shading, .colour, .flash, .revision:              true
        case .consultation, .initialDrafting, .touchUp, .flashDesign:      false
        }
    }

    static var defaultChargeableRawValues: [String] {
        allCases.filter(\.defaultChargeable).map(\.rawValue)
    }
}

// Custom Codable so legacy raw values stored on disk (e.g. "Drafting" from the old
// enum) are migrated forward instead of causing a fatal decode crash.
extension SessionType: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        // Legacy → current mappings
        case "Drafting":        self = .initialDrafting
        // Normal path
        default:
            if let value = SessionType(rawValue: raw) {
                self = value
            } else {
                // Unknown future value — fall back gracefully
                self = .consultation
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
