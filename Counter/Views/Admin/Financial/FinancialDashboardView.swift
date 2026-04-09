import SwiftUI
import SwiftData

struct FinancialDashboardView: View {
    /// When `true` the view is embedded inside `SettingsView` — no `NavigationSplitView` wrapper.
    var embedded: Bool = false

    @Query(sort: \Piece.updatedAt, order: .reverse) private var allPieces: [Piece]
    @Query private var profiles: [UserProfile]
    @Environment(BusinessLockManager.self) private var lockManager

    @State private var selectedPiece: Piece?
    @State private var showingLogPayment = false

    // MARK: - Filtered Pieces

    private var unsettledPieces: [Piece] {
        allPieces
            .filter { $0.outstandingBalance > 0 }
            .sorted { $0.outstandingBalance > $1.outstandingBalance }
    }

    private var depositPaidPieces: [Piece] {
        unsettledPieces.filter { $0.depositReceived >= $0.depositAmount && $0.depositAmount > 0 }
    }

    private var depositUnpaidPieces: [Piece] {
        unsettledPieces.filter { $0.depositReceived < $0.depositAmount && $0.depositAmount > 0 }
    }

    private var settledPieces: [Piece] {
        allPieces
            .filter { $0.outstandingBalance <= 0 && $0.totalCost > 0 }
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }

    private var totalUnsettled: Decimal {
        unsettledPieces.reduce(Decimal.zero) { $0 + $1.outstandingBalance }
    }

    private var totalSettled: Decimal {
        settledPieces.reduce(Decimal.zero) { $0 + $1.totalPaymentsReceived }
    }

    // MARK: - Body

    var body: some View {
        if embedded {
            financialContent
        } else {
            NavigationSplitView {
                financialContent
            } detail: {
                if let selectedPiece {
                    NavigationStack {
                        PieceFinancialDetailView(piece: selectedPiece)
                    }
                    .id(selectedPiece.persistentModelID)
                } else {
                    ContentUnavailableView(
                        "Select a Piece",
                        systemImage: "dollarsign.circle",
                        description: Text("Choose a piece from the list to view its financial details.")
                    )
                }
            }
            .sheet(isPresented: $showingLogPayment) {
                PaymentLogView()
            }
        }
    }

    @ViewBuilder
    private var financialContent: some View {
        sidebar
            .navigationTitle("Financial")
            .navigationDestination(for: Piece.self) { piece in
                PieceFinancialDetailView(piece: piece)
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
                    Button { showingLogPayment = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingLogPayment) {
                PaymentLogView()
            }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedPiece) {
            // Summary header
            Section {
                summaryCards
            }

            // Filter groups — drill down into piece lists
            Section("Filter Groups") {
                // Unsettled
                NavigationLink {
                    FinancialFilteredListView(
                        title: "Unsettled",
                        pieces: unsettledPieces,
                        selectedPiece: $selectedPiece
                    )
                } label: {
                    filterGroupRow(
                        icon: "exclamationmark.triangle",
                        label: "Unsettled",
                        count: unsettledPieces.count,
                        amount: totalUnsettled,
                        color: .orange
                    )
                }

                // Deposit Paid
                NavigationLink {
                    FinancialFilteredListView(
                        title: "Deposit Paid",
                        pieces: depositPaidPieces,
                        selectedPiece: $selectedPiece
                    )
                } label: {
                    filterGroupRow(
                        icon: "checkmark.circle",
                        label: "Deposit Paid",
                        count: depositPaidPieces.count,
                        amount: nil,
                        color: .blue,
                        indented: true
                    )
                }

                // Deposit Unpaid
                NavigationLink {
                    FinancialFilteredListView(
                        title: "Deposit Unpaid",
                        pieces: depositUnpaidPieces,
                        selectedPiece: $selectedPiece
                    )
                } label: {
                    filterGroupRow(
                        icon: "xmark.circle",
                        label: "Deposit Unpaid",
                        count: depositUnpaidPieces.count,
                        amount: nil,
                        color: .red,
                        indented: true
                    )
                }

                // Settled
                NavigationLink {
                    FinancialFilteredListView(
                        title: "Settled",
                        pieces: settledPieces,
                        selectedPiece: $selectedPiece
                    )
                } label: {
                    filterGroupRow(
                        icon: "checkmark.seal.fill",
                        label: "Settled",
                        count: settledPieces.count,
                        amount: totalSettled,
                        color: .green
                    )
                }
            }

            // All pieces — directly selectable
            Section("All Pieces") {
                if allPieces.isEmpty {
                    Text("No pieces yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allPieces) { piece in
                        NavigationLink(value: piece) {
                            financialPieceRow(piece)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 0) {
            StatBlock(label: "Pieces", value: "\(allPieces.count)")
            Divider()
            StatBlock(label: "Unsettled", value: totalUnsettled.currencyFormatted)
            Divider()
            StatBlock(label: "Collected", value: totalSettled.currencyFormatted)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Filter Group Row

    private func filterGroupRow(
        icon: String,
        label: String,
        count: Int,
        amount: Decimal?,
        color: Color,
        indented: Bool = false
    ) -> some View {
        HStack {
            if indented {
                Spacer().frame(width: 12)
            }
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            if let amount {
                Text(amount.currencyFormatted)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
            }
            Text("\(count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.06), in: Capsule())
        }
    }

    // MARK: - Piece Row

    private func financialPieceRow(_ piece: Piece) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let client = piece.client {
                Text(client.fullName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Text(piece.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack {
                Text(piece.isFullyPaid ? "Settled" : piece.outstandingBalance.currencyFormatted)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (piece.isFullyPaid ? Color.green : Color.orange).opacity(0.12),
                        in: Capsule()
                    )
                    .foregroundStyle(piece.isFullyPaid ? .green : .orange)

                Spacer()

                Text(piece.totalCost.currencyFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Filtered List (pushed within sidebar)

struct FinancialFilteredListView: View {
    let title: String
    let pieces: [Piece]
    @Binding var selectedPiece: Piece?

    var body: some View {
        List(pieces, selection: $selectedPiece) { piece in
            NavigationLink(value: piece) {
                VStack(alignment: .leading, spacing: 4) {
                    if let client = piece.client {
                        Text(client.fullName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }

                    Text(piece.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack {
                        Text(piece.isFullyPaid ? "Settled" : piece.outstandingBalance.currencyFormatted)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (piece.isFullyPaid ? Color.green : Color.orange).opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(piece.isFullyPaid ? .green : .orange)

                        Spacer()

                        Text(piece.totalCost.currencyFormatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Financial Category

enum FinancialCategory: String, CaseIterable {
    case unsettledAll = "All Unsettled"
    case depositPaid = "Deposit Paid"
    case depositUnpaid = "Deposit Unpaid"
    case settled = "Settled"
    case allPieces = "All Pieces"

    var label: String { rawValue }

    var systemImage: String {
        switch self {
        case .unsettledAll: "exclamationmark.triangle"
        case .depositPaid: "checkmark.circle"
        case .depositUnpaid: "xmark.circle"
        case .settled: "checkmark.seal.fill"
        case .allPieces: "square.grid.2x2"
        }
    }

    var color: Color {
        switch self {
        case .unsettledAll: .orange
        case .depositPaid: .blue
        case .depositUnpaid: .red
        case .settled: .green
        case .allPieces: .primary
        }
    }
}

// MARK: - Time Period

enum TimePeriod: String, CaseIterable {
    case thisWeek = "Week"
    case thisMonth = "Month"
    case thisYear = "Year"
    case allTime = "All"

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (start, now)
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (start, now)
        case .thisYear:
            let start = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return (start, now)
        case .allTime:
            return (Date.distantPast, now)
        }
    }
}

#Preview {
    FinancialDashboardView()
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}
