import StoreKit
import Foundation

/// Manages StoreKit products and purchases for Counter's support tiers.
@Observable
final class DonationStore {

    // MARK: - Product IDs

    enum ProductID: String, CaseIterable {
        case flat       = "counter.support.flat"
        case monthly    = "counter.support.monthly"
        case perTattoo  = "counter.support.pertattoo"
    }

    // MARK: - State

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    var isLoading = false
    var purchaseError: String?

    @ObservationIgnored
    private var transactionListener: Task<Void, Never>?

    // MARK: - Init

    init() {
        transactionListener = startListeningForTransactions()
        Task { await loadProducts() }
    }

    deinit { transactionListener?.cancel() }

    // MARK: - Products

    func product(for id: ProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    @MainActor
    func loadProducts() async {
        isLoading = true
        purchaseError = nil
        do {
            let fetched = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Couldn't load products: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Purchase

    @MainActor
    func purchase(_ product: Product) async -> PurchaseResult {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("Purchase could not be verified.")
                }
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
                return .success
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Unknown purchase result.")
            }
        } catch {
            purchaseError = error.localizedDescription
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Transaction Listener

    private func startListeningForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if case .verified(let transaction) = result {
                    await MainActor.run {
                        _ = self.purchasedProductIDs.insert(transaction.productID)
                    }
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Result

    enum PurchaseResult {
        case success
        case cancelled
        case pending
        case failed(String)
    }
}
