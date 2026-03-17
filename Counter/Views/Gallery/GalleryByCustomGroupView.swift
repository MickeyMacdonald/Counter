import SwiftUI

/// Gallery view that shows images from pieces matching a custom group's tags.
struct GalleryByCustomGroupView: View {
    let group: CustomGalleryGroup
    let pieces: [Piece]

    @State private var selectedFullScreenImages: [PieceImage] = []
    @State private var selectedFullScreenImage: PieceImage?
    @State private var showingFullScreen = false

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 6)]

    private var matchingItems: [(image: PieceImage, piece: Piece)] {
        let matchingPieces: [Piece]
        if group.tags.isEmpty {
            matchingPieces = pieces
        } else {
            matchingPieces = pieces.filter { piece in
                piece.tags.contains { tag in
                    group.tags.contains { groupTag in
                        tag.localizedCaseInsensitiveContains(groupTag) ||
                        groupTag.localizedCaseInsensitiveContains(tag)
                    }
                }
            }
        }
        return matchingPieces.flatMap { piece in
            piece.allImages
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .map { (image: $0, piece: piece) }
        }
    }

    var body: some View {
        if matchingItems.isEmpty {
            ContentUnavailableView {
                Label("No Matching Images", systemImage: "tag")
            } description: {
                if group.tags.isEmpty {
                    Text("Add tags to this group to filter pieces.")
                } else {
                    Text("No pieces match the tags: \(group.tags.joined(separator: ", "))")
                }
            }
        } else {
            ScrollView {
                if !group.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(group.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(matchingItems, id: \.image.persistentModelID) { item in
                        GalleryImageCell(
                            filePath: item.image.filePath,
                            title: item.piece.title
                        )
                        .onTapGesture {
                            selectedFullScreenImages = matchingItems.map(\.image)
                            selectedFullScreenImage = item.image
                            showingFullScreen = true
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .fullScreenCover(isPresented: $showingFullScreen) {
                if let img = selectedFullScreenImage {
                    FullScreenImageViewer(images: selectedFullScreenImages, initialImage: img)
                }
            }
        }
    }
}
