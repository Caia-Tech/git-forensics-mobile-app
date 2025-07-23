//
//  CloudBackupView.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import SwiftUI

struct CloudBackupView: View {
    @StateObject private var backupManager = CloudBackupManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showingProviderSelection = false
    @State private var showingDisconnectConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSyncing = false
    @State private var selectedProvider: CloudProvider?
    @State private var showingTokenSetup = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !backupManager.isConnected {
                        notConnectedView
                    } else {
                        connectedView
                    }
                }
                .padding()
            }
            .navigationTitle("Cloud Backup")
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
            .sheet(isPresented: $showingProviderSelection) {
                ProviderSelectionView(selectedProvider: $selectedProvider, showingTokenSetup: $showingTokenSetup)
            }
            .sheet(isPresented: $showingTokenSetup) {
                if let provider = selectedProvider {
                    GitHubTokenSetupView(provider: provider)
                }
            }
            .alert("Disconnect Cloud Backup?", isPresented: $showingDisconnectConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    backupManager.disconnect()
                }
            } message: {
                Text("Your records will remain on this device, but will no longer be backed up to the cloud.")
            }
            .alert("Backup Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Not Connected View
    
    private var notConnectedView: some View {
        VStack(spacing: 30) {
            // Hero illustration
            VStack(spacing: 15) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Secure Cloud Backup")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Automatically backup your forensic records to the cloud. Your data is always private and encrypted.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Benefits
            VStack(alignment: .leading, spacing: 15) {
                BenefitRow(
                    icon: "lock.shield",
                    title: "Private & Secure",
                    description: "Your backup is private by default. Only you can access it."
                )
                
                BenefitRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Automatic Sync",
                    description: "Records backup automatically after each event."
                )
                
                BenefitRow(
                    icon: "link",
                    title: "Share Evidence",
                    description: "Generate secure links to share with lawyers or investigators."
                )
                
                BenefitRow(
                    icon: "checkmark.shield",
                    title: "Tamper-Proof",
                    description: "Cryptographic verification ensures records haven't been altered."
                )
            }
            .padding(.vertical)
            
            // Connect button
            Button(action: { showingProviderSelection = true }) {
                HStack {
                    Image(systemName: "cloud")
                    Text("Connect Cloud Backup")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Connected View
    
    private var connectedView: some View {
        VStack(spacing: 20) {
            // Status card
            BackupStatusCard(
                status: backupManager.backupStatus,
                provider: backupManager.currentProvider,
                repositoryName: backupManager.repositoryName
            )
            
            // Quick actions
            HStack(spacing: 15) {
                Button(action: syncNow) {
                    Label("Sync Now", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isSyncing)
                
                Button(action: shareEvidence) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            // Settings
            VStack(spacing: 0) {
                SettingRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Auto-sync",
                    toggle: $backupManager.autoSync
                )
                
                Divider()
                
                SettingRow(
                    icon: "paperclip",
                    title: "Include attachments",
                    subtitle: "May use more storage",
                    toggle: $backupManager.includeAttachments
                )
                
                Divider()
                
                Button(action: viewRepository) {
                    HStack {
                        Image(systemName: "arrow.up.forward.app")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("View in \(backupManager.currentProvider?.displayName ?? "Browser")")
                                .foregroundColor(.primary)
                            Text(backupManager.repositoryURL)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)
            }
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
            
            // Disconnect button
            Button(action: { showingDisconnectConfirmation = true }) {
                Text("Disconnect")
                    .foregroundColor(.red)
            }
            .padding(.top)
        }
    }
    
    // MARK: - Actions
    
    private func syncNow() {
        isSyncing = true
        Task {
            do {
                try await backupManager.syncNow()
                isSyncing = false
            } catch {
                isSyncing = false
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func shareEvidence() {
        // TODO: Implement share evidence flow
    }
    
    private func viewRepository() {
        if let url = URL(string: backupManager.repositoryURL) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #else
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}

// MARK: - Provider Selection View

struct ProviderSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedProvider: CloudProvider?
    @Binding var showingTokenSetup: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Choose a backup service")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(spacing: 15) {
                    ForEach(CloudProvider.allCases, id: \.self) { provider in
                        ProviderButton(
                            provider: provider,
                            isSelected: false,
                            action: { selectProvider(provider) }
                        )
                    }
                }
                .padding()
                
                // Helpful tip
                VStack(spacing: 10) {
                    Label("Tip", systemImage: "lightbulb")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    Text("Both services are free to use. GitHub is more popular, while GitLab offers additional privacy features.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Select Provider")
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
    }
    
    private func selectProvider(_ provider: CloudProvider) {
        selectedProvider = provider
        dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingTokenSetup = true
        }
    }
}

// MARK: - Supporting Views

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct BackupStatusCard: View {
    let status: BackupStatus
    let provider: CloudProvider?
    let repositoryName: String
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: status.icon)
                    .font(.title)
                    .foregroundColor(status.iconColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.displayText)
                        .font(.headline)
                    if let provider = provider {
                        Text("Connected to \(provider.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if case .syncing(let progress) = status {
                ProgressView(value: progress)
                    .tint(.blue)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ProviderButton: View {
    let provider: CloudProvider
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: provider.icon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.headline)
                    Text(provider == .github ? "Most popular choice" : "Privacy-focused alternative")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @Binding var toggle: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $toggle)
                .labelsHidden()
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Not Connected") {
    CloudBackupView()
}

#Preview("Connected") {
    let manager = CloudBackupManager.shared
    manager.isConnected = true
    manager.currentProvider = .github
    manager.backupStatus = .synced(lastSync: Date())
    manager.repositoryName = "forensic-records-iphone-2025-01-23"
    manager.repositoryURL = "https://github.com/user/forensic-records-iphone-2025-01-23"
    
    return CloudBackupView()
}