import SwiftUI
import SwiftData

// MARK: - Works Section

enum WorksSection: String, CaseIterable {
    case clients = "Clients"
    case pieces  = "Pieces"
}

// MARK: - Works Tab

struct WorksTabView: View {
    @Binding var selectedTab: AppTab
    @State private var section: WorksSection = .clients
    @State private var selectedClient: Client?
    @State private var selectedPiece: Piece?
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                AppTabSwitcher(selectedTab: $selectedTab)
                Divider()
                Picker("Section", selection: $section) {
                    ForEach(WorksSection.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                switch section {
                case .clients:
                    WorksClientsList(selectedClient: $selectedClient, searchText: $searchText)
                case .pieces:
                    WorksPiecesList(selectedPiece: $selectedPiece, searchText: $searchText)
                }

                Divider()
                SidebarSearchField(
                    text: $searchText,
                    prompt: section == .clients ? "Search clients..." : "Search pieces..."
                )
            }
            .navigationTitle("Works")
            .navigationBarTitleDisplayMode(.inline)
        } detail: {
            switch section {
            case .clients:
                if let client = selectedClient {
                    NavigationStack {
                        ClientDetailView(client: client)
                    }
                    .id(client.persistentModelID)
                } else {
                    ContentUnavailableView(
                        "Select a Client",
                        systemImage: "person.crop.circle",
                        description: Text("Choose a client from the list.")
                    )
                }
            case .pieces:
                if let piece = selectedPiece {
                    NavigationStack {
                        PieceDetailView(piece: piece)
                    }
                    .id(piece.persistentModelID)
                } else {
                    ContentUnavailableView(
                        "Select a Piece",
                        systemImage: "paintbrush.pointed",
                        description: Text("Choose a piece from the list.")
                    )
                }
            }
        }
        .onChange(of: section) {
            selectedClient = nil
            selectedPiece = nil
            searchText = ""
        }
    }
}

// MARK: - Works Clients List

private struct WorksClientsList: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BusinessLockManager.self) private var lockManager
    @Query(sort: \Client.lastName) private var clients: [Client]
    @Binding var selectedClient: Client?
    @Binding var searchText: String
    @State private var sortOrder: ClientSortOrder = .name
    @State private var showingAddClient = false

    private var filteredClients: [Client] {
        let visible = clients.filter { !$0.isFlashPortfolioClient }
        let filtered: [Client]
        if searchText.isEmpty {
            filtered = visible
        } else {
            let q = searchText.lowercased()
            filtered = visible.filter {
                $0.fullName.lowercased().contains(q) ||
                $0.email.lowercased().contains(q) ||
                $0.phone.contains(q)
            }
        }
        switch sortOrder {
        case .name:   return filtered.sorted { $0.lastName < $1.lastName }
        case .recent: return filtered.sorted { $0.updatedAt > $1.updatedAt }
        case .pieces: return filtered.sorted { $0.pieces.count > $1.pieces.count }
        }
    }

    var body: some View {
        Group {
            if filteredClients.isEmpty && searchText.isEmpty {
                ContentUnavailableView {
                    Label("No Clients Yet", systemImage: "person.2.slash")
                } description: {
                    Text("Tap + to add your first client.")
                } actions: {
                    Button("Add Client") { showingAddClient = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                }
            } else {
                List(filteredClients, selection: $selectedClient) { client in
                    NavigationLink(value: client) {
                        ClientRowView(client: client)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            if selectedClient == client { selectedClient = nil }
                            modelContext.delete(client)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .toolbar {
            if lockManager.isEnabled && !lockManager.isLocked {
                ToolbarItem(placement: .topBarLeading) {
                    Button { lockManager.lock() } label: {
                        Image(systemName: "lock.open.fill").font(.caption)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddClient = true } label: {
                    Image(systemName: "plus").fontWeight(.semibold)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sortOrder) {
                        ForEach(ClientSortOrder.allCases, id: \.self) { order in
                            Label(order.label, systemImage: order.systemImage).tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showingAddClient) {
            ClientEditView(mode: .add)
        }
    }
}

// MARK: - Works Pieces List

private struct WorksPiecesList: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Piece.updatedAt, order: .reverse) private var allPieces: [Piece]
    @Binding var selectedPiece: Piece?
    @Binding var searchText: String
    @State private var sortOrder: PieceSortOrder = .recent
    @State private var filterType: PieceTypeFilter = .all
    @State private var filterStatus: PieceStatusFilter = .all
    @State private var showAddPieceWizard = false

    private var filteredPieces: [Piece] {
        var result = allPieces.filter { $0.client?.isFlashPortfolioClient != true }

        switch filterType {
        case .all:    break
        case .custom: result = result.filter { $0.pieceType == .custom }
        case .flash:  result = result.filter { $0.pieceType == .flash }
        case .walkIn: result = result.filter { $0.pieceType == .walkIn }
        }

        switch filterStatus {
        case .all: break
        case .active:
            result = result.filter {
                [.concept, .designInProgress, .approved, .scheduled, .inProgress].contains($0.status)
            }
        case .completed:
            result = result.filter { [.completed, .healed].contains($0.status) }
        case .archived:
            result = result.filter { $0.status == .archived }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                $0.bodyPlacement.lowercased().contains(q) ||
                $0.client?.fullName.lowercased().contains(q) == true ||
                $0.tags.contains { $0.lowercased().contains(q) }
            }
        }

        switch sortOrder {
        case .recent: result.sort { $0.updatedAt > $1.updatedAt }
        case .title:  result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .status: result.sort { $0.status.rawValue < $1.status.rawValue }
        case .client: result.sort { ($0.client?.fullName ?? "") < ($1.client?.fullName ?? "") }
        }

        return result
    }

    var body: some View {
        Group {
            if allPieces.filter({ $0.client?.isFlashPortfolioClient != true }).isEmpty {
                ContentUnavailableView {
                    Label("No Pieces Yet", systemImage: "paintbrush.pointed")
                } description: {
                    Text("Pieces will appear here as you add them to clients.")
                }
            } else {
                List(filteredPieces, selection: $selectedPiece) { piece in
                    NavigationLink(value: piece) {
                        PieceListRowView(piece: piece)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddPieceWizard = true } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Sort By") {
                        Picker("Sort", selection: $sortOrder) {
                            ForEach(PieceSortOrder.allCases, id: \.self) { order in
                                Label(order.label, systemImage: order.systemImage).tag(order)
                            }
                        }
                    }
                    Section("Type") {
                        Picker("Type", selection: $filterType) {
                            ForEach(PieceTypeFilter.allCases, id: \.self) { type in
                                Label(type.label, systemImage: type.systemImage).tag(type)
                            }
                        }
                    }
                    Section("Status") {
                        Picker("Status", selection: $filterStatus) {
                            ForEach(PieceStatusFilter.allCases, id: \.self) { status in
                                Label(status.label, systemImage: status.systemImage).tag(status)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showAddPieceWizard) {
            QuickAddPieceSheet()
        }
    }
}

#Preview {
    WorksTabView(selectedTab: .constant(.works))
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}
