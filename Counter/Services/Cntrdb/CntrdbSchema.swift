import Foundation

// MARK: - Cntrdb Public Schema (v1)
//
// The `.cntrdb` SQLite schema is the **public, app-owned** export format —
// deliberately decoupled from SwiftData's internal store schema so that
// SwiftData migrations (V1 → V5+) cannot silently break exported files.
//
// Conventions (set once, do not break):
//   - Primary keys are TEXT holding UUID strings (uppercase, dashed).
//   - Foreign keys are TEXT holding the referenced UUID (or NULL).
//   - Dates are TEXT in ISO8601 with fractional seconds (`yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX`).
//   - `Decimal` values are TEXT preserving full precision; never REAL.
//   - String arrays / dictionaries / nested structs are TEXT holding compact JSON.
//   - Booleans are INTEGER (0/1) — SQLite has no native bool.
//   - Enum raw values are TEXT (we already store them as strings).
//
// Bumping `currentVersion` is a breaking change. Older importers MUST refuse
// newer files; newer importers MAY migrate older files via a per-version
// upgrade SQL script (not yet needed for v1).

enum CntrdbSchema {

    /// Schema version stamped into `_meta.schema_version` and `manifest.json`.
    /// Bump on any breaking change; never reuse a number.
    static let currentVersion: Int = 1

    /// Single canonical DDL applied to a fresh SQLite database.
    /// Order matters: parents before children so foreign key constraints
    /// resolve at CREATE time even when `PRAGMA foreign_keys = ON`.
    static let ddl: String = """
    PRAGMA foreign_keys = ON;
    PRAGMA journal_mode = DELETE;

    -- ============================================================
    -- _meta: one-row table describing this export
    -- ============================================================
    CREATE TABLE _meta (
        schema_version  INTEGER NOT NULL,
        app_version     TEXT    NOT NULL,
        exported_at     TEXT    NOT NULL,
        source_device   TEXT,
        notes           TEXT
    );

    -- ============================================================
    -- _user_defaults: key/value snapshot of relevant UserDefaults keys.
    -- Mirrors the JSON backup's UserDefaultsBackup field. Type column
    -- lets us round-trip Bool vs String correctly on import.
    -- ============================================================
    CREATE TABLE _user_defaults (
        key             TEXT PRIMARY KEY,
        value           TEXT,
        value_type      TEXT NOT NULL CHECK (value_type IN ('bool','string','int','double'))
    );

    -- ============================================================
    -- Configuration / standalone
    -- ============================================================
    CREATE TABLE user_profiles (
        id                          TEXT PRIMARY KEY,
        first_name                  TEXT NOT NULL,
        last_name                   TEXT NOT NULL,
        business_name               TEXT NOT NULL,
        email                       TEXT NOT NULL,
        phone                       TEXT NOT NULL,
        profession                  TEXT NOT NULL,
        profile_photo_path          TEXT,
        default_hourly_rate         TEXT NOT NULL,
        currency                    TEXT NOT NULL,
        deposit_flat                TEXT NOT NULL,
        deposit_percentage          TEXT NOT NULL,
        friends_family_discount     TEXT NOT NULL,
        preferred_client_discount   TEXT NOT NULL,
        holiday_discount            TEXT NOT NULL,
        convention_discount         TEXT NOT NULL,
        no_show_fee                 TEXT NOT NULL,
        revision_fee                TEXT NOT NULL,
        administrative_fee          TEXT NOT NULL,
        flash_pricing_mode_raw      TEXT NOT NULL,
        chargeable_session_types    TEXT NOT NULL, -- JSON array of strings
        status_color_names          TEXT NOT NULL, -- JSON object {String: String}
        shop_address_line1          TEXT NOT NULL,
        shop_address_line2          TEXT NOT NULL,
        shop_city                   TEXT NOT NULL,
        shop_state                  TEXT NOT NULL,
        shop_postal_code            TEXT NOT NULL,
        shop_country                TEXT NOT NULL,
        billing_address_line1       TEXT NOT NULL,
        billing_address_line2       TEXT NOT NULL,
        billing_city                TEXT NOT NULL,
        billing_state               TEXT NOT NULL,
        billing_postal_code         TEXT NOT NULL,
        billing_country             TEXT NOT NULL,
        created_at                  TEXT NOT NULL,
        updated_at                  TEXT NOT NULL
    );

    CREATE TABLE session_categories (
        id              TEXT PRIMARY KEY,
        uuid            TEXT NOT NULL,
        name            TEXT NOT NULL,
        is_chargeable   INTEGER NOT NULL,
        sort_order      INTEGER NOT NULL,
        created_at      TEXT NOT NULL
    );

    CREATE TABLE email_templates (
        id              TEXT PRIMARY KEY,
        name            TEXT NOT NULL,
        subject         TEXT NOT NULL,
        body            TEXT NOT NULL,
        category_raw    TEXT NOT NULL,
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL
    );

    CREATE TABLE availability_slots (
        id              TEXT PRIMARY KEY,
        day_of_week     INTEGER NOT NULL,
        start_time      TEXT NOT NULL,
        end_time        TEXT NOT NULL,
        slot_type_raw   TEXT NOT NULL,
        is_flash_only   INTEGER NOT NULL,
        is_active       INTEGER NOT NULL
    );

    CREATE TABLE availability_overrides (
        id              TEXT PRIMARY KEY,
        start_date      TEXT NOT NULL,
        end_date        TEXT NOT NULL,
        reason          TEXT NOT NULL,
        is_unavailable  INTEGER NOT NULL
    );

    CREATE TABLE session_rate_configs (
        id                       TEXT PRIMARY KEY,
        session_type_raw         TEXT NOT NULL,
        rate_mode_raw            TEXT NOT NULL,
        rate_value               TEXT NOT NULL,
        deposit_mode_raw         TEXT NOT NULL,
        discount_type_raw        TEXT NOT NULL,
        fee_type_raw             TEXT NOT NULL,
        flash_pricing_mode_raw   TEXT NOT NULL
    );

    CREATE TABLE flash_price_tiers (
        id              TEXT PRIMARY KEY,
        uuid            TEXT NOT NULL,
        label           TEXT NOT NULL,
        width_inches    REAL NOT NULL,
        height_inches   REAL NOT NULL,
        price           TEXT NOT NULL,
        sort_order      INTEGER NOT NULL
    );

    CREATE TABLE gallery_groups (
        id              TEXT PRIMARY KEY,
        name            TEXT NOT NULL,
        tags            TEXT NOT NULL, -- JSON array of strings
        sort_index      INTEGER NOT NULL,
        created_at      TEXT NOT NULL
    );

    CREATE TABLE discounts (
        id              TEXT PRIMARY KEY,
        name            TEXT NOT NULL,
        percentage      TEXT NOT NULL,
        sort_order      INTEGER NOT NULL
    );

    -- ============================================================
    -- Core: Clients are roots
    -- ============================================================
    CREATE TABLE clients (
        id                          TEXT PRIMARY KEY,
        first_name                  TEXT NOT NULL,
        last_name                   TEXT NOT NULL,
        email                       TEXT NOT NULL,
        phone                       TEXT NOT NULL,
        notes                       TEXT NOT NULL,
        pronouns                    TEXT NOT NULL,
        birthdate                   TEXT,
        allergy_notes               TEXT NOT NULL,
        street_address              TEXT NOT NULL,
        city                        TEXT NOT NULL,
        state                       TEXT NOT NULL,
        zip_code                    TEXT NOT NULL,
        profile_photo_path          TEXT,
        email_opt_in                INTEGER NOT NULL,
        is_flash_portfolio_client   INTEGER NOT NULL,
        created_at                  TEXT NOT NULL,
        updated_at                  TEXT NOT NULL
    );

    CREATE TABLE pieces (
        id                  TEXT PRIMARY KEY,
        client_id           TEXT REFERENCES clients(id) ON DELETE SET NULL,
        title               TEXT NOT NULL,
        body_placement      TEXT NOT NULL,
        description_text    TEXT NOT NULL,
        status              TEXT NOT NULL,
        piece_type          TEXT NOT NULL,
        tags                TEXT NOT NULL, -- JSON array of strings
        primary_image_path  TEXT,
        rating              INTEGER,
        size                TEXT,
        size_dimensions     TEXT, -- JSON object {width, height} or NULL
        hourly_rate         TEXT NOT NULL,
        flat_rate           TEXT,
        deposit_amount      TEXT NOT NULL,
        created_at          TEXT NOT NULL,
        updated_at          TEXT NOT NULL,
        completed_at        TEXT
    );
    CREATE INDEX idx_pieces_client ON pieces(client_id);

    CREATE TABLE sessions (
        id                      TEXT PRIMARY KEY,
        piece_id                TEXT REFERENCES pieces(id) ON DELETE SET NULL,
        date                    TEXT NOT NULL,
        start_time              TEXT NOT NULL,
        end_time                TEXT,
        break_minutes           INTEGER NOT NULL,
        session_type            TEXT NOT NULL,
        hourly_rate_at_time     TEXT NOT NULL,
        flash_rate              TEXT NOT NULL,
        manual_hours_override   REAL,
        is_no_show              INTEGER NOT NULL,
        no_show_fee             TEXT,
        notes                   TEXT NOT NULL
    );
    CREATE INDEX idx_sessions_piece ON sessions(piece_id);

    CREATE TABLE session_progress (
        id                  TEXT PRIMARY KEY,
        piece_id            TEXT REFERENCES pieces(id) ON DELETE SET NULL,
        session_id          TEXT REFERENCES sessions(id) ON DELETE SET NULL,
        stage               TEXT NOT NULL,
        notes               TEXT NOT NULL,
        time_spent_minutes  INTEGER NOT NULL,
        created_at          TEXT NOT NULL
    );
    CREATE INDEX idx_session_progress_piece ON session_progress(piece_id);
    CREATE INDEX idx_session_progress_session ON session_progress(session_id);

    -- ============================================================
    -- Gallery
    -- ============================================================
    CREATE TABLE work_images (
        id                      TEXT PRIMARY KEY,
        session_progress_id     TEXT REFERENCES session_progress(id) ON DELETE SET NULL,
        piece_id                TEXT REFERENCES pieces(id) ON DELETE SET NULL,
        client_id               TEXT REFERENCES clients(id) ON DELETE SET NULL,
        file_path               TEXT NOT NULL,
        file_name               TEXT NOT NULL,
        title                   TEXT NOT NULL,
        notes                   TEXT NOT NULL,
        captured_at             TEXT NOT NULL,
        sort_order              INTEGER NOT NULL,
        is_primary              INTEGER NOT NULL,
        is_portfolio            INTEGER NOT NULL,
        category                TEXT NOT NULL,
        healing_stage           TEXT,
        source                  TEXT NOT NULL,
        tags                    TEXT NOT NULL  -- JSON array of strings
    );
    CREATE INDEX idx_work_images_piece ON work_images(piece_id);
    CREATE INDEX idx_work_images_client ON work_images(client_id);
    CREATE INDEX idx_work_images_session_progress ON work_images(session_progress_id);

    -- ============================================================
    -- Bookings, Agreements, Communications, Payments
    -- ============================================================
    CREATE TABLE bookings (
        id                       TEXT PRIMARY KEY,
        client_id                TEXT REFERENCES clients(id) ON DELETE SET NULL,
        piece_id                 TEXT REFERENCES pieces(id) ON DELETE SET NULL,
        date                     TEXT NOT NULL,
        start_time               TEXT NOT NULL,
        end_time                 TEXT NOT NULL,
        status                   TEXT NOT NULL,
        booking_type             TEXT NOT NULL,
        notes                    TEXT NOT NULL,
        deposit_paid             INTEGER NOT NULL,
        reminder_sent            INTEGER NOT NULL,
        checklist_overrides      TEXT NOT NULL, -- JSON array of strings
        custom_checklist_items   TEXT NOT NULL, -- JSON array of BookingCustomTask
        created_at               TEXT NOT NULL,
        updated_at               TEXT NOT NULL
    );
    CREATE INDEX idx_bookings_client ON bookings(client_id);
    CREATE INDEX idx_bookings_piece  ON bookings(piece_id);

    CREATE TABLE agreements (
        id                       TEXT PRIMARY KEY,
        client_id                TEXT REFERENCES clients(id) ON DELETE SET NULL,
        title                    TEXT NOT NULL,
        agreement_type           TEXT NOT NULL,
        body_text                TEXT NOT NULL,
        is_signed                INTEGER NOT NULL,
        signed_at                TEXT,
        signature_image_path     TEXT,
        created_at               TEXT NOT NULL
    );
    CREATE INDEX idx_agreements_client ON agreements(client_id);

    CREATE TABLE communication_logs (
        id                       TEXT PRIMARY KEY,
        client_id                TEXT REFERENCES clients(id) ON DELETE SET NULL,
        comm_type                TEXT NOT NULL,
        subject                  TEXT NOT NULL,
        body_text                TEXT NOT NULL,
        sent_at                  TEXT NOT NULL,
        was_auto_generated       INTEGER NOT NULL
    );
    CREATE INDEX idx_communication_logs_client ON communication_logs(client_id);

    CREATE TABLE payments (
        id                       TEXT PRIMARY KEY,
        client_id                TEXT REFERENCES clients(id) ON DELETE SET NULL,
        piece_id                 TEXT REFERENCES pieces(id) ON DELETE SET NULL,
        amount                   TEXT NOT NULL,
        payment_date             TEXT NOT NULL,
        payment_method           TEXT NOT NULL,
        payment_type             TEXT NOT NULL,
        notes                    TEXT NOT NULL,
        created_at               TEXT NOT NULL
    );
    CREATE INDEX idx_payments_client ON payments(client_id);
    CREATE INDEX idx_payments_piece  ON payments(piece_id);
    """

    /// Phased table list used by the importer to choose insert order.
    /// Mirrors `RecoveryService.deserializeAndInsert` so the relational
    /// inserts respect parent-before-child ordering even though SQLite
    /// foreign keys are declared with `ON DELETE SET NULL` (lenient).
    static let importPhases: [[String]] = [
        ["user_profiles", "session_categories", "email_templates",
         "availability_slots", "availability_overrides", "session_rate_configs",
         "flash_price_tiers", "gallery_groups", "discounts"],
        ["clients"],
        ["pieces"],
        ["sessions"],
        ["session_progress"],
        ["work_images"],
        ["agreements", "communication_logs"],
        ["payments"],
        ["bookings"]
    ]
}
