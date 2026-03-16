import Foundation
import SwiftData

@Model
final class Agreement {
    var title: String
    var agreementType: AgreementType
    var bodyText: String
    var isSigned: Bool
    var signedAt: Date?

    // Signature stored as image file path
    var signatureImagePath: String?

    var createdAt: Date

    // Relationships
    var client: Client?

    init(
        title: String = "",
        agreementType: AgreementType = .consent,
        bodyText: String = "",
        isSigned: Bool = false,
        signedAt: Date? = nil,
        signatureImagePath: String? = nil
    ) {
        self.title = title
        self.agreementType = agreementType
        self.bodyText = bodyText
        self.isSigned = isSigned
        self.signedAt = signedAt
        self.signatureImagePath = signatureImagePath
        self.createdAt = Date()
    }
}

enum AgreementType: String, Codable, CaseIterable {
    case consent = "Consent Form"
    case liability = "Liability Waiver"
    case photoRelease = "Photo Release"
    case designApproval = "Design Approval"
    case healedConfirmation = "Healed Confirmation"
    case custom = "Custom"

    var systemImage: String {
        switch self {
        case .consent: "doc.text.fill"
        case .liability: "shield.lefthalf.filled"
        case .photoRelease: "camera.badge.ellipsis"
        case .designApproval: "checkmark.seal.fill"
        case .healedConfirmation: "heart.text.square.fill"
        case .custom: "doc.badge.plus"
        }
    }
}
