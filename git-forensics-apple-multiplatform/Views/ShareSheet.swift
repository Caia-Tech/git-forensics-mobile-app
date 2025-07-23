//
//  ShareSheet.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import SwiftUI

#if os(iOS)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Custom activity item for event export
class EventExportItem: NSObject, UIActivityItemSource {
    let event: ForensicEvent
    let data: Data
    let fileType: String
    
    init(event: ForensicEvent, data: Data, fileType: String = "json") {
        self.event = event
        self.data = data
        self.fileType = fileType
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return data
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return data
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Forensic Event: \(event.title)"
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        switch fileType {
        case "pdf":
            return "com.adobe.pdf"
        default:
            return "public.json"
        }
    }
}

#elseif os(macOS)
import AppKit

struct ShareSheet: View {
    let activityItems: [Any]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Export Data")
                .font(.headline)
                .padding()
            
            HStack(spacing: 20) {
                Button("Save to File") {
                    if let item = activityItems.first as? EventExportItem {
                        saveEventToFile(item: item)
                    } else if let item = activityItems.first as? ExportFileItem {
                        saveExportToFile(item: item)
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 300, height: 150)
    }
    
    private func saveEventToFile(item: EventExportItem) {
        let savePanel = NSSavePanel()
        savePanel.title = "Save Forensic Event"
        savePanel.message = "Choose where to save the forensic event export"
        savePanel.nameFieldStringValue = "forensic_event_\(item.event.id.uuidString).\(item.fileType)"
        
        if item.fileType == "pdf" {
            savePanel.allowedContentTypes = [.pdf]
        } else {
            savePanel.allowedContentTypes = [.json]
        }
        
        savePanel.begin { [dismiss] response in
            if response == .OK, let url = savePanel.url {
                do {
                    try item.data.write(to: url)
                } catch {
                    print("Failed to save file: \(error)")
                }
            }
            dismiss()
        }
    }
    
    private func saveExportToFile(item: ExportFileItem) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Git Forensics Data"
        savePanel.message = "Choose where to save the export"
        savePanel.nameFieldStringValue = "\(item.fileName).\(item.fileExtension)"
        
        switch item.fileExtension.lowercased() {
        case "pdf":
            savePanel.allowedContentTypes = [.pdf]
        case "csv":
            savePanel.allowedContentTypes = [.commaSeparatedText]
        default:
            savePanel.allowedContentTypes = [.json]
        }
        
        savePanel.begin { [dismiss] response in
            if response == .OK, let url = savePanel.url {
                do {
                    try item.data.write(to: url)
                } catch {
                    print("Failed to save file: \(error)")
                }
            }
            dismiss()
        }
    }
}

// Custom activity item for event export
class EventExportItem: NSObject {
    let event: ForensicEvent
    let data: Data
    let fileType: String
    
    init(event: ForensicEvent, data: Data, fileType: String = "json") {
        self.event = event
        self.data = data
        self.fileType = fileType
    }
}
#endif

// Cross-platform export file item for settings
class ExportFileItem: NSObject {
    let data: Data
    let fileName: String
    let fileExtension: String
    
    init(data: Data, fileName: String, fileExtension: String) {
        self.data = data
        self.fileName = fileName
        self.fileExtension = fileExtension
        super.init()
    }
}

#if os(iOS)
extension ExportFileItem: UIActivityItemSource {
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return data
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return data
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Git Forensics Export - \(fileName).\(fileExtension)"
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        switch fileExtension.lowercased() {
        case "pdf":
            return "com.adobe.pdf"
        case "csv":
            return "public.comma-separated-values-text"
        default:
            return "public.json"
        }
    }
}
#endif