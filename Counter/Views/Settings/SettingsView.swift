import SwiftUI
import SwiftData

enum SettingsCategory: String, CaseIterable, Identifiable {
    case profile = "Profile"
    case rates = "Rates & Pricing"
    case sessions = "Sessions"
    case booking = "Booking"
    case emailTemplates = "Email Templates"
    case clientMode = "Client Mode"
    case about = "About"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .profile: "person.crop.circle"
        case .rates: "dollarsign.circle"
        case .sessions: "clock.badge.checkmark"
        case .booking: "calendar.badge.clock"
        case .emailTemplates: "envelope.open.fill"
        case .clientMode: "lock.shield"
        case .about: "info.circle"
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
        case .rates:
            SettingsRatesView()
        case .sessions:
            SettingsSessionTypesView()
        case .booking:
            SettingsBookingView()
        case .emailTemplates:
            SettingsEmailTemplatesView()
        case .clientMode:
            SettingsClientModeView()
        case .about:
            SettingsAboutView()
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

// MARK: - Rates & Pricing

struct SettingsRatesView: View {
    @Query private var profiles: [UserProfile]
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        if let profile {
            RatesForm(profile: profile)
        } else {
            noProfileView
                .navigationTitle("Rates & Pricing")
        }
    }
}

private struct RatesForm: View {
    @Bindable var profile: UserProfile
    @Query(sort: \FlashPriceTier.sortOrder) private var flashTiers: [FlashPriceTier]
    @Environment(\.modelContext) private var modelContext

    private static let currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "NZD", "JPY", "CHF", "SEK", "NOK", "DKK"]

    private var flashModeBinding: Binding<FlashPricingMode> {
        Binding(
            get: { FlashPricingMode(rawValue: profile.flashPricingModeRaw) ?? .hourly },
            set: { profile.flashPricingModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("Defaults") {
                currencyRow("Hourly Rate", systemImage: "dollarsign.circle", value: $profile.defaultHourlyRate)
                Picker("Currency", selection: $profile.currency) {
                    ForEach(RatesForm.currencies, id: \.self) { Text($0).tag($0) }
                }
            }

            Section {
                currencyRow("Flat", systemImage: "banknote", value: $profile.depositFlat)
                percentRow("Rate", systemImage: "percent", value: $profile.depositPercentage)
            } header: {
                Text("Deposits")
            } footer: {
                Text("Flat overrides Rate when both are set. Use whichever applies to your workflow.")
            }

            Section("Discounts") {
                percentRow("Friends & Family", systemImage: "heart.circle", value: $profile.friendsFamilyDiscount)
                percentRow("Preferred Client", systemImage: "star.circle", value: $profile.preferredClientDiscount)
                percentRow("Holiday Rate", systemImage: "gift.circle", value: $profile.holidayDiscount)
                percentRow("Convention Rate", systemImage: "person.3.fill", value: $profile.conventionDiscount)
            }

            Section("Fees") {
                currencyRow("No Show", systemImage: "calendar.badge.exclamationmark", value: $profile.noShowFee)
                currencyRow("Revision", systemImage: "arrow.uturn.left.circle", value: $profile.revisionFee)
                currencyRow("Administrative", systemImage: "doc.badge.clock", value: $profile.administrativeFee)
            }

            Section {
                Picker("Pricing Mode", selection: flashModeBinding) {
                    ForEach(FlashPricingMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if flashModeBinding.wrappedValue == .sizeBased {
                    ForEach(flashTiers) { tier in
                        FlashTierRow(tier: tier, currency: profile.currency)
                    }
                    .onDelete { indexSet in
                        indexSet.map { flashTiers[$0] }.forEach { modelContext.delete($0) }
                    }
                    Button {
                        let next = (flashTiers.last?.sortOrder ?? -1) + 1
                        modelContext.insert(FlashPriceTier(sortOrder: next))
                    } label: {
                        Label("Add Size", systemImage: "plus")
                    }
                }
            } header: {
                Text("Flash")
            } footer: {
                if flashModeBinding.wrappedValue == .hourly {
                    Text("Flash sessions bill at the default hourly rate above.")
                } else {
                    Text("Each size tier has a fixed price regardless of time spent. Clients select a tier at booking.")
                }
            }
        }
        .navigationTitle("Rates & Pricing")
    }

    private func currencyRow(_ label: String, systemImage: String, value: Binding<Decimal>) -> some View {
        HStack {
            Label(label, systemImage: systemImage)
            Spacer()
            TextField("0", value: value, format: .currency(code: profile.currency))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }

    private func percentRow(_ label: String, systemImage: String, value: Binding<Decimal>) -> some View {
        HStack {
            Label(label, systemImage: systemImage)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 60)
            Text("%")
                .foregroundStyle(.secondary)
        }
    }
}

private struct FlashTierRow: View {
    @Bindable var tier: FlashPriceTier
    let currency: String

    var body: some View {
        HStack(spacing: 8) {
            TextField("Name", text: $tier.label)
                .frame(maxWidth: 90)
            Spacer()
            TextField("W", value: $tier.widthInches, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 38)
            Text("×").foregroundStyle(.secondary)
            TextField("H", value: $tier.heightInches, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 38)
            Text("in")
                .foregroundStyle(.secondary)
                .font(.caption)
            Spacer()
            TextField("0", value: $tier.price, format: .currency(code: currency))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 80)
        }
    }
}

// MARK: - Session Types

struct SettingsSessionTypesView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \CustomSessionType.sortOrder) private var customTypes: [CustomSessionType]
    @Environment(\.modelContext) private var modelContext

    private var profile: UserProfile? { profiles.first }

    @State private var chargedTargeted = false
    @State private var unchargedTargeted = false
    @State private var editingCustomUUID: UUID? = nil
    @State private var editName: String = ""

    // MARK: - Computed splits

    private var chargedBuiltins: [SessionType] {
        SessionType.allCases.filter { profile?.isChargeable($0) ?? $0.defaultChargeable }
    }
    private var unchargedBuiltins: [SessionType] {
        SessionType.allCases.filter { !(profile?.isChargeable($0) ?? $0.defaultChargeable) }
    }
    private var chargedCustom: [CustomSessionType]   { customTypes.filter {  $0.isChargeable } }
    private var unchargedCustom: [CustomSessionType] { customTypes.filter { !$0.isChargeable } }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if profile != nil {
                    sectionCard(
                        title: "Charged",
                        titleIcon: "dollarsign.circle.fill",
                        titleColor: .green,
                        footer: "Charged sessions count toward cost estimates and running totals.",
                        isTargeted: chargedTargeted,
                        accentColor: .green,
                        builtins: chargedBuiltins,
                        customs: chargedCustom,
                        toCharged: true
                    )
                    sectionCard(
                        title: "Uncharged",
                        titleIcon: "circle.slash",
                        titleColor: .secondary,
                        footer: "Uncharged sessions are tracked but do not affect billing.",
                        isTargeted: unchargedTargeted,
                        accentColor: .secondary,
                        builtins: unchargedBuiltins,
                        customs: unchargedCustom,
                        toCharged: false
                    )
                    // Status colour configuration
                    statusColoursCard

                } else {
                    noProfileCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Sessions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let custom = CustomSessionType(name: "New Session", isChargeable: false, sortOrder: customTypes.count)
                    modelContext.insert(custom)
                    editingCustomUUID = custom.uuid
                    editName = custom.name
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Section card

    @ViewBuilder
    private func sectionCard(
        title: String,
        titleIcon: String,
        titleColor: Color,
        footer: String,
        isTargeted: Bool,
        accentColor: Color,
        builtins: [SessionType],
        customs: [CustomSessionType],
        toCharged: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            Label(title, systemImage: titleIcon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isTargeted ? titleColor : titleColor.opacity(0.75))
                .textCase(.uppercase)
                .padding(.leading, 4)
                .animation(.easeInOut(duration: 0.15), value: isTargeted)

            // Card body — drop target is the whole card
            VStack(spacing: 0) {
                ForEach(Array(builtins.enumerated()), id: \.element) { index, type in
                    builtinRow(type)
                        .draggable("builtin:\(type.rawValue)")
                    if index < builtins.count - 1 || !customs.isEmpty {
                        Divider().padding(.leading, 16)
                    }
                }
                ForEach(Array(customs.enumerated()), id: \.element.uuid) { index, custom in
                    customRow(custom)
                        .draggable("custom:\(custom.uuid.uuidString)")
                    if index < customs.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }

                // Drop zone hint strip at the bottom
                if builtins.isEmpty && customs.isEmpty {
                    emptyDropHint(accentColor: accentColor, isTargeted: isTargeted)
                } else {
                    dropHintStrip(accentColor: accentColor, isTargeted: isTargeted)
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isTargeted ? accentColor.opacity(0.5) : Color.clear,
                        lineWidth: 2
                    )
                    .animation(.easeInOut(duration: 0.15), value: isTargeted)
            )
            .dropDestination(for: String.self, action: { items, _ in
                guard let id = items.first else { return false }
                moveSession(id: id, toCharged: toCharged)
                return true
            }, isTargeted: { targeted in
                if toCharged { chargedTargeted = targeted }
                else { unchargedTargeted = targeted }
            })

            // Footer
            Text(footer)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }

    // MARK: - Row views

    private func builtinRow(_ type: SessionType) -> some View {
        Label(type.rawValue, systemImage: type.systemImage)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func customRow(_ custom: CustomSessionType) -> some View {
        if editingCustomUUID == custom.uuid {
            HStack {
                Image(systemName: "text.cursor").foregroundStyle(.secondary)
                TextField("Session name", text: $editName)
                    .submitLabel(.done)
                    .onSubmit { commitRename(custom) }
                Button("Done") { commitRename(custom) }
                    .font(.caption).foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            HStack {
                Label(custom.name, systemImage: "person.badge.clock")
                Spacer()
                Button {
                    editingCustomUUID = custom.uuid
                    editName = custom.name
                } label: {
                    Image(systemName: "pencil").foregroundStyle(.secondary).font(.caption)
                }
                .buttonStyle(.plain)
                Button {
                    modelContext.delete(custom)
                } label: {
                    Image(systemName: "trash").foregroundStyle(.red.opacity(0.7)).font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    private func dropHintStrip(accentColor: Color, isTargeted: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle").font(.caption2)
            Text("Drop here").font(.caption2)
        }
        .foregroundStyle(isTargeted ? accentColor : Color.secondary.opacity(0.35))
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 7)
        .background(isTargeted ? accentColor.opacity(0.08) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }

    private func emptyDropHint(accentColor: Color, isTargeted: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "tray").font(.title3).foregroundStyle(isTargeted ? accentColor : Color.secondary.opacity(0.4))
            Text(isTargeted ? "Release to move here" : "Drag sessions here")
                .font(.caption)
                .foregroundStyle(isTargeted ? accentColor : Color.secondary.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }

    private var noProfileCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text("No profile found").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Status colours card

    @ViewBuilder
    private var statusColoursCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Statuses", systemImage: "circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondary.opacity(0.75))
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(PieceStatus.allCases.enumerated()), id: \.element) { idx, status in
                    if let p = profile {
                        StatusColourRow(status: status, profile: p)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    if idx < PieceStatus.allCases.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10))

            Text("Colour coding appears on piece badges, list rows, and the To Do view.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }

    // MARK: - Move logic

    private func moveSession(id: String, toCharged: Bool) {
        if id.hasPrefix("builtin:") {
            let raw = String(id.dropFirst(8))
            if let type = SessionType(rawValue: raw) {
                profile?.setChargeable(type, toCharged)
                try? modelContext.save()
            }
        } else if id.hasPrefix("custom:") {
            let uuidStr = String(id.dropFirst(7))
            if let custom = customTypes.first(where: { $0.uuid.uuidString == uuidStr }) {
                custom.isChargeable = toCharged
                try? modelContext.save()
            }
        }
    }

    private func commitRename(_ custom: CustomSessionType) {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        custom.name = trimmed.isEmpty ? "New Session" : trimmed
        editingCustomUUID = nil
    }
}

// MARK: - Status Colour Row

private struct StatusColourRow: View {
    let status: PieceStatus
    @Bindable var profile: UserProfile

    private var currentName: String {
        profile.statusColorNames[status.rawValue] ?? status.defaultColorName
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(status.color(from: profile))
                .frame(width: 10, height: 10)

            Text(status.rawValue)
                .font(.subheadline)

            Spacer()

            Picker("", selection: colorBinding) {
                ForEach(Color.statusColorPalette, id: \.self) { name in
                    Label(name.capitalized, systemImage: "circle.fill")
                        .foregroundStyle(Color.forStatusName(name))
                        .tag(name)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private var colorBinding: Binding<String> {
        Binding(
            get: { currentName },
            set: {
                var dict = profile.statusColorNames
                dict[status.rawValue] = $0
                profile.statusColorNames = dict
            }
        )
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

private var noProfileView: some View {
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
