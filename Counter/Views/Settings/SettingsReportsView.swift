import SwiftUI
import SwiftData

// MARK: - Report Type

enum ReportType: String, CaseIterable, Identifiable {
    case financial     = "Financial"
    case finishedPieces = "Finished Pieces"
    case flashPortfolio = "Flash Portfolio"
    case clientRecord  = "Client Record"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .financial:      "dollarsign.circle.fill"
        case .finishedPieces: "checkmark.seal.fill"
        case .flashPortfolio: "bolt.fill"
        case .clientRecord:   "person.text.rectangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .financial:      .green
        case .finishedPieces: .blue
        case .flashPortfolio: .orange
        case .clientRecord:   .purple
        }
    }

    var description: String {
        switch self {
        case .financial:
            "Revenue summary, outstanding balances, and settled pieces for a selected period."
        case .finishedPieces:
            "All completed and healed pieces with client, placement, sessions, and cost."
        case .flashPortfolio:
            "Full flash portfolio with prices, tags, and status."
        case .clientRecord:
            "Full client record including pieces, sessions, agreements, and communication log."
        }
    }
}

// MARK: - Settings Reports View

struct SettingsReportsView: View {
    @Query(sort: \Piece.updatedAt, order: .reverse) private var allPieces: [Piece]
    @Query(filter: #Predicate<Client> { !$0.isFlashPortfolioClient }, sort: \Client.lastName)
    private var clients: [Client]
    @Query(filter: #Predicate<Client> { $0.isFlashPortfolioClient })
    private var portfolioClients: [Client]
    @Query private var profiles: [UserProfile]

    @State private var selectedPeriod: TimePeriod = .thisYear
    @State private var selectedClient: Client?
    @State private var isGenerating = false
    @State private var shareURL: URL?
    @State private var showingError = false
    @State private var errorMessage = ""

    private var profile: UserProfile? { profiles.first }

    private var flashPieces: [Piece] {
        portfolioClients.first?.pieces ?? []
    }

    var body: some View {
        List {
            ForEach(ReportType.allCases) { type in
                Section {
                    reportRow(for: type)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Reports")
        .sheet(item: $shareURL) { url in
            ActivityView(items: [url])
                .ignoresSafeArea()
        }
        .alert("Report Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Report Rows

    @ViewBuilder
    private func reportRow(for type: ReportType) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(type.color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: type.systemImage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(type.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.subheadline.weight(.semibold))
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Options
            switch type {
            case .financial:
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)

            case .clientRecord:
                Picker("Client", selection: $selectedClient) {
                    Text("Select a client").tag(Client?.none)
                    ForEach(clients) { client in
                        Text(client.fullName).tag(Optional(client))
                    }
                }
                .pickerStyle(.menu)

            default:
                EmptyView()
            }

            // Generate button
            Button {
                generate(type)
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating…")
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Generate PDF")
                    }
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(type.color)
            .disabled(isGenerating || (type == .clientRecord && selectedClient == nil))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Generation

    private func generate(_ type: ReportType) {
        isGenerating = true
        Task {
            let data: Data?
            let fileName: String

            switch type {
            case .financial:
                let range = selectedPeriod.dateRange
                let filtered = allPieces.filter {
                    let date = $0.completedAt ?? $0.updatedAt
                    return date >= range.start && date <= range.end
                }
                data = await PDFReportService.shared.generateFinancialReport(
                    pieces: filtered,
                    profile: profile,
                    period: selectedPeriod.rawValue
                )
                fileName = "financial_report_\(selectedPeriod.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")).pdf"

            case .finishedPieces:
                data = await PDFReportService.shared.generateFinishedPiecesReport(
                    pieces: allPieces.filter { $0.client?.isFlashPortfolioClient != true },
                    profile: profile
                )
                fileName = "finished_pieces_report.pdf"

            case .flashPortfolio:
                data = await PDFReportService.shared.generateFlashReport(
                    pieces: flashPieces,
                    profile: profile
                )
                fileName = "flash_portfolio_report.pdf"

            case .clientRecord:
                guard let client = selectedClient else { isGenerating = false; return }
                data = await PDFReportService.shared.generateClientReport(client: client)
                let safeName = client.fullName
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "_")
                    .filter { $0.isLetter || $0 == "_" }
                fileName = "client_report_\(safeName).pdf"
            }

            await MainActor.run {
                isGenerating = false
                guard let data else {
                    errorMessage = "Failed to generate report."
                    showingError = true
                    return
                }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(fileName)
                do {
                    try data.write(to: url)
                    shareURL = url
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Activity View (share sheet)

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - URL Identifiable

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    NavigationStack {
        SettingsReportsView()
    }
    .modelContainer(PreviewContainer.shared.container)
    .environment(BusinessLockManager())
}
