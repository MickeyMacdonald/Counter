import Foundation
import UIKit

/// Manages all image file storage on the local file system.
/// Images are stored outside the database to keep it lean.
/// Directory structure: Documents/CounterImages/{clientID}/{pieceID}/{stage}/
actor ImageStorageService {
    static let shared = ImageStorageService()

    private let fileManager = FileManager.default
    private let baseDirectoryName = "CounterImages"

    private var baseURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(baseDirectoryName)
    }

    // MARK: - Save

    func saveImage(
        _ image: UIImage,
        clientID: String,
        pieceID: String,
        stage: String,
        fileName: String? = nil
    ) throws -> String {
        let directory = pathForStage(clientID: clientID, pieceID: pieceID, stage: stage)
        let dirURL = baseURL.appendingPathComponent(directory)

        try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let name = fileName ?? "\(UUID().uuidString).png"
        let fileURL = dirURL.appendingPathComponent(name)
        let relativePath = "\(baseDirectoryName)/\(directory)/\(name)"

        guard let data = image.pngData() else {
            throw ImageStorageError.encodingFailed
        }

        try data.write(to: fileURL)
        return relativePath
    }

    // MARK: - Load

    func loadImage(relativePath: String) -> UIImage? {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docs.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    // MARK: - Delete

    func deleteImage(relativePath: String) throws {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docs.appendingPathComponent(relativePath)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    func deleteClientDirectory(clientID: String) throws {
        let dirURL = baseURL.appendingPathComponent(clientID)
        if fileManager.fileExists(atPath: dirURL.path) {
            try fileManager.removeItem(at: dirURL)
        }
    }

    // MARK: - Storage Info

    func totalStorageUsedBytes() -> UInt64 {
        guard fileManager.fileExists(atPath: baseURL.path) else { return 0 }
        return directorySize(url: baseURL)
    }

    var totalStorageFormatted: String {
        let bytes = totalStorageUsedBytes()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Helpers

    private func pathForStage(clientID: String, pieceID: String, stage: String) -> String {
        "\(clientID)/\(pieceID)/\(stage)"
    }

    private func directorySize(url: URL) -> UInt64 {
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        var total: UInt64 = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        return total
    }
}

enum ImageStorageError: Error, LocalizedError {
    case encodingFailed
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .encodingFailed: "Failed to encode image data"
        case .fileNotFound: "Image file not found on disk"
        }
    }
}
