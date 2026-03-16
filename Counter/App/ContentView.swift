import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(BusinessLockManager.self) private var lockManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .works

    private var hasProfile: Bool {
        profiles.first != nil
    }

    var body: some View {
        Group {
            if hasProfile {
                if lockManager.isLocked {
                    // Client mode: Gallery only (no tab bar)
                    GalleryTabView(selectedTab: $selectedTab)
                        .onAppear { selectedTab = .gallery }
                } else {
                    // Full app — no TabView; AppTabSwitcher inside each sidebar drives navigation
                    switch selectedTab {
                    case .settings:
                        SettingsView(selectedTab: $selectedTab)
                    case .works:
                        WorksTabView(selectedTab: $selectedTab)
                    case .sessions:
                        SessionsTabView(selectedTab: $selectedTab)
                    case .gallery:
                        GalleryTabView(selectedTab: $selectedTab)

                    }
                }
            } else {
                WelcomeSetupView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard lockManager.isEnabled else { return }
            switch newPhase {
            case .background, .inactive:
                // Auto-lock whenever the app leaves the foreground
                lockManager.lock()
            case .active:
                // Prompt for biometrics immediately on return if locked
                if lockManager.isLocked {
                    Task { await lockManager.unlockWithBiometrics() }
                }
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Welcome / First-Run Setup

struct WelcomeSetupView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var businessName = ""
    @State private var profession: Profession = .tattooer
    @State private var currentStep = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress
                ProgressView(value: Double(currentStep + 1), total: 3)
                    .padding(.horizontal)
                    .padding(.top, 8)

                TabView(selection: $currentStep) {
                    // Step 1: Welcome
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: "paintbrush.pointed.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor)

                        Text("Welcome to Counter")
                            .font(.largeTitle.weight(.bold))

                        Text("The all-in-one tool for managing your clients, bookings, and business.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Spacer()

                        Button {
                            withAnimation { currentStep = 1 }
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                    .tag(0)

                    // Step 2: Profession
                    VStack(spacing: 24) {
                        Spacer()

                        Text("What do you do?")
                            .font(.title.weight(.bold))

                        VStack(spacing: 12) {
                            ForEach(Profession.allCases, id: \.self) { p in
                                Button {
                                    profession = p
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: p.systemImage)
                                            .font(.title2)
                                            .frame(width: 32)
                                        Text(p.rawValue)
                                            .font(.headline)
                                        Spacer()
                                        if profession == p {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(profession == p ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.05))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 40)

                        Spacer()

                        Button {
                            withAnimation { currentStep = 2 }
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                    .tag(1)

                    // Step 3: Name
                    VStack(spacing: 24) {
                        Spacer()

                        Text("About You")
                            .font(.title.weight(.bold))

                        VStack(spacing: 16) {
                            TextField("First Name", text: $firstName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.givenName)

                            TextField("Last Name", text: $lastName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.familyName)

                            TextField("Business Name (optional)", text: $businessName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.organizationName)
                        }
                        .padding(.horizontal, 40)

                        Spacer()

                        Button {
                            createProfile()
                        } label: {
                            Text("Finish Setup")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(firstName.isEmpty)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
        }
    }

    private func createProfile() {
        let profile = UserProfile(
            firstName: firstName,
            lastName: lastName,
            businessName: businessName,
            profession: profession
        )
        modelContext.insert(profile)
    }
}

enum AppTab: String, CaseIterable {
    case settings
    case works
    case sessions
    case gallery

    var label: String {
        switch self {
        case .settings: "Admin"
        case .works:    "Works"
        case .sessions: "Sessions"
        case .gallery:  "Gallery"
        }
    }

    var systemImage: String {
        switch self {
        case .settings: "gearshape.fill"
        case .works:    "person.crop.rectangle.stack.fill"
        case .gallery:  "photo.fill"
        case .sessions: "calendar.badge.clock"
        }
    }

    var sidebarTint: Color {
        switch self {
        case .settings: Color(hue: 0.615, saturation: 0.30, brightness: 0.68)
        case .works:    Color(hue: 0.610, saturation: 0.22, brightness: 0.80)
        case .sessions: Color(hue: 0.600, saturation: 0.14, brightness: 0.90)
        case .gallery:  Color(hue: 0.590, saturation: 0.08, brightness: 0.97)
        }
    }
}

// MARK: - Sidebar Search Field

struct SidebarSearchField: View {
    @Binding var text: String
    var prompt: String = "Search..."

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            TextField(prompt, text: $text)
                .font(.subheadline)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - App Tab Switcher

struct AppTabSwitcher: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                        Text(tab.label)
                            .font(.caption2.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                    .background(
                        selectedTab == tab
                            ? Color.primary.opacity(0.08)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}

#Preview("Welcome") {
    WelcomeSetupView()
        .modelContainer(PreviewContainer.shared.container)
}
