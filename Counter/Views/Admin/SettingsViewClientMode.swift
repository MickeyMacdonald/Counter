import SwiftUI

// MARK: - Client Mode

struct SettingsClientModeView: View {
    @Environment(BusinessLockManager.self) private var lockManager
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @State private var showingSetPIN = false
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var pinMismatch = false

    @AppStorage("business.autolockOnBackground") private var autoLockOnBackground: Bool = true
    @AppStorage("business.authMethod") private var authMethod: String = "auto" // values: "auto", "pin"
    @AppStorage("business.galleryAllowedSections") private var galleryAllowedSectionsRaw: String = "byStage,byPlacement,bySize"

    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(
                    get: { lockManager.isEnabled },
                    set: { newValue in
                        if newValue {
                            lockManager.enable()
                        } else {
                            lockManager.disable()
                        }
                    }
                )) {
                    Label("Enable Client Mode Lock", systemImage: "lock.shield")
                }

                if lockManager.isEnabled {
                    DisclosureGroup {
                        if lockManager.biometricsAvailable {
                            LabeledContent {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } label: {
                                Label(lockManager.biometricName, systemImage: lockManager.biometricIcon)
                            }
                        }

                        if lockManager.hasPIN {
                            Button(role: .destructive) {
                                lockManager.clearPIN()
                            } label: {
                                Label("Remove PIN", systemImage: "number.circle")
                            }
                        } else {
                            Button {
                                newPIN = ""
                                confirmPIN = ""
                                pinMismatch = false
                                showingSetPIN = true
                            } label: {
                                Label("Set a PIN", systemImage: "number.circle")
                            }
                        }

                        Toggle("Auto-lock on background", isOn: $autoLockOnBackground)

                        Picker("Authentication Method", selection: $authMethod) {
                            Text("Auto (Biometrics if available)").tag("auto")
                            Text("PIN Only").tag("pin")
                        }
                        .pickerStyle(.menu)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Allowed Gallery Sections")
                                .font(.subheadline.weight(.semibold))
                            ForEach(["byStage","byPlacement","bySize","byRating","byClient"], id: \.self) { key in
                                Toggle(labelForGalleryKey(key), isOn: Binding(
                                    get: { allowedGalleryKeys.contains(key) },
                                    set: { on in updateAllowedGalleryKeys(key: key, enabled: on) }
                                ))
                            }
                            Text("These apply only while in Client Mode.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        LabeledContent {
                            Text("Use the Gallery tab banner to enter Client Mode.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("How to Lock", systemImage: "info.circle")
                        }

                        Button {
                            coordinator.selectedTab = .gallery
                        } label: {
                            Label("Open Gallery to Lock", systemImage: "photo.fill.on.rectangle.fill")
                        }
                    } label: {
                        Label("Client Mode Options", systemImage: "slider.horizontal.3")
                    }
                }
            } footer: {
                Text("When locked, Financial and Settings tabs require authentication. Hand your device to clients safely.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Client Mode")
        .alert("Set PIN", isPresented: $showingSetPIN) {
            SecureField("Enter PIN", text: $newPIN)
                .keyboardType(.numberPad)
            SecureField("Confirm PIN", text: $confirmPIN)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if newPIN == confirmPIN && !newPIN.isEmpty {
                    lockManager.setPIN(newPIN)
                } else {
                    pinMismatch = true
                }
            }
        } message: {
            Text("Choose a numeric PIN for unlocking business views.")
        }
        .alert("PINs Don't Match", isPresented: $pinMismatch) {
            Button("Try Again") {
                newPIN = ""
                confirmPIN = ""
                showingSetPIN = true
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var allowedGalleryKeys: Set<String> {
        Set(galleryAllowedSectionsRaw.split(separator: ",").map { String($0) }.filter { !$0.isEmpty })
    }

    private func updateAllowedGalleryKeys(key: String, enabled: Bool) {
        var set = allowedGalleryKeys
        if enabled { set.insert(key) } else { set.remove(key) }
        galleryAllowedSectionsRaw = set.sorted().joined(separator: ",")
    }

    private func labelForGalleryKey(_ key: String) -> String {
        switch key {
        case "byStage": return "By Stage"
        case "byPlacement": return "Placement"
        case "bySize": return "Size"
        case "byRating": return "Rating"
        case "byClient": return "Clients"
        default: return key
        }
    }
}
