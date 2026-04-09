import SwiftUI
import SwiftData

struct BookingCalendarView: View {
    /// When `true` the view is embedded inside `SessionsTabView` — no `NavigationStack`
    /// wrapper and no mode picker (the sidebar handles mode selection).
    var embedded: Bool = false
    var initialMode: CalendarDisplayMode = .list

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Booking.date) private var allBookings: [Booking]

    @State private var selectedDate: Date = Date()
    @State private var showingAddBooking = false
    @State private var displayMode: CalendarDisplayMode

    init(embedded: Bool = false, initialMode: CalendarDisplayMode = .list) {
        self.embedded = embedded
        self.initialMode = initialMode
        _displayMode = State(initialValue: initialMode)
    }

    private var calendar: Calendar { Calendar.current }

    private var bookingsForSelectedDate: [Booking] {
        allBookings.filter { booking in
            calendar.isDate(booking.date, inSameDayAs: selectedDate)
        }
        .sorted { $0.startTime < $1.startTime }
    }

    private var weekDays: [Date] {
        // Always start the week from today, then show 6 days forward
        let startDate = calendar.startOfDay(for: selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startDate) }
    }

    private var bookingsForWeek: [(day: Date, label: String, bookings: [Booking])] {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE, MMM d"

        return weekDays.map { day in
            let dayBookings = allBookings
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .sorted { $0.startTime < $1.startTime }
            let label: String
            if calendar.isDateInToday(day) {
                label = "Today — \(dayFormatter.string(from: day))"
            } else if calendar.isDateInTomorrow(day) {
                label = "Tomorrow — \(dayFormatter.string(from: day))"
            } else {
                label = dayFormatter.string(from: day)
            }
            return (day: day, label: label, bookings: dayBookings)
        }
    }

    private var upcomingBookings: [Booking] {
        let startOfToday = calendar.startOfDay(for: Date())
        return allBookings
            .filter { $0.date >= startOfToday && $0.status != .cancelled }
            .sorted { $0.startTime < $1.startTime }
    }

    private var groupedUpcomingBookings: [(title: String, bookings: [Booking])] {
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today),
              let threeDaysOut = calendar.date(byAdding: .day, value: 4, to: today),
              let nextSunday = calendar.nextDate(after: today, matching: DateComponents(weekday: 1), matchingPolicy: .nextTime),
              let weekEnd = calendar.date(byAdding: .day, value: 1, to: nextSunday)
        else { return [] }

        var todayBookings: [Booking] = []
        var tomorrowBookings: [Booking] = []
        var next3DaysBookings: [Booking] = []
        var thisWeekBookings: [Booking] = []
        var laterBookings: [String: [Booking]] = [:]
        var laterOrder: [String] = []

        let weekFormatter = DateFormatter()
        weekFormatter.dateFormat = "'Week of' MMM d"

        for booking in upcomingBookings {
            let bookingDay = calendar.startOfDay(for: booking.date)
            if bookingDay == today {
                todayBookings.append(booking)
            } else if bookingDay == tomorrow {
                tomorrowBookings.append(booking)
            } else if bookingDay >= dayAfterTomorrow && bookingDay < threeDaysOut {
                next3DaysBookings.append(booking)
            } else if bookingDay >= threeDaysOut && bookingDay < weekEnd {
                thisWeekBookings.append(booking)
            } else if bookingDay >= weekEnd {
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: booking.date)?.start ?? bookingDay
                let key = weekFormatter.string(from: weekStart)
                if laterBookings[key] == nil {
                    laterBookings[key] = []
                    laterOrder.append(key)
                }
                laterBookings[key]?.append(booking)
            }
        }

        var sections: [(title: String, bookings: [Booking])] = []
        if !todayBookings.isEmpty { sections.append(("Today", todayBookings)) }
        if !tomorrowBookings.isEmpty { sections.append(("Tomorrow", tomorrowBookings)) }
        if !next3DaysBookings.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE d"
            let rangeLabel = next3DaysBookings.count == 1
                ? formatter.string(from: next3DaysBookings[0].date)
                : "Next 3 Days"
            sections.append((rangeLabel, next3DaysBookings))
        }
        if !thisWeekBookings.isEmpty { sections.append(("This Week", thisWeekBookings)) }
        for key in laterOrder {
            if let bookings = laterBookings[key] {
                sections.append((key, bookings))
            }
        }
        return sections
    }

    private var datesWithBookings: Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Set(allBookings.map { formatter.string(from: $0.date) })
    }

    var body: some View {
        if embedded {
            calendarContent
        } else {
            NavigationStack { calendarContent }
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        VStack(spacing: 0) {
            // Mode picker — hidden when embedded (sidebar handles selection)
            if !embedded {
                Picker("View", selection: $displayMode) {
                    ForEach(CalendarDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
            }

            switch displayMode {
                case .list:
                    // All upcoming bookings grouped by time period
                    let sections = groupedUpcomingBookings
                    if sections.isEmpty {
                        ContentUnavailableView {
                            Label("No Upcoming Bookings", systemImage: "calendar")
                        } description: {
                            Text("All clear — nothing on the horizon.")
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(sections, id: \.title) { section in
                                Section(section.title) {
                                    ForEach(section.bookings) { booking in
                                        NavigationLink {
                                            BookingDetailView(booking: booking)
                                        } label: {
                                            BookingRowView(booking: booking)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }

                case .week:
                    WeekStripView(
                        selectedDate: $selectedDate,
                        datesWithBookings: datesWithBookings
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Divider()
                        .padding(.top, 8)

                    List {
                        ForEach(bookingsForWeek, id: \.day) { dayGroup in
                            Section {
                                if dayGroup.bookings.isEmpty {
                                    Text("No bookings")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                } else {
                                    ForEach(dayGroup.bookings) { booking in
                                        NavigationLink {
                                            BookingDetailView(booking: booking)
                                        } label: {
                                            BookingRowView(booking: booking)
                                        }
                                    }
                                }
                            } header: {
                                Text(dayGroup.label)
                                    .fontWeight(calendar.isDate(dayGroup.day, inSameDayAs: selectedDate) ? .bold : .regular)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)

                case .month:
                    MonthCalendarView(
                        selectedDate: $selectedDate,
                        datesWithBookings: datesWithBookings
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Divider()
                        .padding(.top, 8)

                    if bookingsForSelectedDate.isEmpty {
                        ContentUnavailableView {
                            Label("No Bookings", systemImage: "calendar.badge.plus")
                        } description: {
                            Text(selectedDate.formatted(date: .long, time: .omitted))
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(bookingsForSelectedDate) { booking in
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
            }
            .navigationTitle("Bookings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        selectedDate = Date()
                    } label: {
                        Text("Today")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBooking = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBooking) {
                AddSessionView(context: .fromCalendar(selectedDate))
            }
        }
    }

// MARK: - Week Strip View

struct WeekStripView: View {
    @Binding var selectedDate: Date
    let datesWithBookings: Set<String>

    private let calendar = Calendar.current

    private var weekTitle: String {
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let startStr = start.formatted(.dateTime.month(.abbreviated).day())
        let endStr = end.formatted(.dateTime.month(.abbreviated).day())
        return "\(startStr) – \(endStr)"
    }

    private var daysInWeek: [Date] {
        let start = calendar.startOfDay(for: selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Week navigation
            HStack {
                Button {
                    moveWeek(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()
                Text(weekTitle)
                    .font(.headline)
                Spacer()

                Button {
                    moveWeek(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            // Day strip
            HStack(spacing: 0) {
                ForEach(daysInWeek, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(date)

                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 4) {
                            Text(date.formatted(.dateTime.weekday(.short)))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isSelected ? .white : .secondary)

                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(.callout, design: .monospaced, weight: isToday ? .bold : .regular))
                                .foregroundStyle(isSelected ? .white : isToday ? Color.accentColor : .primary)

                            Circle()
                                .fill(hasBookings(on: date) ? (isSelected ? .white : Color.accentColor) : .clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentColor)
                            } else if isToday {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.accentColor, lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func moveWeek(by value: Int) {
        if let newDate = calendar.date(byAdding: .day, value: value * 7, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func hasBookings(on date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return datesWithBookings.contains(formatter.string(from: date))
    }
}

// MARK: - Month Calendar Grid

struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    let datesWithBookings: Set<String>

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var monthTitle: String {
        selectedDate.formatted(.dateTime.month(.wide).year())
    }

    private var daysInMonth: [DateCell] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedDate),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var cells: [DateCell] = []

        // Leading blanks
        for _ in 0..<firstWeekday {
            cells.append(DateCell(date: nil, day: 0))
        }

        // Actual days
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                cells.append(DateCell(date: date, day: day))
            }
        }

        return cells
    }

    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()
                Text(monthTitle)
                    .font(.headline)
                Spacer()

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            // Weekday headers
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            // Day grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(daysInMonth) { cell in
                    if let date = cell.date {
                        DayCellView(
                            day: cell.day,
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasBookings: hasBookings(on: date)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Text("")
                            .frame(height: 36)
                    }
                }
            }
        }
    }

    private func moveMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func hasBookings(on date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return datesWithBookings.contains(formatter.string(from: date))
    }
}

struct DateCell: Identifiable {
    let id = UUID()
    let date: Date?
    let day: Int
}

struct DayCellView: View {
    let day: Int
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasBookings: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(.callout, design: .monospaced, weight: isToday ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : isToday ? Color.accentColor : .primary)

            Circle()
                .fill(hasBookings ? (isSelected ? .white : Color.accentColor) : .clear)
                .frame(width: 5, height: 5)
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor)
            } else if isToday {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 1)
            }
        }
    }
}

// MARK: - Booking Row

struct BookingRowView: View {
    let booking: Booking

    private var prepTasks: [PrepTask] { booking.prepTasks }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // Booking type color bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(booking.bookingType.color)
                    .frame(width: 4, height: 36)

                // Time column
                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    Text(booking.durationFormatted)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70, alignment: .leading)

                // Status indicator
                Image(systemName: booking.status.systemImage)
                    .foregroundStyle(statusColor(booking.status))
                    .font(.caption)

                // Details
                VStack(alignment: .leading, spacing: 2) {
                    if let client = booking.client {
                        Text(client.fullName)
                            .font(.subheadline.weight(.medium))
                    } else {
                        Text("Walk-in")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: booking.bookingType.systemImage)
                            .font(.caption2)
                        Text(booking.bookingType.rawValue)
                            .font(.caption)
                    }
                    .foregroundStyle(booking.bookingType.color)
                }

                Spacer()

                if booking.depositPaid {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            // Prep checklist
            if !prepTasks.isEmpty {
                HStack(spacing: 8) {
                    ForEach(prepTasks) { task in
                        HStack(spacing: 3) {
                            Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                                .font(.caption2)
                                .foregroundStyle(task.isComplete ? .green : .secondary)
                            Text(task.label)
                                .font(.caption2)
                                .foregroundStyle(task.isComplete ? .primary : .secondary)
                        }
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 2)
    }

    private func statusColor(_ status: BookingStatus) -> Color {
        switch status {
        case .requested: .orange
        case .confirmed: .blue
        case .inProgress: .purple
        case .completed: .green
        case .cancelled: .red
        case .noShow: .gray
        }
    }
}

// MARK: - Display Mode

enum CalendarDisplayMode: String, CaseIterable, Identifiable {
    case list = "List"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }
}

#Preview {
    BookingCalendarView()
        .modelContainer(PreviewContainer.shared.container)
}
