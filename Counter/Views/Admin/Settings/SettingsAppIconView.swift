import SwiftUI

struct SettingsAppIconView: View {
    @State private var store = AppIconStore.shared
    @State private var showingEditor = false
    @State private var iconPendingDelete: CustomAppIcon?

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    private var canAddCustomIcon: Bool {
        store.customIcons.count < CustomAppIcon.slotNames.count
    }

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
        .navigationDestination(isPresented: $showingEditor) {
            AppIconEditorView {
                store.reload()
            }
        }
        .confirmationDialog(
            "Delete this custom icon?",
            isPresented: Binding(
                get: { iconPendingDelete != nil },
                set: { if !$0 { iconPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let icon = iconPendingDelete else { return }
                iconPendingDelete = nil
                Task { @MainActor in await store.deleteCustomIcon(icon) }
            }
            Button("Cancel", role: .cancel) {
                iconPendingDelete = nil
            }
        } message: {
            Text("Built-in icons cannot be deleted.")
        }
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
                ForEach(store.allIcons) { selection in
                    AppIconTile(
                        selection: selection,
                        isSelected: store.selected == selection,
                        isDisabled: store.isApplying
                    ) {
                        Task { @MainActor in await store.apply(selection) }
                    } onDelete: {
                        if case .custom(let icon) = selection {
                            iconPendingDelete = icon
                        }
                    }
                }

                if canAddCustomIcon {
                    AddAppIconTile(isDisabled: store.isApplying) {
                        showingEditor = true
                    }
                }
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Tap an icon to apply it. Create a custom icon with the Counter logo or your own PNG.")
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
    let selection: AppIconSelection
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                AppIconThumbnailView(selection: selection)
                    .frame(width: 72, height: 72)
                    .overlay {
                        AppIconSquircle()
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

                Text(selection.displayName)
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
        .contextMenu {
            if selection.isDeletable {
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
        .accessibilityLabel("\(selection.displayName) app icon")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct AppIconThumbnailView: View {
    let selection: AppIconSelection

    var body: some View {
        Group {
            if let image = AppIconRenderer.thumbnailImage(for: selection) {
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

private struct AddAppIconTile: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                AppIconSquircle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .foregroundStyle(Color.accentColor.opacity(0.6))
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                Text("New Icon")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel("Create new app icon")
    }
}

#Preview {
    NavigationStack {
        SettingsAppIconView()
    }
}
