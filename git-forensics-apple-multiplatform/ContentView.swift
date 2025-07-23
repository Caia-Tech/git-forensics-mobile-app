//
//  ContentView.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//
//  Main content view with all UI components
//

import SwiftUI
import Foundation

// MARK: - Views
// Note: Using full-featured implementations from other files

struct ContentView: View {
    @EnvironmentObject var eventManager: EventManager
    @State private var showingCreateEvent = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            } else {
                mainContent
            }
        }
    }
    
    var mainContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if eventManager.isLoading && eventManager.events.isEmpty {
                    ProgressView("Setting up secure storage...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EventListView(searchText: searchText)
                }
            }
            .navigationTitle("Your Events")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .searchable(text: $searchText, prompt: "Search events")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.headline)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateEvent = true }) {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                }
                #else
                ToolbarItem(placement: .navigation) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.headline)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingCreateEvent = true }) {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                }
                #endif
            }
            .overlay(alignment: .bottom) {
                if !eventManager.isLoading {
                    CreateEventButton(showingCreateEvent: $showingCreateEvent)
                        .padding()
                }
            }
            .sheet(isPresented: $showingCreateEvent) {
                CreateEventView()
                    .environmentObject(eventManager)
                    .environmentObject(BiometricAuthManager.shared)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(eventManager)
                    .environmentObject(BiometricAuthManager.shared)
            }
        }
    }
}

// EventListView moved to Views/EventListView.swift

// EventRowView moved to Views/EventListView.swift

// EmptyStateView moved to Views/EventListView.swift

// Removed simplified CreateEventView - using full-featured version from Views/CreateEventView.swift

// Removed simplified SettingsView - using full-featured version from Views/SettingsView.swift

struct CreateEventButton: View {
    @Binding var showingCreateEvent: Bool
    
    var body: some View {
        Button(action: { showingCreateEvent = true }) {
            Label("Create Event", systemImage: "plus")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(12)
                .shadow(radius: 4)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(EventManager.shared)
        .environmentObject(BiometricAuthManager.shared)
}
