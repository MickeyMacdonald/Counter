import Foundation
import SwiftUI
import SwiftData

@Model
final class Booking {
    var date: Date
    var startTime: Date
    var endTime: Date
    var status: BookingStatus
    var bookingType: BookingType
    var notes: String

    var depositPaid: Bool
    var reminderSent: Bool

    /// Labels of auto-generated prep tasks whose completion state has been
    /// manually overridden (toggled from what the piece data would compute).
    var checklistOverrides: [String] = []

    /// User-defined to-do items appended to the checklist.
    var customChecklistItems: [BookingCustomTask] = []

    var createdAt: Date
    var updatedAt: Date

    // Relationships
    var client: Client?
    var piece: Piece?

    var durationFormatted: String {
        let seconds = endTime.timeIntervalSince(startTime)
        let hours = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    /// Prep tasks derived from the linked piece's image/stage progression.
    /// Each task indicates whether a required pre-session item has been uploaded.
    var prepTasks: [PrepTask] {
        guard let piece else { return [] }

        switch bookingType {
        case .consultation:
            // Check direct inspiration/reference images on the piece
            return [
                PrepTask(
                    label: "Inspiration",
                    icon: PieceImageCategory.inspiration.systemImage,
                    isComplete: !piece.inspirationImages.isEmpty
                ),
                PrepTask(
                    label: "Reference",
                    icon: PieceImageCategory.reference.systemImage,
                    isComplete: !piece.referenceImages.isEmpty
                )
            ]
        case .session:
            return stageChecklist(for: piece, stages: [.sketch, .lineart, .stencil])
        case .touchUp:
            return stageChecklist(for: piece, stages: [.freshlyTattooed, .healed])
        case .flashPickup:
            return []
        }
    }

    /// Checks whether work-stage image groups exist and have images.
    private func stageChecklist(for piece: Piece, stages: [ImageStage]) -> [PrepTask] {
        let allGroups = piece.sessions.flatMap(\.imageGroups) + piece.imageGroups
        return stages.map { stage in
            let group = allGroups.first { $0.stage == stage }
            return PrepTask(
                label: stage.rawValue,
                icon: stage.systemImage,
                isComplete: group != nil && !group!.images.isEmpty
            )
        }
    }

    var isUpcoming: Bool {
        date >= Calendar.current.startOfDay(for: Date()) && status != .cancelled && status != .completed
    }

    var isPast: Bool {
        date < Calendar.current.startOfDay(for: Date())
    }

    init(
        date: Date = Date(),
        startTime: Date = Date(),
        endTime: Date = Date().addingTimeInterval(3600),
        status: BookingStatus = .confirmed,
        bookingType: BookingType = .session,
        notes: String = "",
        depositPaid: Bool = false,
        reminderSent: Bool = false,
        client: Client? = nil,
        piece: Piece? = nil
    ) {
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.bookingType = bookingType
        self.notes = notes
        self.depositPaid = depositPaid
        self.reminderSent = reminderSent
        self.client = client
        self.piece = piece
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct PrepTask: Identifiable {
    let label: String
    let icon: String
    let isComplete: Bool
    var id: String { label }
}

/// A user-defined checklist item stored directly on a Booking.
struct BookingCustomTask: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var label: String
    var isComplete: Bool = false
}

enum BookingStatus: String, Codable, CaseIterable {
    case requested = "Requested"
    case confirmed = "Confirmed"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case noShow = "No Show"

    var systemImage: String {
        switch self {
        case .requested: "questionmark.circle"
        case .confirmed: "checkmark.circle"
        case .inProgress: "flame"
        case .completed: "checkmark.seal.fill"
        case .cancelled: "xmark.circle"
        case .noShow: "person.slash"
        }
    }

    var tintColor: String {
        switch self {
        case .requested: "orange"
        case .confirmed: "blue"
        case .inProgress: "purple"
        case .completed: "green"
        case .cancelled: "red"
        case .noShow: "gray"
        }
    }
}

enum BookingType: String, Codable, CaseIterable {
    case consultation = "Consultation"
    case session = "Session"
    case touchUp = "Touch-Up"
    case flashPickup = "Flash Pickup"

    var systemImage: String {
        switch self {
        case .consultation: "bubble.left.and.bubble.right"
        case .session: "paintbrush.pointed"
        case .touchUp: "bandage"
        case .flashPickup: "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .consultation: .blue
        case .session: .purple
        case .touchUp: .orange
        case .flashPickup: .yellow
        }
    }
}
