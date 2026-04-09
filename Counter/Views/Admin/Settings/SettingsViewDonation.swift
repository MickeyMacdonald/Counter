import SwiftUI
import StoreKit

// MARK: - Settings Donation View

struct SettingsViewDonation: View {
    @State private var store = DonationStore()
    @State private var activePurchase: DonationStore.ProductID?
    @State private var thankYouIDs: Set<String> = []
    @State private var showingThankYou = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.bottom, 28)

                VStack(spacing: 14) {
                    freeTierCard
                    flatDonationCard
                    monthlyCard
                    perTattooCard
                }
                .padding(.horizontal)

                footer
                    .padding(.top, 32)
                    .padding(.bottom, 40)
            }
            .padding(.top, 20)
        }
        .navigationTitle("Support Counter")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thank You ♥", isPresented: $showingThankYou) {
            Button("You're welcome", role: .cancel) { }
        } message: {
            Text("Seriously, this means a lot. Counter stays independent because of people like you.")
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { store.purchaseError != nil },
            set: { if !$0 { store.purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(store.purchaseError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.1))
                    .frame(width: 80, height: 80)
                Text("☕️")
                    .font(.system(size: 38))
            }

            Text("Counter is free. For real.")
                .font(.title2.weight(.bold))

            Text("No subscriptions required. No paywalls. No data harvesting.\nI built this because I needed it, and I figured you might too.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Tier Cards

    private var freeTierCard: some View {
        DonationTierCard(
            icon: "infinity",
            iconColor: .primary,
            title: "Free Forever",
            price: "$0.00",
            priceDetail: "always",
            description: "Every feature, every update, no charge. I'm not going to hold your client list hostage. Counter is yours.",
            footnote: "Though if you find yourself saving time and making money with this, throwing a dollar into the jar would genuinely make my day.",
            buttonLabel: "You're already in",
            buttonStyle: .plain,
            isLoading: false,
            isThanked: false,
            action: nil
        )
    }

    private var flatDonationCard: some View {
        let product = store.product(for: .flat)
        let isThanked = thankYouIDs.contains(DonationStore.ProductID.flat.rawValue)
        return DonationTierCard(
            icon: "mug.fill",
            iconColor: .brown,
            title: "Buy Me a Beer",
            price: product?.displayPrice ?? "$4.99",
            priceDetail: "once",
            description: "A one-time thank-you. Covers approximately one (1) cold beverage, which I will drink while fixing bugs at midnight.",
            footnote: nil,
            buttonLabel: isThanked ? "Cheers ♥" : "Send a beer",
            buttonStyle: .primary,
            isLoading: activePurchase == .flat,
            isThanked: isThanked,
            action: product == nil ? nil : {
                await purchase(.flat, product: product!)
            }
        )
    }

    private var monthlyCard: some View {
        let product = store.product(for: .monthly)
        let isThanked = thankYouIDs.contains(DonationStore.ProductID.monthly.rawValue)
        return DonationTierCard(
            icon: "calendar.badge.checkmark",
            iconColor: .blue,
            title: "Monthly Support",
            price: product?.displayPrice ?? "$1.99",
            priceDetail: "/ month",
            description: "Slip me a few bucks a month. It helps me keep developing features instead of finding a real job.",
            footnote: "Cancel any time from your App Store subscriptions. No hard feelings.",
            buttonLabel: isThanked ? "Subscribed ♥" : "Support monthly",
            buttonStyle: .primary,
            isLoading: activePurchase == .monthly,
            isThanked: isThanked,
            action: product == nil ? nil : {
                await purchase(.monthly, product: product!)
            }
        )
    }

    private var perTattooCard: some View {
        let product = store.product(for: .perTattoo)
        let isThanked = thankYouIDs.contains(DonationStore.ProductID.perTattoo.rawValue)
        return DonationTierCard(
            icon: "bolt.fill",
            iconColor: .orange,
            title: "Tip Per Session",
            price: product?.displayPrice ?? "$0.99",
            priceDetail: "per tip",
            description: "Every time Counter helps you land a booking, throw a coin in the jar. Like a tip, but for the app that helped you get the tip.",
            footnote: "You control when. Tap whenever it feels right.",
            buttonLabel: isThanked ? "Tipped ♥" : "Drop a tip",
            buttonStyle: .primary,
            isLoading: activePurchase == .perTattoo,
            isThanked: isThanked,
            action: product == nil ? nil : {
                await purchase(.perTattoo, product: product!)
            }
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Restore Purchases") {
                Task {
                    try? await AppStore.sync()
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
    }

    // MARK: - Purchase Handler

    private func purchase(_ id: DonationStore.ProductID, product: Product) async {
        activePurchase = id
        let result = await store.purchase(product)
        activePurchase = nil
        if case .success = result {
            thankYouIDs.insert(id.rawValue)
            showingThankYou = true
        }
    }
}

// MARK: - Donation Tier Card

private struct DonationTierCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let price: String
    let priceDetail: String
    let description: String
    let footnote: String?
    let buttonLabel: String
    let buttonStyle: CardButtonStyle
    let isLoading: Bool
    let isThanked: Bool
    let action: (() async -> Void)?

    enum CardButtonStyle { case plain, primary }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(price)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(iconColor)
                        Text(priceDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            // Description
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Button
            if let action {
                actionButton(action: action)
            } else {
                // Free tier — no action
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(buttonLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func actionButton(action: @escaping () async -> Void) -> some View {
        let label = HStack(spacing: 6) {
            if isLoading {
                ProgressView().scaleEffect(0.75)
            } else if isThanked {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
            }
            Text(buttonLabel)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)

        if buttonStyle == .primary {
            Button { Task { await action() } } label: { label }
                .buttonStyle(.borderedProminent)
                .tint(isThanked ? .green : iconColor)
                .disabled(isLoading)
        } else {
            Button { Task { await action() } } label: { label }
                .buttonStyle(.bordered)
                .tint(isThanked ? .green : iconColor)
                .disabled(isLoading)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsViewDonation()
    }
    .modelContainer(PreviewContainer.shared.container)
}
