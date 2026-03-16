import SwiftUI
import SwiftData

// MARK: - Sessions Group (top-level picker)

enum SessionsGroup: String, CaseIterable {
    case tasks    = "Tasks"
    case schedule = "Schedule"
}

// MARK: - Sessions Sidebar Section

enum SessionsSection: String, CaseIterable, Hashable, Identifiable {
    case todo    = "To Do"
    case list    = "List View"
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

    var group: SessionsGroup {
        switch self {
        case .todo, .list:      .tasks
        case .weekly, .monthly: .schedule
        }
    }
}

// MARK: - Sessions Tab

struct SessionsTabView: View {
    @Binding var selectedTab: AppTab
    @State private var group: SessionsGroup = .tasks
    @State private var selectedSection: SessionsSection? = .list
    @State private var searchText = ""

    private var visibleSections: [SessionsSection] {
        let base = SessionsSection.allCases.filter { $0.group == group }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                AppTabSwitcher(selectedTab: $selectedTab)
                Divider()
                Picker("Group", selection: $group) {
                    ForEach(SessionsGroup.allCases, id: \.self) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                Divider()
                List(visibleSections, selection: $selectedSection) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
                .listStyle(.sidebar)
                Divider()
                SidebarSearchField(text: $searchText, prompt: "Search...")
            }
            .toolbarBackground(AppTab.sessions.sidebarTint.opacity(0.55), for: .navigationBar)
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
        } detail: {
            NavigationStack {
                if let section = selectedSection {
                    detailView(for: section)
                } else {
                    ContentUnavailableView(
                        "Select a View",
                        systemImage: "calendar",
                        description: Text("Choose a view from the sidebar.")
                    )
                }
            }
        }
        .onChange(of: group) {
            selectedSection = visibleSections.first
            searchText = ""
        }
    }

    @ViewBuilder
    private func detailView(for section: SessionsSection) -> some View {
        switch section {
        case .todo:    ToDoView(embedded: true)
        case .list:    BookingCalendarView(embedded: true, initialMode: .list)
        case .weekly:  BookingCalendarView(embedded: true, initialMode: .week)
        case .monthly: BookingCalendarView(embedded: true, initialMode: .month)
        }
    }
}

#Preview {
    SessionsTabView(selectedTab: .constant(.sessions))
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}
