import SwiftUI

/// Unified thumbnail cell used across all gallery views.
/// Consolidates the repeated thumbnail pattern from FlashThumbnailCell,
/// ImageThumbnailCell, and InspirationCell into a single reusable component.
struct GalleryImageCell: View {
    let filePath: String
    var title: String? = nil
    var stageBadge: ImageStage? = nil
    var categoryBadge: PieceImageCategory? = nil
    var priceLabel: String? = nil
    var ratingValue: Int? = nil
    var tags: [String] = []

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            RoundedRectangle(cornerRadius: 10)
                .fill(.primary.opacity(0.05))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let thumb = thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ProgressView()
                    }
                }
                .clipped()

            // Bottom overlay
            VStack(spacing: 0) {
                Spacer()

                // Tags row (if present)
                if !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 3) {
                            ForEach(tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.55), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                    }
                }

                // Title bar
                if title != nil || stageBadge != nil || categoryBadge != nil || priceLabel != nil {
                    HStack(spacing: 4) {
                        if let stage = stageBadge {
                            Image(systemName: stage.systemImage)
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.8))
                        } else if let category = categoryBadge {
                            Image(systemName: category.systemImage)
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        if let title {
                            Text(title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let price = priceLabel {
                            Text(price)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        if let rating = ratingValue {
                            HStack(spacing: 1) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                Text("\(rating)")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.yellow)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.5))
                    .clipShape(
                        UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10)
                    )
                }
            }
        }
        .task { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        guard let img = await ImageStorageService.shared.loadImage(relativePath: filePath) else { return }
        let size = CGSize(width: 300, height: 300)
        let thumb = UIGraphicsImageRenderer(size: size).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
        await MainActor.run { self.thumbnail = thumb }
    }
}
