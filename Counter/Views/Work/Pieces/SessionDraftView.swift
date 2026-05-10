import SwiftUI

// MARK: - Draft value types used during piece creation

struct DraftPhoto: Identifiable {
    var id = UUID()
    var image: UIImage
    var isPrimary: Bool
}

struct DraftSession: Identifiable {
    var id = UUID()
    var sessionType: SessionType = .consultation
    var eventTags: [String] = []
    var date: Date = Date()
    var startTime: Date = Date()
    var endTime: Date = Date().addingTimeInterval(3600)
    var isManualOverride: Bool = false
    var manualHours: Double = 1.0
    var isNoShow: Bool = false
    var chargeNoShowFee: Bool = false
    var noShowFee: Decimal = 0
    var flashRate: Decimal = 150
    var notes: String = ""

    var computedHours: Double {
        if isManualOverride { return max(0, manualHours) }
        let seconds = endTime.timeIntervalSince(startTime)
        return max(0, seconds / 3600)
    }
}

// MARK: - Session detail sheet for the add-piece flow

struct SessionDraftView: View {
    @State private var session: DraftSession
    let hourlyRate: Decimal
    let onSave: (DraftSession) -> Void

    @Environment(\.dismiss) private var dismiss

    init(session: DraftSession, hourlyRate: Decimal, onSave: @escaping (DraftSession) -> Void) {
        _session = State(initialValue: session)
        self.hourlyRate = hourlyRate
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                sessionTypeSection
                bookingSection
                costsSection
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(session)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var availableEventTags: [String] {
        UserDefaults.standard.stringArray(forKey: "sessionEventTags") ?? [
            "Convention", "Guest Spot", "Walk-In Day", "Private Event", "Pop-Up Shop", "Flash Day"
        ]
    }

    private var sessionTypeSection: some View {
        Section("Session Type") {
            Picker("Type", selection: $session.sessionType) {
                ForEach(SessionType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.systemImage).tag(type)
                }
            }
            .pickerStyle(.menu)

            if !availableEventTags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(availableEventTags, id: \.self) { tag in
                        let selected = session.eventTags.contains(tag)
                        Button {
                            if selected { session.eventTags.removeAll { $0 == tag } }
                            else        { session.eventTags.append(tag) }
                        } label: {
                            Text(tag)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06),
                                    in: Capsule()
                                )
                                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                                .overlay(Capsule().stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    private var bookingSection: some View {
        Section("Booking") {
            DatePicker("Date & Time", selection: $session.date, displayedComponents: [.date, .hourAndMinute])

            if session.isManualOverride {
                HStack {
                    Text("Total Hours")
                    Spacer()
                    TextField("0.0", value: $session.manualHours, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            } else {
                DatePicker("Start", selection: $session.startTime, displayedComponents: .hourAndMinute)
                DatePicker("End", selection: $session.endTime, displayedComponents: .hourAndMinute)
                LabeledContent("Duration", value: String(format: "%.1fh", session.computedHours))
                    .foregroundStyle(.secondary)
            }

            Toggle("Override Hours Manually", isOn: $session.isManualOverride)
                .onChange(of: session.isManualOverride) { _, on in
                    if on { session.manualHours = session.computedHours }
                }

            Toggle("Mark No Show", isOn: $session.isNoShow)

            if session.isNoShow {
                Toggle("Charge No-Show Fee", isOn: $session.chargeNoShowFee)
                if session.chargeNoShowFee {
                    HStack {
                        Text("Fee Amount")
                        Spacer()
                        TextField("0", value: $session.noShowFee, format: .currency(code: "USD"))
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
            if session.sessionType.isFlash {
                HStack {
                    Text("Flash Rate")
                    Spacer()
                    Stepper(
                        session.flashRate.currencyFormatted,
                        onIncrement: { session.flashRate += 10 },
                        onDecrement: { session.flashRate = max(0, session.flashRate - 10) }
                    )
                }
            } else {
                let estimated = Decimal(session.computedHours) * hourlyRate
                LabeledContent("Hours", value: String(format: "%.1f", session.computedHours))
                LabeledContent("Rate", value: hourlyRate.currencyFormatted + "/hr")
                LabeledContent("Estimated Cost", value: estimated.currencyFormatted)
                    .fontWeight(.semibold)
            }
        }
    }
}
