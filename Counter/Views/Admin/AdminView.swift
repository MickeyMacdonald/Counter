import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum AdminFilter: String, CaseIterable {
    case settings  = "Settings"
    case analytics = "Analytics"
    case archive   = "Archive"
}

enum SettingsCategory: String, CaseIterable, Identifiable {
    // Settings
    case profile        = "profile"
    case emailTemplates = "emailTemplates"
    case schedule       = "schedule"
    case rates          = "rates"
    case about          = "about"
    case appIcon        = "appIcon"
    case recovery       = "recovery"
    case support        = "support"
    case clientMode     = "clientMode"
    case pieces         = "pieces"
    case taskTemplates  = "taskTemplates"
    case notifications  = "notifications"

    // Analytics
    case statistics     = "statistics"
    case trends         = "trends"
    case financial      = "financial"
    case reports        = "reports"
    case paymentHistory = "paymentHistory"

    // Archive
    case clientRecords    = "clientRecords"
    case archivedPieces   = "archivedPieces"
    case archivedBookings = "archivedBookings"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .profile:          "Profile"
        case .emailTemplates:   "Email Templates"
        case .schedule:         "Schedule"
        case .rates:            "Rates"
        case .about:            "About"
        case .appIcon:          "App Icon"
        case .recovery:         "Recovery"
        case .support:          "Support Counter"
        case .clientMode:       "Client Mode"
        case .pieces:           "Pieces"
        case .taskTemplates:    "Task Templates"
        case .notifications:    "Notifications"
        case .statistics:       "Statistics"
        case .trends:           "Trends"
        case .financial:        "Financials"
        case .reports:          "Reports"
        case .paymentHistory:   "Payment History"
        case .clientRecords:    "Client Records"
        case .archivedPieces:   "Pieces"
        case .archivedBookings: "Bookings"
        }
    }

    var adminFilter: AdminFilter {
        switch self {
        case .profile, .emailTemplates, .about, .appIcon, .recovery, .support,
             .clientMode, .pieces, .rates, .schedule, .taskTemplates, .notifications:
            return .settings
        case .statistics, .trends, .financial, .reports, .paymentHistory:
            return .analytics
        case .clientRecords, .archivedPieces, .archivedBookings:
            return .archive
        }
    }

    var systemImage: String {
        switch self {
        case .profile:          "person.crop.circle"
        case .emailTemplates:   "envelope.open.fill"
        case .about:            "info.circle"
        case .appIcon:          "app.badge"
        case .support:          "heart.fill"
        case .clientRecords:    "person.text.rectangle.fill"
        case .statistics:       "chart.bar.fill"
        case .trends:           "chart.line.uptrend.xyaxis"
        case .financial:        "dollarsign.circle.fill"
        case .reports:          "doc.text.magnifyingglass"
        case .paymentHistory:   "banknote"
        case .clientMode:       "lock.shield"
        case .pieces:           "paintbrush.pointed.fill"
        case .recovery:         "arrow.clockwise.icloud"
        case .schedule:         "book.badge.plus"
        case .rates:            "plus.forwardslash.minus"
        case .taskTemplates:    "checklist"
        case .notifications:    "bell.fill"
        case .archivedPieces:   "paintbrush.pointed"
        case .archivedBookings: "calendar.badge.minus"
        }
    }
}

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    
    //Sidebar State
    @State private var selectedCategory: SettingsCategory? = .profile
    @State private var searchText = ""
    @State private var adminFilter: AdminFilter = .settings

    private var profile: UserProfile? { profiles.first }

    // Sub-categories Order
    private static let settingsItems:  [SettingsCategory] = [
        .profile, .pieces, .clientMode, .emailTemplates,
        .schedule, .taskTemplates, .notifications, .rates,
        .about, .appIcon, .recovery, .support,
    ]
    private static let analyticsItems: [SettingsCategory] = [
        .statistics, .trends, .financial, .reports, .paymentHistory,
    ]
    private static let archiveItems:   [SettingsCategory] = [
        .clientRecords, .archivedPieces, .archivedBookings,
    ]

    
    private var visibleCategories: [SettingsCategory] {
        
        let base: [SettingsCategory]

        switch adminFilter {
        case .settings:
            base = Self.settingsItems
        case .analytics:
            base = Self.analyticsItems
        case .archive:
            base = Self.archiveItems
        }
        
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.label.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                AppTabSwitcher()
                Divider()
                Picker("Admin Filter", selection: $adminFilter) {
                    ForEach(AdminFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                Divider()
                List(visibleCategories, selection: $selectedCategory) { category in
                    NavigationLink(value: category) {
                        Label(category.label, systemImage: category.systemImage)
                            .foregroundStyle(category == .support ? Color.pink : Color.primary)
                    }
                }
                .listStyle(.sidebar)
                Divider()
                SidebarSearchField(text: $searchText, prompt: "Search...")
            }
            .toolbarBackground(AppTab.settings.sidebarTint.opacity(0.55), for: .navigationBar)
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: adminFilter) {
                if let current = selectedCategory,
                   !visibleCategories.contains(current) {
                    selectedCategory = visibleCategories.first
                }
            }
        } detail: {
            if let selectedCategory {
                NavigationStack {
                    settingsDetail(for: selectedCategory)
                }
            } else {
                ContentUnavailableView(
                    "Select a Category",
                    systemImage: "gearshape",
                    description: Text("Choose a settings category from the list.")
                )
            }
        }
    }

    // SettingView File Sync
    @ViewBuilder
    private func settingsDetail(for category: SettingsCategory) -> some View {
        switch category {
        case .trends:
            AnalyticsViewTrends()
        case .profile:
            SettingsProfileView(profile: profile)
        case .emailTemplates:
            SettingsViewEmailTemplates()
        case .about:
            SettingsAboutView()
        case .appIcon:
            SettingsAppIconView()
        case .statistics:
            SettingsStatisticsView()
        case .schedule:
            SettingsViewBooking()
        case .financial:
            FinancialDashboardView(embedded: true)
        case .reports:
            SettingsViewReports()
        case .paymentHistory:
            PaymentHistoryView()
        case .clientMode:
            SettingsClientModeView()
        case .pieces:
            SettingsViewPieces()
        case .recovery:
            SettingsViewRecovery()
        case .support:
            SettingsViewDonation()
        case .taskTemplates:
            SettingsViewTaskTemplates()
        case .notifications:
            SettingsViewNotifications()
        case .rates:
            SettingsViewFinancial()
        case .clientRecords:
            AdminClientManagementView()
        case .archivedPieces:
            ArchiveViewPieces()
        case .archivedBookings:
            ArchiveViewBookings()
        }
    }
}



