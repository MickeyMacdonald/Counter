import SwiftUI
import SwiftData

// MARK: - Sessions Sidebar Section

enum SessionsSection: String, CaseIterable, Hashable, Identifiable {
    case availability = "Availability"
    case todo         = "To Do"
    case list         = "List View"
    case nextWeek     = "Next Week"
    case month        = "Month View"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .availability: "clock"
        case .todo:         "checklist"
        case .list:         "list.bullet"
        case .nextWeek:     "calendar.badge.clock"
        case .month:        "calendar"
        }
    }
}

// MARK: - Sessions Tab

struct SessionsTabView: View {
    @Binding var selectedTab: AppTab
    @State private var selectedSection: SessionsSection? = .list
    @State private var searchText = ""

    private var filteredSections: [SessionsSection] {
        guard !searchText.isEmpty else { return SessionsSection.allCases }
        return SessionsSection.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                AppTabSwitcher(selectedTab: $selectedTab)
                Divider()
                List(filteredSections, selection: $selectedSection) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
                .listStyle(.sidebar)
                Divider()
                SidebarSearchField(text: $searchText, prompt: "Search...")
            }
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
    }

    @ViewBuilder
    private func detailView(for section: SessionsSection) -> some View {
        switch section {
        case .availability:
            SettingsBookingView()
        case .todo:
            ToDoView(embedded: true)
        case .list:
            BookingCalendarView(embedded: true, initialMode: .list)
        case .nextWeek:
            BookingCalendarView(embedded: true, initialMode: .week)
        case .month:
            BookingCalendarView(embedded: true, initialMode: .month)
        }
    }
}

#Preview {
    SessionsTabView(selectedTab: .constant(.sessions))
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}
