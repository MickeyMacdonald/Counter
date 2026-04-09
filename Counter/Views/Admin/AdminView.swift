import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum AdminFilter: String, CaseIterable {
    case settings  = "Settings"
    case analytics = "Analytics"
    case financial = "Financials"
}

enum SettingsCategory: String, CaseIterable, Identifiable {
    // Settings
    case profile        = "Profile"
    case emailTemplates = "Email Templates"
    case schedule       = "Schedule"
    case rates          = "Rates"
    case about          = "About"
    case recovery       = "Recovery"
    case support        = "Support Counter"

    case clientMode     = "Client Mode"
    case pieces         = "Pieces"
    
    // Analytics
    case statistics     = "Statistics"
    case trends         = "Trends"
    
    // Financials
    case financial      = "Financials"
    case reports        = "Reports"
    case paymentHistory = "Payment History"
    
    // Settings/Analysis Filter
    var id: String { rawValue }

    var adminFilter: AdminFilter {
        switch self {
        case .profile,
                .emailTemplates,
                .about,
                .recovery,
                .support,
                .clientMode,
                .pieces,
                .rates,
                .schedule:
            return .settings
        case .statistics,
                .trends:
            return .analytics
        case .financial,
                .reports,
                .paymentHistory:
            return .financial
        }
    }

    // Icons
    var systemImage: String {
        switch self {
        case .profile:        "person.crop.circle"
        case .emailTemplates: "envelope.open.fill"
        case .about:          "info.circle"
        case .support:        "heart.fill"
        case .statistics:     "chart.bar.fill"
        case .trends:         "chart.line.uptrend.xyaxis"
        case .financial:      "dollarsign.circle.fill"
        case .reports:        "doc.text.magnifyingglass"
        case .paymentHistory: "banknote"
        case .clientMode:     "lock.shield"
        case .pieces:         "paintbrush.pointed.fill"
        case .recovery:       "arrow.clockwise.icloud"
        case .schedule:       "book.badge.plus"
        case .rates :         "plus.forwardslash.minus"
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
    private static let settingsItems:  [SettingsCategory] = [.profile,
                                                             .pieces,
                                                             .clientMode,
                                                             .emailTemplates,
                                                             .schedule,
                                                             .rates,
                                                             .about,
                                                             .recovery,
                                                             .support,]
    private static let analyticsItems: [SettingsCategory] = [.statistics, .trends]
    private static let financialItems: [SettingsCategory] = [.financial,
                                                             .reports,
                                                            .paymentHistory]

    
    private var visibleCategories: [SettingsCategory] {
        
        let base: [SettingsCategory]

        switch adminFilter {
        case .settings:
            base = Self.settingsItems
        case .analytics:
            base = Self.analyticsItems
        case .financial:
            base = Self.financialItems
        }
        
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
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
                        Label(category.rawValue, systemImage: category.systemImage)
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
        case .rates:
            SettingsViewFinancial()
        }
    }
}



