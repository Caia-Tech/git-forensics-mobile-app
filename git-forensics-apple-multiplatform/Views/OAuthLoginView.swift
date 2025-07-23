//
//  OAuthLoginView.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import SwiftUI
import AuthenticationServices

struct OAuthLoginView: View {
    let provider: CloudProvider
    @Environment(\.dismiss) var dismiss
    @StateObject private var backupManager = CloudBackupManager.shared
    
    @State private var isAuthenticating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingHelp = false
    @State private var currentStep = 1
    @State private var authCode = ""
    @State private var showingManualEntry = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: provider.icon)
                            .font(.system(size: 60))
                            .foregroundColor(provider == .github ? .black : .orange)
                        
                        Text("Connect to \(provider.displayName)")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("We'll help you connect your \(provider.displayName) account to automatically backup your forensic records.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // Step indicator
                    StepIndicator(currentStep: currentStep, totalSteps: 3)
                        .padding(.horizontal)
                    
                    // Main content based on step
                    Group {
                        if currentStep == 1 {
                            stepOneView
                        } else if currentStep == 2 {
                            stepTwoView
                        } else {
                            stepThreeView
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                    Spacer(minLength: 50)
                }
                .animation(.easeInOut, value: currentStep)
            }
            .navigationTitle("Secure Connection")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isAuthenticating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingHelp = true }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isAuthenticating)
                    .keyboardShortcut(.cancelAction)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingHelp = true }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingHelp) {
                HelpView(provider: provider)
            }
            .alert("Connection Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Step 1: Introduction
    
    private var stepOneView: some View {
        VStack(spacing: 25) {
            // What will happen
            VStack(alignment: .leading, spacing: 20) {
                Text("What happens next:")
                    .font(.headline)
                
                InfoRow(
                    number: "1",
                    icon: "safari",
                    title: "Open \(provider.displayName)",
                    description: "We'll open your browser to sign in securely"
                )
                
                InfoRow(
                    number: "2",
                    icon: "key.horizontal",
                    title: "Authorize App",
                    description: "Grant permission for Git Forensics to create backups"
                )
                
                InfoRow(
                    number: "3",
                    icon: "checkmark.shield",
                    title: "Start Backing Up",
                    description: "Your records will automatically save to the cloud"
                )
            }
            .padding(.horizontal)
            
            // Privacy note
            VStack(spacing: 10) {
                Label("Your Privacy Matters", systemImage: "lock.shield")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text("We only request permission to create and update a single private repository for your backups. We cannot access your other repositories or personal data.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Continue button
            Button(action: { currentStep = 2 }) {
                Label("Continue", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Step 2: Authentication
    
    private var stepTwoView: some View {
        VStack(spacing: 25) {
            if !isAuthenticating {
                // Instructions
                VStack(spacing: 15) {
                    Image(systemName: "safari")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Ready to connect?")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Click the button below to open \(provider.displayName) in your browser. After you sign in and authorize the app, you'll be redirected back here automatically.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // OAuth button
                Button(action: startOAuthFlow) {
                    HStack {
                        Image(systemName: provider.icon)
                        Text("Sign in with \(provider.displayName)")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(provider == .github ? Color.black : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Manual entry option
                Button(action: { showingManualEntry = true }) {
                    Text("Having trouble? Enter code manually")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .sheet(isPresented: $showingManualEntry) {
                    ManualCodeEntryView(authCode: $authCode) {
                        handleManualCode()
                    }
                }
            } else {
                // Authenticating state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    
                    Text("Connecting to \(provider.displayName)...")
                        .font(.headline)
                    
                    Text("This may take a moment. Please complete the authorization in your browser.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Tips while waiting
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Tip", systemImage: "lightbulb")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text("Make sure to click 'Authorize' in your browser when prompted. This allows Git Forensics to create a private backup repository.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Step 3: Success
    
    private var stepThreeView: some View {
        VStack(spacing: 25) {
            // Success animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .scaleEffect(1.2)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: currentStep)
            
            Text("You're all set!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your forensic records will now be automatically backed up to \(provider.displayName) after each event.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // What's next
            VStack(alignment: .leading, spacing: 15) {
                Text("What happens now:")
                    .font(.headline)
                
                HStack(alignment: .top, spacing: 15) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatic Backups")
                            .fontWeight(.medium)
                        Text("Every new event is backed up instantly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 15) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Private & Secure")
                            .fontWeight(.medium)
                        Text("Only you can access your backup repository")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 15) {
                    Image(systemName: "link")
                        .foregroundColor(.purple)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Share When Ready")
                            .fontWeight(.medium)
                        Text("Generate secure links for lawyers or investigators")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Done button
            Button(action: { dismiss() }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Actions
    
    private func startOAuthFlow() {
        isAuthenticating = true
        
        Task {
            do {
                // In a real implementation, this would:
                // 1. Generate PKCE challenge
                // 2. Open ASWebAuthenticationSession
                // 3. Handle callback with authorization code
                // 4. Exchange code for access token
                
                try await simulateOAuthFlow()
                
                await MainActor.run {
                    currentStep = 3
                    isAuthenticating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to connect: \(error.localizedDescription)"
                    showingError = true
                    isAuthenticating = false
                }
            }
        }
    }
    
    private func simulateOAuthFlow() async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // In real implementation, this would handle the OAuth flow
        try await backupManager.connectProvider(provider)
    }
    
    private func handleManualCode() {
        // Handle manual code entry
        showingManualEntry = false
        currentStep = 3
    }
}

// MARK: - Supporting Views

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .frame(height: 8)
    }
}

struct InfoRow: View {
    let number: String
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 30, height: 30)
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ManualCodeEntryView: View {
    @Binding var authCode: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "key.horizontal")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                    .padding()
                
                Text("Enter Authorization Code")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("If the automatic connection didn't work, you can enter the authorization code manually. You'll find this code on the authorization page.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("Authorization Code", text: $authCode)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .autocapitalization(.none)
                    #endif
                    .padding(.horizontal)
                
                Button(action: {
                    onSubmit()
                    dismiss()
                }) {
                    Text("Connect")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(authCode.isEmpty)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Manual Entry")
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
}

struct HelpView: View {
    let provider: CloudProvider
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Why connect?
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Why connect to \(provider.displayName)?", systemImage: "questionmark.circle")
                            .font(.headline)
                        
                        Text("Connecting to \(provider.displayName) provides a secure, off-device backup of your forensic records. This ensures your evidence is preserved even if something happens to your device.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(10)
                    
                    // What permissions?
                    VStack(alignment: .leading, spacing: 10) {
                        Label("What permissions are needed?", systemImage: "key")
                            .font(.headline)
                        
                        Text("Git Forensics only requests permission to:")
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Text("•")
                                Text("Create one private repository for your backups")
                            }
                            HStack(alignment: .top) {
                                Text("•")
                                Text("Read and write to that repository only")
                            }
                        }
                        .padding(.leading)
                        
                        Text("We cannot access your other repositories, profile, or personal information.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(10)
                    
                    // Troubleshooting
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Troubleshooting", systemImage: "wrench.and.screwdriver")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            TroubleshootingItem(
                                title: "Browser didn't open",
                                solution: "Try using the manual code entry option"
                            )
                            
                            TroubleshootingItem(
                                title: "Authorization failed",
                                solution: "Make sure you're logged into the correct \(provider.displayName) account"
                            )
                            
                            TroubleshootingItem(
                                title: "Connection timed out",
                                solution: "Check your internet connection and try again"
                            )
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(10)
                    
                    // Contact support
                    VStack(spacing: 10) {
                        Label("Need more help?", systemImage: "envelope")
                            .font(.headline)
                        
                        Text("Contact us at owner@caiatech.com")
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Help")
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

struct TroubleshootingItem: View {
    let title: String
    let solution: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .fontWeight(.medium)
            Text(solution)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    OAuthLoginView(provider: .github)
}