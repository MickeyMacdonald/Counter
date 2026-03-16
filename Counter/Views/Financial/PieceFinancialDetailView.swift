import SwiftUI
import SwiftData

/// Detailed financial breakdown for a single piece:
/// cost structure, deposit info, session-by-session costs, payment history, and outstanding balance.
struct PieceFinancialDetailView: View {
    @Bindable var piece: Piece
    @Query private var profiles: [UserProfile]
    @State private var showingLogPayment = false

    private var chargeableTypes: [String] {
        profiles.first?.effectiveChargeableSessionTypes ?? SessionType.defaultChargeableRawValues
    }

    private var sortedPayments: [Payment] {
        piece.payments.sorted { $0.paymentDate > $1.paymentDate }
    }

    private var sortedSessions: [TattooSession] {
        piece.sessions.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            // Status banner
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(piece.title)
                            .font(.headline)
                        if let client = piece.client {
                            Label(client.fullName, systemImage: "person.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    statusBadge
                }
            }

            // Financial summary
            Section("Cost Breakdown") {
                if let flat = piece.flatRate {
                    LabeledContent("Flat Rate", value: flat.currencyFormatted)
                } else {
                    LabeledContent("Hourly Rate", value: piece.hourlyRate.currencyFormatted)
                    LabeledContent("Chargeable Hours", value: String(format: "%.1f", piece.chargeableHours(using: chargeableTypes)))
                    LabeledContent("Session Cost", value: piece.chargeableCost(using: chargeableTypes).currencyFormatted)
                }

                let noShowFees = piece.sessions.reduce(Decimal.zero) { $0 + ($1.noShowFee ?? 0) }
                if noShowFees > 0 {
                    LabeledContent("No-Show Fees", value: noShowFees.currencyFormatted)
                        .foregroundStyle(.orange)
                }

                LabeledContent("Total Cost") {
                    Text(piece.totalCost.currencyFormatted)
                        .fontWeight(.bold)
                }
            }

            // Payment status
            Section("Payment Status") {
                LabeledContent("Total Paid", value: piece.totalPaymentsReceived.currencyFormatted)
                if piece.depositAmount > 0 {
                    LabeledContent("Deposit Required", value: piece.depositAmount.currencyFormatted)
                    LabeledContent("Deposit Received", value: piece.depositReceived.currencyFormatted)
                        .foregroundStyle(piece.depositReceived >= piece.depositAmount ? .green : .orange)
                }

                HStack {
                    Text("Outstanding Balance")
                        .fontWeight(.medium)
                    Spacer()
                    Text(piece.outstandingBalance.currencyFormatted)
                        .fontWeight(.bold)
                        .foregroundStyle(piece.isFullyPaid ? .green : .orange)
                }

                Button {
                    showingLogPayment = true
                } label: {
                    Label("Log Payment", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }

            // Session costs
            if !sortedSessions.isEmpty {
                Section("Sessions") {
                    ForEach(sortedSessions) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.sessionType.rawValue)
                                    .font(.subheadline.weight(.medium))
                                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(session.cost.currencyFormatted)
                                    .font(.subheadline.weight(.medium))
                                Text(session.durationFormatted)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Payment history
            if !sortedPayments.isEmpty {
                Section("Payment History") {
                    ForEach(sortedPayments) { payment in
                        HStack(spacing: 12) {
                            Image(systemName: payment.paymentMethod.systemImage)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(payment.paymentType.rawValue)
                                    .font(.subheadline.weight(.medium))
                                Text(payment.paymentDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(payment.amount.currencyFormatted)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Piece Financials")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLogPayment) {
            PaymentLogView(prefillPiece: piece, prefillClient: piece.client)
        }
    }

    private var statusBadge: some View {
        Text(piece.isFullyPaid ? "Paid" : "Outstanding")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                (piece.isFullyPaid ? Color.green : Color.orange).opacity(0.15),
                in: Capsule()
            )
            .foregroundStyle(piece.isFullyPaid ? .green : .orange)
    }
}

#Preview {
    NavigationStack {
        PieceFinancialDetailView(piece: {
            let piece = Piece(
                title: "Botanical Sleeve",
                bodyPlacement: "Left forearm",
                hourlyRate: 175,
                depositAmount: 200
            )
            return piece
        }())
    }
    .modelContainer(PreviewContainer.shared.container)
}
