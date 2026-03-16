import SwiftUI
import SwiftData

// MARK: - Flash Portfolio Tab

struct FlashPortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Client> { $0.isFlashPortfolioClient })
    private var portfolioClients: [Client]

    @State private var selectionMode = false
    @State private var selectedPieceIDs: Set<PersistentIdentifier> = []
    @State private var showAddDesign = false
    @State private var showSheetBuilder = false
    @State private var transferPiece: Piece?
    @State private var searchText = ""
    @State private var navigateToPiece: Piece?

    private var portfolioClient: Client? { portfolioClients.first }

    private var flashPieces: [Piece] {
        guard let client = portfolioClient else { return [] }
        let pieces = client.pieces
        let sorted = pieces.sorted { $0.updatedAt > $1.updatedAt }
        guard !searchText.isEmpty else { return sorted }
        let q = searchText.lowercased()
        return sorted.filter {
            $0.title.lowercased().contains(q) ||
            $0.tags.contains { $0.lowercased().contains(q) } ||
            $0.descriptionText.lowercased().contains(q)
        }
    }

    private var selectedPieces: [Piece] {
        flashPieces.filter { selectedPieceIDs.contains($0.persistentModelID) }
    }

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if portfolioClient == nil {
                    setupState
                } else if flashPieces.isEmpty && searchText.isEmpty {
                    emptyState
                } else {
                    gallery
                }
            }
            .navigationTitle("Flash Portfolio")
            .searchable(text: $searchText, prompt: "Search designs…")
            .toolbar { toolbarContent }
            .navigationDestination(item: $navigateToPiece) { piece in
                PieceDetailView(piece: piece)
            }
            .sheet(isPresented: $showAddDesign) {
                AddFlashDesignSheet(portfolioClient: portfolioClient)
            }
            .sheet(isPresented: $showSheetBuilder) {
                FlashSheetBuilderView(pieces: selectedPieces) {
                    selectionMode = false
                    selectedPieceIDs.removeAll()
                }
            }
            .sheet(item: $transferPiece) { piece in
                TransferFlashPieceView(piece: piece)
            }
        }
    }

    // MARK: - Gallery Grid

    @ViewBuilder
    private var gallery: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(flashPieces) { piece in
                    FlashPortfolioCell(
                        piece: piece,
                        isSelected: selectionMode && selectedPieceIDs.contains(piece.persistentModelID),
                        onTap: {
                            if selectionMode {
                                toggleSelection(piece)
                            } else {
                                navigateToPiece = piece
                            }
                        },
                        onTransfer: {
                            transferPiece = piece
                        }
                    )
                }
            }
            .padding(16)
        }
    }

    // MARK: - Empty / Setup States

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Flash Designs", systemImage: "bolt.fill")
        } description: {
            Text("Add your available flash designs here. Transfer them to clients when purchased.")
        } actions: {
            Button("Add Design") { showAddDesign = true }
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var setupState: some View {
        ContentUnavailableView {
            Label("Flash Portfolio", systemImage: "bolt.fill")
        } description: {
            Text("Set up your flash portfolio to manage your available designs separately from client work.")
        } actions: {
            Button("Set Up Portfolio") { createPortfolioClient() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if selectionMode {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    withAnimation {
                        selectionMode = false
                        selectedPieceIDs.removeAll()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSheetBuilder = true
                } label: {
                    Label("Create Sheet", systemImage: "square.grid.2x2")
                }
                .fontWeight(.semibold)
                .disabled(selectedPieceIDs.isEmpty)
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                if !flashPieces.isEmpty {
                    Button("Select") {
                        withAnimation { selectionMode = true }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddDesign = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Helpers

    private func toggleSelection(_ piece: Piece) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedPieceIDs.contains(piece.persistentModelID) {
                selectedPieceIDs.remove(piece.persistentModelID)
            } else {
                selectedPieceIDs.insert(piece.persistentModelID)
            }
        }
    }

    private func createPortfolioClient() {
        let client = Client(firstName: "Flash", lastName: "Portfolio")
        client.isFlashPortfolioClient = true
        modelContext.insert(client)
    }
}

// MARK: - Flash Portfolio Cell

private struct FlashPortfolioCell: View {
    let piece: Piece
    let isSelected: Bool
    let onTap: () -> Void
    let onTransfer: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Thumbnail
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.06))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let thumb = thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                            .transition(.opacity)
                    }
                }
                .clipped()

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(piece.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(piece.status.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(statusColor)

                    Spacer()

                    if let flat = piece.flatRate {
                        Text(flat, format: .currency(code: "USD"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            Button {
                onTap()   // navigate when not in selection mode
            } label: {
                Label("View Design", systemImage: "eye")
            }
            Divider()
            Button {
                onTransfer()
            } label: {
                Label("Transfer to Client", systemImage: "person.crop.circle.badge.checkmark")
            }
        }
        .task { await loadThumbnail() }
    }

    private var statusColor: Color {
        switch piece.status {
        case .concept:              .gray
        case .designInProgress:     .orange
        case .approved:             .green
        case .completed:            .blue
        case .archived:             .secondary
        default:                    .secondary
        }
    }

    private func loadThumbnail() async {
        guard let path = piece.primaryImagePath,
              let img = await ImageStorageService.shared.loadImage(relativePath: path) else { return }
        let size = CGSize(width: 400, height: 400)
        let thumb = UIGraphicsImageRenderer(size: size).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
        await MainActor.run { thumbnail = thumb }
    }
}

// MARK: - Add Flash Design Sheet

struct AddFlashDesignSheet: View {
    let portfolioClient: Client?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var price: Decimal = 150
    @State private var sizeNote = ""
    @State private var tagInput = ""
    @State private var tags: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Design") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                    TextField("Size (e.g. 3\" × 3\")", text: $sizeNote)
                }

                Section("Pricing") {
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("$0", value: $price, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    HStack {
                        TextField("Add tag…", text: $tagInput)
                        Button("Add") {
                            let t = tagInput.trimmingCharacters(in: .whitespaces)
                            guard !t.isEmpty else { return }
                            tags.append(t)
                            tagInput = ""
                        }
                        .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    ForEach(tags, id: \.self) { tag in
                        Text(tag).foregroundStyle(.secondary)
                    }
                    .onDelete { tags.remove(atOffsets: $0) }
                } header: {
                    Text("Tags")
                }
            }
            .navigationTitle("New Flash Design")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let client = portfolioClient else { return }
        let piece = Piece(
            title: title.trimmingCharacters(in: .whitespaces),
            bodyPlacement: sizeNote,
            descriptionText: description,
            status: .concept,
            pieceType: .flash,
            tags: tags,
            hourlyRate: 0,
            flatRate: price > 0 ? price : nil,
            depositAmount: 0
        )
        piece.client = client
        modelContext.insert(piece)
        dismiss()
    }
}

// MARK: - Transfer Flash Piece

struct TransferFlashPieceView: View {
    let piece: Piece

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Client> { !$0.isFlashPortfolioClient },
           sort: \Client.lastName)
    private var clients: [Client]

    @State private var selectedClient: Client?
    @State private var searchText = ""

    private var filteredClients: [Client] {
        guard !searchText.isEmpty else { return clients }
        let q = searchText.lowercased()
        return clients.filter {
            $0.fullName.lowercased().contains(q) ||
            $0.email.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredClients) { client in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.fullName)
                            .font(.body.weight(.medium))
                        if !client.email.isEmpty {
                            Text(client.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if selectedClient?.persistentModelID == client.persistentModelID {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                            .fontWeight(.semibold)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedClient = client }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search clients…")
            .navigationTitle("Transfer \"\(piece.title)\"")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Transfer") { transfer() }
                        .fontWeight(.semibold)
                        .disabled(selectedClient == nil)
                }
            }
        }
    }

    private func transfer() {
        guard let client = selectedClient else { return }
        piece.client = client
        piece.status = .approved
        dismiss()
    }
}

// MARK: - Flash Sheet Builder

struct FlashSheetBuilderView: View {
    let pieces: [Piece]
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var columnCount: Int = 2
    @State private var showPrices: Bool = true
    @State private var showHandle: Bool = true
    @State private var sheetTitle: String = ""
    @State private var loadedImages: [String: UIImage] = [:]
    @State private var renderedImage: UIImage?

    private var handle: String {
        profiles.first?.businessName.isEmpty == false
            ? profiles.first!.businessName
            : profiles.first.map { "\($0.firstName) \($0.lastName)" } ?? "Artist"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Live preview
                ScrollView {
                    FlashSheetContent(
                        pieces: pieces,
                        columnCount: columnCount,
                        showPrices: showPrices,
                        showHandle: showHandle,
                        sheetTitle: sheetTitle,
                        handle: handle,
                        loadedImages: loadedImages
                    )
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                    .padding()
                }

                Divider()

                // Controls
                Form {
                    Section {
                        Picker("Columns", selection: $columnCount) {
                            Text("2 Columns").tag(2)
                            Text("3 Columns").tag(3)
                        }
                        .pickerStyle(.segmented)
                        Toggle("Show Prices", isOn: $showPrices)
                        Toggle("Show Artist Handle", isOn: $showHandle)
                        TextField("Sheet Title (optional)", text: $sheetTitle)
                    }
                }
                .frame(maxHeight: 230)
                .scrollDisabled(true)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Flash Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let img = renderedImage {
                        ShareLink(
                            item: Image(uiImage: img),
                            preview: SharePreview(sheetTitle.isEmpty ? "Flash Sheet" : sheetTitle,
                                                  image: Image(uiImage: img))
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .fontWeight(.semibold)
                    } else {
                        ProgressView()
                    }
                }
            }
            .task { await loadImages() }
            .onChange(of: columnCount)  { _, _ in Task { @MainActor in renderSheet() } }
            .onChange(of: showPrices)   { _, _ in Task { @MainActor in renderSheet() } }
            .onChange(of: showHandle)   { _, _ in Task { @MainActor in renderSheet() } }
            .onChange(of: sheetTitle)   { _, _ in Task { @MainActor in renderSheet() } }
        }
    }

    private func loadImages() async {
        var loaded: [String: UIImage] = [:]
        for piece in pieces {
            if let path = piece.primaryImagePath,
               let img = await ImageStorageService.shared.loadImage(relativePath: path) {
                loaded[path] = img
            }
        }
        await MainActor.run {
            loadedImages = loaded
            renderSheet()
        }
    }

    @MainActor
    private func renderSheet() {
        let content = FlashSheetContent(
            pieces: pieces,
            columnCount: columnCount,
            showPrices: showPrices,
            showHandle: showHandle,
            sheetTitle: sheetTitle,
            handle: handle,
            loadedImages: loadedImages
        )
        .frame(width: 1080)
        .background(Color.white)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2.0
        renderedImage = renderer.uiImage
    }
}

// MARK: - Flash Sheet Renderable Content

struct FlashSheetContent: View {
    let pieces: [Piece]
    let columnCount: Int
    let showPrices: Bool
    let showHandle: Bool
    let sheetTitle: String
    let handle: String
    let loadedImages: [String: UIImage]

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: columnCount)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            // Header
            if !sheetTitle.isEmpty || showHandle {
                VStack(spacing: 4) {
                    if !sheetTitle.isEmpty {
                        Text(sheetTitle)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.black)
                    }
                    if showHandle {
                        Text("@\(handle)")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.top, 8)
            }

            // Piece grid
            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(pieces) { piece in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if let path = piece.primaryImagePath,
                                   let img = loadedImages[path] {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image(systemName: "bolt.fill")
                                        .foregroundStyle(Color.gray.opacity(0.4))
                                }
                            }
                            .clipped()

                        Text(piece.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.black)
                            .lineLimit(1)

                        if showPrices, let flat = piece.flatRate {
                            Text(flat, format: .currency(code: "USD"))
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    FlashPortfolioView()
        .modelContainer(PreviewContainer.shared.container)
}
