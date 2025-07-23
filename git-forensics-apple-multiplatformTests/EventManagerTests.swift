//
//  EventManagerTests.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import XCTest
@testable import git_forensics_apple_multiplatform
import Foundation

@MainActor
final class EventManagerTests: XCTestCase {
    
    var eventManager: EventManager!
    var testRepository: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary directory for testing
        testRepository = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-repo-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: testRepository, withIntermediateDirectories: true)
        
        // Create a fresh EventManager instance for testing
        eventManager = EventManager()
    }
    
    override func tearDown() async throws {
        // Clean up test repository
        if FileManager.default.fileExists(atPath: testRepository.path) {
            try FileManager.default.removeItem(at: testRepository)
        }
        
        eventManager = nil
        testRepository = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testEventManagerInitialization() async throws {
        XCTAssertNotNil(eventManager)
        XCTAssertTrue(eventManager.events.isEmpty)
        XCTAssertFalse(eventManager.isLoading)
        XCTAssertNil(eventManager.error)
    }
    
    func testEventManagerInitialize() async throws {
        // Initialize should complete without error
        await eventManager.initialize()
        
        XCTAssertFalse(eventManager.isLoading)
        XCTAssertNil(eventManager.error)
    }
    
    // MARK: - Event Creation Tests
    
    func testCreateBasicEvent() async throws {
        await eventManager.initialize()
        
        let event = try await eventManager.createEvent(
            type: .general,
            title: "Test Event",
            notes: "Test notes"
        )
        
        XCTAssertEqual(event.type, .general)
        XCTAssertEqual(event.title, "Test Event")
        XCTAssertEqual(event.notes, "Test notes")
        XCTAssertNotNil(event.id)
        XCTAssertFalse(event.integrity.contentHash.isEmpty)
        
        // Check that event was added to manager
        XCTAssertEqual(eventManager.events.count, 1)
        XCTAssertEqual(eventManager.events.first?.id, event.id)
    }
    
    func testCreateEventWithAttachments() async throws {
        await eventManager.initialize()
        
        let attachment = EventAttachment(
            filename: "test.jpg",
            mimeType: "image/jpeg",
            sizeBytes: 1024,
            hashSHA256: "testhash",
            storagePath: "path/to/file"
        )
        
        let event = try await eventManager.createEvent(
            type: .incident,
            title: "Event with attachment",
            notes: "Has attachment",
            attachments: [attachment]
        )
        
        XCTAssertEqual(event.attachments.count, 1)
        XCTAssertEqual(event.attachments.first?.filename, "test.jpg")
        XCTAssertEqual(eventManager.events.count, 1)
    }
    
    func testCreateEventWithLocation() async throws {
        await eventManager.initialize()
        
        let location = EventLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            accuracyMeters: 5.0,
            altitudeMeters: nil,
            altitudeAccuracyMeters: nil,
            headingDegrees: nil,
            speedMPS: nil,
            capturedAt: Date(),
            source: .gps,
            address: nil
        )
        
        let event = try await eventManager.createEvent(
            type: .observation,
            title: "Event with location",
            notes: "GPS included",
            location: location
        )
        
        XCTAssertNotNil(event.location)
        XCTAssertEqual(event.location?.latitude, 37.7749)
        XCTAssertEqual(eventManager.events.count, 1)
    }
    
    func testCreateEventChain() async throws {
        await eventManager.initialize()
        
        // Create first event
        let event1 = try await eventManager.createEvent(
            type: .general,
            title: "First Event",
            notes: "Initial event"
        )
        
        // Create second event (should be chained)
        let event2 = try await eventManager.createEvent(
            type: .meeting,
            title: "Second Event",
            notes: "Chained event"
        )
        
        XCTAssertNil(event1.chain, "First event should not have chain")
        XCTAssertNotNil(event2.chain, "Second event should have chain")
        XCTAssertEqual(event2.chain?.previousEventId, event1.id)
        XCTAssertEqual(event2.chain?.previousEventHash, event1.integrity.contentHash)
        XCTAssertEqual(eventManager.events.count, 2)
    }
    
    // MARK: - Event Validation Tests
    
    func testCreateEventWithEmptyTitle() async throws {
        await eventManager.initialize()
        
        do {
            _ = try await eventManager.createEvent(
                type: .general,
                title: "",
                notes: "Valid notes"
            )
            XCTFail("Should throw error for empty title")
        } catch EventError.invalidTitle {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCreateEventWithWhitespaceTitle() async throws {
        await eventManager.initialize()
        
        do {
            _ = try await eventManager.createEvent(
                type: .general,
                title: "   \n\t   ",
                notes: "Valid notes"
            )
            XCTFail("Should throw error for whitespace-only title")
        } catch EventError.invalidTitle {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCreateEventWithTooLongTitle() async throws {
        await eventManager.initialize()
        
        let longTitle = String(repeating: "a", count: 201)
        
        do {
            _ = try await eventManager.createEvent(
                type: .general,
                title: longTitle,
                notes: "Valid notes"
            )
            XCTFail("Should throw error for title too long")
        } catch EventError.titleTooLong {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCreateEventWithTooLongNotes() async throws {
        await eventManager.initialize()
        
        let longNotes = String(repeating: "a", count: 10001)
        
        do {
            _ = try await eventManager.createEvent(
                type: .general,
                title: "Valid title",
                notes: longNotes
            )
            XCTFail("Should throw error for notes too long")
        } catch EventError.notesTooLong {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCreateEventTrimsTitleAndNotes() async throws {
        await eventManager.initialize()
        
        let event = try await eventManager.createEvent(
            type: .general,
            title: "  Title with spaces  ",
            notes: "  Notes with spaces  "
        )
        
        XCTAssertEqual(event.title, "Title with spaces")
        XCTAssertEqual(event.notes, "Notes with spaces")
    }
    
    // MARK: - Search Tests
    
    func testSearchEventsByTitle() async throws {
        await eventManager.initialize()
        
        _ = try await eventManager.createEvent(type: .general, title: "Meeting Notes", notes: "Important meeting")
        _ = try await eventManager.createEvent(type: .incident, title: "Security Incident", notes: "System breach")
        _ = try await eventManager.createEvent(type: .legal, title: "Legal Review", notes: "Contract review")
        
        let searchResults = eventManager.searchEvents(query: "meeting")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.title, "Meeting Notes")
    }
    
    func testSearchEventsByNotes() async throws {
        await eventManager.initialize()
        
        _ = try await eventManager.createEvent(type: .general, title: "Daily Update", notes: "Security check completed")
        _ = try await eventManager.createEvent(type: .incident, title: "System Issue", notes: "Database connection failed")
        
        let searchResults = eventManager.searchEvents(query: "security")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.title, "Daily Update")
    }
    
    func testSearchEventsByType() async throws {
        await eventManager.initialize()
        
        _ = try await eventManager.createEvent(type: .meeting, title: "Team Meeting", notes: "Weekly standup")
        _ = try await eventManager.createEvent(type: .incident, title: "System Issue", notes: "Server down")
        
        let searchResults = eventManager.searchEvents(query: "meeting")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.type, .meeting)
    }
    
    func testSearchEventsCaseInsensitive() async throws {
        await eventManager.initialize()
        
        _ = try await eventManager.createEvent(type: .general, title: "Important Update", notes: "System maintenance")
        
        let searchResults1 = eventManager.searchEvents(query: "important")
        let searchResults2 = eventManager.searchEvents(query: "IMPORTANT")
        let searchResults3 = eventManager.searchEvents(query: "Important")
        
        XCTAssertEqual(searchResults1.count, 1)
        XCTAssertEqual(searchResults2.count, 1)
        XCTAssertEqual(searchResults3.count, 1)
    }
    
    func testSearchEventsEmptyQuery() async throws {
        await eventManager.initialize()
        
        _ = try await eventManager.createEvent(type: .general, title: "Event 1", notes: "Notes 1")
        _ = try await eventManager.createEvent(type: .meeting, title: "Event 2", notes: "Notes 2")
        
        let searchResults = eventManager.searchEvents(query: "")
        XCTAssertEqual(searchResults.count, 2, "Empty query should return all events")
    }
    
    // MARK: - Filter Tests
    
    func testEventsByType() async throws {
        await eventManager.initialize()
        
        _ = try await eventManager.createEvent(type: .meeting, title: "Meeting 1", notes: "Notes")
        _ = try await eventManager.createEvent(type: .meeting, title: "Meeting 2", notes: "Notes")
        _ = try await eventManager.createEvent(type: .incident, title: "Incident 1", notes: "Notes")
        
        let meetingEvents = eventManager.events(ofType: .meeting)
        let incidentEvents = eventManager.events(ofType: .incident)
        let legalEvents = eventManager.events(ofType: .legal)
        
        XCTAssertEqual(meetingEvents.count, 2)
        XCTAssertEqual(incidentEvents.count, 1)
        XCTAssertEqual(legalEvents.count, 0)
    }
    
    func testEventsByDateRange() async throws {
        await eventManager.initialize()
        
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        
        // Create events (they'll have current timestamp, but we can test the filtering logic)
        _ = try await eventManager.createEvent(type: .general, title: "Recent Event", notes: "Notes")
        _ = try await eventManager.createEvent(type: .general, title: "Another Event", notes: "Notes")
        
        // Test date range filtering
        let recentEvents = eventManager.events(from: oneHourAgo, to: now.addingTimeInterval(3600))
        XCTAssertEqual(recentEvents.count, 2, "All events should be in recent range")
        
        let oldEvents = eventManager.events(from: twoHoursAgo, to: oneHourAgo)
        XCTAssertEqual(oldEvents.count, 0, "No events should be in old range")
    }
    
    // MARK: - Export Tests
    
    func testExportSingleEvent() async throws {
        await eventManager.initialize()
        
        let event = try await eventManager.createEvent(
            type: .legal,
            title: "Contract Review",
            notes: "Reviewed employment contract"
        )
        
        let exportData = try eventManager.exportEvent(event)
        XCTAssertFalse(exportData.isEmpty, "Export data should not be empty")
        
        // Verify it's valid JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedEvent = try decoder.decode(ForensicEvent.self, from: exportData)
        
        XCTAssertEqual(decodedEvent.id, event.id)
        XCTAssertEqual(decodedEvent.title, event.title)
    }
    
    func testExportAllEvents() async throws {
        await eventManager.initialize()
        
        _ = try await eventManager.createEvent(type: .general, title: "Event 1", notes: "Notes 1")
        _ = try await eventManager.createEvent(type: .meeting, title: "Event 2", notes: "Notes 2")
        
        let exportData = try eventManager.exportAllEvents()
        XCTAssertFalse(exportData.isEmpty, "Export data should not be empty")
        
        // Verify it's valid JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportBundle = try decoder.decode(EventExportBundle.self, from: exportData)
        
        XCTAssertEqual(exportBundle.events.count, 2)
        XCTAssertEqual(exportBundle.version, "1.0")
        XCTAssertEqual(exportBundle.verificationInfo.eventCount, 2)
        XCTAssertTrue(exportBundle.verificationInfo.chainValid)
    }
    
    func testExportEmptyEventList() async throws {
        await eventManager.initialize()
        
        let exportData = try eventManager.exportAllEvents()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportBundle = try decoder.decode(EventExportBundle.self, from: exportData)
        
        XCTAssertEqual(exportBundle.events.count, 0)
        XCTAssertEqual(exportBundle.verificationInfo.eventCount, 0)
        XCTAssertTrue(exportBundle.verificationInfo.chainValid, "Empty chain should be valid")
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorStates() async throws {
        await eventManager.initialize()
        
        // Initially no error
        XCTAssertNil(eventManager.error)
        
        // Create a valid event
        _ = try await eventManager.createEvent(type: .general, title: "Valid Event", notes: "Notes")
        XCTAssertNil(eventManager.error, "Valid operations should not set error")
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentEventCreation() async throws {
        await eventManager.initialize()
        
        // Create multiple events concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    do {
                        _ = try await self.eventManager.createEvent(
                            type: .general,
                            title: "Concurrent Event \(i)",
                            notes: "Created concurrently"
                        )
                    } catch {
                        XCTFail("Concurrent event creation failed: \(error)")
                    }
                }
            }
        }
        
        XCTAssertEqual(eventManager.events.count, 10, "All concurrent events should be created")
        
        // Verify chain integrity
        let result = CryptoUtils.verifyEventChain(eventManager.events)
        XCTAssertTrue(result.isValid, "Chain should remain valid after concurrent creation")
    }
    
    // MARK: - Performance Tests
    
    func testCreateManyEvents() async throws {
        await eventManager.initialize()
        
        measure {
            Task {
                for i in 0..<100 {
                    do {
                        _ = try await eventManager.createEvent(
                            type: .general,
                            title: "Performance Test Event \(i)",
                            notes: "Performance testing notes"
                        )
                    } catch {
                        XCTFail("Event creation failed: \(error)")
                    }
                }
            }
        }
    }
    
    func testSearchPerformance() async throws {
        await eventManager.initialize()
        
        // Create many events
        for i in 0..<1000 {
            _ = try await eventManager.createEvent(
                type: .general,
                title: "Event \(i)",
                notes: "Notes for event \(i)"
            )
        }
        
        measure {
            _ = eventManager.searchEvents(query: "Event 500")
        }
    }
}