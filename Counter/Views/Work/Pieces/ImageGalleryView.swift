import SwiftUI
import SwiftData

/// Grid gallery showing all images within an SessionProgress stage.
/// Supports adding new images, deleting, and tapping to view full-screen.
struct ImageGalleryView: View {
    @Bindable var imageGroup: SessionProgress
    let clientID: String
    let pieceID: String

    @Environment(\.modelContext) private var modelContext
    @State private var showingImportPicker = false
    @State private var selectedImage: WorkImage?
    @State private var showingFullScreen = false
    @State private var isProcessing = false

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Stage header with time tracking
                stageHeader

                // Image grid
                if sortedImages.isEmpty && !isProcessing {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        // Add button as first cell
                        addImageCell

                        ForEach(sortedImages) { pieceImage in
                            ImageThumbnailCell(pieceImage: pieceImage)
                                .onTapGesture {
                                    selectedImage = pieceImage
                                    showingFullScreen = true
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteImage(pieceImage)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }

                if isProcessing {
                    ProgressView("Importing images...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
        }
        .navigationTitle(imageGroup.stage.rawValue)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingImportPicker = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingImportPicker) {
            PhotoImportPicker(isPresented: $showingImportPicker) { images, _ in
                Task {
                    await importImages(images)
                }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let selectedImage {
                FullScreenImageViewer(
                    images: sortedImages,
                    initialImage: selectedImage
                )
            }
        }
    }

    private var sortedImages: [WorkImage] {
        imageGroup.images.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var stageHeader: some View {
        HStack {
            Label(imageGroup.stage.rawValue, systemImage: imageGroup.stage.systemImage)
                .font(.headline)

            Spacer()

            if imageGroup.timeSpentMinutes > 0 {
                Label(imageGroup.timeSpentFormatted, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("\(sortedImages.count) images")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: imageGroup.stage.systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No images yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showingImportPicker = true
            } label: {
                Label("Add Images", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var addImageCell: some View {
        Button {
            showingImportPicker = true
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .foregroundStyle(.quaternary)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.title2)
                        Text("Add")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .aspectRatio(1, contentMode: .fit)
        }
    }

    private func importImages(_ images: [UIImage]) async {
        isProcessing = true
        let storage = ImageStorageService.shared
        let currentCount = sortedImages.count

        for (index, image) in images.enumerated() {
            do {
                let relativePath = try await storage.saveImage(
                    image,
                    clientID: clientID,
                    pieceID: pieceID,
                    stage: imageGroup.stage.rawValue
                )

                await MainActor.run {
                    let pieceImage = WorkImage(
                        filePath: relativePath,
                        fileName: "IMG_\(currentCount + index + 1)",
                        sortOrder: currentCount + index
                    )
                    pieceImage.sessionProgress = imageGroup
                    modelContext.insert(pieceImage)
                }
            } catch {
                // Continue with remaining images if one fails
                continue
            }
        }

        await MainActor.run {
            isProcessing = false
        }
    }

    private func deleteImage(_ pieceImage: WorkImage) {
        Task {
            try? await ImageStorageService.shared.deleteImage(relativePath: pieceImage.filePath)
        }
        modelContext.delete(pieceImage)
    }
}

/// Single thumbnail cell in the gallery grid
struct ImageThumbnailCell: View {
    let pieceImage: WorkImage
    @State private var thumbnail: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.primary.opacity(0.05))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ProgressView()
                }
            }
            .clipped()
            .task {
                await loadThumbnail()
            }
    }

    private func loadThumbnail() async {
        guard let image = await ImageStorageService.shared.loadImage(relativePath: pieceImage.filePath) else { return }
        // Downsample for grid performance
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumb = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        await MainActor.run {
            self.thumbnail = thumb
        }
    }
}

