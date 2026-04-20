import SwiftUI
import SwiftData

// MARK: - Admin Gallery Group

enum AdminGalleryGroup: String, CaseIterable {
    case all       = "All"
    case portfolio = "Portfolio"
    case flash     = "Flash"
}

// MARK: - All Filter (Admin)

enum AllFilter: String, CaseIterable, Hashable, Identifiable {
    case client      = "Client"
    case piece       = "Piece"
    case placement   = "Placement"
    case sessionType = "Session Type"
    case rating      = "Rating"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .client:      "person.2.fill"
        case .piece:       "paintbrush.pointed.fill"
        case .placement:   "figure.arms.open"
        case .sessionType: "square.stack.3d.up.fill"
        case .rating:      "star.fill"
        }
    }
}

// MARK: - Portfolio Sidebar Selection (Admin)

enum PortfolioSelection: Hashable {
    case customGroup(PersistentIdentifier)
    case flash
}

// MARK: - Flash Admin Filter

enum FlashAdminFilter: String, CaseIterable, Hashable, Identifiable {
    case size  = "Size"
    case price = "Price"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .size:  "arrow.up.left.and.arrow.down.right"
        case .price: "dollarsign.circle"
        }
    }
}

// MARK: - Client Gallery Group

enum ClientGalleryGroup: String, CaseIterable {
    case portfolio      = "Portfolio"
    case availableFlash = "Available Flash"
}

// MARK: - Portfolio Filter (Client)

enum PortfolioFilter: String, CaseIterable, Hashable, Identifiable {
    case placement = "Placement"
    case size      = "Size"
    case stage     = "Stage"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .placement: "figure.arms.open"
        case .size:      "arrow.up.left.and.arrow.down.right"
        case .stage:     "square.stack.3d.up.fill"
        }
    }
}

// MARK: - Gallery Sort Order

enum GallerySortOrder: String, CaseIterable {
    case chronological = "Chronological"
    case rating        = "Rating"

    var systemImage: String {
        switch self {
        case .chronological: "clock"
        case .rating:        "star.fill"
        }
    }
}

// MARK: - Gallery Tab

struct GalleryTabView: View {
    @Query(sort: \Piece.updatedAt, order: .reverse) private var allPieces: [Piece]
    @Query(sort: \Client.lastName) private var allClients: [Client]
    @Query(sort: \GalleryGroup.sortIndex) private var customGroups: [GalleryGroup]
    @Environment(\.modelContext) private var modelContext
    @Environment(BusinessLockManager.self) private var lockManager
    @Environment(AppNavigationCoordinator.self) private var coordinator

    // Admin state
    @State private var adminGroup: AdminGalleryGroup = .all
    @State private var allFilter: AllFilter? = .client
    @State private var portfolioSelection: PortfolioSelection? = .flash
    @State private var flashFilter: FlashAdminFilter? = .size
    @State private var clientFilter: Client? = nil
    @State private var categoryFilter: Set<ImageCategory> = []

    // Client state
    @State private var clientGroup: ClientGalleryGroup = .portfolio
    @State private var portfolioFilter: PortfolioFilter? = .placement

    // Shared
    @State private var sortOrder: GallerySortOrder = .chronological
    @State private var searchText = ""

    // Custom group creation
    @State private var showAddCustomGroup = false
    @State private var newGroupName = ""
    @State private var newGroupTags = ""

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                if !lockManager.isLocked {
                    AppTabSwitcher()
                    Divider()
                    Picker("", selection: $adminGroup) {
                        ForEach(AdminGalleryGroup.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    Divider()
                    adminSidebar
                } else {
                    Picker("", selection: $clientGroup) {
                        ForEach(ClientGalleryGroup.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    Divider()
                    clientSidebar
                }
                if showsSearchBar {
                    Divider()
                    SidebarSearchField(text: $searchText, prompt: "Search...")
                }
            }
            .toolbarBackground(AppTab.gallery.sidebarTint.opacity(0.55), for: .navigationBar)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
        } detail: {
            VStack(spacing: 0) {
                if lockManager.isEnabled {
                    ClientLockBanner(lockManager: lockManager)
                }
                NavigationStack {
                    if !lockManager.isLocked {
                        adminDetail
                    } else {
                        clientDetail
                    }
                }
            }
        }
        .onChange(of: coordinator.pendingGalleryClient) { _, client in
            guard let client else { return }
            adminGroup = .all
            allFilter = .client
            clientFilter = client
            coordinator.pendingGalleryClient = nil
        }
        .onChange(of: adminGroup) {
            searchText = ""
            clientFilter = nil
            categoryFilter = []
            if adminGroup == .portfolio, portfolioSelection == nil {
                portfolioSelection = customGroups.first.map { .customGroup($0.persistentModelID) } ?? .flash
            }
        }
        .onChange(of: allFilter) {
            if allFilter != .client { clientFilter = nil }
            categoryFilter = []
        }
        .onChange(of: lockManager.isLocked) {
            if lockManager.isLocked { sortOrder = .chronological }
        }
        .alert("New Custom Group", isPresented: $showAddCustomGroup) {
            TextField("Group Name", text: $newGroupName)
            TextField("Tags (comma-separated)", text: $newGroupTags)
            Button("Create") { createCustomGroup() }
            Button("Cancel", role: .cancel) { resetNewGroupForm() }
        } message: {
            Text("Pieces with matching tags will appear in this group.")
        }
    }

    // MARK: - Sidebar Content

    @ViewBuilder
    private var adminSidebar: some View {
        switch adminGroup {
        case .all:
            List(AllFilter.allCases, selection: $allFilter) { filter in
                NavigationLink(value: filter) {
                    Label(filter.rawValue, systemImage: filter.systemImage)
                }
            }
            .listStyle(.sidebar)

        case .portfolio:
            List(selection: $portfolioSelection) {
                Section("Custom") {
                    ForEach(customGroups) { group in
                        Label(group.name, systemImage: "tag.fill")
                            .tag(PortfolioSelection.customGroup(group.persistentModelID))
                    }
                    Button {
                        showAddCustomGroup = true
                    } label: {
                        Label("New Group", systemImage: "plus")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Section("Flash") {
                    Label("Flash Portfolio", systemImage: "bolt.fill")
                        .tag(PortfolioSelection.flash)
                }
            }
            .listStyle(.sidebar)

        case .flash:
            List(FlashAdminFilter.allCases, selection: $flashFilter) { filter in
                NavigationLink(value: filter) {
                    Label(filter.rawValue, systemImage: filter.systemImage)
                }
            }
            .listStyle(.sidebar)
        }
    }

    @ViewBuilder
    private var clientSidebar: some View {
        switch clientGroup {
        case .portfolio:
            List(PortfolioFilter.allCases, selection: $portfolioFilter) { filter in
                NavigationLink(value: filter) {
                    Label(filter.rawValue, systemImage: filter.systemImage)
                }
            }
            .listStyle(.sidebar)
        case .availableFlash:
            Spacer()
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var adminDetail: some View {
        switch adminGroup {
        case .all:
            if let filter = allFilter {
                VStack(spacing: 0) {
                    ImageCategoryFilterBar(activeCategories: $categoryFilter)
                    Divider()
                    allDetailView(for: filter)
                }
                .navigationTitle(filter.rawValue)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { sortMenu }
                }
            } else {
                ContentUnavailableView("Select a Category", systemImage: "photo.on.rectangle.angled",
                                       description: Text("Choose a category from the sidebar."))
            }

        case .portfolio:
            switch portfolioSelection {
            case .flash:
                FlashPortfolioView()
                    .navigationTitle("Flash")
            case .customGroup(let id):
                if let group = customGroups.first(where: { $0.persistentModelID == id }) {
                    GalleryByCustomGroupView(group: group, pieces: sortedPieces)
                        .navigationTitle(group.name)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { sortMenu }
                        }
                } else {
                    ContentUnavailableView("Group Not Found", systemImage: "tag",
                                           description: Text("This group may have been deleted."))
                }
            case nil:
                ContentUnavailableView("Select a Group", systemImage: "tag",
                                       description: Text("Choose a group from the sidebar."))
            }

        case .flash:
            if let filter = flashFilter {
                flashDetailView(for: filter)
                    .navigationTitle(filter.rawValue)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { sortMenu }
                    }
            } else {
                ContentUnavailableView("Select a Category", systemImage: "bolt",
                                       description: Text("Choose a category from the sidebar."))
            }
        }
    }

    @ViewBuilder
    private var clientDetail: some View {
        switch clientGroup {
        case .portfolio:
            if let filter = portfolioFilter {
                portfolioDetailView(for: filter)
                    .navigationTitle(filter.rawValue)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { sortMenu }
                    }
            } else {
                ContentUnavailableView("Select a Category", systemImage: "photo.on.rectangle.angled",
                                       description: Text("Choose a category from the sidebar."))
            }
        case .availableFlash:
            AvailableFlashGalleryView()
                .navigationTitle("Available Flash")
        }
    }

    @ViewBuilder
    private func allDetailView(for filter: AllFilter) -> some View {
        switch filter {
        case .client:
            let displayed = clientFilter.map { [$0] } ?? clientsWithImages
            GalleryByClientView(clients: displayed, categoryFilter: categoryFilter)
        case .piece:       GalleryByPieceView(pieces: sortedPieces, categoryFilter: categoryFilter)
        case .placement:   GalleryByPlacementView(pieces: sortedPieces, categoryFilter: categoryFilter)
        case .sessionType: GalleryByStageView(pieces: sortedPieces, categoryFilter: categoryFilter)
        case .rating:      GalleryByRatingView(pieces: sortedPieces, categoryFilter: categoryFilter)
        }
    }

    @ViewBuilder
    private func flashDetailView(for filter: FlashAdminFilter) -> some View {
        switch filter {
        case .size:  GalleryBySizeView(pieces: sortedPieces)
        case .price: GalleryByPriceView(pieces: sortedPieces)
        }
    }

    @ViewBuilder
    private func portfolioDetailView(for filter: PortfolioFilter) -> some View {
        switch filter {
        case .placement: GalleryByPlacementView(pieces: sortedPieces)
        case .size:      GalleryBySizeView(pieces: sortedPieces)
        case .stage:     GalleryByStageView(pieces: sortedPieces)
        }
    }

    // MARK: - Sort Menu

    @ViewBuilder
    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sortOrder) {
                Label(GallerySortOrder.chronological.rawValue,
                      systemImage: GallerySortOrder.chronological.systemImage)
                    .tag(GallerySortOrder.chronological)
                if !lockManager.isLocked {
                    Label(GallerySortOrder.rating.rawValue,
                          systemImage: GallerySortOrder.rating.systemImage)
                        .tag(GallerySortOrder.rating)
                }
            }
        } label: {
            Image(systemName: sortOrder == .chronological ? "arrow.up.arrow.down" : "star.fill")
        }
    }

    // MARK: - Helpers

    private var showsSearchBar: Bool {
        if lockManager.isLocked { return clientGroup == .portfolio }
        return adminGroup == .all || adminGroup == .portfolio
    }

    // MARK: - Derived Data

    private var filteredPieces: [Piece] {
        let base = allPieces.filter { $0.client?.isFlashPortfolioClient != true }
        guard !searchText.isEmpty else { return base }
        return base.filter { piece in
            piece.title.localizedCaseInsensitiveContains(searchText) ||
            piece.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
            piece.client?.fullName.localizedCaseInsensitiveContains(searchText) == true ||
            piece.bodyPlacement.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sortedPieces: [Piece] {
        switch sortOrder {
        case .chronological: return filteredPieces
        case .rating:        return filteredPieces.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        }
    }

    private var clientsWithImages: [Client] {
        let filtered: [Client]
        if searchText.isEmpty {
            filtered = allClients.filter { !$0.isFlashPortfolioClient }
        } else {
            let q = searchText.lowercased()
            filtered = allClients.filter {
                !$0.isFlashPortfolioClient &&
                ($0.fullName.lowercased().contains(q) ||
                 $0.pieces.contains { $0.title.lowercased().contains(q) })
            }
        }
        let withImages = filtered.filter { client in
            client.pieces.contains { !$0.allImages.isEmpty }
        }
        switch sortOrder {
        case .chronological:
            return withImages.sorted { $0.updatedAt > $1.updatedAt }
        case .rating:
            return withImages.sorted {
                let r0 = $0.pieces.compactMap(\.rating).max() ?? 0
                let r1 = $1.pieces.compactMap(\.rating).max() ?? 0
                return r0 > r1
            }
        }
    }

    // MARK: - Custom Group Management

    private func createCustomGroup() {
        guard !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty else {
            resetNewGroupForm()
            return
        }
        let tags = newGroupTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let group = GalleryGroup(
            name: newGroupName.trimmingCharacters(in: .whitespaces),
            tags: tags,
            sortIndex: customGroups.count
        )
        modelContext.insert(group)
        portfolioSelection = .customGroup(group.persistentModelID)
        resetNewGroupForm()
    }

    private func resetNewGroupForm() {
        newGroupName = ""
        newGroupTags = ""
    }
}

// MARK: - Image Category Filter Bar

struct ImageCategoryFilterBar: View {
    @Binding var activeCategories: Set<ImageCategory>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ImageCategory.allCases, id: \.self) { category in
                    let isActive = activeCategories.contains(category)
                    Button {
                        if isActive {
                            activeCategories.remove(category)
                        } else {
                            activeCategories.insert(category)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: category.systemImage)
                                .font(.caption2)
                            Text(category.rawValue)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isActive ? Color.accentColor : Color.primary.opacity(0.07),
                                    in: Capsule())
                        .foregroundStyle(isActive ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: isActive)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Client Lock Banner

struct ClientLockBanner: View {
    let lockManager: BusinessLockManager
    @AppStorage("business.authMethod") private var authMethod: String = "auto"
    @State private var showPINEntry = false
    @State private var pinInput = ""
    @State private var pinError = false

    var body: some View {
        Button {
            if lockManager.isLocked {
                if authMethod == "pin" {
                    showPINEntry = true
                } else {
                    Task {
                        let success = await lockManager.unlockWithBiometrics()
                        if !success { showPINEntry = true }
                    }
                }
            } else {
                lockManager.lock()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: lockManager.isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(lockManager.isLocked ? "Exit Client Mode" : "Enter Client Mode")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: lockManager.isLocked
                      ? (authMethod == "pin" ? "number.circle" : lockManager.biometricIcon)
                      : "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(lockManager.isLocked ? .primary : .tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                lockManager.isLocked
                    ? Color.orange.opacity(0.12)
                    : Color.accentColor.opacity(0.1)
            )
            .foregroundStyle(lockManager.isLocked ? Color.orange : Color.accentColor)
        }
        .buttonStyle(.plain)
        .alert("Enter PIN", isPresented: $showPINEntry) {
            SecureField("PIN", text: $pinInput)
                .keyboardType(.numberPad)
            Button("Unlock") {
                if !lockManager.unlockWithPIN(pinInput) {
                    pinInput = ""
                    pinError = true
                }
            }
            Button("Cancel", role: .cancel) { pinInput = "" }
        }
        .alert("Incorrect PIN", isPresented: $pinError) {
            Button("Try Again") { showPINEntry = true }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    GalleryTabView()
        .environment(AppNavigationCoordinator())
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}
