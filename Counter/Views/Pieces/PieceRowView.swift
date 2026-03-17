import SwiftUI
import SwiftData

struct PieceRowView: View {
    let piece: Piece
    @Query private var profiles: [UserProfile]
    @AppStorage("pieceSizeMode") private var sizeMode:     PieceSizeMode = .categorical
    @AppStorage("dimensionUnit") private var dimensionUnit: DimensionUnit = .inches

    private var chargeableTypes: [String] {
        profiles.first?.effectiveChargeableSessionTypes ?? SessionType.defaultChargeableRawValues
    }

    private var sizeLabel: String? {
        switch sizeMode {
        case .categorical:  return piece.size?.rawValue
        case .dimensional:  return piece.sizeDimensions?.displayString(unit: dimensionUnit)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: piece.status.systemImage)
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(piece.title)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Text(piece.bodyPlacement)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if piece.sessions.count > 0 {
                        Text("\(String(format: "%.1f", piece.chargeableHours(using: chargeableTypes)))h")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(piece.status.rawValue)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.primary.opacity(0.08), in: Capsule())

                if let label = sizeLabel {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let rating = piece.rating {
                    HStack(spacing: 1) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 8))
                                .foregroundStyle(star <= rating ? .yellow : Color.gray.opacity(0.3))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        PieceRowView(piece: Piece(
            title: "Botanical Sleeve",
            bodyPlacement: "Left forearm",
            status: .inProgress,
            hourlyRate: 175
        ))
        PieceRowView(piece: Piece(
            title: "Dagger Traditional",
            bodyPlacement: "Right calf",
            status: .completed
        ))
    }
    .modelContainer(PreviewContainer.shared.container)
}
