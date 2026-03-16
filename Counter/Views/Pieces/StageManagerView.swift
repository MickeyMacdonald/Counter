import SwiftUI
import SwiftData

/// Manages adding/removing image stages for a piece.
/// Each stage (inspiration, lineart, shading, etc.) is an ImageGroup.
struct StageManagerView: View {
    @Bindable var piece: Piece
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var timeInput: [ImageStage: Int] = [:]

    private var existingStages: Set<ImageStage> {
        Set(piece.imageGroups.map(\.stage))
    }

    private var availableStages: [ImageStage] {
        ImageStage.allCases.filter { !existingStages.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Active stages
                Section("Active Stages") {
                    if piece.sortedImageGroups.isEmpty {
                        Text("No stages added yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(piece.sortedImageGroups) { group in
                            HStack {
                                Label(group.stage.rawValue, systemImage: group.stage.systemImage)
                                Spacer()
                                Text("\(group.images.count) images")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if group.timeSpentMinutes > 0 {
                                    Text(group.timeSpentFormatted)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    removeStage(group)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // Add stages
                if !availableStages.isEmpty {
                    Section("Add Stage") {
                        ForEach(availableStages, id: \.self) { stage in
                            Button {
                                addStage(stage)
                            } label: {
                                Label {
                                    Text(stage.rawValue)
                                        .foregroundStyle(.primary)
                                } icon: {
                                    Image(systemName: stage.systemImage)
                                }
                            }
                        }
                    }
                }

                // Quick-add all remaining
                if availableStages.count > 1 {
                    Section {
                        Button {
                            addAllStages()
                        } label: {
                            Label("Add All Remaining Stages", systemImage: "plus.circle.fill")
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .navigationTitle("Manage Stages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addStage(_ stage: ImageStage) {
        let group = ImageGroup(stage: stage)
        group.piece = piece
        modelContext.insert(group)
        piece.updatedAt = Date()
    }

    private func addAllStages() {
        for stage in availableStages {
            let group = ImageGroup(stage: stage)
            group.piece = piece
            modelContext.insert(group)
        }
        piece.updatedAt = Date()
    }

    private func removeStage(_ group: ImageGroup) {
        // Delete associated image files
        for image in group.images {
            Task {
                try? await ImageStorageService.shared.deleteImage(relativePath: image.filePath)
            }
        }
        modelContext.delete(group)
        piece.updatedAt = Date()
    }
}

#Preview {
    StageManagerView(piece: Piece(title: "Test Piece"))
        .modelContainer(PreviewContainer.shared.container)
}
