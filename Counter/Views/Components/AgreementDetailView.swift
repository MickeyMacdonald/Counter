import SwiftUI
import SwiftData

/// View for reviewing a signed agreement, with options to re-sign or export.
struct AgreementDetailView: View {
    @Bindable var agreement: Agreement
    @State private var showingSignature = false
    @State private var signatureImage: UIImage?
    @State private var showingShareSheet = false

    var body: some View {
        List {
            // Status header
            Section {
                HStack {
                    Label(agreement.agreementType.rawValue, systemImage: agreement.agreementType.systemImage)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    if agreement.isSigned {
                        Label("Signed", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    } else {
                        Label("Unsigned", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Agreement text
            Section("Agreement") {
                Text(agreement.bodyText)
                    .font(.body)
            }

            // Signature
            Section("Signature") {
                if let signatureImage {
                    VStack(spacing: 8) {
                        Image(uiImage: signatureImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.primary.opacity(0.03))
                            )

                        if let signedAt = agreement.signedAt {
                            Text("Signed on \(signedAt.formatted(date: .long, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if agreement.isSigned {
                    Text("Signature on file")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        showingSignature = true
                    } label: {
                        Label("Sign Now", systemImage: "pencil.tip.crop.circle")
                            .font(.body.weight(.medium))
                    }
                }
            }

            // Export
            Section("Export") {
                AgreementExportView(agreement: agreement)
            }

            // Meta
            Section {
                LabeledContent("Created", value: agreement.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let signedAt = agreement.signedAt {
                    LabeledContent("Signed", value: signedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(agreement.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !agreement.isSigned {
                    Button {
                        showingSignature = true
                    } label: {
                        Label("Sign", systemImage: "pencil.tip.crop.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSignature) {
            SignatureCaptureView(signatureImage: $signatureImage)
        }
        .onChange(of: signatureImage) { _, newImage in
            guard let newImage else { return }
            saveSignature(newImage)
        }
        .task {
            await loadSignature()
        }
    }

    private func loadSignature() async {
        guard let path = agreement.signatureImagePath else { return }
        if let img = await ImageStorageService.shared.loadImage(relativePath: path) {
            await MainActor.run { signatureImage = img }
        }
    }

    private func saveSignature(_ image: UIImage) {
        Task {
            let clientID = agreement.client?.persistentModelID.hashValue.description ?? "unknown"
            if let path = try? await ImageStorageService.shared.saveImage(
                image,
                clientID: clientID,
                pieceID: "agreements",
                stage: "signatures",
                fileName: "sig_\(UUID().uuidString).png"
            ) {
                await MainActor.run {
                    agreement.signatureImagePath = path
                    agreement.isSigned = true
                    agreement.signedAt = Date()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AgreementDetailView(agreement: Agreement(
            title: "Consent Form",
            agreementType: .consent,
            bodyText: "I consent to receive a tattoo...",
            isSigned: true,
            signedAt: Date()
        ))
    }
    .modelContainer(PreviewContainer.shared.container)
}
