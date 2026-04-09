//
//  WelcomeSetupView.swift
//  Counter
//
//  Created by Mickey Macdonald on 2026-04-08.
//

import SwiftData
import SwiftUI

// MARK: - Welcome / First-Run Setup
struct WelcomeSetupView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var businessName = ""
    @State private var profession: Profession = .tattooer
    @State private var currentStep = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress
                ProgressView(value: Double(currentStep + 1), total: 3)
                    .padding(.horizontal)
                    .padding(.top, 8)

                TabView(selection: $currentStep) {
                    // Step 1: Welcome
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: "paintbrush.pointed.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor)

                        Text("Welcome to Counter")
                            .font(.largeTitle.weight(.bold))

                        Text("The all-in-one tool for managing your clients, bookings, and business.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Spacer()

                        Button {
                            withAnimation { currentStep = 1 }
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                    .tag(0)

                    // Step 2: Profession
                    VStack(spacing: 24) {
                        Spacer()

                        Text("What do you do?")
                            .font(.title.weight(.bold))

                        VStack(spacing: 12) {
                            ForEach(Profession.allCases, id: \.self) { p in
                                Button {
                                    profession = p
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: p.systemImage)
                                            .font(.title2)
                                            .frame(width: 32)
                                        Text(p.rawValue)
                                            .font(.headline)
                                        Spacer()
                                        if profession == p {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(profession == p ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.05))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 40)

                        Spacer()

                        Button {
                            withAnimation { currentStep = 2 }
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                    .tag(1)

                    // Step 3: Name
                    VStack(spacing: 24) {
                        Spacer()

                        Text("About You")
                            .font(.title.weight(.bold))

                        VStack(spacing: 16) {
                            TextField("First Name", text: $firstName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.givenName)

                            TextField("Last Name", text: $lastName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.familyName)

                            TextField("Business Name (optional)", text: $businessName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.organizationName)
                        }
                        .padding(.horizontal, 40)

                        Spacer()

                        Button {
                            createProfile()
                        } label: {
                            Text("Finish Setup")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(firstName.isEmpty)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
        }
    }

    private func createProfile() {
        let profile = UserProfile(
            firstName: firstName,
            lastName: lastName,
            businessName: businessName,
            profession: profession
        )
        modelContext.insert(profile)
    }
}
