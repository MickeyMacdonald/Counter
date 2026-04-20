import SwiftUI
import SwiftData

/// Gallery sub-view showing images organized by piece.
struct GalleryByPieceView: View {
    let pieces: [Piece]
    var categoryFilter: Set<ImageCategory> = []

    @State private var selectedFullScreenImages: [WorkImage] = []
    @State private var selectedFullScreenImage: WorkImage?
    @State private var showingFullScreen = false

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 6)]

    private var pieceGroups: [(piece: Piece, images: [WorkImage])] {
        pieces.compactMap { piece in
            let images = piece.allImages
                .sorted { $0.sortOrder < $1.sortOrder }
                .filter { categoryFilter.isEmpty || categoryFilter.contains($0.category) }
            guard !images.isEmpty else { return nil }
            return (piece: piece, images: images)
        }
    }

    var body: some View {
        if pieceGroups.isEmpty {
            ContentUnavailableView {
                Label("No Images", systemImage: "paintbrush.pointed.fill")
            } description: {
                Text("Add images to pieces to see them here.")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(pieceGroups, id: \.piece.persistentModelID) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: group.piece.pieceType.systemImage)
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(group.piece.title)
                                        .font(.headline)
                                    if let client = group.piece.client {
                                        Text(client.fullName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(group.images.count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)

                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(group.images) { image in
                                    GalleryImageCell(filePath: image.filePath)
                                        .onTapGesture {
                                            selectedFullScreenImages = group.images
                                            selectedFullScreenImage = image
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
