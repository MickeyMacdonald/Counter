import Foundation
import SwiftData

@Model
final class Client {
    var firstName: String
    var lastName: String
    var email: String
    var phone: String
    var notes: String

    var pronouns: String
    var birthdate: Date?
    var allergyNotes: String

    // Address
    var streetAddress: String
    var city: String
    var state: String
    var zipCode: String

    // Profile photo stored as file path relative to app documents
    var profilePhotoPath: String?

    // Flash Portfolio: this client is the artist's hidden flash inventory holder
    var isFlashPortfolioClient: Bool = false

    var createdAt: Date
    var updatedAt: Date

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Piece.client)
    var pieces: [Piece] = []

    @Relationship(deleteRule: .cascade, inverse: \Agreement.client)
    var agreements: [Agreement] = []

    @Relationship(deleteRule: .cascade, inverse: \CommunicationLog.client)
    var communicationLogs: [CommunicationLog] = []

    @Relationship(deleteRule: .cascade, inverse: \Payment.client)
    var payments: [Payment] = []

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    var initialsDisplay: String {
        let first = firstName.first.map(String.init) ?? ""
        let last = lastName.first.map(String.init) ?? ""
        return "\(first)\(last)".uppercased()
    }

    var totalSpent: Decimal {
        pieces.reduce(Decimal.zero) { $0 + $1.totalCost }
    }

    var totalPaymentsReceived: Decimal {
        payments.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var totalOutstanding: Decimal {
        pieces.reduce(Decimal.zero) { $0 + $1.outstandingBalance }
    }

    var totalHours: Double {
        pieces.reduce(0) { $0 + $1.totalHours }
    }

    func chargeableSpent(using chargeableTypes: [String]) -> Decimal {
        pieces.reduce(Decimal.zero) { $0 + $1.chargeableCost(using: chargeableTypes) }
    }

    func chargeableHours(using chargeableTypes: [String]) -> Double {
        pieces.reduce(0) { $0 + $1.chargeableHours(using: chargeableTypes) }
    }

    init(
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        phone: String = "",
        notes: String = "",
        pronouns: String = "",
        birthdate: Date? = nil,
        allergyNotes: String = "",
        streetAddress: String = "",
        city: String = "",
        state: String = "",
        zipCode: String = ""
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.notes = notes
        self.pronouns = pronouns
        self.birthdate = birthdate
        self.allergyNotes = allergyNotes
        self.streetAddress = streetAddress
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
