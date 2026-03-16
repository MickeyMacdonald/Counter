import Foundation
import SwiftData

@Model
final class AvailabilityOverride {
    var startDate: Date
    var endDate: Date
    var reason: String
    var isUnavailable: Bool // true = blocked off, false = special open day

    init(
        startDate: Date = Date(),
        endDate: Date = Date(),
        reason: String = "",
        isUnavailable: Bool = true
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.reason = reason
        self.isUnavailable = isUnavailable
    }

    var dateRangeFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return f.string(from: startDate)
        }
        return "\(f.string(from: startDate)) – \(f.string(from: endDate))"
    }
}
