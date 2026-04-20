import SwiftUI
import SwiftData

// MARK: - Filter helpers

enum SessionWorkType: String, CaseIterable {
    case all    = "All"
    case custom = "Custom"
    case flash  = "Flash"

    var systemImage: String {
        switch self {
        case .all:    "square.grid.2x2"
        case .custom: "paintbrush"
        case .flash:  "bolt.fill"
        }
    }
}

// MARK: - SessionsSidebarList
// Displayed directly in the Bookings sidebar when the Sessions group is active.
// The parent (SessionsTabView) owns `selectedSession` and `searchText` so the
// SidebarSearchField at the bottom feeds into this list automatically.

struct SessionsSidebarList: View {
    @Binding var selectedSession: Session?
    @Binding var searchText: String

    @Query(sort: \Session.date, order: .reverse) private var allSessions: [Session]
    @Query(sort: \Client.lastName) private var allClients: [Client]

    // MARK: Filters (managed internally, exposed via toolbar)
    @State private var filterClient: Client?          = nil
    @State private var filterMonth: Int?              = nil
    @State private var filterYear: Int?               = nil
    @State private var filterWorkType: SessionWorkType = .all
    @State private var filterSessionType: SessionType? = nil
    @State private var billableOnly = false

    private var visibleClients: [Client] {
        allClients.filter { !$0.isFlashPortfolioClient }
    }

    private var availableYears: [Int] {
        Set(allSessions.map { Calendar.current.component(.year, from: $0.date) })
            .sorted(by: >)
    }

    private var filteredSessions: [Session] {
        var result = allSessions

        if let client = filterClient {
            result = result.filter {
                $0.piece?.client?.persistentModelID == client.persistentModelID
            }
        }

        switch filterWorkType {
        case .all:    break
        case .custom: result = result.filter { $0.piece?.pieceType != .flash }
        case .flash:  result = result.filter { $0.piece?.pieceType == .flash }
        }

        if let type = filterSessionType {
            result = result.filter { $0.sessionType == type }
        }

        if let month = filterMonth {
            result = result.filter {
                Calendar.current.component(.month, from: $0.date) == month
            }
        }
        if let year = filterYear {
            result = result.filter {
                Calendar.current.component(.year, from: $0.date) == year
            }
        }

        if billableOnly {
            result = result.filter { $0.sessionType.defaultChargeable }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.piece?.title.lowercased().contains(q) == true ||
                $0.piece?.client?.fullName.lowercased().contains(q) == true ||
                $0.sessionType.rawValue.lowercased().contains(q) ||
                $0.notes.lowercased().contains(q)
            }
        }

        return result
    }

    // MARK: Body

    var body: some View {
        Group {
            if filteredSessions.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Sessions" : "No Results",
                    systemImage: searchText.isEmpty
                        ? "clock.arrow.2.circlepath"
                        : "magnifyingglass"
                )
            } else {
                List(filteredSessions, selection: $selectedSession) { session in
                    sidebarRow(session)
                        .tag(session)
                }
                .listStyle(.sidebar)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    filterMenuContent
                } label: {
                    Image(systemName: hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    // MARK: - Sidebar row

    private func sidebarRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // Type + duration
            HStack(spacing: 6) {
                Image(systemName: session.sessionType.systemImage)
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                Text(session.sessionType.rawValue)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
                Text(session.durationFormatted)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            // Piece · Client
            if let piece = session.piece {
                HStack(spacing: 3) {
                    Text(piece.title)
                        .font(.caption)
                        .lineLimit(1)
                    if let client = piece.client {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(client.fullName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            // Date
            Text(session.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Filter menu

    @ViewBuilder
    private var filterMenuContent: some View {
        Section("Client") {
            Picker("Client", selection: $filterClient) {
                Text("All Clients").tag(Client?.none)
                ForEach(visibleClients) { client in
                    Text(client.fullName).tag(Client?.some(client))
                }
            }
        }

        Section("Work Type") {
            Picker("Work Type", selection: $filterWorkType) {
                ForEach(SessionWorkType.allCases, id: \.self) { t in
                    Label(t.rawValue, systemImage: t.systemImage).tag(t)
                }
            }
        }

        Section("Session Type") {
            Picker("Session Type", selection: $filterSessionType) {
                Text("Any Type").tag(SessionType?.none)
                ForEach(SessionType.allCases, id: \.self) { t in
                    Label(t.rawValue, systemImage: t.systemImage).tag(SessionType?.some(t))
                }
            }
        }

        if !availableYears.isEmpty {
            Section("Year") {
                Picker("Year", selection: $filterYear) {
                    Text("Any Year").tag(Int?.none)
                    ForEach(availableYears, id: \.self) { y in
                        Text(String(y)).tag(Int?.some(y))
                    }
                }
            }
        }

        Section("Month") {
            Picker("Month", selection: $filterMonth) {
                Text("Any Month").tag(Int?.none)
                ForEach(1...12, id: \.self) { m in
                    Text(Calendar.current.monthSymbols[m - 1]).tag(Int?.some(m))
                }
            }
        }

        Divider()

        Toggle("Billable Only", isOn: $billableOnly)

        if hasActiveFilters {
            Button(role: .destructive) {
                resetFilters()
            } label: {
                Label("Clear Filters", systemImage: "xmark.circle")
            }
        }
    }

    private var hasActiveFilters: Bool {
        filterClient != nil || filterMonth != nil || filterYear != nil ||
        filterWorkType != .all || filterSessionType != nil || billableOnly
    }

    private func resetFilters() {
        filterClient      = nil
        filterMonth       = nil
        filterYear        = nil
        filterWorkType    = .all
        filterSessionType = nil
        billableOnly      = false
    }
}
