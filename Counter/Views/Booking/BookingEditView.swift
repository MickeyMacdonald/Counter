import SwiftUI
import SwiftData

struct BookingEditView: View {
    enum Mode {
        case add
        case edit(Booking)
    }

    let mode: Mode
    var initialDate: Date?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Client.lastName) private var clients: [Client]

    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var bookingType: BookingType = .session
    @State private var status: BookingStatus = .confirmed
    @State private var notes: String = ""
    @State private var depositPaid: Bool = false
    @State private var selectedClient: Client?
    @State private var selectedPiece: Piece?
    @State private var isWalkIn: Bool = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String {
        isEditing ? "Edit Booking" : "New Booking"
    }

    private var availablePieces: [Piece] {
        selectedClient?.pieces.sorted(by: { $0.updatedAt > $1.updatedAt }) ?? []
    }

    init(mode: Mode, initialDate: Date? = nil) {
        self.mode = mode
        self.initialDate = initialDate

        switch mode {
        case .add:
            let now = Date()
            let baseDate = initialDate ?? now
            _date = State(initialValue: baseDate)
            // Default to next hour
            let calendar = Calendar.current
            let nextHour = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
            let rounded = calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
            _startTime = State(initialValue: rounded)
            _endTime = State(initialValue: rounded.addingTimeInterval(3600))
        case .edit(let booking):
            _date = State(initialValue: booking.date)
            _startTime = State(initialValue: booking.startTime)
            _endTime = State(initialValue: booking.endTime)
            _bookingType = State(initialValue: booking.bookingType)
            _status = State(initialValue: booking.status)
            _notes = State(initialValue: booking.notes)
            _depositPaid = State(initialValue: booking.depositPaid)
            _selectedClient = State(initialValue: booking.client)
            _selectedPiece = State(initialValue: booking.piece)
            _isWalkIn = State(initialValue: booking.client == nil)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Booking Type
                Section("Type") {
                    Picker("Booking Type", selection: $bookingType) {
                        ForEach(BookingType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }

                    if isEditing {
                        Picker("Status", selection: $status) {
                            ForEach(BookingStatus.allCases, id: \.self) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                    }
                }

                // Date & Time
                Section("Date & Time") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                // Client
                Section("Client") {
                    Toggle("Walk-in", isOn: $isWalkIn)

                    if !isWalkIn {
                        Picker("Client", selection: $selectedClient) {
                            Text("None").tag(Client?.none)
                            ForEach(clients) { client in
                                Text(client.fullName).tag(Client?.some(client))
                            }
                        }
                    }
                }
                .onChange(of: isWalkIn) {
                    if isWalkIn {
                        selectedClient = nil
                        selectedPiece = nil
                    }
                }
                .onChange(of: selectedClient) {
                    // Reset piece when client changes
                    if selectedPiece?.client != selectedClient {
                        selectedPiece = nil
                    }
                }

                // Piece (only if client selected)
                if !isWalkIn, let _ = selectedClient, !availablePieces.isEmpty {
                    Section("Piece") {
                        Picker("Piece", selection: $selectedPiece) {
                            Text("None").tag(Piece?.none)
                            ForEach(availablePieces) { piece in
                                Text(piece.title).tag(Piece?.some(piece))
                            }
                        }
                    }
                }

                // Deposit
                Section {
                    Toggle("Deposit Paid", isOn: $depositPaid)
                }

                // Notes
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        switch mode {
        case .add:
            let booking = Booking(
                date: date,
                startTime: startTime,
                endTime: endTime,
                status: status,
                bookingType: bookingType,
                notes: notes,
                depositPaid: depositPaid,
                client: isWalkIn ? nil : selectedClient,
                piece: selectedPiece
            )
            modelContext.insert(booking)

        case .edit(let booking):
            booking.date = date
            booking.startTime = startTime
            booking.endTime = endTime
            booking.status = status
            booking.bookingType = bookingType
            booking.notes = notes
            booking.depositPaid = depositPaid
            booking.client = isWalkIn ? nil : selectedClient
            booking.piece = selectedPiece
            booking.updatedAt = Date()
        }

        dismiss()
    }
}

#Preview("Add") {
    BookingEditView(mode: .add)
        .modelContainer(PreviewContainer.shared.container)
}

