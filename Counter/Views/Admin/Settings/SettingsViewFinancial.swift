import SwiftUI
import SwiftData

// MARK: - Entry Point

struct SettingsViewFinancial: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if let profile = profiles.first {
            FinancialContent(profile: profile)
        } else {
            noProfileView
                .navigationTitle("Rates")
        }
    }
}

// MARK: - Content

private struct FinancialContent: View {
    @Bindable var profile: UserProfile
    @Query(sort: \Discount.sortOrder) private var customDiscounts: [Discount]
    @Query(sort: \FlashPriceTier.sortOrder) private var allFlashTiers: [FlashPriceTier]
    @Environment(\.modelContext) private var modelContext

    // New-dimension inline form state
    @State private var addingDimension = false
    @State private var newWidth: Double = 2.0
    @State private var newHeight: Double = 2.0
    @State private var newDimensionPrice: Decimal = 0

    /// Persisted increment used by the size-based +/- steppers.
    @AppStorage("flash.sizeIncrement") private var incrementRaw: Double = 5.0

    private static let locales = ["CAD", "USD", "AUD", "EUR", "GBP"]
    private static let incrementOptions: [Double] = [1, 5, 10, 25, 50, 100]

    private var increment: Decimal { Decimal(incrementRaw) }

    private var namedTiers:      [FlashPriceTier] { allFlashTiers.filter { !$0.isDimensionBased } }
    private var builtInTiers:    [FlashPriceTier] { namedTiers.filter {  $0.isBuiltIn } }
    private var customNamedTiers:[FlashPriceTier] { namedTiers.filter { !$0.isBuiltIn } }
    private var dimensionTiers:  [FlashPriceTier] { allFlashTiers.filter { $0.isDimensionBased } }

    var body: some View {
        List {

            // MARK: Locale
            Section("Locale") {
                Picker("Currency", selection: $profile.currency) {
                    ForEach(FinancialContent.locales, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .pickerStyle(.menu)
            }

            // MARK: Hourly Rate
            Section("Hourly Rate") {
                finRow("Base Rate") {
                    TextField("0", value: $profile.defaultHourlyRate,
                              format: .currency(code: profile.currency))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 110)
                }
                finRow("Special Rate") {
                    TextField("0", value: $profile.specialHourlyRate,
                              format: .currency(code: profile.currency))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 110)
                }
            }

            // MARK: Discounts
            Section("Discounts") {
                finRow("Friends & Family") {
                    HStack(spacing: 4) {
                        TextField("0", value: $profile.friendsFamilyDiscount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 50)
                        Text("%").foregroundStyle(.secondary)
                    }
                }

                ForEach(customDiscounts) { discount in
                    DiscountRow(discount: discount)
                }
                .onDelete { indexSet in
                    indexSet.map { customDiscounts[$0] }.forEach { modelContext.delete($0) }
                }

                Button {
                    withAnimation {
                        modelContext.insert(Discount(sortOrder: customDiscounts.count))
                    }
                } label: {
                    Label("Create New", systemImage: "plus")
                        .font(.subheadline)
                }
            }

            // MARK: Flash — Size Based
            Section {
                // Increment picker
                finRow("Increment") {
                    Picker("", selection: $incrementRaw) {
                        ForEach(FinancialContent.incrementOptions, id: \.self) { val in
                            Text("$\(Int(val))").tag(val)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // Built-in tiers — label locked, price via stepper
                ForEach(builtInTiers) { tier in
                    SizedFlashTierRow(tier: tier, currency: profile.currency, increment: increment)
                }

                // Custom named tiers — label locked, price via stepper, swipe-to-delete
                ForEach(customNamedTiers) { tier in
                    SizedFlashTierRow(tier: tier, currency: profile.currency, increment: increment)
                }
                .onDelete { indexSet in
                    indexSet.map { customNamedTiers[$0] }.forEach { modelContext.delete($0) }
                }

                Button {
                    modelContext.insert(FlashPriceTier(
                        label: "Custom",
                        isDimensionBased: false,
                        isBuiltIn: false,
                        sortOrder: (namedTiers.last?.sortOrder ?? -1) + 1
                    ))
                } label: {
                    Label("Add Custom Size", systemImage: "plus")
                        .font(.subheadline)
                }
            } header: {
                Label("Flash — Size Based", systemImage: "rectangle.3.group")
            }

            // MARK: Flash — Dimension Based
            Section {
                ForEach(dimensionTiers) { tier in
                    DimensionFlashTierRow(tier: tier, currency: profile.currency)
                }
                .onDelete { indexSet in
                    indexSet.map { dimensionTiers[$0] }.forEach { modelContext.delete($0) }
                }

                // Inline dimension creation form
                if addingDimension {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Width")
                                .foregroundStyle(.primary)
                                .frame(width: 56, alignment: .leading)
                            Slider(value: $newWidth, in: 1...12, step: 0.5)
                            Text(String(format: "%.1f\"", newWidth))
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                                .font(.subheadline.monospacedDigit())
                        }
                        HStack {
                            Text("Height")
                                .foregroundStyle(.primary)
                                .frame(width: 56, alignment: .leading)
                            Slider(value: $newHeight, in: 1...12, step: 0.5)
                            Text(String(format: "%.1f\"", newHeight))
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                                .font(.subheadline.monospacedDigit())
                        }
                        HStack {
                            Text("Price")
                                .foregroundStyle(.primary)
                            Spacer()
                            TextField("0", value: $newDimensionPrice,
                                      format: .currency(code: profile.currency))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 110)
                        }
                        HStack(spacing: 12) {
                            Spacer()
                            Button("Cancel") {
                                withAnimation(.easeInOut) { addingDimension = false }
                            }
                            .buttonStyle(.bordered)
                            Button("Add") {
                                let lbl = String(format: "%.1f\" × %.1f\"", newWidth, newHeight)
                                modelContext.insert(FlashPriceTier(
                                    label: lbl,
                                    widthInches: newWidth,
                                    heightInches: newHeight,
                                    price: newDimensionPrice,
                                    isDimensionBased: true,
                                    isBuiltIn: false,
                                    sortOrder: (dimensionTiers.last?.sortOrder ?? -1) + 1
                                ))
                                newWidth = 2.0; newHeight = 2.0; newDimensionPrice = 0
                                withAnimation(.easeInOut) { addingDimension = false }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if !addingDimension {
                    Button {
                        withAnimation(.easeInOut) { addingDimension = true }
                    } label: {
                        Label("Create New Dimension", systemImage: "plus")
                            .font(.subheadline)
                    }
                }
            } header: {
                Label("Flash — Dimension Based", systemImage: "ruler")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Financial")
        .onAppear {
            migrateLegacyTiers()
            ensureBuiltInFlashTiers()
        }
    }

    // MARK: - Helpers

    /// Fixes tiers created by the old session-rates view that have W×H labels
    /// but were never flagged as dimension-based.
    private func migrateLegacyTiers() {
        for tier in allFlashTiers where !tier.isDimensionBased && tier.label.contains("×") {
            tier.isDimensionBased = true
            tier.isBuiltIn = false
        }
    }

    /// Creates Small / Medium / Large built-in tiers on first launch.
    private func ensureBuiltInFlashTiers() {
        let existingLabels = Set(builtInTiers.map { $0.label })
        let defaults: [(label: String, price: Decimal, order: Int)] = [
            ("Small",  80,  0),
            ("Medium", 150, 1),
            ("Large",  250, 2),
        ]
        for item in defaults where !existingLabels.contains(item.label) {
            modelContext.insert(FlashPriceTier(
                label: item.label,
                price: item.price,
                isDimensionBased: false,
                isBuiltIn: true,
                sortOrder: item.order
            ))
        }
    }

    @ViewBuilder
    private func finRow<Input: View>(_ label: String, @ViewBuilder input: () -> Input) -> some View {
        HStack {
            Text(label).foregroundStyle(.primary)
            Spacer()
            input()
        }
    }
}

// MARK: - Size Based Flash Tier Row
// Label is always locked to Text. Price is controlled via +/- stepper.

private struct SizedFlashTierRow: View {
    @Bindable var tier: FlashPriceTier
    let currency: String
    let increment: Decimal

    var body: some View {
        HStack(spacing: 10) {
            Text(tier.label)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                tier.price = max(0, tier.price - increment)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text(tier.price, format: .currency(code: currency))
                .foregroundStyle(.secondary)
                .frame(minWidth: 72, alignment: .center)
                .font(.subheadline.monospacedDigit())

            Button {
                tier.price += increment
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Dimension Flash Tier Row
// Dimensions are read-only. Price field clears on tap so the user can type freely.

private struct DimensionFlashTierRow: View {
    @Bindable var tier: FlashPriceTier
    let currency: String

    @FocusState private var priceFocused: Bool
    @State private var displayText: String = ""

    var body: some View {
        HStack {
            Text(String(format: "%.1f\" × %.1f\"", tier.widthInches, tier.heightInches))
                .foregroundStyle(.primary)
            Spacer()
            TextField("", text: $displayText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 110)
                .focused($priceFocused)
        }
        .onAppear { displayText = formattedPrice }
        .onChange(of: priceFocused) { _, focused in
            if focused {
                displayText = ""            // clear on tap
            } else {
                commitPrice()               // parse on dismiss
                displayText = formattedPrice
            }
        }
    }

    private var formattedPrice: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        return f.string(from: NSDecimalNumber(decimal: tier.price)) ?? "0"
    }

    private func commitPrice() {
        let cleaned = displayText
            .filter { $0.isNumber || $0 == "." }
        if let d = Decimal(string: cleaned), d >= 0 {
            tier.price = d
        }
    }
}

// MARK: - Custom Discount Row

private struct DiscountRow: View {
    @Bindable var discount: Discount

    var body: some View {
        HStack {
            TextField("Discount Name", text: $discount.name)
            Spacer()
            TextField("0", value: $discount.percentage, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 50)
            Text("%").foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsViewFinancial()
    }
    .modelContainer(PreviewContainer.shared.container)
}
