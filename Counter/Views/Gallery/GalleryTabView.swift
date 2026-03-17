import SwiftUI
import SwiftData

// MARK: - Gallery Section

enum GallerySection: String, CaseIterable, Hashable, Identifiable {
    case byClient    = "Clients"
    case byStage     = "Stages"
    case byPlacement = "Placement"
    case bySize      = "Size"
    case byRating    = "Rating"
    case flash       = "Available Flash"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .byClient:    "person.2.fill"
        case .byStage:     "square.stack.3d.up.fill"
        case .byPlacement: "figure.arms.open"
        case .bySize:      "arrow.up.left.and.arrow.down.right"
        case .byRating:    "star.fill"
        case .flash:       "bolt.fill"
        }
    }

    /// Sections listed in the sidebar (flash is shown via the filter toggle, not the list).
    static var sidebarSections: [GallerySection] {
        [.byClient, .byStage, .byPlacement, .bySize, .byRating]
    }
}

// MARK: - Gallery Destination

enum GalleryDestination: Hashable {
    case section(GallerySection)
    case customGroup(CustomGalleryGroup)
}

// MARK: - Gallery Filter

enum GalleryFilter: String, CaseIterable {
    case all    = "All"
    case custom = "Custom"
    case flash  = "Flash"
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

/// Main gallery tab — NavigationSplitView with sidebar (Stages, Placement, Size, Rating, custom groups).
/// Available Flash is accessed via the top filter toggle, not the sidebar list.
struct GalleryTabView: View {
    @Query(sort: \Piece.updatedAt, order: .reverse) private var allPieces: [Piece]
    @Query(sort: \Client.lastName) private var allClients: [Client]
    @Query(sort: \CustomGalleryGroup.sortIndex) private var customGroups: [CustomGalleryGroup]
    @Environment(\.modelContext) private var modelContext
    @Environment(BusinessLockManager.self) private var lockManager
    @Environment(AppNavigationCoordinator.self) private var coordinator

    @State private var selectedDestination: GalleryDestination? = .section(.byStage)
    @State private var sortOrder: GallerySortOrder = .chronological
    @State private var searchText = ""
    @State private var galleryFilter: GalleryFilter = .all
    @State private var showAddCustomGroup = false
    @State private var newGroupName = ""
    @State private var newGroupTags = ""

    private var filteredSections: [GallerySection] {
        switch galleryFilter {
        case .all:
            let base = GallerySection.sidebarSections
            return lockManager.isLocked ? base.filter { $0 != .byClient && $0 != .byRating } : base
        case .custom:
            let base: [GallerySection] = [.byClient, .byStage, .byPlacement, .bySize]
            return lockManager.isLocked ? base.filter { $0 != .byClient } : base
        case .flash:
            return []
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                if !lockManager.isLocked {
                    AppTabSwitcher()
                    Divider()
                    Picker("Filter", selection: $galleryFilter) {
                        ForEach(GalleryFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    Divider()
                }
                List(selection: $selectedDestination) {
                    Section {
                        ForEach(filteredSections) { section in
                            Label(section.rawValue, systemImage: section.systemImage)
                                .tag(GalleryDestination.section(section))
                        }
                    }
                    if !lockManager.isLocked && galleryFilter != .flash {
                        Section("Custom") {
                            ForEach(customGroups) { group in
                                Label(group.name, systemImage: "tag.fill")
                                    .tag(GalleryDestination.customGroup(group))
                            }
                            Button {
                                showAddCustomGroup = true
                            } label: {
                                Label("New Group", systemImage: "plus")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                Divider()
                SidebarSearchField(text: $searchText, prompt: "Search...")
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
                    detailContent
                }
            }
        }
        .onChange(of: galleryFilter) { updateSelectionForFilter() }
        .onChange(of: lockManager.isLocked) { updateSelectionForLock() }
        .alert("New Custom Group", isPresented: $showAddCustomGroup) {
            TextField("Group Name", text: $newGroupName)
            TextField("Tags (comma-separated)", text: $newGroupTags)
            Button("Create") { createCustomGroup() }
            Button("Cancel", role: .cancel) { resetNewGroupForm() }
        } message: {
            Text("Pieces with matching tags will appear in this group.")
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        if galleryFilter == .flash {
            AvailableFlashGalleryView()
                .navigationTitle(GallerySection.flash.rawValue)
        } else if let dest = selectedDestination {
            switch dest {
            case .section(let section):
                sectionView(for: section)
                    .navigationTitle(section.rawValue)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { sortMenu }
                    }
            case .customGroup(let group):
                GalleryByCustomGroupView(group: group, pieces: sortedPieces)
                    .navigationTitle(group.name)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { sortMenu }
                    }
            }
        } else {
            ContentUnavailableView(
                "Select a Category",
                systemImage: "photo.on.rectangle.angled",
                description: Text("Choose a category from the sidebar.")
            )
        }
    }

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

    @ViewBuilder
    private func sectionView(for section: GallerySection) -> some View {
        switch section {
        case .byClient:
            GalleryByClientView(clients: clientsWithImages)
        case .byStage:
            GalleryByStageView(pieces: sortedPieces)
        case .byPlacement:
            GalleryByPlacementView(pieces: sortedPieces)
        case .bySize:
            GalleryBySizeView(pieces: sortedPieces)
        case .byRating:
            GalleryByRatingView(pieces: sortedPieces)
        case .flash:
            AvailableFlashGalleryView()
        }
    }

    // MARK: - Selection Helpers

    private func updateSelectionForFilter() {
        if galleryFilter == .flash {
            selectedDestination = nil
            return
        }
        guard let dest = selectedDestination else {
            selectedDestination = filteredSections.first.map { .section($0) }
            return
        }
        if case .section(let section) = dest, !filteredSections.contains(section) {
            selectedDestination = filteredSections.first.map { .section($0) }
        }
    }

    private func updateSelectionForLock() {
        guard lockManager.isLocked else { return }
        if let dest = selectedDestination {
            switch dest {
            case .section(let section) where section == .byClient || section == .byRating:
                selectedDestination = filteredSections.first.map { .section($0) }
            case .customGroup:
                selectedDestination = filteredSections.first.map { .section($0) }
            default:
                break
            }
        }
        if sortOrder == .rating { sortOrder = .chronological }
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
        let group = CustomGalleryGroup(
            name: newGroupName.trimmingCharacters(in: .whitespaces),
            tags: tags,
            sortIndex: customGroups.count
        )
        modelContext.insert(group)
        selectedDestination = .customGroup(group)
        resetNewGroupForm()
    }

    private func resetNewGroupForm() {
        newGroupName = ""
        newGroupTags = ""
    }

    // MARK: - Derived Data

    private var filteredPieces: [Piece] {
        let nonFlash = allPieces.filter { $0.client?.isFlashPortfolioClient != true }
        guard !searchText.isEmpty else { return nonFlash }
        return nonFlash.filter { piece in
            piece.title.localizedCaseInsensitiveContains(searchText) ||
            piece.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
            piece.client?.fullName.localizedCaseInsensitiveContains(searchText) == true ||
            piece.bodyPlacement.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sortedPieces: [Piece] {
        switch sortOrder {
        case .chronological:
            return filteredPieces
        case .rating:
            return filteredPieces.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
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
}

// MARK: - Client Lock Banner

struct ClientLockBanner: View {
    let lockManager: BusinessLockManager
    @State private var showPINEntry = false
    @State private var pinInput = ""
    @State private var pinError = false

    var body: some View {
        Button {
            if lockManager.isLocked {
                Task {
                    let success = await lockManager.unlockWithBiometrics()
                    if !success { showPINEntry = true }
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
                      ? "faceid"
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

// MARK: - Gallery Category (kept for any remaining references)

enum GalleryCategory: String, CaseIterable {
    case all          = "All"
    case byStage      = "By Stage"
    case byClient     = "By Client"
    case byRating     = "By Rating"
    case flash        = "Flash"
    case inspiration  = "Inspiration"
    case bodyPlacement = "Placement"

    var systemImage: String {
        switch self {
        case .all:           "square.grid.2x2"
        case .byStage:       "square.stack.3d.up"
        case .byClient:      "person.2"
        case .byRating:      "star"
        case .flash:         "bolt.fill"
        case .inspiration:   "sparkles"
        case .bodyPlacement: "figure.arms.open"
        }
    }

    var isClientSafe: Bool {
        switch self {
        case .all, .flash, .bodyPlacement:                    true
        case .byStage, .byClient, .byRating, .inspiration:   false
        }
    }
}

#Preview {
    GalleryTabView()
        .environment(AppNavigationCoordinator())
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}
