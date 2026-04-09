import SwiftUI

struct SettingsViewPieces: View {
    @AppStorage("pieceSizeMode")  private var sizeMode:      PieceSizeMode = .categorical
    @AppStorage("dimensionUnit")  private var dimensionUnit: DimensionUnit  = .inches

    var body: some View {
        List {
            // MARK: Size Mode
            Section {
                Picker("Size Mode", selection: $sizeMode) {
                    Text("Categorical").tag(PieceSizeMode.categorical)
                    Text("Dimensional").tag(PieceSizeMode.dimensional)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                Text("Size Mode")
            } footer: {
                switch sizeMode {
                case .categorical:
                    Text("Pieces are tagged with a general size: Tiny, Small, Medium, Large, Extra Large, Half Sleeve, Sleeve, or Back Piece.")
                case .dimensional:
                    Text("Pieces have an exact width and height. Dimensions are stored in inches and displayed in your chosen unit below.")
                }
            }

            // MARK: Units (dimensional mode only)
            if sizeMode == .dimensional {
                Section("Units") {
                    Picker("Units", selection: $dimensionUnit) {
                        ForEach([DimensionUnit.inches, .centimeters], id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Pieces")
        .animation(.easeInOut(duration: 0.2), value: sizeMode)
    }
}

#Preview {
    NavigationStack { SettingsViewPieces() }
}
