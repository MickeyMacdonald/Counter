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
    @State private var showingTimeLog: ImageGroup?
    @State private var showingLogPayment = false
    @State private var showingFinancialDetail = false
    @State private var editingSession: TattooSession?
    @State private var galleryImages: [PieceImage] = []
    @State private var galleryInitialImage: PieceImage?
    @State private var showingImageGallery = false

    private var chargeableTypes: [String] {
        profiles.first?.effectiveChargeableSessionTypes ?? SessionType.defaultChargeableRawValues
    }

    private var clientID: String {
        piece.client?.persistentModelID.hashValue.description ?? "unknown"
    }
    private var pieceID: String {
        piece.persistentModelID.hashValue.description
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

                    if !piece.descriptionText.isEmpty {
                        Text(piece.descriptionText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            // MARK: - Client Link
            if let client = piece.client {
                Section {
                    NavigationLink {
                        ClientDetailView(client: client)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(.primary.opacity(0.08))
                                    .frame(width: 40, height: 40)
                                Text(client.initialsDisplay)
                                    .font(.system(.caption, design: .monospaced, weight: .bold))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.fullName)
                                    .font(.subheadline.weight(.medium))
                                if !client.pronouns.isEmpty {
                                    Text(client.pronouns)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Client")
                }
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
                .padding(.vertical, 4)
            }

            // MARK: - Inspiration & Reference
            if !piece.directImages.isEmpty {
                Section {
                    if !piece.inspirationImages.isEmpty {
                        directImageRow(
                            label: "Inspiration",
                            icon: "sparkles",
                            images: piece.inspirationImages
                        )
                        .onTapGesture { openGallery(piece.inspirationImages) }
                    }

                    if !piece.referenceImages.isEmpty {
                        directImageRow(
                            label: "Reference",
                            icon: "photo.on.rectangle",
                            images: piece.referenceImages
                        )
                        .onTapGesture { openGallery(piece.referenceImages) }
                    }
                } header: {
                    Text("Inspiration & Reference")
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
                        sessionRow(session)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                coordinator.navigateToSession(session)
                            }
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

            // MARK: - Tags
            if !piece.tags.isEmpty {
                Section("Tags") {
                    FlowLayout(spacing: 6) {
                        ForEach(piece.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.primary.opacity(0.06), in: Capsule())
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            // MARK: - Financials
            Section {
                if let flat = piece.flatRate {
                    LabeledContent("Flat Rate", value: flat.currencyFormatted)
                } else {
                    LabeledContent("Hourly Rate", value: piece.hourlyRate.currencyFormatted)
                }

                if piece.depositAmount > 0 {
                    LabeledContent("Deposit Required", value: piece.depositAmount.currencyFormatted)
                    LabeledContent("Deposit Received") {
                        Text(piece.depositReceived.currencyFormatted)
                            .foregroundStyle(piece.depositReceived >= piece.depositAmount ? .green : .orange)
                    }
                }

                HStack {
                    Text("Outstanding")
                        .fontWeight(.medium)
                    Spacer()
                    Text(piece.outstandingBalance.currencyFormatted)
                        .fontWeight(.bold)
                        .foregroundStyle(piece.isFullyPaid ? .green : .orange)
                }

                HStack(spacing: 12) {
                    Button {
                        showingLogPayment = true
                    } label: {
                        Label("Log Payment", systemImage: "plus.circle.fill")
                    }

                    Spacer()

                    NavigationLink {
                        PieceFinancialDetailView(piece: piece)
                    } label: {
                        Text("Full Breakdown")
                            .font(.subheadline)
                    }
                }
            } header: {
                Text("Financials")
            }

            // MARK: - Payments
            if !piece.payments.isEmpty {
                Section("Payment History") {
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
        .navigationTitle(piece.title)
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

    private func sessionRow(_ session: TattooSession) -> some View {
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
            if !session.imageGroups.isEmpty {
                HStack(spacing: 6) {
                    ForEach(session.sortedImageGroups) { group in
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
