import Foundation
import SwiftData

/// Stores per-session-type rate configuration.
/// Key: `SessionType.rawValue` for built-in types; `uuid.uuidString` for custom types.
@Model
final class SessionRateConfig {

    var sessionTypeRaw: String

    // MARK: - Rate
    /// "inherited" uses the artist's default hourly rate. "custom" uses rateValue.
    var rateModeRaw: String
    var rateValue: Decimal

    // MARK: - Deposit
    /// Which global deposit applies to this session type.
    /// "notApplicable" | "flat" | "percentage" | "waived"
    /// The actual values come from UserProfile.depositFlat / depositPercentage.
    var depositModeRaw: String

    // MARK: - Discount
    /// Which named global discount applies.
    /// "none" | "friendsFamily" | "preferredClient" | "holiday" | "convention"
    var discountTypeRaw: String

    // MARK: - Fee
    /// Which named global fee applies.
    /// "none" | "noShow" | "revision" | "administrative"
    var feeTypeRaw: String

    // MARK: - Flash-specific
    /// Only relevant when sessionTypeRaw == SessionType.flash.rawValue.
    /// "hourly" | "sizeBased"
    var flashPricingModeRaw: String

    init(sessionTypeRaw: String) {
        self.sessionTypeRaw      = sessionTypeRaw
        self.rateModeRaw         = "inherited"
        self.rateValue           = 0
        self.depositModeRaw      = "notApplicable"
        self.discountTypeRaw     = "none"
        self.feeTypeRaw          = "none"
        self.flashPricingModeRaw = "hourly"
    }
}
