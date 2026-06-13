import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class AppIconStore {
    static let shared = AppIconStore()

    private(set) var customIcons: [CustomAppIcon] = []
    private(set) var selected: AppIconSelection = .builtIn(.classic)
    var isApplying = false
    var lastError: String?

    private let selectionKey = "app.selectedIcon.v2"

    init() {
        reload()
    }

    func reload() {
        customIcons = loadCustomIcons()
        selected = restoreSelection()
    }

    var allIcons: [AppIconSelection] {
        BuiltInAppIcon.catalog.map { .builtIn($0) } + customIcons.map { .custom($0) }
    }

    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    func apply(_ selection: AppIconSelection) async {
        guard supportsAlternateIcons else { return }
        isApplying = true
        lastError = nil
        defer { isApplying = false }

        do {
            try await AppIconService.applyAlternateIcon(named: selection.alternateName)
            self.selected = selection
            persistSelection(selection)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func saveCustomIcon(
        name: String,
        backgroundTop: Color,
        backgroundBottom: Color,
        usesGradient: Bool,
        logoColor: Color,
        customLogo: UIImage?,
        customLogoScale: CGFloat = 1
    ) async throws -> CustomAppIcon {
        guard let slot = nextAvailableSlot() else { throw AppIconError.noAvailableSlots }

        let style = AppIconRenderer.Style(
            backgroundTop: backgroundTop,
            backgroundBottom: backgroundBottom,
            usesGradient: usesGradient,
            logoColor: logoColor,
            customLogoImage: customLogo,
            customLogoScale: customLogoScale
        )

        guard let image = AppIconRenderer.renderPNG(style: style),
              let png = image.pngData() else {
            throw AppIconError.renderFailed
        }

        let icon = CustomAppIcon(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            backgroundTopHex: backgroundTop.hexString,
            backgroundBottomHex: backgroundBottom.hexString,
            usesGradient: usesGradient,
            logoColorHex: logoColor.hexString,
            hasCustomLogo: customLogo != nil,
            customLogoScale: customLogo != nil ? customLogoScale : 1,
            slotName: slot,
            assetSetName: CustomAppIcon.assetSetName(forSlot: slot),
            createdAt: Date()
        )

        let folder = AppIconStorage.iconFolder(for: icon.id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: AppIconStorage.thumbnailURL(for: icon.id))

        if let customLogo, let logoPNG = customLogo.normalized().pngData() {
            try logoPNG.write(to: AppIconStorage.customLogoURL(for: icon.id))
        }

        try writeSlotRender(png: png, slotName: slot, assetSetName: icon.assetSetName)

        customIcons.append(icon)
        try persistCustomIcons()

        await apply(.custom(icon))
        return icon
    }

    func deleteCustomIcon(_ icon: CustomAppIcon) async {
        customIcons.removeAll { $0.id == icon.id }
        try? FileManager.default.removeItem(at: AppIconStorage.iconFolder(for: icon.id))
        try? persistCustomIcons()

        if selected == .custom(icon) {
            await apply(.builtIn(.classic))
        }
    }

    func syncStoredSelectionIfNeeded() async {
        let restored = restoreSelection()
        guard restored.alternateName != currentAlternateName else { return }
        await apply(restored)
    }

    private var currentAlternateName: String? {
        UIApplication.shared.alternateIconName
    }

    private func nextAvailableSlot() -> String? {
        let used = Set(customIcons.map(\.slotName))
        return CustomAppIcon.slotNames.first { !used.contains($0) }
    }

    private func restoreSelection() -> AppIconSelection {
        guard let raw = UserDefaults.standard.string(forKey: selectionKey) else {
            return .builtIn(AppIconSelection.builtIn(matching: UIApplication.shared.alternateIconName))
        }
        if raw.hasPrefix("builtIn.") {
            let id = String(raw.dropFirst("builtIn.".count))
            if let icon = BuiltInAppIcon.catalog.first(where: { $0.id == id }) {
                return .builtIn(icon)
            }
        }
        if raw.hasPrefix("custom.") {
            let idString = String(raw.dropFirst("custom.".count))
            if let uuid = UUID(uuidString: idString),
               let icon = customIcons.first(where: { $0.id == uuid }) {
                return .custom(icon)
            }
        }
        return .builtIn(AppIconSelection.builtIn(matching: UIApplication.shared.alternateIconName))
    }

    private func persistSelection(_ selection: AppIconSelection) {
        switch selection {
        case .builtIn(let icon):
            UserDefaults.standard.set("builtIn.\(icon.id)", forKey: selectionKey)
        case .custom(let icon):
            UserDefaults.standard.set("custom.\(icon.id.uuidString)", forKey: selectionKey)
        }
    }

    private func loadCustomIcons() -> [CustomAppIcon] {
        guard let data = try? Data(contentsOf: AppIconStorage.manifestURL()) else { return [] }
        return (try? JSONDecoder().decode([CustomAppIcon].self, from: data)) ?? []
    }

    private func persistCustomIcons() throws {
        let data = try JSONEncoder().encode(customIcons)
        try data.write(to: AppIconStorage.manifestURL(), options: .atomic)
    }

    private func writeSlotRender(png: Data, slotName: String, assetSetName: String) throws {
        let folder = AppIconStorage.slotAssetFolder(for: slotName)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for filename in ["AppIcon.png", "AppIconDark.png", "AppIconTintedDark.png"] {
            try png.write(to: folder.appendingPathComponent(filename))
        }

        let marker = """
        {
          "slotName": "\(slotName)",
          "assetSetName": "\(assetSetName)",
          "updatedAt": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """
        try marker.write(to: folder.appendingPathComponent("slot.json"), atomically: true, encoding: .utf8)
    }
}

enum AppIconService {
    @MainActor
    static func applyAlternateIcon(named alternateName: String?) async throws {
        guard UIApplication.shared.alternateIconName != alternateName else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIApplication.shared.setAlternateIconName(alternateName) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

enum AppIconError: LocalizedError {
    case noAvailableSlots
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .noAvailableSlots: "All custom icon slots are in use. Delete one to add another."
        case .renderFailed: "Could not render the icon image."
        }
    }
}
