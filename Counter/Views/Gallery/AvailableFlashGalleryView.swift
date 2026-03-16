import SwiftUI
import SwiftData

// MARK: - Available Flash Gallery

struct AvailableFlashGalleryView: View {
    @Query(
        filter: #Predicate<Client> { $0.isFlashPortfolioClient },
        sort: \Client.lastName
    )
    private var portfolioClients: [Client]

    @State private var selectedPiece: Piece?
    @State private var showManagePortfolio = false

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12)]

    private var flashPieces: [Piece] {
        portfolioClients.first?.pieces.sorted { $0.updatedAt > $1.updatedAt } ?? []
    }

    var body: some View {
        Group {
            if flashPieces.isEmpty {
                ContentUnavailableView {
                    Label("No Flash Available", systemImage: "bolt.slash.fill")
                } description: {
                    Text("Add flash designs to your portfolio to see them here.")
                } actions: {
                    Button("Manage Portfolio") { showManagePortfolio = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(flashPieces) { piece in
                            FlashAvailableCell(piece: piece)
                                .onTapGesture { selectedPiece = piece }
                        }
                    }
                    .padding(14)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Manage") { showManagePortfolio = true }
                    .font(.subheadline)
            }
        }
        .sheet(isPresented: $showManagePortfolio) {
            FlashPortfolioView()
        }
        .sheet(item: $selectedPiece) { piece in
            FlashSelectSheet(piece: piece)
        }
    }
}

// MARK: - Flash Available Cell

private struct FlashAvailableCell: View {
    let piece: Piece
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.primary.opacity(0.06))

                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Price badge
            if let priceText = priceText {
                Text(priceText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        )
        .task { await loadThumbnail() }
    }

    private var priceText: String? {
        if let flat = piece.flatRate {
            return flat.currencyFormatted
        }
        return nil
    }

    private func loadThumbnail() async {
        guard let path = piece.primaryImagePath,
              let img = await ImageStorageService.shared.loadImage(relativePath: path) else { return }
        let size = CGSize(width: 440, height: 440)
        let thumb = UIGraphicsImageRenderer(size: size).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
        await MainActor.run { self.thumbnail = thumb }
    }
}

// MARK: - Flash Select Sheet

struct FlashSelectSheet: View {
    let piece: Piece
    @Environment(\.dismiss) private var dismiss
    @State private var showBooking = false
    @State private var thumbnail: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Full image
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.primary.opacity(0.06))

                        if let thumb = thumbnail {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                                .frame(height: 300)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(piece.title)
                            .font(.title2.weight(.bold))

                        if let flat = piece.flatRate {
                            Label(flat.currencyFormatted, systemImage: "tag.fill")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }

                        if !piece.descriptionText.isEmpty {
                            Text(piece.descriptionText)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        if !piece.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(piece.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Book button
                    Button {
                        showBooking = true
                    } label: {
                        Label("Book This Flash", systemImage: "calendar.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Flash Design")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadImage() }
            .sheet(isPresented: $showBooking) {
                AddSessionView(context: .fromCalendar(Date()))
            }
        }
    }

    private func loadImage() async {
        guard let path = piece.primaryImagePath,
              let img = await ImageStorageService.shared.loadImage(relativePath: path) else { return }
        await MainActor.run { self.thumbnail = img }
    }
}
