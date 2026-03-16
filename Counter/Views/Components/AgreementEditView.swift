import SwiftUI
import SwiftData

/// Create or edit an agreement/consent form for a client.
/// Supports template selection, custom text, and signature capture.
struct AgreementEditView: View {
    enum Mode {
        case create(client: Client)
        case edit(Agreement)
    }

    let mode: Mode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var agreementType: AgreementType = .consent
    @State private var bodyText = ""
    @State private var showingSignature = false
    @State private var signatureImage: UIImage?
    @State private var isSigned = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Agreement Type") {
                    Picker("Type", selection: $agreementType) {
                        ForEach(AgreementType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }
                    .onChange(of: agreementType) { _, newType in
                        if title.isEmpty || AgreementType.allCases.map(\.rawValue).contains(title) {
                            title = newType.rawValue
                        }
                        if bodyText.isEmpty {
                            bodyText = templateText(for: newType)
                        }
                    }
                }

                Section("Title") {
                    TextField("Agreement title", text: $title)
                }

                Section("Agreement Text") {
                    TextField("Full agreement text...", text: $bodyText, axis: .vertical)
                        .lineLimit(6...20)
                }

                Section("Signature") {
                    if let signatureImage {
                        VStack(spacing: 8) {
                            Image(uiImage: signatureImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.primary.opacity(0.03))
                                )

                            HStack {
                                Label("Signed", systemImage: "checkmark.seal.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)

                                Spacer()

                                Button("Re-sign") {
                                    showingSignature = true
                                }
                                .font(.caption)
                            }
                        }
                    } else {
                        Button {
                            showingSignature = true
                        } label: {
                            Label("Capture Signature", systemImage: "pencil.tip.crop.circle")
                                .font(.body.weight(.medium))
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Agreement" : "New Agreement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingSignature) {
                SignatureCaptureView(signatureImage: $signatureImage)
            }
            .onAppear {
                loadExistingData()
                if !isEditing && title.isEmpty {
                    title = agreementType.rawValue
                    bodyText = templateText(for: agreementType)
                }
            }
        }
    }

    private func loadExistingData() {
        guard case .edit(let agreement) = mode else { return }
        title = agreement.title
        agreementType = agreement.agreementType
        bodyText = agreement.bodyText
        isSigned = agreement.isSigned

        // Load existing signature image if available
        if let path = agreement.signatureImagePath {
            Task {
                if let img = await ImageStorageService.shared.loadImage(relativePath: path) {
                    await MainActor.run { signatureImage = img }
                }
            }
        }
    }

    private func save() {
        Task {
            var signaturePath: String?

            // Save signature image if present
            if let signatureImage {
                let clientID: String
                switch mode {
                case .create(let client):
                    clientID = client.persistentModelID.hashValue.description
                case .edit(let agreement):
                    clientID = agreement.client?.persistentModelID.hashValue.description ?? "unknown"
                }

                signaturePath = try? await ImageStorageService.shared.saveImage(
                    signatureImage,
                    clientID: clientID,
                    pieceID: "agreements",
                    stage: "signatures",
                    fileName: "sig_\(UUID().uuidString).png"
                )
            }

            await MainActor.run {
                switch mode {
                case .create(let client):
                    let agreement = Agreement(
                        title: title.trimmed,
                        agreementType: agreementType,
                        bodyText: bodyText.trimmed,
                        isSigned: signatureImage != nil,
                        signedAt: signatureImage != nil ? Date() : nil,
                        signatureImagePath: signaturePath
                    )
                    agreement.client = client
                    modelContext.insert(agreement)
                    client.updatedAt = Date()

                case .edit(let agreement):
                    agreement.title = title.trimmed
                    agreement.agreementType = agreementType
                    agreement.bodyText = bodyText.trimmed
                    if signatureImage != nil && !agreement.isSigned {
                        agreement.isSigned = true
                        agreement.signedAt = Date()
                    }
                    if let signaturePath {
                        agreement.signatureImagePath = signaturePath
                    }
                }

                dismiss()
            }
        }
    }

    private func templateText(for type: AgreementType) -> String {
        switch type {
        case .consent:
            return "I, the undersigned, hereby consent to receive a tattoo as described and discussed with my tattoo artist. I confirm that I am at least 18 years of age, I am not under the influence of alcohol or drugs, and I have disclosed any relevant medical conditions or allergies."
        case .liability:
            return "I understand that tattooing involves inherent risks including but not limited to infection, allergic reaction, and scarring. I assume full responsibility for any complications that may arise and release the artist from liability for any adverse reactions."
        case .photoRelease:
            return "I grant permission for photographs of my tattoo to be used for the artist's portfolio, social media, and promotional purposes. I understand that my identity may be kept anonymous upon request."
        case .designApproval:
            return "I have reviewed and approve the final design as presented. I understand that once tattooing begins, changes to the design may not be possible."
        case .healedConfirmation:
            return "I confirm that my tattoo has healed satisfactorily and I am pleased with the final result. I understand that any touch-up requests should be made within the agreed timeframe."
        case .custom:
            return ""
        }
    }
}

#Preview {
    AgreementEditView(mode: .create(client: Client(firstName: "Test", lastName: "Client")))
        .modelContainer(PreviewContainer.shared.container)
}
