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

    // MARK: - Bookings deep-link

    /// When non-nil, `SessionsTabView` should switch to the Sessions group
    /// and highlight this session in the list.
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

    /// Navigate to a session in the Bookings → Sessions list (switches tab).
    func navigateToSession(_ session: Session) {
        selectedTab = .schedule
        // Delay one run-loop so SessionsTabView has appeared before consuming.
        Task { @MainActor in
            self.pendingSession = session
        }
    }
}
