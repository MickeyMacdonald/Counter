import SwiftUI
import SwiftData

/// Standalone inspiration/reference image library.
/// Non-tattoo imagery tagged for study — not tied to any client or piece.
struct InspirationGalleryView: View {
    @Query(sort: \InspirationImage.capturedAt, order: .reverse) private var images: [InspirationImage]
    @Environment(\.modelContext) private var modelContext

    @State private var showImporter = false
    @State private var filterTag = ""
    @State private var editingImage: InspirationImage?

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 6)]

    private var filteredImages: [InspirationImage] {
        guard !filterTag.isEmpty else { return images }
        return images.filter { $0.tags.contains { $0.localizedCaseInsensitiveContains(filterTag) } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            inspirationHeader
            Divider()
            if filteredImages.isEmpty { inspirationEmpty } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(filteredImages) { image in
                            InspirationCell(image: image)
                                .onTapGesture { editingImage = image }
                                .contextMenu {
                                    Button(role: .destructive) { deleteInspiration(image) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(10)
                }
            }
        }
        .sheet(isPresented: $showImporter) {
            PhotoImportPicker(isPresented: $showImporter) { uiImages in
                Task { await saveInspirationImages(uiImages) }
            }
        }
        .sheet(item: $editingImage) { img in InspirationImageDetailView(image: img) }
    }

    private var inspirationHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(Color.accentColor).font(.subheadline)
            Text("Inspiration Library").font(.subheadline.weight(.semibold))
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "tag").font(.caption2)
                TextField("Filter tag", text: $filterTag).font(.caption).frame(width: 80)
                if !filterTag.isEmpty {
                    Button { filterTag = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.primary.opacity(0.06), in: Capsule())
            Button { showImporter = true } label: {
                Image(systemName: "plus.circle.fill").font(.body).foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private var inspirationEmpty: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.plus").font(.system(size: 40)).foregroundStyle(.quaternary)
            Text("No inspiration images yet").font(.subheadline).foregroundStyle(.secondary)
            Button { showImporter = true } label: { Label("Add Images", systemImage: "plus.circle.fill") }
                .buttonStyle(.borderedProminent).tint(Color.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 30)
    }

    private func saveInspirationImages(_ uiImages: [UIImage]) async {
        for (idx, img) in uiImages.enumerated() {
            let name = "\(UUID().uuidString).png"
            let path = "CounterImages/inspiration/\(name)"
            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let dir = docs.appendingPathComponent("CounterImages/inspiration")
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                if let data = img.pngData() { try? data.write(to: dir.appendingPathComponent(name)) }
            }
            await MainActor.run {
                modelContext.insert(InspirationImage(filePath: path, fileName: "Inspiration \(idx + 1)"))
            }
        }
    }

    private func deleteInspiration(_ image: InspirationImage) {
        Task { try? await ImageStorageService.shared.deleteImage(relativePath: image.filePath) }
        modelContext.delete(image)
    }
}

private struct InspirationCell: View {
    let image: InspirationImage
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 10).fill(.primary.opacity(0.05))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let thumb = thumbnail {
                        Image(uiImage: thumb).resizable().scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else { ProgressView() }
                }
                .clipped()
            if !image.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(image.tags.prefix(3), id: \.self) { tag in
                            Text(tag).font(.system(size: 9, weight: .medium)).foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(.black.opacity(0.55), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 5).padding(.vertical, 4)
                }
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

struct InspirationImageDetailView: View {
    @Bindable var image: InspirationImage
    @Environment(\.dismiss) private var dismiss
    @State private var tagInput = ""
    @State private var thumbnail: UIImage?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let thumb = thumbnail {
                        Image(uiImage: thumb).resizable().scaledToFit()
                            .frame(maxHeight: 240).clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(maxWidth: .infinity)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }
                Section("Tags") {
                    if !image.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(image.tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag).font(.caption)
                                        Button {
                                            image.tags.removeAll { $0 == tag }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(.primary.opacity(0.08), in: Capsule())
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    HStack {
                        TextField("Add tag...", text: $tagInput).onSubmit { addDetailTag() }
                        if !tagInput.isEmpty {
                            Button("Add") { addDetailTag() }.font(.subheadline).buttonStyle(.borderless)
                        }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $image.notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .navigationTitle("Inspiration Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .task { thumbnail = await ImageStorageService.shared.loadImage(relativePath: image.filePath) }
        }
    }

    private func addDetailTag() {
        let t = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty && !image.tags.contains(t) { image.tags.append(t) }
        tagInput = ""
    }
}

#Preview {
    InspirationGalleryView()
        .modelContainer(PreviewContainer.shared.container)
}
