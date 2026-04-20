import Foundation

// MARK: - Recovery Backup (Alpha Safety Net)
// Temporary backup format for alpha testers. Will be retired at release.

struct RecoveryBackup: Codable {
    let version: Int  // Schema version, start at 1
    let createdAt: Date
    let appVersion: String

    // All 18 model tables
    let clients: [ClientBackup]
    let pieces: [PieceBackup]
    let sessions: [SessionBackup]
    let sessionProgress: [SessionProgressBackup]
    let pieceImages: [PieceImageBackup]
    let inspirationImages: [PieceImageBackup]
    let bookings: [BookingBackup]
    let agreements: [AgreementBackup]
    let communicationLogs: [CommunicationLogBackup]
    let payments: [PaymentBackup]
    let profiles: [UserProfileBackup]
    let customSessionTypes: [SessionTypeBackup]
    let customEmailTemplates: [EmailTemplateBackup]
    let availabilitySlots: [AvailabilitySlotBackup]
    let availabilityOverrides: [AvailabilityOverrideBackup]
    let sessionRateConfigs: [SessionRateConfigBackup]
    let flashPriceTiers: [FlashPriceTierBackup]
    let customGalleryGroups: [GalleryGroupBackup]

    /// Added in the V2 schema slice (0.8.x). Optional so that backups
    /// written by pre-V2 builds still decode into the current
    /// `RecoveryBackup` shape — the field is simply absent in the
    /// JSON and will be `nil` after decoding. New backups always write
    /// a (possibly empty) array.
    ///
    /// Keep this field optional even after V2 has been live for a
    /// while. The `RecoveryBackup.currentVersion` bump that would let
    /// us require it is gated on the "forward migration of backups"
    /// task in pillar 1, which has not landed yet.
    let customDiscounts: [DiscountBackup]?

    let userDefaults: UserDefaultsBackup

    static let currentVersion = 1
}

// MARK: - Backup Metadata

/// Distinguishes user-initiated backups from snapshots taken automatically
/// before a destructive restore. Pre-restore snapshots are pruned on a
/// separate retention budget so they can't push real user backups out of
/// rotation.
enum BackupKind: String, Codable {
    case userBackup
    case preRestoreSnapshot
}

struct BackupMetadata: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let appVersion: String
    let modelCount: Int
    let imageCount: Int
    let jsonSizeBytes: UInt64
    let imageSizeBytes: UInt64
    let folderName: String

    /// SHA-256 (hex) of the `backup.json` payload at write time.
    /// Optional so backups written before integrity checking shipped still
    /// decode. On restore, when present, a mismatch aborts the restore
    /// before any destructive action runs.
    let jsonChecksum: String?

    /// `nil` is treated as `.userBackup` for backwards compatibility with
    /// metadata files written before pre-restore snapshots existed.
    let kind: BackupKind?

    var effectiveKind: BackupKind { kind ?? .userBackup }
}

// MARK: - UserDefaults Snapshot

struct UserDefaultsBackup: Codable {
    let businessLockEnabled: Bool?
    let businessLockPIN: String?
    let todoDismissedIDs: String?
    let pieceSizeMode: String?
    let dimensionUnit: String?
    let hasSeededDataV2: Bool?
    let hasSeededPayments: Bool?
    let hasSeededFlashPortfolio: Bool?
}

// MARK: - Recovery Error

enum RecoveryError: Error, LocalizedError {
    case serializationFailed(String)
    case deserializationFailed(String)
    case backupNotFound
    case imageCopyFailed(String)
    case restoreFailed(String)
    case versionMismatch(found: Int, expected: Int)
    case checksumMismatch(expected: String, actual: String)
    case refuseEmptyRestore
    case imageCountMismatch(expected: Int, actual: Int)
    case preRestoreSnapshotFailed(String)

    var errorDescription: String? {
        switch self {
        case .serializationFailed(let detail):
            return "Failed to serialize data: \(detail)"
        case .deserializationFailed(let detail):
            return "Failed to read backup: \(detail)"
        case .backupNotFound:
            return "The selected backup could not be found."
        case .imageCopyFailed(let detail):
            return "Failed to copy images: \(detail)"
        case .restoreFailed(let detail):
            return "Restore failed: \(detail)"
        case .versionMismatch(let found, let expected):
            return "Backup version \(found) is incompatible (expected \(expected))."
        case .checksumMismatch(let expected, let actual):
            return "Backup integrity check failed. The backup file may be corrupt or partially written. (expected \(expected.prefix(12))…, got \(actual.prefix(12))…)"
        case .refuseEmptyRestore:
            return "This backup contains zero records. Restoring it would erase your current data without putting anything in its place. Restore was aborted."
        case .imageCountMismatch(let expected, let actual):
            return "Image restore is incomplete: expected \(expected) image files, found \(actual). Restore aborted to avoid losing image references."
        case .preRestoreSnapshotFailed(let detail):
            return "Could not save a safety snapshot of your current data before restoring. Restore aborted. (\(detail))"
        }
    }
}

// MARK: - Model Backup Structs

struct ClientBackup: Codable {
    let backupID: UUID
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let notes: String
    let pronouns: String
    let birthdate: Date?
    let allergyNotes: String
    let streetAddress: String
    let city: String
    let state: String
    let zipCode: String
    let profilePhotoPath: String?
    let emailOptIn: Bool
    let isFlashPortfolioClient: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct PieceBackup: Codable {
    let backupID: UUID
    let clientBackupID: UUID?
    let title: String
    let bodyPlacement: String
    let descriptionText: String
    let status: String
    let pieceType: String
    let tags: [String]
    let primaryImagePath: String?
    let rating: Int?
    let size: String?
    let sizeDimensions: PieceDimensions?
    let hourlyRate: Decimal
    let flatRate: Decimal?
    let depositAmount: Decimal
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
}

struct SessionBackup: Codable {
    let backupID: UUID
    let pieceBackupID: UUID?
    let date: Date
    let startTime: Date
    let endTime: Date?
    let breakMinutes: Int
    let sessionType: String
    let hourlyRateAtTime: Decimal
    let flashRate: Decimal
    let manualHoursOverride: Double?
    let isNoShow: Bool
    let noShowFee: Decimal?
    let notes: String
}

struct SessionProgressBackup: Codable {
    let backupID: UUID
    let pieceBackupID: UUID?
    let sessionBackupID: UUID?
    let stage: String
    let notes: String
    let timeSpentMinutes: Int
    let createdAt: Date
}

struct PieceImageBackup: Codable {
    let backupID: UUID
    let imageGroupBackupID: UUID?
    let pieceBackupID: UUID?
    let filePath: String
    let fileName: String
    let notes: String
    let capturedAt: Date
    let sortOrder: Int
    let isPrimary: Bool
    let category: String?
    let tags: [String]
}

struct PieceImageBackup: Codable {
    let backupID: UUID
    let filePath: String
    let fileName: String
    let tags: [String]
    let notes: String
    let capturedAt: Date
}

struct BookingBackup: Codable {
    let backupID: UUID
    let clientBackupID: UUID?
    let pieceBackupID: UUID?
    let date: Date
    let startTime: Date
    let endTime: Date
    let status: String
    let bookingType: String
    let notes: String
    let depositPaid: Bool
    let reminderSent: Bool
    let checklistOverrides: [String]
    let customChecklistItems: [BookingCustomTask]
    let createdAt: Date
    let updatedAt: Date
}

struct AgreementBackup: Codable {
    let backupID: UUID
    let clientBackupID: UUID?
    let title: String
    let agreementType: String
    let bodyText: String
    let isSigned: Bool
    let signedAt: Date?
    let signatureImagePath: String?
    let createdAt: Date
}

struct CommunicationLogBackup: Codable {
    let backupID: UUID
    let clientBackupID: UUID?
    let commType: String
    let subject: String
    let bodyText: String
    let sentAt: Date
    let wasAutoGenerated: Bool
}

struct PaymentBackup: Codable {
    let backupID: UUID
    let clientBackupID: UUID?
    let pieceBackupID: UUID?
    let amount: Decimal
    let paymentDate: Date
    let paymentMethod: String
    let paymentType: String
    let notes: String
    let createdAt: Date
}

struct UserProfileBackup: Codable {
    let backupID: UUID
    let firstName: String
    let lastName: String
    let businessName: String
    let email: String
    let phone: String
    let profession: String
    let profilePhotoPath: String?
    let defaultHourlyRate: Decimal
    let currency: String
    let depositFlat: Decimal
    let depositPercentage: Decimal
    let friendsFamilyDiscount: Decimal
    let preferredClientDiscount: Decimal
    let holidayDiscount: Decimal
    let conventionDiscount: Decimal
    let noShowFee: Decimal
    let revisionFee: Decimal
    let administrativeFee: Decimal
    let flashPricingModeRaw: String
    let chargeableSessionTypes: [String]
    let statusColorNames: [String: String]
    let shopAddressLine1: String
    let shopAddressLine2: String
    let shopCity: String
    let shopState: String
    let shopPostalCode: String
    let shopCountry: String
    let billingAddressLine1: String
    let billingAddressLine2: String
    let billingCity: String
    let billingState: String
    let billingPostalCode: String
    let billingCountry: String
    let createdAt: Date
    let updatedAt: Date
}

struct SessionTypeBackup: Codable {
    let backupID: UUID
    let uuid: UUID
    let name: String
    let isChargeable: Bool
    let sortOrder: Int
    let createdAt: Date
}

struct EmailTemplateBackup: Codable {
    let backupID: UUID
    let name: String
    let subject: String
    let body: String
    let categoryRaw: String
    let createdAt: Date
    let updatedAt: Date
}

struct AvailabilitySlotBackup: Codable {
    let backupID: UUID
    let dayOfWeek: Int
    let startTime: Date
    let endTime: Date
    let slotTypeRaw: String
    let isFlashOnly: Bool
    let isActive: Bool
}

struct AvailabilityOverrideBackup: Codable {
    let backupID: UUID
    let startDate: Date
    let endDate: Date
    let reason: String
    let isUnavailable: Bool
}

struct SessionRateConfigBackup: Codable {
    let backupID: UUID
    let sessionTypeRaw: String
    let rateModeRaw: String
    let rateValue: Decimal
    let depositModeRaw: String
    let discountTypeRaw: String
    let feeTypeRaw: String
    let flashPricingModeRaw: String
}

struct FlashPriceTierBackup: Codable {
    let backupID: UUID
    let uuid: UUID
    let label: String
    let widthInches: Double
    let heightInches: Double
    let price: Decimal
    let sortOrder: Int
}

struct GalleryGroupBackup: Codable {
    let backupID: UUID
    let name: String
    let tags: [String]
    let sortIndex: Int
    let createdAt: Date
}

struct DiscountBackup: Codable {
    let backupID: UUID
    let name: String
    let percentage: Decimal
    let sortOrder: Int
}
