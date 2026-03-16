import SwiftUI
import SwiftData

struct ProfileEditView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    @State private var firstName: String
    @State private var lastName: String
    @State private var businessName: String
    @State private var email: String
    @State private var phone: String
    @State private var profession: Profession
    // Shop address
    @State private var shopAddressLine1: String
    @State private var shopAddressLine2: String
    @State private var shopCity: String
    @State private var shopState: String
    @State private var shopPostalCode: String
    @State private var shopCountry: String

    // Billing address
    @State private var billingSameAsShop: Bool
    @State private var billingAddressLine1: String
    @State private var billingAddressLine2: String
    @State private var billingCity: String
    @State private var billingState: String
    @State private var billingPostalCode: String
    @State private var billingCountry: String

    init(profile: UserProfile) {
        self.profile = profile
        _firstName        = State(initialValue: profile.firstName)
        _lastName         = State(initialValue: profile.lastName)
        _businessName     = State(initialValue: profile.businessName)
        _email            = State(initialValue: profile.email)
        _phone            = State(initialValue: profile.phone)
        _profession       = State(initialValue: profile.profession)
        _shopAddressLine1 = State(initialValue: profile.shopAddressLine1)
        _shopAddressLine2 = State(initialValue: profile.shopAddressLine2)
        _shopCity         = State(initialValue: profile.shopCity)
        _shopState        = State(initialValue: profile.shopState)
        _shopPostalCode   = State(initialValue: profile.shopPostalCode)
        _shopCountry      = State(initialValue: profile.shopCountry)

        _billingSameAsShop    = State(initialValue: profile.billingMatchesShop)
        _billingAddressLine1  = State(initialValue: profile.billingAddressLine1)
        _billingAddressLine2  = State(initialValue: profile.billingAddressLine2)
        _billingCity          = State(initialValue: profile.billingCity)
        _billingState         = State(initialValue: profile.billingState)
        _billingPostalCode    = State(initialValue: profile.billingPostalCode)
        _billingCountry       = State(initialValue: profile.billingCountry)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Business Name", text: $businessName)
                }

                Section("Profession") {
                    Picker("Profession", selection: $profession) {
                        ForEach(Profession.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: p.systemImage).tag(p)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Contact") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("Shop Address") {
                    TextField("Address Line 1", text: $shopAddressLine1)
                        .textContentType(.streetAddressLine1)
                    TextField("Address Line 2", text: $shopAddressLine2)
                        .textContentType(.streetAddressLine2)
                    TextField("City", text: $shopCity)
                        .textContentType(.addressCity)
                    TextField("State / Province", text: $shopState)
                        .textContentType(.addressState)
                    TextField("Postal Code", text: $shopPostalCode)
                        .textContentType(.postalCode)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Country", text: $shopCountry)
                        .textContentType(.countryName)
                }

                Section("Billing Address") {
                    Toggle("Same as shop address", isOn: $billingSameAsShop)
                        .onChange(of: billingSameAsShop) { _, sameAsShop in
                            if sameAsShop { copyShopToBilling() }
                        }

                    if !billingSameAsShop {
                        TextField("Address Line 1", text: $billingAddressLine1)
                            .textContentType(.streetAddressLine1)
                        TextField("Address Line 2", text: $billingAddressLine2)
                            .textContentType(.streetAddressLine2)
                        TextField("City", text: $billingCity)
                            .textContentType(.addressCity)
                        TextField("State / Province", text: $billingState)
                            .textContentType(.addressState)
                        TextField("Postal Code", text: $billingPostalCode)
                            .textContentType(.postalCode)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("Country", text: $billingCountry)
                            .textContentType(.countryName)
                    }
                }

            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(firstName.isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers

    private func copyShopToBilling() {
        billingAddressLine1 = shopAddressLine1
        billingAddressLine2 = shopAddressLine2
        billingCity         = shopCity
        billingState        = shopState
        billingPostalCode   = shopPostalCode
        billingCountry      = shopCountry
    }

    private func save() {
        profile.firstName         = firstName
        profile.lastName          = lastName
        profile.businessName      = businessName
        profile.email             = email
        profile.phone             = phone
        profile.profession        = profession
        profile.shopAddressLine1  = shopAddressLine1
        profile.shopAddressLine2  = shopAddressLine2
        profile.shopCity          = shopCity
        profile.shopState         = shopState
        profile.shopPostalCode    = shopPostalCode
        profile.shopCountry       = shopCountry

        if billingSameAsShop {
            copyShopToBilling()
        }
        profile.billingAddressLine1 = billingAddressLine1
        profile.billingAddressLine2 = billingAddressLine2
        profile.billingCity         = billingCity
        profile.billingState        = billingState
        profile.billingPostalCode   = billingPostalCode
        profile.billingCountry      = billingCountry

        profile.updatedAt = Date()
        dismiss()
    }
}

#Preview {
    ProfileEditView(profile: UserProfile(
        firstName: "Alex",
        lastName: "Rivera",
        businessName: "Ink & Iron",
        profession: .tattooer
    ))
    .modelContainer(PreviewContainer.shared.container)
}
