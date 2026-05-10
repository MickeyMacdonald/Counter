import Foundation
import UserNotifications
import SwiftData

// MARK: - NotificationService

/// Owns all interactions with UNUserNotificationCenter.
///
/// Two notification types per Booking:
///   _eve     — evening before, at the artist's configured hour (default 6 PM)
///   _morning — morning of,     at the artist's configured hour (default 8 AM)
///
/// Notification IDs are stable: "{booking.id}_eve" / "{booking.id}_morning".
/// This lets individual bookings be cancelled and rescheduled without
/// touching unrelated pending notifications.
actor NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - UserDefaults keys

    static let enabledKey        = "notifications.enabled"
    static let eveEnabledKey     = "notifications.eveEnabled"
    static let eveHourKey        = "notifications.eveHour"
    static let morningEnabledKey = "notifications.morningEnabled"
    static let morningHourKey    = "notifications.morningHour"

    static let defaultEveHour     = 18
    static let defaultMorningHour = 8

    // MARK: - Permission

    var authorizationStatus: UNAuthorizationStatus {
        get async { await center.notificationSettings().authorizationStatus }
    }

    /// Requests alert + sound permission. Returns true if granted.
    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    // MARK: - Per-booking schedule / cancel

    func schedule(for booking: Booking) async {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { return }
        await cancel(for: booking)

        let clientName = booking.client?.name ?? "Client"
        let pieceTitle = booking.piece?.title ?? "Session"
        let timeStr    = booking.startTime.formatted(date: .omitted, time: .shortened)
        let day        = Calendar.current.dateComponents([.year, .month, .day], from: booking.startTime)

        // Evening reminder — day before at configured hour
        let eveEnabled = UserDefaults.standard.object(forKey: Self.eveEnabledKey) as? Bool ?? true
        if eveEnabled, let bookingDate = Calendar.current.date(from: day),
           let eveBase = Calendar.current.date(byAdding: .day, value: -1, to: bookingDate) {
            let eveHour = UserDefaults.standard.object(forKey: Self.eveHourKey) as? Int ?? Self.defaultEveHour
            var eveTrigger = Calendar.current.dateComponents([.year, .month, .day], from: eveBase)
            eveTrigger.hour   = eveHour
            eveTrigger.minute = 0

            if let fireDate = Calendar.current.date(from: eveTrigger), fireDate > .now {
                await addNotification(
                    id:      "\(booking.id.uuidString)_eve",
                    title:   "Tomorrow — \(clientName)",
                    body:    "\(timeStr) · \(pieceTitle)",
                    trigger: eveTrigger
                )
            }
        }

        // Morning-of reminder — booking day at configured hour
        let morningEnabled = UserDefaults.standard.object(forKey: Self.morningEnabledKey) as? Bool ?? true
        if morningEnabled {
            let morningHour = UserDefaults.standard.object(forKey: Self.morningHourKey) as? Int ?? Self.defaultMorningHour
            var morningTrigger = day
            morningTrigger.hour   = morningHour
            morningTrigger.minute = 0

            if let fireDate = Calendar.current.date(from: morningTrigger), fireDate > .now {
                await addNotification(
                    id:      "\(booking.id.uuidString)_morning",
                    title:   "Today — \(clientName)",
                    body:    "\(timeStr) · \(pieceTitle)",
                    trigger: morningTrigger
                )
            }
        }
    }

    func cancel(for booking: Booking) {
        center.removePendingNotificationRequests(withIdentifiers: [
            "\(booking.id.uuidString)_eve",
            "\(booking.id.uuidString)_morning"
        ])
    }

    // MARK: - Full sync

    /// Removes all pending notifications and reschedules from every upcoming
    /// Booking. Call on app launch and when notification settings change.
    func syncAll(context: ModelContext) async {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else {
            center.removeAllPendingNotificationRequests()
            return
        }

        guard await authorizationStatus == .authorized else { return }

        center.removeAllPendingNotificationRequests()

        let bookings = (try? context.fetch(FetchDescriptor<Booking>())) ?? []
        for booking in bookings where booking.isUpcoming {
            await schedule(for: booking)
        }
    }

    // MARK: - Private

    private func addNotification(
        id: String,
        title: String,
        body: String,
        trigger: DateComponents
    ) async {
        let content       = UNMutableNotificationContent()
        content.title     = title
        content.body      = body
        content.sound     = .default
        let request = UNNotificationRequest(
            identifier: id,
            content:    content,
            trigger:    UNCalendarNotificationTrigger(dateMatching: trigger, repeats: false)
        )
        try? await center.add(request)
    }
}
