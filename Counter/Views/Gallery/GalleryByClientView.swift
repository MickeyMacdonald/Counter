import SwiftUI
import SwiftData

/// Gallery sub-view showing images organized by client, then by piece.
struct GalleryByClientView: View {
    let clients: [Client]
    var categoryFilter: Set<ImageCategory> = []

    @State private var selectedFullScreenImages: [WorkImage] = []
    @State private var selectedFullScreenImage: WorkImage?
    @State private var showingFullScreen = false
    @State private var expandedClients: Set<PersistentIdentifier> = []

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 6)]

    var body: some View {
        if clients.isEmpty {
            ContentUnavailableView {
                Label("No Client Images", systemImage: "person.2")
            } description: {
                Text("Add images to client pieces to see them here.")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(clients) { client in
                        let piecesWithImages = client.pieces.filter { !$0.sessionProgress.isEmpty }
                        if !piecesWithImages.isEmpty {
                            clientSection(client: client, pieces: piecesWithImages)
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

    private func clientSection(client: Client, pieces: [Piece]) -> some View {
        let isExpanded = expandedClients.contains(client.persistentModelID)

        return VStack(alignment: .leading, spacing: 8) {
            // Client header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedClients.remove(client.persistentModelID)
                    } else {
                        expandedClients.insert(client.persistentModelID)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(.primary.opacity(0.08))
                            .frame(width: 32, height: 32)
                        Text(client.initialsDisplay)
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(client.fullName)
                            .font(.headline)
                        Text("\(pieces.count) piece\(pieces.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)

            if isExpanded {
                ForEach(pieces) { piece in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(piece.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)

                        let images = piece.sortedSessionProgress.flatMap { group in
                            group.images
                                .sorted { $0.sortOrder < $1.sortOrder }
                                .filter { categoryFilter.isEmpty || categoryFilter.contains($0.category) }
                                .map { (image: $0, stage: group.stage) }
                        }

                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(images, id: \.image.persistentModelID) { item in
                                GalleryImageCell(
                                    filePath: item.image.filePath,
                                    stageBadge: item.stage
                                )
                                .onTapGesture {
                                    selectedFullScreenImages = images.map(\.image)
                                    selectedFullScreenImage = item.image
                                    showingFullScreen = true
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }
            }
        }
    }
}
