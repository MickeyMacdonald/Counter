import Foundation
import SwiftUI
import SwiftData

@Model
final class Payment {
    var amount: Decimal
    var paymentDate: Date
    var paymentMethod: PaymentMethod
    var paymentType: PaymentType
    var notes: String
    var createdAt: Date

    // Relationships
    var piece: Piece?
    var client: Client?

    init(
        amount: Decimal = 0,
        paymentDate: Date = Date(),
        paymentMethod: PaymentMethod = .cash,
        paymentType: PaymentType = .sessionPayment,
        notes: String = "",
        piece: Piece? = nil,
        client: Client? = nil
    ) {
        self.amount = amount
        self.paymentDate = paymentDate
        self.paymentMethod = paymentMethod
        self.paymentType = paymentType
        self.notes = notes
        self.piece = piece
        self.client = client
        self.createdAt = Date()
    }
}

enum PaymentMethod: String, Codable, CaseIterable {
    case cash = "Cash"
    case card = "Card"
    case eTransfer = "e-Transfer"
    case other = "Other"

    var systemImage: String {
        switch self {
        case .cash: "banknote"
        case .card: "creditcard"
        case .eTransfer: "arrow.left.arrow.right"
        case .other: "ellipsis.circle"
        }
    }
}

enum PaymentType: String, Codable, CaseIterable {
    case deposit = "Deposit"
    case sessionPayment = "Session Payment"
    case touchUpFee = "Touch-Up Fee"
    case noShowFee = "No-Show Fee"
    case tip = "Tip"
    case refund = "Refund"

    var systemImage: String {
        switch self {
        case .deposit: "arrow.down.circle"
        case .sessionPayment: "dollarsign.circle"
        case .touchUpFee: "bandage"
        case .noShowFee: "person.slash"
        case .tip: "heart.circle"
        case .refund: "arrow.uturn.backward.circle"
        }
    }
}
