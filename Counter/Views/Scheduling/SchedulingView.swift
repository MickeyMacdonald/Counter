import SwiftUI
import SwiftData

// MARK: - Bookings Group (top-level picker)

enum ScheduleGroup: String, CaseIterable {
    case sessions = "Sessions"
    case tasks    = "Tasks"
    case schedule = "Schedule"
}

// MARK: - Bookings Sidebar Section
// Used only for the Tasks, Scheduling and Sessions. Calendar functionality
// The Sessions group renders its own item list directly in the sidebar.

enum ScheduleSection: String, CaseIterable, Hashable, Identifiable {
    case todo    = "To Do"
    case list    = "Upcoming"
    case weekly  = "Weekly View"
    case monthly = "Monthly View"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .todo:    "checklist"
        case .list:    "list.bullet"
        case .weekly:  "calendar.badge.clock"
        case .monthly: "calendar"
        }
    }

    var group: ScheduleGroup {
        switch self {
        case .todo, .list:      .tasks
        case .weekly, .monthly: .schedule
        }
    }
}

// MARK: - Scheduling Tab

struct SchedulingView: View {
    @Environment(AppNavigationCoordinator.self) private var coordinator

    @State private var group: ScheduleGroup            = .tasks
    @State private var selectedSection: ScheduleSection? = .list
    @State private var selectedSession: TattooSession?   = nil
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
                    // Sessions group: actual session rows fill the sidebar
                    SessionsSidebarList(selectedSession: $selectedSession,
                                        searchText: $searchText)
                } else {
                    // Tasks / Schedule groups: section links
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
                    if let session = selectedSession {
                        SessionDetailView(session: session)
                    } else {
                        ContentUnavailableView(
                            "Select a Session",
                            systemImage: "clock.arrow.2.circlepath",
                            description: Text("Choose a session from the list.")
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
            selectedSession = nil
            searchText = ""
        }
        // Deep-link: navigate to a specific session in the Sessions sidebar
        .onAppear { consumePendingSession() }
        .onChange(of: coordinator.pendingSession) { _, _ in consumePendingSession() }
    }

    // MARK: - Detail view dispatcher (Tasks / Schedule)

    @ViewBuilder
    private func detailView(for section: ScheduleSection) -> some View {
        switch section {
        case .todo:    ToDoView(embedded: true)
        case .list:    BookingCalendarView(embedded: true, initialMode: .list)
        case .weekly:  BookingCalendarView(embedded: true, initialMode: .week)
        case .monthly: BookingCalendarView(embedded: true, initialMode: .month)
        }
    }

    // MARK: - Deep-link consumer

    private func consumePendingSession() {
        guard let session = coordinator.pendingSession else { return }
        // Clear pending immediately so onChange(of: group) doesn't see it
        coordinator.pendingSession = nil
        group           = .sessions
        selectedSection = nil
        // Defer selection to next run-loop tick so onChange(of: group) fires first
        // and its `selectedSession = nil` reset doesn't overwrite our value.
        Task { @MainActor in selectedSession = session }
    }
}
