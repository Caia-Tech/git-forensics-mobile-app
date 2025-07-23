//
//  GitHubTokenSetupView.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import SwiftUI

struct GitHubTokenSetupView: View {
    let provider: CloudProvider
    @Environment(\.dismiss) var dismiss
    @StateObject private var backupManager = CloudBackupManager.shared
    
    @State private var token = ""
    @State private var isConnecting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingInstructions = true
    @State private var currentStep = 1
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: provider.icon)
                            .font(.system(size: 60))
                            .foregroundColor(provider == .github ? .black : .orange)
                        
                        Text("Connect to \(provider.displayName)")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Set up secure backup using a Personal Access Token")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    if showingInstructions {
                        instructionsView
                    } else {
                        tokenInputView
                    }
                    
                    Spacer(minLength: 50)
                }
                .animation(.easeInOut, value: showingInstructions)
            }
            .navigationTitle("Setup GitHub Backup")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isConnecting)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isConnecting)
                    .keyboardShortcut(.cancelAction)
                }
                #endif
            }
            .alert("Connection Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Instructions View
    
    private var instructionsView: some View {
        VStack(spacing: 25) {
            // Step indicator
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    if step < 3 {
                        Rectangle()
                            .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            .frame(height: 8)
            .padding(.horizontal)
            
            // Instructions
            VStack(alignment: .leading, spacing: 20) {
                Text("To connect GitHub, you'll need a Personal Access Token:")
                    .font(.headline)
                
                InstructionStep(
                    number: "1",
                    title: "Go to GitHub Settings",
                    description: "Visit github.com → Settings → Developer settings → Personal access tokens → Tokens (classic)"
                )
                
                InstructionStep(
                    number: "2",
                    title: "Generate New Token",
                    description: "Click 'Generate new token (classic)' and give it a descriptive name like 'Git Forensics Mobile'"
                )
                
                InstructionStep(
                    number: "3",
                    title: "Select Permissions",
                    description: "Enable these scopes: repo (Full control of private repositories)"
                )
                
                InstructionStep(
                    number: "4",
                    title: "Copy Token",
                    description: "Copy the generated token (it starts with 'ghp_') and paste it below"
                )
            }
            .padding(.horizontal)
            
            // Security note
            VStack(spacing: 10) {
                Label("Security Notice", systemImage: "lock.shield")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text("Your token is stored securely in the device keychain and never shared with anyone. You can revoke it anytime from GitHub settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Continue button
            Button(action: { 
                withAnimation {
                    showingInstructions = false
                    currentStep = 2
                }
            }) {
                Label("I have my token", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            // Quick link button
            Button(action: openGitHubSettings) {
                Text("Open GitHub Settings")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Token Input View
    
    private var tokenInputView: some View {
        VStack(spacing: 25) {
            if !isConnecting {
                VStack(spacing: 15) {
                    Image(systemName: "key.horizontal")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Enter your Personal Access Token")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Paste the token you copied from GitHub. It should start with 'ghp_'.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Token input
                VStack(alignment: .leading, spacing: 8) {
                    Text("GitHub Personal Access Token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("ghp_...", text: $token)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.horizontal)
                
                // Connect button
                Button(action: connectWithToken) {
                    Text("Connect to GitHub")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(token.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(token.isEmpty)
                .padding(.horizontal)
                
                // Back button
                Button(action: { 
                    withAnimation {
                        showingInstructions = true
                        currentStep = 1
                    }
                }) {
                    Text("Back to instructions")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
            } else {
                // Connecting state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    
                    Text("Connecting to GitHub...")
                        .font(.headline)
                    
                    Text("Validating your token and setting up the backup repository.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func openGitHubSettings() {
        let url = URL(string: "https://github.com/settings/tokens")!
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
    
    private func connectWithToken() {
        guard !token.isEmpty else { return }
        
        isConnecting = true
        
        Task {
            do {
                try await backupManager.connectWithToken(token, provider: provider)
                
                await MainActor.run {
                    isConnecting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isConnecting = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InstructionStep: View {
    let number: String
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

#Preview {
    GitHubTokenSetupView(provider: .github)
}