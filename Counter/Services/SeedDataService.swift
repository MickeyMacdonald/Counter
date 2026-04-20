import Foundation
import SwiftData
import UIKit

/// Populates the persistent store with realistic dummy data for testing.
/// Gates a fresh seed behind UserDefaults flags; exposes `wipeAndReseed` for dev resets.
@MainActor
enum SeedDataService {

    // MARK: - Keys

    private static let seedKey        = "com.counter.hasSeededData.v2"
    private static let paymentKey     = "com.counter.hasSeededPayments"
    private static let flashKey       = "com.counter.hasSeededFlashPortfolio"

    static var hasSeeded: Bool { UserDefaults.standard.bool(forKey: seedKey) }

    // MARK: - Public API

    static func seedIfNeeded(context: ModelContext) {
        if !hasSeeded {
            seed(context: context)
            markAllSeeded()
        }
        if !UserDefaults.standard.bool(forKey: flashKey) {
            seedFlashPortfolioClient(context: context)
            UserDefaults.standard.set(true, forKey: flashKey)
        }
    }

    /// Deletes every record in the store, then runs a fresh seed. For dev/test use.
    static func wipeAndReseed(context: ModelContext) {
        wipeAll(context: context)
        resetSeedFlags()
        seed(context: context)
        seedFlashPortfolioClient(context: context)
        markAllSeeded()
    }

    // MARK: - Wipe

    static func wipeAll(context: ModelContext) {
        let types: [any PersistentModel.Type] = [
            PieceImage.self, SessionProgress.self, Session.self,
            Booking.self, Payment.self, Agreement.self,
            CommunicationLog.self, PieceImage.self,
            Piece.self, Client.self, UserProfile.self,
            SessionType.self, EmailTemplate.self,
            AvailabilitySlot.self, AvailabilityOverride.self,
            SessionRateConfig.self, FlashPriceTier.self, GalleryGroup.self
        ]
        for type in types {
            try? context.delete(model: type)
        }
        try? context.save()
    }

    // MARK: - Helpers

    private static func markAllSeeded() {
        UserDefaults.standard.set(true, forKey: seedKey)
        UserDefaults.standard.set(true, forKey: paymentKey)
        UserDefaults.standard.set(true, forKey: flashKey)
    }

    private static func resetSeedFlags() {
        UserDefaults.standard.removeObject(forKey: seedKey)
        UserDefaults.standard.removeObject(forKey: paymentKey)
        UserDefaults.standard.removeObject(forKey: flashKey)
    }

    // MARK: - Payment Scenarios

    private enum PaymentScenario {
        case fullyPaid                        // deposit + full balance settled, optional tip
        case depositAndPartial(pct: Double)   // deposit + X% of remainder
        case depositOnly                      // deposit only — balance open
        case unpaid                           // nothing paid yet
        case noShow(fee: Decimal)             // no-show fee charged
    }

    // MARK: - Main Seed

    private static func seed(context: ModelContext) {
        let cal  = Calendar.current
        let now  = Date()

        func date(daysFromNow d: Int, hour h: Int = 10, minute m: Int = 0) -> Date {
            let base = cal.date(byAdding: .day, value: d, to: now)!
            return cal.date(bySettingHour: h, minute: m, second: 0, of: base)!
        }

        // MARK: Profile
        let profile = UserProfile(
            firstName: "Casey",
            lastName: "Morgan",
            businessName: "Iron & Ink Studio",
            email: "casey@ironink.com",
            phone: "555-9999",
            profession: .tattooer,
            defaultHourlyRate: 175,
            depositPercentage: 25
        )
        context.insert(profile)

        for day in 1...5 { context.insert(AvailabilitySlot(dayOfWeek: day)) }

        let rate: Decimal = 175
        let dep:  Decimal = 150

        // MARK: - Client Roster

        // ── 1. Alex Rivera ───────────────────────────────────────────────────
        do {
            let c = makeClient("Alex", "Rivera", "alex@example.com", "555-0101",
                               "they/them", "Loves botanical and nature motifs.",
                               "Red ink sensitivity", context: context)
            addPiece(
                context: context, client: c,
                title: "Botanical Sleeve", placement: "Left forearm",
                desc: "Mixed floral sleeve with fern and peony motifs",
                status: .inProgress, tags: ["floral", "botanical", "sleeve"],
                size: .halfSleeve, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -180, startHour: 10, hours: 3.5, type: .consultation, notes: "Initial consult and design review"),
                    (daysFromNow: -150, startHour: 10, hours: 4.0, type: .linework,    notes: "Outlines — inner forearm"),
                    (daysFromNow: -110, startHour: 10, hours: 4.5, type: .linework,    notes: "Outlines — outer forearm"),
                    (daysFromNow: -70,  startHour: 10, hours: 5.0, type: .shading,     notes: "Shading session 1"),
                    (daysFromNow: -30,  startHour: 10, hours: 4.0, type: .shading,     notes: "Shading session 2"),
                ],
                bookingDaysFromNow: 14, scenario: .depositAndPartial(pct: 0.55)
            )
            addPiece(
                context: context, client: c,
                title: "Compass Rose", placement: "Right shoulder",
                desc: "Nautical compass with ornamental frame",
                status: .scheduled, tags: ["nautical", "compass"],
                size: .medium, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -45, startHour: 14, hours: 1.5, type: .consultation, notes: "Design consult"),
                ],
                bookingDaysFromNow: 21, scenario: .depositOnly
            )
        }

        // ── 2. Sam Nakamura ──────────────────────────────────────────────────
        do {
            let c = makeClient("Sam", "Nakamura", "sam.nak@example.com", "555-0202",
                               "he/him", "Regular client. Loves blackwork and geometric.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Blackwork Mandala", placement: "Upper back",
                desc: "Geometric mandala, solid black fill", rating: 5,
                status: .completed, tags: ["blackwork", "mandala", "geometric"],
                size: .large, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -240, startHour: 10, hours: 2.0, type: .consultation,    notes: "Concept review"),
                    (daysFromNow: -210, startHour: 10, hours: 5.0, type: .linework,        notes: "Full outline session"),
                    (daysFromNow: -180, startHour: 10, hours: 5.5, type: .shading,         notes: "Shading complete"),
                    (daysFromNow: -150, startHour: 10, hours: 1.0, type: .touchUp,         notes: "Minor touch up"),
                ],
                bookingDaysFromNow: nil, scenario: .fullyPaid
            )
            addPiece(
                context: context, client: c,
                title: "Serpent Wrap", placement: "Right forearm",
                desc: "Snake wrapping the forearm, dotwork scales",
                status: .inProgress, tags: ["snake", "blackwork", "dotwork"],
                size: .medium, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -60, startHour: 11, hours: 1.5, type: .consultation, notes: "Design approval"),
                    (daysFromNow: -30, startHour: 11, hours: 4.0, type: .linework,    notes: "Outline session"),
                    (daysFromNow: 10,  startHour: 11, hours: 4.5, type: .shading,     notes: "Dotwork shading — upcoming"),
                ],
                bookingDaysFromNow: 10, scenario: .depositAndPartial(pct: 0.4)
            )
        }

        // ── 3. Jordan Okafor ─────────────────────────────────────────────────
        do {
            let c = makeClient("Jordan", "Okafor", "jordan.o@example.com", "555-0303",
                               "she/her", "Wants a full back piece long-term.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Phoenix Back Piece", placement: "Full back",
                desc: "Japanese-style phoenix rising from flames",
                status: .designInProgress, tags: ["japanese", "phoenix", "backpiece"],
                size: .backpiece, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -30, startHour: 10, hours: 2.0, type: .consultation,    notes: "Initial consult"),
                    (daysFromNow: -10, startHour: 10, hours: 3.0, type: .initialDrafting, notes: "Draft sketches review"),
                ],
                bookingDaysFromNow: 30, scenario: .depositOnly
            )
        }

        // ── 4. Taylor Kim ────────────────────────────────────────────────────
        do {
            let c = makeClient("Taylor", "Kim", "taylor.k@example.com", "555-0404",
                               "he/him", "First-timer — be gentle with the process.",
                               "Latex allergy", context: context)
            addPiece(
                context: context, client: c,
                title: "Small Wave", placement: "Inner wrist",
                desc: "Fine-line wave, minimal shading", rating: 4,
                status: .completed, tags: ["fine-line", "minimal", "wave"],
                size: .small, hourlyRate: 0, flatRate: 200, depositAmount: 50,
                sessions: [
                    (daysFromNow: -90, startHour: 14, hours: 1.0, type: .consultation, notes: "Quick design check"),
                    (daysFromNow: -60, startHour: 14, hours: 1.5, type: .flash,        notes: "Single-session piece"),
                ],
                bookingDaysFromNow: nil, scenario: .fullyPaid
            )
            addPiece(
                context: context, client: c,
                title: "Mountain Range Band", placement: "Forearm band",
                desc: "Minimalist mountain range wrap",
                status: .concept, tags: ["minimal", "mountain", "band"],
                size: .small, hourlyRate: rate, depositAmount: 0,
                sessions: [],
                bookingDaysFromNow: nil, scenario: .unpaid
            )
        }

        // ── 5. Morgan Chen ───────────────────────────────────────────────────
        do {
            let c = makeClient("Morgan", "Chen", "morgan.c@example.com", "555-0505",
                               "she/her", "Loves fine-line and micro realism.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Pet Portrait — Mochi", placement: "Inner bicep",
                desc: "Realistic fine-line portrait of her cat, Mochi",
                status: .inProgress, tags: ["portrait", "fine-line", "realism"],
                size: .medium, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -75, startHour: 12, hours: 1.5, type: .consultation,    notes: "Photo selection and sizing"),
                    (daysFromNow: -45, startHour: 12, hours: 4.0, type: .linework,        notes: "Fine-line outline"),
                    (daysFromNow: -5,  startHour: 12, hours: 3.5, type: .shading,         notes: "Shading and whisker detail"),
                ],
                bookingDaysFromNow: 28, scenario: .depositAndPartial(pct: 0.5)
            )
        }

        // ── 6. Casey Dubois ──────────────────────────────────────────────────
        do {
            let c = makeClient("Casey", "Dubois", "casey.d@example.com", "555-0606",
                               "they/them", "Tattoo artist themselves. Very specific references.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Geometric Wolf", placement: "Chest",
                desc: "Low-poly geometric wolf head, bold black", rating: 5,
                status: .completed, tags: ["geometric", "wolf", "blackwork"],
                size: .large, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -200, startHour: 11, hours: 1.0, type: .consultation, notes: "Design sign-off"),
                    (daysFromNow: -170, startHour: 11, hours: 5.0, type: .linework,     notes: "Full outline"),
                    (daysFromNow: -140, startHour: 11, hours: 4.5, type: .shading,      notes: "Fill and shading"),
                ],
                bookingDaysFromNow: nil, scenario: .fullyPaid
            )
            addPiece(
                context: context, client: c,
                title: "Sacred Geometry Sleeve", placement: "Right arm",
                desc: "Full sleeve of interlocking sacred geometry patterns",
                status: .inProgress, tags: ["geometric", "sleeve", "sacred"],
                size: .sleeve, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -120, startHour: 11, hours: 5.0, type: .linework, notes: "Upper arm outlines"),
                    (daysFromNow: -80,  startHour: 11, hours: 5.5, type: .linework, notes: "Forearm outlines"),
                    (daysFromNow: -40,  startHour: 11, hours: 5.0, type: .shading,  notes: "Shading pass 1"),
                ],
                bookingDaysFromNow: 7, scenario: .depositAndPartial(pct: 0.35)
            )
        }

        // ── 7. Riley Patel ───────────────────────────────────────────────────
        do {
            let c = makeClient("Riley", "Patel", "riley.p@example.com", "555-0707",
                               "she/her", "Collector — 20+ pieces already. Loves traditional.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Traditional Panther", placement: "Thigh",
                desc: "Classic American traditional panther head, red mouth", rating: 5,
                status: .healed, tags: ["traditional", "panther", "american"],
                size: .large, hourlyRate: 0, flatRate: 650, depositAmount: 100,
                sessions: [
                    (daysFromNow: -365, startHour: 10, hours: 6.0, type: .flash, notes: "Single-session flash piece"),
                ],
                bookingDaysFromNow: nil, scenario: .fullyPaid
            )
            addPiece(
                context: context, client: c,
                title: "Rose Collection", placement: "Inner forearms",
                desc: "Matching traditional roses on both inner forearms",
                status: .touchUp, tags: ["traditional", "rose", "floral"],
                size: .medium, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -300, startHour: 10, hours: 3.0, type: .linework, notes: "Left arm"),
                    (daysFromNow: -270, startHour: 10, hours: 3.0, type: .linework, notes: "Right arm"),
                    (daysFromNow: -240, startHour: 10, hours: 2.0, type: .colour,   notes: "Colour session"),
                    (daysFromNow: -30,  startHour: 10, hours: 1.0, type: .touchUp,  notes: "Touch-up both arms"),
                ],
                bookingDaysFromNow: nil, scenario: .depositAndPartial(pct: 0.7)
            )
        }

        // ── 8. Jamie Larsson ─────────────────────────────────────────────────
        do {
            let c = makeClient("Jamie", "Larsson", "jamie.l@example.com", "555-0808",
                               "he/him", "Wants matching tattoos with partner — both booked together.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Matching Infinity", placement: "Inner wrist",
                desc: "Infinity symbol with partner's initials — fine-line",
                status: .approved, tags: ["fine-line", "matching", "minimal"],
                size: .tiny, hourlyRate: 0, flatRate: 180, depositAmount: 50,
                sessions: [
                    (daysFromNow: -14, startHour: 15, hours: 1.0, type: .consultation, notes: "Sizing and placement confirmed"),
                ],
                bookingDaysFromNow: 5, scenario: .depositOnly
            )
        }

        // ── 9. Avery Washington ──────────────────────────────────────────────
        do {
            let c = makeClient("Avery", "Washington", "avery.w@example.com", "555-0909",
                               "they/them", "Into neo-traditional. Very detail-oriented.",
                               "Numbing cream allergy", context: context)
            addPiece(
                context: context, client: c,
                title: "Neo-trad Eagle", placement: "Chest piece",
                desc: "Neo-traditional eagle with floral banner and filigree",
                status: .inProgress, tags: ["neo-traditional", "eagle", "chest"],
                size: .large, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -90,  startHour: 13, hours: 1.5, type: .consultation, notes: "Extended consult with revisions"),
                    (daysFromNow: -60,  startHour: 13, hours: 5.0, type: .linework,     notes: "Outline session"),
                    (daysFromNow: -20,  startHour: 13, hours: 4.5, type: .colour,       notes: "Colour pass 1 — feathers"),
                ],
                bookingDaysFromNow: 18, scenario: .depositAndPartial(pct: 0.45)
            )
            addPiece(
                context: context, client: c,
                title: "Dagger & Rose", placement: "Forearm",
                desc: "Classic dagger through a rose, neo-trad colour",
                status: .approved, tags: ["neo-traditional", "dagger", "rose"],
                size: .medium, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -10, startHour: 13, hours: 1.0, type: .consultation, notes: "Design approval"),
                ],
                bookingDaysFromNow: 35, scenario: .depositOnly
            )
        }

        // ── 10. Quinn Martinez ───────────────────────────────────────────────
        do {
            let c = makeClient("Quinn", "Martinez", "quinn.m@example.com", "555-1010",
                               "she/her", "Referred by Alex Rivera. New to tattooing.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Watercolor Hummingbird", placement: "Shoulder blade",
                desc: "Watercolor-style hummingbird with abstract splashes",
                status: .designInProgress, tags: ["watercolor", "bird", "colour"],
                size: .medium, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -7, startHour: 11, hours: 1.5, type: .consultation,    notes: "First consult"),
                ],
                bookingDaysFromNow: nil, scenario: .depositOnly
            )
        }

        // ── 11. Theo Bergström ───────────────────────────────────────────────
        do {
            let c = makeClient("Theo", "Bergström", "theo.b@example.com", "555-1111",
                               "he/him", "Loves Japanese traditional. Patient and easy-going.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Japanese Crane", placement: "Upper arm",
                desc: "Irezumi-style crane with cloud and wave fill", rating: 5,
                status: .completed, tags: ["japanese", "crane", "irezumi"],
                size: .large, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -280, startHour: 10, hours: 2.0, type: .consultation, notes: "Reference review"),
                    (daysFromNow: -250, startHour: 10, hours: 5.5, type: .linework,     notes: "Outline"),
                    (daysFromNow: -220, startHour: 10, hours: 5.0, type: .colour,       notes: "Colour — blues and whites"),
                    (daysFromNow: -180, startHour: 10, hours: 1.5, type: .touchUp,      notes: "Healed touch-up"),
                ],
                bookingDaysFromNow: nil, scenario: .fullyPaid
            )
            addPiece(
                context: context, client: c,
                title: "Oni Mask", placement: "Calf",
                desc: "Traditional Japanese Oni mask with horns and fire",
                status: .inProgress, tags: ["japanese", "oni", "traditional"],
                size: .large, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -45, startHour: 10, hours: 5.0, type: .linework, notes: "Full outline"),
                    (daysFromNow: -8,  startHour: 10, hours: 5.0, type: .colour,   notes: "Colour session 1"),
                ],
                bookingDaysFromNow: 25, scenario: .depositAndPartial(pct: 0.3)
            )
        }

        // ── 12. Nadia Osei ───────────────────────────────────────────────────
        do {
            let c = makeClient("Nadia", "Osei", "nadia.o@example.com", "555-1212",
                               "she/her", "Building a floral half-sleeve over multiple appointments.",
                               "Penicillin (unrelated)", context: context)
            addPiece(
                context: context, client: c,
                title: "Floral Half Sleeve", placement: "Left upper arm",
                desc: "Botanical half-sleeve — peonies, dahlias, ferns",
                status: .inProgress, tags: ["floral", "botanical", "sleeve"],
                size: .halfSleeve, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -130, startHour: 12, hours: 5.0, type: .linework, notes: "Outline — upper section"),
                    (daysFromNow: -90,  startHour: 12, hours: 5.5, type: .linework, notes: "Outline — lower section"),
                    (daysFromNow: -50,  startHour: 12, hours: 5.0, type: .shading,  notes: "Shading pass"),
                    (daysFromNow: -10,  startHour: 12, hours: 4.5, type: .colour,   notes: "Colour — pinks and greens"),
                ],
                bookingDaysFromNow: 20, scenario: .depositAndPartial(pct: 0.5)
            )
        }

        // ── 13. Marcus Delacroix ─────────────────────────────────────────────
        do {
            let c = makeClient("Marcus", "Delacroix", "marcus.d@example.com", "555-1313",
                               "he/him", "Collected since the 90s. Appreciates old-school work.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Koi Fish", placement: "Left thigh",
                desc: "Japanese koi ascending, surrounded by waves and cherry blossoms", rating: 4,
                status: .healed, tags: ["japanese", "koi", "colour"],
                size: .extraLarge, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -400, startHour: 10, hours: 6.0, type: .linework, notes: "Full outline — thigh"),
                    (daysFromNow: -360, startHour: 10, hours: 6.0, type: .colour,   notes: "Colour session 1"),
                    (daysFromNow: -320, startHour: 10, hours: 5.5, type: .colour,   notes: "Colour session 2 — background waves"),
                    (daysFromNow: -240, startHour: 10, hours: 1.5, type: .touchUp,  notes: "Healed touch-up"),
                ],
                bookingDaysFromNow: nil, scenario: .fullyPaid
            )
            addPiece(
                context: context, client: c,
                title: "Skull & Flowers", placement: "Right forearm",
                desc: "Day-of-the-dead skull with marigolds, fine-line style",
                status: .approved, tags: ["skull", "floral", "dia-de-los-muertos"],
                size: .medium, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -21, startHour: 10, hours: 1.0, type: .consultation, notes: "Design confirmed"),
                ],
                bookingDaysFromNow: 12, scenario: .depositOnly
            )
        }

        // ── 14. Priya Sharma ─────────────────────────────────────────────────
        do {
            let c = makeClient("Priya", "Sharma", "priya.s@example.com", "555-1414",
                               "she/her", "Mindful, spiritual. Loves sacred geometry and botanicals.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Lotus Mandala", placement: "Sternum",
                desc: "Intricate lotus mandala with fine-line dotwork surround", rating: 5,
                status: .healed, tags: ["mandala", "lotus", "dotwork", "fine-line"],
                size: .medium, hourlyRate: 0, flatRate: 480, depositAmount: 100,
                sessions: [
                    (daysFromNow: -160, startHour: 11, hours: 1.0, type: .consultation, notes: "Sizing and placement"),
                    (daysFromNow: -130, startHour: 11, hours: 5.0, type: .linework,     notes: "Fine-line and dotwork session"),
                    (daysFromNow: -90,  startHour: 11, hours: 1.0, type: .touchUp,      notes: "Touch-up after healing"),
                ],
                bookingDaysFromNow: nil, scenario: .fullyPaid
            )
        }

        // ── 15. Eli Nakamura ─────────────────────────────────────────────────
        do {
            let c = makeClient("Eli", "Nakamura", "eli.n@example.com", "555-1515",
                               "they/them", "Sam's sibling. Wants something abstract.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Abstract Geometry", placement: "Ribcage",
                desc: "Overlapping geometric shapes in bold black — personal design",
                status: .inProgress, tags: ["geometric", "abstract", "blackwork"],
                size: .large, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -50, startHour: 13, hours: 2.0, type: .consultation,    notes: "Design collaboration"),
                    (daysFromNow: -20, startHour: 13, hours: 4.5, type: .linework,        notes: "Outline session"),
                ],
                bookingDaysFromNow: 16, scenario: .depositOnly
            )
            addPiece(
                context: context, client: c,
                title: "Blackbird Study", placement: "Ankle",
                desc: "Delicate fine-line blackbird perched on branch",
                status: .concept, tags: ["fine-line", "bird", "minimal"],
                size: .small, hourlyRate: rate, depositAmount: 0,
                sessions: [],
                bookingDaysFromNow: nil, scenario: .unpaid
            )
        }

        // ── 16. Sofia Reyes ──────────────────────────────────────────────────
        do {
            let c = makeClient("Sofia", "Reyes", "sofia.r@example.com", "555-1616",
                               "she/her", "Day of the Dead inspired art. Vibrant colour work.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Calavera Portrait", placement: "Upper arm",
                desc: "Vibrant Día de los Muertos calavera with florals and candles",
                status: .scheduled, tags: ["dia-de-los-muertos", "colour", "portrait"],
                size: .large, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -20, startHour: 15, hours: 1.5, type: .consultation, notes: "Design presentation and approval"),
                ],
                bookingDaysFromNow: 8, scenario: .depositOnly
            )
        }

        // ── 17. Cameron Blake ────────────────────────────────────────────────
        do {
            let c = makeClient("Cameron", "Blake", "cam.b@example.com", "555-1717",
                               "he/him", "Into Norse mythology. Wants historical accuracy.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Viking Runes", placement: "Inner forearm",
                desc: "Elder Futhark rune band with knotwork borders", rating: 4,
                status: .completed, tags: ["norse", "runes", "blackwork", "band"],
                size: .medium, hourlyRate: 0, flatRate: 350, depositAmount: 75,
                sessions: [
                    (daysFromNow: -100, startHour: 10, hours: 3.5, type: .linework, notes: "Single-session band"),
                ],
                bookingDaysFromNow: nil, scenario: .fullyPaid
            )
            addPiece(
                context: context, client: c,
                title: "Dragon Sleeve", placement: "Right arm",
                desc: "Norse dragon (Níðhöggr) coiled around the full sleeve",
                status: .inProgress, tags: ["norse", "dragon", "sleeve"],
                size: .sleeve, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -35, startHour: 10, hours: 2.0, type: .consultation,    notes: "Reference and sketches"),
                    (daysFromNow: -7,  startHour: 10, hours: 5.5, type: .linework,        notes: "Upper arm outlines — started"),
                ],
                bookingDaysFromNow: 22, scenario: .depositOnly
            )
        }

        // ── 18. Yuki Tanaka ──────────────────────────────────────────────────
        do {
            let c = makeClient("Yuki", "Tanaka", "yuki.t@example.com", "555-1818",
                               "she/her", "Delicate fine-line work only. Loves botanicals.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Cherry Blossom Branch", placement: "Shoulder blade",
                desc: "Sweeping cherry blossom branch, micro-fine linework", rating: 5,
                status: .healed, tags: ["fine-line", "botanical", "japanese", "cherry"],
                size: .medium, hourlyRate: 0, flatRate: 420, depositAmount: 100,
                sessions: [
                    (daysFromNow: -190, startHour: 13, hours: 1.0, type: .consultation, notes: "Placement and sizing"),
                    (daysFromNow: -160, startHour: 13, hours: 4.0, type: .linework,     notes: "Full piece — single session"),
                    (daysFromNow: -120, startHour: 13, hours: 0.5, type: .touchUp,      notes: "Healing check-in"),
                ],
                bookingDaysFromNow: nil, scenario: .fullyPaid
            )
        }

        // ── 19. Isaac Ford ───────────────────────────────────────────────────
        do {
            let c = makeClient("Isaac", "Ford", "isaac.f@example.com", "555-1919",
                               "he/him", "Nautical theme — building a cohesive collection.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Traditional Ship", placement: "Chest",
                desc: "Three-mast tall ship in full sail, American traditional", rating: 4,
                status: .completed, tags: ["traditional", "nautical", "ship"],
                size: .extraLarge, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -310, startHour: 10, hours: 6.0, type: .linework, notes: "Full outline"),
                    (daysFromNow: -280, startHour: 10, hours: 5.5, type: .colour,   notes: "Colour — blues and reds"),
                    (daysFromNow: -250, startHour: 10, hours: 2.0, type: .colour,   notes: "Detail and finish"),
                ],
                bookingDaysFromNow: nil, scenario: .fullyPaid
            )
            addPiece(
                context: context, client: c,
                title: "Anchor & Wave", placement: "Upper arm",
                desc: "Classic anchor with rope and cresting wave surround",
                status: .inProgress, tags: ["traditional", "nautical", "anchor"],
                size: .large, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -40, startHour: 10, hours: 5.0, type: .linework, notes: "Full outline"),
                    (daysFromNow: -3,  startHour: 10, hours: 4.5, type: .colour,   notes: "Colour session"),
                ],
                bookingDaysFromNow: 30, scenario: .depositAndPartial(pct: 0.4)
            )
        }

        // ── 20. Valentina Cruz ───────────────────────────────────────────────
        do {
            let c = makeClient("Valentina", "Cruz", "val.c@example.com", "555-2020",
                               "she/her", "First tattoo. Very excited, has clear vision.",
                               "", context: context)
            addPiece(
                context: context, client: c,
                title: "Hummingbird & Hibiscus", placement: "Shoulder",
                desc: "Realistic hummingbird hovering over hibiscus flowers",
                status: .designInProgress, tags: ["realism", "bird", "floral", "colour"],
                size: .medium, hourlyRate: rate, depositAmount: dep,
                sessions: [
                    (daysFromNow: -14, startHour: 14, hours: 1.5, type: .consultation,    notes: "First consult — great energy"),
                    (daysFromNow: -3,  startHour: 14, hours: 2.0, type: .initialDrafting, notes: "Sketch review session"),
                ],
                bookingDaysFromNow: 40, scenario: .depositOnly
            )
        }
    }

    // MARK: - Build Helpers

    @discardableResult
    private static func makeClient(
        _ first: String, _ last: String, _ email: String, _ phone: String,
        _ pronouns: String, _ notes: String, _ allergy: String,
        context: ModelContext
    ) -> Client {
        let c = Client(
            firstName: first, lastName: last,
            email: email, phone: phone,
            notes: notes, pronouns: pronouns,
            allergyNotes: allergy
        )
        context.insert(c)
        return c
    }

    private static func addPiece(
        context: ModelContext,
        client: Client,
        title: String,
        placement: String,
        desc: String,
        rating: Int? = nil,
        status: PieceStatus,
        tags: [String] = [],
        size: TattooSize? = nil,
        hourlyRate: Decimal = 175,
        flatRate: Decimal? = nil,
        depositAmount: Decimal = 150,
        sessions: [(daysFromNow: Int, startHour: Int, hours: Double, type: SessionType, notes: String)],
        bookingDaysFromNow: Int?,
        scenario: PaymentScenario
    ) {
        let cal = Calendar.current
        let now = Date()

        let piece = Piece(
            title: title, bodyPlacement: placement, descriptionText: desc,
            status: status, pieceType: .custom, tags: tags,
            hourlyRate: hourlyRate, flatRate: flatRate, depositAmount: depositAmount
        )
        piece.rating = rating
        piece.size   = size
        piece.client = client
        context.insert(piece)

        // Placeholder image
        let clientID = "\(client.firstName.lowercased())_\(client.lastName.lowercased())"
        let pieceID  = title.lowercased().replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
        let imgPath = savePlaceholderImage(
            color: colorForTitle(title),
            clientID: clientID, pieceID: pieceID, stage: "primary"
        )
        piece.primaryImagePath = imgPath

        // Sessions
        var createdSessions: [Session] = []
        for spec in sessions {
            guard let base = cal.date(byAdding: .day, value: spec.daysFromNow, to: now),
                  let start = cal.date(bySettingHour: spec.startHour, minute: 0, second: 0, of: base)
            else { continue }
            let end = start.addingTimeInterval(spec.hours * 3600)
            let session = Session(
                date: base,
                startTime: start,
                endTime: end,
                breakMinutes: spec.hours > 3 ? 15 : 0,
                sessionType: spec.type,
                hourlyRateAtTime: hourlyRate > 0 ? hourlyRate : 175,
                notes: spec.notes
            )
            session.piece = piece
            context.insert(session)
            createdSessions.append(session)
        }

        // Upcoming booking
        if let d = bookingDaysFromNow,
           let bBase  = cal.date(byAdding: .day, value: d, to: now),
           let bStart = cal.date(bySettingHour: 10, minute: 0, second: 0, of: bBase),
           let bEnd   = cal.date(bySettingHour: 14, minute: 0, second: 0, of: bBase) {
            let booking = Booking(
                date: bBase, startTime: bStart, endTime: bEnd,
                status: d < 7 ? .confirmed : .confirmed,
                bookingType: .session,
                notes: "\(title) — upcoming appointment",
                depositPaid: depositAmount > 0,
                client: client, piece: piece
            )
            context.insert(booking)
        }

        // Payments
        applyPayments(context: context, piece: piece, client: client,
                      scenario: scenario, sessions: createdSessions)
    }

    // MARK: - Payment Application

    private static func applyPayments(
        context: ModelContext,
        piece: Piece,
        client: Client,
        scenario: PaymentScenario,
        sessions: [Session]
    ) {
        let cal = Calendar.current
        let now = Date()
        let methods: [PaymentMethod] = [.cash, .card, .eTransfer, .card]
        let methodFor: (Int) -> PaymentMethod = { methods[$0 % methods.count] }

        // Calculate the piece's estimated total cost for payment math
        let totalHours = sessions.reduce(0.0) { $0 + ($1.durationHours) }
        let estimatedTotal: Decimal
        if let flat = piece.flatRate {
            estimatedTotal = flat
        } else {
            estimatedTotal = Decimal(totalHours) * piece.hourlyRate
        }

        // Earliest session date (or 30 days ago as fallback)
        let earliestSession = sessions.compactMap { $0.date }.min()
        let depositDate = earliestSession.map {
            cal.date(byAdding: .day, value: -14, to: $0) ?? $0
        } ?? cal.date(byAdding: .day, value: -30, to: now)!

        switch scenario {

        case .fullyPaid:
            // Deposit
            if piece.depositAmount > 0 {
                context.insert(Payment(
                    amount: piece.depositAmount, paymentDate: depositDate,
                    paymentMethod: methodFor(0), paymentType: .deposit,
                    notes: "Deposit — \(piece.title)", piece: piece, client: client
                ))
            }
            // Session payment covering the remainder
            let remainder = estimatedTotal - piece.depositAmount
            if remainder > 0, let lastSession = sessions.last {
                let payDate = cal.date(byAdding: .day, value: 0, to: lastSession.date)!
                context.insert(Payment(
                    amount: remainder, paymentDate: payDate,
                    paymentMethod: methodFor(1), paymentType: .sessionPayment,
                    notes: "Balance paid — \(piece.title)", piece: piece, client: client
                ))
            }
            // Tip (~40% chance)
            if Int.random(in: 0...4) > 2, let lastSession = sessions.last {
                context.insert(Payment(
                    amount: Decimal(Int.random(in: 20...80)),
                    paymentDate: lastSession.date,
                    paymentMethod: .cash, paymentType: .tip,
                    notes: "Tip — thank you!", piece: piece, client: client
                ))
            }

        case .depositAndPartial(let pct):
            // Deposit
            if piece.depositAmount > 0 {
                context.insert(Payment(
                    amount: piece.depositAmount, paymentDate: depositDate,
                    paymentMethod: methodFor(0), paymentType: .deposit,
                    notes: "Deposit — \(piece.title)", piece: piece, client: client
                ))
            }
            // Partial session payment
            let partialAmount = (estimatedTotal - piece.depositAmount) * Decimal(pct)
            if partialAmount > 0, let midSession = sessions.dropFirst().first ?? sessions.first {
                let payDate = cal.date(byAdding: .day, value: 0, to: midSession.date)!
                context.insert(Payment(
                    amount: partialAmount, paymentDate: payDate,
                    paymentMethod: methodFor(2), paymentType: .sessionPayment,
                    notes: "Partial session payment — \(piece.title)", piece: piece, client: client
                ))
            }

        case .depositOnly:
            if piece.depositAmount > 0 {
                context.insert(Payment(
                    amount: piece.depositAmount, paymentDate: depositDate,
                    paymentMethod: methodFor(1), paymentType: .deposit,
                    notes: "Deposit — \(piece.title)", piece: piece, client: client
                ))
            }

        case .unpaid:
            break   // No payments — outstanding balance remains open

        case .noShow(let fee):
            context.insert(Payment(
                amount: fee, paymentDate: now,
                paymentMethod: .other, paymentType: .noShowFee,
                notes: "No-show fee charged — \(piece.title)", piece: piece, client: client
            ))
        }
    }

    // MARK: - Flash Portfolio Client Seed

    private static func seedFlashPortfolioClient(context: ModelContext) {
        let descriptor = FetchDescriptor<Client>(predicate: #Predicate { $0.isFlashPortfolioClient })
        guard let existing = try? context.fetch(descriptor), existing.isEmpty else { return }

        let portfolioClient = Client(firstName: "Flash", lastName: "Portfolio")
        portfolioClient.isFlashPortfolioClient = true
        context.insert(portfolioClient)

        let designs: [(title: String, desc: String, price: Decimal, tags: [String])] = [
            ("Traditional Rose",    "Classic American traditional rose, bold lines",              200, ["traditional", "floral"]),
            ("Geometric Moth",      "Blackwork geometric moth with dot-work shading",             180, ["geometric", "blackwork"]),
            ("Dagger Flash",        "Traditional dagger through a rose with banner",              150, ["traditional", "dagger"]),
            ("Serpent Coil",        "Simple serpent coil, fine-line style",                       220, ["snake", "fine-line"]),
            ("Anchor & Stars",      "Nautical anchor with small star accents",                    160, ["nautical", "traditional"]),
            ("Swallow Pair",        "Matching swallows in flight, classic sailor style",          175, ["traditional", "birds"]),
            ("Evil Eye",            "Nazar amulet in fine-line with dotwork surround",            140, ["fine-line", "evil-eye"]),
            ("Scorpion",            "American traditional scorpion, bold and clean",              190, ["traditional", "scorpion"]),
            ("Lightning Bolt",      "Neo-traditional lightning bolt with cloud elements",         130, ["neo-traditional", "lightning"]),
            ("Pansy Cluster",       "Three pansies, delicate fine-line botanical",               165, ["fine-line", "floral", "botanical"]),
        ]

        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange,
                                  .systemPurple, .systemTeal, .systemPink, .systemYellow,
                                  .systemIndigo, .systemBrown]

        for (i, design) in designs.enumerated() {
            let piece = Piece(
                title: design.title, bodyPlacement: "",
                descriptionText: design.desc, status: .approved,
                pieceType: .flash, tags: design.tags,
                hourlyRate: 0, flatRate: design.price, depositAmount: 0
            )
            piece.client = portfolioClient
            let pieceID = design.title.lowercased().replacingOccurrences(of: " ", with: "_")
            piece.primaryImagePath = savePlaceholderImage(
                color: colors[i % colors.count],
                clientID: "flash_portfolio", pieceID: pieceID, stage: "flash"
            )
            context.insert(piece)
        }
    }

    // MARK: - Helpers

    /// Deterministic placeholder color based on the title string.
    private static func colorForTitle(_ title: String) -> UIColor {
        let palette: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange,
                                   .systemPurple, .systemTeal, .systemPink, .systemBrown,
                                   .systemIndigo, .systemYellow]
        let hash = abs(title.hashValue)
        return palette[hash % palette.count]
    }

    private static func savePlaceholderImage(
        color: UIColor, clientID: String, pieceID: String, stage: String
    ) -> String {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            color.withAlphaComponent(0.35).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.white.withAlphaComponent(0.15).setStroke()
            let path = UIBezierPath()
            for x in stride(from: 0, through: 400, by: 40) {
                path.move(to: CGPoint(x: x, y: 0));    path.addLine(to: CGPoint(x: x, y: 400))
                path.move(to: CGPoint(x: 0, y: x));    path.addLine(to: CGPoint(x: 400, y: x))
            }
            path.lineWidth = 1; path.stroke()
            let label = "\(stage)\n\(pieceID)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.white
            ]
            let textSize = label.boundingRect(with: size, options: .usesLineFragmentOrigin,
                                              attributes: attrs, context: nil).size
            label.draw(at: CGPoint(x: (size.width - textSize.width) / 2,
                                   y: (size.height - textSize.height) / 2),
                       withAttributes: attrs)
        }
        let fileName = UUID().uuidString + ".png"
        let basePath = "CounterImages/\(clientID)/\(pieceID)/\(stage)"
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dirURL = docs.appendingPathComponent(basePath)
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let fileURL = dirURL.appendingPathComponent(fileName)
        try? image.pngData()?.write(to: fileURL)
        return "\(basePath)/\(fileName)"
    }
}
