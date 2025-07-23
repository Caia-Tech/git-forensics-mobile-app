//
//  EventDetailView.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import SwiftUI

struct EventDetailView: View {
    let event: ForensicEvent
    @State private var showingVerification = false
    @State private var showingExport = false
    @State private var showingPDFExport = false
    
    private var platformSecondaryBackground: Color {
        #if os(iOS)
        return Color(.secondarySystemBackground)
        #else
        return Color(.controlBackgroundColor)
        #endif
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Label(event.type.displayName, systemImage: event.type.icon)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(event.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        Text("Verified")
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        Text(event.createdAt, format: .dateTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Details
                if !event.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.headline)
                        
                        Text(event.notes)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal)
                }
                
                // Attachments (if any)
                if !event.attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Attachments")
                            .font(.headline)
                        
                        ForEach(event.attachments) { attachment in
                            AttachmentRow(attachment: attachment)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Location (if any)
                if let location = event.location {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "location.fill")
                            Text("\(location.latitude), \(location.longitude)")
                                .font(.system(.body, design: .monospaced))
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Actions
                VStack(spacing: 12) {
                    Button(action: { showingVerification = true }) {
                        Label("View Verification", systemImage: "checkmark.shield")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    HStack(spacing: 12) {
                        Button(action: { showingExport = true }) {
                            Label("Export JSON", systemImage: "doc.text")
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button(action: { showingPDFExport = true }) {
                            Label("Export PDF", systemImage: "doc.richtext")
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            .padding(.vertical)
        }
        .navigationTitle("Event Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingVerification) {
            VerificationDetailsView(event: event)
        }
        .sheet(isPresented: $showingExport) {
            if let data = try? EventManager.shared.exportEvent(event) {
                ShareSheet(activityItems: [
                    EventExportItem(event: event, data: data, fileType: "json")
                ])
            }
        }
        .sheet(isPresented: $showingPDFExport) {
            if let data = try? PDFExportManager.shared.exportEventToPDF(event) {
                ShareSheet(activityItems: [
                    EventExportItem(event: event, data: data, fileType: "pdf")
                ])
            }
        }
    }
}

struct AttachmentRow: View {
    let attachment: EventAttachment
    
    var body: some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading) {
                Text(attachment.filename)
                    .font(.subheadline)
                
                Text("SHA-256: \(String(attachment.hashSHA256.prefix(16)))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontDesign(.monospaced)
            }
            
            Spacer()
            
            Text(ByteCountFormatter.string(fromByteCount: attachment.sizeBytes, countStyle: .file))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct VerificationDetailsView: View {
    let event: ForensicEvent
    @Environment(\.dismiss) var dismiss
    
    private var platformSecondaryBackground: Color {
        #if os(iOS)
        return Color(.secondarySystemBackground)
        #else
        return Color(.controlBackgroundColor)
        #endif
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("This event cannot be altered without detection.")
                        .font(.callout)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    
                    Group {
                        DetailRow(label: "Created", value: event.createdAt.formatted(.dateTime.year().month().day().hour().minute().second()))
                        
                        DetailRow(label: "Event ID", value: event.id.uuidString, monospaced: true)
                        
                        DetailRow(label: "Verification Code", value: event.integrity.contentHash, monospaced: true)
                        
                        if let chain = event.chain {
                            DetailRow(label: "Event Number", value: "#\(chain.eventNumber)")
                            
                            DetailRow(label: "Previous Event", value: String(chain.previousEventHash.prefix(16)) + "...", monospaced: true)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Learn More", systemImage: "info.circle")
                            .font(.headline)
                        
                        Text("The verification code is a cryptographic hash that uniquely identifies this event and all its contents. Any change to the event would result in a completely different code, making tampering mathematically detectable.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(platformSecondaryBackground)
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Verification Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false
    
    private var platformSecondaryBackground: Color {
        #if os(iOS)
        return Color(.secondarySystemBackground)
        #else
        return Color(.controlBackgroundColor)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(platformSecondaryBackground)
        .cornerRadius(8)
    }
}

// ShareSheet is now in ShareSheet.swift for cross-platform support

#Preview {
    NavigationStack {
        EventDetailView(event: ForensicEvent(
            type: .meeting,
            title: "Performance Review Meeting",
            notes: "Met with manager to discuss recent performance. No specific issues were raised but timing is suspicious given recent safety report.",
            previousEvent: nil
        ))
    }
}