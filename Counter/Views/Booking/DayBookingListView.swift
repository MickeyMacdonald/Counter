import SwiftUI
import SwiftData

struct DayBookingListView: View {
    let date: Date
    @Query(sort: \Booking.startTime) private var allBookings: [Booking]
    @State private var showingAddBooking = false

    private var bookingsForDay: [Booking] {
        let calendar = Calendar.current
        return allBookings.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        Group {
            if bookingsForDay.isEmpty {
                ContentUnavailableView {
                    Label("No Bookings", systemImage: "calendar")
                } description: {
                    Text("Nothing scheduled for \(date.formatted(date: .long, time: .omitted))")
                }
            } else {
                List {
                    ForEach(bookingsForDay) { booking in
                        NavigationLink {
                            BookingDetailView(booking: booking)
                        } label: {
                            BookingRowView(booking: booking)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddBooking = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddBooking) {
            AddSessionView(context: .fromCalendar(date))
        }
    }
}

#Preview {
    NavigationStack {
        DayBookingListView(date: Date())
    }
    .modelContainer(PreviewContainer.shared.container)
}
