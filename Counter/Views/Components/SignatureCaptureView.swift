import SwiftUI
import PencilKit

/// Full PencilKit-based signature capture pad.
/// Designed for client sign-off on iPad, optimized for finger and Apple Pencil.
struct SignatureCaptureView: View {
    @Binding var signatureImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    @State private var canvasView = PKCanvasView()
    @State private var hasDrawn = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Instructions
                Text("Sign below")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                // Signature pad
                SignatureCanvas(canvasView: $canvasView, hasDrawn: $hasDrawn)
                    .frame(height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.background)
                            .shadow(color: .primary.opacity(0.08), radius: 4, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                    )
                    .padding()

                // Signature line
                HStack {
                    Rectangle()
                        .fill(.primary.opacity(0.3))
                        .frame(height: 1)
                    Text("Signature")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 40)
                .offset(y: -24)

                Spacer()
            }
            .navigationTitle("Capture Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        canvasView.drawing = PKDrawing()
                        hasDrawn = false
                    } label: {
                        Label("Clear", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!hasDrawn)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Accept") {
                        captureSignature()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasDrawn)
                }
            }
        }
    }

    private func captureSignature() {
        let renderer = UIGraphicsImageRenderer(bounds: canvasView.bounds)
        let image = renderer.image { context in
            canvasView.drawHierarchy(in: canvasView.bounds, afterScreenUpdates: true)
        }
        signatureImage = image
    }
}

/// UIKit PencilKit wrapper
struct SignatureCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var hasDrawn: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        // Use a thin black pen for signatures
        let inkingTool = PKInkingTool(.pen, color: .label, width: 3)
        canvasView.tool = inkingTool

        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(hasDrawn: $hasDrawn)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var hasDrawn: Bool

        init(hasDrawn: Binding<Bool>) {
            _hasDrawn = hasDrawn
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            hasDrawn = !canvasView.drawing.strokes.isEmpty
        }
    }
}
