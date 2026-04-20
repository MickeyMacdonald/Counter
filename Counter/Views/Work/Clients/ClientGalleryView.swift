import SwiftUI
import SwiftData

/// Shows all images from a specific client, split into Custom, Flash, and Inspiration tabs.
struct ClientGalleryView: View {
    let client: Client

    @State private var selectedTab: ClientGalleryTab = .custom
    @State private var selectedFullScreenImages: [WorkImage] = []
    @State private var selectedFullScreenImage: WorkImage?
    @State private var showingFullScreen = false

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 6)]

    // MARK: - Data

    private var customPieces: [Piece] {
        client.pieces
            .filter { $0.pieceType == .custom || $0.pieceType == .walkIn }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var flashPieces: [Piece] {
        client.pieces
            .filter { $0.pieceType == .flash }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func tattooImages(for pieces: [Piece]) -> [(image: WorkImage, piece: Piece, stage: ImageStage)] {
        var result: [(WorkImage, Piece, ImageStage)] = []
        for piece in pieces {
            for group in piece.sortedSessionProgress {
                for image in group.images.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                    result.append((image, piece, group.stage))
                }
            }
        }
        return result
    }

    private var inspirationImages: [(image: WorkImage, piece: Piece, category: ImageCategory)] {
        var result: [(WorkImage, Piece, ImageCategory)] = []
        for piece in client.pieces.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            for image in piece.images
                    .filter({ $0.category == .inspiration || $0.category == .reference })
                    .sorted(by: { $0.sortOrder < $1.sortOrder }) {
                result.append((image, piece, image.category))
            }
        }
        return result
    }

    private var customImages: [(image: WorkImage, piece: Piece, stage: ImageStage)] {
        tattooImages(for: customPieces)
    }

    private var flashImages: [(image: WorkImage, piece: Piece, stage: ImageStage)] {
        tattooImages(for: flashPieces)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Category", selection: $selectedTab) {
                ForEach(ClientGalleryTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            // Content
            Group {
                switch selectedTab {
                case .custom:
                    if customPieces.isEmpty {
                        emptyState(
                            icon: "paintbrush.pointed",
                            title: "No Custom Work",
                            subtitle: "Custom and walk-in pieces will appear here."
                        )
                    } else {
                        pieceGroupedGrid(pieces: customPieces, images: customImages)
                    }
                case .flash:
                    if flashPieces.isEmpty {
                        emptyState(
                            icon: "bolt.fill",
                            title: "No Flash Work",
                            subtitle: "Flash pieces for this client will appear here."
                        )
                    } else {
                        pieceGroupedGrid(pieces: flashPieces, images: flashImages)
                    }
                case .inspiration:
                    inspirationGrid
                }
            }
        }
        .navigationTitle("\(client.firstName)'s Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let img = selectedFullScreenImage {
                FullScreenImageViewer(images: selectedFullScreenImages, initialImage: img)
            }
        }
    }

    // MARK: - Piece-Grouped Grid

    /// Shows pieces as section headers with their images underneath
    private func pieceGroupedGrid(pieces: [Piece], images: [(image: WorkImage, piece: Piece, stage: ImageStage)]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(pieces) { piece in
                    let pieceImages = images.filter { $0.piece.persistentModelID == piece.persistentModelID }

                    if !pieceImages.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            // Piece header
                            HStack(spacing: 8) {
                                Image(systemName: piece.pieceType.systemImage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(piece.title.isEmpty ? "Untitled" : piece.title)
                                    .font(.subheadline.weight(.semibold))

                                if !piece.bodyPlacement.isEmpty {
                                    Text("· \(piece.bodyPlacement)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                statusBadge(piece.status)
                            }
                            .padding(.horizontal, 14)

                            // Image grid
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(pieceImages, id: \.image.persistentModelID) { item in
                                    GalleryImageCell(
                                        filePath: item.image.filePath,
                                        title: item.piece.title,
                                        stageBadge: item.stage
                                    )
                                    .onTapGesture {
                                        selectedFullScreenImages = pieceImages.map(\.image)
                                        selectedFullScreenImage = item.image
                                        showingFullScreen = true
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                        }

                        if piece.persistentModelID != pieces.last?.persistentModelID {
                            Divider()
                                .padding(.vertical, 4)
                        }
                    }
                }

                // Show pieces with no images
                let emptyPieces = pieces.filter { piece in
                    images.allSatisfy { $0.piece.persistentModelID != piece.persistentModelID }
                }
                if !emptyPieces.isEmpty {
                    Section {
                        ForEach(emptyPieces) { piece in
                            HStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .foregroundStyle(.secondary)
                                Text(piece.title.isEmpty ? "Untitled" : piece.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("No photos")
                                    .font(.caption)
                                    .foregroundStyle(Color.gray.opacity(0.6))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                        }
                    } header: {
                        Text("Awaiting Photos")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 14)
                            .padding(.top, 8)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Inspiration Grid

    private var inspirationGrid: some View {
        Group {
            if inspirationImages.isEmpty {
                emptyState(
                    icon: "sparkles",
                    title: "No Inspiration Images",
                    subtitle: "Inspiration and reference images will appear here."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(inspirationImages, id: \.image.persistentModelID) { item in
                            GalleryImageCell(
                                filePath: item.image.filePath,
                                title: item.piece.title,
                                categoryBadge: item.category
                            )
                            .onTapGesture {
                                selectedFullScreenImages = inspirationImages.map(\.image)
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

    // MARK: - Helpers

    private func statusBadge(_ status: PieceStatus) -> some View {
        Text(status.rawValue)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(subtitle)
        }
    }
}

enum ClientGalleryTab: String, CaseIterable {
    case custom = "Custom"
    case flash = "Flash"
    case inspiration = "Inspiration"

    var systemImage: String {
        switch self {
        case .custom: "paintbrush.pointed"
        case .flash: "bolt.fill"
        case .inspiration: "sparkles"
        }
    }
}
