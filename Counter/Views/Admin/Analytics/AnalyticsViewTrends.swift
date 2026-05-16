//
//  AnalyticsViewTrends.swift
//  Counter
//
//  Created by Mickey Macdonald on 2026-04-08.
//

import SwiftUI

struct AnalyticsViewTrends: View {
    var body: some View {
        ContentUnavailableView(
            "Trends Coming Soon",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Earnings over time, monthly breakdown, and top clients by revenue.")
        )
        .navigationTitle("Trends")
    }
}
