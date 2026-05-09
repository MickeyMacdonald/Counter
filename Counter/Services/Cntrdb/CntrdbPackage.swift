import Foundation
import CryptoKit

// MARK: - Cntrdb Package Layout
//
// A `.cntrdb` is a folder bundle on disk:
//
//     MyBackup.cntrdb/
//       database.sqlite     <- structured relational data (CntrdbSchema)
//       Images/             <- mirror of Documents/CounterImages
//       manifest.json       <- format/schema version + integrity metadata
//
// We use a folder rather than a single file for the same reason the JSON
// backup pipeline does — image trees can be hundreds of MB and we want the
// OS file system to handle them, not a giant BLOB column. The folder is
// registered as a UTI (`com.counter.cntrdb`) so the share sheet and Files
// app treat it as one opaque "document".

struct CntrdbPackage {

    // MARK: Layout constants

    static let fileExtension = "cntrdb"
    static let databaseFileName = "database.sqlite"
    static let imagesFolderName = "Images"
    static let manifestFileName = "manifest.json"

    /// Bumped only when the *package layout* itself changes (file names,
    /// adding sibling files, etc). Independent from `CntrdbSchema.currentVersion`,
    /// which tracks SQL schema changes.
    static let currentFormatVersion: Int = 1

    let url: URL

    var databaseURL: URL { url.appendingPathComponent(Self.databaseFileName) }
    var imagesURL:   URL { url.appendingPathComponent(Self.imagesFolderName) }
    var manifestURL: URL { url.appendingPathComponent(Self.manifestFileName) }

    // MARK: Creation

    /// Creates the on-disk folder skeleton for a new package. Caller is
    /// responsible for writing the database, copying images, and writing
    /// the manifest. Throws if the folder already exists — callers that
    /// want to overwrite must remove the existing folder first.
    @discardableResult
    static func create(at url: URL) throws -> CntrdbPackage {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            throw CntrdbError.packageAlreadyExists(url.lastPathComponent)
        }
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        try fm.createDirectory(at: url.appendingPathComponent(Self.imagesFolderName),
                               withIntermediateDirectories: true)
        return CntrdbPackage(url: url)
    }

    /// Lightweight existence/shape check — useful for early-failing the
    /// importer before spinning up SQLite.
    static func validateLayout(at url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            throw CntrdbError.packageNotFound(url.lastPathComponent)
        }
        let pkg = CntrdbPackage(url: url)
        guard fm.fileExists(atPath: pkg.databaseURL.path) else {
            throw CntrdbError.malformedPackage("missing \(Self.databaseFileName)")
        }
        guard fm.fileExists(atPath: pkg.manifestURL.path) else {
            throw CntrdbError.malformedPackage("missing \(Self.manifestFileName)")
        }
        // Images folder is allowed to be absent only when the manifest
        // declares zero images; the importer enforces that, not us.
    }
}

// MARK: - Manifest

/// Top-level metadata written alongside the SQLite database. Lives in JSON
/// (not SQLite) so it can be inspected and compared without opening the DB.
/// The `database_checksum` field is the SHA-256 of `database.sqlite` at
/// write time — the importer recomputes it before touching the live store.
struct CntrdbManifest: Codable {
    let formatVersion: Int          // CntrdbPackage.currentFormatVersion
    let schemaVersion: Int          // CntrdbSchema.currentVersion
    let appVersion: String          // human-readable, e.g. "0.8.2 (104)"
    let createdAt: Date
    let modelCount: Int
    let imageCount: Int
    let databaseSizeBytes: UInt64
    let imageSizeBytes: UInt64
    let databaseChecksum: String    // SHA-256 hex of database.sqlite
    let sourceDevice: String?
    let notes: String?

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256HexOfFile(at url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return sha256Hex(data)
    }
}

// MARK: - Errors

enum CntrdbError: Error, LocalizedError {
    // Package-level
    case packageAlreadyExists(String)
    case packageNotFound(String)
    case malformedPackage(String)

    // Manifest-level
    case manifestUnreadable(String)
    case formatVersionUnsupported(found: Int, expected: Int)
    case schemaVersionUnsupported(found: Int, expected: Int)
    case databaseChecksumMismatch(expected: String, actual: String)

    // Image integrity
    case imageCountMismatch(expected: Int, actual: Int)
    case imagesFolderMissing

    // Import flow
    case refuseEmptyImport
    case preRestoreSnapshotFailed(String)
    case importFailed(String)

    // Export flow
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .packageAlreadyExists(let n):
            return "A .cntrdb package named \"\(n)\" already exists at that location."
        case .packageNotFound(let n):
            return "Could not find the .cntrdb package \"\(n)\"."
        case .malformedPackage(let detail):
            return "The .cntrdb package is incomplete or damaged: \(detail)."
        case .manifestUnreadable(let detail):
            return "Could not read the .cntrdb manifest: \(detail)."
        case .formatVersionUnsupported(let found, let expected):
            return "This .cntrdb file uses package format \(found); this build supports up to \(expected). Update the app to import it."
        case .schemaVersionUnsupported(let found, let expected):
            return "This .cntrdb file uses schema version \(found); this build supports up to \(expected). Update the app to import it."
        case .databaseChecksumMismatch(let expected, let actual):
            return "Database integrity check failed. The .cntrdb file may be corrupt or partially copied. (expected \(expected.prefix(12))…, got \(actual.prefix(12))…)"
        case .imageCountMismatch(let expected, let actual):
            return "Image count mismatch in .cntrdb: manifest claims \(expected) image files, but \(actual) were found."
        case .imagesFolderMissing:
            return "The .cntrdb manifest declares images, but the Images folder is missing from the package."
        case .refuseEmptyImport:
            return "The .cntrdb file contains zero records. Importing it would erase your current data. Aborted."
        case .preRestoreSnapshotFailed(let detail):
            return "Could not save a safety snapshot before importing. Aborted. (\(detail))"
        case .importFailed(let detail):
            return "Import failed: \(detail)"
        case .exportFailed(let detail):
            return "Export failed: \(detail)"
        }
    }
}

// Date formatting for cntrdb columns lives in `SQLiteService.SQLiteDateFormat`
// — the SQLite layer owns the canonical format so write and read can't drift.
