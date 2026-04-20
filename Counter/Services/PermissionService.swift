import AVFoundation
import Photos
import SwiftUI

/// Centralises permission checks and requests for camera and photo library access.
@Observable
final class PermissionService {

    static let shared = PermissionService()
    private init() {}

    // MARK: - Camera

    var cameraStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    var isCameraAuthorized: Bool {
        cameraStatus == .authorized
    }

    func requestCamera() async -> Bool {
        switch cameraStatus {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Photo Library

    var photoLibraryStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    var isPhotoLibraryAuthorized: Bool {
        let status = photoLibraryStatus
        return status == .authorized || status == .limited
    }

    func requestPhotoLibrary() async -> Bool {
        switch photoLibraryStatus {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let result = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return result == .authorized || result == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Settings Deep-Link

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Permission Denied Alert Modifier

extension View {
    /// Presents an alert when the user has denied a required permission, directing them to Settings.
    func permissionDeniedAlert(
        isPresented: Binding<Bool>,
        permissionName: String
    ) -> some View {
        alert("\(permissionName) Access Denied", isPresented: isPresented) {
            Button("Open Settings") { PermissionService.shared.openAppSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Counter needs \(permissionName) access to use this feature. Enable it in Settings.")
        }
    }
}
