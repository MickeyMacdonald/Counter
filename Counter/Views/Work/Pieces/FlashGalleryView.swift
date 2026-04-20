import SwiftUI
import SwiftData

/// Portfolio-wide image grid used when booking a Flash session.
/// Shows all WorkImages across every piece so the artist can pick a design.
struct FlashGalleryView: View {
    @Query(sort: \Piece.updatedAt, order: .reverse) private var pieces: [Piece]
    let onSelect: (WorkImage, Piece) -> Void

    @State private var searchText = ""
    @State private var selectedImage: WorkImage?
    @State private var selectedPiece: Piece?

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 6)]

    private var allImages: [(image: WorkImage, piece: Piece)] {
        var result: [(WorkImage, Piece)] = []
        for piece in pieces {
            if !searchText.isEmpty {
                guard piece.title.localizedCaseInsensitiveContains(searchText) ||
                      piece.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
                else { continue }
            }
            for image in piece.allImages.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                result.append((image, piece))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if allImages.isEmpty {
                    ContentUnavailableView {
                        Label("No Portfolio Images", systemImage: "photo.on.rectangle.angled")
                    } description: {
                        Text("Add images to pieces to build your flash portfolio.")
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(allImages, id: \.image.persistentModelID) { pair in
                                FlashThumbnailCell(
                                    image: pair.image, piece: pair.piece,
                                    isSelected: selectedImage?.persistentModelID == pair.image.persistentModelID
                                )
                                .onTapGesture {
                                    selectedImage = pair.image
                                    selectedPiece = pair.piece
                                }
                            }
                        }
                        .padding(10)
                    }
                }
            }
            .navigationTitle("Flash Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by title or tag")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        if let img = selectedImage, let piece = selectedPiece { onSelect(img, piece) }
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedImage == nil)
                }
            }
        }
    }
}

private struct FlashThumbnailCell: View {
    let image: WorkImage
    let piece: Piece
    let isSelected: Bool
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.primary.opacity(0.05))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let thumb = thumbnail {
                        Image(uiImage: thumb).resizable().scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else { ProgressView() }
                }
                .clipped()
            Text(piece.title)
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                .padding(.horizontal, 6).padding(.vertical, 3).frame(maxWidth: .infinity)
                .background(.black.opacity(0.5))
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10))
            if isSelected {
                RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: 3)
                Image(systemName: "checkmark.circle.fill").font(.title3)
                    .foregroundStyle(.white).background(Color.accentColor, in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(6)
            }
        }
        .task { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        guard let img = await ImageStorageService.shared.loadImage(relativePath: image.filePath) else { return }
        let size = CGSize(width: 300, height: 300)
        let thumb = UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        await MainActor.run { self.thumbnail = thumb }
    }
}

#Preview {
    FlashGalleryView { _, _ in }
        .modelContainer(PreviewContainer.shared.container)
}
