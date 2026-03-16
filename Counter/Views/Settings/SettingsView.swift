import SwiftUI
import SwiftData

enum SettingsCategory: String, CaseIterable, Identifiable {
    case profile        = "Profile"
    case sessionRates   = "Session Rates"
    case emailTemplates = "Email Templates"
    case clientMode     = "Client Mode"
    case financial      = "Financial"
    case reports        = "Reports"
    case about          = "About"
    case support        = "Support Counter"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .profile:        "person.crop.circle"
        case .sessionRates:   "banknote"
        case .emailTemplates: "envelope.open.fill"
        case .clientMode:     "lock.shield"
        case .financial:      "dollarsign.circle.fill"
        case .reports:        "doc.text.magnifyingglass"
        case .about:          "info.circle"
        case .support:        "heart.fill"
        }
    }
}

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(BusinessLockManager.self) private var lockManager
    @State private var selectedCategory: SettingsCategory? = .profile

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                NavigationLink(value: category) {
                    Label(category.rawValue, systemImage: category.systemImage)
                        .foregroundStyle(category == .support ? Color.pink : Color.primary)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Settings")
            .toolbar {
                if lockManager.isEnabled {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            lockManager.lock()
                        } label: {
                            Image(systemName: "lock.open.fill")
                                .font(.caption)
                        }
                    }
                }
            }
        } detail: {
            if let selectedCategory {
                NavigationStack {
                    settingsDetail(for: selectedCategory)
                }
            } else {
                ContentUnavailableView(
                    "Select a Category",
                    systemImage: "gearshape",
                    description: Text("Choose a settings category from the list.")
                )
            }
        }
    }

    @ViewBuilder
    private func settingsDetail(for category: SettingsCategory) -> some View {
        switch category {
        case .profile:
            SettingsProfileView(profile: profile)
        case .sessionRates:
            SettingsSessionRatesView()
        case .emailTemplates:
            SettingsEmailTemplatesView()
        case .clientMode:
            SettingsClientModeView()
        case .financial:
            FinancialDashboardView(embedded: true)
        case .reports:
            SettingsReportsView()
        case .about:
            SettingsAboutView()
        case .support:
            SettingsDonationView()
        }
    }
}

// MARK: - Profile

struct SettingsProfileView: View {
    let profile: UserProfile?
    @State private var showingEditProfile = false

    var body: some View {
        List {
            if let profile {
                // Identity card
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(.primary.opacity(0.08))
                                .frame(width: 72, height: 72)
                            Text(profile.initialsDisplay)
                                .font(.system(.title, design: .monospaced, weight: .bold))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.fullName)
                                .font(.title3.weight(.bold))
                            if !profile.businessName.isEmpty {
                                Text(profile.businessName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: profile.profession.systemImage)
                                    .font(.caption)
                                Text(profile.profession.rawValue)
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Contact
                Section("Contact") {
                    if !profile.email.isEmpty {
                        LabeledContent {
                            Text(profile.email).foregroundStyle(.secondary)
                        } label: {
                            Label("Email", systemImage: "envelope")
                        }
                    }
                    if !profile.phone.isEmpty {
                        LabeledContent {
                            Text(profile.phone).foregroundStyle(.secondary)
                        } label: {
                            Label("Phone", systemImage: "phone")
                        }
                    }
                    if profile.email.isEmpty && profile.phone.isEmpty {
                        Text("No contact info added.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                // Shop Address
                Section("Shop Address") {
                    if let summary = profile.shopAddressSummary {
                        Text(summary)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        Text("No shop address added.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                // Billing Address
                Section("Billing Address") {
                    if profile.billingMatchesShop {
                        Label("Same as shop address", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else if let summary = profile.billingAddressSummary {
                        Text(summary)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        Text("No billing address added.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        showingEditProfile = true
                    } label: {
                        Label("Edit Profile", systemImage: "pencil")
                    }
                }
            } else {
                noProfileView
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
        .sheet(isPresented: $showingEditProfile) {
            if let profile {
                ProfileEditView(profile: profile)
            }
        }
    }
}


// MARK: - Availability

struct SettingsAvailabilityView: View {
    @State private var showingAvailability = false

    var body: some View {
        List {
            Section {
                Button {
                    showingAvailability = true
                } label: {
                    Label("Manage Weekly Hours", systemImage: "clock.badge.checkmark")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Availability")
        .sheet(isPresented: $showingAvailability) {
            AvailabilityEditView()
        }
    }
}

// MARK: - Client Mode

struct SettingsClientModeView: View {
    @Environment(BusinessLockManager.self) private var lockManager
    @State private var showingSetPIN = false
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var pinMismatch = false

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

                    Button {
                        lockManager.lock()
                    } label: {
                        Label("Lock Now", systemImage: "lock.fill")
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
}

// MARK: - About

struct SettingsAboutView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: "Pre-Alpha 0.2")
                LabeledContent("Build", value: "CounterPreAlpha")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
    }
}

// MARK: - Shared

var noProfileView: some View {
    ContentUnavailableView {
        Label("No Profile", systemImage: "person.crop.circle.badge.questionmark")
    } description: {
        Text("Set up your profile to get started.")
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}
