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

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: buildNumber)
                LabeledContent("Channel", value: "Beta")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
    }
}
