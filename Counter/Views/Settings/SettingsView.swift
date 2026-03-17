import SwiftUI
import SwiftData

enum AdminFilter: String, CaseIterable {
    case settings  = "Settings"
    case analytics = "Analytics"
}

enum SettingsCategory: String, CaseIterable, Identifiable {
    // Settings
    case profile        = "Profile"
    case emailTemplates = "Email Templates"
    case about          = "About"
    case support        = "Support Counter"
    // Analytics
    case statistics     = "Statistics"
    case financial      = "Financials"
    case reports        = "Reports"
    // Hidden (accessible elsewhere)
    case sessionRates   = "Session Rates"
    case clientMode     = "Client Mode"

    var id: String { rawValue }

    var adminFilter: AdminFilter {
        switch self {
        case .profile, .emailTemplates, .about, .support:
            return .settings
        case .statistics, .financial, .reports:
            return .analytics
        case .sessionRates, .clientMode:
            return .settings
        }
    }

    var systemImage: String {
        switch self {
        case .profile:        "person.crop.circle"
        case .emailTemplates: "envelope.open.fill"
        case .about:          "info.circle"
        case .support:        "heart.fill"
        case .statistics:     "chart.bar.fill"
        case .financial:      "dollarsign.circle.fill"
        case .reports:        "doc.text.magnifyingglass"
        case .sessionRates:   "banknote"
        case .clientMode:     "lock.shield"
        }
    }
}

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedCategory: SettingsCategory? = .profile
    @State private var searchText = ""
    @State private var adminFilter: AdminFilter = .settings

    private var profile: UserProfile? { profiles.first }

    private static let settingsItems:  [SettingsCategory] = [.profile, .emailTemplates, .about, .support]
    private static let analyticsItems: [SettingsCategory] = [.statistics, .financial, .reports]

    private var visibleCategories: [SettingsCategory] {
        let base = adminFilter == .settings ? Self.settingsItems : Self.analyticsItems
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

    @ViewBuilder
    private func settingsDetail(for category: SettingsCategory) -> some View {
        switch category {
        case .profile:
            SettingsProfileView(profile: profile)
        case .emailTemplates:
            SettingsEmailTemplatesView()
        case .about:
            SettingsAboutView()
        case .support:
            SettingsDonationView()
        case .statistics:
            SettingsStatisticsView()
        case .financial:
            FinancialDashboardView(embedded: true)
        case .reports:
            SettingsReportsView()
        case .sessionRates:
            SettingsSessionRatesView()
        case .clientMode:
            SettingsClientModeView()
        }
    }
}

// MARK: - Profile

struct SettingsProfileView: View {
    let profile: UserProfile?
    @State private var showingEditProfile = false

    var body: some View {
        List {
            if let profile {
                // Identity card
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(.primary.opacity(0.08))
                                .frame(width: 72, height: 72)
                            Text(profile.initialsDisplay)
                                .font(.system(.title, design: .monospaced, weight: .bold))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.fullName)
                                .font(.title3.weight(.bold))
                            if !profile.businessName.isEmpty {
                                Text(profile.businessName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: profile.profession.systemImage)
                                    .font(.caption)
                                Text(profile.profession.rawValue)
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Contact
                Section("Contact") {
                    if !profile.email.isEmpty {
                        LabeledContent {
                            Text(profile.email).foregroundStyle(.secondary)
                        } label: {
                            Label("Email", systemImage: "envelope")
                        }
                    }
                    if !profile.phone.isEmpty {
                        LabeledContent {
                            Text(profile.phone).foregroundStyle(.secondary)
                        } label: {
                            Label("Phone", systemImage: "phone")
                        }
                    }
                    if profile.email.isEmpty && profile.phone.isEmpty {
                        Text("No contact info added.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                // Shop Address
                Section("Shop Address") {
                    if let summary = profile.shopAddressSummary {
                        Text(summary)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        Text("No shop address added.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                // Billing Address
                Section("Billing Address") {
                    if profile.billingMatchesShop {
                        Label("Same as shop address", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else if let summary = profile.billingAddressSummary {
                        Text(summary)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        Text("No billing address added.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        showingEditProfile = true
                    } label: {
                        Label("Edit Profile", systemImage: "pencil")
                    }
                }
            } else {
                noProfileView
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
        .sheet(isPresented: $showingEditProfile) {
            if let profile {
                ProfileEditView(profile: profile)
            }
        }
    }
}


// MARK: - Availability

struct SettingsAvailabilityView: View {
    @State private var showingAvailability = false

    var body: some View {
        List {
            Section {
                Button {
                    showingAvailability = true
                } label: {
                    Label("Manage Weekly Hours", systemImage: "clock.badge.checkmark")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Availability")
        .sheet(isPresented: $showingAvailability) {
            AvailabilityEditView()
        }
    }
}

// MARK: - Client Mode

struct SettingsClientModeView: View {
    @Environment(BusinessLockManager.self) private var lockManager
    @State private var showingSetPIN = false
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var pinMismatch = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(
                    get: { lockManager.isEnabled },
                    set: { newValue in
                        if newValue {
                            lockManager.enable()
                        } else {
                            lockManager.disable()
                        }
                    }
                )) {
                    Label("Enable Client Mode Lock", systemImage: "lock.shield")
                }

                if lockManager.isEnabled {
                    if lockManager.biometricsAvailable {
                        LabeledContent {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } label: {
                            Label(lockManager.biometricName, systemImage: lockManager.biometricIcon)
                        }
                    }

                    if lockManager.hasPIN {
                        Button(role: .destructive) {
                            lockManager.clearPIN()
                        } label: {
                            Label("Remove PIN", systemImage: "number.circle")
                        }
                    } else {
                        Button {
                            newPIN = ""
                            confirmPIN = ""
                            pinMismatch = false
                            showingSetPIN = true
                        } label: {
                            Label("Set a PIN", systemImage: "number.circle")
                        }
                    }

                    Button {
                        lockManager.lock()
                    } label: {
                        Label("Lock Now", systemImage: "lock.fill")
                    }
                }
            } footer: {
                Text("When locked, Financial and Settings tabs require authentication. Hand your device to clients safely.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Client Mode")
        .alert("Set PIN", isPresented: $showingSetPIN) {
            SecureField("Enter PIN", text: $newPIN)
                .keyboardType(.numberPad)
            SecureField("Confirm PIN", text: $confirmPIN)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if newPIN == confirmPIN && !newPIN.isEmpty {
                    lockManager.setPIN(newPIN)
                } else {
                    pinMismatch = true
                }
            }
        } message: {
            Text("Choose a numeric PIN for unlocking business views.")
        }
        .alert("PINs Don't Match", isPresented: $pinMismatch) {
            Button("Try Again") {
                newPIN = ""
                confirmPIN = ""
                showingSetPIN = true
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - About

struct SettingsAboutView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: "Pre-Alpha 0.2")
                LabeledContent("Build", value: "CounterPreAlpha")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
    }
}

// MARK: - Statistics

struct SettingsStatisticsView: View {
    @Query private var allClients: [Client]
    @Query private var allPieces: [Piece]
    @Query private var allSessions: [TattooSession]
    @Query private var allBookings: [Booking]
    @Query private var allPayments: [Payment]

    // MARK: Derived

    private var clients: [Client]         { allClients.filter { !$0.isFlashPortfolioClient } }
    private var customPieces: [Piece]     { allPieces.filter { $0.pieceType != .flash && $0.client?.isFlashPortfolioClient != true } }
    private var flashPieces: [Piece]      { allPieces.filter { $0.pieceType == .flash } }
    private var completedCustom: [Piece]  { customPieces.filter { $0.status == .completed } }
    private var completedFlash: [Piece]   { flashPieces.filter { $0.status == .completed } }

    private var totalProcessPhotos: Int {
        allPieces.reduce(0) { $0 + $1.allImages.count }
    }

    private var avgRating: Double? {
        let rated = completedCustom.compactMap(\.rating)
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0, +)) / Double(rated.count)
    }

    private var ratingDistribution: [(label: String, count: Int)] {
        (1...5).map { star in
            (label: String(repeating: "★", count: star), count: completedCustom.filter { $0.rating == star }.count)
        }
    }

    private var avgCostCustom: Decimal? {
        let priced = completedCustom.filter { $0.totalCost > 0 }
        guard !priced.isEmpty else { return nil }
        return priced.reduce(Decimal(0)) { $0 + $1.totalCost } / Decimal(priced.count)
    }

    private var avgCostFlash: Decimal? {
        let priced = completedFlash.filter { $0.totalCost > 0 }
        guard !priced.isEmpty else { return nil }
        return priced.reduce(Decimal(0)) { $0 + $1.totalCost } / Decimal(priced.count)
    }

    private var totalRevenue: Decimal {
        allPayments.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var totalOutstanding: Decimal {
        (customPieces + flashPieces).reduce(Decimal(0)) { $0 + $1.outstandingBalance }
    }

    private var avgHoursPerPiece: Double? {
        let timed = completedCustom.filter { $0.totalHours > 0 }
        guard !timed.isEmpty else { return nil }
        return timed.reduce(0.0) { $0 + $1.totalHours } / Double(timed.count)
    }

    private var totalHours: Double {
        allSessions.reduce(0.0) { $0 + $1.durationHours }
    }

    private var pieceStatusBreakdown: [(label: String, count: Int, color: Color)] {
        let statuses: [(PieceStatus, String, Color)] = [
            (.completed,         "Completed",     .green),
            (.inProgress,        "In Progress",   .blue),
            (.designInProgress,  "Designing",     .purple),
            (.scheduled,         "Scheduled",     .orange),
            (.approved,          "Approved",      .teal),
            (.touchUp,           "Touch-Up",      .yellow),
            (.healed,            "Healed",        .mint),
            (.concept,           "Concept",       .indigo),
            (.archived,          "Archived",      .gray),
        ]
        return statuses.compactMap { (status, label, color) in
            let count = customPieces.filter { $0.status == status }.count
            return count > 0 ? (label, count, color) : nil
        }
    }

    private var bookingTypeBreakdown: [(label: String, count: Int)] {
        let types: [(BookingType, String)] = [
            (.session,      "Session"),
            (.consultation, "Consult"),
            (.touchUp,      "Touch-Up"),
            (.flashPickup,  "Flash"),
        ]
        return types.compactMap { (type, label) in
            let count = allBookings.filter { $0.bookingType == type }.count
            return count > 0 ? (label, count) : nil
        }
    }

    private var repeatClients: Int {
        clients.filter { $0.pieces.count > 1 }.count
    }

    private var noShowCount: Int {
        allBookings.filter { $0.status == .noShow }.count
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {

                // Clients
                StatSection(title: "Clients", systemImage: "person.2.fill") {
                    StatGrid {
                        StatCard(value: "\(clients.count)",          label: "Total Clients")
                        StatCard(value: "\(repeatClients)",          label: "Repeat Clients")
                        StatCard(
                            value: "\(clients.filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month) }.count)",
                            label: "New This Month"
                        )
                        StatCard(
                            value: "\(clients.filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .year) }.count)",
                            label: "New This Year"
                        )
                    }
                }

                // Pieces
                StatSection(title: "Custom Pieces", systemImage: "pencil.and.ruler.fill") {
                    StatGrid {
                        StatCard(value: "\(customPieces.count)",    label: "Total")
                        StatCard(value: "\(completedCustom.count)", label: "Completed")
                        StatCard(value: totalProcessPhotos.formatted(), label: "Process Photos")
                        StatCard(
                            value: avgHoursPerPiece.map { String(format: "%.1fh", $0) } ?? "—",
                            label: "Avg Hours/Piece"
                        )
                    }
                    if !pieceStatusBreakdown.isEmpty {
                        StatusBreakdownRow(items: pieceStatusBreakdown)
                    }
                }

                // Flash
                StatSection(title: "Flash", systemImage: "bolt.fill") {
                    StatGrid {
                        StatCard(value: "\(flashPieces.count)",    label: "Total Flash")
                        StatCard(value: "\(completedFlash.count)", label: "Sold")
                        StatCard(
                            value: avgCostFlash.map { "$\(NSDecimalNumber(decimal: $0).intValue)" } ?? "—",
                            label: "Avg Price"
                        )
                        StatCard(
                            value: "\(flashPieces.filter { $0.status != .completed }.count)",
                            label: "Available"
                        )
                    }
                }

                // Time & Sessions
                StatSection(title: "Time & Sessions", systemImage: "clock.fill") {
                    StatGrid {
                        StatCard(value: String(format: "%.0fh", totalHours),  label: "Total Hours")
                        StatCard(value: "\(allSessions.count)",                label: "Sessions")
                        StatCard(value: "\(allBookings.count)",                label: "Bookings")
                        StatCard(value: "\(noShowCount)",                      label: "No-Shows")
                    }
                    if !bookingTypeBreakdown.isEmpty {
                        BreakdownPillRow(items: bookingTypeBreakdown)
                    }
                }

                // Financials
                StatSection(title: "Financials", systemImage: "dollarsign.circle.fill") {
                    StatGrid {
                        StatCard(
                            value: "$\(NSDecimalNumber(decimal: totalRevenue).intValue)",
                            label: "Total Revenue"
                        )
                        StatCard(
                            value: "$\(NSDecimalNumber(decimal: totalOutstanding).intValue)",
                            label: "Outstanding"
                        )
                        StatCard(
                            value: avgCostCustom.map { "$\(NSDecimalNumber(decimal: $0).intValue)" } ?? "—",
                            label: "Avg Custom Cost"
                        )
                        StatCard(
                            value: avgCostFlash.map { "$\(NSDecimalNumber(decimal: $0).intValue)" } ?? "—",
                            label: "Avg Flash Cost"
                        )
                    }
                }

                // Ratings
                if !ratingDistribution.allSatisfy({ $0.count == 0 }) {
                    StatSection(title: "Ratings", systemImage: "star.fill") {
                        if let avg = avgRating {
                            HStack(spacing: 6) {
                                Text(String(format: "%.1f", avg))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(repeating: "★", count: Int(avg.rounded())))
                                        .foregroundStyle(.yellow)
                                        .font(.title3)
                                    Text("avg across \(completedCustom.compactMap(\.rating).count) pieces")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        }
                        VStack(spacing: 6) {
                            ForEach(ratingDistribution.reversed(), id: \.label) { item in
                                HStack(spacing: 8) {
                                    Text(item.label)
                                        .font(.caption)
                                        .frame(width: 56, alignment: .leading)
                                        .foregroundStyle(.secondary)
                                    GeometryReader { geo in
                                        let maxCount = ratingDistribution.map(\.count).max() ?? 1
                                        let width = maxCount > 0 ? geo.size.width * CGFloat(item.count) / CGFloat(maxCount) : 0
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.yellow.opacity(0.7))
                                            .frame(width: max(width, item.count > 0 ? 4 : 0))
                                    }
                                    .frame(height: 16)
                                    Text("\(item.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Statistics")
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Stat Sub-views

private struct StatSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .padding(.horizontal, 20)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                content
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }
}

private struct StatGrid<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
            content
        }
        .padding(.vertical, 4)
    }
}

private struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

private struct StatusBreakdownRow: View {
    let items: [(label: String, count: Int, color: Color)]

    var body: some View {
        Divider().padding(.horizontal, 12)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], spacing: 6) {
            ForEach(items, id: \.label) { item in
                HStack(spacing: 4) {
                    Circle().fill(item.color).frame(width: 7, height: 7)
                    Text("\(item.label) \(item.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(item.color.opacity(0.08), in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct BreakdownPillRow: View {
    let items: [(label: String, count: Int)]

    var body: some View {
        Divider().padding(.horizontal, 12)
        HStack(spacing: 12) {
            ForEach(items, id: \.label) { item in
                VStack(spacing: 2) {
                    Text("\(item.count)").font(.headline)
                    Text(item.label).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}


// MARK: - Shared

var noProfileView: some View {
    ContentUnavailableView {
        Label("No Profile", systemImage: "person.crop.circle.badge.questionmark")
    } description: {
        Text("Set up your profile to get started.")
    }
}

#Preview {
    SettingsView()
        .environment(AppNavigationCoordinator())
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}
