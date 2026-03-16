import SwiftUI
import SwiftData

/// Gallery sub-view showing images from rated pieces, grouped by star rating (highest first).
struct GalleryByRatingView: View {
    let pieces: [Piece]

    @State private var selectedFullScreenImages: [PieceImage] = []
    @State private var selectedFullScreenImage: PieceImage?
    @State private var showingFullScreen = false

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 6)]

    private var ratingGroups: [(rating: Int, items: [(image: PieceImage, piece: Piece)])] {
        var grouped: [Int: [(PieceImage, Piece)]] = [:]
        for piece in pieces {
            guard let rating = piece.rating else { continue }
            for image in piece.allImages.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                grouped[rating, default: []].append((image, piece))
            }
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (rating: $0.key, items: $0.value) }
    }

    var body: some View {
        if ratingGroups.isEmpty {
            ContentUnavailableView {
                Label("No Rated Pieces", systemImage: "star")
            } description: {
                Text("Rate your pieces to see their images organized here.")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(ratingGroups, id: \.rating) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            // Rating header
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= group.rating ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundStyle(star <= group.rating ? Color.yellow : Color.gray.opacity(0.3))
                                }
                                Spacer()
                                Text("\(group.items.count) image\(group.items.count == 1 ? "" : "s")")
                                    .font(.caption)
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
                                        selectedFullScreenImages = group.items.map(\.image)
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
