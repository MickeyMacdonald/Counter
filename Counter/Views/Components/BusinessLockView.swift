import SwiftUI

/// Overlay shown when a business tab is locked in client mode.
/// Provides biometric and PIN unlock options.
struct BusinessLockView: View {
    @Environment(BusinessLockManager.self) private var lockManager

    @State private var showingPINEntry = false
    @State private var enteredPIN = ""
    @State private var pinError = false
    @State private var isAuthenticating = false
    @AppStorage("business.authMethod") private var authMethod: String = "auto"

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Lock icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
            }

            Text("Artist Unlock")
                .font(.title2.weight(.bold))

            Text("Client mode is active. Authenticate to access business views.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // Unlock buttons
            VStack(spacing: 12) {
                if lockManager.biometricsAvailable && authMethod != "pin" {
                    Button {
                        authenticateWithBiometrics()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: lockManager.biometricIcon)
                                .font(.title3)
                            Text("Unlock with \(lockManager.biometricName)")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isAuthenticating)
                }

                if lockManager.hasPIN {
                    Button {
                        showingPINEntry = true
                        enteredPIN = ""
                        pinError = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "number.circle")
                                .font(.title3)
                            Text("Enter PIN")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                // Fallback if neither biometrics nor PIN
                if !lockManager.biometricsAvailable && !lockManager.hasPIN {
                    Button {
                        lockManager.disable()
                    } label: {
                        Text("Unlock")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .alert("Enter PIN", isPresented: $showingPINEntry) {
            SecureField("PIN", text: $enteredPIN)
                .keyboardType(.numberPad)

            Button("Cancel", role: .cancel) { }
            Button("Unlock") {
                if !lockManager.unlockWithPIN(enteredPIN) {
                    pinError = true
                }
            }
        } message: {
            if pinError {
                Text("Incorrect PIN. Please try again.")
            } else {
                Text("Enter your business PIN to unlock.")
            }
        }
        .alert("Incorrect PIN", isPresented: $pinError) {
            Button("Try Again") {
                showingPINEntry = true
                enteredPIN = ""
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            // Auto-prompt biometrics when the view appears
            if lockManager.biometricsAvailable && authMethod != "pin" {
                authenticateWithBiometrics()
            }
        }
    }

    private func authenticateWithBiometrics() {
        isAuthenticating = true
        Task {
            _ = await lockManager.unlockWithBiometrics()
            isAuthenticating = false
        }
    }
}

#Preview {
    BusinessLockView()
        .environment(BusinessLockManager())
}
