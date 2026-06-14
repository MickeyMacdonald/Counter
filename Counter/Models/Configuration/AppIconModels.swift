import Foundation

/// A built-in icon shipped as an Icon Composer `.icon` bundle and registered via the
/// target's `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` build setting.
struct BuiltInAppIcon: Identifiable, Equatable, Codable {
    let id: String
    let displayName: String
    let subtitle: String
    /// Key passed to `setAlternateIconName`. `nil` restores the primary icon.
    let alternateName: String?
    let thumbnailAssetName: String

    static let classic = BuiltInAppIcon(
        id: "classic",
        displayName: "Classic",
        subtitle: "Default Counter icon",
        alternateName: nil,
        thumbnailAssetName: "AppIconThumbClassic"
    )

    static let catalog: [BuiltInAppIcon] = [
        .classic,
        BuiltInAppIcon(
            id: "ukraine",
            displayName: "Ukraine",
            subtitle: "Blue and yellow",
            alternateName: "AppIconUkraine",
            thumbnailAssetName: "AppIconThumbUkraine"
        ),
        BuiltInAppIcon(
            id: "xmas",
            displayName: "Holiday",
            subtitle: "Seasonal",
            alternateName: "AppIconHoliday",
            thumbnailAssetName: "AppIconThumbXmas"
        ),
        BuiltInAppIcon(
            id: "pride",
            displayName: "Pride",
            subtitle: "Rainbow",
            alternateName: "AppIconPride",
            thumbnailAssetName: "AppIconThumbPride"
        )
    ]

    static func matching(alternateName: String?) -> BuiltInAppIcon {
        catalog.first { $0.alternateName == alternateName } ?? .classic
    }
}
