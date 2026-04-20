import SwiftUI
import SwiftData

// MARK: - Admin Gallery Group

enum AdminGalleryGroup: String, CaseIterable {
    case library = "Library"
    case custom  = "Custom"
    case flash   = "Flash"
}

// MARK: - Library Filter (Admin)

enum LibraryFilter: String, CaseIterable, Hashable, Identifiable {
    case client    = "Client"
    case placement = "Placement"
    case size      = "Size"
    case stage     = "Stage"
    case price     = "Price"
    case rating    = "Rating"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .client:    "person.2.fill"
        case .placement: "figure.arms.open"
        case .size:      "arrow.up.left.and.arrow.down.right"
        case .stage:     "square.stack.3d.up.fill"
        case .price:     "dollarsign.circle"
        case .rating:    "star.fill"
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
    @State private var adminGroup: AdminGalleryGroup = .library
    @State private var libraryFilter: LibraryFilter? = .stage
    @State private var selectedCustomGroup: GalleryGroup?

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
            .navigationTitle("Gallery")
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
        .onChange(of: adminGroup) {
            searchText = ""
            if adminGroup == .custom { selectedCustomGroup = customGroups.first }
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
        case .library:
            List(LibraryFilter.allCases, selection: $libraryFilter) { filter in
                NavigationLink(value: filter) {
                    Label(filter.rawValue, systemImage: filter.systemImage)
                }
            }
            .listStyle(.sidebar)
        case .custom:
            List(selection: $selectedCustomGroup) {
                ForEach(customGroups) { group in
                    Label(group.name, systemImage: "tag.fill")
                        .tag(group)
                }
                Button {
                    showAddCustomGroup = true
                } label: {
                    Label("New Group", systemImage: "plus")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .listStyle(.sidebar)
        case .flash:
            Spacer()
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
        case .library:
            if let filter = libraryFilter {
                libraryDetailView(for: filter)
                    .navigationTitle(filter.rawValue)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { sortMenu }
                    }
            } else {
                ContentUnavailableView("Select a Category", systemImage: "photo.on.rectangle.angled",
                                       description: Text("Choose a category from the sidebar."))
            }
        case .custom:
            if let group = selectedCustomGroup {
                GalleryByCustomGroupView(group: group, pieces: sortedPieces)
                    .navigationTitle(group.name)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { sortMenu }
                    }
            } else {
                ContentUnavailableView(
                    "Select a Group",
                    systemImage: "tag",
                    description: Text("Choose a custom group from the sidebar.")
                )
            }
        case .flash:
            FlashPortfolioView()
                .navigationTitle("Flash")
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
    private func libraryDetailView(for filter: LibraryFilter) -> some View {
        switch filter {
        case .client:    GalleryByClientView(clients: clientsWithImages)
        case .placement: GalleryByPlacementView(pieces: sortedPieces)
        case .size:      GalleryBySizeView(pieces: sortedPieces)
        case .stage:     GalleryByStageView(pieces: sortedPieces)
        case .price:     GalleryByPriceView(pieces: sortedPieces)
        case .rating:    GalleryByRatingView(pieces: sortedPieces)
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
        return adminGroup == .library || adminGroup == .custom
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
        selectedCustomGroup = group
        resetNewGroupForm()
    }

    private func resetNewGroupForm() {
        newGroupName = ""
        newGroupTags = ""
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
