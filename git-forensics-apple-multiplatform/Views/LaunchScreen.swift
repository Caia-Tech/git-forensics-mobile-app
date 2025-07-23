//
//  LaunchScreen.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import SwiftUI

struct LaunchScreen: View {
    @State private var isAnimating = false
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App icon
                ZStack {
                    // Background circle
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    // Shield icon
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                
                // App title
                VStack(spacing: 8) {
                    Text("Git Forensics")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(opacity)
                    
                    Text("Tamper-Evident Documentation")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .opacity(opacity)
                }
                
                // Loading indicator
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .opacity(opacity)
                    
                    Text("Initializing secure storage...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                opacity = 1.0
            }
            
            withAnimation(.easeInOut(duration: 1.0).delay(0.3)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - App Icon Generator View (for development)

struct AppIconGeneratorView: View {
    let size: CGFloat
    
    init(size: CGFloat = 1024) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Shield icon
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: size * 0.6))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: size * 0.01, x: 0, y: size * 0.01)
        }
        .frame(width: size, height: size)
        .cornerRadius(size * 0.2237) // iOS app icon corner radius ratio
    }
}

#Preview("Launch Screen") {
    LaunchScreen()
}

#Preview("App Icon 1024") {
    AppIconGeneratorView(size: 1024)
}

#Preview("App Icon 180") {
    AppIconGeneratorView(size: 180)
}