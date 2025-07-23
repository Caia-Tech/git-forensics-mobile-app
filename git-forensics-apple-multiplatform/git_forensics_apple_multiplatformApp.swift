//
//  git_forensics_apple_multiplatformApp.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//
//  Main application entry point
//

import SwiftUI

@main
struct git_forensics_apple_multiplatformApp: App {
    @StateObject private var eventManager = EventManager.shared
    @StateObject private var authManager = BiometricAuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(eventManager)
                .environmentObject(authManager)
        }
    }
}
