import SwiftUI

struct ClientRowView: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            initialsCircle

            VStack(alignment: .leading, spacing: 2) {
                Text(client.fullName)
                    .font(.body.weight(.medium))

                if !client.email.isEmpty {
                    Text(client.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !client.pieces.isEmpty {
                Text("\(client.pieces.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var initialsCircle: some View {
        ZStack {
            Circle()
                .fill(.primary.opacity(0.1))
                .frame(width: 40, height: 40)

            Text(client.initialsDisplay)
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    let container = PreviewContainer.shared.container
    List {
        ClientRowView(client: Client(firstName: "Alex", lastName: "Rivera", email: "alex@example.com"))
        ClientRowView(client: Client(firstName: "Sam", lastName: "Nakamura"))
    }
    .modelContainer(container)
}
