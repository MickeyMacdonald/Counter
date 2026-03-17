import SwiftUI
import SwiftData

@main
struct CounterApp: App {
    let modelContainer: ModelContainer
    @State private var lockManager = BusinessLockManager()

    init() {
        do {
            let schema = Schema([
                Client.self,
                Piece.self,
                ImageGroup.self,
                PieceImage.self,
                TattooSession.self,
                Agreement.self,
                CommunicationLog.self,
                UserProfile.self,
                Booking.self,
                AvailabilitySlot.self,
                InspirationImage.self,
                Payment.self,
                CustomEmailTemplate.self,
                AvailabilityOverride.self,
                CustomSessionType.self,
                FlashPriceTier.self,
                SessionRateConfig.self,
                CustomGalleryGroup.self
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(lockManager)
                .onAppear {
                    SeedDataService.seedIfNeeded(context: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
