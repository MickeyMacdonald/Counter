//
//  SettingsAboutView.swift
//  Counter
//
//  Created by Mickey Macdonald on 2026-04-08.
//

// MARK: - Imports
import SwiftData
import SwiftUI

// MARK: - About

struct SettingsAboutView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: "Alpha 0.8")
                LabeledContent("Build", value: "CounterAlpha")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
    }
}
