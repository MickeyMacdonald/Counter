import SwiftUI
import SwiftData

struct BookingDetailView: View {
    @Bindable var booking: Booking
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(BusinessLockManager.self) private var lockManager

    @Query(sort: \Client.lastName) private var allClients: [Client]

    @State private var showingCancelConfirm = false
    @State private var showingClientPicker  = false
    @State private var showingPiecePicker   = false
    @State private var newTaskText          = ""
    @State private var galleryImages: [WorkImage]  = []
    @State private var galleryInitialImage: WorkImage?
    @State private var showingImageGallery  = false

    private var visibleClients: [Client] {
        allClients.filter { !$0.isFlashPortfolioClient }
    }

    private var allSessionImages: [WorkImage] {
        guard let piece = booking.piece else { return [] }
        return (piece.sessions.flatMap(\.sessionProgress) + piece.sessionProgress)
            .flatMap(\.images)
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Body

    var body: some View {
        List {
            headerSection
            actionSection
            detailsSection
            photosSection
            todosSection
            metaSection
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showingClientPicker) {
            ClientPickerSheet(
                selectedClient: $booking.client,
                onSelect: {
                    if let piece = booking.piece,
                       piece.client?.persistentModelID != booking.client?.persistentModelID {
                        booking.piece = nil
                    }
                    booking.updatedAt = Date()
                }
            )
        }
        .sheet(isPresented: $showingPiecePicker) {
            PiecePickerSheet(
                client: booking.client,
                selectedPiece: $booking.piece,
                onSelect: { booking.updatedAt = Date() }
            )
        }
        .sheet(isPresented: $showingImageGallery) {
            if let initial = galleryInitialImage, !galleryImages.isEmpty {
                FullScreenImageViewer(images: galleryImages, initialImage: initial)
                    .environment(lockManager)
            }
        }
        .alert("Cancel Booking?", isPresented: $showingCancelConfirm) {
            Button("Cancel Booking", role: .destructive) {
                booking.status = .cancelled
                booking.updatedAt = Date()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("This will mark the booking as cancelled.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(booking.bookingType.color.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: booking.bookingType.systemImage)
                        .font(.system(size: 28))
                        .foregroundStyle(booking.bookingType.color)
                }
                VStack(spacing: 4) {
                    Text(booking.bookingType.rawValue)
                        .font(.title2.weight(.bold))
                    Text(booking.date.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                StatusBadge(status: booking.status)

                // Client nav row
                HStack(spacing: 8) {
                    if let client = booking.client {
                        Button { coordinator.navigateToClient(client) } label: {
                            navRowLabel(
                                avatar: AnyView(clientAvatar(client)),
                                title: client.fullName
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        placeholderNavRow(icon: "person.fill", title: "No Client")
                    }
                    changeButton { showingClientPicker = true }
                }

                // Piece nav row
                HStack(spacing: 8) {
                    if let piece = booking.piece {
                        Button { coordinator.navigateToPiece(piece) } label: {
                            navRowLabel(
                                avatar: AnyView(pieceAvatar(piece)),
                                title: piece.title
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        placeholderNavRow(icon: "paintbrush.pointed", title: "No Piece")
                    }
                    changeButton { showingPiecePicker = true }
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private func navRowLabel(avatar: AnyView, title: String) -> some View {
        HStack(spacing: 12) {
            avatar
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func placeholderNavRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 35, height: 35)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
            }
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func clientAvatar(_ client: Client) -> some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 35, height: 35)
            Text(client.initialsDisplay)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Color.accentColor)
        }
    }

    private func pieceAvatar(_ piece: Piece) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.10))
                .frame(width: 35, height: 35)
            Image(systemName: piece.pieceType.systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)
        }
    }

    private func changeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "arrow.2.circlepath")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Bar

    private var actionSection: some View {
        Section {
            HStack(spacing: 20) {
                let client = booking.client

                actionButton(icon: "envelope.fill", label: "Email",
                             disabled: client?.email.isEmpty ?? true) {
                    guard let email = client?.email, !email.isEmpty,
                          let url = URL(string: "mailto:\(email)") else { return }
                    UIApplication.shared.open(url)
                }
                actionButton(icon: "message.fill", label: "Text",
                             disabled: client?.phone.isEmpty ?? true) {
                    guard let phone = client?.phone, !phone.isEmpty else { return }
                    let clean = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
                    if let url = URL(string: "sms:\(clean)") { UIApplication.shared.open(url) }
                }
                actionButton(icon: "phone.fill", label: "Call",
                             disabled: client?.phone.isEmpty ?? true) {
                    guard let phone = client?.phone, !phone.isEmpty else { return }
                    let clean = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
                    if let url = URL(string: "tel://\(clean)") { UIApplication.shared.open(url) }
                }
                if booking.status != .cancelled, booking.status != .completed {
                    let action = currentStatusAction
                    actionButton(icon: action.systemImage, label: action.label,
                                 disabled: false, tint: action.tint) {
                        advanceStatus()
                    }
                }
                if booking.status != .cancelled {
                    actionButton(icon: "xmark.circle.fill", label: "Cancel",
                                 disabled: false, tint: .red) {
                        showingCancelConfirm = true
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    private func actionButton(
        icon: String,
        label: String,
        disabled: Bool,
        tint: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(disabled ? Color.primary.opacity(0.04) : tint.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(disabled ? Color.gray.opacity(0.3) : tint)
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(disabled ? Color.gray.opacity(0.3) : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Details

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            Picker("Session Type", selection: $booking.bookingType) {
                ForEach(BookingType.allCases, id: \.self) { t in
                    Label(t.rawValue, systemImage: t.systemImage).tag(t)
                }
            }
            .onChange(of: booking.bookingType) { _, _ in booking.updatedAt = Date() }

            Picker("Status", selection: $booking.status) {
                ForEach(BookingStatus.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .onChange(of: booking.status) { _, _ in booking.updatedAt = Date() }

            DatePicker("Date", selection: $booking.date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .onChange(of: booking.date) { _, _ in booking.updatedAt = Date() }

            DatePicker("Start", selection: $booking.startTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .onChange(of: booking.startTime) { _, _ in booking.updatedAt = Date() }

            DatePicker("End", selection: $booking.endTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .onChange(of: booking.endTime) { _, _ in booking.updatedAt = Date() }

            LabeledContent {
                Text(booking.durationFormatted)
                    .foregroundStyle(.secondary)
            } label: {
                Label("Duration", systemImage: "hourglass")
            }

            Toggle(isOn: $booking.depositPaid) {
                Label("Deposit Needed", systemImage: "dollarsign.circle")
            }
            .onChange(of: booking.depositPaid) { _, _ in booking.updatedAt = Date() }
        }
    }

    // MARK: - Photos

    @ViewBuilder
    private var photosSection: some View {
        let images = allSessionImages
        if !images.isEmpty {
            Section("Photos") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3),
                    spacing: 3
                ) {
                    ForEach(images) { image in
                        Button {
                            galleryImages       = images
                            galleryInitialImage = image
                            showingImageGallery = true
                        } label: {
                            BookingPhotoCell(filePath: image.filePath)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    // MARK: - TODOs

    @ViewBuilder
    private var todosSection: some View {
        Section("To Do") {
            ForEach(booking.prepTasks) { task in
                let done = effectiveCompletion(for: task)
                Button { togglePrepTask(task) } label: {
                    checklistRow(icon: task.icon, label: task.label, isComplete: done)
                }
                .buttonStyle(.plain)
            }

            ForEach(booking.customChecklistItems) { task in
                Button { toggleCustomTask(task) } label: {
                    checklistRow(
                        icon: task.isComplete ? "checkmark.circle.fill" : "circle",
                        label: task.label,
                        isComplete: task.isComplete,
                        isCustom: true
                    )
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { deleteCustomTask(task) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentColor)
                TextField("Add to-do…", text: $newTaskText)
                    .onSubmit { addCustomTask() }
            }
        }
    }

    private func checklistRow(icon: String, label: String, isComplete: Bool, isCustom: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(isComplete ? Color.green : Color.secondary)
            if isCustom {
                Text(label)
                    .foregroundStyle(isComplete ? Color.secondary : Color.primary)
                    .strikethrough(isComplete, color: .secondary)
            } else {
                Label(label, systemImage: icon)
                    .foregroundStyle(isComplete ? Color.secondary : Color.primary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    // MARK: - Checklist Helpers

    private func effectiveCompletion(for task: PrepTask) -> Bool {
        let overridden = booking.checklistOverrides.contains(task.label)
        return overridden ? !task.isComplete : task.isComplete
    }

    private func togglePrepTask(_ task: PrepTask) {
        if booking.checklistOverrides.contains(task.label) {
            booking.checklistOverrides.removeAll { $0 == task.label }
        } else {
            booking.checklistOverrides.append(task.label)
        }
        booking.updatedAt = Date()
    }

    private func toggleCustomTask(_ task: BookingCustomTask) {
        guard let idx = booking.customChecklistItems.firstIndex(where: { $0.id == task.id }) else { return }
        booking.customChecklistItems[idx].isComplete.toggle()
        booking.updatedAt = Date()
    }

    private func deleteCustomTask(_ task: BookingCustomTask) {
        booking.customChecklistItems.removeAll { $0.id == task.id }
        booking.updatedAt = Date()
    }

    private func addCustomTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        booking.customChecklistItems.append(BookingCustomTask(label: trimmed))
        newTaskText = ""
        booking.updatedAt = Date()
    }

    // MARK: - Meta

    private var metaSection: some View {
        Section {
            LabeledContent("Created", value: booking.createdAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent("Updated", value: booking.updatedAt.formatted(date: .abbreviated, time: .shortened))
        }
    }

    // MARK: - Status Helpers

    private var currentStatusAction: BookingAction {
        switch booking.status {
        case .requested:  return .confirm
        case .confirmed:  return .start
        default:          return .complete
        }
    }

    private func advanceStatus() {
        switch booking.status {
        case .requested:  booking.status = .confirmed
        case .confirmed:  booking.status = .inProgress
        default:          booking.status = .completed
        }
        booking.updatedAt = Date()
    }
}

// MARK: - Booking Photo Cell

private struct BookingPhotoCell: View {
    let filePath: String
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.primary.opacity(0.06)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .task {
            image = await ImageStorageService.shared.loadImage(relativePath: filePath)
        }
    }
}

// MARK: - Client Picker Sheet

private struct ClientPickerSheet: View {
    @Binding var selectedClient: Client?
    var onSelect: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Client.lastName) private var allClients: [Client]
    @State private var searchText = ""

    private var visibleClients: [Client] {
        allClients.filter {
            !$0.isFlashPortfolioClient &&
            (searchText.isEmpty || $0.fullName.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if selectedClient != nil {
                    Button(role: .destructive) {
                        selectedClient = nil; onSelect(); dismiss()
                    } label: {
                        Label("Remove Client", systemImage: "person.slash")
                    }
                }
                ForEach(visibleClients) { client in
                    Button {
                        selectedClient = client; onSelect(); dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.10))
                                    .frame(width: 32, height: 32)
                                Text(client.initialsDisplay)
                                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            Text(client.fullName).foregroundStyle(.primary)
                            Spacer()
                            if selectedClient?.persistentModelID == client.persistentModelID {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search clients…")
            .navigationTitle("Select Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Piece Picker Sheet

private struct PiecePickerSheet: View {
    let client: Client?
    @Binding var selectedPiece: Piece?
    var onSelect: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var availablePieces: [Piece] {
        let pieces = client?.pieces.sorted { $0.title < $1.title } ?? []
        guard !searchText.isEmpty else { return pieces }
        return pieces.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if client == nil {
                    ContentUnavailableView(
                        "No Client Selected",
                        systemImage: "person.slash",
                        description: Text("Assign a client first to pick a piece.")
                    )
                } else if availablePieces.isEmpty && searchText.isEmpty {
                    ContentUnavailableView(
                        "No Pieces",
                        systemImage: "paintbrush.pointed",
                        description: Text("This client has no pieces yet.")
                    )
                } else {
                    List {
                        if selectedPiece != nil {
                            Button(role: .destructive) {
                                selectedPiece = nil; onSelect(); dismiss()
                            } label: {
                                Label("Remove Piece", systemImage: "paintbrush.pointed")
                            }
                        }
                        ForEach(availablePieces) { piece in
                            Button {
                                selectedPiece = piece; onSelect(); dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.accentColor.opacity(0.10))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: piece.pieceType.systemImage)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(piece.title).foregroundStyle(.primary)
                                        Text(piece.bodyPlacement)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedPiece?.persistentModelID == piece.persistentModelID {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search pieces…")
                }
            }
            .navigationTitle("Select Piece")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Booking Action

enum BookingAction: String, CaseIterable {
    case confirm, start, complete

    var label: String {
        switch self {
        case .confirm:  "Confirm"
        case .start:    "Start"
        case .complete: "Complete"
        }
    }

    var systemImage: String {
        switch self {
        case .confirm:  "checkmark.circle"
        case .start:    "flame"
        case .complete: "checkmark.seal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .confirm:  .blue
        case .start:    .purple
        case .complete: .green
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: BookingStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.systemImage)
                .font(.caption2)
            Text(status.rawValue)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.15))
        .foregroundStyle(badgeColor)
        .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch status {
        case .requested:  .orange
        case .confirmed:  .blue
        case .inProgress: .purple
        case .completed:  .green
        case .cancelled:  .red
        case .noShow:     .gray
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BookingDetailView(booking: {
            let b = Booking(bookingType: .session, notes: "Full sleeve continuation, left arm")
            return b
        }())
    }
    .modelContainer(PreviewContainer.shared.container)
    .environment(AppNavigationCoordinator())
    .environment(BusinessLockManager())
}
