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
    // Artist
    case artistName     = "{{ARTIST_NAME}}"
    case artistSig      = "{{ARTIST_SIGNATURE}}"
    // Misc
    case sessionDate    = "{{SESSION_DATE}}"
    case currentYear    = "{{CURRENT_YEAR}}"
    // Images (auto-attach on send) — kept last
    case piecePhoto         = "{{PIECE_PHOTO}}"
    case lastSessionPhoto   = "{{LAST_SESSION_PHOTO}}"
    case lastLineartPhoto   = "{{LAST_LINEART_PHOTO}}"

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

struct SettingsViewEmailTemplateEditor: View {
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
    @State private var editingSubject = false
    @State private var editingBody = false

    // Cursor positions for insert-at-cursor
    @State private var subjectCursor: Int?
    @State private var bodyCursor: Int?

    // Send flow
    @State private var showSendAllConfirmation = false
    @State private var showClientPicker = false

    @Query private var allClients: [Client]
    private var optedInClients: [Client] {
        allClients.filter { $0.emailOptIn && !$0.email.trimmingCharacters(in: .whitespaces).isEmpty && !$0.isFlashPortfolioClient }
    }

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

    private var showsSendSection: Bool {
        switch mode {
        case .create:
            return category == .customGeneral
        case .edit(let template):
            return template.category == .customGeneral || category == .customGeneral
        case .fromBuiltIn(let template):
            return template.id == "flash_drop"
        }
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
                Section {
                    if editingSubject {
                        InlineSmartBlocksGrid { token in
                            insertAtCursor(token.rawValue, into: &subject, cursor: &subjectCursor)
                        }
                        CursorTrackingTextField(text: $subject, cursorPosition: $subjectCursor, placeholder: "Email subject")
                            .focused($focusedField, equals: .subject)
                    } else {
                        TokenRenderedInline(text: subject, placeholder: "Email subject")
                    }
                } header: {
                    HStack {
                        Text("Subject Line")
                        Spacer()
                        Button(editingSubject ? "Done" : "Edit") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                editingSubject.toggle()
                            }
                            if editingSubject {
                                editingBody = false
                                focusedField = .subject
                            } else {
                                focusedField = nil
                            }
                        }
                        .font(.subheadline)
                        .textCase(nil)
                    }
                }

                // MARK: Body
                Section {
                    if editingBody {
                        InlineSmartBlocksGrid { token in
                            insertAtCursor(token.rawValue, into: &bodyText, cursor: &bodyCursor)
                        }
                        CursorTrackingTextEditor(text: $bodyText, cursorPosition: $bodyCursor)
                            .focused($focusedField, equals: .body)
                            .frame(minHeight: 220)
                    } else {
                        TokenRenderedBody(text: bodyText)
                            .frame(minHeight: 220, alignment: .topLeading)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                } header: {
                    HStack {
                        Text("Message Body")
                        Spacer()
                        Button(editingBody ? "Done" : "Edit") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                editingBody.toggle()
                            }
                            if editingBody {
                                editingSubject = false
                                focusedField = .body
                            } else {
                                focusedField = nil
                            }
                        }
                        .font(.subheadline)
                        .textCase(nil)
                    }
                }

                // MARK: Send
                if showsSendSection {
                    Section {
                        Button {
                            showClientPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                Text("Send to Specific Clients")
                            }
                        }
                        .disabled(!canSave || optedInClients.isEmpty)

                        Button(role: .destructive) {
                            showSendAllConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Send to All Clients")
                                Spacer()
                                Text("\(optedInClients.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(!canSave || optedInClients.isEmpty)
                    } header: {
                        Text("Send")
                    } footer: {
                        Text("Only clients with an email address and \"Email List Opt-In\" enabled will be included. \(optedInClients.count) client\(optedInClients.count == 1 ? "" : "s") eligible.")
                    }
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
            .confirmationDialog(
                "Send to All Clients",
                isPresented: $showSendAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Send to \(optedInClients.count) Client\(optedInClients.count == 1 ? "" : "s")") {
                    sendToClients(optedInClients)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will open a mail draft to all \(optedInClients.count) opted-in client\(optedInClients.count == 1 ? "" : "s"). Clients without an email or who have not opted in will not be included.")
            }
            .sheet(isPresented: $showClientPicker) {
                ClientPickerSheet(clients: optedInClients) { selected in
                    sendToClients(selected)
                }
            }
            .sheet(isPresented: $showMailComposer) {
                EmailComposerView(
                    recipients: mailRecipients,
                    subject: mailSubject,
                    body: mailBody,
                    attachmentImages: []
                ) { _ in
                    showMailComposer = false
                }
            }
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

    private func insertAtCursor(_ token: String, into text: inout String, cursor: inout Int?) {
        let pos = cursor ?? text.count
        let clamped = min(pos, text.count)
        let index = text.index(text.startIndex, offsetBy: clamped)
        text.insert(contentsOf: token, at: index)
        cursor = clamped + token.count
    }

    @State private var mailRecipients: [String] = []
    @State private var mailSubject: String = ""
    @State private var mailBody: String = ""
    @State private var showMailComposer = false

    private func sendToClients(_ clients: [Client]) {
        mailRecipients = clients.map { $0.email }
        mailSubject = subject
        mailBody = bodyText
        showMailComposer = true
    }
}

// MARK: - Client Picker Sheet

private struct ClientPickerSheet: View {
    let clients: [Client]
    let onSend: ([Client]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<ObjectIdentifier> = []

    private var selectedClients: [Client] {
        clients.filter { selectedIDs.contains(ObjectIdentifier($0)) }
    }

    var body: some View {
        NavigationStack {
            List(clients, id: \.self) { client in
                Button {
                    let id = ObjectIdentifier(client)
                    if selectedIDs.contains(id) {
                        selectedIDs.remove(id)
                    } else {
                        selectedIDs.insert(id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(client.fullName)
                                .font(.body)
                            Text(client.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedIDs.contains(ObjectIdentifier(client)) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
            .navigationTitle("Select Clients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send (\(selectedClients.count))") {
                        dismiss()
                        onSend(selectedClients)
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedClients.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button("Select All") {
                            selectedIDs = Set(clients.map { ObjectIdentifier($0) })
                        }
                        Spacer()
                        Button("Deselect All") {
                            selectedIDs.removeAll()
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

// MARK: - Cursor-Tracking UIKit Wrappers

/// A `UITextField` wrapper that reports cursor position back to SwiftUI.
private struct CursorTrackingTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int?
    var placeholder: String = ""

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.font = .preferredFont(forTextStyle: .body)
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text { field.text = text }
        // Restore cursor after token insertion
        if let pos = cursorPosition, let newPos = field.position(from: field.beginningOfDocument, offset: min(pos, text.count)) {
            if field.isFirstResponder {
                field.selectedTextRange = field.textRange(from: newPos, to: newPos)
            }
        }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CursorTrackingTextField
        init(_ parent: CursorTrackingTextField) { self.parent = parent }

        @objc func textChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
            updateCursor(field)
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            updateCursor(textField)
        }

        private func updateCursor(_ field: UITextField) {
            guard let selected = field.selectedTextRange else { return }
            parent.cursorPosition = field.offset(from: field.beginningOfDocument, to: selected.end)
        }
    }
}

/// A `UITextView` wrapper that reports cursor position back to SwiftUI.
private struct CursorTrackingTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = .preferredFont(forTextStyle: .body)
        view.backgroundColor = .clear
        view.delegate = context.coordinator
        view.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text { view.text = text }
        // Restore cursor after token insertion
        if let pos = cursorPosition {
            let clamped = min(pos, text.count)
            let range = NSRange(location: clamped, length: 0)
            if view.isFirstResponder && view.selectedRange != range {
                view.selectedRange = range
            }
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CursorTrackingTextEditor
        init(_ parent: CursorTrackingTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.cursorPosition = textView.selectedRange.location
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.cursorPosition = textView.selectedRange.location
        }
    }
}

// MARK: - Inline Smart Blocks Grid (Accordion)

/// 6-column grid of token chips shown inline within a section when editing.
private struct InlineSmartBlocksGrid: View {
    let onInsert: (TemplateToken) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Smart Blocks")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(TemplateToken.allCases, id: \.rawValue) { token in
                    TokenChip(token: token) {
                        onInsert(token)
                    }
                }
            }

            Text("Tap a block to insert. Image blocks auto-attach when sending.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Token Rendered Inline (Subject Line)

/// Single-line rendered view for the subject field — shows tokens as inline pills.
fileprivate struct TokenRenderedInline: View {
    let text: String
    var placeholder: String = ""

    var body: some View {
        if text.isEmpty {
            Text(placeholder)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            buildText()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func buildText() -> Text {
        var result = Text("")
        var remaining = text[...]

        while let openRange = remaining.range(of: "{{") {
            let before = remaining[remaining.startIndex..<openRange.lowerBound]
            if !before.isEmpty {
                result = result + Text(before).font(.body)
            }

            let afterOpen = remaining[openRange.upperBound...]
            if let closeRange = afterOpen.range(of: "}}") {
                let raw = "{{\(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])}}"
                if let token = TemplateToken(rawValue: raw) {
                    let color: Color = token.isImageToken ? .purple : .orange
                    result = result + Text(" \(Image(systemName: token.systemImage)) \(token.label) ")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(color)
                } else {
                    result = result + Text(raw).font(.body)
                }
                remaining = remaining[closeRange.upperBound...]
            } else {
                result = result + Text(remaining).font(.body)
                remaining = remaining[remaining.endIndex...]
            }
        }

        if !remaining.isEmpty {
            result = result + Text(remaining).font(.body)
        }
        return result
    }
}

// MARK: - Token Rendered Body

/// Displays template body text with {{TOKEN}} placeholders rendered as inline colored text with icons.
/// Uses the same Text-concatenation approach as the subject line, split by paragraphs.
fileprivate struct TokenRenderedBody: View {
    let text: String

    var body: some View {
        if text.isEmpty {
            Text("Tap to start writing…")
                .foregroundStyle(.secondary)
                .font(.body)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                let paragraphs = text.components(separatedBy: "\n")
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    if paragraph.isEmpty {
                        Text(" ").font(.body) // preserve blank lines
                    } else {
                        buildRichText(from: paragraph)
                    }
                }
            }
        }
    }

    private func buildRichText(from line: String) -> Text {
        var result = Text("")
        var remaining = line[...]

        while let openRange = remaining.range(of: "{{") {
            let before = remaining[remaining.startIndex..<openRange.lowerBound]
            if !before.isEmpty {
                result = result + Text(before).font(.body)
            }

            let afterOpen = remaining[openRange.upperBound...]
            if let closeRange = afterOpen.range(of: "}}") {
                let raw = "{{\(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])}}"
                if let token = TemplateToken(rawValue: raw) {
                    let color: Color = token.isImageToken ? .purple : .orange
                    result = result + Text(" \(Image(systemName: token.systemImage)) \(token.label) ")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(color)
                } else {
                    result = result + Text(raw).font(.body)
                }
                remaining = remaining[closeRange.upperBound...]
            } else {
                result = result + Text(remaining).font(.body)
                remaining = remaining[remaining.endIndex...]
            }
        }

        if !remaining.isEmpty {
            result = result + Text(remaining).font(.body)
        }
        return result
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
            .frame(maxWidth: .infinity)
            .frame(height: 60)
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
    SettingsViewEmailTemplateEditor(mode: .create)
        .modelContainer(PreviewContainer.shared.container)
}
