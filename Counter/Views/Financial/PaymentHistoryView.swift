import SwiftUI
import SwiftData

/// Full scrollable, filterable list of all recorded payments.
struct PaymentHistoryView: View {
    @Query(sort: \Payment.paymentDate, order: .reverse) private var allPayments: [Payment]
    @Environment(\.dismiss) private var dismiss

    @State private var filterMethod: PaymentMethod?
    @State private var filterType: PaymentType?
    @State private var searchText = ""

    private var filteredPayments: [Payment] {
        var result = allPayments

        if let method = filterMethod {
            result = result.filter { $0.paymentMethod == method }
        }
        if let type = filterType {
            result = result.filter { $0.paymentType == type }
        }
        if !searchText.isEmpty {
            result = result.filter { payment in
                payment.client?.fullName.localizedCaseInsensitiveContains(searchText) == true ||
                payment.piece?.title.localizedCaseInsensitiveContains(searchText) == true ||
                payment.notes.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var groupedPayments: [(key: String, payments: [Payment])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: filteredPayments) { payment in
            formatter.string(from: payment.paymentDate)
        }

        return grouped
            .map { (key: $0.key, payments: $0.value) }
            .sorted { $0.payments.first!.paymentDate > $1.payments.first!.paymentDate }
    }

    private var totalFiltered: Decimal {
        filteredPayments
            .reduce(Decimal.zero) {
                $0 + ($1.paymentType == .refund ? -$1.amount : $1.amount)
            }
    }

    var body: some View {
        List {
            // Filters
            Section {
                HStack(spacing: 8) {
                    Menu {
                        Button("All Methods") { filterMethod = nil }
                        Divider()
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Button {
                                filterMethod = method
                            } label: {
                                Label(method.rawValue, systemImage: method.systemImage)
                            }
                        }
                    } label: {
                        filterChip(
                            label: filterMethod?.rawValue ?? "Method",
                            isActive: filterMethod != nil
                        )
                    }

                    Menu {
                        Button("All Types") { filterType = nil }
                        Divider()
                        ForEach(PaymentType.allCases, id: \.self) { type in
                            Button {
                                filterType = type
                            } label: {
                                Label(type.rawValue, systemImage: type.systemImage)
                            }
                        }
                    } label: {
                        filterChip(
                            label: filterType?.rawValue ?? "Type",
                            isActive: filterType != nil
                        )
                    }

                    Spacer()

                    Text(totalFiltered.currencyFormatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            if filteredPayments.isEmpty {
                ContentUnavailableView {
                    Label("No Payments", systemImage: "dollarsign.circle")
                } description: {
                    Text("No payments match the current filters.")
                }
            } else {
                ForEach(groupedPayments, id: \.key) { group in
                    Section(group.key) {
                        ForEach(group.payments) { payment in
                            paymentRow(payment)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Payment History")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search by client, piece, or notes")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }
        }
    }

    private func filterChip(label: String, isActive: Bool) -> some View {
        Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentColor.opacity(0.15) : .primary.opacity(0.06), in: Capsule())
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
    }

    private func paymentRow(_ payment: Payment) -> some View {
        HStack(spacing: 12) {
            Image(systemName: payment.paymentMethod.systemImage)
                .font(.title3)
                .foregroundStyle(payment.paymentType == .refund ? .red : Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(payment.paymentType.rawValue)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    if let client = payment.client {
                        Text(client.fullName)
                    }
                    if let piece = payment.piece {
                        Text("· \(piece.title)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if !payment.notes.isEmpty {
                    Text(payment.notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(payment.paymentType == .refund ? "-\(payment.amount.currencyFormatted)" : payment.amount.currencyFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(payment.paymentType == .refund ? .red : .primary)
                Text(payment.paymentDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        PaymentHistoryView()
    }
    .modelContainer(PreviewContainer.shared.container)
}
