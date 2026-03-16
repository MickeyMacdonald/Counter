import SwiftUI
import SwiftData

struct ClientListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BusinessLockManager.self) private var lockManager
    @Query(sort: \Client.lastName) private var clients: [Client]
    @State private var searchText = ""
    @State private var showingAddClient = false
    @State private var selectedClient: Client?
    @State private var sortOrder: ClientSortOrder = .name

    private var filteredClients: [Client] {
        // Exclude the hidden flash portfolio client from the standard client list
        let visible = clients.filter { !$0.isFlashPortfolioClient }
        let filtered: [Client]
        if searchText.isEmpty {
            filtered = visible
        } else {
            let query = searchText.lowercased()
            filtered = visible.filter {
                $0.fullName.lowercased().contains(query) ||
                $0.email.lowercased().contains(query) ||
                $0.phone.contains(query)
            }
        }
        switch sortOrder {
        case .name:
            return filtered.sorted { $0.lastName < $1.lastName }
        case .recent:
            return filtered.sorted { $0.updatedAt > $1.updatedAt }
        case .pieces:
            return filtered.sorted { $0.pieces.count > $1.pieces.count }
        }
    }

    var body: some View {
        NavigationSplitView {
            Group {
                if filteredClients.isEmpty {
                    emptyState
                } else {
                    clientList
                }
            }
            .navigationTitle("Clients")
            .searchable(text: $searchText, prompt: "Search clients...")
            .toolbar {
                if lockManager.isEnabled && !lockManager.isLocked {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            lockManager.lock()
                        } label: {
                            Image(systemName: "lock.open.fill")
                                .font(.caption)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddClient = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
            }
            .sheet(isPresented: $showingAddClient) {
                ClientEditView(mode: .add)
            }
        } detail: {
            if let selectedClient {
                NavigationStack {
                    ClientDetailView(client: selectedClient)
                }
                .id(selectedClient.persistentModelID)
            } else {
                ContentUnavailableView(
                    "Select a Client",
                    systemImage: "person.crop.circle",
                    description: Text("Choose a client from the list to view their details.")
                )
            }
        }
    }

    private var clientList: some View {
        List(filteredClients, selection: $selectedClient) { client in
            NavigationLink(value: client) {
                ClientRowView(client: client)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    deleteClient(client)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Clients Yet", systemImage: "person.2.slash")
        } description: {
            Text("Tap + to add your first client.")
        } actions: {
            Button("Add Client") {
                showingAddClient = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOrder) {
                ForEach(ClientSortOrder.allCases, id: \.self) { order in
                    Label(order.label, systemImage: order.systemImage)
                        .tag(order)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    private func deleteClient(_ client: Client) {
        if selectedClient == client {
            selectedClient = nil
        }
        modelContext.delete(client)
    }
}

enum ClientSortOrder: String, CaseIterable {
    case name, recent, pieces

    var label: String {
        switch self {
        case .name: "Name"
        case .recent: "Recently Updated"
        case .pieces: "Most Pieces"
        }
    }

    var systemImage: String {
        switch self {
        case .name: "textformat.abc"
        case .recent: "clock"
        case .pieces: "number"
        }
    }
}

#Preview {
    ClientListView()
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}
