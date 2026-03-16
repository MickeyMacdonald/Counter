import Foundation
import SwiftData
import UIKit

/// Populates the persistent store with realistic dummy data for testing.
/// Only runs once, gated by a UserDefaults flag.
@MainActor
enum SeedDataService {
    private static let seedKey = "com.counter.hasSeededData.v2"

    static var hasSeeded: Bool {
        UserDefaults.standard.bool(forKey: seedKey)
    }

    private static let paymentSeedKey    = "com.counter.hasSeededPayments"
    private static let flashPortfolioKey = "com.counter.hasSeededFlashPortfolio"

    static func seedIfNeeded(context: ModelContext) {
        if !hasSeeded {
            seed(context: context)
            UserDefaults.standard.set(true, forKey: seedKey)
            UserDefaults.standard.set(true, forKey: paymentSeedKey)
            UserDefaults.standard.set(true, forKey: flashPortfolioKey)
        } else if !UserDefaults.standard.bool(forKey: paymentSeedKey) {
            seedPaymentsForExistingPieces(context: context)
            UserDefaults.standard.set(true, forKey: paymentSeedKey)
        }
        if !UserDefaults.standard.bool(forKey: flashPortfolioKey) {
            seedFlashPortfolioClient(context: context)
            UserDefaults.standard.set(true, forKey: flashPortfolioKey)
        }
    }

    /// Back-fills payment records for existing pieces that were seeded before
    /// the Payment model was added.
    private static func seedPaymentsForExistingPieces(context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        let paymentMethods: [PaymentMethod] = [.cash, .card, .eTransfer, .card]

        let descriptor = FetchDescriptor<Piece>()
        guard let pieces = try? context.fetch(descriptor) else { return }

        for (i, piece) in pieces.enumerated() {
            // Deposit
            if piece.depositAmount > 0 {
                let depositDate = calendar.date(byAdding: .day, value: -(30 + i * 5), to: now) ?? now
                let deposit = Payment(
                    amount: piece.depositAmount,
                    paymentDate: depositDate,
                    paymentMethod: paymentMethods[i % paymentMethods.count],
                    paymentType: .deposit,
                    notes: "Deposit for \(piece.title)",
                    piece: piece,
                    client: piece.client
                )
                context.insert(deposit)
            }

            // Session payment for completed or in-progress pieces
            let activeStatuses: [PieceStatus] = [.completed, .inProgress, .touchUp, .healed]
            if activeStatuses.contains(piece.status) {
                let paymentDate = calendar.date(byAdding: .day, value: -(7 + i * 2), to: now) ?? now
                let sessionPayment = Payment(
                    amount: Decimal(Int.random(in: 300...700)),
                    paymentDate: paymentDate,
                    paymentMethod: paymentMethods[(i + 1) % paymentMethods.count],
                    paymentType: .sessionPayment,
                    notes: "Session payment — \(piece.title)",
                    piece: piece,
                    client: piece.client
                )
                context.insert(sessionPayment)
            }

            // Tips for completed pieces
            if piece.status == .completed && Bool.random() {
                let tipDate = calendar.date(byAdding: .day, value: -(7 + i * 2), to: now) ?? now
                let tip = Payment(
                    amount: Decimal(Int.random(in: 20...80)),
                    paymentDate: tipDate,
                    paymentMethod: .cash,
                    paymentType: .tip,
                    piece: piece,
                    client: piece.client
                )
                context.insert(tip)
            }
        }
    }

    // MARK: - Seed

    private static func seed(context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()

        // -- User Profile --
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

        // -- Availability (Mon–Fri) --
        for day in 1...5 {
            context.insert(AvailabilitySlot(dayOfWeek: day))
        }

        // -- Client data --
        let clientData: [(first: String, last: String, email: String, phone: String, pronouns: String, notes: String, allergy: String)] = [
            ("Alex", "Rivera", "alex@example.com", "555-0101", "they/them", "Prefers traditional style.", "Red ink sensitivity"),
            ("Sam", "Nakamura", "sam.nak@example.com", "555-0202", "he/him", "Regular. Loves blackwork.", ""),
            ("Jordan", "Okafor", "jordan.o@example.com", "555-0303", "she/her", "Wants a full back piece long-term.", ""),
            ("Taylor", "Kim", "taylor.k@example.com", "555-0404", "he/him", "First-timer, nervous. Be gentle.", "Latex allergy"),
            ("Morgan", "Chen", "morgan.c@example.com", "555-0505", "she/her", "Loves fine-line work.", ""),
            ("Casey", "Dubois", "casey.d@example.com", "555-0606", "they/them", "Artist themselves, very specific refs.", ""),
            ("Riley", "Patel", "riley.p@example.com", "555-0707", "she/her", "Collector. Has 20+ pieces already.", ""),
            ("Jamie", "Larsson", "jamie.l@example.com", "555-0808", "he/him", "Wants matching tattoos with partner.", ""),
            ("Avery", "Washington", "avery.w@example.com", "555-0909", "they/them", "Into neo-traditional.", "Numbing cream allergy"),
            ("Quinn", "Martinez", "quinn.m@example.com", "555-1010", "she/her", "Referred by Alex Rivera.", "")
        ]

        // Piece templates per client (1–2 each)
        let pieceTemplates: [[(title: String, placement: String, desc: String, status: PieceStatus, type: PieceType)]] = [
            [
                ("Botanical Sleeve", "Left forearm", "Mixed floral sleeve with fern and peony motifs", .inProgress, .custom),
                ("Compass Rose", "Right shoulder", "Nautical compass with ornamental frame", .scheduled, .custom)
            ],
            [
                ("Blackwork Mandala", "Upper back", "Geometric mandala, solid black fill", .completed, .custom),
                ("Serpent Wrap", "Right forearm", "Snake wrapping around forearm, dotwork scales", .inProgress, .custom)
            ],
            [
                ("Phoenix Back Piece", "Full back", "Japanese-style phoenix rising from flames", .designInProgress, .custom)
            ],
            [
                ("First Tattoo — Wave", "Inner wrist", "Small fine-line wave design", .approved, .custom),
                ("Mountain Range", "Forearm band", "Minimalist mountain range wrap", .concept, .custom)
            ],
            [
                ("Fine-line Portrait", "Inner bicep", "Realistic portrait of pet cat", .inProgress, .custom)
            ],
            [
                ("Geometric Wolf", "Chest", "Low-poly geometric wolf head", .completed, .custom),
                ("Sacred Geometry Sleeve", "Right arm", "Full sleeve of sacred geometry patterns", .inProgress, .custom)
            ],
            [
                ("Traditional Panther", "Thigh", "Classic American traditional panther head", .completed, .custom),
                ("Rose Collection", "Both arms", "Matching traditional roses on inner forearms", .touchUp, .custom)
            ],
            [
                ("Matching Infinity", "Inner wrist", "Infinity symbol with partner's initials", .scheduled, .custom)
            ],
            [
                ("Neo-trad Eagle", "Chest", "Neo-traditional eagle with banner", .inProgress, .custom),
                ("Dagger & Rose", "Forearm", "Classic dagger through a rose", .approved, .custom)
            ],
            [
                ("Watercolor Hummingbird", "Shoulder blade", "Watercolor-style hummingbird with splashes", .designInProgress, .custom)
            ]
        ]

        // Session types to cycle through
        let sessionTypes: [SessionType] = [.consultation, .linework, .shading, .colour]

        // Booking types to cycle
        let bookingTypes: [BookingType] = [.session, .consultation, .touchUp, .session]
        let bookingStatuses: [BookingStatus] = [.confirmed, .requested, .confirmed, .confirmed]

        // Direct image categories for variety (inspiration/reference on the Piece)
        let directImageSets: [[(category: PieceImageCategory, count: Int)]] = [
            [(.inspiration, 2), (.reference, 1)],
            [(.inspiration, 1), (.reference, 2)],
            [(.inspiration, 3)],
            [(.inspiration, 1), (.reference, 1)],
            [(.inspiration, 2), (.reference, 2)]
        ]

        // Work stages that go on Sessions via ImageGroups
        let workStageGroups: [[ImageStage]] = [
            [.sketch, .lineart, .stencil],
            [.sketch, .lineart, .shading],
            [.sketch],
            [.lineart, .stencil, .freshlyTattooed, .healed],
            [.sketch, .lineart, .shading, .stencil]
        ]

        // Placeholder colors for generated images
        let placeholderColors: [UIColor] = [
            .systemRed, .systemBlue, .systemGreen, .systemOrange,
            .systemPurple, .systemTeal, .systemPink, .systemYellow
        ]

        var allClients: [Client] = []

        for (i, data) in clientData.enumerated() {
            let client = Client(
                firstName: data.first,
                lastName: data.last,
                email: data.email,
                phone: data.phone,
                notes: data.notes,
                pronouns: data.pronouns,
                allergyNotes: data.allergy
            )
            context.insert(client)
            allClients.append(client)

            let templates = pieceTemplates[i]

            for (pi, tmpl) in templates.enumerated() {
                let piece = Piece(
                    title: tmpl.title,
                    bodyPlacement: tmpl.placement,
                    descriptionText: tmpl.desc,
                    status: tmpl.status,
                    pieceType: tmpl.type,
                    hourlyRate: profile.defaultHourlyRate,
                    depositAmount: 150
                )
                if tmpl.status == .completed {
                    piece.rating = Int.random(in: 3...5)
                }
                piece.client = client
                context.insert(piece)

                // -- Sessions (2–3 per piece, created FIRST so we can attach image groups) --
                var createdSessions: [TattooSession] = []
                let sessionCount = Int.random(in: 2...3)
                for si in 0..<sessionCount {
                    let dayOffset = -(si + 1) * 14 + (i * 3) // Spread across past weeks
                    guard let sessionDate = calendar.date(byAdding: .day, value: dayOffset, to: now),
                          let start = calendar.date(bySettingHour: 10 + si, minute: 0, second: 0, of: sessionDate),
                          let end = calendar.date(bySettingHour: 13 + si, minute: 30, second: 0, of: sessionDate)
                    else { continue }

                    let session = TattooSession(
                        date: sessionDate,
                        startTime: start,
                        endTime: end,
                        breakMinutes: si == 0 ? 0 : 15,
                        sessionType: sessionTypes[(i + si) % sessionTypes.count],
                        hourlyRateAtTime: profile.defaultHourlyRate,
                        notes: "Session \(si + 1) for \(tmpl.title)"
                    )
                    session.piece = piece
                    context.insert(session)
                    createdSessions.append(session)
                }

                let clientID = "\(data.first.lowercased())_\(data.last.lowercased())"
                let pieceID = tmpl.title.lowercased().replacingOccurrences(of: " ", with: "_")
                var globalImageCount = 0

                // -- Direct images: Inspiration & Reference (owned by Piece) --
                let directSet = directImageSets[(i + pi) % directImageSets.count]
                for entry in directSet {
                    for imgIdx in 0..<entry.count {
                        let color = placeholderColors[(globalImageCount + i) % placeholderColors.count]
                        let relativePath = savePlaceholderImage(
                            color: color,
                            clientID: clientID,
                            pieceID: pieceID,
                            stage: entry.category.rawValue.lowercased()
                        )

                        let pieceImage = PieceImage(
                            filePath: relativePath,
                            fileName: "\(entry.category.rawValue.lowercased())_\(imgIdx).png",
                            sortOrder: imgIdx,
                            isPrimary: globalImageCount == 0,
                            category: entry.category
                        )
                        pieceImage.piece = piece
                        context.insert(pieceImage)

                        if globalImageCount == 0 {
                            piece.primaryImagePath = relativePath
                        }
                        globalImageCount += 1
                    }
                }

                // -- Work photo ImageGroups (owned by Sessions) --
                let workStages = workStageGroups[(i + pi) % workStageGroups.count]
                for (si, stage) in workStages.enumerated() {
                    // Distribute work stages across available sessions
                    let targetSession = createdSessions.isEmpty ? nil : createdSessions[si % createdSessions.count]

                    let group = ImageGroup(
                        stage: stage,
                        notes: "\(stage.rawValue) photos for \(tmpl.title)",
                        timeSpentMinutes: stage == .lineart || stage == .shading ? Int.random(in: 30...180) : 0
                    )
                    group.session = targetSession
                    group.piece = piece  // Keep temporarily for backward compat
                    context.insert(group)

                    // 1–2 images per work stage
                    let imagesForStage = Int.random(in: 1...2)
                    for imgIdx in 0..<imagesForStage {
                        let color = placeholderColors[(globalImageCount + i) % placeholderColors.count]
                        let relativePath = savePlaceholderImage(
                            color: color,
                            clientID: clientID,
                            pieceID: pieceID,
                            stage: stage.rawValue.lowercased()
                        )

                        let pieceImage = PieceImage(
                            filePath: relativePath,
                            fileName: "\(stage.rawValue.lowercased())_\(imgIdx).png",
                            sortOrder: imgIdx,
                            isPrimary: false
                        )
                        pieceImage.imageGroup = group
                        context.insert(pieceImage)
                        globalImageCount += 1
                    }
                }

                // -- Booking (1 upcoming per piece) --
                let dayOffset = (i * 2) + (pi * 3) + 1 // Spread bookings across upcoming days
                guard let bookingDate = calendar.date(byAdding: .day, value: dayOffset, to: now),
                      let bStart = calendar.date(bySettingHour: 10 + pi, minute: 0, second: 0, of: bookingDate),
                      let bEnd = calendar.date(bySettingHour: 13 + pi, minute: 0, second: 0, of: bookingDate)
                else { continue }

                let booking = Booking(
                    date: bookingDate,
                    startTime: bStart,
                    endTime: bEnd,
                    status: bookingStatuses[(i + pi) % bookingStatuses.count],
                    bookingType: bookingTypes[(i + pi) % bookingTypes.count],
                    notes: "Upcoming: \(tmpl.title)",
                    depositPaid: Bool.random(),
                    client: client,
                    piece: piece
                )
                context.insert(booking)

                // -- Payments (vary by piece status) --
                let paymentMethods: [PaymentMethod] = [.cash, .card, .eTransfer, .card]

                // Deposit payment for most pieces
                if piece.depositAmount > 0 {
                    let depositDate = calendar.date(byAdding: .day, value: -(30 + i * 5), to: now) ?? now
                    let deposit = Payment(
                        amount: piece.depositAmount,
                        paymentDate: depositDate,
                        paymentMethod: paymentMethods[(i + pi) % paymentMethods.count],
                        paymentType: .deposit,
                        notes: "Deposit for \(tmpl.title)",
                        piece: piece,
                        client: client
                    )
                    context.insert(deposit)
                }

                // Session payments for completed or in-progress pieces
                if tmpl.status == .completed || tmpl.status == .inProgress {
                    let paymentDate = calendar.date(byAdding: .day, value: -(7 + i * 2), to: now) ?? now
                    let sessionPayment = Payment(
                        amount: Decimal(Int.random(in: 300...700)),
                        paymentDate: paymentDate,
                        paymentMethod: paymentMethods[(i + pi + 1) % paymentMethods.count],
                        paymentType: .sessionPayment,
                        notes: "Session payment — \(tmpl.title)",
                        piece: piece,
                        client: client
                    )
                    context.insert(sessionPayment)
                }

                // Tips for completed pieces
                if tmpl.status == .completed && Bool.random() {
                    let tipDate = calendar.date(byAdding: .day, value: -(7 + i * 2), to: now) ?? now
                    let tip = Payment(
                        amount: Decimal(Int.random(in: 20...80)),
                        paymentDate: tipDate,
                        paymentMethod: .cash,
                        paymentType: .tip,
                        piece: piece,
                        client: client
                    )
                    context.insert(tip)
                }
            }
        }
    }

    // MARK: - Flash Portfolio Client Seed

    private static func seedFlashPortfolioClient(context: ModelContext) {
        // Guard: don't create a duplicate
        let descriptor = FetchDescriptor<Client>(predicate: #Predicate { $0.isFlashPortfolioClient })
        guard let existing = try? context.fetch(descriptor), existing.isEmpty else { return }

        let portfolioClient = Client(firstName: "Flash", lastName: "Portfolio")
        portfolioClient.isFlashPortfolioClient = true
        context.insert(portfolioClient)

        let designs: [(title: String, desc: String, price: Decimal, tags: [String])] = [
            ("Traditional Rose",    "Classic American traditional rose, bold lines and solid fill", 200, ["traditional", "floral"]),
            ("Geometric Moth",      "Blackwork geometric moth with dot-work shading",               180, ["geometric", "blackwork"]),
            ("Dagger Flash",        "Traditional dagger through a rose with banner",                150, ["traditional", "dagger"]),
            ("Serpent Wrap",        "Simple serpent coil, fine-line style",                        220, ["snake", "fine-line"]),
            ("Anchor & Stars",      "Nautical anchor with small star accents",                     160, ["nautical", "traditional"]),
            ("Swallow Pair",        "Matching swallows in flight, classic sailor style",           175, ["traditional", "birds"]),
        ]

        let placeholderColors: [UIColor] = [.systemRed, .systemBlue, .systemGreen,
                                             .systemOrange, .systemPurple, .systemTeal]

        for (i, design) in designs.enumerated() {
            let piece = Piece(
                title: design.title,
                bodyPlacement: "",
                descriptionText: design.desc,
                status: .approved,
                pieceType: .flash,
                tags: design.tags,
                hourlyRate: 0,
                flatRate: design.price,
                depositAmount: 0
            )
            piece.client = portfolioClient

            // Placeholder image
            let pieceID = design.title.lowercased().replacingOccurrences(of: " ", with: "_")
            let relativePath = savePlaceholderImage(
                color: placeholderColors[i % placeholderColors.count],
                clientID: "flash_portfolio",
                pieceID: pieceID,
                stage: "flash"
            )
            piece.primaryImagePath = relativePath
            context.insert(piece)
        }
    }

    // MARK: - Placeholder Image Generator

    private static func savePlaceholderImage(
        color: UIColor,
        clientID: String,
        pieceID: String,
        stage: String
    ) -> String {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            color.withAlphaComponent(0.3).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Draw a subtle cross-hatch to distinguish from blank
            UIColor.white.withAlphaComponent(0.2).setStroke()
            let path = UIBezierPath()
            for x in stride(from: 0, through: 400, by: 40) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: 400))
                path.move(to: CGPoint(x: 0, y: x))
                path.addLine(to: CGPoint(x: 400, y: x))
            }
            path.lineWidth = 1
            path.stroke()

            // Label
            let label = "\(stage)\n\(pieceID)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.white
            ]
            let textSize = label.boundingRect(
                with: size,
                options: .usesLineFragmentOrigin,
                attributes: attrs,
                context: nil
            ).size
            let textOrigin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            label.draw(at: textOrigin, withAttributes: attrs)
        }

        // Save via ImageStorageService synchronously (blocking is fine for seed)
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
