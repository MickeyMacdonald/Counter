import SwiftUI
import SwiftData

struct SessionEditView: View {

    // MARK: - Mode

    enum Mode {
        case add
        case edit(TattooSession)

        var existingSession: TattooSession? {
            if case .edit(let s) = self { return s }
            return nil
        }
        var isEditing: Bool { existingSession != nil }
    }

    // MARK: - Init

    let piece: Piece
    let mode: Mode

    init(piece: Piece, mode: Mode = .add) {
        self.piece = piece
        self.mode = mode
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var sessionType: SessionType = .consultation
    @State private var date = Date()
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var isManualOverride = false
    @State private var manualHours: Double = 1.0
    @State private var isNoShow = false
    @State private var chargeNoShowFee = false
    @State private var noShowFee: Decimal = 0
    @State private var flashRate: Decimal = 150
    @State private var notes = ""

    private var computedHours: Double {
        if isManualOverride { return max(0, manualHours) }
        let seconds = endTime.timeIntervalSince(startTime)
        return max(0, seconds / 3600)
    }

    var body: some View {
        NavigationStack {
            Form {
                sessionTypeSection
                bookingSection
                costsSection

                Section("Notes") {
                    TextField("Session notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(mode.isEditing ? "Edit Session" : "Log Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { populateFromExisting() }
        }
    }

    // MARK: - Sections

    private var sessionTypeSection: some View {
        Section("Session Type") {
            Picker("Type", selection: $sessionType) {
                ForEach(SessionType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.systemImage).tag(type)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var bookingSection: some View {
        Section("Booking") {
            DatePicker("Date", selection: $date, displayedComponents: [.date])

            if isManualOverride {
                HStack {
                    Text("Total Hours")
                    Spacer()
                    TextField("0.0", value: $manualHours, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            } else {
                DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                LabeledContent("Duration", value: String(format: "%.1fh", computedHours))
                    .foregroundStyle(.secondary)
            }

            Toggle("Manual Hours", isOn: $isManualOverride)
                .onChange(of: isManualOverride) { _, on in
                    if on { manualHours = computedHours }
                }

            Toggle("Mark No Show", isOn: $isNoShow)

            if isNoShow {
                Toggle("Charge No-Show Fee", isOn: $chargeNoShowFee)
                if chargeNoShowFee {
                    HStack {
                        Text("Fee Amount")
                        Spacer()
                        TextField("0", value: $noShowFee, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }
            }
        }
    }

    private var costsSection: some View {
        Section("Costs") {
            if sessionType.isFlash {
                HStack {
                    Text("Flash Rate")
                    Spacer()
                    Stepper(
                        flashRate.currencyFormatted,
                        onIncrement: { flashRate += 10 },
                        onDecrement: { flashRate = max(0, flashRate - 10) }
                    )
                }
            } else {
                let estimated = Decimal(computedHours) * piece.hourlyRate + noShowFee
                LabeledContent("Hours", value: String(format: "%.1f", computedHours))
                LabeledContent("Rate", value: piece.hourlyRate.currencyFormatted + "/hr")
                LabeledContent("Estimated Cost", value: estimated.currencyFormatted)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Populate from existing session

    private func populateFromExisting() {
        guard let s = mode.existingSession else { return }
        sessionType        = s.sessionType
        date               = s.date
        startTime          = s.startTime
        endTime            = s.endTime ?? s.startTime.addingTimeInterval(3600)
        isManualOverride   = s.manualHoursOverride != nil
        manualHours        = s.manualHoursOverride ?? s.durationHours
        isNoShow           = s.isNoShow
        chargeNoShowFee    = s.noShowFee != nil
        noShowFee          = s.noShowFee ?? 0
        flashRate          = s.flashRate
        notes              = s.notes
    }

    // MARK: - Save

    private func save() {
        switch mode {
        case .add:
            let session = TattooSession(
                date: date,
                startTime: startTime,
                endTime: isManualOverride ? nil : endTime,
                sessionType: sessionType,
                hourlyRateAtTime: piece.hourlyRate,
                flashRate: flashRate,
                manualHoursOverride: isManualOverride ? manualHours : nil,
                isNoShow: isNoShow,
                noShowFee: (isNoShow && chargeNoShowFee) ? noShowFee : nil,
                notes: notes.trimmed
            )
            session.piece = piece
            modelContext.insert(session)

        case .edit(let session):
            session.sessionType          = sessionType
            session.date                 = date
            session.startTime            = startTime
            session.endTime              = isManualOverride ? nil : endTime
            session.manualHoursOverride  = isManualOverride ? manualHours : nil
            session.isNoShow             = isNoShow
            session.noShowFee            = (isNoShow && chargeNoShowFee) ? noShowFee : nil
            session.flashRate            = flashRate
            session.notes                = notes.trimmed
        }

        piece.updatedAt = Date()
        dismiss()
    }
}

#Preview {
    SessionEditView(piece: Piece(title: "Test", hourlyRate: 150))
        .modelContainer(PreviewContainer.shared.container)
}
