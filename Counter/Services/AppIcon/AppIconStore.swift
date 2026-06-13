import Foundation
import UIKit

@MainActor
@Observable
final class AppIconStore {
    static let shared = AppIconStore()

    private(set) var selected: BuiltInAppIcon = .classic
    var isApplying = false
    var lastError: String?

    private let selectionKey = "app.selectedIcon.v2"

    init() {
        reload()
    }

    func reload() {
        selected = restoreSelection()
    }

    var icons: [BuiltInAppIcon] {
        BuiltInAppIcon.catalog
    }

    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    func apply(_ icon: BuiltInAppIcon) async {
        guard supportsAlternateIcons else { return }
        isApplying = true
        lastError = nil
        defer { isApplying = false }

        do {
            try await AppIconService.applyAlternateIcon(named: icon.alternateName)
            selected = icon
            UserDefaults.standard.set("builtIn.\(icon.id)", forKey: selectionKey)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func syncStoredSelectionIfNeeded() async {
        let restored = restoreSelection()
        guard restored.alternateName != UIApplication.shared.alternateIconName else { return }
        await apply(restored)
    }

    private func restoreSelection() -> BuiltInAppIcon {
        guard let raw = UserDefaults.standard.string(forKey: selectionKey),
              raw.hasPrefix("builtIn.") else {
            return BuiltInAppIcon.matching(alternateName: UIApplication.shared.alternateIconName)
        }

        let id = String(raw.dropFirst("builtIn.".count))
        return BuiltInAppIcon.catalog.first { $0.id == id }
            ?? BuiltInAppIcon.matching(alternateName: UIApplication.shared.alternateIconName)
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
