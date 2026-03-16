import SwiftUI
import SwiftData

struct ClientDetailView: View {
    @Bindable var client: Client
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Booking.date) private var allBookings: [Booking]
    @Query private var profiles: [UserProfile]
    @State private var showingEditClient = false
    @State private var showingAddPiece = false
    @State private var showingAddAgreement = false
    @State private var showingEmailPicker = false
    @State private var showingReportExport = false
    @State private var showingAddBooking = false
    @State private var showingClientGallery = false

    private var chargeableTypes: [String] {
        profiles.first?.effectiveChargeableSessionTypes ?? SessionType.defaultChargeableRawValues
    }

    private var clientBookings: [Booking] {
        allBookings.filter { $0.client?.persistentModelID == client.persistentModelID && $0.isUpcoming }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            // Header with avatar, name, and action buttons
            Section {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.primary.opacity(0.08))
                            .frame(width: 72, height: 72)
                        Text(client.initialsDisplay)
                            .font(.system(.title, design: .monospaced, weight: .bold))
                    }

                    Text(client.fullName)
                        .font(.title2.weight(.bold))

                    if !client.pronouns.isEmpty {
                        Text(client.pronouns)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Action buttons
                    HStack(spacing: 20) {
                        actionButton(
                            icon: "envelope.fill",
                            label: "Email",
                            disabled: client.email.isEmpty
                        ) {
                            showingEmailPicker = true
                        }

                        actionButton(
                            icon: "message.fill",
                            label: "Text",
                            disabled: client.phone.isEmpty
                        ) {
                            openSMS()
                        }

                        actionButton(
                            icon: "phone.fill",
                            label: "Call",
                            disabled: client.phone.isEmpty
                        ) {
                            openPhone()
                        }

                        actionButton(
                            icon: "doc.text.fill",
                            label: "Report",
                            disabled: false
                        ) {
                            showingReportExport = true
                        }

                        actionButton(
                            icon: "photo.on.rectangle.angled",
                            label: "Gallery",
                            disabled: false
                        ) {
                            showingClientGallery = true
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            // Quick stats
            Section {
                HStack {
                    StatBlock(label: "Pieces", value: "\(client.pieces.count)")
                    Divider()
                    StatBlock(label: "Hours", value: String(format: "%.1f", client.chargeableHours(using: chargeableTypes)))
                    Divider()
                    StatBlock(label: "Total", value: client.chargeableSpent(using: chargeableTypes).currencyFormatted)
                }
                .padding(.vertical, 4)
            }

            // Contact info
            Section("Contact") {
                if !client.email.isEmpty {
                    LabeledContent {
                        Text(client.email)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Email", systemImage: "envelope")
                    }
                }
                if !client.phone.isEmpty {
                    LabeledContent {
                        Text(client.phone)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Phone", systemImage: "phone")
                    }
                }
                if !client.streetAddress.isEmpty {
                    LabeledContent {
                        VStack(alignment: .trailing) {
                            Text(client.streetAddress)
                            if !client.city.isEmpty || !client.state.isEmpty {
                                Text("\(client.city), \(client.state) \(client.zipCode)")
                            }
                        }
                        .foregroundStyle(.secondary)
                    } label: {
                        Label("Address", systemImage: "mappin")
                    }
                }
            }

            // Upcoming Bookings
            Section {
                if clientBookings.isEmpty {
                    Text("No upcoming bookings")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(clientBookings) { booking in
                        NavigationLink {
                            BookingDetailView(booking: booking)
                        } label: {
                            BookingRowView(booking: booking)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Upcoming Bookings")
                    Spacer()
                    Button {
                        showingAddBooking = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                    }
                }
            }

            // Allergy / notes
            if !client.allergyNotes.isEmpty {
                Section("Allergies / Sensitivities") {
                    Label {
                        Text(client.allergyNotes)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Pieces
            Section {
                if client.pieces.isEmpty {
                    ContentUnavailableView {
                        Label("No Pieces", systemImage: "photo.on.rectangle.angled")
                    } description: {
                        Text("Add a piece to start tracking this client's work.")
                    }
                } else {
                    ForEach(client.pieces.sorted(by: { $0.updatedAt > $1.updatedAt })) { piece in
                        NavigationLink {
                            PieceDetailView(piece: piece)
                        } label: {
                            PieceRowView(piece: piece)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Pieces")
                    Spacer()
                    Button {
                        showingAddPiece = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                    }
                }
            }

            // Agreements
            Section {
                if client.agreements.isEmpty {
                    ContentUnavailableView {
                        Label("No Agreements", systemImage: "doc.text")
                    } description: {
                        Text("Create consent forms, waivers, and sign-offs.")
                    }
                } else {
                    ForEach(client.agreements.sorted(by: { $0.createdAt > $1.createdAt })) { agreement in
                        NavigationLink {
                            AgreementDetailView(agreement: agreement)
                        } label: {
                            HStack {
                                Label(agreement.title, systemImage: agreement.agreementType.systemImage)
                                Spacer()
                                if agreement.isSigned {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Agreements")
                    Spacer()
                    Button {
                        showingAddAgreement = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                    }
                }
            }

            // Notes
            if !client.notes.isEmpty {
                Section("Notes") {
                    Text(client.notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            // Meta
            Section {
                LabeledContent("Added", value: client.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Updated", value: client.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditClient = true
                } label: {
                    Image(systemName: "pencil.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditClient) {
            ClientEditView(mode: .edit(client))
        }
        .sheet(isPresented: $showingAddPiece) {
            PieceEditView(mode: .add(client: client))
        }
        .sheet(isPresented: $showingAddAgreement) {
            AgreementEditView(mode: .create(client: client))
        }
        .sheet(isPresented: $showingEmailPicker) {
            EmailTemplatePickerView(client: client, piece: nil)
        }
        .sheet(isPresented: $showingReportExport) {
            ClientReportExportView(client: client)
        }
        .sheet(isPresented: $showingAddBooking) {
            AddSessionView(context: .fromClient(client))
        }
        .navigationDestination(isPresented: $showingClientGallery) {
            ClientGalleryView(client: client)
        }
    }

    // MARK: - Action Button

    private func actionButton(icon: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(disabled ? Color.primary.opacity(0.04) : Color.accentColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(disabled ? Color.gray.opacity(0.3) : Color.accentColor)
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(disabled ? Color.gray.opacity(0.3) : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Phone / SMS Actions

    private func openPhone() {
        let cleaned = client.phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        guard let url = URL(string: "tel://\(cleaned)") else { return }
        UIApplication.shared.open(url)
    }

    private func openSMS() {
        let cleaned = client.phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        guard let url = URL(string: "sms:\(cleaned)") else { return }
        UIApplication.shared.open(url)
    }
}

struct StatBlock: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

extension Decimal {
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: self as NSDecimalNumber) ?? "$0"
    }
}

#Preview {
    NavigationStack {
        ClientDetailView(client: {
            let c = Client(
                firstName: "Alex",
                lastName: "Rivera",
                email: "alex@example.com",
                phone: "555-0101",
                notes: "Prefers traditional style.",
                pronouns: "they/them",
                allergyNotes: "Red ink sensitivity"
            )
            return c
        }())
    }
    .modelContainer(PreviewContainer.shared.container)
}
