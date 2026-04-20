import UIKit
import SwiftUI
import SwiftData

/// Handles exporting images and PDFs via the system share sheet.
/// Supports PNG, TIFF, and PDF export with no external dependencies.
struct ExportService {

    /// Export a single image as PNG via share sheet
    static func shareImage(_ image: UIImage, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        activityVC.modalPresentationStyle = .popover
        viewController.present(activityVC, animated: true)
    }

    /// Export multiple images
    static func shareImages(_ images: [UIImage], from viewController: UIViewController) {
        let activityVC = UIActivityViewController(
            activityItems: images,
            applicationActivities: nil
        )
        activityVC.modalPresentationStyle = .popover
        viewController.present(activityVC, animated: true)
    }

    /// Export PDF data via share sheet
    static func sharePDF(_ data: Data, fileName: String, from viewController: UIViewController) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)

        let activityVC = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        activityVC.modalPresentationStyle = .popover
        viewController.present(activityVC, animated: true)
    }

    /// Save image as TIFF data (with alpha channel preserved)
    static func imageAsTIFF(_ image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            "public.tiff" as CFString,
            1,
            nil
        ) else { return nil }

        let options: [CFString: Any] = [
            kCGImagePropertyTIFFCompression: 5, // LZW compression
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return mutableData as Data
    }

    /// Save image as PNG data
    static func imageAsPNG(_ image: UIImage) -> Data? {
        image.pngData()
    }
}

/// SwiftUI share sheet wrapper for PDFs and images
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// View for exporting a client report
struct ClientReportExportView: View {
    let client: Client
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @State private var isGenerating = false
    @State private var pdfData: Data?
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Full Client Report", systemImage: "doc.text.fill")
                            .font(.headline)
                        Text("Includes contact info, all pieces, sessions, financials, agreements, and communication log.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Included") {
                    row("Contact Information", systemImage: "person.fill")
                    row("Pieces & Sessions", systemImage: "flame")
                    row("Financial Summary", systemImage: "dollarsign.circle")
                    row("Signed Agreements", systemImage: "checkmark.seal.fill")
                    row("Communication Log", systemImage: "envelope.fill")
                }

                Section {
                    Button {
                        generateAndShare()
                    } label: {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Generating...")
                            } else {
                                Label("Generate PDF Report", systemImage: "doc.badge.arrow.up")
                            }
                            Spacer()
                        }
                        .font(.body.weight(.semibold))
                    }
                    .disabled(isGenerating)
                }
            }
            .navigationTitle("Export Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfData {
                    let tempURL = saveTempPDF(pdfData, name: "\(client.fullName)_Report.pdf")
                    ShareSheet(items: [tempURL])
                }
            }
        }
    }

    private func row(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func generateAndShare() {
        isGenerating = true
        let types = profiles.first?.effectiveChargeableSessionTypes ?? SessionType.defaultChargeableRawValues
        Task {
            let data = await PDFReportService.shared.generateClientReport(client: client, chargeableTypes: types)
            await MainActor.run {
                pdfData = data
                isGenerating = false
                showingShareSheet = true
            }
        }
    }

    private func saveTempPDF(_ data: Data, name: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }
}

/// View for exporting an agreement as PDF
struct AgreementExportView: View {
    let agreement: Agreement
    @Environment(\.dismiss) private var dismiss
    @State private var isGenerating = false
    @State private var showingShareSheet = false
    @State private var pdfData: Data?

    var body: some View {
        Button {
            exportAgreement()
        } label: {
            Label("Export as PDF", systemImage: "doc.badge.arrow.up")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let pdfData {
                let tempURL = saveTempPDF(pdfData, name: "\(agreement.title).pdf")
                ShareSheet(items: [tempURL])
            }
        }
    }

    private func exportAgreement() {
        isGenerating = true
        Task {
            // Load signature image if available
            var sigImage: UIImage?
            if let path = agreement.signatureImagePath {
                sigImage = await ImageStorageService.shared.loadImage(relativePath: path)
            }

            let data = await PDFReportService.shared.generateAgreementPDF(
                agreement: agreement,
                signatureImage: sigImage
            )
            await MainActor.run {
                pdfData = data
                isGenerating = false
                showingShareSheet = true
            }
        }
    }

    private func saveTempPDF(_ data: Data, name: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }
}
