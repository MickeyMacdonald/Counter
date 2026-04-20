import Foundation
import SwiftData

/// A user-created email template stored persistently in SwiftData.
@Model
final class EmailTemplate {
    var name: String
    var subject: String
    var body: String
    /// Stores the raw value of EmailTemplate.TemplateCategory
    var categoryRaw: String
    var createdAt: Date
    var updatedAt: Date

    var category: EmailTemplate.TemplateCategory {
        get { EmailTemplate.TemplateCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        name: String = "",
        subject: String = "",
        body: String = "",
        category: EmailTemplate.TemplateCategory = .custom
    ) {
        self.name = name
        self.subject = subject
        self.body = body
        self.categoryRaw = category.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Converts to the value-type EmailTemplate for rendering.
    func asEmailTemplate() -> EmailTemplate {
        EmailTemplate(
            id: "custom_\(createdAt.timeIntervalSince1970)",
            name: name,
            subject: subject,
            body: body,
            category: category
        )
    }
}
