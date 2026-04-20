import Foundation

/// Pre-built email templates for common tattoo artist communications.
/// Templates use placeholder tokens that get replaced with client/piece data.
struct EmailTemplate: Identifiable {
    let id: String
    let name: String
    let subject: String
    let body: String
    let category: TemplateCategory

    enum TemplateCategory: String, CaseIterable {
        case healedPhoto = "Healed Photo Request"
        case birthday = "Birthday"
        case flash = "Flash Offering"
        case followUp = "Follow-Up"
        case appointment = "Appointment"
        case custom = "Custom (Individual)"
        case customGeneral = "Custom (General)"

        var systemImage: String {
            switch self {
            case .healedPhoto: "heart.circle"
            case .birthday: "gift"
            case .flash: "bolt.fill"
            case .followUp: "arrow.turn.up.right"
            case .appointment: "calendar"
            case .custom: "envelope"
            case .customGeneral: "envelope.open.fill"
            }
        }
    }

    /// Replace placeholders with actual client, piece, and artist data.
    func rendered(
        clientName: String,
        clientEmail: String = "",
        clientPhone: String = "",
        artistName: String = "your artist",
        artistSignature: String = "",
        pieceName: String = "",
        piecePlacement: String = "",
        sessionDate: String = "",
        customFields: [String: String] = [:]
    ) -> (subject: String, body: String) {
        var s = subject
        var b = body

        let signature = artistSignature.isEmpty ? artistName : artistSignature

        let replacements: [String: String] = [
            "{{CLIENT_NAME}}": clientName,
            "{{CLIENT_FIRST}}": clientName.components(separatedBy: " ").first ?? clientName,
            "{{CLIENT_EMAIL}}": clientEmail,
            "{{CLIENT_PHONE}}": clientPhone,
            "{{ARTIST_NAME}}": artistName,
            "{{ARTIST_SIGNATURE}}": signature,
            "{{PIECE_NAME}}": pieceName,
            "{{PIECE_PLACEMENT}}": piecePlacement,
            "{{SESSION_DATE}}": sessionDate,
            "{{CURRENT_YEAR}}": "\(Calendar.current.component(.year, from: Date()))",
        ].merging(customFields) { _, new in new }

        for (token, value) in replacements {
            s = s.replacingOccurrences(of: token, with: value)
            b = b.replacingOccurrences(of: token, with: value)
        }

        return (s, b)
    }
}

/// Built-in template library
enum EmailTemplates {

    static let healedPhotoRequest = EmailTemplate(
        id: "healed_photo_4wk",
        name: "Healed Photo Request (4 weeks)",
        subject: "How's your tattoo healing? — Quick photo request",
        body: """
        Hey {{CLIENT_FIRST}},

        Hope you're doing well! It's been about 4 weeks since your session on {{SESSION_DATE}} for "{{PIECE_NAME}}", and your tattoo should be nicely healed by now.

        Would you mind sending me a quick photo of how it's looking? Healed photos are really important for my records and help me keep track of how my work settles over time.

        Just snap a photo in good natural light and reply to this email with it attached — no need to be fancy.

        If you notice anything that looks like it needs a touch-up, let me know and we'll get that sorted.

        Thanks!
        {{ARTIST_NAME}}
        """,
        category: .healedPhoto
    )

    static let healedPhotoReminder = EmailTemplate(
        id: "healed_photo_8wk",
        name: "Healed Photo Reminder (8 weeks)",
        subject: "Following up — healed photo of your tattoo",
        body: """
        Hey {{CLIENT_FIRST}},

        Just following up on my earlier message about getting a healed photo of "{{PIECE_NAME}}". It's been about 8 weeks now and I'd love to see how it's settled.

        A quick photo whenever you get a chance would be great. These healed shots are essential for my portfolio and records.

        Thanks again for trusting me with your skin.

        {{ARTIST_NAME}}
        """,
        category: .healedPhoto
    )

    static let birthdayGreeting = EmailTemplate(
        id: "birthday",
        name: "Birthday Greeting",
        subject: "Happy Birthday, {{CLIENT_FIRST}}!",
        body: """
        Hey {{CLIENT_FIRST}},

        Happy birthday! Hope you have an incredible day.

        If you've been thinking about your next piece, birthdays are a great excuse. Hit me up if you want to get something on the books.

        Cheers,
        {{ARTIST_NAME}}
        """,
        category: .birthday
    )

    static let birthdayWithDiscount = EmailTemplate(
        id: "birthday_discount",
        name: "Birthday Greeting + Discount",
        subject: "Happy Birthday — a little something for you",
        body: """
        Hey {{CLIENT_FIRST}},

        Happy birthday! To celebrate, I'm offering you a birthday discount on your next session — mention this email when you book.

        Whether you've been sitting on an idea or want something spontaneous, let's make it happen.

        This offer is good for 30 days, no rush.

        Have a great one,
        {{ARTIST_NAME}}
        """,
        category: .birthday
    )

    static let flashOffering = EmailTemplate(
        id: "flash_drop",
        name: "Flash Sheet Drop",
        subject: "New flash available — first come, first served",
        body: """
        Hey {{CLIENT_FIRST}},

        I just dropped a new set of flash designs and wanted to give you early access before I post them publicly.

        These are ready to go — no wait time on design, just book and sit. Sizes and pricing vary, so reach out if anything catches your eye.

        First come, first served. Reply to this email or DM me to claim one.

        {{ARTIST_NAME}}
        """,
        category: .flash
    )

    static let followUpPostSession = EmailTemplate(
        id: "post_session",
        name: "Post-Session Follow-Up",
        subject: "Aftercare reminder — {{PIECE_NAME}}",
        body: """
        Hey {{CLIENT_FIRST}},

        Thanks for sitting like a champ today! Here's a quick aftercare reminder for "{{PIECE_NAME}}":

        - Keep the wrap on for 2-4 hours (or as we discussed)
        - Wash gently with unscented soap, pat dry
        - Apply a thin layer of unscented moisturizer 2-3x daily
        - No submerging in water (pools, baths, ocean) for 2-3 weeks
        - Keep it out of direct sunlight while healing
        - Don't pick or scratch — let it peel naturally

        If anything looks off or you have questions, don't hesitate to reach out.

        I'll follow up in a few weeks to check on healing and grab a healed photo.

        {{ARTIST_NAME}}
        """,
        category: .followUp
    )

    static let appointmentReminder = EmailTemplate(
        id: "appt_reminder",
        name: "Appointment Reminder",
        subject: "Reminder: Your tattoo appointment on {{SESSION_DATE}}",
        body: """
        Hey {{CLIENT_FIRST}},

        Just a reminder that you've got a session coming up on {{SESSION_DATE}} for "{{PIECE_NAME}}".

        A few things to remember:
        - Get a good night's sleep
        - Eat a solid meal beforehand
        - Stay hydrated
        - Wear comfortable clothing that gives access to the area
        - No alcohol 24 hours before

        If you need to reschedule, please let me know at least 48 hours in advance.

        See you soon,
        {{ARTIST_NAME}}
        """,
        category: .appointment
    )

    static var all: [EmailTemplate] {
        [
            healedPhotoRequest,
            healedPhotoReminder,
            birthdayGreeting,
            birthdayWithDiscount,
            flashOffering,
            followUpPostSession,
            appointmentReminder,
        ]
    }

    static func templates(for category: EmailTemplate.TemplateCategory) -> [EmailTemplate] {
        all.filter { $0.category == category }
    }
}
