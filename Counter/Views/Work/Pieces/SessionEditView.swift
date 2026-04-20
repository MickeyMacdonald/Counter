import SwiftUI
import SwiftData

// MARK: - Supporting Enums

fileprivate enum SessionChargeMode: String, Hashable {
    case shopDefault = "Shop Default"
    case hourly      = "Hourly"
    case flash       = "Flash"
}

fileprivate enum SessionDepositMode: String, Hashable {
    case shopDefault = "Shop Default"
    case flat        = "Flat"
    case percentage  = "% Rate"
    case none        = "None"
}

// MARK: - SessionEditView

struct SessionEditView: View {

    // MARK: - Mode

    enum Mode {
        case add
        case edit(Session)

        var existingSession: Session? {
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
        self.mode  = mode
    }

    // MARK: - Environment & Queries

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \FlashPriceTier.sortOrder) private var flashTiers: [FlashPriceTier]

    // MARK: - Booking State

    @State private var sessionType: SessionType = .consultation
    @State private var date        = Date()
    @State private var startTime   = Date()
    @State private var endTime     = Date().addingTimeInterval(3600)
    @State private var isManualOverride = false
    @State private var manualHours: Double = 1.0
    @State private var isNoShow         = false
    @State private var chargeNoShowFee  = false
    @State private var noShowFee: Decimal = 0
    @State private var notes = ""

    // MARK: - Charge State

    @State private var chargeMode: SessionChargeMode = .shopDefault
    @State private var customHourlyRate: Decimal     = 150
    @State private var rateIncrement: Decimal        = 25
    @State private var selectedFlashTier: FlashPriceTier?
    @State private var flashRateOverride: Decimal    = 150
    @State private var flashIncrement: Decimal       = 10

    // MARK: - Deposit State

    @State private var depositMode: SessionDepositMode = .shopDefault
    @State private var depositFlat: Decimal    = 0
    @State private var depositIncrement: Decimal = 25
    @State private var depositRate: Double     = 20

    // MARK: - Computed

    private var computedHours: Double {
        if isManualOverride { return max(0, manualHours) }
        let seconds = endTime.timeIntervalSince(startTime)
        return max(0, seconds / 3600)
    }

    private var effectiveRate: Decimal {
        switch chargeMode {
        case .shopDefault: return piece.hourlyRate
        case .hourly:      return customHourlyRate
        case .flash:       return selectedFlashTier?.price ?? flashRateOverride
        }
    }

    private var estimatedCost: Decimal {
        if chargeMode == .flash {
            return effectiveRate + noShowFee
        }
        return Decimal(computedHours) * effectiveRate + noShowFee
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                sessionTypeSection
                bookingSection
                chargeSection
                depositSection

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

    // MARK: - Session Type

    private var sessionTypeSection: some View {
        Section("Session Type") {
            Picker("Type", selection: $sessionType) {
                ForEach(SessionType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.systemImage).tag(type)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: sessionType) { _, type in
                if type.isFlash && chargeMode != .flash  { chargeMode = .flash }
                if !type.isFlash && chargeMode == .flash { chargeMode = .shopDefault }
            }
        }
    }

    // MARK: - Booking

    private var bookingSection: some View {
        Section("Booking") {
            DatePicker("Date", selection: $date, displayedComponents: [.date])

            if isManualOverride {
                HStack {
                    Text("Total Hours")
                    Spacer()
                    TextField("0.0", value: $manualHours,
                              format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            } else {
                DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End",   selection: $endTime,   displayedComponents: .hourAndMinute)
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
                        TextField("0", value: $noShowFee,
                                  format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }
            }
        }
    }

    // MARK: - Charge

    private var chargeSection: some View {
        Section("Charge") {
            HStack {
                Text("Charge type")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Charge type", selection: $chargeMode) {
                    Text("Shop Default").tag(SessionChargeMode.shopDefault)
                    Text("Hourly").tag(SessionChargeMode.hourly)
                    if !flashTiers.isEmpty {
                        Text("Flash").tag(SessionChargeMode.flash)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            switch chargeMode {
            case .shopDefault:
                LabeledContent("Rate") {
                    Text(piece.hourlyRate.currencyFormatted + "/hr")
                        .foregroundStyle(.secondary)
                }

            case .hourly:
                HStack {
                    Text("Increment")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Increment", selection: $rateIncrement) {
                        ForEach([5, 10, 25, 50, 100, 250], id: \.self) { v in
                            Text("$\(v)").tag(Decimal(v))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                incrementControl(value: $customHourlyRate, increment: rateIncrement, suffix: "/hr")

            case .flash:
                if !flashTiers.isEmpty {
                    Picker("Flash Tier", selection: $selectedFlashTier) {
                        ForEach(flashTiers) { tier in
                            Text("\(tier.label) – \(tier.price.currencyFormatted)")
                                .tag(Optional(tier))
                        }
                    }
                    .onChange(of: selectedFlashTier) { _, tier in
                        if let tier { flashRateOverride = tier.price }
                    }
                }
                HStack {
                    Text("Increment")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Increment", selection: $flashIncrement) {
                        ForEach([5, 10, 25, 50, 100], id: \.self) { v in
                            Text("$\(v)").tag(Decimal(v))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                incrementControl(value: $flashRateOverride, increment: flashIncrement, suffix: "")
            }

            LabeledContent("Estimated Cost") {
                Text(estimatedCost.currencyFormatted).fontWeight(.semibold)
            }
        }
    }

    // MARK: - Deposit

    private var depositSection: some View {
        Section("Deposit") {
            HStack {
                Text("Deposit type")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Deposit type", selection: $depositMode) {
                    Text("Shop Default").tag(SessionDepositMode.shopDefault)
                    Text("Flat").tag(SessionDepositMode.flat)
                    Text("% Rate").tag(SessionDepositMode.percentage)
                    Text("None").tag(SessionDepositMode.none)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: depositMode) { _, mode in
                    switch mode {
                    case .shopDefault: depositFlat = profiles.first?.depositFlat ?? 0
                    case .flat:        if depositFlat == 0 { depositFlat = 50 }
                    case .percentage:  depositFlat = piece.totalCost * Decimal(depositRate) / 100
                    case .none:        depositFlat = 0
                    }
                }
            }

            switch depositMode {
            case .shopDefault:
                if let profile = profiles.first, profile.depositFlat > 0 {
                    LabeledContent("Amount") {
                        Text(profile.depositFlat.currencyFormatted).foregroundStyle(.secondary)
                    }
                } else {
                    Text("No shop default set").foregroundStyle(.secondary)
                }

            case .flat:
                HStack {
                    Text("Increment")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Increment", selection: $depositIncrement) {
                        ForEach([5, 10, 25, 50, 100], id: \.self) { v in
                            Text("$\(v)").tag(Decimal(v))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                incrementControl(value: $depositFlat, increment: depositIncrement, suffix: "")

            case .percentage:
                Stepper("\(Int(depositRate))% of session cost",
                        value: $depositRate, in: 5...50, step: 5)
                    .onChange(of: depositRate) { _, rate in
                        depositFlat = piece.totalCost * Decimal(rate) / 100
                    }
                LabeledContent("Deposit Amount") {
                    Text(depositFlat.currencyFormatted).foregroundStyle(.secondary)
                }

            case .none:
                Text("No deposit required").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Increment Control

    @ViewBuilder
    private func incrementControl(value: Binding<Decimal>, increment: Decimal, suffix: String) -> some View {
        HStack {
            Button {
                value.wrappedValue = max(0, value.wrappedValue - increment)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(value.wrappedValue.currencyFormatted + suffix)
                .font(.title3.weight(.bold))

            Spacer()

            Button {
                value.wrappedValue += increment
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Populate from existing

    private func populateFromExisting() {
        // Defaults for new sessions
        customHourlyRate = piece.hourlyRate
        if piece.pieceType == .flash, !flashTiers.isEmpty {
            chargeMode        = .flash
            selectedFlashTier = flashTiers.first
            flashRateOverride = flashTiers.first?.price ?? piece.hourlyRate
        }
        depositFlat = profiles.first?.depositFlat ?? 0

        guard let s = mode.existingSession else { return }

        sessionType      = s.sessionType
        date             = s.date
        startTime        = s.startTime
        endTime          = s.endTime ?? s.startTime.addingTimeInterval(3600)
        isManualOverride = s.manualHoursOverride != nil
        manualHours      = s.manualHoursOverride ?? s.durationHours
        isNoShow         = s.isNoShow
        chargeNoShowFee  = s.noShowFee != nil
        noShowFee        = s.noShowFee ?? 0
        notes            = s.notes

        if s.sessionType.isFlash {
            chargeMode        = .flash
            flashRateOverride = s.flashRate
            selectedFlashTier = flashTiers.first(where: { $0.price == s.flashRate })
        } else if s.hourlyRateAtTime != piece.hourlyRate {
            chargeMode       = .hourly
            customHourlyRate = s.hourlyRateAtTime
        } else {
            chargeMode = .shopDefault
        }

        depositFlat = piece.depositAmount
        depositMode = piece.depositAmount > 0 ? .flat : .none
    }

    // MARK: - Save

    private func save() {
        let rateToSave: Decimal
        let flashToSave: Decimal
        switch chargeMode {
        case .shopDefault:
            rateToSave  = piece.hourlyRate
            flashToSave = flashRateOverride
        case .hourly:
            rateToSave  = customHourlyRate
            flashToSave = flashRateOverride
        case .flash:
            rateToSave  = piece.hourlyRate
            flashToSave = selectedFlashTier?.price ?? flashRateOverride
        }

        switch mode {
        case .add:
            let session = Session(
                date:                date,
                startTime:           startTime,
                endTime:             isManualOverride ? nil : endTime,
                sessionType:         sessionType,
                hourlyRateAtTime:    rateToSave,
                flashRate:           flashToSave,
                manualHoursOverride: isManualOverride ? manualHours : nil,
                isNoShow:            isNoShow,
                noShowFee:           (isNoShow && chargeNoShowFee) ? noShowFee : nil,
                notes:               notes.trimmed
            )
            session.piece = piece
            modelContext.insert(session)
            if depositMode != .none {
                piece.depositAmount = depositFlat
            }

        case .edit(let session):
            session.sessionType         = sessionType
            session.date                = date
            session.startTime           = startTime
            session.endTime             = isManualOverride ? nil : endTime
            session.manualHoursOverride = isManualOverride ? manualHours : nil
            session.isNoShow            = isNoShow
            session.noShowFee           = (isNoShow && chargeNoShowFee) ? noShowFee : nil
            session.hourlyRateAtTime    = rateToSave
            session.flashRate           = flashToSave
            session.notes               = notes.trimmed
        }

        piece.updatedAt = Date()
        dismiss()
    }
}

#Preview {
    SessionEditView(piece: Piece(title: "Test", hourlyRate: 150))
        .modelContainer(PreviewContainer.shared.container)
}
