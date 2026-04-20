import SwiftUI
import SwiftData
//TODO: daily switch case add lines 24, 34, 42, 136. Booking Calendar needs edits

// MARK: - Bookings Group (top-level picker)

enum ScheduleGroup: String, CaseIterable {
    case sessions = "Sessions"
    case tasks    = "Tasks"
    case calendar = "Calendar"
}

// MARK: - Bookings Sidebar Section
// Used only for the Tasks and Calendar groups.
// The Sessions group renders Booking rows directly in the sidebar.

enum ScheduleSection: String, CaseIterable, Hashable, Identifiable {
    case todo    = "To Do"
    case list    = "Upcoming"
    case weekly  = "Weekly View"
    case monthly = "Monthly View"
    // case daily   = "Today" TODO: repair with exhaustive switch on ln-136

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .todo:    "checklist"
        case .list:    "list.bullet"
        case .weekly:  "calendar.badge.clock"
        case .monthly: "calendar"
        // case .daily: "1.calendar" TODO: repair with exhaustive switch on ln-136
        }
    }

    var group: ScheduleGroup {
        switch self {
        case .todo, .list:
            return .tasks
        case .weekly, .monthly: // TODO: daily add
            return .calendar
        }
    }
}

// MARK: - Scheduling Tab

struct SchedulingView: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator

    @State private var group: ScheduleGroup              = .tasks
    @State private var selectedSection: ScheduleSection? = .list
    @State private var selectedBooking: Booking?         = nil
    @State private var searchText = ""

    private var visibleSections: [ScheduleSection] {
        let base = ScheduleSection.allCases.filter { $0.group == group }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                AppTabSwitcher()
                Divider()

                Picker("Group", selection: $group) {
                    ForEach(ScheduleGroup.allCases, id: \.self) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                if group == .sessions {
                    SessionsSidebarList(selectedBooking: $selectedBooking,
                                       searchText: $searchText)
                } else {
                    List(visibleSections, selection: $selectedSection) { section in
                        Label(section.rawValue, systemImage: section.systemImage)
                            .tag(section)
                    }
                    .listStyle(.sidebar)
                }

                Divider()
                SidebarSearchField(
                    text: $searchText,
                    prompt: "Search…"
                )
            }
            .toolbarBackground(AppTab.schedule.sidebarTint.opacity(0.55), for: .navigationBar)
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
        } detail: {
            NavigationStack {
                if group == .sessions {
                    if let booking = selectedBooking {
                        BookingDetailView(booking: booking)
                    } else {
                        ContentUnavailableView(
                            "Select a Booking",
                            systemImage: "calendar.badge.clock",
                            description: Text("Choose a booking from the list.")
                        )
                    }
                } else if let section = selectedSection {
                    detailView(for: section)
                } else {
                    ContentUnavailableView(
                        "Select a View",
                        systemImage: "book",
                        description: Text("Choose a view from the sidebar.")
                    )
                }
            }
        }
        .onChange(of: group) {
            selectedSection = group == .sessions ? nil : visibleSections.first
            selectedBooking = nil
            searchText = ""
        }
        .onAppear { consumePendingBooking() }
        .onChange(of: coordinator.pendingBooking) { _, _ in consumePendingBooking() }
    }

    // MARK: - Detail view dispatcher (Tasks / Calendar)

    @ViewBuilder
    private func detailView(for section: ScheduleSection) -> some View {
        switch section {
        case .todo:    ToDoView(embedded: true)
        case .list:    BookingCalendarView(embedded: true, initialMode: .list)
        case .weekly:  BookingCalendarView(embedded: true, initialMode: .week)
        case .monthly: BookingCalendarView(embedded: true, initialMode: .month)
        // case .daily:   BookingCalendarView(embedded: true, initialMode: ) //TODO: Fix daily
        }
    }

    // MARK: - Deep-link consumer

    private func consumePendingBooking() {
        guard let booking = coordinator.pendingBooking else { return }
        coordinator.pendingBooking = nil
        group           = .sessions
        selectedSection = nil
        Task { @MainActor in selectedBooking = booking }
    }
}
