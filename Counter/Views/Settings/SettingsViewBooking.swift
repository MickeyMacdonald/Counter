import SwiftUI
import SwiftData

// MARK: - SlotType view-layer extensions

extension AvailabilitySlot.SlotType {
    var color: Color {
        switch self {
        case .available:   return Color(red: 0.55, green: 0.82, blue: 0.60)
        case .prep:        return Color(red: 0.45, green: 0.65, blue: 0.92)
        case .unavailable: return Color(UIColor.systemGray3)
        }
    }
}

// MARK: - Settings Booking View

struct SettingsViewBooking: View {
    @Query(sort: \AvailabilityOverride.startDate) private var overrides: [AvailabilityOverride]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddOverride = false

    var body: some View {
        List {
            Section {
                WeekAvailabilityGrid()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } header: {
                Text("Weekly Hours")
            } footer: {
                Text("Select a block type, then drag a column to paint a time range. Drawing over an existing block replaces it. Tap a block to remove it. Tap a day name to clear the whole day.")
            }

            Section {
                if overrides.isEmpty {
                    Label("No overrides added", systemImage: "calendar.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(overrides) { override in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(override.dateRangeFormatted).font(.subheadline)
                                if !override.reason.isEmpty {
                                    Text(override.reason).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: override.isUnavailable ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(override.isUnavailable ? Color.red.opacity(0.7) : Color.green.opacity(0.7))
                        }
                    }
                    .onDelete { offsets in offsets.forEach { modelContext.delete(overrides[$0]) } }
                }
                Button { showingAddOverride = true } label: {
                    Label("Add Override", systemImage: "plus.circle")
                }
            } header: {
                Text("Overrides")
            } footer: {
                Text("Override specific dates or date ranges — e.g. holidays, vacations, or pop-up availability.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Booking")
        .sheet(isPresented: $showingAddOverride) { AvailabilityOverrideEditView() }
    }
}

// MARK: - Type selector button

private struct TypeSelectorButton: View {
    let slotType: AvailabilitySlot.SlotType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle().fill(slotType.color).frame(width: 7, height: 7)
                Text(slotType.shortLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? slotType.color : Color.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected ? slotType.color.opacity(0.12) : Color(UIColor.systemGray6),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(isSelected ? slotType.color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Week Availability Grid

struct WeekAvailabilityGrid: View {
    @Query(sort: \AvailabilitySlot.dayOfWeek) private var slots: [AvailabilitySlot]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var selectedType: AvailabilitySlot.SlotType = .unavailable
    @State private var visibleDay: Int = 0   // compact-mode only

    private let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let columnHeight: CGFloat = 390
    private let headerHeight: CGFloat = 28
    private let gridStartHour: Int = 7
    private let gridEndHour: Int = 20
    private var totalHours: Int { gridEndHour - gridStartHour }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            typeSelector
            if hSizeClass == .compact {
                compactGrid
            } else {
                fullGrid
            }
        }
    }

    // MARK: Type selector

    private var typeSelector: some View {
        HStack(spacing: 6) {
            ForEach(AvailabilitySlot.SlotType.allCases, id: \.self) { type in
                TypeSelectorButton(slotType: type, isSelected: selectedType == type) {
                    selectedType = type
                }
            }
        }
    }

    // MARK: Full (regular width) grid

    private var fullGrid: some View {
        HStack(alignment: .top, spacing: 0) {
            timeLabelsView(topOffset: headerHeight)
            gridSeparator(height: headerHeight + columnHeight)
            ForEach(0..<7, id: \.self) { day in
                DayAvailabilityColumn(
                    dayIndex: day,
                    dayShort: days[day],
                    daySlots: slots.filter { $0.dayOfWeek == day },
                    selectedType: selectedType,
                    columnHeight: columnHeight,
                    gridStartHour: gridStartHour,
                    totalHours: totalHours,
                    showHeader: true,
                    onAdd: { s, e, t in addSlot(day: day, start: s, end: e, type: t) },
                    onDelete: { modelContext.delete($0) },
                    onClearDay: { clearDay(day) }
                )
                if day < 6 { columnSeparator(height: headerHeight + columnHeight) }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Compact (single-day) grid

    private var compactGrid: some View {
        VStack(spacing: 0) {
            compactDayNav
            HStack(alignment: .top, spacing: 0) {
                timeLabelsView(topOffset: 0)
                gridSeparator(height: columnHeight)
                DayAvailabilityColumn(
                    dayIndex: visibleDay,
                    dayShort: days[visibleDay],
                    daySlots: slots.filter { $0.dayOfWeek == visibleDay },
                    selectedType: selectedType,
                    columnHeight: columnHeight,
                    gridStartHour: gridStartHour,
                    totalHours: totalHours,
                    showHeader: false,
                    onAdd: { s, e, t in addSlot(day: visibleDay, start: s, end: e, type: t) },
                    onDelete: { modelContext.delete($0) },
                    onClearDay: { clearDay(visibleDay) }
                )
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var compactDayNav: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { visibleDay = max(0, visibleDay - 1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 44, height: headerHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(visibleDay > 0 ? Color.primary : Color.secondary)

            Spacer()

            VStack(spacing: 1) {
                Text(days[visibleDay]).font(.system(size: 13, weight: .semibold))
                let count = slots.filter { $0.dayOfWeek == visibleDay }.count
                if count > 0 {
                    Text("\(count) block\(count == 1 ? "" : "s")")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.18)) { visibleDay = min(6, visibleDay + 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 44, height: headerHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(visibleDay < 6 ? Color.primary : Color.secondary)
        }
        .frame(height: headerHeight)
    }

    // MARK: Shared sub-views

    private func timeLabelsView(topOffset: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.clear.frame(width: 28, height: topOffset + columnHeight)
            ForEach(0...totalHours, id: \.self) { i in
                Text(hourLabel(gridStartHour + i))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, alignment: .trailing)
                    .offset(y: topOffset + CGFloat(i) / CGFloat(totalHours) * columnHeight - 5)
            }
        }
        .frame(width: 28, height: topOffset + columnHeight)
    }

    private func gridSeparator(height: CGFloat) -> some View {
        Rectangle().fill(Color(.separator).opacity(0.5)).frame(width: 0.5, height: height)
    }

    private func columnSeparator(height: CGFloat) -> some View {
        Rectangle().fill(Color(.separator).opacity(0.3)).frame(width: 0.5, height: height)
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 12 { return "12p" }
        return hour < 12 ? "\(hour)a" : "\(hour - 12)p"
    }

    // MARK: Data mutations

    private func mins(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
    }

    private func addSlot(day: Int, start: Date, end: Date, type: AvailabilitySlot.SlotType) {
        let newS = mins(start), newE = mins(end)
        guard newE > newS else { return }

        // Resolve overlaps: trim, split, or delete existing blocks that intersect [start, end]
        let existing = Array(slots.filter { $0.dayOfWeek == day })
        for ex in existing {
            let eS = mins(ex.startTime), eE = mins(ex.endTime)
            if eE <= newS || eS >= newE { continue }          // no overlap

            if eS >= newS && eE <= newE {                     // fully consumed
                modelContext.delete(ex)
            } else if eS < newS && eE > newE {                // new block inside existing: split
                let tailEnd = ex.endTime
                let tailType = ex.slotType
                ex.endTime = start
                modelContext.insert(AvailabilitySlot(dayOfWeek: day, startTime: end, endTime: tailEnd, slotType: tailType))
            } else if eS < newS {                             // existing hangs over left edge
                ex.endTime = start
            } else {                                          // existing hangs over right edge
                ex.startTime = end
            }
        }

        modelContext.insert(AvailabilitySlot(dayOfWeek: day, startTime: start, endTime: end, slotType: type))
    }

    private func clearDay(_ day: Int) {
        slots.filter { $0.dayOfWeek == day }.forEach { modelContext.delete($0) }
    }
}

// MARK: - Day Column

private struct DayAvailabilityColumn: View {
    let dayIndex: Int
    let dayShort: String
    let daySlots: [AvailabilitySlot]
    let selectedType: AvailabilitySlot.SlotType
    let columnHeight: CGFloat
    let gridStartHour: Int
    let totalHours: Int
    let showHeader: Bool
    let onAdd: (Date, Date, AvailabilitySlot.SlotType) -> Void
    let onDelete: (AvailabilitySlot) -> Void
    let onClearDay: () -> Void

    private let headerHeight: CGFloat = 28

    @State private var isDragging = false
    @State private var dragAnchorY: CGFloat? = nil
    @State private var dragCurrentY: CGFloat? = nil

    private var coordinateSpace: String { "strip_\(dayIndex)" }
    private var hasBlocks: Bool { !daySlots.isEmpty }

    private func yToDate(_ y: CGFloat) -> Date {
        let clamped = max(0, min(columnHeight, y))
        let fraction = clamped / columnHeight
        let snapped = round(fraction * CGFloat(totalHours) * 2) / 2  // snap to 0.5 hr
        let hour = gridStartHour + Int(snapped)
        let minute = snapped.truncatingRemainder(dividingBy: 1) > 0 ? 30 : 0
        return Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }

    private func timeToY(_ date: Date) -> CGFloat {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let hoursFromStart = CGFloat(h) + CGFloat(m) / 60 - CGFloat(gridStartHour)
        return max(0, min(columnHeight, hoursFromStart / CGFloat(totalHours) * columnHeight))
    }

    var body: some View {
        VStack(spacing: 0) {
            if showHeader { dayHeader }
            availabilityStrip
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var dayHeader: some View {
        let weight: Font.Weight = hasBlocks ? .semibold : .regular
        let color: Color = hasBlocks ? Color.primary : Color.secondary
        Button { onClearDay() } label: {
            Text(dayShort)
                .font(.system(size: 11, weight: weight))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(height: headerHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var availabilityStrip: some View {
        ZStack(alignment: .topLeading) {
            stripBackground
            hourDividers
            halfHourTicks
            savedBlocks
            dragPreview
        }
        .frame(maxWidth: .infinity, minHeight: columnHeight, maxHeight: columnHeight)
        .clipShape(Rectangle())
        .coordinateSpace(name: coordinateSpace)
        .highPriorityGesture(stripDragGesture)
    }

    @ViewBuilder private var stripBackground: some View {
        Color(UIColor.systemGray6)
    }

    @ViewBuilder private var hourDividers: some View {
        ForEach(1..<totalHours, id: \.self) { h in
            Rectangle()
                .fill(Color(UIColor.separator).opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 0.5)
                .offset(y: CGFloat(h) / CGFloat(totalHours) * columnHeight)
        }
    }

    @ViewBuilder private var halfHourTicks: some View {
        ForEach(Array(stride(from: 1, to: totalHours * 2, by: 2)), id: \.self) { half in
            Rectangle()
                .fill(Color(UIColor.separator).opacity(0.3))
                .frame(maxWidth: .infinity)
                .frame(height: 0.5)
                .offset(y: CGFloat(half) / CGFloat(totalHours * 2) * columnHeight)
        }
    }

    @ViewBuilder private var savedBlocks: some View {
        ForEach(daySlots) { slot in slotBlockView(slot) }
    }

    private func slotBlockView(_ slot: AvailabilitySlot) -> some View {
        let top = timeToY(slot.startTime)
        let blockH = max(timeToY(slot.endTime) - top, 4)
        return RoundedRectangle(cornerRadius: 2)
            .fill(slot.slotType.color.opacity(0.72))
            .frame(maxWidth: .infinity)
            .frame(height: blockH)
            .offset(y: top)
            .padding(.horizontal, 2)
            .onTapGesture { onDelete(slot) }
    }

    @ViewBuilder private var dragPreview: some View {
        if isDragging, let a = dragAnchorY, let c = dragCurrentY {
            dragPreviewBlock(anchorY: a, currentY: c)
        }
    }

    private func dragPreviewBlock(anchorY: CGFloat, currentY: CGFloat) -> some View {
        let top = min(anchorY, currentY)
        let blockH = max(abs(currentY - anchorY), 4)
        return RoundedRectangle(cornerRadius: 2)
            .fill(selectedType.color.opacity(0.35))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(selectedType.color.opacity(0.75), lineWidth: 1))
            .frame(maxWidth: .infinity)
            .frame(height: blockH)
            .offset(y: top)
            .padding(.horizontal, 2)
    }

    private var stripDragGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(coordinateSpace))
            .onChanged { value in
                if !isDragging { isDragging = true; dragAnchorY = value.startLocation.y }
                dragCurrentY = value.location.y
            }
            .onEnded { value in
                if let a = dragAnchorY, let c = dragCurrentY {
                    onAdd(yToDate(min(a, c)), yToDate(max(a, c)), selectedType)
                }
                isDragging = false; dragAnchorY = nil; dragCurrentY = nil
            }
    }
}

// MARK: - Override Edit View

struct AvailabilityOverrideEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var reason = ""
    @State private var isUnavailable = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                Section {
                    TextField("Reason (optional)", text: $reason)
                    Toggle(isOn: $isUnavailable) {
                        Label(
                            isUnavailable ? "Mark Unavailable" : "Mark Available",
                            systemImage: isUnavailable ? "xmark.circle" : "checkmark.circle"
                        )
                    }
                }
            }
            .navigationTitle("Add Override")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        modelContext.insert(AvailabilityOverride(startDate: startDate, endDate: endDate, reason: reason, isUnavailable: isUnavailable))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsViewBooking() }
        .modelContainer(PreviewContainer.shared.container)
}
