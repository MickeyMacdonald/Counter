//
//  SettingsProfileView.swift
//  Counter
//
//  Created by Mickey Macdonald on 2026-04-08.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
 
// MARK: - Profile

struct SettingsProfileView: View {
    let profile: UserProfile?

    var body: some View {
        if let profile {
            ProfileInlineEditView(profile: profile)
        } else {
            noProfileView
                .navigationTitle("Profile")
        }
    }
}

struct ProfileInlineEditView: View {
    @Bindable var profile: UserProfile
    
    @State private var personalSameAsStudio: Bool = false ///mirrors studio on true
    @State private var studioSameAsPersonal: Bool = false  ///mirrors personal on true
    @State private var billingSameAsStudio: Bool = false /// mirrors studio on true

    init(profile: UserProfile) {
        self.profile = profile
        _billingSameAsStudio = State(initialValue: profile.billingMatchesShop)
    }

    var body: some View {
        List {

            // MARK: Identity card
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.primary.opacity(0.08))
                            .frame(width: 72, height: 72)
                        Text(profile.initialsDisplay)
                            .font(.system(.title, design: .monospaced, weight: .bold))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.fullName.isEmpty ? "Your Name" : profile.fullName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(profile.fullName.isEmpty ? .secondary : .primary)
                        if !profile.businessName.isEmpty {
                            Text(profile.businessName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: profile.profession.systemImage)
                                .font(.caption)
                            Text(profile.profession.rawValue)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // MARK: Personal group — name, profession, contact
            Section("Personal") {
                profileRow("First Name") {
                    TextField("", text: $profile.firstName)
                        .textContentType(.givenName)
                }
                profileRow("Last Name") {
                    TextField("", text: $profile.lastName)
                        .textContentType(.familyName)
                }

                Picker("Profession", selection: $profile.profession) {
                    ForEach(Profession.allCases, id: \.self) { p in
                        Label(p.rawValue, systemImage: p.systemImage).tag(p)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Sync contact", isOn: $personalSameAsStudio)
                    .onChange(of: personalSameAsStudio) { _, same in
                        withAnimation(.easeInOut) {
                            if same {
                                studioSameAsPersonal = false
                                profile.email = profile.studioEmail
                                profile.phone = profile.studioPhone
                            }
                        }
                    }
                if !personalSameAsStudio {
                    profileRow("Email") {
                        TextField("", text: $profile.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                    }
                    profileRow("Phone") {
                        TextField("", text: $profile.phone)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                    }
                }
            }

            // MARK: Studio group — name, contact, address
            Section("Studio") {
                profileRow("Studio Name") {
                    TextField("", text: $profile.businessName)
                        .textContentType(.organizationName)
                }

                Toggle("Sync contact", isOn: $studioSameAsPersonal)
                    .onChange(of: studioSameAsPersonal) { _, same in
                        withAnimation(.easeInOut) {
                            if same {
                                personalSameAsStudio = false
                                profile.studioEmail = profile.email
                                profile.studioPhone = profile.phone
                            }
                        }
                    }
                if !studioSameAsPersonal {
                    profileRow("Email") {
                        TextField("", text: $profile.studioEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                    }
                    profileRow("Phone") {
                        TextField("", text: $profile.studioPhone)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                    }
                }

                profileRow("Address Line 1") {
                    TextField("123 Main St", text: $profile.shopAddressLine1)
                        .textContentType(.streetAddressLine1)
                }
                profileRow("Address Line 2") {
                    TextField("Suite 100", text: $profile.shopAddressLine2)
                        .textContentType(.streetAddressLine2)
                }
                profileRow("City") {
                    TextField("City", text: $profile.shopCity)
                        .textContentType(.addressCity)
                }
                profileRow("State / Province") {
                    TextField("State", text: $profile.shopState)
                        .textContentType(.addressState)
                }
                profileRow("Postal Code") {
                    TextField("00000", text: $profile.shopPostalCode)
                        .textContentType(.postalCode)
                        .keyboardType(.numbersAndPunctuation)
                }
                profileRow("Country") {
                    TextField("Country", text: $profile.shopCountry)
                        .textContentType(.countryName)
                }
            }

            // MARK: Billing Address
            Section("Billing Address") {
                Toggle("Same as studio address", isOn: $billingSameAsStudio)
                    .onChange(of: billingSameAsStudio) { _, same in
                        withAnimation(.easeInOut) {
                            if same { copyStudioToBilling() }
                        }
                    }
                if !billingSameAsStudio {
                    profileRow("Address Line 1") {
                        TextField("123 Main St", text: $profile.billingAddressLine1)
                            .textContentType(.streetAddressLine1)
                    }
                    profileRow("Address Line 2") {
                        TextField("Suite 100", text: $profile.billingAddressLine2)
                            .textContentType(.streetAddressLine2)
                    }
                    profileRow("City") {
                        TextField("City", text: $profile.billingCity)
                            .textContentType(.addressCity)
                    }
                    profileRow("State / Province") {
                        TextField("State", text: $profile.billingState)
                            .textContentType(.addressState)
                    }
                    profileRow("Postal Code") {
                        TextField("00000", text: $profile.billingPostalCode)
                            .textContentType(.postalCode)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    profileRow("Country") {
                        TextField("Country", text: $profile.billingCountry)
                            .textContentType(.countryName)
                    }
                }
            }

            // MARK: Share Contact Card
            Section {
                ShareLink(
                    item: VCardFile(content: profile.makeVCard(personalContactSameAsStudio: personalSameAsStudio)),
                    preview: SharePreview(
                        profile.fullName.isEmpty ? "Contact Card" : profile.fullName,
                        image: Image(systemName: "person.crop.circle")
                    )
                ) {
                    Label("Share Contact Card", systemImage: "square.and.arrow.up")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
    }

    // MARK: - Helpers

    @ViewBuilder
    private func profileRow<Input: View>(_ label: String, @ViewBuilder input: () -> Input) -> some View {
        HStack {
            Text(label).foregroundStyle(.primary)
            Spacer()
            input()
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }

    private func copyStudioToBilling() {
        profile.billingAddressLine1 = profile.shopAddressLine1
        profile.billingAddressLine2 = profile.shopAddressLine2
        profile.billingCity         = profile.shopCity
        profile.billingState        = profile.shopState
        profile.billingPostalCode   = profile.shopPostalCode
        profile.billingCountry      = profile.shopCountry
    }
}

// MARK: - vCard Transferable

struct VCardFile: Transferable {
    let content: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .vCard) { Data($0.content.utf8) }
    }
}

// MARK: - Shared

var noProfileView: some View {
    ContentUnavailableView {
        Label("No Profile", systemImage: "person.crop.circle.badge.questionmark")
    } description: {
        Text("Set up your profile to get started.")
    }
}

#Preview {
    SettingsView()
        .environment(AppNavigationCoordinator())
        .modelContainer(PreviewContainer.shared.container)
        .environment(BusinessLockManager())
}

