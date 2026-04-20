import SwiftUI

/// Image viewer with a proper top navigation bar, metadata pills, and forward/back arrows.
struct FullScreenImageViewer: View {
    let images: [PieceImage]
    let initialImage: PieceImage

    @Environment(\.dismiss) private var dismiss
    @Environment(BusinessLockManager.self) private var lockManager
    @State private var currentIndex: Int = 0
    @State private var showingShareSheet = false

    private var currentImage: PieceImage? {
        guard currentIndex >= 0, currentIndex < images.count else { return nil }
        return images[currentIndex]
    }

    private var currentGroup: SessionProgress? {
        currentImage?.sessionProgress
    }

    /// Resolves the piece via direct ownership or through the image group chain
    private var currentPiece: Piece? {
        currentImage?.piece ?? currentGroup?.piece
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Metadata pills
                if let image = currentImage {
                    infoBar(image)
                    Divider()
                }

                // Image
                ZStack {
                    Color.black.ignoresSafeArea()

                    if let image = currentImage {
                        ZoomableImageView(pieceImage: image)
                    }
                }

                Divider()

                // Bottom navigation
                bottomBar
            }
            .background(Color.black)
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
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
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
        .onAppear {
            if let idx = images.firstIndex(where: { $0.id == initialImage.id }) {
                currentIndex = idx
            }
        }
    }

    // MARK: - Info Bar

    private func infoBar(_ image: PieceImage) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 1. Rating (business only)
                if !lockManager.isLocked, let rating = currentPiece?.rating {
                    infoPill(
                        icon: "star.fill",
                        text: "\(rating)/5",
                        tint: .yellow
                    )
                }

                // 2. Date
                infoPill(
                    icon: "calendar",
                    text: image.capturedAt.formatted(date: .abbreviated, time: .omitted),
                    tint: .blue
                )

                // 3. Stage or Category
                if let stage = currentGroup?.stage {
                    infoPill(
                        icon: stage.systemImage,
                        text: stage.rawValue,
                        tint: .purple
                    )
                } else if let category = currentImage?.category {
                    infoPill(
                        icon: category.systemImage,
                        text: category.rawValue,
                        tint: .purple
                    )
                }

                // 4. Piece
                if let piece = currentPiece, !piece.title.isEmpty {
                    infoPill(
                        icon: piece.pieceType.systemImage,
                        text: piece.title,
                        tint: .green
                    )
                }

                // 5. Placement
                if let placement = currentPiece?.bodyPlacement, !placement.isEmpty {
                    infoPill(
                        icon: "figure.arms.open",
                        text: placement,
                        tint: .orange
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func infoPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.1), in: Capsule())
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 24) {
            // Previous
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentIndex = max(0, currentIndex - 1)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                    Text("Previous")
                        .font(.subheadline.weight(.medium))
                }
            }
            .disabled(currentIndex <= 0)
            .opacity(currentIndex <= 0 ? 0.3 : 1)

            Spacer()

            // Notes preview
            if let image = currentImage, !image.notes.isEmpty {
                Text(image.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 180)
            }

            Spacer()

            // Next
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentIndex = min(images.count - 1, currentIndex + 1)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Next")
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.right")
                        .fontWeight(.semibold)
                }
            }
            .disabled(currentIndex >= images.count - 1)
            .opacity(currentIndex >= images.count - 1 ? 0.3 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Zoomable Image

struct ZoomableImageView: View {
    let pieceImage: PieceImage
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
                            .onChanged { value in
                                scale = lastScale * value.magnification
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1 {
                                    withAnimation(.spring()) {
                                        scale = 1
                                        lastScale = 1
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1 {
                                scale = 1
                                lastScale = 1
                            } else {
                                scale = 3
                                lastScale = 3
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .task {
            image = await ImageStorageService.shared.loadImage(relativePath: pieceImage.filePath)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let pieceImage: PieceImage
    @State private var loadedImage: UIImage?

    func makeUIViewController(context: Context) -> UIViewController {
        let placeholder = UIViewController()

        Task {
            guard let image = await ImageStorageService.shared.loadImage(relativePath: pieceImage.filePath) else { return }

            await MainActor.run {
                let activityVC = UIActivityViewController(
                    activityItems: [image],
                    applicationActivities: nil
                )
                // On iPad UIActivityViewController is presented as a popover and MUST have a
                // sourceView set — omitting it raises UIPopoverPresentationController exception.
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = placeholder.view
                    popover.sourceRect = CGRect(
                        x: placeholder.view.bounds.midX,
                        y: placeholder.view.bounds.midY,
                        width: 0, height: 0
                    )
                    popover.permittedArrowDirections = []
                }
                placeholder.present(activityVC, animated: true)
            }
        }

        return placeholder
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
