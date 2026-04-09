//
//  AnalyticsViewTrends.swift
//  Counter
//
//  Created by Mickey Macdonald on 2026-04-08.
//

// MARK: - Imports
import SwiftData
import SwiftUI

// MARK: - About

struct AnalyticsViewTrends: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: "Pre-Alpha 0.8")
                LabeledContent("Build", value: "CounterPreAlpha")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
    }
}
