import SwiftUI
import SwiftData

// MARK: - Entry Point

struct SettingsViewFinancial: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if let profile = profiles.first {
            SessionRatesContent(profile: profile)
        } else {
            noProfileView
                .navigationTitle("Financial Settings")
        }
    }
}

// MARK: - Content

private struct SessionRatesContent: View {
    @Bindable var profile: UserProfile
    @Query private var allConfigs: [SessionRateConfig]
    @Query(sort: \CustomSessionType.sortOrder) private var customTypes: [CustomSessionType]
    @Query(sort: \FlashPriceTier.sortOrder) private var flashTiers: [FlashPriceTier]
    @Environment(\.modelContext) private var modelContext

    private static let currencies = [
        "USD", "EUR", "GBP", "CAD", "AUD", "NZD",
        "JPY", "CHF", "SEK", "NOK", "DKK"
    ]

    var body: some View {
        List {

            // MARK: Defaults
            Section("Defaults") {
                HStack {
                    Label("Hourly Rate", systemImage: "dollarsign.circle")
                    Spacer()
                    TextField("0", value: $profile.defaultHourlyRate,
                              format: .currency(code: profile.currency))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 110)
                }
                Picker("Currency", selection: $profile.currency) {
                    ForEach(SessionRatesContent.currencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
            }

            // MARK: Global Deposits
            Section {
                HStack {
                    Label("Flat Amount", systemImage: "banknote")
                    Spacer()
                    TextField("0", value: $profile.depositFlat,
                              format: .currency(code: profile.currency))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 110)
                }
                HStack {
                    Label("Percentage", systemImage: "percent")
                    Spacer()
                    TextField("0", value: $profile.depositPercentage, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 60)
                    Text("%").foregroundStyle(.secondary)
                }
            } header: {
                Text("Global Deposits")
            } footer: {
                Text("Per-session types can apply the flat amount, percentage, or waive the deposit entirely.")
            }

            // MARK: Global Discounts
            Section {
                percentField("Friends & Family", icon: "heart.circle",
                             value: $profile.friendsFamilyDiscount)
                percentField("Preferred Client", icon: "star.circle",
                             value: $profile.preferredClientDiscount)
                percentField("Holiday", icon: "gift.circle",
                             value: $profile.holidayDiscount)
                percentField("Convention", icon: "person.3.fill",
                             value: $profile.conventionDiscount)
            } header: {
                Text("Global Discounts")
            } footer: {
                Text("Select one of these to apply to an individual session type below.")
            }

            // MARK: Global Fees
            Section {
                currencyField("No Show", icon: "calendar.badge.exclamationmark",
                              value: $profile.noShowFee)
                currencyField("Revision", icon: "arrow.uturn.left.circle",
                              value: $profile.revisionFee)
                currencyField("Administrative", icon: "doc.badge.clock",
                              value: $profile.administrativeFee)
            } header: {
                Text("Global Fees")
            } footer: {
                Text("Select one of these to apply to an individual session type below.")
            }

            // MARK: Built-in Session Types — one section per type
            ForEach(SessionType.allCases, id: \.self) { type in
                if let config = configFor(type.rawValue) {
                    Section {
                        SessionRatePanel(
                            config: config,
                            profile: profile,
                            isFlash: type.isFlash,
                            isChargeableBinding: chargeableBinding(for: type),
                            flashTiers: type.isFlash ? flashTiers : []
                        )
                    } header: {
                        Label(type.rawValue, systemImage: type.systemImage)
                    }
                }
            }

            // MARK: Custom Session Types — one section per type
            ForEach(customTypes) { custom in
                if let config = configFor(custom.uuid.uuidString) {
                    Section {
                        SessionRatePanel(
                            config: config,
                            profile: profile,
                            isFlash: false,
                            isChargeableBinding: Binding(
                                get: { custom.isChargeable },
                                set: { custom.isChargeable = $0 }
                            ),
                            flashTiers: []
                        )
                    } header: {
                        Label(custom.name, systemImage: "person.badge.clock")
                    }
                }
            }

            // MARK: Status Colours
            Section {
                ForEach(PieceStatus.allCases, id: \.self) { status in
                    StatusColourRow(status: status, profile: profile)
                }
            } header: {
                Label("Status Colours", systemImage: "circle.fill")
            } footer: {
                Text("Colour coding appears on piece badges, list rows, and detail views.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Session Rates")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    modelContext.insert(CustomSessionType(
                        name: "New Session",
                        isChargeable: false,
                        sortOrder: customTypes.count
                    ))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear { ensureConfigs() }
    }

    // MARK: - Helpers

    private func configFor(_ key: String) -> SessionRateConfig? {
        allConfigs.first { $0.sessionTypeRaw == key }
    }

    private func chargeableBinding(for type: SessionType) -> Binding<Bool> {
        Binding(
            get: { profile.isChargeable(type) },
            set: { profile.setChargeable(type, $0) }
        )
    }

    private func ensureConfigs() {
        let existingKeys = Set(allConfigs.map { $0.sessionTypeRaw })
        for type in SessionType.allCases where !existingKeys.contains(type.rawValue) {
            modelContext.insert(SessionRateConfig(sessionTypeRaw: type.rawValue))
        }
        for custom in customTypes where !existingKeys.contains(custom.uuid.uuidString) {
            modelContext.insert(SessionRateConfig(sessionTypeRaw: custom.uuid.uuidString))
        }
        if flashTiers.isEmpty { generateDefaultFlashTiers() }
    }

    /// Auto-generates flash size tiers on first use.
    /// Price = $100 per 2 sq in of area.
    private func generateDefaultFlashTiers() {
        let sizes: [(w: Double, h: Double)] = [
            (2, 1), (2, 2), (4, 2), (4, 4), (6, 4), (6, 6), (8, 6), (8, 8)
        ]
        for (i, s) in sizes.enumerated() {
            let price = Decimal(Int((s.w * s.h / 2).rounded()) * 100)
            modelContext.insert(FlashPriceTier(
                label: "\(Int(s.w))\" × \(Int(s.h))\"",
                widthInches: s.w,
                heightInches: s.h,
                price: price,
                sortOrder: i
            ))
        }
    }

    // MARK: - Field helpers

    private func currencyField(_ label: String, icon: String, value: Binding<Decimal>) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            TextField("0", value: value, format: .currency(code: profile.currency))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 110)
        }
    }

    private func percentField(_ label: String, icon: String, value: Binding<Decimal>) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 60)
            Text("%").foregroundStyle(.secondary)
        }
    }
}

// MARK: - Session Rate Panel

/// The per-type rate configuration rows, placed inside a Section.
private struct SessionRatePanel: View {
    @Bindable var config: SessionRateConfig
    @Bindable var profile: UserProfile
    let isFlash: Bool
    let isChargeableBinding: Binding<Bool>
    let flashTiers: [FlashPriceTier]

    @Environment(\.modelContext) private var modelContext

    private var isChargeable: Bool { isChargeableBinding.wrappedValue }

    var body: some View {
        // ── Chargeable toggle ─────────────────────────────
        Toggle("Charge for this session", isOn: isChargeableBinding)

        // ── Rate panel (visible when chargeable) ──────────
        if isChargeable {

            // Rate
            HStack {
                Text("Rate").foregroundStyle(.secondary)
                Spacer()
                Picker("Rate", selection: $config.rateModeRaw) {
                    Text("Inherit Default").tag("inherited")
                    Text("Custom").tag("custom")
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            if config.rateModeRaw == "custom" && !sizeBasedFlash {
                HStack {
                    Text("Custom Rate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("0", value: $config.rateValue,
                              format: .currency(code: profile.currency))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                }
            }

            // Flash pricing mode
            if isFlash {
                HStack {
                    Text("Flash Pricing").foregroundStyle(.secondary)
                    Spacer()
                    Picker("Flash Mode", selection: $config.flashPricingModeRaw) {
                        Text("Hourly").tag("hourly")
                        Text("Size Based").tag("sizeBased")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                }

                if sizeBasedFlash {
                    ForEach(flashTiers) { tier in
                        FlashTierRow(tier: tier, currency: profile.currency)
                    }
                    .onDelete { indexSet in
                        indexSet.map { flashTiers[$0] }.forEach { modelContext.delete($0) }
                    }
                    Button {
                        modelContext.insert(FlashPriceTier(
                            sortOrder: (flashTiers.last?.sortOrder ?? -1) + 1
                        ))
                    } label: {
                        Label("Add Size", systemImage: "plus").font(.subheadline)
                    }
                }
            }

            // Deposit
            HStack {
                Text("Deposit").foregroundStyle(.secondary)
                Spacer()
                Picker("Deposit", selection: $config.depositModeRaw) {
                    Text("Not Applicable").tag("notApplicable")
                    Text(depositFlatLabel).tag("flat")
                    Text(depositPercentLabel).tag("percentage")
                    Text("Waived").tag("waived")
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Discount
            HStack {
                Text("Discount").foregroundStyle(.secondary)
                Spacer()
                Picker("Discount", selection: $config.discountTypeRaw) {
                    Text("None").tag("none")
                    Text(discountLabel("friendsFamily")).tag("friendsFamily")
                    Text(discountLabel("preferredClient")).tag("preferredClient")
                    Text(discountLabel("holiday")).tag("holiday")
                    Text(discountLabel("convention")).tag("convention")
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Fee
            HStack {
                Text("Fee").foregroundStyle(.secondary)
                Spacer()
                Picker("Fee", selection: $config.feeTypeRaw) {
                    Text("None").tag("none")
                    Text(feeLabel("noShow")).tag("noShow")
                    Text(feeLabel("revision")).tag("revision")
                    Text(feeLabel("administrative")).tag("administrative")
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    // MARK: - Label helpers

    private var sizeBasedFlash: Bool {
        isFlash && config.flashPricingModeRaw == "sizeBased"
    }

    private var depositFlatLabel: String {
        "Flat — \(profile.depositFlat.currencyString(code: profile.currency))"
    }

    private var depositPercentLabel: String {
        "Percentage — \(profile.depositPercentage.percentString)%"
    }

    private func discountLabel(_ key: String) -> String {
        switch key {
        case "friendsFamily":   return "Friends & Family — \(profile.friendsFamilyDiscount.percentString)%"
        case "preferredClient": return "Preferred Client — \(profile.preferredClientDiscount.percentString)%"
        case "holiday":         return "Holiday — \(profile.holidayDiscount.percentString)%"
        case "convention":      return "Convention — \(profile.conventionDiscount.percentString)%"
        default:                return "None"
        }
    }

    private func feeLabel(_ key: String) -> String {
        switch key {
        case "noShow":         return "No Show — \(profile.noShowFee.currencyString(code: profile.currency))"
        case "revision":       return "Revision — \(profile.revisionFee.currencyString(code: profile.currency))"
        case "administrative": return "Administrative — \(profile.administrativeFee.currencyString(code: profile.currency))"
        default:               return "None"
        }
    }
}

// MARK: - Flash Tier Row

private struct FlashTierRow: View {
    @Bindable var tier: FlashPriceTier
    let currency: String

    var body: some View {
        HStack(spacing: 8) {
            TextField("Name", text: $tier.label)
                .frame(maxWidth: 80)
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
            TextField("0", value: $tier.price,
                      format: .currency(code: currency))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 90)
        }
    }
}

// MARK: - Status Colour Row

struct StatusColourRow: View {
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
            Text(status.rawValue).font(.subheadline)
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

// MARK: - Decimal formatting helpers

private extension Decimal {
    /// Clean percentage string with no trailing zeros (e.g. "20" not "20.000000").
    var percentString: String {
        let n = NSDecimalNumber(decimal: self)
        if n == n.rounding(accordingToBehavior: nil) {
            return "\(Int(truncating: n))"
        }
        return n.stringValue
    }

    /// Short currency string without grouping separators for use in picker labels.
    func currencyString(code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = self.isWholeNumber ? 0 : 2
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "$\(self)"
    }

    var isWholeNumber: Bool {
        self == Decimal(Int(truncating: NSDecimalNumber(decimal: self)))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsViewFinancial()
    }
    .modelContainer(PreviewContainer.shared.container)
    .environment(BusinessLockManager())
}
