import SwiftUI
import SwiftData

struct BookingDetailView: View {
    @Bindable var booking: Booking
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditBooking = false
    @State private var showingCancelConfirm = false
    @State private var pieceThumbnail: UIImage?

    var body: some View {
        List {
            // Header — Client + Piece thumbnail
            Section {
                VStack(spacing: 12) {
                    // Session type
                    HStack(spacing: 6) {
                        Image(systemName: booking.bookingType.systemImage)
                            .font(.subheadline)
                        Text(booking.bookingType.rawValue)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(booking.bookingType.color)

                    // Client name
                    if let client = booking.client {
                        NavigationLink {
                            ClientDetailView(client: client)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(.primary.opacity(0.08))
                                        .frame(width: 48, height: 48)
                                    Text(client.initialsDisplay)
                                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(client.fullName)
                                        .font(.title3.weight(.semibold))
                                    if !client.phone.isEmpty {
                                        Text(client.phone)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(.primary.opacity(0.08))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "person.badge.plus")
                                    .font(.subheadline)
                            }
                            Text("Walk-in")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Piece thumbnail (if available)
                    if let piece = booking.piece {
                        NavigationLink {
                            PieceDetailView(piece: piece)
                        } label: {
                            HStack(spacing: 12) {
                                if let thumbnail = pieceThumbnail {
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.primary.opacity(0.06))
                                        .frame(width: 56, height: 56)
                                        .overlay {
                                            Image(systemName: piece.status.systemImage)
                                                .foregroundStyle(.secondary)
                                        }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(piece.title)
                                        .font(.subheadline.weight(.medium))
                                    Text(piece.bodyPlacement)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                StatusBadge(status: booking.status)
                            }
                        }
                    } else {
                        HStack {
                            Spacer()
                            StatusBadge(status: booking.status)
                            Spacer()
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            // Date & Time
            Section("Details") {
                LabeledContent {
                    Text(booking.date.formatted(date: .long, time: .omitted))
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Date", systemImage: "calendar")
                }

                LabeledContent {
                    Text("\(booking.startTime.formatted(date: .omitted, time: .shortened)) – \(booking.endTime.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Time", systemImage: "clock")
                }

                LabeledContent {
                    Text(booking.durationFormatted)
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Duration", systemImage: "hourglass")
                }

                HStack {
                    Label("Deposit Paid", systemImage: "dollarsign.circle")
                    Spacer()
                    Image(systemName: booking.depositPaid ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(booking.depositPaid ? .green : .red)
                }
            }

            // Notes
            if !booking.notes.isEmpty {
                Section("Notes") {
                    Text(booking.notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            // Status Actions
            Section("Actions") {
                ForEach(availableActions, id: \.self) { action in
                    Button {
                        applyAction(action)
                    } label: {
                        Label(action.label, systemImage: action.systemImage)
                    }
                    .tint(action.tint)
                }

                if booking.status != .cancelled && booking.status != .completed {
                    Button(role: .destructive) {
                        showingCancelConfirm = true
                    } label: {
                        Label("Cancel Booking", systemImage: "xmark.circle")
                    }
                }
            }

            // Meta
            Section {
                LabeledContent("Created", value: booking.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Updated", value: booking.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .listStyle(.insetGrouped)
        .task { await loadThumbnail() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditBooking = true
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditBooking) {
            BookingEditView(mode: .edit(booking))
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

    private var availableActions: [BookingAction] {
        switch booking.status {
        case .requested:
            return [.confirm]
        case .confirmed:
            return [.start]
        case .inProgress:
            return [.complete]
        case .completed, .cancelled, .noShow:
            return []
        }
    }

    private func loadThumbnail() async {
        guard let path = booking.piece?.primaryImagePath else { return }
        guard let image = await ImageStorageService.shared.loadImage(relativePath: path) else { return }
        let size = CGSize(width: 120, height: 120)
        let thumb = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        pieceThumbnail = thumb
    }

    private func applyAction(_ action: BookingAction) {
        switch action {
        case .confirm:
            booking.status = .confirmed
        case .start:
            booking.status = .inProgress
        case .complete:
            booking.status = .completed
        }
        booking.updatedAt = Date()
    }
}

enum BookingAction: String, CaseIterable {
    case confirm, start, complete

    var label: String {
        switch self {
        case .confirm: "Confirm Booking"
        case .start: "Start Session"
        case .complete: "Mark Complete"
        }
    }

    var systemImage: String {
        switch self {
        case .confirm: "checkmark.circle"
        case .start: "flame"
        case .complete: "checkmark.seal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .confirm: .blue
        case .start: .purple
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
        case .requested: .orange
        case .confirmed: .blue
        case .inProgress: .purple
        case .completed: .green
        case .cancelled: .red
        case .noShow: .gray
        }
    }
}

#Preview {
    NavigationStack {
        BookingDetailView(booking: {
            let b = Booking(
                bookingType: .session,
                notes: "Full sleeve continuation, left arm"
            )
            return b
        }())
    }
    .modelContainer(PreviewContainer.shared.container)
}
