import SwiftUI
import SwiftData

// Make EmailTemplate usable with .sheet(item:)
extension EmailTemplate: Identifiable {}

struct SettingsViewEmailTemplates: View {
    @Query(sort: \CustomEmailTemplate.name) private var customTemplates: [CustomEmailTemplate]
    @Environment(\.modelContext) private var modelContext

    @State private var showingNewTemplate = false
    @State private var editingTemplate: CustomEmailTemplate?
    @State private var customizingBuiltIn: EmailTemplate?

    var body: some View {
        List {
            // MARK: My Templates
            Section {
                if customTemplates.isEmpty {
                    ContentUnavailableView {
                        Label("No Custom Templates", systemImage: "envelope.badge")
                    } description: {
                        Text("Tap + to create your first template.")
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(customTemplates) { template in
                        Button {
                            editingTemplate = template
                        } label: {
                            TemplateListRow(
                                name: template.name,
                                subject: template.subject,
                                category: template.category,
                                isCustom: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            modelContext.delete(customTemplates[offset])
                        }
                    }
                }
            } header: {
                Text("My Templates")
            }

            // MARK: Built-In Templates
            ForEach(EmailTemplate.TemplateCategory.allCases, id: \.self) { category in
                let templates = EmailTemplates.templates(for: category)
                if !templates.isEmpty {
                    Section(category.rawValue) {
                        ForEach(templates, id: \.id) { template in
                            Button {
                                customizingBuiltIn = template
                            } label: {
                                TemplateListRow(
                                    name: template.name,
                                    subject: template.subject,
                                    category: template.category,
                                    isCustom: false
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Email Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewTemplate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTemplate) {
            EmailTemplateEditorView(mode: .create)
        }
        .sheet(item: $editingTemplate) { template in
            EmailTemplateEditorView(mode: .edit(template))
        }
        .sheet(item: $customizingBuiltIn) { template in
            EmailTemplateEditorView(mode: .fromBuiltIn(template))
        }
    }
}

// MARK: - Template List Row

private struct TemplateListRow: View {
    let name: String
    let subject: String
    let category: EmailTemplate.TemplateCategory
    let isCustom: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.systemImage)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.body)
                    if isCustom {
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(subject)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: isCustom ? "chevron.right" : "wand.and.stars")
                .font(.caption)
                .foregroundStyle(isCustom ? Color.secondary.opacity(0.4) : Color.orange.opacity(0.6))
        }
        .padding(.vertical, 2)
    }
}


#Preview {
    NavigationStack {
        SettingsViewEmailTemplates()
    }
    .modelContainer(PreviewContainer.shared.container)
}
