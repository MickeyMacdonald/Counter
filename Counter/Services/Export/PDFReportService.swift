import UIKit
import SwiftData

/// Generates PDF reports for client records, legal documentation, and year-end summaries.
/// All rendering is done locally with no external dependencies.
actor PDFReportService {
    static let shared = PDFReportService()

    private let pageSize = CGSize(width: 612, height: 792) // US Letter
    private let margin: CGFloat = 50

    // MARK: - Full Client Report

    func generateClientReport(client: Client, chargeableTypes: [String] = SessionType.defaultChargeableRawValues, includeImages: Bool = false) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        return renderer.pdfData { context in
            var y: CGFloat = 0

            // Page 1: Client Info
            context.beginPage()
            y = margin

            y = drawHeader(context: context.cgContext, y: y, text: "CLIENT REPORT")
            y = drawSubheader(context: context.cgContext, y: y, text: client.fullName)
            y = drawDivider(context: context.cgContext, y: y)

            y = drawLabelValue(context: context.cgContext, y: y, label: "Generated", value: Date().formatted(date: .long, time: .shortened))
            y += 10

            // Contact
            y = drawSectionTitle(context: context.cgContext, y: y, text: "CONTACT INFORMATION")
            if !client.email.isEmpty {
                y = drawLabelValue(context: context.cgContext, y: y, label: "Email", value: client.email)
            }
            if !client.phone.isEmpty {
                y = drawLabelValue(context: context.cgContext, y: y, label: "Phone", value: client.phone)
            }
            if !client.pronouns.isEmpty {
                y = drawLabelValue(context: context.cgContext, y: y, label: "Pronouns", value: client.pronouns)
            }
            if let birthdate = client.birthdate {
                y = drawLabelValue(context: context.cgContext, y: y, label: "Birthdate", value: birthdate.formatted(date: .long, time: .omitted))
            }
            if !client.streetAddress.isEmpty {
                let addr = [client.streetAddress, client.city, client.state, client.zipCode]
                    .filter { !$0.isEmpty }.joined(separator: ", ")
                y = drawLabelValue(context: context.cgContext, y: y, label: "Address", value: addr)
            }

            if !client.allergyNotes.isEmpty {
                y += 10
                y = drawSectionTitle(context: context.cgContext, y: y, text: "ALLERGIES / SENSITIVITIES")
                y = drawBodyText(context: context.cgContext, y: y, text: client.allergyNotes)
            }

            if !client.notes.isEmpty {
                y += 10
                y = drawSectionTitle(context: context.cgContext, y: y, text: "NOTES")
                y = drawBodyText(context: context.cgContext, y: y, text: client.notes)
            }

            // Summary stats
            y += 10
            y = drawSectionTitle(context: context.cgContext, y: y, text: "SUMMARY")
            y = drawLabelValue(context: context.cgContext, y: y, label: "Total Pieces", value: "\(client.pieces.count)")
            y = drawLabelValue(context: context.cgContext, y: y, label: "Total Hours", value: String(format: "%.1f", client.chargeableHours(using: chargeableTypes)))
            y = drawLabelValue(context: context.cgContext, y: y, label: "Total Revenue", value: client.chargeableSpent(using: chargeableTypes).currencyFormatted)
            y = drawLabelValue(context: context.cgContext, y: y, label: "Client Since", value: client.createdAt.formatted(date: .long, time: .omitted))

            // Pieces
            for piece in client.pieces.sorted(by: { $0.createdAt < $1.createdAt }) {
                // Check if we need a new page
                if y > pageSize.height - 200 {
                    context.beginPage()
                    y = margin
                }

                y += 20
                y = drawSectionTitle(context: context.cgContext, y: y, text: "PIECE: \(piece.title.uppercased())")
                y = drawLabelValue(context: context.cgContext, y: y, label: "Status", value: piece.status.rawValue)
                y = drawLabelValue(context: context.cgContext, y: y, label: "Placement", value: piece.bodyPlacement)

                if !piece.descriptionText.isEmpty {
                    y = drawLabelValue(context: context.cgContext, y: y, label: "Description", value: piece.descriptionText)
                }

                if piece.flatRate != nil {
                    y = drawLabelValue(context: context.cgContext, y: y, label: "Flat Rate", value: piece.chargeableCost(using: chargeableTypes).currencyFormatted)
                } else {
                    y = drawLabelValue(context: context.cgContext, y: y, label: "Hourly Rate", value: "\(piece.hourlyRate.currencyFormatted)/hr")
                    y = drawLabelValue(context: context.cgContext, y: y, label: "Chargeable Hours", value: String(format: "%.1f", piece.chargeableHours(using: chargeableTypes)))
                    y = drawLabelValue(context: context.cgContext, y: y, label: "Total Cost", value: piece.chargeableCost(using: chargeableTypes).currencyFormatted)
                }

                if piece.depositAmount > 0 {
                    y = drawLabelValue(context: context.cgContext, y: y, label: "Deposit", value: piece.depositAmount.currencyFormatted)
                }

                if let rating = piece.rating {
                    let stars = String(repeating: "\u{2605}", count: rating) + String(repeating: "\u{2606}", count: 5 - rating)
                    y = drawLabelValue(context: context.cgContext, y: y, label: "Rating", value: stars)
                }

                // Sessions for this piece
                let sortedSessions = piece.sessions.sorted { $0.date < $1.date }
                if !sortedSessions.isEmpty {
                    y += 8
                    y = drawBodyText(context: context.cgContext, y: y, text: "Sessions:", bold: true)
                    for session in sortedSessions {
                        if y > pageSize.height - 80 {
                            context.beginPage()
                            y = margin
                        }
                        let dateStr = session.date.formatted(date: .abbreviated, time: .omitted)
                        let line = "  \(dateStr) — \(session.durationFormatted) — \(session.cost.currencyFormatted)"
                        y = drawBodyText(context: context.cgContext, y: y, text: line)
                        if !session.notes.isEmpty {
                            y = drawBodyText(context: context.cgContext, y: y, text: "    \(session.notes)", color: .gray)
                        }
                    }
                }
            }

            // Agreements
            let signedAgreements = client.agreements.filter(\.isSigned)
            if !signedAgreements.isEmpty {
                if y > pageSize.height - 200 {
                    context.beginPage()
                    y = margin
                }
                y += 20
                y = drawSectionTitle(context: context.cgContext, y: y, text: "SIGNED AGREEMENTS")
                for agreement in signedAgreements.sorted(by: { $0.createdAt < $1.createdAt }) {
                    if y > pageSize.height - 80 {
                        context.beginPage()
                        y = margin
                    }
                    y = drawLabelValue(context: context.cgContext, y: y, label: agreement.agreementType.rawValue, value: agreement.title)
                    if let signedAt = agreement.signedAt {
                        y = drawBodyText(context: context.cgContext, y: y, text: "  Signed: \(signedAt.formatted(date: .long, time: .shortened))", color: .gray)
                    }
                }
            }

            // Communication log
            if !client.communicationLogs.isEmpty {
                if y > pageSize.height - 200 {
                    context.beginPage()
                    y = margin
                }
                y += 20
                y = drawSectionTitle(context: context.cgContext, y: y, text: "COMMUNICATION LOG")
                for log in client.communicationLogs.sorted(by: { $0.sentAt < $1.sentAt }) {
                    if y > pageSize.height - 80 {
                        context.beginPage()
                        y = margin
                    }
                    let dateStr = log.sentAt.formatted(date: .abbreviated, time: .shortened)
                    y = drawBodyText(context: context.cgContext, y: y, text: "\(dateStr) — \(log.commType.rawValue): \(log.subject)")
                }
            }

            // Footer on last page
            drawFooter(context: context.cgContext, text: "Counter — Generated \(Date().formatted())")
        }
    }

    // MARK: - Financial Report

    func generateFinancialReport(pieces: [Piece], profile: UserProfile?, period: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        let totalBilled    = pieces.reduce(Decimal.zero) { $0 + $1.totalCost }
        let totalCollected = pieces.reduce(Decimal.zero) { $0 + $1.totalPaymentsReceived }
        let totalOutstanding = pieces.reduce(Decimal.zero) { $0 + max($1.outstandingBalance, 0) }
        let settledPieces  = pieces.filter { $0.outstandingBalance <= 0 && $0.totalCost > 0 }
        let unsettledPieces = pieces.filter { $0.outstandingBalance > 0 }

        return renderer.pdfData { context in
            context.beginPage()
            var y = margin

            y = drawHeader(context: context.cgContext, y: y, text: "FINANCIAL REPORT")
            if let name = profile?.fullName { y = drawSubheader(context: context.cgContext, y: y, text: name) }
            y = drawDivider(context: context.cgContext, y: y)

            y = drawLabelValue(context: context.cgContext, y: y, label: "Period", value: period)
            y = drawLabelValue(context: context.cgContext, y: y, label: "Generated", value: Date().formatted(date: .long, time: .shortened))
            y += 12

            y = drawSectionTitle(context: context.cgContext, y: y, text: "SUMMARY")
            y = drawLabelValue(context: context.cgContext, y: y, label: "Total Pieces", value: "\(pieces.count)")
            y = drawLabelValue(context: context.cgContext, y: y, label: "Total Billed", value: totalBilled.currencyFormatted)
            y = drawLabelValue(context: context.cgContext, y: y, label: "Total Collected", value: totalCollected.currencyFormatted)
            y = drawLabelValue(context: context.cgContext, y: y, label: "Outstanding", value: totalOutstanding.currencyFormatted)
            y = drawLabelValue(context: context.cgContext, y: y, label: "Settled Pieces", value: "\(settledPieces.count)")
            y = drawLabelValue(context: context.cgContext, y: y, label: "Unsettled Pieces", value: "\(unsettledPieces.count)")
            y += 12

            if !unsettledPieces.isEmpty {
                y = drawSectionTitle(context: context.cgContext, y: y, text: "OUTSTANDING BALANCES")
                for piece in unsettledPieces.sorted(by: { $0.outstandingBalance > $1.outstandingBalance }) {
                    if y > pageSize.height - 80 { context.beginPage(); y = margin }
                    let clientName = piece.client?.fullName ?? "Unknown"
                    let line = "\(piece.title) — \(clientName)"
                    y = drawLabelValue(context: context.cgContext, y: y, label: line, value: piece.outstandingBalance.currencyFormatted)
                }
                y += 12
            }

            if !settledPieces.isEmpty {
                if y > pageSize.height - 200 { context.beginPage(); y = margin }
                y = drawSectionTitle(context: context.cgContext, y: y, text: "SETTLED PIECES")
                for piece in settledPieces {
                    if y > pageSize.height - 80 { context.beginPage(); y = margin }
                    let clientName = piece.client?.fullName ?? "Unknown"
                    let line = "\(piece.title) — \(clientName)"
                    y = drawLabelValue(context: context.cgContext, y: y, label: line, value: piece.totalPaymentsReceived.currencyFormatted)
                }
            }

            drawFooter(context: context.cgContext, text: "Counter — Financial Report — \(Date().formatted())")
        }
    }

    // MARK: - Finished Pieces Report

    func generateFinishedPiecesReport(pieces: [Piece], profile: UserProfile?) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let finished = pieces
            .filter { [PieceStatus.completed, .healed, .touchUp].contains($0.status) }
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }

        return renderer.pdfData { context in
            context.beginPage()
            var y = margin

            y = drawHeader(context: context.cgContext, y: y, text: "FINISHED PIECES")
            if let name = profile?.fullName { y = drawSubheader(context: context.cgContext, y: y, text: name) }
            y = drawDivider(context: context.cgContext, y: y)

            y = drawLabelValue(context: context.cgContext, y: y, label: "Generated", value: Date().formatted(date: .long, time: .shortened))
            y = drawLabelValue(context: context.cgContext, y: y, label: "Total Finished", value: "\(finished.count)")
            y += 12

            if finished.isEmpty {
                y = drawBodyText(context: context.cgContext, y: y, text: "No finished pieces found.")
            } else {
                for piece in finished {
                    if y > pageSize.height - 120 { context.beginPage(); y = margin }

                    y = drawSectionTitle(context: context.cgContext, y: y, text: piece.title.uppercased())
                    if let client = piece.client {
                        y = drawLabelValue(context: context.cgContext, y: y, label: "Client", value: client.fullName)
                    }
                    y = drawLabelValue(context: context.cgContext, y: y, label: "Status", value: piece.status.rawValue)
                    if !piece.bodyPlacement.isEmpty {
                        y = drawLabelValue(context: context.cgContext, y: y, label: "Placement", value: piece.bodyPlacement)
                    }
                    let sessions = piece.sessions.count
                    if sessions > 0 {
                        y = drawLabelValue(context: context.cgContext, y: y, label: "Sessions", value: "\(sessions)")
                    }
                    y = drawLabelValue(context: context.cgContext, y: y, label: "Total Cost", value: piece.totalCost.currencyFormatted)
                    if let completedAt = piece.completedAt {
                        y = drawLabelValue(context: context.cgContext, y: y, label: "Completed", value: completedAt.formatted(date: .long, time: .omitted))
                    }
                    if let rating = piece.rating {
                        let stars = String(repeating: "\u{2605}", count: rating) + String(repeating: "\u{2606}", count: 5 - rating)
                        y = drawLabelValue(context: context.cgContext, y: y, label: "Rating", value: stars)
                    }
                    y += 6
                }
            }

            drawFooter(context: context.cgContext, text: "Counter — Finished Pieces — \(Date().formatted())")
        }
    }

    // MARK: - Flash Portfolio Report

    func generateFlashReport(pieces: [Piece], profile: UserProfile?) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let flash = pieces.sorted { $0.updatedAt > $1.updatedAt }

        return renderer.pdfData { context in
            context.beginPage()
            var y = margin

            y = drawHeader(context: context.cgContext, y: y, text: "FLASH PORTFOLIO")
            if let name = profile?.fullName { y = drawSubheader(context: context.cgContext, y: y, text: name) }
            y = drawDivider(context: context.cgContext, y: y)

            y = drawLabelValue(context: context.cgContext, y: y, label: "Generated", value: Date().formatted(date: .long, time: .shortened))
            y = drawLabelValue(context: context.cgContext, y: y, label: "Total Designs", value: "\(flash.count)")
            y += 12

            if flash.isEmpty {
                y = drawBodyText(context: context.cgContext, y: y, text: "No flash designs found.")
            } else {
                for piece in flash {
                    if y > pageSize.height - 100 { context.beginPage(); y = margin }

                    y = drawSectionTitle(context: context.cgContext, y: y, text: piece.title.uppercased())
                    y = drawLabelValue(context: context.cgContext, y: y, label: "Status", value: piece.status.rawValue)
                    if let flat = piece.flatRate {
                        y = drawLabelValue(context: context.cgContext, y: y, label: "Price", value: flat.currencyFormatted)
                    }
                    if !piece.tags.isEmpty {
                        y = drawLabelValue(context: context.cgContext, y: y, label: "Tags", value: piece.tags.joined(separator: ", "))
                    }
                    if !piece.descriptionText.isEmpty {
                        y = drawLabelValue(context: context.cgContext, y: y, label: "Description", value: piece.descriptionText)
                    }
                    y += 6
                }
            }

            drawFooter(context: context.cgContext, text: "Counter — Flash Portfolio — \(Date().formatted())")
        }
    }

    // MARK: - Agreement PDF

    func generateAgreementPDF(agreement: Agreement, signatureImage: UIImage?) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        return renderer.pdfData { context in
            context.beginPage()
            var y = margin

            y = drawHeader(context: context.cgContext, y: y, text: agreement.agreementType.rawValue.uppercased())
            y = drawSubheader(context: context.cgContext, y: y, text: agreement.title)
            y = drawDivider(context: context.cgContext, y: y)

            if let clientName = agreement.client?.fullName {
                y = drawLabelValue(context: context.cgContext, y: y, label: "Client", value: clientName)
            }
            y = drawLabelValue(context: context.cgContext, y: y, label: "Date", value: agreement.createdAt.formatted(date: .long, time: .omitted))
            y += 15

            // Agreement body
            y = drawBodyText(context: context.cgContext, y: y, text: agreement.bodyText)

            // Signature
            y += 30
            if let signatureImage {
                let sigHeight: CGFloat = 80
                let sigWidth = sigHeight * (signatureImage.size.width / signatureImage.size.height)
                let sigRect = CGRect(x: margin, y: y, width: min(sigWidth, 250), height: sigHeight)
                signatureImage.draw(in: sigRect)
                y += sigHeight + 8
            }

            // Signature line
            let lineY = y
            context.cgContext.setStrokeColor(UIColor.label.cgColor)
            context.cgContext.setLineWidth(0.5)
            context.cgContext.move(to: CGPoint(x: margin, y: lineY))
            context.cgContext.addLine(to: CGPoint(x: margin + 250, y: lineY))
            context.cgContext.strokePath()
            y += 4

            y = drawBodyText(context: context.cgContext, y: y, text: "Signature", color: .gray)

            if let signedAt = agreement.signedAt {
                y += 4
                y = drawBodyText(context: context.cgContext, y: y, text: "Signed: \(signedAt.formatted(date: .long, time: .shortened))", color: .gray)
            }

            drawFooter(context: context.cgContext, text: "Counter — \(agreement.agreementType.rawValue)")
        }
    }

    // MARK: - Drawing Helpers

    private func drawHeader(context: CGContext, y: CGFloat, text: String) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.label,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        str.draw(at: CGPoint(x: margin, y: y))
        return y + 30
    }

    private func drawSubheader(context: CGContext, y: CGFloat, text: String) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        str.draw(at: CGPoint(x: margin, y: y))
        return y + 24
    }

    private func drawSectionTitle(context: CGContext, y: CGFloat, text: String) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.label,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        str.draw(at: CGPoint(x: margin, y: y))
        return y + 18
    }

    private func drawLabelValue(context: CGContext, y: CGFloat, label: String, value: String) -> CGFloat {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel,
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.label,
        ]

        let labelStr = NSAttributedString(string: "\(label): ", attributes: labelAttrs)
        let valueStr = NSAttributedString(string: value, attributes: valueAttrs)

        let combined = NSMutableAttributedString()
        combined.append(labelStr)
        combined.append(valueStr)

        let maxWidth = pageSize.width - (margin * 2)
        let rect = CGRect(x: margin, y: y, width: maxWidth, height: 200)
        combined.draw(with: rect, options: [.usesLineFragmentOrigin], context: nil)

        let boundingRect = combined.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil)
        return y + boundingRect.height + 4
    }

    private func drawBodyText(context: CGContext, y: CGFloat, text: String, bold: Bool = false, color: UIColor = .label) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: bold ? UIFont.systemFont(ofSize: 10, weight: .semibold) : UIFont.systemFont(ofSize: 10),
            .foregroundColor: color,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let maxWidth = pageSize.width - (margin * 2)
        let rect = CGRect(x: margin, y: y, width: maxWidth, height: 600)
        str.draw(with: rect, options: [.usesLineFragmentOrigin], context: nil)

        let boundingRect = str.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil)
        return y + boundingRect.height + 4
    }

    private func drawDivider(context: CGContext, y: CGFloat) -> CGFloat {
        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
        context.strokePath()
        return y + 12
    }

    private func drawFooter(context: CGContext, text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 7, weight: .regular),
            .foregroundColor: UIColor.tertiaryLabel,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        str.draw(at: CGPoint(x: margin, y: pageSize.height - 30))
    }
}
