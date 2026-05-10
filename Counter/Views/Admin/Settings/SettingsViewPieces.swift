import SwiftUI

private let defaultBodyPositions = [
    "Forearm", "Upper Arm", "Shoulder", "Back", "Chest",
    "Ribcage", "Thigh", "Calf", "Ankle", "Wrist",
    "Neck", "Hand", "Foot", "Hip", "Stomach"
]

struct SettingsViewPieces: View {
    @AppStorage("pieceSizeMode")  private var sizeMode:      PieceSizeMode = .categorical
    @AppStorage("dimensionUnit")  private var dimensionUnit: DimensionUnit  = .inches
    @State private var positions: [String] = UserDefaults.standard.stringArray(forKey: "bodyPositions") ?? defaultBodyPositions
    @State private var newPosition = ""

    var body: some View {
        List {
            // MARK: Body Positions
            Section {
                ForEach(positions, id: \.self) { position in
                    Text(position)
                }
                .onDelete { indexSet in
                    positions.remove(atOffsets: indexSet)
                    save()
                }
                .onMove { from, to in
                    positions.move(fromOffsets: from, toOffset: to)
                    save()
                }

                HStack {
                    TextField("Add position…", text: $newPosition)
                        .onSubmit { addPosition() }
                    if !newPosition.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button(action: addPosition) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                HStack {
                    Text("Body Positions")
                    Spacer()
                    EditButton()
                }
            } footer: {
                Text("These positions appear in the body placement picker when creating or editing pieces.")
            }

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

    private func addPosition() {
        let trimmed = newPosition.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !positions.contains(trimmed) else {
            newPosition = ""
            return
        }
        positions.append(trimmed)
        newPosition = ""
        save()
    }

    private func save() {
        UserDefaults.standard.set(positions, forKey: "bodyPositions")
    }
}

#Preview {
    NavigationStack { SettingsViewPieces() }
}
