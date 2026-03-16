import SwiftUI
import SwiftData

struct AvailabilityEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AvailabilitySlot.dayOfWeek) private var slots: [AvailabilitySlot]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Set your weekly availability. Flash-only slots let clients self-book flash work during those hours.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                ForEach(0..<7, id: \.self) { day in
                    DayAvailabilitySection(
                        dayOfWeek: day,
                        slot: slots.first(where: { $0.dayOfWeek == day }),
                        onToggle: { enabled in
                            toggleDay(day, enabled: enabled)
                        },
                        onUpdate: { start, end, flashOnly in
                            updateSlot(day: day, start: start, end: end, flashOnly: flashOnly)
                        }
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Weekly Availability")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggleDay(_ day: Int, enabled: Bool) {
        if enabled {
            // Create a default slot
            if slots.first(where: { $0.dayOfWeek == day }) == nil {
                let slot = AvailabilitySlot(dayOfWeek: day)
                modelContext.insert(slot)
            } else {
                // Re-enable existing
                if let slot = slots.first(where: { $0.dayOfWeek == day }) {
                    slot.isActive = true
                }
            }
        } else {
            if let slot = slots.first(where: { $0.dayOfWeek == day }) {
                slot.isActive = false
            }
        }
    }

    private func updateSlot(day: Int, start: Date, end: Date, flashOnly: Bool) {
        if let slot = slots.first(where: { $0.dayOfWeek == day }) {
            slot.startTime = start
            slot.endTime = end
            slot.isFlashOnly = flashOnly
        }
    }
}

struct DayAvailabilitySection: View {
    let dayOfWeek: Int
    let slot: AvailabilitySlot?
    let onToggle: (Bool) -> Void
    let onUpdate: (Date, Date, Bool) -> Void

    @State private var isEnabled: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isFlashOnly: Bool

    private var dayName: String {
        let formatter = DateFormatter()
        let symbols = formatter.weekdaySymbols ?? []
        guard dayOfWeek >= 0, dayOfWeek < symbols.count else { return "Unknown" }
        return symbols[dayOfWeek]
    }

    init(dayOfWeek: Int, slot: AvailabilitySlot?, onToggle: @escaping (Bool) -> Void, onUpdate: @escaping (Date, Date, Bool) -> Void) {
        self.dayOfWeek = dayOfWeek
        self.slot = slot
        self.onToggle = onToggle
        self.onUpdate = onUpdate

        let defaultStart = Calendar.current.date(from: DateComponents(hour: 10, minute: 0)) ?? Date()
        let defaultEnd = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()

        _isEnabled = State(initialValue: slot?.isActive ?? false)
        _startTime = State(initialValue: slot?.startTime ?? defaultStart)
        _endTime = State(initialValue: slot?.endTime ?? defaultEnd)
        _isFlashOnly = State(initialValue: slot?.isFlashOnly ?? false)
    }

    var body: some View {
        Section {
            Toggle(dayName, isOn: $isEnabled)
                .onChange(of: isEnabled) { _, newValue in
                    onToggle(newValue)
                }

            if isEnabled {
                DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    .onChange(of: startTime) { _, _ in
                        onUpdate(startTime, endTime, isFlashOnly)
                    }

                DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                    .onChange(of: endTime) { _, _ in
                        onUpdate(startTime, endTime, isFlashOnly)
                    }

                Toggle("Flash Only", isOn: $isFlashOnly)
                    .onChange(of: isFlashOnly) { _, newValue in
                        onUpdate(startTime, endTime, newValue)
                    }

                if isFlashOnly {
                    Label("Clients can self-book flash during these hours", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

#Preview {
    AvailabilityEditView()
        .modelContainer(PreviewContainer.shared.container)
}
