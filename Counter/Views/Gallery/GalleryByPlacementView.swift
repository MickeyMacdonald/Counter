import SwiftUI
import SwiftData

/// Gallery sub-view showing images organized by body placement.
struct GalleryByPlacementView: View {
    let pieces: [Piece]
    var categoryFilter: Set<ImageCategory> = []

    @State private var selectedFullScreenImages: [WorkImage] = []
    @State private var selectedFullScreenImage: WorkImage?
    @State private var showingFullScreen = false

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 6)]

    private var placementGroups: [(placement: String, items: [(image: WorkImage, piece: Piece)])] {
        var grouped: [String: [(WorkImage, Piece)]] = [:]
        for piece in pieces {
            let placement = piece.bodyPlacement.isEmpty ? "Unspecified" : piece.bodyPlacement
            for image in piece.allImages.sorted(by: { $0.sortOrder < $1.sortOrder })
                where categoryFilter.isEmpty || categoryFilter.contains(image.category) {
                grouped[placement, default: []].append((image, piece))
            }
        }
        return grouped
            .sorted { $0.value.count > $1.value.count }
            .map { (placement: $0.key, items: $0.value) }
    }

    var body: some View {
        if placementGroups.isEmpty {
            ContentUnavailableView {
                Label("No Images", systemImage: "figure.arms.open")
            } description: {
                Text("Add images to pieces with body placement info to see them here.")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(placementGroups, id: \.placement) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            // Placement header
                            HStack(spacing: 6) {
                                Image(systemName: "figure.arms.open")
                                    .foregroundStyle(Color.accentColor)
                                Text(group.placement)
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
