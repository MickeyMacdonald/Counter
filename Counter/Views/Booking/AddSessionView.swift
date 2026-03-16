import SwiftUI
import SwiftData

/// Multi-step "Add Session" wizard.
///
/// - `fromClient`  — skips client selection; opens directly at Flash / Custom choice.
/// - `fromCalendar`— begins with client selection (existing, new, or walk-in),
///                   then continues to Flash / Custom choice.
struct AddSessionView: View {

    enum Context {
        case fromClient(Client)
        case fromCalendar(Date)
    }

    private enum Step: Equatable {
        case clientSelection
        case sessionKind
        case flashDetails
        case customDetails
    }

    let context: Context

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Query(sort: \Client.lastName) private var allClients: [Client]

    // MARK: - Client step state
    @State private var selectedClient: Client?
    @State private var isWalkIn = false
    @State private var showNewClientSheet = false
    @State private var clientSearchText = ""

    // MARK: - Session kind
    @State private var step: Step

    // MARK: - Flash details
    @State private var flashDate: Date
    @State private var flashStart: Date
    @State private var flashEnd: Date
    @State private var selectedFlashImage: PieceImage?
    @State private var selectedFlashPiece: Piece?
    @State private var showFlashGallery = false

    // MARK: - Custom details
    @State private var customSessionType: SessionType = .consultation
    @State private var customDate: Date
    @State private var customStart: Date
    @State private var customEnd: Date
    @State private var customNotes = ""

    init(context: Context) {
        self.context = context

        let baseDate: Date
        switch context {
        case .fromClient:
            baseDate = Date()
            _step = State(initialValue: .sessionKind)
        case .fromCalendar(let d):
            baseDate = d
            _step = State(initialValue: .clientSelection)
        }

        let cal = Calendar.current
        let nextHour = cal.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let rounded = cal.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour

        _flashDate  = State(initialValue: baseDate)
        _flashStart = State(initialValue: rounded)
        _flashEnd   = State(initialValue: rounded.addingTimeInterval(7200))
        _customDate  = State(initialValue: baseDate)
        _customStart = State(initialValue: rounded)
        _customEnd   = State(initialValue: rounded.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .clientSelection: clientSelectionStep
                case .sessionKind:     sessionKindStep
                case .flashDetails:    flashDetailsStep
                case .customDetails:   customDetailsStep
                }
            }
            .animation(.easeInOut(duration: 0.2), value: step)
            .sheet(isPresented: $showNewClientSheet) {
                ClientEditView(mode: .add)
            }
            .sheet(isPresented: $showFlashGallery) {
                FlashGalleryView { image, piece in
                    selectedFlashImage = image
                    selectedFlashPiece = piece
                    showFlashGallery = false
                }
            }
        }
    }

    // MARK: - Step 1: Client Selection (calendar only)

    private var filteredClients: [Client] {
        if clientSearchText.isEmpty { return allClients }
        let query = clientSearchText.lowercased()
        return allClients.filter {
            $0.fullName.lowercased().contains(query) ||
            $0.email.lowercased().contains(query) ||
            $0.phone.contains(query)
        }
    }

    private var clientSelectionStep: some View {
        Form {
            Section {
                Button {
                    showNewClientSheet = true
                } label: {
                    Label("Add New Client", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            if !isWalkIn {
                Section("Select Client") {
                    ForEach(filteredClients) { client in
                        Button {
                            selectedClient = client
                        }
                        label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(client.fullName)
                                        .foregroundStyle(.primary)
                                        .font(.body.weight(.medium))
                                    if !client.email.isEmpty {
                                        Text(client.email)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedClient?.persistentModelID == client.persistentModelID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $clientSearchText, prompt: "Search clients...")
        .navigationTitle("Who's the Client?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Continue") { step = .sessionKind }
                    .fontWeight(.semibold)
                    .disabled(!isWalkIn && selectedClient == nil)
            }
        }
    }

    // MARK: - Step 2: Flash or Custom

    private var sessionKindStep: some View {
        VStack(spacing: 0) {
            clientBanner
            Spacer()
            HStack(spacing: 16) {
                kindCard(title: "Flash",
                         subtitle: "Pre-designed piece\nfrom your portfolio",
                         icon: "bolt.fill", color: .orange) { step = .flashDetails }
                kindCard(title: "Custom",
                         subtitle: "Bespoke work\nstarting with a consult",
                         icon: "paintbrush.pointed.fill", color: Color.accentColor) { step = .customDetails }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .navigationTitle("Session Type")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(backLabel) { goBack() }
            }
        }
    }

    private func kindCard(title: String, subtitle: String, icon: String,
                          color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 38)).foregroundStyle(color)
                VStack(spacing: 4) {
                    Text(title).font(.title3.weight(.bold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.25), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3a: Flash Details

    private var flashDetailsStep: some View {
        Form {
            clientBannerSection
            Section("Booking") {
                DatePicker("Date",  selection: $flashDate,  displayedComponents: .date)
                DatePicker("Start", selection: $flashStart, displayedComponents: .hourAndMinute)
                DatePicker("End",   selection: $flashEnd,   displayedComponents: .hourAndMinute)
            }
            Section {
                if let image = selectedFlashImage, let piece = selectedFlashPiece {
                    HStack(spacing: 12) {
                        SessionImagePreview(filePath: image.filePath)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(piece.title).font(.subheadline.weight(.medium))
                            Text("Flash design selected").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Change") { showFlashGallery = true }.font(.subheadline).buttonStyle(.borderless)
                    }
                } else {
                    Button {
                        showFlashGallery = true
                    } label: {
                        Label("Pick from Flash Gallery", systemImage: "photo.on.rectangle.angled")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            } header: { Text("Design") }
              footer: { Text("Optional — select a design from your portfolio to attach to this booking.").font(.caption) }
        }
        .navigationTitle("Flash Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Back") { step = .sessionKind } }
            ToolbarItem(placement: .confirmationAction) { Button("Book") { saveFlash() }.fontWeight(.semibold) }
        }
    }

    // MARK: - Step 3b: Custom Details

    private var customDetailsStep: some View {
        ScrollView {
            VStack(spacing: 0) {
                Form {
                    clientBannerSection
                    Section("Session Type") {
                        Picker("Type", selection: $customSessionType) {
                            ForEach(SessionType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.systemImage).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Section("Booking") {
                        DatePicker("Date",  selection: $customDate,  displayedComponents: .date)
                        DatePicker("Start", selection: $customStart, displayedComponents: .hourAndMinute)
                        DatePicker("End",   selection: $customEnd,   displayedComponents: .hourAndMinute)
                    }
                    Section("Notes") {
                        TextField("Notes", text: $customNotes, axis: .vertical).lineLimit(2...5)
                    }
                }
                .frame(minHeight: 460)
                .scrollDisabled(true)

                InspirationGalleryView()
                    .frame(minHeight: 320)
                    .background(Color(.systemBackground))
            }
        }
        .navigationTitle("Custom Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Back") { step = .sessionKind } }
            ToolbarItem(placement: .confirmationAction) { Button("Book") { saveCustom() }.fontWeight(.semibold) }
        }
    }

    // MARK: - Shared sub-views

    private var clientBanner: some View {
        Group {
            if let client = effectiveClient {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill").foregroundStyle(Color.accentColor)
                    Text(client.fullName).font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.primary.opacity(0.04))
            } else if isWalkIn {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk").foregroundStyle(.secondary)
                    Text("Walk-in / Anonymous").font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.primary.opacity(0.04))
            }
        }
    }

    private var clientBannerSection: some View {
        Section {
            if let client = effectiveClient {
                Label(client.fullName, systemImage: "person.circle.fill").foregroundStyle(.primary)
            } else {
                Label("Walk-in / Anonymous", systemImage: "figure.walk").foregroundStyle(.secondary)
            }
        } header: { Text("Client") }
    }

    // MARK: - Helpers

    private var effectiveClient: Client? {
        switch context {
        case .fromClient(let c): return c
        case .fromCalendar:      return isWalkIn ? nil : selectedClient
        }
    }

    private var backLabel: String {
        if case .fromCalendar = context { return "Back" }
        return "Cancel"
    }

    private func goBack() {
        switch context {
        case .fromCalendar: step = .clientSelection
        case .fromClient:   dismiss()
        }
    }

    // MARK: - Save

    private func saveFlash() {
        let booking = Booking(date: flashDate, startTime: flashStart, endTime: flashEnd,
                              status: .confirmed, bookingType: .flashPickup,
                              client: effectiveClient, piece: selectedFlashPiece)
        modelContext.insert(booking)
        dismiss()
    }

    private func saveCustom() {
        let bookingType: BookingType = customSessionType == .consultation ? .consultation : .session
        let booking = Booking(date: customDate, startTime: customStart, endTime: customEnd,
                              status: .confirmed, bookingType: bookingType,
                              notes: customNotes, client: effectiveClient)
        modelContext.insert(booking)
        dismiss()
    }
}

// Async image thumbnail helper used in flash details step
struct SessionImagePreview: View {
    let filePath: String
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8).fill(.primary.opacity(0.06)).overlay(ProgressView())
            }
        }
        .task { image = await ImageStorageService.shared.loadImage(relativePath: filePath) }
    }
}

#Preview("From Client") {
    AddSessionView(context: .fromClient(Client(firstName: "Alex", lastName: "Rivera")))
        .modelContainer(PreviewContainer.shared.container)
}

#Preview("From Calendar") {
    AddSessionView(context: .fromCalendar(Date()))
        .modelContainer(PreviewContainer.shared.container)
}
