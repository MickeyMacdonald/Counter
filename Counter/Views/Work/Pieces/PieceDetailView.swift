import SwiftUI
import SwiftData

struct PieceDetailView: View {
    @Bindable var piece: Piece
    @Environment(\.modelContext) private var modelContext
    @Environment(BusinessLockManager.self) private var lockManager
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Query private var profiles: [UserProfile]
    @State private var showingEditPiece = false
    @State private var showingAddSession = false
    @State private var showingStageManager = false
    @State private var showingTimeLog: SessionProgress?
    @State private var showingLogPayment = false
    @State private var showingFinancialDetail = false
    @State private var editingSession: Session?
    @State private var galleryImages: [PieceImage] = []
    @State private var galleryInitialImage: PieceImage?
    @State private var showingImageGallery = false
    @State private var showingEmailPicker = false
    @State private var showDiscount = false
    @State private var selectedDiscount: Discount?
    @Query(sort: \Discount.sortOrder) private var discounts: [Discount]

    @AppStorage("pieceSizeMode")  private var sizeMode:      PieceSizeMode = .categorical
    @AppStorage("dimensionUnit")  private var dimensionUnit: DimensionUnit  = .inches

    private var chargeableTypes: [String] {
        profiles.first?.effectiveChargeableSessionTypes ?? SessionType.defaultChargeableRawValues
    }

    private var effectiveCost: Decimal {
        let base = piece.totalCost
        if showDiscount, let pct = selectedDiscount?.percentage {
            return base * (1 - pct / 100)
        }
        return base
    }

    private var adjustedOutstanding: Decimal {
        effectiveCost - piece.totalPaymentsReceived
    }

    private var clientID: String {
        piece.client?.persistentModelID.hashValue.description ?? "unknown"
    }
    private var pieceID: String {
        piece.persistentModelID.hashValue.description
    }

    /// Returns a display string for the piece's size, or nil if not set.
    private var pieceSizeLabel: String? {
        switch sizeMode {
        case .categorical:
            return piece.size?.rawValue
        case .dimensional:
            return piece.sizeDimensions?.displayString(unit: dimensionUnit)
        }
    }

    var body: some View {
        List {
            // MARK: - Header
            Section {
                VStack(spacing: 12) {
                    // Type icon
                    ZStack {
                        Circle()
                            .fill(.primary.opacity(0.08))
                            .frame(width: 72, height: 72)
                        Image(systemName: piece.pieceType.systemImage)
                            .font(.system(size: 28))
                            .foregroundStyle(.primary)
                    }

                    Text(piece.title)
                        .font(.title2.weight(.bold))

                    // Status + Type badges
                    HStack(spacing: 8) {
                        let statusClr = piece.status.color(from: profiles.first)
                        Label(piece.status.rawValue, systemImage: piece.status.systemImage)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(statusClr.opacity(0.12), in: Capsule())
                            .foregroundStyle(statusClr)

                        Label(piece.pieceType.rawValue, systemImage: piece.pieceType.systemImage)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }

                    // Rating
                    ratingView

                    if !piece.bodyPlacement.isEmpty {
                        Label(piece.bodyPlacement, systemImage: "figure.arms.open")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let sizeLabel = pieceSizeLabel {
                        Label(sizeLabel, systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !piece.descriptionText.isEmpty {
                        Text(piece.descriptionText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // MARK: Client Button
                    if let client = piece.client {
                        Button {
                            coordinator.navigateToClient(client)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.12))
                                        .frame(width: 35, height: 35)
                                    Text(client.initialsDisplay)
                                        .font(.system(.caption, design: .monospaced, weight: .bold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                Text(client.fullName)
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
                        .buttonStyle(.plain)
                        .containerRelativeFrame(.horizontal) { width, _ in width / 3 }
                    }

                    // MARK: Quick Actions
                    HStack(spacing: 20) {
                        actionButton(icon: "envelope.fill", label: "Email",
                                     disabled: piece.client?.email.isEmpty ?? true) {
                            showingEmailPicker = true
                        }
                        actionButton(icon: "message.fill", label: "Message",
                                     disabled: piece.client?.phone.isEmpty ?? true) {
                            openSMS()
                        }
                        actionButton(icon: "clock.badge", label: "Session",
                                     disabled: false) {
                            showingAddSession = true
                        }
                        actionButton(icon: "photo.badge.plus", label: "Photo",
                                     disabled: false) {
                            showingEditPiece = true
                        }
                        actionButton(icon: "banknote", label: "Payment",
                                     disabled: false) {
                            showingLogPayment = true
                        }
                        actionButton(icon: "photo.on.rectangle.angled", label: "Gallery",
                                     disabled: piece.allImages.isEmpty) {
                            openGallery(piece.allImages)
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            // MARK: - Quick Stats
            Section {
                HStack {
                    StatBlock(label: "Sessions", value: "\(piece.sessions.count)")
                    Divider()
                    StatBlock(label: "Hours", value: String(format: "%.1f", piece.chargeableHours(using: chargeableTypes)))
                    Divider()
                    StatBlock(label: "Cost", value: piece.chargeableCost(using: chargeableTypes).currencyFormatted)
                }
                .padding(.vertical, 2)
            }

            // MARK: - Photos
            Section {
                if piece.directImages.isEmpty {
                    Button {
                        showingEditPiece = true
                    } label: {
                        Label("Add Photos", systemImage: "photo.badge.plus")
                    }
                } else {
                    if !piece.inspirationImages.isEmpty {
                        directImageRow(label: "Inspiration", icon: "sparkles", images: piece.inspirationImages)
                            .onTapGesture { openGallery(piece.inspirationImages) }
                    }
                    if !piece.referenceImages.isEmpty {
                        directImageRow(label: "Reference", icon: "photo.on.rectangle", images: piece.referenceImages)
                            .onTapGesture { openGallery(piece.referenceImages) }
                    }
                }
            } header: {
                HStack {
                    Text("Photos")
                    Spacer()
                    Button { showingEditPiece = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                    }
                }
            }

            // MARK: - Sessions
            Section {
                if piece.sessions.isEmpty {
                    ContentUnavailableView {
                        Label("No Sessions", systemImage: "clock")
                    } description: {
                        Text("Log sessions to track time and costs.")
                    }
                } else {
                    ForEach(piece.sessions.sorted(by: { $0.date > $1.date })) { session in
                        Button {
                            coordinator.navigateToSession(session)
                        } label: {
                            HStack {
                                sessionRow(session)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                editingSession = session
                            } label: {
                                Label("Edit Session", systemImage: "pencil")
                            }
                            Button {
                                coordinator.navigateToSession(session)
                            } label: {
                                Label("View in Bookings", systemImage: "book")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Sessions")
                    Spacer()
                    Button {
                        showingAddSession = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                    }
                }
            }

            // MARK: - Details
            Section("Details") {
                if !piece.bodyPlacement.isEmpty {
                    LabeledContent("Body Location", value: piece.bodyPlacement)
                }
                LabeledContent("Type", value: piece.pieceType.rawValue)
                if !piece.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tags")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        FlowLayout(spacing: 6) {
                            ForEach(piece.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.primary.opacity(0.06), in: Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - Discount
            if !discounts.isEmpty {
                Section {
                    Toggle(isOn: $showDiscount.animation()) {
                        Text("Apply Discount")
                    }
                    .onChange(of: showDiscount) { _, on in
                        if on && selectedDiscount == nil { selectedDiscount = discounts.first }
                        if !on { selectedDiscount = nil }
                    }
                    if showDiscount {
                        Picker("Discount", selection: $selectedDiscount) {
                            ForEach(discounts) { discount in
                                Text("\(discount.name) (\(discount.percentage.formatted())%)")
                                    .tag(Optional(discount))
                            }
                        }
                    }
                } header: {
                    Text("Discount")
                }
            }

            // MARK: - Summary
            Section {
                LabeledContent("Session Hours") {
                    Text(String(format: "%.1f hrs", piece.totalHours))
                }
                LabeledContent("Total Charge") {
                    Text(effectiveCost.currencyFormatted)
                        .foregroundStyle(showDiscount ? Color.orange : Color.primary)
                }
                HStack {
                    Text("Outstanding")
                        .fontWeight(.medium)
                    Spacer()
                    Text(adjustedOutstanding.currencyFormatted)
                        .fontWeight(.bold)
                        .foregroundStyle(adjustedOutstanding <= 0 ? Color.green : Color.orange)
                }
                NavigationLink {
                    PieceFinancialDetailView(piece: piece)
                } label: {
                    Text("Full Breakdown").font(.subheadline)
                }
            } header: {
                Text("Summary")
            }

            // MARK: - Payments
            Section {
                if piece.payments.isEmpty {
                    ContentUnavailableView {
                        Label("No Payments", systemImage: "banknote")
                    } description: {
                        Text("Log a payment to track income.")
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(piece.payments.sorted(by: { $0.paymentDate > $1.paymentDate })) { payment in
                        HStack(spacing: 12) {
                            Image(systemName: payment.paymentMethod.systemImage)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(payment.paymentType.rawValue)
                                    .font(.subheadline.weight(.medium))
                                Text(payment.paymentDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(payment.amount.currencyFormatted)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Payments")
                    Spacer()
                    Button { showingLogPayment = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                    }
                }
            }

           
            // MARK: - Meta
            Section {
                LabeledContent("Created", value: piece.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Updated", value: piece.updatedAt.formatted(date: .abbreviated, time: .shortened))
                if let completed = piece.completedAt {
                    LabeledContent("Completed", value: completed.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditPiece = true
                } label: {
                    Image(systemName: "pencil.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditPiece) {
            PieceEditView(mode: .edit(piece))
        }
        .sheet(isPresented: $showingAddSession) {
            SessionEditView(piece: piece)
        }
        .sheet(isPresented: $showingStageManager) {
            StageManagerView(piece: piece)
        }
        .sheet(item: $showingTimeLog) { group in
            TimeLogView(imageGroup: group)
        }
        .sheet(isPresented: $showingLogPayment) {
            PaymentLogView(prefillPiece: piece, prefillClient: piece.client)
        }
        .sheet(item: $editingSession) { session in
            SessionEditView(piece: piece, mode: .edit(session))
        }
        .sheet(isPresented: $showingImageGallery) {
            if let initial = galleryInitialImage, !galleryImages.isEmpty {
                FullScreenImageViewer(images: galleryImages, initialImage: initial)
                    .environment(lockManager)
            }
        }
        .sheet(isPresented: $showingEmailPicker) {
            if let client = piece.client {
                EmailTemplatePickerView(client: client, piece: piece)
            }
        }
    }

    // MARK: - Quick Action Helpers

    private func actionButton(icon: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(disabled ? Color.primary.opacity(0.04) : Color.accentColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(disabled ? Color.gray.opacity(0.3) : Color.accentColor)
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(disabled ? Color.gray.opacity(0.3) : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func openSMS() {
        guard let phone = piece.client?.phone, !phone.isEmpty else { return }
        let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        guard let url = URL(string: "sms:\(cleaned)") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Gallery helper

    private func openGallery(_ images: [PieceImage]) {
        guard !images.isEmpty else { return }
        galleryImages = images
        galleryInitialImage = images[0]
        showingImageGallery = true
    }

    // MARK: - Rating View

    private var ratingView: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= (piece.rating ?? 0) ? "star.fill" : "star")
                    .font(.system(size: 16))
                    .foregroundStyle(star <= (piece.rating ?? 0) ? .yellow : Color.gray.opacity(0.3))
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            piece.rating = (piece.rating == star) ? nil : star
                        }
                    }
            }
        }
    }

    // MARK: - Session Row

    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: session.sessionType.systemImage)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 16)
                Text(session.sessionType.rawValue)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if session.isNoShow {
                    Image(systemName: "person.slash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text(session.durationFormatted)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            HStack {
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(session.cost.currencyFormatted)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Show image groups attached to this session
            if !session.sessionProgress.isEmpty {
                HStack(spacing: 6) {
                    ForEach(session.sortedSessionProgress) { group in
                        Label("\(group.images.count)", systemImage: group.stage.systemImage)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            if !session.notes.isEmpty {
                Text(session.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Direct Image Row

    private func directImageRow(label: String, icon: String, images: [PieceImage]) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text("\(images.count)")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.primary.opacity(0.08), in: Capsule())
        }
    }
}

// MARK: - Flow Layout (for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], sizes: [CGSize], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, sizes, CGSize(width: maxX, height: y + rowHeight))
    }
}

#Preview {
    NavigationStack {
        PieceDetailView(piece: {
            let p = Piece(
                title: "Botanical Sleeve",
                bodyPlacement: "Left forearm",
                descriptionText: "Mixed floral with fern and peony motifs",
                status: .inProgress,
                pieceType: .custom,
                tags: ["Floral", "Botanical", "Color"],
                hourlyRate: 175,
                depositAmount: 200
            )
            p.rating = 4
            return p
        }())
    }
    .modelContainer(PreviewContainer.shared.container)
}
