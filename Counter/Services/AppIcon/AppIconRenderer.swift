import SwiftUI
import UIKit

enum AppIconRenderer {
    static let exportSize: CGFloat = 1024
    static let logoPaddingFraction: CGFloat = 0.18
    /// Counter mark renders 50% larger than the base fit area.
    static let counterLogoScale: CGFloat = 1.5

    struct Style: Equatable {
        var backgroundTop: Color
        var backgroundBottom: Color
        var usesGradient: Bool
        var logoColor: Color
        var customLogoImage: UIImage?
        /// Custom logo scale from 0–2 (0–200%).
        var customLogoScale: CGFloat

        init(
            backgroundTop: Color = Color(white: 0.92),
            backgroundBottom: Color = Color(white: 0.72),
            usesGradient: Bool = true,
            logoColor: Color = .black,
            customLogoImage: UIImage? = nil,
            customLogoScale: CGFloat = 1
        ) {
            self.backgroundTop = backgroundTop
            self.backgroundBottom = backgroundBottom
            self.usesGradient = usesGradient
            self.logoColor = logoColor
            self.customLogoImage = customLogoImage
            self.customLogoScale = customLogoScale
        }

        init(custom icon: CustomAppIcon) {
            let customLogo: UIImage?
            if icon.hasCustomLogo,
               let data = try? Data(contentsOf: AppIconStorage.customLogoURL(for: icon.id)) {
                customLogo = UIImage(data: data)
            } else {
                customLogo = nil
            }

            self.init(
                backgroundTop: icon.backgroundTop,
                backgroundBottom: icon.backgroundBottom,
                usesGradient: icon.usesGradient,
                logoColor: icon.logoColor,
                customLogoImage: customLogo,
                customLogoScale: icon.customLogoScale
            )
        }

        static func == (lhs: Style, rhs: Style) -> Bool {
            lhs.backgroundTop == rhs.backgroundTop
                && lhs.backgroundBottom == rhs.backgroundBottom
                && lhs.usesGradient == rhs.usesGradient
                && lhs.logoColor == rhs.logoColor
                && lhs.customLogoScale == rhs.customLogoScale
                && lhs.customLogoImage?.pngData() == rhs.customLogoImage?.pngData()
        }
    }

    @MainActor
    static func renderPNG(style: Style) -> UIImage? {
        let size = CGSize(width: exportSize, height: exportSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            if style.usesGradient {
                let colors = [
                    UIColor(style.backgroundTop).cgColor,
                    UIColor(style.backgroundBottom).cgColor
                ] as CFArray
                guard let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: [0, 1]
                ) else { return }
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.midX, y: rect.minY),
                    end: CGPoint(x: rect.midX, y: rect.maxY),
                    options: []
                )
            } else {
                UIColor(style.backgroundTop).setFill()
                context.fill(rect)
            }

            let padding = exportSize * Self.logoPaddingFraction
            let logoRect = rect.insetBy(dx: padding, dy: padding)

            if let customLogo = style.customLogoImage {
                let normalized = customLogo.normalized()
                normalized.draw(in: scaledAspectFitRect(
                    for: normalized.size,
                    in: logoRect,
                    scale: style.customLogoScale
                ))
            } else if let templateLogo = UIImage(named: "AppLogoMark") {
                let tinted = templateLogo.withTintColor(UIColor(style.logoColor), renderingMode: .alwaysOriginal)
                tinted.draw(in: scaledAspectFitRect(
                    for: templateLogo.size,
                    in: logoRect,
                    scale: Self.counterLogoScale
                ))
            }
        }
    }

    @MainActor
    static func thumbnailImage(for selection: AppIconSelection) -> UIImage? {
        switch selection {
        case .builtIn(let icon):
            return UIImage(named: icon.thumbnailAssetName)
        case .custom(let icon):
            let url = AppIconStorage.thumbnailURL(for: icon.id)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }
    }

    private static func aspectFitRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let fitScale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * fitScale, height: imageSize.height * fitScale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func scaledAspectFitRect(for imageSize: CGSize, in bounds: CGRect, scale: CGFloat) -> CGRect {
        let fit = aspectFitRect(for: imageSize, in: bounds)
        let width = fit.width * scale
        let height = fit.height * scale
        return CGRect(
            x: fit.midX - width / 2,
            y: fit.midY - height / 2,
            width: width,
            height: height
        )
    }
}

/// iOS home-screen icon silhouette (continuous-corner superellipse approximation).
struct AppIconSquircle: InsettableShape {
    /// Corner radius ratio used by Apple's app icon mask.
    static let cornerRadiusFraction: CGFloat = 0.2237

    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let radius = min(insetRect.width, insetRect.height) * Self.cornerRadiusFraction
        return Path(roundedRect: insetRect, cornerRadius: radius, style: .continuous)
    }

    func inset(by amount: CGFloat) -> AppIconSquircle {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

struct AppIconCanvas: View {
    let style: AppIconRenderer.Style
    var applySquircleMask: Bool
    var size: CGFloat

    init(style: AppIconRenderer.Style, applySquircleMask: Bool, size: CGFloat = AppIconRenderer.exportSize) {
        self.style = style
        self.applySquircleMask = applySquircleMask
        self.size = size
    }

    var body: some View {
        ZStack {
            background
                .frame(width: size, height: size)
            logo
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .modifier(AppIconSquircleClipModifier(enabled: applySquircleMask))
    }

    private var logoPadding: CGFloat {
        size * AppIconRenderer.logoPaddingFraction
    }

    @ViewBuilder
    private var logo: some View {
        if let customLogo = style.customLogoImage {
            Image(uiImage: customLogo.normalized())
                .resizable()
                .scaledToFit()
                .padding(logoPadding)
                .scaleEffect(style.customLogoScale)
        } else {
            Image("AppLogoMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(style.logoColor)
                .padding(logoPadding)
                .scaleEffect(AppIconRenderer.counterLogoScale)
        }
    }

    @ViewBuilder
    private var background: some View {
        if style.usesGradient {
            LinearGradient(
                colors: [style.backgroundTop, style.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            style.backgroundTop
        }
    }
}

private struct AppIconSquircleClipModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.clipShape(AppIconSquircle())
        } else {
            content
        }
    }
}

enum AppIconStorage {
    private static let folderName = "CustomAppIcons"

    static var rootURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func iconFolder(for id: UUID) -> URL {
        rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func thumbnailURL(for id: UUID) -> URL {
        iconFolder(for: id).appendingPathComponent("thumbnail.png")
    }

    static func customLogoURL(for id: UUID) -> URL {
        iconFolder(for: id).appendingPathComponent("custom-logo.png")
    }

    static func manifestURL() -> URL {
        rootURL.appendingPathComponent("manifest.json")
    }

    static func slotAssetFolder(for slotName: String) -> URL {
        rootURL
            .appendingPathComponent("SlotAssets", isDirectory: true)
            .appendingPathComponent(slotName, isDirectory: true)
    }
}

extension UIImage {
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
