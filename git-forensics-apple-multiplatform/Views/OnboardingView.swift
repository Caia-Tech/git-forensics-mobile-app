//
//  OnboardingView.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var authManager = BiometricAuthManager.shared
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var currentPage = 0
    @State private var showingPermissions = false
    
    let onComplete: () -> Void
    
    private let pages = OnboardingPage.allPages
    
    private var platformBackgroundColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(.controlBackgroundColor)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentPage ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            #endif
            .animation(.easeInOut, value: currentPage)
            
            // Navigation buttons
            VStack(spacing: 16) {
                if currentPage == pages.count - 1 {
                    // Final page - Setup buttons
                    VStack(spacing: 12) {
                        Button(action: setupBiometric) {
                            HStack {
                                Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                                Text("Enable \(authManager.biometricTypeDescription)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(authManager.isBiometricAvailable ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!authManager.isBiometricAvailable)
                        
                        Button(action: setupLocation) {
                            HStack {
                                Image(systemName: "location")
                                Text("Enable Location Services")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: completeOnboarding) {
                            Text("Get Started")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Button("Skip Setup") {
                            completeOnboarding()
                        }
                        .foregroundColor(.secondary)
                    }
                } else {
                    // Regular navigation
                    HStack {
                        if currentPage > 0 {
                            Button("Back") {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(currentPage == pages.count - 2 ? "Setup" : "Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
        .background(platformBackgroundColor)
    }
    
    private func setupBiometric() {
        Task {
            await authManager.enableBiometric()
        }
    }
    
    private func setupLocation() {
        locationManager.enableLocation()
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        onComplete()
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.color)
            
            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            // Feature highlights
            if !page.features.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(page.features, id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(feature)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let features: [String]
    
    static let allPages = [
        OnboardingPage(
            title: "Welcome to Git Forensics",
            description: "Create tamper-evident documentation that can't be altered without detection. Perfect for maintaining an unbreakable record of important events.",
            icon: "shield.lefthalf.filled",
            color: .blue,
            features: [
                "Military-grade cryptographic security",
                "Complete privacy - data never leaves your device",
                "Instant tamper detection",
                "Professional evidence formatting"
            ]
        ),
        
        OnboardingPage(
            title: "How It Works",
            description: "Each event is cryptographically linked to create an unbreakable chain. Like blockchain, but for your personal evidence.",
            icon: "link",
            color: .purple,
            features: [
                "SHA-256 hashing prevents tampering",
                "Chain linking detects any alterations",
                "Attachments are cryptographically verified",
                "Export ready for legal proceedings"
            ]
        ),
        
        OnboardingPage(
            title: "Your Privacy Matters",
            description: "Unlike other apps, Git Forensics keeps everything local. No servers, no cloud, no data collection.",
            icon: "hand.raised.fill",
            color: .green,
            features: [
                "No internet connection required",
                "You control where data is shared",
                "No tracking or analytics",
                "Open source transparency"
            ]
        ),
        
        OnboardingPage(
            title: "Powerful Features",
            description: "Attach photos, documents, and location data. Export as PDF reports with QR code verification.",
            icon: "star.fill",
            color: .orange,
            features: [
                "Photo and document attachments",
                "Optional GPS coordinates",
                "PDF reports with QR verification",
                "Multiple export formats"
            ]
        ),
        
        OnboardingPage(
            title: "Ready to Begin?",
            description: "Let's set up some optional features to enhance your experience. You can always change these later in Settings.",
            icon: "gearshape.fill",
            color: .indigo,
            features: []
        )
    ]
}

// MARK: - Onboarding Wrapper

struct OnboardingWrapper<Content: View>: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                content()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
}