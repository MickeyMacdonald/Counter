import SwiftUI
import SwiftData

// MARK: - Task Model (derived from SwiftData, not persisted separately)

enum ToDoCategory: String, CaseIterable {
    case design = "Design"
    case photos  = "Photos"
    case admin   = "Admin"

    var systemImage: String {
        switch self {
        case .design:  "pencil.tip"
        case .photos:  "camera.fill"
        case .admin:   "doc.text.fill"
        }
    }

    var color: Color {
        switch self {
        case .design:  .orange
        case .photos:  .blue
        case .admin:   .purple
        }
    }
}

struct ToDoTask: Identifiable {
    let id: String              // Stable identifier for persistence / comparison
    let category: ToDoCategory
    let title: String
    let subtitle: String
    let piece: Piece?
    let booking: Booking?
}

// MARK: - To Do View

struct ToDoView: View {
    /// When `true` the view is embedded inside `SessionsTabView` — no `NavigationStack` wrapper.
    var embedded: Bool = false

    @Query private var pieces: [Piece]
    @Query private var bookings: [Booking]

    @State private var selectedFilter: ToDoCategory? = nil
    @State private var navigateToPiece: Piece?

    // Dismissed task IDs stored in UserDefaults
    @AppStorage("todo.dismissedIDs") private var dismissedRaw: String = ""

    private var dismissedIDs: Set<String> {
        Set(dismissedRaw.split(separator: ",").map(String.init))
    }

    // MARK: - Task Derivation

    private var activePieces: [Piece] {
        pieces.filter { $0.client?.isFlashPortfolioClient != true }
    }

    private var allTasks: [ToDoTask] {
        var result: [ToDoTask] = []
        let now = Date()

        // ── Design tasks ──────────────────────────────────────────────────────
        for piece in activePieces where piece.status == .designInProgress {
            result.append(ToDoTask(
                id: "draft_\(stableID(piece))",
                category: .design,
                title: "Draft needed",
                subtitle: pieceSubtitle(piece),
                piece: piece, booking: nil
            ))
        }

        for piece in activePieces where piece.status == .concept && !piece.sessions.isEmpty {
            result.append(ToDoTask(
                id: "concept_\(stableID(piece))",
                category: .design,
                title: "Design not started",
                subtitle: pieceSubtitle(piece),
                piece: piece, booking: nil
            ))
        }

        // ── Photo tasks ───────────────────────────────────────────────────────
        // Process photos: sessions in the past but no freshly-tattooed images
        let inProgressPieces = activePieces.filter {
            [PieceStatus.inProgress, .completed, .touchUp].contains($0.status)
        }
        for piece in inProgressPieces {
            let hasFreshPhotos = piece.sessions.flatMap { $0.imageGroups }.contains {
                $0.stage == .freshlyTattooed && !$0.images.isEmpty
            }
            let hasPastSessions = piece.sessions.contains { $0.date < now }
            if !hasFreshPhotos && hasPastSessions {
                result.append(ToDoTask(
                    id: "freshphoto_\(stableID(piece))",
                    category: .photos,
                    title: "Process photos needed",
                    subtitle: pieceSubtitle(piece),
                    piece: piece, booking: nil
                ))
            }
        }

        // Healed photos: completed or healed pieces with no healed-stage images
        let healCandidates = activePieces.filter {
            [PieceStatus.completed, .healed, .touchUp].contains($0.status)
        }
        for piece in healCandidates {
            let hasHealedPhotos = piece.sessions.flatMap { $0.imageGroups }.contains {
                ($0.stage == .healed || $0.stage == .finalResult) && !$0.images.isEmpty
            }
            if !hasHealedPhotos {
                result.append(ToDoTask(
                    id: "healedphoto_\(stableID(piece))",
                    category: .photos,
                    title: "Healed photos needed",
                    subtitle: pieceSubtitle(piece),
                    piece: piece, booking: nil
                ))
            }
        }

        // ── Admin tasks ───────────────────────────────────────────────────────
        let thirtyDaysOut = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        let upcomingBookings = bookings.filter {
            $0.date >= now &&
            $0.date <= thirtyDaysOut &&
            $0.status != .cancelled
        }
        for booking in upcomingBookings {
            let clientAgreements = booking.client?.agreements ?? []
            if clientAgreements.isEmpty {
                let clientName = booking.client?.fullName ?? "Unknown Client"
                let dateStr = booking.date.formatted(date: .abbreviated, time: .omitted)
                result.append(ToDoTask(
                    id: "agreement_\(Int(booking.date.timeIntervalSince1970))_\(clientName.hashValue)",
                    category: .admin,
                    title: "Agreement needed",
                    subtitle: "\(clientName) · \(dateStr)",
                    piece: booking.piece, booking: booking
                ))
            }
        }

        // ── Apply filter + dismiss ─────────────────────────────────────────────
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

    // MARK: - Body

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
                        Button {
                            selectedFilter = nil
                        } label: {
                            Label("All Categories", systemImage: "tray.2")
                        }

                        Divider()

                        ForEach(ToDoCategory.allCases, id: \.self) { cat in
                            Button {
                                selectedFilter = cat
                            } label: {
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

    // MARK: - Task List

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
                    Label(group.category.rawValue, systemImage: group.category.systemImage)
                        .foregroundStyle(group.category.color)
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

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

    // MARK: - Helpers

    private func pieceSubtitle(_ piece: Piece) -> String {
        let clientPart = piece.client.map { $0.fullName } ?? ""
        return clientPart.isEmpty ? piece.title : "\(piece.title) · \(clientPart)"
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
            // Category icon badge
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

            if task.piece != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let piece = task.piece {
                onNavigate(piece)
            }
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
