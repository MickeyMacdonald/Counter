import SwiftUI
import SwiftData
import UserNotifications

struct SettingsViewNotifications: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(NotificationService.enabledKey)        private var enabled:        Bool = false
    @AppStorage(NotificationService.eveEnabledKey)     private var eveEnabled:     Bool = true
    @AppStorage(NotificationService.eveHourKey)        private var eveHour:        Int  = NotificationService.defaultEveHour
    @AppStorage(NotificationService.morningEnabledKey) private var morningEnabled: Bool = true
    @AppStorage(NotificationService.morningHourKey)    private var morningHour:    Int  = NotificationService.defaultMorningHour

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var showDeniedAlert = false
    @State private var isSyncing = false

    var body: some View {
        List {
            permissionSection
            if enabled && authStatus == .authorized {
                eveSection
                morningSection
                syncSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .task { await refreshAuthStatus() }
        .alert("Notifications Blocked", isPresented: $showDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Counter's notifications have been blocked in iOS Settings. Tap \"Open Settings\" to allow them, then return to the app.")
        }
    }

    // MARK: - Permission Section

    private var permissionSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { enabled },
                set: { newValue in Task { await setEnabled(newValue) } }
            )) {
                Label("Booking Reminders", systemImage: "bell.fill")
            }

            if authStatus != .notDetermined {
                LabeledContent("Status") {
                    statusBadge
                }
            }
        } footer: {
            Text("Counter schedules local reminders for upcoming bookings. No account or internet connection required.")
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch authStatus {
        case .authorized, .provisional:
            Label("Authorized", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .denied:
            Label("Blocked — tap to fix", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .onTapGesture { showDeniedAlert = true }
        default:
            Label("Not requested", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Evening Reminder Section

    private var eveSection: some View {
        Section {
            Toggle("Evening Reminder", isOn: Binding(
                get: { eveEnabled },
                set: { eveEnabled = $0; triggerSync() }
            ))

            if eveEnabled {
                Picker("Time", selection: Binding(
                    get: { eveHour },
                    set: { eveHour = $0; triggerSync() }
                )) {
                    ForEach(eveningHours, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
            }
        } header: {
            Text("Night Before")
        } footer: {
            Text("Sent the evening before each booking so you can prepare.")
        }
    }

    // MARK: - Morning Reminder Section

    private var morningSection: some View {
        Section {
            Toggle("Morning Reminder", isOn: Binding(
                get: { morningEnabled },
                set: { morningEnabled = $0; triggerSync() }
            ))

            if morningEnabled {
                Picker("Time", selection: Binding(
                    get: { morningHour },
                    set: { morningHour = $0; triggerSync() }
                )) {
                    ForEach(morningHours, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
            }
        } header: {
            Text("Day Of")
        } footer: {
            Text("Sent the morning of each booking as a start-of-day heads-up.")
        }
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        Section {
            Button {
                triggerSync()
            } label: {
                HStack {
                    Label("Sync Reminders Now", systemImage: "arrow.clockwise")
                    Spacer()
                    if isSyncing { ProgressView() }
                }
            }
            .disabled(isSyncing)
        } footer: {
            Text("Reminders are synced automatically on launch. Use this if you've recently added bookings and want them scheduled immediately.")
        }
    }

    // MARK: - Helpers

    private let eveningHours = Array(15...22)
    private let morningHours = Array(5...11)

    private func hourLabel(_ hour: Int) -> String {
        var c = DateComponents()
        c.hour = hour; c.minute = 0
        guard let date = Calendar.current.date(from: c) else { return "\(hour):00" }
        return date.formatted(.dateTime.hour().minute())
    }

    private func refreshAuthStatus() async {
        authStatus = await NotificationService.shared.authorizationStatus
    }

    private func setEnabled(_ newValue: Bool) async {
        if newValue {
            let status = await NotificationService.shared.authorizationStatus
            switch status {
            case .notDetermined:
                let granted = await NotificationService.shared.requestPermission()
                enabled = granted
                await refreshAuthStatus()
                if granted { triggerSync() }
            case .denied:
                enabled = false
                showDeniedAlert = true
                await refreshAuthStatus()
            default:
                enabled = true
                await refreshAuthStatus()
                triggerSync()
            }
        } else {
            enabled = false
            let context = modelContext
            Task { await NotificationService.shared.syncAll(context: context) }
        }
    }

    private func triggerSync() {
        let context = modelContext
        isSyncing = true
        Task {
            await NotificationService.shared.syncAll(context: context)
            isSyncing = false
        }
    }
}

#Preview {
    NavigationStack {
        SettingsViewNotifications()
    }
    .modelContainer(PreviewContainer.shared.container)
}
