import SwiftUI
import PhotosUI

/// Wraps PhotosPicker and camera capture into a unified import flow.
/// Returns UIImage instances ready to be saved via ImageStorageService.
struct PhotoImportPicker: View {
    @Binding var isPresented: Bool
    let onImport: ([UIImage]) -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingSourcePicker = true

    var body: some View {
        Group {
            if showingSourcePicker {
                sourcePickerSheet
            }
        }
        .photosPicker(
            isPresented: $showingLibrary,
            selection: $selectedItems,
            maxSelectionCount: 20,
            matching: .images
        )
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCapture { image in
                if let image {
                    onImport([image])
                }
                showingCamera = false
                isPresented = false
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                var images: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                if !images.isEmpty {
                    onImport(images)
                }
                selectedItems = []
                isPresented = false
            }
        }
    }

    @State private var showingLibrary = false

    private var sourcePickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    showingSourcePicker = false
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .font(.body.weight(.medium))
                }

                Button {
                    showingSourcePicker = false
                    showingLibrary = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .font(.body.weight(.medium))
                }

                Button {
                    showingSourcePicker = false
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
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .png, .jpeg, .tiff],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                var images: [UIImage] = []
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                if !images.isEmpty {
                    onImport(images)
                }
            case .failure:
                break
            }
            isPresented = false
        }
    }

    @State private var showingFilePicker = false
}

/// UIKit camera wrapper for SwiftUI
struct CameraCapture: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void

        init(onCapture: @escaping (UIImage?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}
