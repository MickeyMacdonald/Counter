import SwiftUI
import SwiftData

struct PieceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BusinessLockManager.self) private var lockManager
    @Query(sort: \Piece.updatedAt, order: .reverse) private var allPieces: [Piece]
    @State private var searchText = ""
    @State private var sortOrder: PieceSortOrder = .recent
    @State private var filterType: PieceTypeFilter = .all
    @State private var filterStatus: PieceStatusFilter = .all
    @State private var selectedPiece: Piece?
    @State private var showAddPieceWizard = false

    private var filteredPieces: [Piece] {
        // Exclude flash portfolio pieces — those live in the Flash Portfolio tab
        var result = allPieces.filter { $0.client?.isFlashPortfolioClient != true }

        // Type filter
        switch filterType {
        case .all: break
        case .custom: result = result.filter { $0.pieceType == .custom }
        case .flash: result = result.filter { $0.pieceType == .flash }
        case .walkIn: result = result.filter { $0.pieceType == .walkIn }
        }

        // Status filter
        switch filterStatus {
        case .all: break
        case .active:
            result = result.filter {
                [.concept, .designInProgress, .approved, .scheduled, .inProgress].contains($0.status)
            }
        case .completed:
            result = result.filter {
                [.completed, .healed].contains($0.status)
            }
        case .archived:
            result = result.filter { $0.status == .archived }
        }

        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.bodyPlacement.lowercased().contains(query) ||
                $0.client?.fullName.lowercased().contains(query) == true ||
                $0.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }

        // Sort
        switch sortOrder {
        case .recent:
            result.sort { $0.updatedAt > $1.updatedAt }
        case .title:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .status:
            result.sort { $0.status.rawValue < $1.status.rawValue }
        case .client:
            result.sort { ($0.client?.fullName ?? "") < ($1.client?.fullName ?? "") }
        }

        return result
    }

    var body: some View {
        NavigationSplitView {
            Group {
                if allPieces.isEmpty {
                    emptyState
                } else {
                    pieceList
                }
            }
            .navigationTitle("Pieces")
            .searchable(text: $searchText, prompt: "Search pieces...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Button {
                            showAddPieceWizard = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        sortFilterMenu
                    }
                }
            }
            .sheet(isPresented: $showAddPieceWizard) {
                QuickAddPieceSheet()
            }
        } detail: {
            if let selectedPiece {
                NavigationStack {
                    PieceDetailView(piece: selectedPiece)
                }
                .id(selectedPiece.persistentModelID)
            } else {
                ContentUnavailableView(
                    "Select a Piece",
                    systemImage: "paintbrush.pointed",
                    description: Text("Choose a piece from the list to view its details.")
                )
            }
        }
    }

    // MARK: - Piece List

    private var pieceList: some View {
        List(filteredPieces, selection: $selectedPiece) { piece in
            NavigationLink(value: piece) {
                PieceListRowView(piece: piece)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Pieces Yet", systemImage: "paintbrush.pointed")
        } description: {
            Text("Pieces will appear here as you add them to clients.")
        }
    }

    // MARK: - Sort / Filter Menu

    private var sortFilterMenu: some View {
        Menu {
            // Sort
            Section("Sort By") {
                Picker("Sort", selection: $sortOrder) {
                    ForEach(PieceSortOrder.allCases, id: \.self) { order in
                        Label(order.label, systemImage: order.systemImage)
                            .tag(order)
                    }
                }
            }

            // Type filter
            Section("Type") {
                Picker("Type", selection: $filterType) {
                    ForEach(PieceTypeFilter.allCases, id: \.self) { type in
                        Label(type.label, systemImage: type.systemImage)
                            .tag(type)
                    }
                }
            }

            // Status filter
            Section("Status") {
                Picker("Status", selection: $filterStatus) {
                    ForEach(PieceStatusFilter.allCases, id: \.self) { status in
                        Label(status.label, systemImage: status.systemImage)
                            .tag(status)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
}

// MARK: - Piece List Row

struct PieceListRowView: View {
    let piece: Piece
    @Query private var profiles: [UserProfile]
    @State private var thumbnail: UIImage?

    private var chargeableTypes: [String] {
        profiles.first?.effectiveChargeableSessionTypes ?? SessionType.defaultChargeableRawValues
    }

    /// The primary image, or the first available image for this piece
    private var primaryImage: PieceImage? {
        let all = piece.allImages
        return all.first(where: { $0.isPrimary }) ?? all.first
    }

    var body: some View {
        HStack(spacing: 10) {
            // Left: primary image thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.primary.opacity(0.05))
                    .frame(width: 52, height: 52)

                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: piece.pieceType.systemImage)
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                }
            }

            // Right: piece info
            VStack(alignment: .leading, spacing: 4) {
                Text(piece.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                if let client = piece.client {
                    Text(client.fullName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(piece.status.rawValue)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(statusColor)

                    let hours = piece.chargeableHours(using: chargeableTypes)
                    if hours > 0 {
                        Label(String(format: "%.1fh", hours), systemImage: "clock")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .task { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        guard let path = primaryImage?.filePath,
              let img = await ImageStorageService.shared.loadImage(relativePath: path) else { return }
        let size = CGSize(width: 150, height: 150)
        let thumb = UIGraphicsImageRenderer(size: size).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
        await MainActor.run { self.thumbnail = thumb }
    }

    private var statusColor: Color {
        piece.status.color(from: profiles.first)
    }
}

// MARK: - Enums

enum PieceSortOrder: String, CaseIterable {
    case recent, title, status, client

    var label: String {
        switch self {
        case .recent: "Recently Updated"
        case .title: "Title"
        case .status: "Status"
        case .client: "Client"
        }
    }

    var systemImage: String {
        switch self {
        case .recent: "clock"
        case .title: "textformat.abc"
        case .status: "circle.badge.checkmark"
        case .client: "person"
        }
    }
}

enum PieceTypeFilter: String, CaseIterable {
    case all, custom, flash, walkIn

    var label: String {
        switch self {
        case .all: "All Types"
        case .custom: "Custom"
        case .flash: "Flash"
        case .walkIn: "Walk-In"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .custom: "paintbrush.pointed"
        case .flash: "bolt.fill"
        case .walkIn: "figure.walk"
        }
    }
}

enum PieceStatusFilter: String, CaseIterable {
    case all, active, completed, archived

    var label: String {
        switch self {
        case .all: "All Statuses"
        case .active: "Active"
        case .completed: "Completed"
        case .archived: "Archived"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "circle"
        case .active: "flame"
        case .completed: "checkmark.circle"
        case .archived: "archivebox"
        }
    }
}

// MARK: - Status Colour System (module-wide)

/// Named colour palette available for status customisation.
extension Color {
    static func forStatusName(_ name: String) -> Color {
        switch name {
        case "blue":    return .blue
        case "purple":  return .purple
        case "orange":  return .orange
        case "green":   return .green
        case "red":     return .red
        case "gray":    return .gray
        case "yellow":  return .yellow
        case "pink":    return .pink
        case "teal":    return .teal
        case "indigo":  return .indigo
        case "cyan":    return .cyan
        case "mint":    return .mint
        default:        return .secondary
        }
    }

    static let statusColorPalette: [String] = [
        "blue", "purple", "orange", "green", "red",
        "gray", "yellow", "pink", "teal", "indigo", "cyan", "mint"
    ]
}

extension PieceStatus {
    var defaultColorName: String {
        switch self {
        case .concept, .designInProgress: "blue"
        case .approved, .scheduled:       "purple"
        case .inProgress:                 "orange"
        case .completed, .healed:         "green"
        case .touchUp:                    "red"
        case .archived:                   "gray"
        }
    }

    var defaultColor: Color { .forStatusName(defaultColorName) }

    /// Returns the artist's custom colour for this status, falling back to the default.
    func color(from profile: UserProfile?) -> Color {
        guard let name = profile?.statusColorNames[rawValue], !name.isEmpty else {
            return defaultColor
        }
        return .forStatusName(name)
    }
}

// MARK: - Quick Add Piece Wizard

struct QuickAddPieceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Client> { !$0.isFlashPortfolioClient }, sort: \Client.lastName)
    private var clients: [Client]
    @Query private var profiles: [UserProfile]

    @State private var selectedClient: Client?
    @State private var title = ""
    @State private var pieceType: PieceType = .custom
    @State private var step: WizardStep = .selectClient
    @State private var searchText = ""

    private enum WizardStep { case selectClient, details }

    private var defaultRate: Decimal { profiles.first?.defaultHourlyRate ?? 150 }

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
            Group {
                switch step {
                case .selectClient: clientStep
                case .details:      detailsStep
                }
            }
        }
    }

    // MARK: Step 1 — Client

    private var clientStep: some View {
        List(filteredClients) { client in
            Button {
                selectedClient = client
                withAnimation { step = .details }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.accentColor.opacity(0.1)).frame(width: 38, height: 38)
                        Text(client.initialsDisplay)
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.fullName).font(.body.weight(.medium))
                        if !client.email.isEmpty {
                            Text(client.email).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.caption)
                }
            }
            .buttonStyle(.plain)
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search clients…")
        .navigationTitle("Select Client")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    // MARK: Step 2 — Details

    private var detailsStep: some View {
        Form {
            Section("Piece") {
                TextField("Title", text: $title)
                    .submitLabel(.done)
                Picker("Type", selection: $pieceType) {
                    ForEach(PieceType.allCases, id: \.self) { t in
                        Label(t.rawValue, systemImage: t.systemImage).tag(t)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                LabeledContent("Client", value: selectedClient?.fullName ?? "")
                LabeledContent("Rate", value: defaultRate.currencyFormatted + "/hr")
                Text("A consultation session will be added automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Summary")
            }
        }
        .navigationTitle(selectedClient?.fullName ?? "New Piece")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { withAnimation { step = .selectClient } }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { save() }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: Save

    private func save() {
        guard let client = selectedClient else { return }
        let piece = Piece(
            title: title.trimmingCharacters(in: .whitespaces),
            status: .concept,
            pieceType: pieceType,
            hourlyRate: defaultRate,
            depositAmount: 0
        )
        piece.client = client
        modelContext.insert(piece)

        // Auto-create a default consultation session
        let session = Session(
            date: Date(),
            startTime: Date(),
            sessionType: .consultation,
            hourlyRateAtTime: defaultRate,
            notes: "Initial consultation"
        )
        session.piece = piece
        modelContext.insert(session)
        piece.updatedAt = Date()
        dismiss()
    }
}

#Preview {
    PieceListView()
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}
