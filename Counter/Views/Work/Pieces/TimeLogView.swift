import SwiftUI

/// Inline time logger for an SessionProgress stage.
/// Allows quick input of time spent on design work per stage.
struct TimeLogView: View {
    @Bindable var imageGroup: SessionProgress
    @Environment(\.dismiss) private var dismiss

    @State private var hours: Int = 0
    @State private var minutes: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Time Spent on \(imageGroup.stage.rawValue)") {
                    HStack {
                        Stepper("\(hours)h", value: $hours, in: 0...100)
                        Divider()
                        Stepper("\(minutes)m", value: $minutes, in: 0...55, step: 5)
                    }
                }

                Section {
                    LabeledContent("Total", value: totalFormatted)
                        .font(.headline.monospaced())
                }

                Section("Notes") {
                    TextField("Stage notes...", text: $imageGroup.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        imageGroup.timeSpentMinutes = (hours * 60) + minutes
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                hours = imageGroup.timeSpentMinutes / 60
                minutes = imageGroup.timeSpentMinutes % 60
            }
        }
    }

    private var totalFormatted: String {
        let total = (hours * 60) + minutes
        let h = total / 60
        let m = total % 60
        return "\(h)h \(m)m"
    }
}
