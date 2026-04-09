//
//  SettingsAvailabilityView.swift
//  Counter
//
//  Created by Mickey Macdonald on 2026-04-08.
//

import SwiftUI
import SwiftData

// MARK: - Availability

struct SettingsAvailabilityView: View {
    @State private var showingAvailability = false

    var body: some View {
        List {
            Section {
                Button {
                    showingAvailability = true
                } label: {
                    Label("Manage Weekly Hours", systemImage: "clock.badge.checkmark")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Availability")
        .sheet(isPresented: $showingAvailability) {
            SettingsViewAvailability()
        }
    }
}
