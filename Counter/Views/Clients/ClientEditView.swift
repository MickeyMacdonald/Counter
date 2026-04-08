import SwiftUI
import SwiftData

struct ClientEditView: View {
    enum Mode {
        case add
        case edit(Client)
    }

    let mode: Mode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var pronouns = ""
    @State private var birthdate: Date?
    @State private var hasBirthdate = false
    @State private var allergyNotes = ""
    @State private var notes = ""
    @State private var emailOptIn = true
    @State private var streetAddress = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String {
        isEditing ? "Edit Client" : "New Client"
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty ||
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                    TextField("Pronouns", text: $pronouns)
                }

                Section("Contact") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    Toggle("Email List Opt-In", isOn: $emailOptIn)
                }

                Section("Details") {
                    Toggle("Birthday", isOn: $hasBirthdate)
                    if hasBirthdate {
                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { birthdate ?? Date() },
                                set: { birthdate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                    TextField("Allergy / Sensitivity Notes", text: $allergyNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Address") {
                    TextField("Street", text: $streetAddress)
                        .textContentType(.streetAddressLine1)
                    TextField("City", text: $city)
                        .textContentType(.addressCity)
                    TextField("State", text: $state)
                        .textContentType(.addressState)
                    TextField("Zip", text: $zipCode)
                        .textContentType(.postalCode)
                        .keyboardType(.numberPad)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: loadExistingData)
        }
    }

    private func loadExistingData() {
        guard case .edit(let client) = mode else { return }
        firstName = client.firstName
        lastName = client.lastName
        email = client.email
        phone = client.phone
        pronouns = client.pronouns
        birthdate = client.birthdate
        hasBirthdate = client.birthdate != nil
        allergyNotes = client.allergyNotes
        emailOptIn = client.emailOptIn
        notes = client.notes
        streetAddress = client.streetAddress
        city = client.city
        state = client.state
        zipCode = client.zipCode
    }

    private func save() {
        switch mode {
        case .add:
            let client = Client(
                firstName: firstName.trimmed,
                lastName: lastName.trimmed,
                email: email.trimmed,
                phone: phone.trimmed,
                notes: notes.trimmed,
                pronouns: pronouns.trimmed,
                birthdate: hasBirthdate ? birthdate : nil,
                allergyNotes: allergyNotes.trimmed,
                streetAddress: streetAddress.trimmed,
                city: city.trimmed,
                state: state.trimmed,
                zipCode: zipCode.trimmed
            )
            client.emailOptIn = emailOptIn
            modelContext.insert(client)

        case .edit(let client):
            client.firstName = firstName.trimmed
            client.lastName = lastName.trimmed
            client.email = email.trimmed
            client.phone = phone.trimmed
            client.pronouns = pronouns.trimmed
            client.birthdate = hasBirthdate ? birthdate : nil
            client.allergyNotes = allergyNotes.trimmed
            client.notes = notes.trimmed
            client.emailOptIn = emailOptIn
            client.streetAddress = streetAddress.trimmed
            client.city = city.trimmed
            client.state = state.trimmed
            client.zipCode = zipCode.trimmed
            client.updatedAt = Date()
        }

        dismiss()
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    ClientEditView(mode: .add)
        .modelContainer(PreviewContainer.shared.container)
}
