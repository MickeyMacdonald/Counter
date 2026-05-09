import Foundation
import SQLite3

// MARK: - SQLite Service
//
// Thin, opinionated Swift wrapper around the system `libsqlite3` for
// callers that need raw SQLite access without taking on a third-party
// dependency. Currently used by the `.cntrdb` export/import path, but
// deliberately domain-agnostic — RecoveryService, future archive formats,
// or test fixtures can all sit on top of it.
//
// Design constraints:
//   - Zero dependencies (libsqlite3 ships in the iOS SDK).
//   - Surface kept small: open, exec, prepare/bind/step, transaction, row read.
//   - Errors are structured (`SQLiteError`) so callers can choose to wrap
//     them in their own domain errors or surface directly.
//   - The wrapper is safe to use from one actor at a time but does NOT
//     perform internal serialisation — concurrent use must be externally
//     coordinated.
//
// `SQLITE_TRANSIENT` is required when binding Swift `String` values: SQLite
// otherwise assumes the buffer outlives the bind call, which is unsafe for
// `withCString` lifetimes.

private let SQLITE_TRANSIENT = unsafeBitCast(
    OpaquePointer(bitPattern: -1),
    to: sqlite3_destructor_type.self
)

// MARK: - Errors

enum SQLiteError: Error, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)
    case execFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let detail):
            return "Could not open SQLite database: \(detail)"
        case .prepareFailed(let detail):
            return "Could not prepare SQLite statement: \(detail)"
        case .stepFailed(let detail):
            return "SQLite step failed: \(detail)"
        case .bindFailed(let detail):
            return "Could not bind SQLite parameter: \(detail)"
        case .execFailed(let detail):
            return "SQLite exec failed: \(detail)"
        }
    }
}

// MARK: - Connection

final class SQLiteConnection {

    /// Opaque connection handle; `nil` only after `close()`.
    private var db: OpaquePointer?

    // MARK: Open / Close

    /// Opens or creates the SQLite database at `url`. Enables foreign keys
    /// and forces DELETE journal mode so the resulting file is a single
    /// self-contained payload — no `-wal`/`-shm` siblings to forget when
    /// shipping the file via AirDrop, the share sheet, or a folder copy.
    init(openAt url: URL, create: Bool) throws {
        let flags: Int32 = create
            ? (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            : SQLITE_OPEN_READWRITE
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(url.path, &handle, flags, nil)
        guard rc == SQLITE_OK, let h = handle else {
            let msg = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "rc=\(rc)"
            if let h = handle { sqlite3_close(h) }
            throw SQLiteError.openFailed(msg)
        }
        self.db = h
        // Foreign keys default to OFF in SQLite for backwards compat; we
        // want them honoured for ON DELETE clauses on the import side.
        try exec("PRAGMA foreign_keys = ON")
        try exec("PRAGMA journal_mode = DELETE")
    }

    deinit {
        if let db = db { sqlite3_close(db) }
    }

    func close() {
        if let db = db { sqlite3_close(db) }
        self.db = nil
    }

    // MARK: Exec (multi-statement)

    /// Runs one or more SQL statements separated by `;`. Used for DDL
    /// application. Throws on the first failure with the SQLite error
    /// message attached so callers see something actionable instead of `rc=1`.
    func exec(_ sql: String) throws {
        guard let db = db else { throw SQLiteError.openFailed("connection closed") }
        var errPtr: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errPtr)
        if rc != SQLITE_OK {
            let msg = errPtr.map { String(cString: $0) } ?? "rc=\(rc)"
            sqlite3_free(errPtr)
            throw SQLiteError.execFailed(msg)
        }
    }

    // MARK: Transactions

    /// Wraps `body` in a SQL transaction. Commits on success, rolls back on
    /// throw. Best-effort rollback — if rollback itself fails, the original
    /// error is preserved (the rollback failure is swallowed silently
    /// because surfacing it would mask the real problem).
    func transaction<T>(_ body: () throws -> T) throws -> T {
        try exec("BEGIN TRANSACTION")
        do {
            let result = try body()
            try exec("COMMIT")
            return result
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    // MARK: Prepared statements

    /// Returns a prepared statement bound to this connection. Caller must
    /// finalize() it (typically via `defer`) — there is no automatic
    /// finalization because lifetimes are intentionally short.
    func prepare(_ sql: String) throws -> SQLiteStatement {
        guard let db = db else { throw SQLiteError.openFailed("connection closed") }
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let s = stmt else {
            let msg = String(cString: sqlite3_errmsg(db))
            if let s = stmt { sqlite3_finalize(s) }
            throw SQLiteError.prepareFailed(msg)
        }
        return SQLiteStatement(handle: s, db: db)
    }

    /// Convenience: prepare → bind → step until done. Used for inserts.
    func write(_ sql: String, _ params: [SQLiteValue]) throws {
        let stmt = try prepare(sql)
        defer { stmt.finalize() }
        try stmt.bind(params)
        try stmt.stepDone()
    }
}

// MARK: - Value bridging

/// Sum type wrapping every SQL value bound or read. Keeping this explicit
/// (rather than `Any`) makes the bind site type-checked and avoids
/// accidental double conversions at the C boundary.
enum SQLiteValue {
    case null
    case int(Int64)
    case double(Double)
    case text(String)
}

// MARK: Convenience constructors
//
// These are helpers callers reach for when binding common Swift types.
// Encoding decisions made here are baked in for the whole app:
//
//   - UUID: uppercase, hyphenated, via `uuidString`.
//   - Date: ISO8601 with fractional seconds (preserves SwiftData's
//     millisecond precision — bare ISO8601 would silently truncate).
//   - Decimal: TEXT formatted with POSIX locale to avoid locale-dependent
//     separators and to round-trip exactly via `Decimal(string:locale:)`.
//   - Codable values: compact JSON UTF-8 with sortedKeys (so a row diff
//     against another export is meaningful).
//
// If a future format needs different conventions, extend with an alternate
// helper rather than reusing these — these decisions are now contract.

extension SQLiteValue {

    static func bool(_ v: Bool) -> SQLiteValue { .int(v ? 1 : 0) }

    static func int(_ v: Int)    -> SQLiteValue { .int(Int64(v)) }
    static func int(_ v: Int?)   -> SQLiteValue { v.map { .int(Int64($0)) } ?? .null }
    static func int(_ v: Int64?) -> SQLiteValue { v.map(SQLiteValue.int) ?? .null }

    static func real(_ v: Double)  -> SQLiteValue { .double(v) }
    static func real(_ v: Double?) -> SQLiteValue { v.map(SQLiteValue.double) ?? .null }

    static func text(_ v: String?) -> SQLiteValue { v.map(SQLiteValue.text) ?? .null }

    static func decimal(_ v: Decimal) -> SQLiteValue {
        .text(NSDecimalNumber(decimal: v).description(withLocale: Locale(identifier: "en_US_POSIX")))
    }
    static func decimal(_ v: Decimal?) -> SQLiteValue {
        v.map(SQLiteValue.decimal) ?? .null
    }

    static func uuid(_ v: UUID)  -> SQLiteValue { .text(v.uuidString) }
    static func uuid(_ v: UUID?) -> SQLiteValue { v.map { .text($0.uuidString) } ?? .null }

    static func date(_ v: Date)  -> SQLiteValue { .text(SQLiteDateFormat.string(from: v)) }
    static func date(_ v: Date?) -> SQLiteValue { v.map(SQLiteValue.date) ?? .null }

    /// Encodes `value` to compact JSON UTF-8 and stores as TEXT. Hard
    /// failure is surfaced via assertionFailure rather than throwing
    /// because every type bound this way is Codable by construction;
    /// runtime failure here would indicate a programming error, not a
    /// recoverable condition.
    static func json<T: Encodable>(_ value: T) -> SQLiteValue {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(value)
            return .text(String(data: data, encoding: .utf8) ?? "")
        } catch {
            assertionFailure("SQLiteValue.json encoding failed: \(error)")
            return .text("")
        }
    }
}

// MARK: - Statement

/// Wraps a prepared `sqlite3_stmt`. Owners must call `finalize()` (or rely
/// on the `defer` pattern in callers).
final class SQLiteStatement {

    private let handle: OpaquePointer
    private let db: OpaquePointer

    init(handle: OpaquePointer, db: OpaquePointer) {
        self.handle = handle
        self.db = db
    }

    func finalize() {
        sqlite3_finalize(handle)
    }

    // MARK: Bind

    /// Binds positional parameters in order. Indices are 1-based at the
    /// SQLite C level; we hide that here so callers always pass `[v0, v1, ...]`.
    func bind(_ values: [SQLiteValue]) throws {
        sqlite3_reset(handle)
        sqlite3_clear_bindings(handle)
        for (i, v) in values.enumerated() {
            try bind(v, at: Int32(i + 1))
        }
    }

    private func bind(_ v: SQLiteValue, at idx: Int32) throws {
        let rc: Int32
        switch v {
        case .null:
            rc = sqlite3_bind_null(handle, idx)
        case .int(let i):
            rc = sqlite3_bind_int64(handle, idx, i)
        case .double(let d):
            rc = sqlite3_bind_double(handle, idx, d)
        case .text(let s):
            rc = sqlite3_bind_text(handle, idx, s, -1, SQLITE_TRANSIENT)
        }
        if rc != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.bindFailed("idx=\(idx): \(msg)")
        }
    }

    // MARK: Step

    /// Runs a write statement that returns no rows (INSERT/UPDATE/DELETE).
    /// Throws unless the step finishes with SQLITE_DONE.
    func stepDone() throws {
        let rc = sqlite3_step(handle)
        guard rc == SQLITE_DONE else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.stepFailed("rc=\(rc): \(msg)")
        }
    }

    /// Iterates a SELECT, calling `body` once per row. The `Row` argument
    /// is a thin reader bound to this statement; it MUST NOT escape the
    /// callback — the underlying memory belongs to SQLite and is
    /// invalidated on the next step.
    func forEachRow(_ body: (SQLiteRow) throws -> Void) throws {
        while true {
            let rc = sqlite3_step(handle)
            if rc == SQLITE_DONE { return }
            if rc == SQLITE_ROW {
                try body(SQLiteRow(handle: handle))
                continue
            }
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.stepFailed("rc=\(rc): \(msg)")
        }
    }
}

// MARK: - Row reader

/// Read-only view of the current row. All accessors are 0-indexed by
/// column position; callers know their schema, so we don't need name lookup.
struct SQLiteRow {
    let handle: OpaquePointer

    func isNull(_ col: Int) -> Bool {
        sqlite3_column_type(handle, Int32(col)) == SQLITE_NULL
    }

    func int(_ col: Int) -> Int {
        Int(sqlite3_column_int64(handle, Int32(col)))
    }

    func intOrNil(_ col: Int) -> Int? {
        isNull(col) ? nil : int(col)
    }

    func bool(_ col: Int) -> Bool {
        sqlite3_column_int64(handle, Int32(col)) != 0
    }

    func double(_ col: Int) -> Double {
        sqlite3_column_double(handle, Int32(col))
    }

    func doubleOrNil(_ col: Int) -> Double? {
        isNull(col) ? nil : double(col)
    }

    /// Returns "" for SQLITE_NULL; use `textOrNil` if you need to distinguish.
    func text(_ col: Int) -> String {
        guard let cstr = sqlite3_column_text(handle, Int32(col)) else { return "" }
        return String(cString: cstr)
    }

    func textOrNil(_ col: Int) -> String? {
        isNull(col) ? nil : text(col)
    }

    func uuid(_ col: Int) -> UUID? {
        guard let s = textOrNil(col) else { return nil }
        return UUID(uuidString: s)
    }

    func date(_ col: Int) -> Date? {
        guard let s = textOrNil(col) else { return nil }
        return SQLiteDateFormat.date(from: s)
    }

    /// Decimals are stored as POSIX-formatted TEXT; if that ever changes,
    /// also update `SQLiteValue.decimal(_:)` to match.
    func decimal(_ col: Int) -> Decimal? {
        guard let s = textOrNil(col) else { return nil }
        return Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Decodes a JSON-encoded TEXT column into the requested type.
    /// Returns `nil` when the column is NULL OR the JSON is malformed —
    /// callers decide whether that's a hard fail or a soft default.
    func json<T: Decodable>(_ col: Int, as type: T.Type) -> T? {
        guard let s = textOrNil(col), let data = s.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }
}

// MARK: - Date formatting
//
// One canonical formatter used by both `SQLiteValue.date(_:)` and
// `SQLiteRow.date(_:)`. Centralising the format here means write and read
// can never silently drift apart. ISO8601 with fractional seconds is the
// app-wide choice — it preserves SwiftData millisecond precision and is
// human-readable from any SQLite browser.

enum SQLiteDateFormat {

    static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    /// Tolerant parser: accepts both fractional and non-fractional ISO8601.
    /// Hand-edited fixtures and pre-fractional payloads round-trip cleanly.
    static func date(from string: String) -> Date? {
        if let d = formatter.date(from: string) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
