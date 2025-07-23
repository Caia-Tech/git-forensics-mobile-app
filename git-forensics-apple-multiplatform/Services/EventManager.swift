//
//  EventManager.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation
import Combine

@MainActor
class EventManager: ObservableObject {
    static let shared = EventManager()
    
    @Published private(set) var events: [ForensicEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let gitManager = SimpleGitManager.shared
    private var lastEvent: ForensicEvent?
    
    private init() {
        Task {
            await initialize()
        }
    }
    
    /// Initialize the event manager and Git repository
    func initialize() async {
        do {
            isLoading = true
            
            // Initialize Git repository
            try gitManager.initializeRepository()
            
            // Load existing events
            await loadEvents()
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
            print("Failed to initialize EventManager: \(error)")
        }
    }
    
    /// Create a new forensic event
    func createEvent(
        type: EventType,
        title: String,
        notes: String,
        attachments: [EventAttachment] = [],
        location: EventLocation? = nil
    ) async throws -> ForensicEvent {
        // Validate input
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EventError.invalidTitle
        }
        
        guard title.count <= 200 else {
            throw EventError.titleTooLong
        }
        
        guard notes.count <= 10000 else {
            throw EventError.notesTooLong
        }
        
        // Create event with chain reference to previous event
        var event = ForensicEvent(
            type: type,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            attachments: attachments,
            location: location,
            previousEvent: lastEvent
        )
        
        // Calculate content hash
        let contentHash = CryptoUtils.calculateEventHash(event)
        
        // Update event with calculated hash
        event.integrity = EventIntegrity(contentHash: contentHash, signature: nil)
        
        // Save to Git repository
        try gitManager.saveEvent(event)
        
        // Update local state
        events.insert(event, at: 0)
        lastEvent = event
        
        // Trigger cloud backup if enabled
        await CloudBackupManager.shared.handleEventCreated(event)
        
        return event
    }
    
    /// Load all events from the repository
    func loadEvents() async {
        do {
            let loadedEvents = try gitManager.loadAllEvents()
            
            // Verify chain integrity
            let (isValid, error) = CryptoUtils.verifyEventChain(loadedEvents)
            
            if !isValid {
                print("Warning: Event chain verification failed: \(error ?? "Unknown error")")
                // In production, we might want to handle this differently
            }
            
            events = loadedEvents
            
            // Find the most recent event for chain linking
            lastEvent = loadedEvents.first
        } catch {
            self.error = error
            print("Failed to load events: \(error)")
        }
    }
    
    /// Search events by text
    func searchEvents(query: String) -> [ForensicEvent] {
        guard !query.isEmpty else { return events }
        
        let lowercasedQuery = query.lowercased()
        
        return events.filter { event in
            event.title.lowercased().contains(lowercasedQuery) ||
            event.notes.lowercased().contains(lowercasedQuery) ||
            event.type.displayName.lowercased().contains(lowercasedQuery)
        }
    }
    
    /// Get events filtered by type
    func events(ofType type: EventType) -> [ForensicEvent] {
        events.filter { $0.type == type }
    }
    
    /// Get events within a date range
    func events(from startDate: Date, to endDate: Date) -> [ForensicEvent] {
        events.filter { event in
            event.createdAt >= startDate && event.createdAt <= endDate
        }
    }
    
    /// Export a single event as JSON
    func exportEvent(_ event: ForensicEvent) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(event)
    }
    
    /// Export all events as a bundle
    func exportAllEvents() throws -> Data {
        let exportData = EventExportBundle(
            version: "1.0",
            exportDate: Date(),
            deviceId: DeviceInfo.shared.deviceId,
            events: events,
            verificationInfo: VerificationInfo(
                chainValid: CryptoUtils.verifyEventChain(events).isValid,
                eventCount: events.count,
                dateRange: events.isEmpty ? nil : DateRange(
                    start: events.last?.createdAt ?? Date(),
                    end: events.first?.createdAt ?? Date()
                )
            )
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(exportData)
    }
}

// MARK: - Supporting Types

enum EventError: LocalizedError {
    case invalidTitle
    case titleTooLong
    case notesTooLong
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidTitle:
            return "Please enter a title for your event"
        case .titleTooLong:
            return "Title must be less than 200 characters"
        case .notesTooLong:
            return "Notes must be less than 10,000 characters"
        case .saveFailed:
            return "Failed to save event"
        }
    }
}

struct EventExportBundle: Codable {
    let version: String
    let exportDate: Date
    let deviceId: UUID
    let events: [ForensicEvent]
    let verificationInfo: VerificationInfo
}

struct VerificationInfo: Codable {
    let chainValid: Bool
    let eventCount: Int
    let dateRange: DateRange?
}

struct DateRange: Codable {
    let start: Date
    let end: Date
}