import Foundation
import Observation

/// Lightweight coordinator for cross-tab deep-link navigation.
///
/// Any view in the hierarchy can set `selectedTab` alongside one of the
/// `pending*` properties to jump straight to a specific item in another tab.
/// The receiving tab view consumes (and clears) the pending value inside
/// `.onAppear` / `.onChange`.
@Observable
final class AppNavigationCoordinator {
    var selectedTab: AppTab = .work

    // MARK: - Works deep-link

    /// When non-nil, `WorksTabView` should switch to the Clients section
    /// and select this client in the sidebar.
    var pendingClient: Client?

    /// When non-nil, `WorksTabView` should switch to the Pieces section
    /// and select this piece in the sidebar.
    var pendingPiece: Piece?

    // MARK: - Scheduling deep-link

    /// When non-nil, `SchedulingView` should switch to the Sessions group
    /// and select this booking.
    var pendingBooking: Booking?

    /// Legacy: navigating from PieceDetailView sessions list. Switches to
    /// the schedule tab; the Sessions group now shows Bookings so this is
    /// not consumed by SchedulingView — use `navigateToBooking` instead.
    var pendingSession: Session?

    // MARK: - Gallery deep-link

    /// When non-nil, GalleryTabView should switch to Library → Client view
    /// and filter to this specific client.
    var pendingGalleryClient: Client?

    // MARK: - Convenience navigators

    /// Navigate to a client in the Works sidebar (switches tab if needed).
    func navigateToClient(_ client: Client) {
        selectedTab   = .work
        pendingClient = client
    }

    /// Navigate to a piece in the Works sidebar (switches tab if needed).
    func navigateToPiece(_ piece: Piece) {
        selectedTab  = .work
        pendingPiece = piece
    }

    /// Navigate to Gallery → Library → Client, filtered to the given client.
    func navigateToGallery(client: Client) {
        selectedTab = .gallery
        Task { @MainActor in
            pendingGalleryClient = client
        }
    }

    /// Navigate to a booking in the Scheduling → Sessions list (switches tab).
    func navigateToBooking(_ booking: Booking) {
        selectedTab    = .schedule
        Task { @MainActor in
            self.pendingBooking = booking
        }
    }

    /// Navigate to a session in the Scheduling tab (legacy — switches tab only).
    func navigateToSession(_ session: Session) {
        selectedTab = .schedule
        Task { @MainActor in
            self.pendingSession = session
        }
    }
}
