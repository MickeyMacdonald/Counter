import SwiftUI
import SwiftData

/// Gallery sub-view that groups images by their ImageStage.
/// Each stage is a collapsible section with a grid of images.
struct GalleryByStageView: View {
    let pieces: [Piece]

    @State private var selectedFullScreenImages: [PieceImage] = []
    @State private var selectedFullScreenImage: PieceImage?
    @State private var showingFullScreen = false

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 6)]

    private var imagesByStage: [(stage: ImageStage, items: [(image: PieceImage, piece: Piece)])] {
        var grouped: [ImageStage: [(PieceImage, Piece)]] = [:]
        for piece in pieces {
            // Work photos from session image groups
            for session in piece.sessions {
                for group in session.imageGroups {
                    for image in group.images.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                        grouped[group.stage, default: []].append((image, piece))
                    }
                }
            }
            // Legacy: also check piece.imageGroups for backward compat
            for group in piece.imageGroups {
                for image in group.images.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                    // Avoid duplicates if already added via session
                    if group.session == nil {
                        grouped[group.stage, default: []].append((image, piece))
                    }
                }
            }
        }
        return ImageStage.allCases.compactMap { stage in
            guard let items = grouped[stage], !items.isEmpty else { return nil }
            return (stage, items)
        }
    }

    var body: some View {
        if imagesByStage.isEmpty {
            ContentUnavailableView {
                Label("No Images", systemImage: "square.stack.3d.up")
            } description: {
                Text("Add images to your pieces to see them organized by stage.")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(imagesByStage, id: \.stage) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            // Stage header
                            HStack(spacing: 6) {
                                Image(systemName: group.stage.systemImage)
                                    .foregroundStyle(Color.accentColor)
                                Text(group.stage.rawValue)
                                    .font(.headline)
                                Spacer()
                                Text("\(group.items.count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)

                            // Image grid
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(group.items, id: \.image.persistentModelID) { item in
                                    GalleryImageCell(
                                        filePath: item.image.filePath,
                                        title: item.piece.title,
                                        ratingValue: item.piece.rating
                                    )
                                    .onTapGesture {
                                        let allGroupImages = group.items.map(\.image)
                                        selectedFullScreenImages = allGroupImages
                                        selectedFullScreenImage = item.image
                                        showingFullScreen = true
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .padding(.vertical, 10)
            }
            .fullScreenCover(isPresented: $showingFullScreen) {
                if let img = selectedFullScreenImage {
                    FullScreenImageViewer(images: selectedFullScreenImages, initialImage: img)
                }
            }
        }
    }
}
