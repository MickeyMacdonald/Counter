import Foundation
import SwiftData

@Model
final class UserProfile {
    var firstName: String
    var lastName: String
    var businessName: String
    var email: String
    var phone: String

    var profession: Profession
    var profilePhotoPath: String?

    var defaultHourlyRate: Decimal
    var currency: String

    // Deposits
    var depositFlat: Decimal = 0
    var depositPercentage: Decimal

    // Discounts (stored as 0–100 percentage off)
    var friendsFamilyDiscount: Decimal = 0
    var preferredClientDiscount: Decimal = 0
    var holidayDiscount: Decimal = 0
    var conventionDiscount: Decimal = 0

    // Fees
    var noShowFee: Decimal = 100
    var revisionFee: Decimal = 0
    var administrativeFee: Decimal = 0

    // Flash pricing (stored as raw string for SwiftData migration safety)
    var flashPricingModeRaw: String = "hourly"

    var chargeableSessionTypes: [String] = SessionType.defaultChargeableRawValues

    // Status colour overrides — keyed by PieceStatus.rawValue, values are colour names
    var statusColorNames: [String: String] = [:]

    // Shop address
    var shopAddressLine1: String = ""
    var shopAddressLine2: String = ""
    var shopCity: String = ""
    var shopState: String = ""
    var shopPostalCode: String = ""
    var shopCountry: String = ""

    // Billing address
    var billingAddressLine1: String = ""
    var billingAddressLine2: String = ""
    var billingCity: String = ""
    var billingState: String = ""
    var billingPostalCode: String = ""
    var billingCountry: String = ""

    var createdAt: Date
    var updatedAt: Date

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    var initialsDisplay: String {
        let first = firstName.first.map(String.init) ?? ""
        let last = lastName.first.map(String.init) ?? ""
        return "\(first)\(last)".uppercased()
    }

    /// Returns the stored chargeable types, falling back to defaults for migrated profiles.
    var effectiveChargeableSessionTypes: [String] {
        chargeableSessionTypes.isEmpty
            ? SessionType.defaultChargeableRawValues
            : chargeableSessionTypes
    }

    func isChargeable(_ sessionType: SessionType) -> Bool {
        effectiveChargeableSessionTypes.contains(sessionType.rawValue)
    }

    func setChargeable(_ sessionType: SessionType, _ chargeable: Bool) {
        if chargeable {
            if !chargeableSessionTypes.contains(sessionType.rawValue) {
                chargeableSessionTypes.append(sessionType.rawValue)
            }
        } else {
            chargeableSessionTypes.removeAll { $0 == sessionType.rawValue }
        }
    }

    /// One-line summary of the shop address, or nil if empty.
    var shopAddressSummary: String? {
        let parts = [shopAddressLine1, shopAddressLine2, shopCity, shopState, shopPostalCode, shopCountry]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// One-line summary of the billing address, or nil if empty.
    var billingAddressSummary: String? {
        let parts = [billingAddressLine1, billingAddressLine2, billingCity, billingState, billingPostalCode, billingCountry]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// True when every billing field matches the corresponding shop field.
    var billingMatchesShop: Bool {
        billingAddressLine1 == shopAddressLine1 &&
        billingAddressLine2 == shopAddressLine2 &&
        billingCity         == shopCity &&
        billingState        == shopState &&
        billingPostalCode   == shopPostalCode &&
        billingCountry      == shopCountry
    }

    init(
        firstName: String = "",
        lastName: String = "",
        businessName: String = "",
        email: String = "",
        phone: String = "",
        profession: Profession = .tattooer,
        defaultHourlyRate: Decimal = 150,
        depositPercentage: Decimal = 20,
        currency: String = "USD",
        noShowFee: Decimal = 100,
        chargeableSessionTypes: [String] = SessionType.defaultChargeableRawValues
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.businessName = businessName
        self.email = email
        self.phone = phone
        self.profession = profession
        self.defaultHourlyRate = defaultHourlyRate
        self.depositPercentage = depositPercentage
        self.currency = currency
        self.noShowFee = noShowFee
        self.chargeableSessionTypes = chargeableSessionTypes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum Profession: String, Codable, CaseIterable {
    case tattooer = "Tattooer"
    case tattooRemoval = "Tattoo Removal"
    case hairdresser = "Hairdresser"

    var systemImage: String {
        switch self {
        case .tattooer: "paintbrush.pointed.fill"
        case .tattooRemoval: "eraser.fill"
        case .hairdresser: "scissors"
        }
    }
}
