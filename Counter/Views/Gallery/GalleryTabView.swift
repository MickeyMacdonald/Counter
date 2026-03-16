import SwiftUI
import SwiftData

// MARK: - Gallery Section

enum GallerySection: String, CaseIterable, Hashable, Identifiable {
    case byClient    = "Clients"
    case byStage     = "Stages"
    case byPlacement = "Placement"
    case flash       = "Available Flash"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .byClient:    "person.2.fill"
        case .byStage:     "square.stack.3d.up.fill"
        case .byPlacement: "figure.arms.open"
        case .flash:       "bolt.fill"
        }
    }
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

/// Main gallery tab — NavigationSplitView with sidebar (Clients, Stages, Placement, Available Flash).
struct GalleryTabView: View {
    @Query(sort: \Piece.updatedAt, order: .reverse) private var allPieces: [Piece]
    @Query(sort: \Client.lastName) private var allClients: [Client]
    @Environment(BusinessLockManager.self) private var lockManager
    @Binding var selectedTab: AppTab

    @State private var selectedSection: GallerySection? = .byStage
    @State private var sortOrder: GallerySortOrder = .chronological
    @State private var searchText = ""
    @State private var galleryFilter: GalleryFilter = .all

    private var filteredSections: [GallerySection] {
        let base: [GallerySection]
        switch galleryFilter {
        case .all:    base = GallerySection.allCases
        case .custom: base = [.byClient, .byStage, .byPlacement]
        case .flash:  base = [.flash]
        }
        return lockManager.isLocked ? base.filter { $0 != .byClient } : base
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                AppTabSwitcher(selectedTab: $selectedTab)
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
                List(filteredSections, selection: $selectedSection) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
                .listStyle(.sidebar)
                Divider()
                SidebarSearchField(text: $searchText, prompt: "Search...")
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
        } detail: {
            VStack(spacing: 0) {
                if lockManager.isEnabled {
                    ClientLockBanner(lockManager: lockManager)
                }
                NavigationStack {
                    if let section = selectedSection {
                        detailView(for: section)
                            .navigationTitle(section.rawValue)
                            .toolbar {
                                if section != .flash {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        Menu {
                                            Picker("Sort", selection: $sortOrder) {
                                                ForEach(GallerySortOrder.allCases, id: \.self) { order in
                                                    Label(order.rawValue, systemImage: order.systemImage)
                                                        .tag(order)
                                                }
                                            }
                                        } label: {
                                            Image(systemName: sortOrder == .chronological
                                                  ? "arrow.up.arrow.down"
                                                  : "star.fill")
                                        }
                                    }
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
            }
        }
        .onChange(of: galleryFilter) {
            if let current = selectedSection, !filteredSections.contains(current) {
                selectedSection = filteredSections.first
            }
        }
        .onChange(of: lockManager.isLocked) {
            if lockManager.isLocked && selectedSection == .byClient {
                selectedSection = filteredSections.first
            }
        }
    }

    // MARK: - Detail Routing

    @ViewBuilder
    private func detailView(for section: GallerySection) -> some View {
        switch section {
        case .byClient:
            GalleryByClientView(clients: clientsWithImages)
        case .byStage:
            GalleryByStageView(pieces: sortedPieces)
        case .byPlacement:
            GalleryByPlacementView(pieces: sortedPieces)
        case .flash:
            AvailableFlashGalleryView()
        }
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
        case .all, .flash, .bodyPlacement:          true
        case .byStage, .byClient, .byRating, .inspiration: false
        }
    }
}

#Preview {
    GalleryTabView(selectedTab: .constant(.gallery))
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}
