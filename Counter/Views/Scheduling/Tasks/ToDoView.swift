import SwiftUI
import SwiftData

// MARK: - Category

enum ToDoCategory: String, CaseIterable {
    case drafts        = "Drafts"
    case forms         = "Form Requirements"
    case healedPhotos  = "Healed Photos"
    case touchUps      = "Touch-Ups"
    case payments      = "Outstanding Payments"
    case processPhotos = "Process Photos"

    var systemImage: String {
        switch self {
        case .drafts:        "pencil.tip"
        case .forms:         "doc.text.fill"
        case .healedPhotos:  "camera.fill"
        case .touchUps:      "bandage.fill"
        case .payments:      "dollarsign.circle.fill"
        case .processPhotos: "camera.aperture"
        }
    }

    var color: Color {
        switch self {
        case .drafts:        .orange
        case .forms:         .purple
        case .healedPhotos:  .teal
        case .touchUps:      .yellow
        case .payments:      .red
        case .processPhotos: .blue
        }
    }
}

// MARK: - Task Model

struct ToDoTask: Identifiable {
    let id: String
    let category: ToDoCategory
    let title: String
    let subtitle: String
    let piece: Piece?
    let booking: Booking?
    let client: Client?
}

// MARK: - To Do View

struct ToDoView: View {
    var embedded: Bool = false

    @Query private var pieces: [Piece]
    @Query private var bookings: [Booking]

    @State private var selectedFilter: ToDoCategory? = nil
    @State private var navigateToPiece: Piece?

    @AppStorage("todo.dismissedIDs") private var dismissedRaw: String = ""

    private var dismissedIDs: Set<String> {
        Set(dismissedRaw.split(separator: ",").map(String.init))
    }

    // MARK: Derived

    private var activePieces: [Piece] {
        pieces.filter { $0.client?.isFlashPortfolioClient != true }
    }

    private var allTasks: [ToDoTask] {
        var result: [ToDoTask] = []
        let now = Date()

        // ── Drafts ───────────────────────────────────────────────────────────
        for piece in activePieces where [PieceStatus.concept, .designInProgress].contains(piece.status) {
            let label = piece.status == .designInProgress ? "Draft in progress" : "Design not started"
            result.append(ToDoTask(
                id: "draft_\(stableID(piece))",
                category: .drafts,
                title: label,
                subtitle: pieceSubtitle(piece),
                piece: piece, booking: nil, client: piece.client
            ))
        }

        // ── Form Requirements ────────────────────────────────────────────────
        let thirtyDays = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        let upcomingBookings = bookings.filter {
            $0.date >= now && $0.date <= thirtyDays && $0.status != .cancelled
        }
        let requiredForms: [(AgreementType, String)] = [
            (.consent,     "Tattoo Consent"),
            (.photoRelease,"Photo Release"),
            (.liability,   "Liability Waiver"),
        ]
        for booking in upcomingBookings {
            guard let client = booking.client else { continue }
            let signedTypes = Set(client.agreements.filter(\.isSigned).map(\.agreementType))
            let dateStr = booking.date.formatted(date: .abbreviated, time: .omitted)
            for (type, label) in requiredForms where !signedTypes.contains(type) {
                result.append(ToDoTask(
                    id: "form_\(type.rawValue)_\(client.fullName.hashValue)_\(Int(booking.date.timeIntervalSince1970))",
                    category: .forms,
                    title: "\(label) missing",
                    subtitle: "\(client.fullName) · \(dateStr)",
                    piece: booking.piece, booking: booking, client: client
                ))
            }
        }

        // ── Healed Photos ────────────────────────────────────────────────────
        let healCandidates = activePieces.filter {
            [PieceStatus.completed, .healed, .touchUp].contains($0.status)
        }
        for piece in healCandidates {
            let hasHealedPhotos = piece.sessions.flatMap { $0.sessionProgress }.contains {
                ($0.stage == .healed || $0.stage == .finalResult) && !$0.images.isEmpty
            }
            if !hasHealedPhotos {
                result.append(ToDoTask(
                    id: "healedphoto_\(stableID(piece))",
                    category: .healedPhotos,
                    title: "Healed photos needed",
                    subtitle: pieceSubtitle(piece),
                    piece: piece, booking: nil, client: piece.client
                ))
            }
        }

        // ── Touch-Ups ────────────────────────────────────────────────────────
        for piece in activePieces where piece.status == .touchUp {
            result.append(ToDoTask(
                id: "touchup_\(stableID(piece))",
                category: .touchUps,
                title: "Touch-up required",
                subtitle: pieceSubtitle(piece),
                piece: piece, booking: nil, client: piece.client
            ))
        }

        // ── Outstanding Payments ─────────────────────────────────────────────
        let unpaidPieces = activePieces.filter {
            $0.outstandingBalance > 0 &&
            $0.status != .archived &&
            $0.status != .concept
        }
        for piece in unpaidPieces {
            let amount = piece.outstandingBalance
            let formatted = NumberFormatter.localizedString(
                from: NSDecimalNumber(decimal: amount), number: .currency
            )
            result.append(ToDoTask(
                id: "payment_\(stableID(piece))",
                category: .payments,
                title: "\(formatted) outstanding",
                subtitle: pieceSubtitle(piece),
                piece: piece, booking: nil, client: piece.client
            ))
        }

        // ── Process Photos ───────────────────────────────────────────────────
        let inProgressPieces = activePieces.filter {
            [PieceStatus.inProgress, .completed, .touchUp].contains($0.status)
        }
        for piece in inProgressPieces {
            let hasFreshPhotos = piece.sessions.flatMap { $0.sessionProgress }.contains {
                $0.stage == .freshlyTattooed && !$0.images.isEmpty
            }
            let hasPastSessions = piece.sessions.contains { $0.date < now }
            if !hasFreshPhotos && hasPastSessions {
                result.append(ToDoTask(
                    id: "freshphoto_\(stableID(piece))",
                    category: .processPhotos,
                    title: "Process photos needed",
                    subtitle: pieceSubtitle(piece),
                    piece: piece, booking: nil, client: piece.client
                ))
            }
        }

        // ── Filter + dismiss ─────────────────────────────────────────────────
        let dismissed = dismissedIDs
        let undismissed = result.filter { !dismissed.contains($0.id) }
        if let filter = selectedFilter {
            return undismissed.filter { $0.category == filter }
        }
        return undismissed
    }

    private var groupedTasks: [(category: ToDoCategory, tasks: [ToDoTask])] {
        ToDoCategory.allCases.compactMap { cat in
            let catTasks = allTasks.filter { $0.category == cat }
            return catTasks.isEmpty ? nil : (cat, catTasks)
        }
    }

    // MARK: Body

    var body: some View {
        if embedded {
            toDoContent
        } else {
            NavigationStack { toDoContent }
        }
    }

    @ViewBuilder
    private var toDoContent: some View {
        Group {
            if allTasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .navigationTitle("To Do")
        .navigationDestination(item: $navigateToPiece) { piece in
            PieceDetailView(piece: piece)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { selectedFilter = nil } label: {
                        Label("All", systemImage: "tray.2")
                    }
                    Divider()
                    ForEach(ToDoCategory.allCases, id: \.self) { cat in
                        Button { selectedFilter = cat } label: {
                            Label(cat.rawValue, systemImage: cat.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: selectedFilter == nil
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
    }

    // MARK: Task List

    @ViewBuilder
    private var taskList: some View {
        List {
            ForEach(groupedTasks, id: \.category) { group in
                Section {
                    ForEach(group.tasks) { task in
                        ToDoRow(
                            task: task,
                            onNavigate: { piece in navigateToPiece = piece },
                            onDismiss: { dismiss(task) }
                        )
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: group.category.systemImage)
                        Text(group.category.rawValue)
                        Spacer()
                        Text("\(group.tasks.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(group.category.color)
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: Empty State

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("All Caught Up", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } description: {
            Text(selectedFilter == nil
                 ? "No pending tasks. Everything is up to date."
                 : "No \(selectedFilter!.rawValue.lowercased()) tasks pending.")
        } actions: {
            if selectedFilter != nil {
                Button("Clear Filter") { selectedFilter = nil }
                    .buttonStyle(.bordered)
            }
        }
    }

    // MARK: Helpers

    private func pieceSubtitle(_ piece: Piece) -> String {
        let client = piece.client.map { $0.fullName } ?? ""
        return client.isEmpty ? piece.title : "\(piece.title) · \(client)"
    }

    private func stableID(_ piece: Piece) -> String {
        "\(piece.title.hashValue)_\(piece.createdAt.timeIntervalSince1970)"
    }

    private func dismiss(_ task: ToDoTask) {
        var ids = dismissedIDs
        ids.insert(task.id)
        dismissedRaw = ids.joined(separator: ",")
    }
}

// MARK: - To Do Row

private struct ToDoRow: View {
    let task: ToDoTask
    let onNavigate: (Piece) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(task.category.color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: task.category.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(task.category.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                Text(task.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if task.piece != nil || task.booking != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let piece = task.piece { onNavigate(piece) }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { onDismiss() }
            } label: {
                Label("Dismiss", systemImage: "xmark.circle")
            }
            .tint(.gray)
        }
    }
}

#Preview {
    ToDoView()
        .modelContainer(PreviewContainer.shared.container)
}
