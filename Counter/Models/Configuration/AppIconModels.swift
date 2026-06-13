import SwiftUI
import UIKit

/// A built-in icon shipped in the asset catalog and registered in `AppIconInfo.plist`.
struct BuiltInAppIcon: Identifiable, Equatable, Codable {
    let id: String
    let displayName: String
    let subtitle: String
    /// Key passed to `setAlternateIconName`. `nil` restores the primary icon.
    let alternateName: String?
    let assetSetName: String
    let thumbnailAssetName: String

    static let classic = BuiltInAppIcon(
        id: "classic",
        displayName: "Classic",
        subtitle: "Default Counter icon",
        alternateName: nil,
        assetSetName: "CounterAppIcon",
        thumbnailAssetName: "AppIconThumbClassic"
    )

    static let catalog: [BuiltInAppIcon] = [
        .classic,
        BuiltInAppIcon(
            id: "ukraine",
            displayName: "Ukraine",
            subtitle: "Blue and yellow",
            alternateName: "Ukraine",
            assetSetName: "CounterAppIconUkraine",
            thumbnailAssetName: "AppIconThumbUkraine"
        ),
        BuiltInAppIcon(
            id: "xmas",
            displayName: "Holiday",
            subtitle: "Seasonal",
            alternateName: "Xmas",
            assetSetName: "CounterAppIconXmas",
            thumbnailAssetName: "AppIconThumbXmas"
        )
    ]
}

/// User-authored icon stored on disk with an assigned runtime slot.
struct CustomAppIcon: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var backgroundTopHex: String
    var backgroundBottomHex: String
    var usesGradient: Bool
    var logoColorHex: String
    var hasCustomLogo: Bool
    var customLogoScale: CGFloat
    /// Plist key such as `Custom03` — pre-registered alternate icon slot.
    let slotName: String
    let assetSetName: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, backgroundTopHex, backgroundBottomHex, usesGradient, logoColorHex
        case hasCustomLogo, customLogoScale, slotName, assetSetName, createdAt
    }

    init(
        id: UUID,
        name: String,
        backgroundTopHex: String,
        backgroundBottomHex: String,
        usesGradient: Bool,
        logoColorHex: String,
        hasCustomLogo: Bool = false,
        customLogoScale: CGFloat = 1,
        slotName: String,
        assetSetName: String,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.backgroundTopHex = backgroundTopHex
        self.backgroundBottomHex = backgroundBottomHex
        self.usesGradient = usesGradient
        self.logoColorHex = logoColorHex
        self.hasCustomLogo = hasCustomLogo
        self.customLogoScale = customLogoScale
        self.slotName = slotName
        self.assetSetName = assetSetName
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        backgroundTopHex = try container.decode(String.self, forKey: .backgroundTopHex)
        backgroundBottomHex = try container.decode(String.self, forKey: .backgroundBottomHex)
        usesGradient = try container.decode(Bool.self, forKey: .usesGradient)
        logoColorHex = try container.decode(String.self, forKey: .logoColorHex)
        hasCustomLogo = try container.decodeIfPresent(Bool.self, forKey: .hasCustomLogo) ?? false
        customLogoScale = try container.decodeIfPresent(CGFloat.self, forKey: .customLogoScale) ?? 1
        slotName = try container.decode(String.self, forKey: .slotName)
        assetSetName = try container.decode(String.self, forKey: .assetSetName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    var backgroundTop: Color { Color(hex: backgroundTopHex) ?? .gray }
    var backgroundBottom: Color { Color(hex: backgroundBottomHex) ?? .black }
    var logoColor: Color { Color(hex: logoColorHex) ?? .white }

    static let slotNames = (1...8).map { String(format: "Custom%02d", $0) }

    static func assetSetName(forSlot slotName: String) -> String {
        "CounterAppIcon\(slotName)"
    }
}

enum AppIconSelection: Equatable, Identifiable {
    case builtIn(BuiltInAppIcon)
    case custom(CustomAppIcon)

    var id: String {
        switch self {
        case .builtIn(let icon): "builtIn.\(icon.id)"
        case .custom(let icon): "custom.\(icon.id.uuidString)"
        }
    }

    var displayName: String {
        switch self {
        case .builtIn(let icon): icon.displayName
        case .custom(let icon): icon.name
        }
    }

    var alternateName: String? {
        switch self {
        case .builtIn(let icon): icon.alternateName
        case .custom(let icon): icon.slotName
        }
    }

    var isDeletable: Bool {
        if case .custom = self { return true }
        return false
    }

    static func builtIn(matching alternateName: String?) -> BuiltInAppIcon {
        BuiltInAppIcon.catalog.first { $0.alternateName == alternateName } ?? .classic
    }
}

extension Color {
    init?(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let value = UInt64(raw, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
