import MessageUI
import SwiftUI
import SwiftData

// MARK: - Mail Composer

/// Sends emails through the device's native mail client.
/// No server required — uses MFMailComposeViewController.
struct EmailComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    let attachmentImages: [UIImage]
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)

        // Attach images as PNGs
        for (index, image) in attachmentImages.enumerated() {
            if let data = image.pngData() {
                composer.addAttachmentData(
                    data,
                    mimeType: "image/png",
                    fileName: "image_\(index + 1).png"
                )
            }
        }

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onComplete: (Bool) -> Void

        init(onComplete: @escaping (Bool) -> Void) {
            self.onComplete = onComplete
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            let success = result == .sent
            onComplete(success)
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Send Email View

/// Composition sheet — pre-populated from a template and editable before sending.
struct SendEmailView: View {
    let client: Client
    let template: EmailTemplate?
    let piece: Piece?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var subject = ""
    @State private var messageBody = ""
    @State private var showingComposer = false
    @State private var canSendMail = MFMailComposeViewController.canSendMail()
    @State private var selectedImages: [WorkImage] = []

    private var profile: UserProfile? { profiles.first }

    /// All piece images available for attachment.
    private var availableImages: [WorkImage] {
        if let piece {
            return piece.allImages
        }
        return client.pieces.flatMap { $0.allImages }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("To") {
                    LabeledContent("Recipient", value: client.email.isEmpty ? "No email on file" : client.email)
                }

                Section("Subject") {
                    TextField("Email subject", text: $subject)
                }

                Section("Message") {
                    TextEditor(text: $messageBody)
                        .frame(minHeight: 160)
                        .font(.body)
                }

                // Photo attachment — shown when images are available
                if !availableImages.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(availableImages, id: \.filePath) { image in
                                    AttachmentThumbnail(
                                        image: image,
                                        isSelected: selectedImages.contains(where: { $0.filePath == image.filePath })
                                    ) {
                                        toggleImage(image)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        HStack {
                            Text("Attach Photos")
                            Spacer()
                            if !selectedImages.isEmpty {
                                Text("\(selectedImages.count) selected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } footer: {
                        Text("Tap photos to attach them to the email.")
                    }
                }

                // Quick-edit hint
                Section {
                    Label("All fields are editable before sending.", systemImage: "pencil.and.list.clipboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Send Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingComposer = true
                    } label: {
                        Label("Send", systemImage: "paperplane.fill")
                    }
                    .fontWeight(.semibold)
                    .disabled(client.email.isEmpty || !canSendMail)
                }
            }
            .sheet(isPresented: $showingComposer) {
                let attachments = selectedImages.compactMap { img -> UIImage? in
                    guard let url = img.fileURL else { return nil }
                    return UIImage(contentsOfFile: url.path)
                }
                EmailComposerView(
                    recipients: [client.email],
                    subject: subject,
                    body: messageBody,
                    attachmentImages: attachments
                ) { sent in
                    if sent { logCommunication() }
                    dismiss()
                }
            }
            .onAppear {
                populateFromTemplate()
            }
        }
    }

    // MARK: - Template Population

    private func populateFromTemplate() {
        guard let template else {
            subject = ""
            messageBody = ""
            return
        }

        let sessionDate = piece?.sessions.last?.date.formatted(date: .abbreviated, time: .omitted) ?? ""
        let artistName = profile?.fullName ?? "your artist"
        let artistSignature = buildSignature()

        let rendered = template.rendered(
            clientName: client.fullName,
            clientEmail: client.email,
            clientPhone: client.phone,
            artistName: artistName,
            artistSignature: artistSignature,
            pieceName: piece?.title ?? "",
            piecePlacement: piece?.bodyPlacement ?? "",
            sessionDate: sessionDate
        )

        subject = rendered.subject
        messageBody = rendered.body

        resolveImageTokens()
    }

    /// Auto-selects photos and replaces image tokens with a placeholder.
    private func resolveImageTokens() {
        guard let piece else { return }

        // {{LAST_SESSION_PHOTO}} — most recent session's first work photo
        if messageBody.contains("{{LAST_SESSION_PHOTO}}") {
            let photo = piece.sessions
                .sorted { $0.date > $1.date }
                .first?
                .sessionProgress
                .flatMap { $0.images }
                .first
            if let photo, !selectedImages.contains(where: { $0.filePath == photo.filePath }) {
                selectedImages.append(photo)
            }
            messageBody = messageBody.replacingOccurrences(
                of: "{{LAST_SESSION_PHOTO}}",
                with: photo != nil ? "[see attached photo]" : ""
            )
        }

        // {{LAST_LINEART_PHOTO}} — most recent lineart stage photo
        if messageBody.contains("{{LAST_LINEART_PHOTO}}") {
            let photo = piece.sessions
                .flatMap { $0.sessionProgress }
                .filter { $0.stage == .lineart }
                .sorted { $0.createdAt > $1.createdAt }
                .first?
                .images
                .first
            if let photo, !selectedImages.contains(where: { $0.filePath == photo.filePath }) {
                selectedImages.append(photo)
            }
            messageBody = messageBody.replacingOccurrences(
                of: "{{LAST_LINEART_PHOTO}}",
                with: photo != nil ? "[see attached lineart]" : ""
            )
        }

        // {{PIECE_PHOTO}} — generic indicator, just remove the token (user picks manually)
        messageBody = messageBody.replacingOccurrences(of: "{{PIECE_PHOTO}}", with: "")
    }

    /// Builds a multi-line artist signature from the user profile.
    private func buildSignature() -> String {
        guard let profile else { return "your artist" }
        var lines: [String] = [profile.fullName]
        if !profile.businessName.isEmpty { lines.append(profile.businessName) }
        var contact: [String] = []
        if !profile.email.isEmpty { contact.append(profile.email) }
        if !profile.phone.isEmpty { contact.append(profile.phone) }
        if !contact.isEmpty { lines.append(contact.joined(separator: " | ")) }
        return lines.joined(separator: "\n")
    }

    // MARK: - Photo Selection

    private func toggleImage(_ image: WorkImage) {
        if let idx = selectedImages.firstIndex(where: { $0.filePath == image.filePath }) {
            selectedImages.remove(at: idx)
        } else {
            selectedImages.append(image)
        }
    }

    // MARK: - Communication Log

    private func logCommunication() {
        let log = CommunicationLog(
            commType: .email,
            subject: subject,
            bodyText: messageBody,
            wasAutoGenerated: template != nil
        )
        log.client = client
        modelContext.insert(log)
        client.updatedAt = Date()
    }
}

// MARK: - Attachment Thumbnail

private struct AttachmentThumbnail: View {
    let image: WorkImage
    let isSelected: Bool
    let onTap: () -> Void

    @State private var uiImage: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let uiImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.primary.opacity(0.08)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, Color.accentColor)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            if let url = image.fileURL {
                uiImage = UIImage(contentsOfFile: url.path)
            }
        }
    }
}

// MARK: - Template Picker

/// Presents built-in and custom templates then leads into the email composer.
struct EmailTemplatePickerView: View {
    let client: Client
    let piece: Piece?

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedEmailTemplate.name) private var customTemplates: [SavedEmailTemplate]

    @State private var selectedTemplate: EmailTemplate?
    @State private var showingSendView = false
    @State private var editingCustomTemplate: SavedEmailTemplate?

    var body: some View {
        NavigationStack {
            List {
                // Blank email
                Section {
                    Button {
                        selectedTemplate = nil
                        showingSendView = true
                    } label: {
                        Label("Blank Email", systemImage: "envelope")
                            .font(.body.weight(.medium))
                    }
                }

                // My Templates
                if !customTemplates.isEmpty {
                    Section("My Templates") {
                        ForEach(customTemplates) { custom in
                            HStack {
                                Button {
                                    selectedTemplate = custom.asEmailTemplate()
                                    showingSendView = true
                                } label: {
                                    PickerTemplateRow(
                                        name: custom.name,
                                        subject: custom.subject,
                                        category: custom.category
                                    )
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button {
                                    editingCustomTemplate = custom
                                } label: {
                                    Image(systemName: "pencil.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Built-in templates grouped by category
                ForEach(EmailTemplate.TemplateCategory.allCases, id: \.self) { category in
                    let templates = EmailTemplates.templates(for: category)
                    if !templates.isEmpty {
                        Section(category.rawValue) {
                            ForEach(templates, id: \.id) { template in
                                Button {
                                    selectedTemplate = template
                                    showingSendView = true
                                } label: {
                                    PickerTemplateRow(
                                        name: template.name,
                                        subject: template.subject,
                                        category: template.category
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Email Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSendView) {
                SendEmailView(
                    client: client,
                    template: selectedTemplate,
                    piece: piece
                )
            }
            .sheet(item: $editingCustomTemplate) { template in
                SettingsViewEmailTemplateEditor(mode: .edit(template))
            }
        }
    }
}

// MARK: - Picker Template Row

private struct PickerTemplateRow: View {
    let name: String
    let subject: String
    let category: EmailTemplate.TemplateCategory

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(subject)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: category.systemImage)
        }
    }
}

#Preview {
    EmailTemplatePickerView(
        client: Client(firstName: "Alex", lastName: "Rivera", email: "alex@example.com"),
        piece: nil
    )
    .modelContainer(PreviewContainer.shared.container)
}
