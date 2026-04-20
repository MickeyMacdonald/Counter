import Foundation
import LocalAuthentication
import SwiftUI

/// Manages the "client mode" lock that hides business-sensitive views (Financial, Settings)
/// so the artist can safely hand their device to a client to browse the gallery.
@Observable
final class BusinessLockManager {
    /// Whether business views are currently locked
    var isLocked: Bool = false

    /// Whether the lock feature is enabled in settings
    @ObservationIgnored
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "businessLockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "businessLockEnabled") }
    }

    /// The stored PIN (hashed). Empty means biometric-only.
    @ObservationIgnored
    private var storedPIN: String {
        get { UserDefaults.standard.string(forKey: "businessLockPIN") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "businessLockPIN") }
    }

    /// Whether a PIN has been set
    var hasPIN: Bool {
        !storedPIN.isEmpty
    }

    /// Whether biometrics are available on this device
    var biometricsAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// The type of biometric available (for display purposes)
    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        case .none: "None"
        @unknown default: "Biometrics"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .none: "lock.shield"
        @unknown default: "lock.shield"
        }
    }

    // MARK: - Actions

    /// Lock business views (enter client mode)
    func lock() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isLocked = true
        }
    }

    /// Attempt biometric unlock
    func unlockWithBiometrics() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Use PIN"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock business views"
            )
            if success {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isLocked = false
                    }
                }
            }
            return success
        } catch {
            return false
        }
    }

    /// Attempt PIN unlock
    func unlockWithPIN(_ pin: String) -> Bool {
        if pin == storedPIN {
            withAnimation(.easeInOut(duration: 0.3)) {
                isLocked = false
            }
            return true
        }
        return false
    }

    /// Set a new PIN
    func setPIN(_ pin: String) {
        storedPIN = pin
    }

    /// Remove the PIN
    func clearPIN() {
        storedPIN = ""
    }

    /// Enable the lock feature
    func enable() {
        isEnabled = true
    }

    /// Disable the lock feature and unlock
    func disable() {
        isEnabled = false
        isLocked = false
    }
}
