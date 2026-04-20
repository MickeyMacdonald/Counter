import SwiftUI
import SwiftData
import PhotosUI

struct PieceEditView: View {
    enum Mode {
        case add(client: Client)
        case edit(Piece)
    }
    
    let mode: Mode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Photos
    @State private var draftPhotos: [DraftPhoto] = []
    @State private var showPhotoImporter = false
    
    // MARK: - Piece fields
    @State private var rating: Int = 3
    @State private var title = ""
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @State private var pieceType: PieceType = .custom
    @State private var hourlyRate: Decimal = 150
    @State private var depositAmount: Decimal = 0
    
    // MARK: - Size fields
    @AppStorage("pieceSizeMode")  private var sizeMode:      PieceSizeMode = .categorical
    @AppStorage("dimensionUnit")  private var dimensionUnit: DimensionUnit  = .inches
    @State private var sizeCategory: TattooSize? = nil
    @State private var sizeWidth  = ""
    @State private var sizeHeight = ""
    
    // MARK: - Sessions
    @State private var draftSessions: [DraftSession] = []
    @State private var activeDraftSession: DraftSession? = nil
    @State private var showSessionTypePicker = false
    @State private var showSessionSheet = false
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                photosSection
                ratingSection
                infoSection
                sessionsSection
            }
            .navigationTitle(isEditing ? "Edit Piece" : "New Piece")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: loadExistingData)
            .sheet(isPresented: $showPhotoImporter) {
                PhotoImportPicker(isPresented: $showPhotoImporter) { images, _ in
                    for image in images {
                        draftPhotos.append(
                            DraftPhoto(image: image, isPrimary: draftPhotos.isEmpty)
                        )
                    }
                }
            }
            .sheet(isPresented: $showSessionSheet) {
                if let draft = activeDraftSession {
                    SessionDraftView(session: draft, hourlyRate: hourlyRate) { updated in
                        if let idx = draftSessions.firstIndex(where: { $0.id == updated.id }) {
                            draftSessions[idx] = updated
                        } else {
                            draftSessions.append(updated)
                        }
                        activeDraftSession = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Photos
    
    private var photosSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    addPhotoButton
                    
                    ForEach(draftPhotos) { photo in
                        DraftPhotoThumbnail(
                            photo: photo,
                            onSetPrimary: {
                                for i in draftPhotos.indices {
                                    draftPhotos[i].isPrimary = (draftPhotos[i].id == photo.id)
                                }
                            },
                            onDelete: {
                                draftPhotos.removeAll { $0.id == photo.id }
                                if !draftPhotos.isEmpty && !draftPhotos.contains(where: \.isPrimary) {
                                    draftPhotos[0].isPrimary = true
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            Text("Photos")
        } footer: {
            if !draftPhotos.isEmpty {
                Text("Tap a photo to set it as the primary thumbnail. The starred photo appears as the piece preview.")
                    .font(.caption)
            }
        }
    }
    
    private var addPhotoButton: some View {
        Button { showPhotoImporter = true } label: {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .foregroundStyle(.quaternary)
                .frame(width: 90, height: 90)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.title2)
                        Text("Add")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Rating
    
    private var ratingSection: some View {
        Section("Rating") {
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .foregroundStyle(star <= rating ? Color.accentColor : .secondary)
                        .font(.title2)
                        .onTapGesture { rating = star }
                }
                Spacer()
                Text("\(rating) / 5")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .monospacedDigit()
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Info
    
    private var infoSection: some View {
        Section("Piece Info") {
            TextField("Title", text: $title)
            
            // Tag chips
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption)
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.primary.opacity(0.08), in: Capsule())
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            
            HStack {
                TextField("Add tag...", text: $tagInput)
                    .onSubmit { submitTag() }
                if !tagInput.isEmpty {
                    Button("Add") { submitTag() }
                        .font(.subheadline)
                        .buttonStyle(.borderless)
                }
            }
            
            Picker("Type", selection: $pieceType) {
                ForEach(PieceType.allCases, id: \.self) { t in
                    Label(t.rawValue, systemImage: t.systemImage).tag(t)
                }
            }
            .pickerStyle(.menu)
            
            sizeField
        }
    }
    
    // MARK: - Size Field
    
    @ViewBuilder
    private var sizeField: some View {
        switch sizeMode {
        case .categorical:
            Picker("Size", selection: $sizeCategory) {
                Text("Not Set").tag(Optional<TattooSize>.none)
                ForEach(TattooSize.allCases, id: \.self) { s in
                    Label(s.rawValue, systemImage: s.systemImage).tag(Optional<TattooSize>.some(s))
                }
            }
            .pickerStyle(.menu)
        case .dimensional:
            HStack(spacing: 8) {
                Label("Size", systemImage: "arrow.up.left.and.arrow.down.right")
                    .foregroundStyle(.primary)
                Spacer()
                TextField("W", text: $sizeWidth)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 52)
                Text(dimensionUnit.symbol)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Text("×")
                    .foregroundStyle(.secondary)
                TextField("H", text: $sizeHeight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 52)
                Text(dimensionUnit.symbol)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Sessions
    private var sessionsSection: some View {
        Section {
            // Existing draft sessions
            ForEach(draftSessions) { session in
                Button {
                    activeDraftSession = session
                    showSessionSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: session.sessionType.systemImage)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.sessionType.rawValue)
                                .foregroundStyle(.primary)
                                .font(.body)
                            Text(session.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if session.isNoShow {
                            Image(systemName: "person.slash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        draftSessions.removeAll { $0.id == session.id }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            // Session type picker rows (shown after tapping Add Session)
            if showSessionTypePicker {
                ForEach(SessionType.allCases, id: \.self) { type in
                    Button {
                        activeDraftSession = DraftSession(sessionType: type)
                        showSessionTypePicker = false
                        showSessionSheet = true
                    } label: {
                        Label(type.rawValue, systemImage: type.systemImage)
                            .foregroundStyle(.primary)
                    }
                }
                Button("Cancel") {
                    showSessionTypePicker = false
                }
                .foregroundStyle(.red)
            } else {
                Button {
                    showSessionTypePicker = true
                } label: {
                    Label("Add Session", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
        } header: {
            Text("Sessions")
        }
    }

    // MARK: - Helpers

    private func submitTag() {
        let tag = tagInput.trimmed
        if !tag.isEmpty && !tags.contains(tag) {
            tags.append(tag)
        }
        tagInput = ""
    }

    private func loadExistingData() {
        guard case .edit(let piece) = mode else { return }
        title = piece.title
        tags = piece.tags
        pieceType = piece.pieceType
        rating = piece.rating ?? 3
        hourlyRate = piece.hourlyRate
        depositAmount = piece.depositAmount
        // Size
        sizeCategory = piece.size
        if let dims = piece.sizeDimensions {
            let (w, h): (Double, Double) = dimensionUnit == .centimeters
                ? (dims.widthInches * 2.54, dims.heightInches * 2.54)
                : (dims.widthInches, dims.heightInches)
            let fmt = dimensionUnit == .centimeters ? "%.0f" : "%.1f"
            sizeWidth  = String(format: fmt, w)
            sizeHeight = String(format: fmt, h)
        }
    }

    // MARK: - Size helper

    private func applySize(to piece: Piece) {
        switch sizeMode {
        case .categorical:
            piece.size = sizeCategory
            piece.sizeDimensions = nil
        case .dimensional:
            piece.size = nil
            let w = Double(sizeWidth.replacingOccurrences(of: ",", with: ".")) ?? 0
            let h = Double(sizeHeight.replacingOccurrences(of: ",", with: ".")) ?? 0
            if w > 0 || h > 0 {
                let factor = dimensionUnit == .centimeters ? (1.0 / 2.54) : 1.0
                piece.sizeDimensions = PieceDimensions(widthInches: w * factor, heightInches: h * factor)
            } else {
                piece.sizeDimensions = nil
            }
        }
    }

    // MARK: - Save

    private func save() {
        switch mode {
        case .add(let client):
            let piece = Piece(
                title: title.trimmed,
                pieceType: pieceType,
                tags: tags,
                rating: rating,
                hourlyRate: hourlyRate
            )
            piece.client = client
            applySize(to: piece)
            modelContext.insert(piece)

            // Persist photos as direct reference images on the piece
            if !draftPhotos.isEmpty {
                let clientIDStr = String(client.persistentModelID.hashValue)
                let pieceIDStr = String(piece.persistentModelID.hashValue)

                for (idx, draftPhoto) in draftPhotos.enumerated() {
                    let isPrimary = draftPhoto.isPrimary
                    let image = draftPhoto.image
                    Task {
                        if let relativePath = try? await ImageStorageService.shared.saveImage(
                            image,
                            clientID: clientIDStr,
                            pieceID: pieceIDStr,
                            stage: ImageCategory.reference.rawValue
                        ) {
                            await MainActor.run {
                                let pieceImage = WorkImage(
                                    filePath: relativePath,
                                    fileName: "IMG_\(idx + 1)",
                                    sortOrder: idx,
                                    isPrimary: isPrimary,
                                    category: .reference
                                )
                                pieceImage.piece = piece
                                modelContext.insert(pieceImage)
                                if isPrimary {
                                    piece.primaryImagePath = relativePath
                                }
                            }
                        }
                    }
                }
            }

            // Persist draft sessions
            for draft in draftSessions {
                let session = Session(
                    date: draft.date,
                    startTime: draft.startTime,
                    endTime: draft.isManualOverride ? nil : draft.endTime,
                    sessionType: draft.sessionType,
                    hourlyRateAtTime: hourlyRate,
                    flashRate: draft.flashRate,
                    manualHoursOverride: draft.isManualOverride ? draft.manualHours : nil,
                    isNoShow: draft.isNoShow,
                    noShowFee: (draft.isNoShow && draft.chargeNoShowFee) ? draft.noShowFee : nil,
                    notes: draft.notes
                )
                session.piece = piece
                modelContext.insert(session)
            }

            client.updatedAt = Date()

        case .edit(let piece):
            piece.title = title.trimmed
            piece.tags = tags
            piece.pieceType = pieceType
            piece.rating = rating
            piece.hourlyRate = hourlyRate
            piece.depositAmount = depositAmount
            applySize(to: piece)

            // Save any newly added draft photos
            if !draftPhotos.isEmpty {
                let clientIDStr = piece.client.map { String($0.persistentModelID.hashValue) } ?? "unknown"
                let pieceIDStr = String(piece.persistentModelID.hashValue)
                let existingCount = piece.images.count
                for (idx, draftPhoto) in draftPhotos.enumerated() {
                    let isPrimary = draftPhoto.isPrimary && piece.primaryImagePath == nil
                    let image = draftPhoto.image
                    let sortOffset = existingCount + idx
                    Task {
                        if let relativePath = try? await ImageStorageService.shared.saveImage(
                            image,
                            clientID: clientIDStr,
                            pieceID: pieceIDStr,
                            stage: ImageCategory.reference.rawValue
                        ) {
                            await MainActor.run {
                                let pieceImage = WorkImage(
                                    filePath: relativePath,
                                    fileName: "IMG_\(sortOffset + 1)",
                                    sortOrder: sortOffset,
                                    isPrimary: isPrimary,
                                    category: .reference
                                )
                                pieceImage.piece = piece
                                modelContext.insert(pieceImage)
                                if isPrimary {
                                    piece.primaryImagePath = relativePath
                                }
                            }
                        }
                    }
                }
            }

            piece.updatedAt = Date()
        }

        dismiss()
    }

    // MARK: - Photo Thumbnail
    
    private struct DraftPhotoThumbnail: View {
        let photo: DraftPhoto
        let onSetPrimary: () -> Void
        let onDelete: () -> Void
        
        var body: some View {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                photo.isPrimary ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .onTapGesture { onSetPrimary() }
                
                // Primary star badge
                if photo.isPrimary {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.accentColor, in: Circle())
                        .offset(x: -6, y: 6)
                        .zIndex(1)
                }
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .background(Color.black.opacity(0.5), in: Circle())
                }
                .offset(x: 6, y: -6)
            }
        }
    }
}

#Preview {
    PieceEditView(mode: .add(client: Client(firstName: "Test", lastName: "Client")))
        .modelContainer(PreviewContainer.shared.container)
}
