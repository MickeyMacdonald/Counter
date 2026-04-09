import SwiftUI

/// Gallery sub-view that groups piece images by flat-rate price range.
struct GalleryByPriceView: View {
    let pieces: [Piece]

    @State private var selectedFullScreenImages: [PieceImage] = []
    @State private var selectedFullScreenImage: PieceImage?
    @State private var showingFullScreen = false

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 6)]

    private enum PriceRange: String, CaseIterable {
        case unpriced  = "Unpriced"
        case under200  = "Under $200"
        case r200_500  = "$200 – $500"
        case r500_1000 = "$500 – $1,000"
        case over1000  = "Over $1,000"

        var systemImage: String {
            switch self {
            case .unpriced:  "minus.circle"
            case .under200:  "1.circle.fill"
            case .r200_500:  "2.circle.fill"
            case .r500_1000: "3.circle.fill"
            case .over1000:  "dollarsign.circle.fill"
            }
        }

        static func bucket(for price: Decimal) -> PriceRange {
            switch price {
            case ..<200:    return .under200
            case ..<500:    return .r200_500
            case ..<1000:   return .r500_1000
            default:        return .over1000
            }
        }
    }

    private var priceGroups: [(range: PriceRange, items: [(image: PieceImage, piece: Piece)])] {
        var grouped: [PriceRange: [(PieceImage, Piece)]] = [:]
        for piece in pieces {
            let range: PriceRange = piece.flatRate.map { PriceRange.bucket(for: $0) } ?? .unpriced
            for image in piece.allImages.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                grouped[range, default: []].append((image, piece))
            }
        }
        return PriceRange.allCases.compactMap { range in
            guard let items = grouped[range], !items.isEmpty else { return nil }
            return (range, items)
        }
    }

    var body: some View {
        if priceGroups.isEmpty {
            ContentUnavailableView {
                Label("No Priced Pieces", systemImage: "dollarsign.circle")
            } description: {
                Text("Set a flat rate on your pieces to browse them by price.")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(priceGroups, id: \.range) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: group.range.systemImage)
                                    .foregroundStyle(Color.accentColor)
                                Text(group.range.rawValue)
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
