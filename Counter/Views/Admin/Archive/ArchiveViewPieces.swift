import SwiftUI
import SwiftData

struct ArchiveViewPieces: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Piece.updatedAt, order: .reverse) private var allPieces: [Piece]

    @State private var piecePendingDelete: Piece?

    private var archivedPieces: [Piece] {
        allPieces.filter { $0.status == .archived }
    }

    var body: some View {
        List {
            if archivedPieces.isEmpty {
                ContentUnavailableView(
                    "No Archived Pieces",
                    systemImage: "archivebox",
                    description: Text("Pieces you archive in the Work tab appear here.")
                )
            } else {
                ForEach(archivedPieces) { piece in
                    row(piece)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Archived Pieces")
        .confirmationDialog(
            "Permanently delete \"\(piecePendingDelete?.title ?? "this piece")\"?",
            isPresented: Binding(
                get: { piecePendingDelete != nil },
                set: { if !$0 { piecePendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                if let piece = piecePendingDelete {
                    modelContext.delete(piece)
                    try? modelContext.save()
                }
                piecePendingDelete = nil
            }
            Button("Cancel", role: .cancel) { piecePendingDelete = nil }
        } message: {
            Text("All sessions, payments, and images for this piece will be permanently deleted. This cannot be undone.")
        }
    }

    private func row(_ piece: Piece) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(piece.title)
                .font(.subheadline.weight(.medium))
            if let client = piece.client {
                Text(client.fullName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(piece.updatedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                piece.status = .concept
                piece.updatedAt = Date()
                try? modelContext.save()
            } label: {
                Label("Restore", systemImage: "tray.and.arrow.up")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                piecePendingDelete = piece
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    NavigationStack { ArchiveViewPieces() }
        .modelContainer(PreviewContainer.shared.container)
}
