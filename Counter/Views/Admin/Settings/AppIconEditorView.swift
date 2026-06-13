import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

private struct ImportedAppIconImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw AppIconImageImportError.invalidData
            }
            return ImportedAppIconImage(image: image)
        }
        DataRepresentation(importedContentType: .png) { data in
            guard let image = UIImage(data: data) else {
                throw AppIconImageImportError.invalidData
            }
            return ImportedAppIconImage(image: image)
        }
        DataRepresentation(importedContentType: .jpeg) { data in
            guard let image = UIImage(data: data) else {
                throw AppIconImageImportError.invalidData
            }
            return ImportedAppIconImage(image: image)
        }
    }
}

private enum AppIconImageImportError: Error {
    case invalidData
}

struct AppIconEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = "My Icon"
    @State private var backgroundTop = Color(white: 0.92)
    @State private var backgroundBottom = Color(white: 0.72)
    @State private var usesGradient = true
    @State private var logoColor = Color.black
    @State private var customLogoImage: UIImage?
    @State private var customLogoScalePercent: Double = 100
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onSaved: () -> Void

    private var style: AppIconRenderer.Style {
        AppIconRenderer.Style(
            backgroundTop: backgroundTop,
            backgroundBottom: backgroundBottom,
            usesGradient: usesGradient,
            logoColor: logoColor,
            customLogoImage: customLogoImage,
            customLogoScale: CGFloat(customLogoScalePercent / 100)
        )
    }

    private var previewToken: Int {
        var hasher = Hasher()
        hasher.combine(backgroundTop.hexString)
        hasher.combine(backgroundBottom.hexString)
        hasher.combine(usesGradient)
        hasher.combine(logoColor.hexString)
        hasher.combine(customLogoScalePercent)
        hasher.combine(customLogoImage?.pngData())
        return hasher.finalize()
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    AppIconCanvas(style: style, applySquircleMask: true, size: 120)
                        .id(previewToken)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    Spacer()
                }
                .frame(minHeight: 132)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
            }

            Section("Name") {
                TextField("Icon name", text: $name)
            }

            Section("Background") {
                Toggle("Gradient", isOn: $usesGradient)
                ColorPicker("Top color", selection: $backgroundTop, supportsOpacity: false)
                if usesGradient {
                    ColorPicker("Bottom color", selection: $backgroundBottom, supportsOpacity: false)
                }
            }

            Section("Logo") {
                if customLogoImage == nil {
                    ColorPicker("Logo color", selection: $logoColor, supportsOpacity: false)
                } else if let customLogoImage {
                    HStack(spacing: 12) {
                        Image(uiImage: customLogoImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("Custom logo selected")
                            .foregroundStyle(.secondary)
                    }
                }

                if customLogoImage != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Logo size")
                            Spacer()
                            Text("\(Int(customLogoScalePercent))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $customLogoScalePercent, in: 0...200, step: 1)
                    }
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(
                        customLogoImage == nil ? "Upload PNG Logo" : "Replace PNG Logo",
                        systemImage: "photo.on.rectangle.angled"
                    )
                }

                if customLogoImage != nil {
                    Button("Use Counter Logo", role: .destructive) {
                        customLogoImage = nil
                        customLogoScalePercent = 100
                        selectedPhotoItem = nil
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("New Icon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .overlay {
            if isSaving {
                ProgressView("Saving icon…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task { @MainActor in await loadSelectedPhoto(from: item) }
        }
    }

    @MainActor
    private func loadSelectedPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            let imported = try await item.loadTransferable(type: ImportedAppIconImage.self)
            customLogoImage = imported?.image
            customLogoScalePercent = 100
            errorMessage = nil
        } catch {
            errorMessage = "Could not load the selected image."
        }
    }

    private func save() {
        errorMessage = nil
        isSaving = true

        Task { @MainActor in
            defer { isSaving = false }
            do {
                _ = try await AppIconStore.shared.saveCustomIcon(
                    name: name,
                    backgroundTop: backgroundTop,
                    backgroundBottom: backgroundBottom,
                    usesGradient: usesGradient,
                    logoColor: logoColor,
                    customLogo: customLogoImage,
                    customLogoScale: CGFloat(customLogoScalePercent / 100)
                )
                onSaved()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        AppIconEditorView(onSaved: {})
    }
}
