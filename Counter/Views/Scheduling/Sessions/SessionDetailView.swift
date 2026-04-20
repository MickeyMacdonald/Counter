import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Bindable var session: Session
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(BusinessLockManager.self) private var lockManager
    @Query private var profiles: [UserProfile]

    @State private var showingEditSession   = false
    @State private var galleryImages: [WorkImage] = []
    @State private var galleryInitialImage: WorkImage?
    @State private var showingImageGallery  = false

    // MARK: - Helpers

    private var chargeableTypes: [String] {
        profiles.first?.effectiveChargeableSessionTypes ?? SessionType.defaultChargeableRawValues
    }

    private var isChargeable: Bool {
        chargeableTypes.contains(session.sessionType.rawValue)
    }

    // MARK: - Body

    var body: some View {
        List {
            headerSection
            workSection
            timeCostSection
            stageImagesSection
            notesSection
            metaSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(session.sessionType.rawValue)
        .toolbar { editButton }
        .sheet(isPresented: $showingEditSession) {
            if let piece = session.piece {
                SessionEditView(piece: piece, mode: .edit(session))
            }
        }
        .sheet(isPresented: $showingImageGallery) {
            if let initial = galleryInitialImage, !galleryImages.isEmpty {
                FullScreenImageViewer(images: galleryImages, initialImage: initial)
                    .environment(lockManager)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var editButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingEditSession = true } label: {
                Image(systemName: "pencil.circle")
            }
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        Section {
            VStack(spacing: 14) {
                typeIcon
                typeAndDate
                badges
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private var typeIcon: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.10))
                .frame(width: 72, height: 72)
            Image(systemName: session.sessionType.systemImage)
                .font(.system(size: 28))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var typeAndDate: some View {
        VStack(spacing: 4) {
            Text(session.sessionType.rawValue)
                .font(.title2.weight(.bold))
            Text(session.date.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var badges: some View {
        HStack(spacing: 8) {
            durationBadge
            statusBadge
        }
    }

    private var durationBadge: some View {
        Label(session.durationFormatted, systemImage: "clock")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.10), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }

    private var statusBadge: some View {
        Group {
            if session.isNoShow {
                Label("No Show", systemImage: "person.slash")
                    .foregroundStyle(.red)
                    .background(Color.red.opacity(0.10), in: Capsule())
            } else {
                let label  = isChargeable ? "Billable" : "Non-billable"
                let icon   = isChargeable ? "dollarsign.circle" : "dollarsign.circle.trianglebadge.exclamationmark"
                let tint   = isChargeable ? Color.green : Color.orange
                Label(label, systemImage: icon)
                    .foregroundStyle(tint)
                    .background(tint.opacity(0.10), in: Capsule())
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    // MARK: - Work Section (piece + client)

    @ViewBuilder
    private var workSection: some View {
        if let piece = session.piece {
            Section("Work") {
                pieceRow(piece)
                if let client = piece.client {
                    clientRow(client)
                }
            }
        }
    }

    private func pieceRow(_ piece: Piece) -> some View {
        Button { coordinator.navigateToPiece(piece) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: piece.pieceType.systemImage)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(piece.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(piece.pieceType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func clientRow(_ client: Client) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.primary.opacity(0.07))
                    .frame(width: 40, height: 40)
                Text(client.initialsDisplay)
                    .font(.system(.caption, design: .monospaced, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(client.fullName)
                    .font(.subheadline.weight(.medium))
                if !client.pronouns.isEmpty {
                    Text(client.pronouns)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Time & Cost Section

    @ViewBuilder
    private var timeCostSection: some View {
        Section("Time & Cost") {
            timeRows
            rateRow
            costRow
        }
    }

    @ViewBuilder
    private var timeRows: some View {
        labeledSecondary("Start Time",
            session.startTime.formatted(date: .omitted, time: .shortened))
        if let end = session.endTime {
            labeledSecondary("End Time",
                end.formatted(date: .omitted, time: .shortened))
        }
        if session.breakMinutes > 0 {
            labeledSecondary("Break", "\(session.breakMinutes) min")
        }
        labeledSecondary(
            session.manualHoursOverride != nil ? "Duration (override)" : "Duration",
            session.durationFormatted
        )
    }

    @ViewBuilder
    private var rateRow: some View {
        if session.sessionType.isFlash {
            labeledSecondary("Flash Rate", session.flashRate.currencyFormatted)
        } else if session.hourlyRateAtTime > 0 {
            labeledSecondary("Hourly Rate", session.hourlyRateAtTime.currencyFormatted)
        }
    }

    private var costRow: some View {
        HStack {
            Text("Session Cost").fontWeight(.medium)
            Spacer()
            Text(session.cost.currencyFormatted)
                .fontWeight(.bold)
                .foregroundStyle(isChargeable ? .primary : .secondary)
        }
    }

    // MARK: - Stage Images Section

    @ViewBuilder
    private var stageImagesSection: some View {
        if !session.sessionProgress.isEmpty {
            Section("Stage Images") {
                ForEach(session.sortedSessionProgress) { group in
                    imageGroupRow(group)
                }
            }
        }
    }

    private func imageGroupRow(_ group: SessionProgress) -> some View {
        Button {
            // group.images is already [WorkImage] — use directly, sorted by sortOrder
            let images = group.images.sorted { $0.sortOrder < $1.sortOrder }
            if let first = images.first {
                galleryImages        = images
                galleryInitialImage  = first
                showingImageGallery  = true
            }
        } label: {
            HStack {
                Label(group.stage.rawValue, systemImage: group.stage.systemImage)
                Spacer()
                Text("\(group.images.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notes Section

    @ViewBuilder
    private var notesSection: some View {
        if !session.notes.isEmpty {
            Section("Notes") {
                Text(session.notes)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Meta Section

    private var metaSection: some View {
        Section {
            labeledSecondary("Date",
                session.date.formatted(date: .long, time: .omitted))
        }
    }

    // MARK: - Helpers

    private func labeledSecondary(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionDetailView(session: {
            let s = Session(
                date: Date(),
                startTime: Calendar.current.date(byAdding: .hour, value: -3, to: Date())!,
                endTime: Date(),
                breakMinutes: 15,
                sessionType: .linework,
                hourlyRateAtTime: 175
            )
            return s
        }())
    }
    .modelContainer(PreviewContainer.shared.container)
    .environment(BusinessLockManager())
    .environment(AppNavigationCoordinator())
}
