import SwiftUI

/// Pushed onto PhotoImportPicker's NavigationStack after images are loaded.
/// Lets the user assign a category that applies to every image in the batch.
struct PhotoImportMetadataView: View {
    let images: [UIImage]
    let onConfirm: (ImageCategory) -> Void

    @State private var selectedCategory: ImageCategory = .reference

    private let importableCategories: [ImageCategory] = [
        .reference, .inspiration, .progress, .healed, .portfolio
    ]

    var body: some View {
        Form {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images.indices, id: \.self) { idx in
                            Image(uiImage: images[idx])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } header: {
                Text(images.count == 1 ? "1 Photo Selected" : "\(images.count) Photos Selected")
            }

            Section("Type") {
                ForEach(importableCategories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack {
                            Label(category.rawValue, systemImage: category.systemImage)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedCategory == category {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Photo Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onConfirm(selectedCategory)
                }
                .fontWeight(.semibold)
            }
        }
    }
}
