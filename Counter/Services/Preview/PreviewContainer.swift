import Foundation
import SwiftData

/// Shared in-memory container for SwiftUI previews with sample data.
@MainActor
final class PreviewContainer {
    static let shared = PreviewContainer()

    let container: ModelContainer

    init() {
        let schema = Schema([
            Client.self,
            Piece.self,
            SessionProgress.self,
            PieceImage.self,
            Session.self,
            Agreement.self,
            CommunicationLog.self,
            UserProfile.self,
            Booking.self,
            AvailabilitySlot.self,
            PieceImage.self,
            Payment.self,
            SavedEmailTemplate.self,
            AvailabilityOverride.self,
            SessionType.self,
            FlashPriceTier.self,
            SessionRateConfig.self,
            GalleryGroup.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            insertSampleData()
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }

    private func insertSampleData() {
        let context = container.mainContext

        // Sample clients
        let client1 = Client(
            firstName: "Alex",
            lastName: "Rivera",
            email: "alex@example.com",
            phone: "555-0101",
            notes: "Prefers traditional style. Allergic to red ink.",
            pronouns: "they/them",
            allergyNotes: "Red ink sensitivity"
        )

        let client2 = Client(
            firstName: "Sam",
            lastName: "Nakamura",
            email: "sam.nak@example.com",
            phone: "555-0202",
            notes: "Regular. Loves blackwork.",
            pronouns: "he/him"
        )

        let client3 = Client(
            firstName: "Jordan",
            lastName: "Okafor",
            email: "jordan.o@example.com",
            phone: "555-0303",
            pronouns: "she/her"
        )

        context.insert(client1)
        context.insert(client2)
        context.insert(client3)

        // Sample piece for client1
        let piece1 = Piece(
            title: "Sleeve — Botanical",
            bodyPlacement: "Left forearm",
            descriptionText: "Mixed floral sleeve with fern and peony motifs",
            status: .inProgress,
            hourlyRate: 175,
            depositAmount: 200
        )
        piece1.client = client1

        let piece2 = Piece(
            title: "Dagger Traditional",
            bodyPlacement: "Right calf",
            descriptionText: "Traditional American dagger with roses",
            status: .completed,
            hourlyRate: 150,
            depositAmount: 100
        )
        piece2.client = client2
        piece2.rating = 5

        context.insert(piece1)
        context.insert(piece2)

        // Sample direct images (inspiration/reference on piece)
        let inspoImage = PieceImage(
            filePath: "preview/inspo_1.png",
            fileName: "inspo_1.png",
            notes: "Client's Pinterest board reference",
            sortOrder: 0,
            isPrimary: false,
            category: .inspiration
        )
        inspoImage.piece = piece1
        context.insert(inspoImage)

        // Sample session with work photo image groups
        let calendar = Calendar.current
        let sessionDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        let startTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: sessionDate)!
        let endTime = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: sessionDate)!

        let session1 = Session(
            date: sessionDate,
            startTime: startTime,
            endTime: endTime,
            breakMinutes: 15,
            hourlyRateAtTime: 175,
            notes: "Completed outline, started shading on inner forearm"
        )
        session1.piece = piece1
        context.insert(session1)

        let lineartGroup = SessionProgress(stage: .lineart, notes: "First pass lineart", timeSpentMinutes: 120)
        lineartGroup.session = session1
        lineartGroup.piece = piece1  // Backward compat
        context.insert(lineartGroup)

        // Sample user profile
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

        // Sample bookings
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let bookingStart1 = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: tomorrow)!
        let bookingEnd1 = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: tomorrow)!

        let booking1 = Booking(
            date: tomorrow,
            startTime: bookingStart1,
            endTime: bookingEnd1,
            status: .confirmed,
            bookingType: .session,
            notes: "Sleeve continuation — shading session",
            depositPaid: true,
            client: client1,
            piece: piece1
        )
        context.insert(booking1)

        let nextWeek = calendar.date(byAdding: .day, value: 5, to: Date())!
        let bookingStart2 = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: nextWeek)!
        let bookingEnd2 = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: nextWeek)!

        let booking2 = Booking(
            date: nextWeek,
            startTime: bookingStart2,
            endTime: bookingEnd2,
            status: .requested,
            bookingType: .consultation,
            notes: "New piece discussion — back panel",
            client: client3
        )
        context.insert(booking2)

        // Sample availability slots (Mon-Fri, 10am-6pm)
        for day in 1...5 {
            let slot = AvailabilitySlot(dayOfWeek: day)
            context.insert(slot)
        }

        // Sample payments
        let payment1 = Payment(
            amount: 200,
            paymentDate: calendar.date(byAdding: .day, value: -14, to: Date())!,
            paymentMethod: .eTransfer,
            paymentType: .deposit,
            notes: "Deposit for botanical sleeve",
            piece: piece1,
            client: client1
        )
        context.insert(payment1)

        let payment2 = Payment(
            amount: 525,
            paymentDate: sessionDate,
            paymentMethod: .card,
            paymentType: .sessionPayment,
            notes: "First session — outline",
            piece: piece1,
            client: client1
        )
        context.insert(payment2)

        let payment3 = Payment(
            amount: 100,
            paymentDate: calendar.date(byAdding: .day, value: -30, to: Date())!,
            paymentMethod: .cash,
            paymentType: .deposit,
            piece: piece2,
            client: client2
        )
        context.insert(payment3)

        let payment4 = Payment(
            amount: 450,
            paymentDate: calendar.date(byAdding: .day, value: -21, to: Date())!,
            paymentMethod: .card,
            paymentType: .sessionPayment,
            notes: "Completed piece — full payment",
            piece: piece2,
            client: client2
        )
        context.insert(payment4)

        let payment5 = Payment(
            amount: 50,
            paymentDate: calendar.date(byAdding: .day, value: -21, to: Date())!,
            paymentMethod: .cash,
            paymentType: .tip,
            piece: piece2,
            client: client2
        )
        context.insert(payment5)
    }
}
