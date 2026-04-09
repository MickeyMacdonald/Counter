import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(BusinessLockManager.self) private var lockManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var coordinator = AppNavigationCoordinator()
    @AppStorage("business.autolockOnBackground") private var autoLockOnBackground: Bool = false

    private var hasProfile: Bool {
        profiles.first != nil
    }

    var body: some View {
        Group {
            if hasProfile {
                if lockManager.isLocked {
                    // Client mode: Gallery only (no tab bar)
                    GalleryTabView()
                        .onAppear { coordinator.selectedTab = .gallery }
                } else {
                    // Full app — no TabView; AppTabSwitcher inside each sidebar drives navigation
                    switch coordinator.selectedTab {
                        case .settings:
                            SettingsView()
                        case .work:
                            WorkView()
                        case .schedule:
                            SchedulingView()
                    case .gallery:
                            GalleryTabView()
                        }
                }
            } else {
                WelcomeSetupView()
            }
        }
        .environment(coordinator)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                // Auto-lock whenever the app leaves the foreground
                if lockManager.isEnabled && autoLockOnBackground { lockManager.lock() }
                // Auto-backup on background (alpha safety net)
                if newPhase == .background {
                    let context = modelContext
                    Task { try? await RecoveryService.shared.performBackup(context: context) }
                }
            case .active:
                // Prompt for biometrics immediately on return if locked
                if lockManager.isEnabled && lockManager.isLocked {
                    Task { await lockManager.unlockWithBiometrics() }
                }
            @unknown default:
                break
            }
        }
    }
}


enum AppTab: String, CaseIterable {
    case settings
    case work
    case schedule
    case gallery

    var label: String {
        switch self {
        case .settings: "Admin"
        case .work:    "Work"
        case .schedule: "Schedule"
        case .gallery:  "Gallery"
        }
    }

    var systemImage: String {
        switch self {
        case .settings: "gearshape.fill"
        case .work:    "paintbrush.pointed.fill"
        case .gallery:  "photo.fill"
        case .schedule: "book.fill"
        }
    }

    var sidebarTint: Color {
        switch self {
        case .settings  : Color(hue: 0.00, saturation: 0.00, brightness: 0.92) // K (neutral gray)
        case .work      : Color(hue: 0.50, saturation: 0.16, brightness: 0.90) // C (~180°)
        case .schedule  : Color(hue: 0.83, saturation: 0.14, brightness: 0.92) // M (~300°)
        case .gallery   : Color(hue: 0.17, saturation: 0.18, brightness: 0.94) // Y (~60°)
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
    @Environment(AppNavigationCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coord = coordinator
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    coord.selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                        Text(tab.label)
                            .font(.caption2.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(coord.selectedTab == tab ? Color.primary : Color.secondary)
                    .background(
                        coord.selectedTab == tab
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
        .environment(AppNavigationCoordinator())
}

#Preview("Welcome") {
    WelcomeSetupView()
        .modelContainer(PreviewContainer.shared.container)
}
