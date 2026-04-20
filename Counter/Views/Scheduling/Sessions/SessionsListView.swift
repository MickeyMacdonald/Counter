import SwiftUI
import SwiftData

// MARK: - SessionsSidebarList
// Displayed directly in the Scheduling sidebar when the Sessions group is active.
// Shows Booking objects — the canonical scheduling type — so all session navigation
// in the Scheduling tab points to a single detail view (BookingDetailView).

struct SessionsSidebarList: View {
    @Binding var selectedBooking: Booking?
    @Binding var searchText: String

    @Query(sort: \Booking.date, order: .reverse) private var allBookings: [Booking]
    @Query(sort: \Client.lastName) private var allClients: [Client]

    @State private var filterClient: Client?          = nil
    @State private var filterBookingType: BookingType? = nil
    @State private var filterStatus: BookingStatus?   = nil
    @State private var filterMonth: Int?              = nil
    @State private var filterYear: Int?               = nil

    private var visibleClients: [Client] {
        allClients.filter { !$0.isFlashPortfolioClient }
    }

    private var availableYears: [Int] {
        Set(allBookings.map { Calendar.current.component(.year, from: $0.date) })
            .sorted(by: >)
    }

    private var filteredBookings: [Booking] {
        var result = allBookings

        if let client = filterClient {
            result = result.filter {
                $0.client?.persistentModelID == client.persistentModelID
            }
        }
        if let type = filterBookingType {
            result = result.filter { $0.bookingType == type }
        }
        if let status = filterStatus {
            result = result.filter { $0.status == status }
        }
        if let month = filterMonth {
            result = result.filter {
                Calendar.current.component(.month, from: $0.date) == month
            }
        }
        if let year = filterYear {
            result = result.filter {
                Calendar.current.component(.year, from: $0.date) == year
            }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.bookingType.rawValue.lowercased().contains(q) ||
                $0.client?.fullName.lowercased().contains(q) == true ||
                $0.piece?.title.lowercased().contains(q) == true ||
                $0.notes.lowercased().contains(q)
            }
        }

        return result
    }

    // MARK: - Body

    var body: some View {
        Group {
            if filteredBookings.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Bookings" : "No Results",
                    systemImage: searchText.isEmpty
                        ? "calendar.badge.clock"
                        : "magnifyingglass"
                )
            } else {
                List(filteredBookings, selection: $selectedBooking) { booking in
                    sidebarRow(booking)
                        .tag(booking)
                }
                .listStyle(.sidebar)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    filterMenuContent
                } label: {
                    Image(systemName: hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    // MARK: - Sidebar Row

    private func sidebarRow(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: booking.bookingType.systemImage)
                    .font(.caption2)
                    .foregroundStyle(booking.bookingType.color)
                Text(booking.bookingType.rawValue)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
                Text(booking.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 3) {
                if let client = booking.client {
                    Text(client.fullName)
                        .font(.caption)
                        .lineLimit(1)
                    if let piece = booking.piece {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(piece.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Walk-in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: booking.status.systemImage)
                    .font(.caption2)
                Text(booking.status.rawValue)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(statusColor(booking.status))
        }
        .padding(.vertical, 2)
    }

    private func statusColor(_ status: BookingStatus) -> Color {
        switch status {
        case .requested:  .orange
        case .confirmed:  .blue
        case .inProgress: .purple
        case .completed:  .green
        case .cancelled:  .red
        case .noShow:     .gray
        }
    }

    // MARK: - Filter Menu

    @ViewBuilder
    private var filterMenuContent: some View {
        Section("Client") {
            Picker("Client", selection: $filterClient) {
                Text("All Clients").tag(Client?.none)
                ForEach(visibleClients) { client in
                    Text(client.fullName).tag(Client?.some(client))
                }
            }
        }

        Section("Type") {
            Picker("Booking Type", selection: $filterBookingType) {
                Text("Any Type").tag(BookingType?.none)
                ForEach(BookingType.allCases, id: \.self) { t in
                    Label(t.rawValue, systemImage: t.systemImage).tag(BookingType?.some(t))
                }
            }
        }

        Section("Status") {
            Picker("Status", selection: $filterStatus) {
                Text("Any Status").tag(BookingStatus?.none)
                ForEach(BookingStatus.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(BookingStatus?.some(s))
                }
            }
        }

        if !availableYears.isEmpty {
            Section("Year") {
                Picker("Year", selection: $filterYear) {
                    Text("Any Year").tag(Int?.none)
                    ForEach(availableYears, id: \.self) { y in
                        Text(String(y)).tag(Int?.some(y))
                    }
                }
            }
        }

        Section("Month") {
            Picker("Month", selection: $filterMonth) {
                Text("Any Month").tag(Int?.none)
                ForEach(1...12, id: \.self) { m in
                    Text(Calendar.current.monthSymbols[m - 1]).tag(Int?.some(m))
                }
            }
        }

        if hasActiveFilters {
            Divider()
            Button(role: .destructive) {
                resetFilters()
            } label: {
                Label("Clear Filters", systemImage: "xmark.circle")
            }
        }
    }

    private var hasActiveFilters: Bool {
        filterClient != nil || filterBookingType != nil || filterStatus != nil ||
        filterMonth != nil || filterYear != nil
    }

    private func resetFilters() {
        filterClient      = nil
        filterBookingType = nil
        filterStatus      = nil
        filterMonth       = nil
        filterYear        = nil
    }
}
