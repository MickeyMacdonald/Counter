import SwiftUI
import UIKit

struct SettingsAppIconView: View {
    @State private var store = AppIconStore.shared

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        List {
            if !store.supportsAlternateIcons {
                unsupportedSection
            } else {
                iconGridSection
                if let error = store.lastError {
                    errorSection(error)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("App Icon")
        .onAppear {
            store.reload()
        }
    }

    private var unsupportedSection: some View {
        Section {
            Label {
                Text("Alternate app icons aren't supported on this device.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var iconGridSection: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(store.icons) { icon in
                    AppIconTile(
                        icon: icon,
                        isSelected: store.selected == icon,
                        isDisabled: store.isApplying
                    ) {
                        Task { @MainActor in await store.apply(icon) }
                    }
                }
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Tap an icon to apply it to the Home Screen.")
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            Text(message)
                .foregroundStyle(.red)
                .font(.footnote)
        }
    }
}

private struct AppIconTile: View {
    let icon: BuiltInAppIcon
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                AppIconThumbnailView(icon: icon)
                    .frame(width: 72, height: 72)
                    .overlay {
                        AppIconSquircle()
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

                Text(icon.displayName)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if isSelected {
                    Label("Selected", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel("\(icon.displayName) app icon")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct AppIconThumbnailView: View {
    let icon: BuiltInAppIcon

    var body: some View {
        Group {
            if let image = UIImage(named: icon.thumbnailAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.2)
                    .overlay {
                        Image(systemName: "app.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .clipShape(AppIconSquircle())
    }
}

/// iOS home-screen icon silhouette (continuous-corner superellipse approximation).
private struct AppIconSquircle: InsettableShape {
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

#Preview {
    NavigationStack {
        SettingsAppIconView()
    }
}
