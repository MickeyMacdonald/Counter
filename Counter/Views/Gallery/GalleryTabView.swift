import SwiftUI
import SwiftData

/// Main gallery tab — unified image browser across all pieces, clients, and inspiration.
struct GalleryTabView: View {
    @Query(sort: \Piece.updatedAt, order: .reverse) private var allPieces: [Piece]
    @Query(sort: \InspirationImage.capturedAt, order: .reverse) private var inspirationImages: [InspirationImage]
    @Query(sort: \Client.lastName) private var allClients: [Client]

    @State private var selectedCategory: GalleryCategory = .byStage
    @State private var searchText = ""
    @State private var selectedFullScreenImages: [PieceImage] = []
    @State private var selectedFullScreenImage: PieceImage?
    @State private var showingFullScreen = false
    @State private var selectedInspiration: InspirationImage?
    @Environment(BusinessLockManager.self) private var lockManager

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 6)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category picker
                categoryPicker

                Divider()

                // Content
                Group {
                    switch selectedCategory {
                    case .all:
                        allImagesGrid
                    case .byStage:
                        GalleryByStageView(pieces: filteredPieces)
                    case .byClient:
                        GalleryByClientView(clients: clientsWithImages)
                    case .byRating:
                        GalleryByRatingView(pieces: ratedPieces)
                    case .flash:
                        flashGrid
                    case .inspiration:
                        inspirationGrid
                    case .bodyPlacement:
                        GalleryByPlacementView(pieces: filteredPieces)
                    }
                }
            }
            .navigationTitle("Gallery")
            .searchable(text: $searchText, prompt: "Search pieces, tags, clients...")
            .onChange(of: lockManager.isLocked) { _, locked in
                if locked && !selectedCategory.isClientSafe {
                    selectedCategory = .all
                }
            }
            .fullScreenCover(isPresented: $showingFullScreen) {
                if let img = selectedFullScreenImage {
                    FullScreenImageViewer(images: selectedFullScreenImages, initialImage: img)
                }
            }
            .sheet(item: $selectedInspiration) { img in
                InspirationImageDetailView(image: img)
            }
            .toolbar {
                if lockManager.isEnabled {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            if lockManager.isLocked {
                                Task { await lockManager.unlockWithBiometrics() }
                            } else {
                                lockManager.lock()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: lockManager.isLocked ? "eye.slash.fill" : "eye.fill")
                                    .font(.caption)
                                Text(lockManager.isLocked ? "Client Mode" : "Artist Mode")
                                    .font(.caption.weight(.medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                lockManager.isLocked
                                    ? Color.orange.opacity(0.15)
                                    : Color.accentColor.opacity(0.15),
                                in: Capsule()
                            )
                            .foregroundStyle(lockManager.isLocked ? .orange : .accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Filtered Data

    private var filteredPieces: [Piece] {
        guard !searchText.isEmpty else { return allPieces }
        return allPieces.filter { piece in
            piece.title.localizedCaseInsensitiveContains(searchText) ||
            piece.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
            piece.client?.fullName.localizedCaseInsensitiveContains(searchText) == true ||
            piece.bodyPlacement.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var clientsWithImages: [Client] {
        allClients.filter { client in
            client.pieces.contains { !$0.allImages.isEmpty }
        }
    }

    private var ratedPieces: [Piece] {
        filteredPieces
            .filter { $0.rating != nil }
            .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }

    private var allPieceImages: [(image: PieceImage, piece: Piece, stage: ImageStage)] {
        var result: [(PieceImage, Piece, ImageStage)] = []
        for piece in filteredPieces {
            for group in piece.sortedImageGroups where !lockManager.isLocked || group.stage.isClientSafe {
                for image in group.images.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                    result.append((image, piece, group.stage))
                }
            }
        }
        return result
    }

    private var flashPieces: [Piece] {
        filteredPieces.filter { $0.pieceType == .flash }
    }

    // MARK: - Category Picker

    private var availableCategories: [GalleryCategory] {
        if lockManager.isLocked {
            return GalleryCategory.allCases.filter(\.isClientSafe)
        }
        return GalleryCategory.allCases
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableCategories, id: \.self) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: category.systemImage)
                                .font(.caption2)
                            Text(category.rawValue)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            selectedCategory == category
                                ? Color.accentColor.opacity(0.15)
                                : Color.primary.opacity(0.06),
                            in: Capsule()
                        )
                        .foregroundStyle(selectedCategory == category ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    // MARK: - All Images Grid

    private var allImagesGrid: some View {
        Group {
            if allPieceImages.isEmpty {
                emptyState(
                    icon: "photo.on.rectangle.angled",
                    title: "No Images Yet",
                    subtitle: "Add images to your pieces to build your gallery."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(allPieceImages, id: \.image.persistentModelID) { item in
                            GalleryImageCell(
                                filePath: item.image.filePath,
                                title: item.piece.title,
                                stageBadge: item.stage
                            )
                            .onTapGesture {
                                selectedFullScreenImages = item.piece.allImages
                                    .sorted { $0.sortOrder < $1.sortOrder }
                                selectedFullScreenImage = item.image
                                showingFullScreen = true
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    // MARK: - Flash Grid

    private var flashGrid: some View {
        Group {
            if flashPieces.isEmpty {
                emptyState(
                    icon: "bolt.fill",
                    title: "No Flash Designs",
                    subtitle: "Create pieces with the Flash type to see them here."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(flashPieces) { piece in
                            if let primaryPath = piece.primaryImagePath {
                                GalleryImageCell(
                                    filePath: primaryPath,
                                    title: piece.title,
                                    priceLabel: piece.flatRate?.currencyFormatted
                                )
                                .onTapGesture {
                                    let images = piece.allImages
                                        .sorted { $0.sortOrder < $1.sortOrder }
                                    if let first = images.first {
                                        selectedFullScreenImages = images
                                        selectedFullScreenImage = first
                                        showingFullScreen = true
                                    }
                                }
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    // MARK: - Inspiration Grid

    private var inspirationGrid: some View {
        Group {
            if inspirationImages.isEmpty {
                emptyState(
                    icon: "sparkles",
                    title: "No Inspiration Images",
                    subtitle: "Add inspiration images from the Custom Session view."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(inspirationImages) { image in
                            GalleryImageCell(
                                filePath: image.filePath,
                                tags: image.tags
                            )
                            .onTapGesture {
                                selectedInspiration = image
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(subtitle)
        }
    }
}

// MARK: - Gallery Category

enum GalleryCategory: String, CaseIterable {
    case all = "All"
    case byStage = "By Stage"
    case byClient = "By Client"
    case byRating = "By Rating"
    case flash = "Flash"
    case inspiration = "Inspiration"
    case bodyPlacement = "Placement"

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .byStage: "square.stack.3d.up"
        case .byClient: "person.2"
        case .byRating: "star"
        case .flash: "bolt.fill"
        case .inspiration: "sparkles"
        case .bodyPlacement: "figure.arms.open"
        }
    }

    /// Categories safe to show in client mode
    var isClientSafe: Bool {
        switch self {
        case .all, .flash, .bodyPlacement:
            true
        case .byStage, .byClient, .byRating, .inspiration:
            false
        }
    }
}

#Preview {
    GalleryTabView()
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}
