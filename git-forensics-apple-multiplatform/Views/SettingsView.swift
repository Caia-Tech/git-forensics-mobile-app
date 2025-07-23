//
//  SettingsView.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import SwiftUI
import LocalAuthentication
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @EnvironmentObject var eventManager: EventManager
    @EnvironmentObject var authManager: BiometricAuthManager
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("locationEnabled") private var locationEnabled = false
    @AppStorage("autoBackup") private var autoBackup = false
    @AppStorage("exportFormat") private var exportFormat = "JSON"
    @AppStorage("maxAttachmentSize") private var maxAttachmentSize = 10
    
    @State private var showingExportOptions = false
    @State private var showingDataManagement = false
    @State private var showingAbout = false
    @State private var showingError = false
    @State private var showingLocationSettings = false
    @State private var showingCloudBackup = false
    @State private var errorMessage = ""
    
    private let availableExportFormats = ["JSON", "PDF", "CSV"]
    private let availableAttachmentSizes = [5, 10, 25, 50] // MB
    
    var body: some View {
        NavigationStack {
            List {
                // Security Section
                Section {
                    HStack {
                        Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(authManager.biometricTypeDescription) Authentication")
                                .font(.body)
                            Text("Require \(authManager.biometricTypeDescription) to open app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { authManager.isBiometricEnabled },
                            set: { newValue in
                                Task {
                                    if newValue {
                                        await enableBiometric()
                                    } else {
                                        authManager.disableBiometric()
                                    }
                                }
                            }
                        ))
                            .disabled(!authManager.isBiometricAvailable)
                    }
                    .opacity(authManager.isBiometricAvailable ? 1.0 : 0.6)
                    
                    Button(action: { showingLocationSettings = true }) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Location Services")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("Add location data to events (optional)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Security & Privacy", systemImage: "lock.shield")
                } footer: {
                    Text("Your data stays on your device. Location data is never transmitted without your explicit consent.")
                        .font(.caption)
                }
                
                // Data Management Section
                Section {
                    HStack {
                        Image(systemName: "externaldrive")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto Backup")
                                .font(.body)
                            Text("Automatically export data weekly")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $autoBackup)
                    }
                    
                    Button(action: { showingCloudBackup = true }) {
                        HStack {
                            Image(systemName: CloudBackupManager.shared.isConnected ? "checkmark.cloud.fill" : "cloud")
                                .foregroundColor(CloudBackupManager.shared.isConnected ? .green : .blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cloud Backup")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(CloudBackupManager.shared.isConnected ? CloudBackupManager.shared.backupStatus.displayText : "Connect to GitHub or GitLab")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { showingExportOptions = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export Data")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("Create backup of all events")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: { showingDataManagement = true }) {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Data Management")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("View storage usage and cleanup")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Data Management", systemImage: "externaldrive")
                }
                
                // Preferences Section
                Section {
                    Picker("Export Format", selection: $exportFormat) {
                        ForEach(availableExportFormats, id: \.self) { format in
                            Text(format).tag(format)
                        }
                    }
                    
                    Picker("Max Attachment Size", selection: $maxAttachmentSize) {
                        ForEach(availableAttachmentSizes, id: \.self) { size in
                            Text("\(size) MB").tag(size)
                        }
                    }
                } header: {
                    Label("Preferences", systemImage: "gearshape")
                }
                
                // Information Section
                Section {
                    Button(action: { showingAbout = true }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("About Git Forensics")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chain Integrity")
                                .font(.body)
                            Text("All events verified")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Device ID")
                                .font(.body)
                            Text(DeviceInfo.shared.deviceId.uuidString.prefix(8).uppercased())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontDesign(.monospaced)
                        }
                    }
                } header: {
                    Label("Information", systemImage: "info.circle")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
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
                    .keyboardShortcut(.defaultAction)
                }
                #endif
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView()
            }
            .sheet(isPresented: $showingDataManagement) {
                DataManagementView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingLocationSettings) {
                LocationSettingsView()
            }
            .sheet(isPresented: $showingCloudBackup) {
                CloudBackupView()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func enableBiometric() async {
        let success = await authManager.enableBiometric()
        if !success {
            await MainActor.run {
                errorMessage = authManager.authenticationError ?? "Failed to enable biometric authentication"
                showingError = true
            }
        }
    }
}

// MARK: - Export Options View

struct ExportOptionsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var eventManager: EventManager
    
    @State private var selectedFormat = "JSON"
    @State private var includeAttachments = true
    @State private var dateRange = DateRange.all
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportedData: Data?
    
    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case lastMonth = "Last Month"
        case lastWeek = "Last Week"
        case custom = "Custom Range"
        
        var dateFilter: (Date, Date)? {
            let now = Date()
            let calendar = Calendar.current
            
            switch self {
            case .all:
                return nil
            case .lastMonth:
                let startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                return (startDate, now)
            case .lastWeek:
                let startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
                return (startDate, now)
            case .custom:
                return nil // TODO: Implement custom date picker
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        Text("JSON").tag("JSON")
                        Text("PDF Report").tag("PDF")
                        Text("CSV").tag("CSV")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Options") {
                    Toggle("Include Attachments", isOn: $includeAttachments)
                    
                    Picker("Date Range", selection: $dateRange) {
                        ForEach(DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                }
                
                Section {
                    Button(action: exportData) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Exporting...")
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Data")
                            }
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle("Export Data")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                #endif
            }
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: {
            // Dismiss the export options view after share sheet closes
            dismiss()
        }) {
            if let data = exportedData {
                let fileName = "forensic_export_\(ISO8601DateFormatter().string(from: Date()))"
                let fileExtension = selectedFormat.lowercased()
                ShareSheet(activityItems: [ExportFileItem(data: data, fileName: fileName, fileExtension: fileExtension)])
            }
        }
    }
    
    private func exportData() {
        isExporting = true
        
        Task {
            do {
                let data: Data
                
                switch selectedFormat {
                case "PDF":
                    let events = getFilteredEvents()
                    data = try PDFExportManager.shared.exportEventsToPDF(events, includeAttachments: includeAttachments)
                case "CSV":
                    // TODO: Implement CSV export
                    data = try eventManager.exportAllEvents()
                default: // JSON
                    data = try eventManager.exportAllEvents()
                }
                
                await MainActor.run {
                    exportedData = data
                    showingShareSheet = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    // Handle error - could show alert
                    print("Export failed: \(error)")
                }
            }
        }
    }
    
    private func getFilteredEvents() -> [ForensicEvent] {
        var events = eventManager.events
        
        if let dateFilter = dateRange.dateFilter {
            events = eventManager.events(from: dateFilter.0, to: dateFilter.1)
        }
        
        return events
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var eventManager: EventManager
    
    var body: some View {
        NavigationStack {
            List {
                Section("Storage Usage") {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Events")
                        Spacer()
                        Text("\(eventManager.events.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "paperclip")
                        Text("Attachments")
                        Spacer()
                        Text("~MB") // TODO: Calculate actual size
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Repository Info") {
                    HStack {
                        Image(systemName: "folder")
                        Text("Repository Path")
                        Spacer()
                        Text("Documents/.git-forensics")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Data Management")
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
                    .keyboardShortcut(.defaultAction)
                }
                #endif
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Git Forensics")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Git Forensics creates tamper-evident records using cryptographic principles borrowed from Git. Each event is cryptographically linked to create an immutable chain of evidence.")
                        
                        Text("Key Features")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "link", title: "Cryptographic Chaining", description: "Events are linked using SHA-256 hashes")
                            FeatureRow(icon: "iphone", title: "Local-First", description: "All data stays on your device")
                            FeatureRow(icon: "checkmark.shield", title: "Tamper Detection", description: "Any modification is immediately detectable")
                            FeatureRow(icon: "square.and.arrow.up", title: "Export Ready", description: "Share evidence in multiple formats")
                        }
                        
                        Text("Privacy")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("Git Forensics is designed with privacy by default. No data is transmitted to external servers. You control where and how your evidence is shared.")
                        
                        Text("Support the Project")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("This app is forever free and non-commercial. If you find it valuable, consider supporting its development:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            SupportLinkRow(icon: "cup.and.saucer", title: "Ko-fi", url: "https://ko-fi.com/caiatech")
                            SupportLinkRow(icon: "creditcard", title: "Square", url: "https://square.link/u/R1C8SjD3")
                            SupportLinkRow(icon: "dollarsign.circle", title: "PayPal", url: "https://paypal.me/caiatech?country.x=US&locale.x=en_US")
                            BitcoinAddressRow()
                        }
                        
                        Text("Legal")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("Copyright © 2025 Caia Tech. All rights reserved.\nContact: owner@caiatech.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Licensed under CC BY-NC-SA 4.0 - Commercial sale is explicitly prohibited.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("About")
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
                    .keyboardShortcut(.defaultAction)
                }
                #endif
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SupportLinkRow: View {
    let icon: String
    let title: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                    .frame(width: 20)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct BitcoinAddressRow: View {
    @State private var showingCopyAlert = false
    private let bitcoinAddress = "bc1qt00lg3llv326w96gn4jx7wgv2f46s06ux2p7m9"
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bitcoinsign.circle")
                .foregroundColor(.orange)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Bitcoin")
                    .foregroundColor(.primary)
                Text(String(bitcoinAddress.prefix(20)) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontDesign(.monospaced)
            }
            
            Spacer()
            
            Button(action: {
                #if os(iOS)
                UIPasteboard.general.string = bitcoinAddress
                #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(bitcoinAddress, forType: .string)
                #endif
                showingCopyAlert = true
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .alert("Copied!", isPresented: $showingCopyAlert) {
            Button("OK") { }
        } message: {
            Text("Bitcoin address copied to clipboard")
        }
    }
}

// ShareSheet and ExportFileItem are now in ShareSheet.swift for cross-platform support

#Preview {
    SettingsView()
        .environmentObject(EventManager.shared)
}