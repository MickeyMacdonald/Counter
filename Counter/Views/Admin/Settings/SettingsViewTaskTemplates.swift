import SwiftUI
import SwiftData

struct SettingsViewTaskTemplates: View {
    @Query(sort: \BookingTaskTemplate.sortOrder) private var allTemplates: [BookingTaskTemplate]
    @Environment(\.modelContext) private var modelContext

    @State private var addingForType: BookingType? = nil
    @State private var newLabel = ""

    var body: some View {
        List {
            ForEach(BookingType.allCases, id: \.self) { type in
                let typeTemplates = templates(for: type)
                Section {
                    ForEach(typeTemplates) { template in
                        TemplateRow(template: template)
                    }
                    .onDelete { offsets in deleteTemplates(offsets, in: typeTemplates) }
                    .onMove  { from, to in moveTemplates(from, to, in: typeTemplates) }

                    if addingForType == type {
                        HStack {
                            TextField("Task label…", text: $newLabel)
                                .onSubmit { commitNew(for: type, templates: typeTemplates) }
                            Button("Add") { commitNew(for: type, templates: typeTemplates) }
                                .disabled(newLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        Button {
                            addingForType = type
                            newLabel = ""
                        } label: {
                            Label("Add Task", systemImage: "plus.circle")
                                .foregroundStyle(type.color)
                        }
                    }
                } header: {
                    Label(type.rawValue, systemImage: type.systemImage)
                        .foregroundStyle(type.color)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Task Templates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }

    // MARK: - Helpers

    private func templates(for type: BookingType) -> [BookingTaskTemplate] {
        allTemplates.filter { $0.bookingType == type }
    }

    private func commitNew(for type: BookingType, templates: [BookingTaskTemplate]) {
        let label = newLabel.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        let next = (templates.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(BookingTaskTemplate(label: label, bookingType: type, sortOrder: next))
        newLabel = ""
        addingForType = nil
    }

    private func deleteTemplates(_ offsets: IndexSet, in subset: [BookingTaskTemplate]) {
        for i in offsets { modelContext.delete(subset[i]) }
    }

    private func moveTemplates(_ from: IndexSet, _ to: Int, in subset: [BookingTaskTemplate]) {
        var reordered = subset
        reordered.move(fromOffsets: from, toOffset: to)
        for (i, template) in reordered.enumerated() { template.sortOrder = i }
    }
}

// MARK: - Template Row

private struct TemplateRow: View {
    @Bindable var template: BookingTaskTemplate

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $template.isEnabled)
                .labelsHidden()
                .tint(template.bookingType.color)
            TextField("Label", text: $template.label)
                .foregroundStyle(template.isEnabled ? .primary : .secondary)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsViewTaskTemplates()
    }
    .modelContainer(PreviewContainer.shared.container)
}
