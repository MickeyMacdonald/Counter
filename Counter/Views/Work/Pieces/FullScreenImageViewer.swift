import SwiftUI

struct FullScreenImageViewer: View {
    let images: [WorkImage]
    let initialImage: WorkImage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(BusinessLockManager.self) private var lockManager
    @State private var currentIndex: Int = 0
    @State private var showingShareSheet = false
    @State private var showingDeleteConfirm = false

    private var currentImage: WorkImage? {
        guard currentIndex >= 0, currentIndex < images.count else { return nil }
        return images[currentIndex]
    }

    private var currentPiece: Piece? {
        currentImage?.piece ?? currentImage?.sessionProgress?.piece
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Photo — top, fixed height, zoomable
                ZStack {
                    Color.black
                    if let image = currentImage {
                        ZoomableImageView(pieceImage: image)
                    }
                }
                .frame(height: 360)

                // Navigation strip
                navStrip
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .systemBackground))

                Divider()

                // Editable metadata
                if let image = currentImage {
                    ImageMetadataPanel(image: image, piece: currentPiece, lockManager: lockManager)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .fontWeight(.semibold)
                            Text("Close")
                                .fontWeight(.semibold)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("\(currentIndex + 1) of \(images.count)")
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button { showingShareSheet = true } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = currentImage {
                ShareSheetView(pieceImage: image)
            }
        }
        .confirmationDialog("Delete Photo", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteCurrentImage() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This photo will be permanently deleted.")
        }
        .onAppear {
            if let idx = images.firstIndex(where: { $0.id == initialImage.id }) {
                currentIndex = idx
            }
        }
    }

    // MARK: - Delete

    private func deleteCurrentImage() {
        guard let image = currentImage else { return }
        if image.isPrimary {
            currentPiece?.primaryImagePath = nil
        }
        Task { try? await ImageStorageService.shared.deleteImage(relativePath: image.filePath) }
        modelContext.delete(image)
        // Move index back if we were at the last image
        if currentIndex >= images.count - 1 {
            currentIndex = max(0, currentIndex - 1)
        }
        if images.isEmpty { dismiss() }
    }

    // MARK: - Navigation Strip

    private var navStrip: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentIndex = max(0, currentIndex - 1)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                    Text("Previous").font(.subheadline.weight(.medium))
                }
            }
            .disabled(currentIndex <= 0)
            .opacity(currentIndex <= 0 ? 0.3 : 1)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentIndex = min(images.count - 1, currentIndex + 1)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Next").font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.right").fontWeight(.semibold)
                }
            }
            .disabled(currentIndex >= images.count - 1)
            .opacity(currentIndex >= images.count - 1 ? 0.3 : 1)
        }
    }
}

// MARK: - Metadata Panel

private struct ImageMetadataPanel: View {
    @Bindable var image: WorkImage
    let piece: Piece?
    let lockManager: BusinessLockManager

    private let editableCategories: [ImageCategory] = [
        .reference, .inspiration, .progress, .healed, .portfolio
    ]

    private var isThumbnail: Bool { image.isPrimary }

    var body: some View {
        List {
            Section("Image Details") {
                LabeledContent("Name") {
                    TextField("Untitled", text: $image.title)
                        .multilineTextAlignment(.trailing)
                }

                Picker("Type", selection: $image.category) {
                    ForEach(editableCategories, id: \.self) { cat in
                        Label(cat.rawValue, systemImage: cat.systemImage).tag(cat)
                    }
                }

                Toggle("Portfolio / Client Visible", isOn: $image.isPortfolio)

                // Thumbnail designation — only one per piece
                Button {
                    setAsThumbnail()
                } label: {
                    HStack {
                        Label(
                            isThumbnail ? "Piece Thumbnail" : "Set as Piece Thumbnail",
                            systemImage: isThumbnail ? "star.fill" : "star"
                        )
                        .foregroundStyle(isThumbnail ? Color.yellow : Color.primary)
                        Spacer()
                        if isThumbnail {
                            Text("Current")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(isThumbnail)

                LabeledContent("Notes") {
                    TextField("Add notes…", text: $image.notes, axis: .vertical)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2...4)
                }
            }

            Section("Context") {
                LabeledContent("Captured", value: image.capturedAt.formatted(date: .abbreviated, time: .omitted))

                if let piece {
                    LabeledContent("Piece", value: piece.title)
                    if !piece.bodyPlacement.isEmpty {
                        LabeledContent("Placement", value: piece.bodyPlacement)
                    }
                    if !lockManager.isLocked, let rating = piece.rating {
                        LabeledContent("Piece Rating", value: "\(rating) / 5")
                    }
                }

                if let stage = image.sessionProgress?.stage {
                    LabeledContent("Session Stage", value: stage.rawValue)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func setAsThumbnail() {
        // Clear isPrimary on all sibling images
        piece?.images.forEach { $0.isPrimary = false }
        image.isPrimary = true
        piece?.primaryImagePath = image.filePath
    }
}

// MARK: - Zoomable Image

struct ZoomableImageView: View {
    let pieceImage: WorkImage
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in scale = lastScale * value.magnification }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1 { withAnimation(.spring()) { scale = 1; lastScale = 1 } }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1 { scale = 1; lastScale = 1 } else { scale = 3; lastScale = 3 }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .task(id: pieceImage.filePath) {
            image = nil
            image = await ImageStorageService.shared.loadImage(relativePath: pieceImage.filePath)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let pieceImage: WorkImage

    func makeUIViewController(context: Context) -> UIViewController {
        let placeholder = UIViewController()
        Task {
            guard let image = await ImageStorageService.shared.loadImage(relativePath: pieceImage.filePath) else { return }
            await MainActor.run {
                let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = placeholder.view
                    popover.sourceRect = CGRect(x: placeholder.view.bounds.midX, y: placeholder.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                placeholder.present(activityVC, animated: true)
            }
        }
        return placeholder
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
