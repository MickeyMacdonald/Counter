import SwiftUI
import SwiftData

// MARK: - Token Descriptors

/// All available smart block tokens with metadata for the editor toolbar.
enum TemplateToken: String, CaseIterable {
    // Client
    case clientFirst    = "{{CLIENT_FIRST}}"
    case clientName     = "{{CLIENT_NAME}}"
    case clientEmail    = "{{CLIENT_EMAIL}}"
    case clientPhone    = "{{CLIENT_PHONE}}"
    // Piece
    case pieceName      = "{{PIECE_NAME}}"
    case piecePlacement = "{{PIECE_PLACEMENT}}"
    case sessionDate    = "{{SESSION_DATE}}"
    // Artist
    case artistName     = "{{ARTIST_NAME}}"
    case artistSig      = "{{ARTIST_SIGNATURE}}"
    // Images (auto-attach on send)
    case piecePhoto         = "{{PIECE_PHOTO}}"
    case lastSessionPhoto   = "{{LAST_SESSION_PHOTO}}"
    case lastLineartPhoto   = "{{LAST_LINEART_PHOTO}}"
    // Misc
    case currentYear    = "{{CURRENT_YEAR}}"

    var label: String {
        switch self {
        case .clientFirst:        "First Name"
        case .clientName:         "Full Name"
        case .clientEmail:        "Client Email"
        case .clientPhone:        "Client Phone"
        case .pieceName:          "Piece Name"
        case .piecePlacement:     "Placement"
        case .sessionDate:        "Session Date"
        case .artistName:         "Artist Name"
        case .artistSig:          "Signature"
        case .piecePhoto:         "Piece Photo"
        case .lastSessionPhoto:   "Last Session"
        case .lastLineartPhoto:   "Lineart"
        case .currentYear:        "Year"
        }
    }

    var systemImage: String {
        switch self {
        case .clientFirst, .clientName: "person.fill"
        case .clientEmail:              "envelope.fill"
        case .clientPhone:              "phone.fill"
        case .pieceName:                "photo.on.rectangle.angled"
        case .piecePlacement:           "mappin"
        case .sessionDate:              "calendar"
        case .artistName:               "paintbrush.pointed.fill"
        case .artistSig:                "signature"
        case .piecePhoto:               "photo.fill"
        case .lastSessionPhoto:         "camera.fill"
        case .lastLineartPhoto:         "pencil.and.outline"
        case .currentYear:              "number.circle"
        }
    }

    /// True for tokens that trigger automatic photo attachment at send time.
    var isImageToken: Bool {
        switch self {
        case .piecePhoto, .lastSessionPhoto, .lastLineartPhoto: true
        default: false
        }
    }
}

// MARK: - Editor View

struct EmailTemplateEditorView: View {
    enum Mode {
        case create
        case edit(CustomEmailTemplate)
        /// Opens a built-in template for customization; saves as a new custom template.
        case fromBuiltIn(EmailTemplate)
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var category: EmailTemplate.TemplateCategory = .custom
    @State private var subject: String = ""
    @State private var bodyText: String = ""

    private enum Field { case subject, body }
    @FocusState private var focusedField: Field?

    private var navigationTitle: String {
        switch mode {
        case .create:        "New Template"
        case .edit:          "Edit Template"
        case .fromBuiltIn:   "Customize Template"
        }
    }

    private var saveLabel: String {
        if case .fromBuiltIn = mode { return "Save as Custom" }
        return "Save"
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !subject.trimmingCharacters(in: .whitespaces).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Template Info
                Section("Template Info") {
                    TextField("Template name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(EmailTemplate.TemplateCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.systemImage).tag(cat)
                        }
                    }
                }

                // MARK: Subject
                Section("Subject Line") {
                    TextField("Email subject", text: $subject)
                        .focused($focusedField, equals: .subject)
                }

                // MARK: Body
                Section("Message Body") {
                    TextEditor(text: $bodyText)
                        .focused($focusedField, equals: .body)
                        .frame(minHeight: 220)
                        .font(.body)
                        .dropDestination(for: String.self) { items, _ in
                            bodyText += items.joined()
                            return true
                        }
                }

                // MARK: Smart Blocks
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(TemplateToken.allCases, id: \.rawValue) { token in
                                TokenChip(token: token) {
                                    insertToken(token.rawValue)
                                }
                                .draggable(token.rawValue)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                    }
                } header: {
                    Text("Smart Blocks")
                } footer: {
                    Text("Tap to insert at end, or drag into the message body. Image blocks auto-attach the photo when sending.")
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveLabel, action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear { loadContent() }
        }
    }

    // MARK: - Actions

    private func loadContent() {
        switch mode {
        case .create:
            break
        case .edit(let template):
            name     = template.name
            category = template.category
            subject  = template.subject
            bodyText = template.body
        case .fromBuiltIn(let template):
            name     = template.name
            category = template.category
            subject  = template.subject
            bodyText = template.body
        }
    }

    private func insertToken(_ token: String) {
        switch focusedField {
        case .subject:
            subject += token
        case .body, .none:
            bodyText += token
        }
    }

    private func save() {
        switch mode {
        case .create, .fromBuiltIn:
            let template = CustomEmailTemplate(
                name: name.trimmingCharacters(in: .whitespaces),
                subject: subject.trimmingCharacters(in: .whitespaces),
                body: bodyText.trimmingCharacters(in: .whitespaces),
                category: category
            )
            modelContext.insert(template)

        case .edit(let template):
            template.name      = name.trimmingCharacters(in: .whitespaces)
            template.subject   = subject.trimmingCharacters(in: .whitespaces)
            template.body      = bodyText.trimmingCharacters(in: .whitespaces)
            template.category  = category
            template.updatedAt = Date()
        }
        dismiss()
    }
}

// MARK: - Token Chip

struct TokenChip: View {
    let token: TemplateToken
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: token.systemImage)
                    .font(.system(size: 15, weight: .medium))
                Text(token.label)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(token.isImageToken ? Color.purple : Color.orange)
            .frame(width: 72, height: 60)
            .background(
                (token.isImageToken ? Color.purple : Color.orange).opacity(0.1),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        (token.isImageToken ? Color.purple : Color.orange).opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EmailTemplateEditorView(mode: .create)
        .modelContainer(PreviewContainer.shared.container)
}
