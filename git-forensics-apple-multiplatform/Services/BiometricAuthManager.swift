//
//  BiometricAuthManager.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    @Published var isAuthenticated = false
    @Published var authenticationError: String?
    @Published var isAuthenticating = false
    
    @AppStorage("biometricEnabled") private var biometricEnabled = false
    
    private init() {}
    
    /// Check if biometric authentication is available on this device
    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Get the type of biometric authentication available
    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        return context.biometryType
    }
    
    /// Human-readable description of available biometric type
    var biometricTypeDescription: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        @unknown default:
            return "Biometric Authentication"
        }
    }
    
    /// Check if the app should require authentication
    var shouldRequireAuthentication: Bool {
        return biometricEnabled && isBiometricAvailable && !isAuthenticated
    }
    
    /// Authenticate the user using biometrics
    func authenticate(reason: String = "Access your forensic evidence") async -> Bool {
        guard biometricEnabled && isBiometricAvailable else {
            isAuthenticated = true
            return true
        }
        
        isAuthenticating = true
        authenticationError = nil
        
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            isAuthenticated = success
            isAuthenticating = false
            
            if success {
                // Log successful authentication
                logAuthenticationEvent(success: true)
            }
            
            return success
        } catch {
            isAuthenticated = false
            isAuthenticating = false
            authenticationError = error.localizedDescription
            
            // Log failed authentication
            logAuthenticationEvent(success: false, error: error)
            
            // Handle specific errors
            if let laError = error as? LAError {
                switch laError.code {
                case .userCancel:
                    authenticationError = "Authentication was cancelled"
                case .userFallback:
                    // User chose to use passcode instead
                    return await authenticateWithPasscode(reason: reason)
                case .biometryNotAvailable:
                    authenticationError = "\(biometricTypeDescription) is not available"
                case .biometryNotEnrolled:
                    authenticationError = "\(biometricTypeDescription) is not set up"
                case .biometryLockout:
                    authenticationError = "\(biometricTypeDescription) is locked. Use passcode to unlock."
                    return await authenticateWithPasscode(reason: reason)
                default:
                    authenticationError = "Authentication failed: \(error.localizedDescription)"
                }
            }
            
            return false
        }
    }
    
    /// Authenticate using device passcode as fallback
    private func authenticateWithPasscode(reason: String) async -> Bool {
        let context = LAContext()
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            isAuthenticated = success
            if success {
                logAuthenticationEvent(success: true, method: "passcode")
            }
            
            return success
        } catch {
            authenticationError = "Passcode authentication failed: \(error.localizedDescription)"
            logAuthenticationEvent(success: false, error: error, method: "passcode")
            return false
        }
    }
    
    /// Enable biometric authentication
    func enableBiometric() async -> Bool {
        guard isBiometricAvailable else {
            authenticationError = "\(biometricTypeDescription) is not available on this device"
            return false
        }
        
        // Test authentication before enabling
        let success = await authenticate(reason: "Enable \(biometricTypeDescription) for Git Forensics")
        
        if success {
            biometricEnabled = true
            logAuthenticationEvent(success: true, method: "enable")
        }
        
        return success
    }
    
    /// Disable biometric authentication
    func disableBiometric() {
        biometricEnabled = false
        isAuthenticated = true // Don't require auth if disabled
        logAuthenticationEvent(success: true, method: "disable")
    }
    
    /// Check if biometric is enabled in settings
    var isBiometricEnabled: Bool {
        biometricEnabled
    }
    
    /// Reset authentication state (for app background/foreground)
    func resetAuthenticationState() {
        if biometricEnabled {
            isAuthenticated = false
        }
    }
    
    /// Log authentication events for audit trail
    private func logAuthenticationEvent(success: Bool, error: Error? = nil, method: String = "biometric") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let deviceId = DeviceInfo.shared.deviceId.uuidString.prefix(8)
        
        var logEntry = [
            "timestamp": timestamp,
            "device": String(deviceId),
            "method": method,
            "success": success,
            "biometricType": biometricTypeDescription
        ] as [String: Any]
        
        if let error = error {
            logEntry["error"] = error.localizedDescription
            if let laError = error as? LAError {
                logEntry["errorCode"] = laError.code.rawValue
            }
        }
        
        // In a production app, you might want to store these logs securely
        // For now, we'll just print them for debugging
        print("Auth Event: \(logEntry)")
    }
}

// MARK: - Authentication View

struct AuthenticationView: View {
    @StateObject private var authManager = BiometricAuthManager.shared
    @State private var showingError = false
    
    let onAuthenticated: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Git Forensics")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Secure Evidence Documentation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                if authManager.isAuthenticating {
                    ProgressView("Authenticating...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Button(action: authenticateUser) {
                        HStack {
                            Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                            Text("Authenticate with \(authManager.biometricTypeDescription)")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(authManager.isAuthenticating)
                }
                
                if let error = authManager.authenticationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    Text("Your data is encrypted and stored locally")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "icloud.slash")
                        .foregroundColor(.blue)
                    Text("No data is sent to external servers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 32)
        }
        .padding()
        .onAppear {
            // Auto-trigger authentication when view appears
            Task {
                await authenticateUser()
            }
        }
    }
    
    private func authenticateUser() {
        Task {
            let success = await authManager.authenticate()
            if success {
                onAuthenticated()
            }
        }
    }
}

#Preview {
    AuthenticationView {
        print("Authenticated!")
    }
}