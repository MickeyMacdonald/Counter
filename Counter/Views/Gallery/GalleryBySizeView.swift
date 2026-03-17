import SwiftUI

/// Gallery sub-view that groups images by tattoo size category.
struct GalleryBySizeView: View {
    let pieces: [Piece]

    @State private var selectedFullScreenImages: [PieceImage] = []
    @State private var selectedFullScreenImage: PieceImage?
    @State private var showingFullScreen = false

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 6)]

    private var sizeGroups: [(size: TattooSize, items: [(image: PieceImage, piece: Piece)])] {
        var grouped: [TattooSize: [(PieceImage, Piece)]] = [:]
        for piece in pieces {
            guard let size = piece.size else { continue }
            for image in piece.allImages.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                grouped[size, default: []].append((image, piece))
            }
        }
        return TattooSize.allCases.compactMap { size in
            guard let items = grouped[size], !items.isEmpty else { return nil }
            return (size, items)
        }
    }

    var body: some View {
        if sizeGroups.isEmpty {
            ContentUnavailableView {
                Label("No Sized Pieces", systemImage: "arrow.up.left.and.arrow.down.right")
            } description: {
                Text("Assign a size to your pieces to browse them here.")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(sizeGroups, id: \.size) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: group.size.systemImage)
                                    .foregroundStyle(Color.accentColor)
                                Text(group.size.rawValue)
                                    .font(.headline)
                                Spacer()
                                Text("\(group.items.count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)

                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(group.items, id: \.image.persistentModelID) { item in
                                    GalleryImageCell(
                                        filePath: item.image.filePath,
                                        title: item.piece.title
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
