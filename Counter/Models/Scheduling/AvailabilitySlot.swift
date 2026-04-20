import Foundation
import SwiftData

@Model
final class AvailabilitySlot {
    var dayOfWeek: Int          // 0 = Sunday, 6 = Saturday
    var startTime: Date
    var endTime: Date
    var slotTypeRaw: String
    var isFlashOnly: Bool
    var isActive: Bool          // retained for backward-compat

    var slotType: SlotType {
        get { SlotType(rawValue: slotTypeRaw) ?? .available }
        set { slotTypeRaw = newValue.rawValue }
    }

    enum SlotType: String, CaseIterable, Codable {
        case available   = "available"
        case prep        = "prep"
        case unavailable = "unavailable"

        var label: String {
            switch self {
            case .available:   return "Available for Sessions"
            case .prep:        return "Reserved for Drawing Prep"
            case .unavailable: return "Fully Unavailable"
            }
        }

        var shortLabel: String {
            switch self {
            case .available:   return "Sessions"
            case .prep:        return "Prep"
            case .unavailable: return "Blocked"
            }
        }
    }

    var dayName: String {
        let formatter = DateFormatter()
        let symbols = formatter.weekdaySymbols ?? []
        guard dayOfWeek >= 0, dayOfWeek < symbols.count else { return "Unknown" }
        return symbols[dayOfWeek]
    }

    var shortDayName: String {
        let formatter = DateFormatter()
        let symbols = formatter.shortWeekdaySymbols ?? []
        guard dayOfWeek >= 0, dayOfWeek < symbols.count else { return "?" }
        return symbols[dayOfWeek]
    }

    var timeRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) – \(formatter.string(from: endTime))"
    }

    init(
        dayOfWeek: Int = 1,
        startTime: Date = {
            Calendar.current.date(from: DateComponents(hour: 10, minute: 0)) ?? Date()
        }(),
        endTime: Date = {
            Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
        }(),
        slotType: SlotType = .available,
        isFlashOnly: Bool = false,
        isActive: Bool = true
    ) {
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.slotTypeRaw = slotType.rawValue
        self.isFlashOnly = isFlashOnly
        self.isActive = isActive
    }
}
