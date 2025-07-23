//
//  PDFExportManager.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation
import PDFKit
import CoreImage
import CoreImage.CIFilterBuiltins

#if os(iOS)
import UIKit
typealias PDFPlatformFont = UIFont
typealias PDFPlatformColor = UIColor
#elseif os(macOS)
import AppKit
typealias PDFPlatformFont = NSFont
typealias PDFPlatformColor = NSColor
extension NSColor {
    static var darkGray: NSColor { .darkGray }  
    static var systemGreen: NSColor { .systemGreen }
    static var systemRed: NSColor { .systemRed }
}
#endif

class PDFExportManager {
    static let shared = PDFExportManager()
    
    private init() {}
    
    /// Export events as a PDF report with verification QR codes
    func exportEventsToPDF(_ events: [ForensicEvent], includeAttachments: Bool = true) throws -> Data {
        #if os(macOS)
        // PDF export not yet implemented for macOS
        throw NSError(domain: "PDFExportManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "PDF export is not available on macOS"])
        #else
        let pdfMetaData = [
            kCGPDFContextCreator: "Git Forensics Mobile",
            kCGPDFContextAuthor: "Device \(DeviceInfo.shared.deviceId.uuidString.prefix(8))",
            kCGPDFContextTitle: "Forensic Evidence Report",
            kCGPDFContextSubject: "Tamper-evident documentation created \(ISO8601DateFormatter().string(from: Date()))"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        return renderer.pdfData { context in
            // Title page
            createTitlePage(context: context, pageRect: pageRect, events: events)
            
            // Chain verification page
            createChainVerificationPage(context: context, pageRect: pageRect, events: events)
            
            // Individual event pages
            for (index, event) in events.enumerated() {
                createEventPage(context: context, pageRect: pageRect, event: event, eventNumber: index + 1, totalEvents: events.count, includeAttachments: includeAttachments)
            }
            
            // Summary page
            createSummaryPage(context: context, pageRect: pageRect, events: events)
        }
        #endif
    }
    
    /// Export a single event as PDF
    func exportEventToPDF(_ event: ForensicEvent, includeAttachments: Bool = true) throws -> Data {
        return try exportEventsToPDF([event], includeAttachments: includeAttachments)
    }
    
    // MARK: - Page Creation Methods
    
    #if os(iOS)
    private func createTitlePage(context: UIGraphicsPDFRendererContext, pageRect: CGRect, events: [ForensicEvent]) {
        context.beginPage()
        let cgContext = context.cgContext
        
        // Title
        let title = "FORENSIC EVIDENCE REPORT"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.boldSystemFont(ofSize: 24),
            .foregroundColor: PDFPlatformColor.black
        ]
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(x: (pageRect.width - titleSize.width) / 2, y: 100, width: titleSize.width, height: titleSize.height)
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Subtitle
        let subtitle = "Tamper-Evident Documentation"
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.systemFont(ofSize: 18),
            .foregroundColor: PDFPlatformColor.darkGray
        ]
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        let subtitleRect = CGRect(x: (pageRect.width - subtitleSize.width) / 2, y: titleRect.maxY + 20, width: subtitleSize.width, height: subtitleSize.height)
        subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)
        
        // Report details
        let reportInfo = [
            "Generated: \(DateFormatter.exportFormatter.string(from: Date()))",
            "Device ID: \(DeviceInfo.shared.deviceId.uuidString.prefix(8).uppercased())",
            "Events: \(events.count)",
            "Date Range: \(getDateRange(for: events))",
            "App Version: \(DeviceInfo.shared.appVersion) (\(DeviceInfo.shared.appBuild))"
        ]
        
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.systemFont(ofSize: 14),
            .foregroundColor: PDFPlatformColor.black
        ]
        
        var yOffset: CGFloat = subtitleRect.maxY + 60
        for info in reportInfo {
            let infoRect = CGRect(x: 80, y: yOffset, width: pageRect.width - 160, height: 20)
            info.draw(in: infoRect, withAttributes: infoAttributes)
            yOffset += 25
        }
        
        // Chain verification QR code
        if let chainHash = calculateChainHash(for: events),
           let qrImage = generateQRCode(for: chainHash) {
            let qrSize: CGFloat = 150
            let qrRect = CGRect(x: (pageRect.width - qrSize) / 2, y: yOffset + 40, width: qrSize, height: qrSize)
            qrImage.draw(in: qrRect)
            
            let qrLabel = "Chain Verification QR Code"
            let qrLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFPlatformFont.systemFont(ofSize: 12),
                .foregroundColor: PDFPlatformColor.darkGray
            ]
            let qrLabelSize = qrLabel.size(withAttributes: qrLabelAttributes)
            let qrLabelRect = CGRect(x: (pageRect.width - qrLabelSize.width) / 2, y: qrRect.maxY + 10, width: qrLabelSize.width, height: qrLabelSize.height)
            qrLabel.draw(in: qrLabelRect, withAttributes: qrLabelAttributes)
        }
        
        // Footer
        let footer = "This report contains cryptographically verified evidence. Each event is linked using SHA-256 hashes to detect tampering."
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.systemFont(ofSize: 10),
            .foregroundColor: PDFPlatformColor.darkGray
        ]
        let footerRect = CGRect(x: 60, y: pageRect.height - 80, width: pageRect.width - 120, height: 40)
        footer.draw(in: footerRect, withAttributes: footerAttributes)
    }
    
    private func createChainVerificationPage(context: UIGraphicsPDFRendererContext, pageRect: CGRect, events: [ForensicEvent]) {
        context.beginPage()
        
        let title = "CHAIN VERIFICATION"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.boldSystemFont(ofSize: 20),
            .foregroundColor: PDFPlatformColor.black
        ]
        let titleRect = CGRect(x: 60, y: 60, width: pageRect.width - 120, height: 30)
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Verification status
        let (isValid, error) = CryptoUtils.verifyEventChain(events)
        let status = isValid ? "✓ CHAIN INTACT" : "⚠ CHAIN COMPROMISED"
        let statusColor = isValid ? PDFPlatformColor.systemGreen : PDFPlatformColor.systemRed
        let statusAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.boldSystemFont(ofSize: 16),
            .foregroundColor: statusColor
        ]
        let statusRect = CGRect(x: 60, y: titleRect.maxY + 20, width: pageRect.width - 120, height: 25)
        status.draw(in: statusRect, withAttributes: statusAttributes)
        
        if let error = error {
            let errorText = "Error: \(error)"
            let errorAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFPlatformFont.systemFont(ofSize: 14),
                .foregroundColor: PDFPlatformColor.systemRed
            ]
            let errorRect = CGRect(x: 60, y: statusRect.maxY + 10, width: pageRect.width - 120, height: 20)
            errorText.draw(in: errorRect, withAttributes: errorAttributes)
        }
        
        // Chain details
        var yOffset = statusRect.maxY + 50
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.systemFont(ofSize: 12),
            .foregroundColor: PDFPlatformColor.black
        ]
        
        for (index, event) in events.enumerated() {
            let eventInfo = "Event \(index + 1): \(event.type.displayName) - \(event.title)"
            let hashInfo = "Hash: \(event.integrity.contentHash.prefix(16))..."
            
            let eventRect = CGRect(x: 60, y: yOffset, width: pageRect.width - 120, height: 15)
            eventInfo.draw(in: eventRect, withAttributes: detailAttributes)
            
            let hashRect = CGRect(x: 80, y: yOffset + 15, width: pageRect.width - 140, height: 15)
            hashInfo.draw(in: hashRect, withAttributes: [
                .font: PDFPlatformFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: PDFPlatformColor.darkGray
            ])
            
            yOffset += 40
            
            // Start new page if needed
            if yOffset > pageRect.height - 100 {
                context.beginPage()
                yOffset = 60
            }
        }
    }
    
    private func createEventPage(context: UIGraphicsPDFRendererContext, pageRect: CGRect, event: ForensicEvent, eventNumber: Int, totalEvents: Int, includeAttachments: Bool) {
        context.beginPage()
        
        // Header
        let header = "EVENT \(eventNumber) OF \(totalEvents)"
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.boldSystemFont(ofSize: 18),
            .foregroundColor: PDFPlatformColor.black
        ]
        let headerRect = CGRect(x: 60, y: 60, width: pageRect.width - 120, height: 25)
        header.draw(in: headerRect, withAttributes: headerAttributes)
        
        // Event type and title
        let typeTitle = "\(event.type.displayName): \(event.title)"
        let typeTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.boldSystemFont(ofSize: 16),
            .foregroundColor: PDFPlatformColor.black
        ]
        let typeTitleRect = CGRect(x: 60, y: headerRect.maxY + 20, width: pageRect.width - 120, height: 25)
        typeTitle.draw(in: typeTitleRect, withAttributes: typeTitleAttributes)
        
        // Timestamp
        let timestamp = "Created: \(DateFormatter.exportFormatter.string(from: event.createdAt))"
        let timestampAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.systemFont(ofSize: 14),
            .foregroundColor: PDFPlatformColor.darkGray
        ]
        let timestampRect = CGRect(x: 60, y: typeTitleRect.maxY + 10, width: pageRect.width - 120, height: 20)
        timestamp.draw(in: timestampRect, withAttributes: timestampAttributes)
        
        // Notes
        if !event.notes.isEmpty {
            let notesLabel = "Details:"
            let notesLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFPlatformFont.boldSystemFont(ofSize: 14),
                .foregroundColor: PDFPlatformColor.black
            ]
            let notesLabelRect = CGRect(x: 60, y: timestampRect.maxY + 30, width: pageRect.width - 120, height: 20)
            notesLabel.draw(in: notesLabelRect, withAttributes: notesLabelAttributes)
            
            let notesAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFPlatformFont.systemFont(ofSize: 12),
                .foregroundColor: PDFPlatformColor.black
            ]
            let notesRect = CGRect(x: 60, y: notesLabelRect.maxY + 5, width: pageRect.width - 120, height: 200)
            event.notes.draw(in: notesRect, withAttributes: notesAttributes)
        }
        
        // Attachments
        if includeAttachments && !event.attachments.isEmpty {
            let attachmentsLabel = "Attachments (\(event.attachments.count)):"
            let attachmentsLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFPlatformFont.boldSystemFont(ofSize: 14),
                .foregroundColor: PDFPlatformColor.black
            ]
            let attachmentsLabelRect = CGRect(x: 60, y: 400, width: pageRect.width - 120, height: 20)
            attachmentsLabel.draw(in: attachmentsLabelRect, withAttributes: attachmentsLabelAttributes)
            
            var attachmentY = attachmentsLabelRect.maxY + 10
            for attachment in event.attachments {
                let attachmentInfo = "• \(attachment.filename) (\(ByteCountFormatter.string(fromByteCount: attachment.sizeBytes, countStyle: .file)))"
                let attachmentHash = "  SHA-256: \(attachment.hashSHA256)"
                
                let attachmentAttributes: [NSAttributedString.Key: Any] = [
                    .font: PDFPlatformFont.systemFont(ofSize: 11),
                    .foregroundColor: PDFPlatformColor.black
                ]
                
                let attachmentRect = CGRect(x: 80, y: attachmentY, width: pageRect.width - 140, height: 15)
                attachmentInfo.draw(in: attachmentRect, withAttributes: attachmentAttributes)
                
                let hashRect = CGRect(x: 80, y: attachmentY + 15, width: pageRect.width - 140, height: 15)
                attachmentHash.draw(in: hashRect, withAttributes: [
                    .font: PDFPlatformFont.monospacedSystemFont(ofSize: 9, weight: .regular),
                    .foregroundColor: PDFPlatformColor.darkGray
                ])
                
                attachmentY += 35
            }
        }
        
        // Event verification QR code
        let eventHash = event.integrity.contentHash
        if let qrImage = generateQRCode(for: eventHash) {
            let qrSize: CGFloat = 80
            let qrRect = CGRect(x: pageRect.width - qrSize - 60, y: pageRect.height - qrSize - 80, width: qrSize, height: qrSize)
            qrImage.draw(in: qrRect)
            
            let qrLabel = "Event Hash"
            let qrLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: PDFPlatformFont.systemFont(ofSize: 10),
                .foregroundColor: PDFPlatformColor.darkGray
            ]
            let qrLabelRect = CGRect(x: qrRect.minX, y: qrRect.maxY + 5, width: qrSize, height: 15)
            qrLabel.draw(in: qrLabelRect, withAttributes: qrLabelAttributes)
        }
        
        // Hash info
        let hashInfo = "Event Hash: \(eventHash.prefix(32))..."
        let hashAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.monospacedSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: PDFPlatformColor.darkGray
        ]
        let hashRect = CGRect(x: 60, y: pageRect.height - 60, width: pageRect.width - 200, height: 15)
        hashInfo.draw(in: hashRect, withAttributes: hashAttributes)
    }
    
    private func createSummaryPage(context: UIGraphicsPDFRendererContext, pageRect: CGRect, events: [ForensicEvent]) {
        context.beginPage()
        
        let title = "REPORT SUMMARY"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.boldSystemFont(ofSize: 20),
            .foregroundColor: PDFPlatformColor.black
        ]
        let titleRect = CGRect(x: 60, y: 60, width: pageRect.width - 120, height: 30)
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Statistics
        let stats = [
            "Total Events: \(events.count)",
            "Event Types: \(Set(events.map { $0.type }).count)",
            "Total Attachments: \(events.flatMap { $0.attachments }.count)",
            "Date Range: \(getDateRange(for: events))",
            "Chain Verification: \(CryptoUtils.verifyEventChain(events).isValid ? "VALID" : "INVALID")"
        ]
        
        let statsAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.systemFont(ofSize: 14),
            .foregroundColor: PDFPlatformColor.black
        ]
        
        var yOffset = titleRect.maxY + 40
        for stat in stats {
            let statRect = CGRect(x: 60, y: yOffset, width: pageRect.width - 120, height: 20)
            stat.draw(in: statRect, withAttributes: statsAttributes)
            yOffset += 25
        }
        
        // Verification instructions
        let instructions = """
        VERIFICATION INSTRUCTIONS:
        
        1. Scan the QR codes in this report to verify event hashes
        2. Check that each event hash matches the recorded data
        3. Verify the chain integrity using the verification page
        4. Compare timestamps and metadata for consistency
        
        This report was generated on \(DateFormatter.exportFormatter.string(from: Date())) by Git Forensics Mobile v\(DeviceInfo.shared.appVersion).
        
        For questions about this report or to verify its authenticity, reference Device ID: \(DeviceInfo.shared.deviceId.uuidString.prefix(8).uppercased())
        """
        
        let instructionsAttributes: [NSAttributedString.Key: Any] = [
            .font: PDFPlatformFont.systemFont(ofSize: 12),
            .foregroundColor: PDFPlatformColor.black
        ]
        let instructionsRect = CGRect(x: 60, y: yOffset + 40, width: pageRect.width - 120, height: 200)
        instructions.draw(in: instructionsRect, withAttributes: instructionsAttributes)
    }
    #endif
    
    // MARK: - Helper Methods
    
    #if os(iOS)
    private func generateQRCode(for string: String) -> UIImage? {
        let data = string.data(using: .utf8)
        
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction
        
        guard let ciImage = filter.outputImage else { return nil }
        
        // Scale up the QR code
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    #else
    private func generateQRCode(for string: String) -> NSImage? {
        let data = string.data(using: .utf8)
        
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    #endif
    
    private func calculateChainHash(for events: [ForensicEvent]) -> String? {
        guard !events.isEmpty else { return nil }
        
        let chainData = events.map { $0.integrity.contentHash }.joined()
        return CryptoUtils.sha256Hash(of: Data(chainData.utf8))
    }
    
    private func getDateRange(for events: [ForensicEvent]) -> String {
        guard !events.isEmpty else { return "No events" }
        
        let dates = events.map { $0.createdAt }.sorted()
        let startDate = dates.first!
        let endDate = dates.last!
        
        let formatter = DateFormatter.exportFormatter
        
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return formatter.string(from: startDate)
        } else {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}