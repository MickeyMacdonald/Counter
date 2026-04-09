import SwiftUI
import SwiftData

struct BookingDetailView: View {
    @Bindable var booking: Booking
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationCoordinator.self) private var coordinator

    @Query(sort: \Payment.paymentDate, order: .reverse) private var allPayments: [Payment]

    @State private var showingEditBooking    = false
    @State private var showingCancelConfirm = false
    @State private var showingLogPayment    = false
    @State private var pieceThumbnail: UIImage?
    @State private var newTaskText           = ""

    // MARK: - Derived

    /// Deposit-type payments linked to this booking's piece or client.
    private var depositPayments: [Payment] {
        allPayments.filter { payment in
            guard payment.paymentType == .deposit else { return false }
            if let piece = booking.piece {
                return payment.piece?.persistentModelID == piece.persistentModelID
            }
            if let client = booking.client {
                return payment.client?.persistentModelID == client.persistentModelID
            }
            return false
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            headerSection
            detailsSection
            depositSection
            prepSection
            notesSection
            metaSection
        }
        .listStyle(.insetGrouped)
        .task { await loadThumbnail() }
        .toolbar { editButton }
        .sheet(isPresented: $showingEditBooking) {
            BookingEditView(mode: .edit(booking))
        }
        .sheet(isPresented: $showingLogPayment) {
            PaymentLogView(
                prefillPiece: booking.piece,
                prefillClient: booking.client
            )
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var editButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingEditBooking = true } label: {
                Image(systemName: "pencil.circle")
            }
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        Section {
            VStack(spacing: 14) {
                // Booking type icon
                ZStack {
                    Circle()
                        .fill(booking.bookingType.color.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: booking.bookingType.systemImage)
                        .font(.system(size: 28))
                        .foregroundStyle(booking.bookingType.color)
                }

                // Title + date
                VStack(spacing: 4) {
                    Text(booking.bookingType.rawValue)
                        .font(.title2.weight(.bold))
                    Text(booking.date.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Status badge
                StatusBadge(status: booking.status)

                Divider()

                // Action buttons
                actionButtonRow
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Action Buttons

    private var actionButtonRow: some View {
        HStack(spacing: 20) {
            let client = booking.client

            actionButton(icon: "envelope.fill",   label: "Email",
                         disabled: client?.email.isEmpty ?? true) {
                if let email = client?.email,
                   let url = URL(string: "mailto:\(email)") {
                    UIApplication.shared.open(url)
                }
            }

            actionButton(icon: "message.fill",    label: "Text",
                         disabled: client?.phone.isEmpty ?? true) {
                if let phone = client?.phone {
                    let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
                    if let url = URL(string: "sms:\(cleaned)") {
                        UIApplication.shared.open(url)
                    }
                }
            }

            actionButton(icon: "phone.fill",      label: "Call",
                         disabled: client?.phone.isEmpty ?? true) {
                if let phone = client?.phone {
                    let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
                    if let url = URL(string: "tel://\(cleaned)") {
                        UIApplication.shared.open(url)
                    }
                }
            }

            if booking.status != .cancelled && booking.status != .completed {
                actionButton(icon: statusAction.systemImage,
                             label: statusAction.label,
                             disabled: false,
                             tint: statusAction.tint) {
                    applyStatusAction()
                }
            }

            if booking.status != .cancelled {
                actionButton(icon: "xmark.circle.fill", label: "Cancel",
                             disabled: false, tint: .red) {
                    showingCancelConfirm = true
                }
            }
        }
        .padding(.bottom, 4)
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

    // MARK: - Details Section

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            // Client
            if let client = booking.client {
                Button { coordinator.navigateToClient(client) } label: {
                    clientRow(client)
                }
                .buttonStyle(.plain)
            }

            // Piece
            if let piece = booking.piece {
                Button { coordinator.navigateToPiece(piece) } label: {
                    pieceRow(piece)
                }
                .buttonStyle(.plain)
            }

            // Time
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
        }
    }

    private func clientRow(_ client: Client) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.primary.opacity(0.07))
                    .frame(width: 40, height: 40)
                Text(client.initialsDisplay)
                    .font(.system(.caption, design: .monospaced, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(client.fullName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                if !client.phone.isEmpty {
                    Text(client.phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func pieceRow(_ piece: Piece) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 40, height: 40)
                if let thumbnail = pieceThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: piece.pieceType.systemImage)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.accentColor)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(piece.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(piece.bodyPlacement)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Deposit Section

    @ViewBuilder
    private var depositSection: some View {
        Section("Deposit") {
            Toggle(isOn: $booking.depositPaid) {
                Label("Deposit Paid", systemImage: "dollarsign.circle")
            }
            .onChange(of: booking.depositPaid) { _, _ in
                booking.updatedAt = Date()
            }

            if booking.depositPaid {
                if depositPayments.isEmpty {
                    Button {
                        showingLogPayment = true
                    } label: {
                        Label("Log Deposit Payment", systemImage: "plus.circle")
                    }
                    .foregroundStyle(Color.accentColor)
                } else {
                    ForEach(depositPayments) { payment in
                        depositPaymentRow(payment)
                    }
                    Button {
                        showingLogPayment = true
                    } label: {
                        Label("Log Another Payment", systemImage: "plus.circle")
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private func depositPaymentRow(_ payment: Payment) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: payment.paymentMethod.systemImage)
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.amount.currencyFormatted)
                    .font(.subheadline.weight(.semibold))
                Text(payment.paymentDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(payment.paymentMethod.rawValue)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.10), in: Capsule())
                .foregroundStyle(.green)
        }
    }

    // MARK: - Prep / Checklist Section

    @ViewBuilder
    private var prepSection: some View {
        Section("Checklist") {
            // Auto-generated tasks (derived from piece state, manually overrideable)
            ForEach(booking.prepTasks) { task in
                let done = effectiveCompletion(for: task)
                Button { togglePrepTask(task) } label: {
                    checklistRow(
                        icon: task.icon,
                        label: task.label,
                        isComplete: done
                    )
                }
                .buttonStyle(.plain)
            }

            // User-defined tasks
            ForEach(booking.customChecklistItems) { task in
                Button {
                    toggleCustomTask(task)
                } label: {
                    checklistRow(
                        icon: task.isComplete ? "checkmark.circle.fill" : "circle",
                        label: task.label,
                        isComplete: task.isComplete,
                        isCustom: true
                    )
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteCustomTask(task)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            // Add-task row
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

    // MARK: - Notes Section

    @ViewBuilder
    private var notesSection: some View {
        if !booking.notes.isEmpty {
            Section("Notes") {
                Text(booking.notes)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Meta Section

    private var metaSection: some View {
        Section {
            LabeledContent("Created", value: booking.createdAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent("Updated", value: booking.updatedAt.formatted(date: .abbreviated, time: .shortened))
        }
    }

    // MARK: - Status Action

    private var statusAction: BookingAction {
        switch booking.status {
        case .requested:  return .confirm
        case .confirmed:  return .start
        default:          return .complete
        }
    }

    private func applyStatusAction() {
        switch booking.status {
        case .requested:  booking.status = .confirmed
        case .confirmed:  booking.status = .inProgress
        default:          booking.status = .completed
        }
        booking.updatedAt = Date()
    }

    // MARK: - Thumbnail

    private func loadThumbnail() async {
        guard let path = booking.piece?.primaryImagePath else { return }
        guard let image = await ImageStorageService.shared.loadImage(relativePath: path) else { return }
        let size = CGSize(width: 80, height: 80)
        pieceThumbnail = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Booking Action

enum BookingAction: String, CaseIterable {
    case confirm, start, complete

    var label: String {
        switch self {
        case .confirm: "Confirm"
        case .start:   "Start"
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
            let b = Booking(
                bookingType: .session,
                notes: "Full sleeve continuation, left arm"
            )
            return b
        }())
    }
    .modelContainer(PreviewContainer.shared.container)
    .environment(AppNavigationCoordinator())
}
