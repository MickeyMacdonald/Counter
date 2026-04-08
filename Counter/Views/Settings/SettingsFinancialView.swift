import SwiftUI
import SwiftData

// MARK: - Entry Point

struct SettingsFinancialView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if let profile = profiles.first {
            FinancialContent(profile: profile)
        } else {
            noProfileView
                .navigationTitle("Financial")
        }
    }
}

// MARK: - Content

private struct FinancialContent: View {
    @Bindable var profile: UserProfile
    @Query(sort: \CustomDiscount.sortOrder) private var customDiscounts: [CustomDiscount]
    @Query(sort: \FlashPriceTier.sortOrder) private var allFlashTiers: [FlashPriceTier]
    @Environment(\.modelContext) private var modelContext

    // New-dimension inline form state
    @State private var addingDimension = false
    @State private var newWidth: Double = 2.0
    @State private var newHeight: Double = 2.0
    @State private var newDimensionPrice: Decimal = 0

    private static let locales = ["CAD", "USD", "AUD", "EUR", "GBP"]

    private var namedTiers: [FlashPriceTier] { allFlashTiers.filter { !$0.isDimensionBased } }
    private var builtInTiers: [FlashPriceTier] { namedTiers.filter { $0.isBuiltIn } }
    private var customNamedTiers: [FlashPriceTier] { namedTiers.filter { !$0.isBuiltIn } }
    private var dimensionTiers: [FlashPriceTier] { allFlashTiers.filter { $0.isDimensionBased } }

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
                    CustomDiscountRow(discount: discount)
                }
                .onDelete { indexSet in
                    indexSet.map { customDiscounts[$0] }.forEach { modelContext.delete($0) }
                }

                Button {
                    withAnimation {
                        modelContext.insert(CustomDiscount(sortOrder: customDiscounts.count))
                    }
                } label: {
                    Label("Create New", systemImage: "plus")
                        .font(.subheadline)
                }
            }

            // MARK: Flash — Size Based
            Section {
                // Built-in tiers (Small / Medium / Large) — label fixed, price editable
                ForEach(builtInTiers) { tier in
                    NamedFlashTierRow(tier: tier, currency: profile.currency, nameEditable: false)
                }

                // Custom named tiers — both label and price editable, swipe-to-delete
                ForEach(customNamedTiers) { tier in
                    NamedFlashTierRow(tier: tier, currency: profile.currency, nameEditable: true)
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
        .onAppear { ensureBuiltInFlashTiers() }
    }

    // MARK: - Helpers

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

// MARK: - Named Flash Tier Row

private struct NamedFlashTierRow: View {
    @Bindable var tier: FlashPriceTier
    let currency: String
    let nameEditable: Bool

    var body: some View {
        HStack {
            if nameEditable {
                TextField("Size Name", text: $tier.label)
            } else {
                Text(tier.label)
            }
            Spacer()
            TextField("0", value: $tier.price, format: .currency(code: currency))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 100)
        }
    }
}

// MARK: - Dimension Flash Tier Row

private struct DimensionFlashTierRow: View {
    @Bindable var tier: FlashPriceTier
    let currency: String

    var body: some View {
        HStack {
            Text(String(format: "%.1f\" × %.1f\"", tier.widthInches, tier.heightInches))
                .foregroundStyle(.primary)
            Spacer()
            TextField("0", value: $tier.price, format: .currency(code: currency))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 100)
        }
    }
}

// MARK: - Custom Discount Row

private struct CustomDiscountRow: View {
    @Bindable var discount: CustomDiscount

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
        SettingsFinancialView()
    }
    .modelContainer(PreviewContainer.shared.container)
}
