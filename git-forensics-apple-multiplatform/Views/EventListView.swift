//
//  EventListView.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import SwiftUI

struct EventListView: View {
    @EnvironmentObject var eventManager: EventManager
    let searchText: String
    
    var filteredEvents: [ForensicEvent] {
        if searchText.isEmpty {
            return eventManager.events
        } else {
            return eventManager.searchEvents(query: searchText)
        }
    }
    
    var body: some View {
        if eventManager.events.isEmpty && searchText.isEmpty {
            EmptyStateView()
        } else if filteredEvents.isEmpty {
            NoResultsView(searchText: searchText)
        } else {
            List {
                ForEach(filteredEvents) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        EventRowView(event: event)
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
    }
}

struct EventRowView: View {
    let event: ForensicEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with type and time
            HStack {
                Label(event.type.displayName, systemImage: event.type.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(event.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Title
            Text(event.title)
                .font(.headline)
                .lineLimit(2)
            
            // Notes preview
            if !event.notes.isEmpty {
                Text(event.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Status indicators
            HStack {
                Label("Verified", systemImage: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                
                if !event.attachments.isEmpty {
                    Label("\(event.attachments.count)", systemImage: "paperclip")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if event.location != nil {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Events Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first tamper-proof record\nby tapping the button below")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NoResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No events found matching '\(searchText)'")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        EventListView(searchText: "")
            .environmentObject(EventManager.shared)
    }
}