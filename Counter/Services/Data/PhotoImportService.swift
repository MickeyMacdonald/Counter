import SwiftUI
import PhotosUI

/// Wraps PhotosPicker and camera capture into a unified import flow.
/// Navigates to a metadata step within the same sheet before calling onImport.
struct PhotoImportPicker: View {
    @Binding var isPresented: Bool
    let onImport: ([UIImage], ImageCategory) -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var showingFilePicker = false
    @State private var showingCameraPermissionAlert = false
    @State private var showingLibraryPermissionAlert = false
    @State private var pendingImages: [UIImage] = []
    @State private var showingMetadata = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    Task {
                        let granted = await PermissionService.shared.requestCamera()
                        if granted {
                            showingCamera = true
                        } else {
                            showingCameraPermissionAlert = true
                        }
                    }
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .font(.body.weight(.medium))
                }

                Button {
                    Task {
                        let granted = await PermissionService.shared.requestPhotoLibrary()
                        if granted {
                            showingLibrary = true
                        } else {
                            showingLibraryPermissionAlert = true
                        }
                    }
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .font(.body.weight(.medium))
                }

                Button {
                    showingFilePicker = true
                } label: {
                    Label("Import File", systemImage: "folder")
                        .font(.body.weight(.medium))
                }
            }
            .navigationTitle("Add Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView("Loading…")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .navigationDestination(isPresented: $showingMetadata) {
                PhotoImportMetadataView(images: pendingImages) { category in
                    onImport(pendingImages, category)
                    isPresented = false
                }
            }
        }
        .photosPicker(
            isPresented: $showingLibrary,
            selection: $selectedItems,
            maxSelectionCount: 20,
            matching: .images
        )
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            if !pendingImages.isEmpty { showingMetadata = true }
        }) {
            CameraCapture { image in
                if let image { pendingImages = [image] }
                showingCamera = false
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await MainActor.run { isLoading = true }
                var images: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                await MainActor.run {
                    selectedItems = []
                    isLoading = false
                    if !images.isEmpty {
                        pendingImages = images
                        showingMetadata = true
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .png, .jpeg, .tiff],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            Task {
                await MainActor.run { isLoading = true }
                var images: [UIImage] = []
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                await MainActor.run {
                    isLoading = false
                    if !images.isEmpty {
                        pendingImages = images
                        showingMetadata = true
                    }
                }
            }
        }
        .permissionDeniedAlert(isPresented: $showingCameraPermissionAlert, permissionName: "Camera")
        .permissionDeniedAlert(isPresented: $showingLibraryPermissionAlert, permissionName: "Photo Library")
    }
}

// MARK: - UIKit camera wrapper

struct CameraCapture: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void
        init(onCapture: @escaping (UIImage?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onCapture(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}
