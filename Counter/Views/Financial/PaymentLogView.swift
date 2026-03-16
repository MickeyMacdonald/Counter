import SwiftUI
import SwiftData

/// Form to record a new payment against a client / piece.
struct PaymentLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Client.lastName) private var allClients: [Client]

    @State private var amount: String = ""
    @State private var paymentDate = Date()
    @State private var paymentMethod: PaymentMethod = .cash
    @State private var paymentType: PaymentType = .sessionPayment
    @State private var notes = ""
    @State private var selectedClient: Client?
    @State private var selectedPiece: Piece?

    /// Optional pre-fill for a specific piece
    var prefillPiece: Piece?
    var prefillClient: Client?

    private var clientPieces: [Piece] {
        selectedClient?.pieces.sorted { $0.updatedAt > $1.updatedAt } ?? []
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amount.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: ""))
    }

    private var canSave: Bool {
        guard let parsed = parsedAmount, parsed > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        Text("$")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amount)
                            .font(.title2.weight(.semibold))
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Details") {
                    Picker("Type", selection: $paymentType) {
                        ForEach(PaymentType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.systemImage).tag(type)
                        }
                    }

                    Picker("Method", selection: $paymentMethod) {
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Label(method.rawValue, systemImage: method.systemImage).tag(method)
                        }
                    }

                    DatePicker("Date", selection: $paymentDate, displayedComponents: .date)
                }

                Section("Client & Piece") {
                    Picker("Client", selection: $selectedClient) {
                        Text("None").tag(Client?.none)
                        ForEach(allClients) { client in
                            Text(client.fullName).tag(Client?.some(client))
                        }
                    }
                    .onChange(of: selectedClient) { _, newClient in
                        // Reset piece if client changes
                        if selectedPiece?.client?.persistentModelID != newClient?.persistentModelID {
                            selectedPiece = nil
                        }
                    }

                    if !clientPieces.isEmpty {
                        Picker("Piece", selection: $selectedPiece) {
                            Text("None").tag(Piece?.none)
                            ForEach(clientPieces) { piece in
                                Text(piece.title).tag(Piece?.some(piece))
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Quick summary
                if let parsed = parsedAmount, parsed > 0, let piece = selectedPiece {
                    Section("Summary") {
                        LabeledContent("Piece Cost", value: piece.totalCost.currencyFormatted)
                        LabeledContent("Already Paid", value: piece.totalPaymentsReceived.currencyFormatted)
                        LabeledContent("This Payment", value: parsed.currencyFormatted)
                        let newBalance = piece.outstandingBalance - parsed
                        LabeledContent("Remaining Balance") {
                            Text(newBalance.currencyFormatted)
                                .foregroundStyle(newBalance <= 0 ? .green : .orange)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Log Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if let prefillClient {
                    selectedClient = prefillClient
                }
                if let prefillPiece {
                    selectedPiece = prefillPiece
                    selectedClient = prefillPiece.client
                }
            }
        }
    }

    private func save() {
        guard let parsed = parsedAmount else { return }
        let payment = Payment(
            amount: parsed,
            paymentDate: paymentDate,
            paymentMethod: paymentMethod,
            paymentType: paymentType,
            notes: notes,
            piece: selectedPiece,
            client: selectedClient
        )
        modelContext.insert(payment)
        dismiss()
    }
}

#Preview {
    PaymentLogView()
        .modelContainer(PreviewContainer.shared.container)
}
