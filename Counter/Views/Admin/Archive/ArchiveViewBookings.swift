import SwiftUI
import SwiftData

struct ArchiveViewBookings: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Booking.date, order: .reverse) private var allBookings: [Booking]

    @State private var bookingPendingDelete: Booking?

    private var archivedBookings: [Booking] {
        allBookings.filter { $0.status == .cancelled || $0.status == .noShow }
    }

    var body: some View {
        List {
            if archivedBookings.isEmpty {
                ContentUnavailableView(
                    "No Archived Bookings",
                    systemImage: "calendar.badge.minus",
                    description: Text("Cancelled and no-show bookings appear here.")
                )
            } else {
                ForEach(archivedBookings) { booking in
                    row(booking)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Archived Bookings")
        .confirmationDialog(
            "Permanently delete this booking?",
            isPresented: Binding(
                get: { bookingPendingDelete != nil },
                set: { if !$0 { bookingPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                if let booking = bookingPendingDelete {
                    modelContext.delete(booking)
                    try? modelContext.save()
                }
                bookingPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { bookingPendingDelete = nil }
        } message: {
            Text("This booking will be permanently deleted. This cannot be undone.")
        }
    }

    private func row(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(booking.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.medium))
                Spacer()
                Label(booking.status.rawValue, systemImage: booking.status.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let client = booking.client {
                Text(client.fullName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let piece = booking.piece {
                Text(piece.title)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                booking.status = .confirmed
                booking.updatedAt = Date()
                try? modelContext.save()
            } label: {
                Label("Restore", systemImage: "tray.and.arrow.up")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                bookingPendingDelete = booking
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    NavigationStack { ArchiveViewBookings() }
        .modelContainer(PreviewContainer.shared.container)
}
