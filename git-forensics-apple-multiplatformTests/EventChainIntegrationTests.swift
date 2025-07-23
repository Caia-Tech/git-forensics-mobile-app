//
//  EventChainIntegrationTests.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import XCTest
@testable import git_forensics_apple_multiplatform
import Foundation

@MainActor
final class EventChainIntegrationTests: XCTestCase {
    
    var eventManager: EventManager!
    var gitManager: SimpleGitManager!
    var attachmentManager: AttachmentManager!
    var testDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary directory for testing
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-integration-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        // Initialize managers
        eventManager = EventManager()
        gitManager = SimpleGitManager.shared
        attachmentManager = AttachmentManager.shared
        
        // Initialize the system
        await eventManager.initialize()
    }
    
    override func tearDown() async throws {
        // Clean up test directory
        if FileManager.default.fileExists(atPath: testDirectory.path) {
            try FileManager.default.removeItem(at: testDirectory)
        }
        
        eventManager = nil
        gitManager = nil
        attachmentManager = nil
        testDirectory = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 10, height: 10)
        UIGraphicsBeginImageContext(size)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    private func createTestFile(content: String) throws -> URL {
        let fileName = "test-\(UUID().uuidString).txt"
        let fileURL = testDirectory.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    // MARK: - Basic Chain Integrity Tests
    
    func testCreateSimpleEventChain() async throws {
        // Create a chain of 5 events
        var createdEvents: [ForensicEvent] = []
        
        for i in 0..<5 {
            let event = try await eventManager.createEvent(
                type: .general,
                title: "Event \(i)",
                notes: "Notes for event \(i)"
            )
            createdEvents.append(event)
        }
        
        // Verify all events were created
        XCTAssertEqual(eventManager.events.count, 5)
        XCTAssertEqual(createdEvents.count, 5)
        
        // Verify chain structure
        XCTAssertNil(createdEvents[0].chain, "First event should not have chain")
        
        for i in 1..<5 {
            XCTAssertNotNil(createdEvents[i].chain, "Event \(i) should have chain")
            XCTAssertEqual(createdEvents[i].chain?.eventNumber, i - 1)
            XCTAssertEqual(createdEvents[i].chain?.previousEventId, createdEvents[i-1].id)
            XCTAssertEqual(createdEvents[i].chain?.previousEventHash, createdEvents[i-1].integrity.contentHash)
        }
        
        // Verify chain integrity
        let verification = CryptoUtils.verifyEventChain(eventManager.events)
        XCTAssertTrue(verification.isValid, "Event chain should be valid")
        XCTAssertNil(verification.error, "Valid chain should have no error")
    }
    
    func testChainIntegrityWithAttachments() async throws {
        // Create events with various attachments
        let testImage = createTestImage()
        let imageAttachment = try await attachmentManager.processImageAttachment(testImage, filename: "test.jpg")
        
        let fileURL = try createTestFile(content: "Test document content")
        let fileAttachment = try await attachmentManager.processFileAttachment(from: fileURL)
        
        // Create first event with image
        let event1 = try await eventManager.createEvent(
            type: .incident,
            title: "Incident with Photo",
            notes: "Photo evidence attached",
            attachments: [imageAttachment]
        )
        
        // Create second event with file
        let event2 = try await eventManager.createEvent(
            type: .legal,
            title: "Legal Document",
            notes: "Document evidence attached",
            attachments: [fileAttachment]
        )
        
        // Create third event with both
        let event3 = try await eventManager.createEvent(
            type: .meeting,
            title: "Meeting with Evidence",
            notes: "Multiple attachments",
            attachments: [imageAttachment, fileAttachment]
        )
        
        // Verify chain integrity
        let verification = CryptoUtils.verifyEventChain(eventManager.events)
        XCTAssertTrue(verification.isValid, "Chain with attachments should be valid")
        
        // Verify attachments are included in hash calculation
        let event1Hash = CryptoUtils.calculateEventHash(event1)
        let event1WithoutAttachments = ForensicEvent(
            type: event1.type,
            title: event1.title,
            notes: event1.notes
        )
        let hashWithoutAttachments = CryptoUtils.calculateEventHash(event1WithoutAttachments)
        
        XCTAssertNotEqual(event1Hash, hashWithoutAttachments, "Attachments should affect event hash")
    }
    
    func testChainIntegrityWithLocation() async throws {
        let location = EventLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            accuracyMeters: 5.0,
            altitudeMeters: 100.0,
            altitudeAccuracyMeters: 10.0,
            headingDegrees: 45.0,
            speedMPS: 2.5,
            capturedAt: Date(),
            source: .gps,
            address: nil
        )
        
        // Create events with and without location
        let event1 = try await eventManager.createEvent(
            type: .observation,
            title: "Observation at Location",
            notes: "GPS coordinates included",
            location: location
        )
        
        let event2 = try await eventManager.createEvent(
            type: .general,
            title: "General Note",
            notes: "No location data"
        )
        
        // Verify chain integrity
        let verification = CryptoUtils.verifyEventChain(eventManager.events)
        XCTAssertTrue(verification.isValid, "Chain with location data should be valid")
        
        // Verify location affects hash
        let event1Hash = CryptoUtils.calculateEventHash(event1)
        let event1WithoutLocation = ForensicEvent(
            type: event1.type,
            title: event1.title,
            notes: event1.notes
        )
        let hashWithoutLocation = CryptoUtils.calculateEventHash(event1WithoutLocation)
        
        XCTAssertNotEqual(event1Hash, hashWithoutLocation, "Location should affect event hash")
    }
    
    // MARK: - Persistence and Loading Tests
    
    func testChainIntegrityAfterReload() async throws {
        // Create a chain of events
        for i in 0..<10 {
            _ = try await eventManager.createEvent(
                type: .general,
                title: "Event \(i)",
                notes: "Notes \(i)"
            )
        }
        
        // Verify initial chain
        let initialVerification = CryptoUtils.verifyEventChain(eventManager.events)
        XCTAssertTrue(initialVerification.isValid, "Initial chain should be valid")
        
        // Simulate app restart by loading events fresh
        await eventManager.loadEvents()
        
        // Verify chain is still valid after reload
        let reloadedVerification = CryptoUtils.verifyEventChain(eventManager.events)
        XCTAssertTrue(reloadedVerification.isValid, "Reloaded chain should be valid")
        XCTAssertEqual(eventManager.events.count, 10, "All events should be loaded")
    }
    
    func testChainIntegrityWithComplexData() async throws {
        // Create events with various complex data
        let testImage = createTestImage()
        let imageAttachment = try await attachmentManager.processImageAttachment(testImage)
        
        let location = EventLocation(
            latitude: 40.7128,
            longitude: -74.0060,
            accuracyMeters: 3.0,
            altitudeMeters: nil,
            altitudeAccuracyMeters: nil,
            headingDegrees: nil,
            speedMPS: nil,
            capturedAt: Date(),
            source: .gps,
            address: EventLocation.Address(
                street: "123 Test St",
                city: "Test City",
                state: "TS",
                postalCode: "12345",
                country: "US"
            )
        )
        
        // Event with special characters and unicode
        let event1 = try await eventManager.createEvent(
            type: .communication,
            title: "Message with émojis 🔒 and spëcial chars",
            notes: "Content with newlines\nand tabs\tand unicode: 中文",
            attachments: [imageAttachment],
            location: location
        )
        
        // Event with very long content
        let longNotes = String(repeating: "This is a very long note. ", count: 200)
        let event2 = try await eventManager.createEvent(
            type: .legal,
            title: "Long Legal Document",
            notes: longNotes
        )
        
        // Event with multiple attachments
        let fileURL = try createTestFile(content: "JSON content: {\"key\": \"value\", \"number\": 42}")
        let fileAttachment = try await attachmentManager.processFileAttachment(from: fileURL)
        
        let event3 = try await eventManager.createEvent(
            type: .incident,
            title: "Multi-attachment Incident",
            notes: "Complex incident with multiple evidence types",
            attachments: [imageAttachment, fileAttachment]
        )
        
        // Verify chain integrity with complex data
        let verification = CryptoUtils.verifyEventChain(eventManager.events)
        XCTAssertTrue(verification.isValid, "Complex data chain should be valid")
        
        // Verify all events have proper hashes
        for event in eventManager.events {
            let calculatedHash = CryptoUtils.calculateEventHash(event)
            XCTAssertEqual(calculatedHash, event.integrity.contentHash, "Event hash should match calculated hash")
        }
    }
    
    // MARK: - Tamper Detection Tests
    
    func testDetectEventContentTampering() async throws {
        // Create a valid chain
        _ = try await eventManager.createEvent(
            type: .general,
            title: "Original Event",
            notes: "Original notes"
        )
        
        // Manually tamper with an event
        var events = eventManager.events
        var tamperedEvent = events[0]
        
        // Create a new event with modified content but keep original hash
        let originalHash = tamperedEvent.integrity.contentHash
        var modifiedEvent = ForensicEvent(
            type: tamperedEvent.type,
            title: "TAMPERED TITLE", // Changed title
            notes: tamperedEvent.notes
        )
        modifiedEvent.integrity = EventIntegrity(contentHash: originalHash, signature: nil) // Keep original hash
        
        // Test verification with tampered event
        let verification = CryptoUtils.verifyEventChain([modifiedEvent])
        XCTAssertFalse(verification.isValid, "Tampered event should be detected")
        XCTAssertNotNil(verification.error, "Tampered event should have error")
        XCTAssertTrue(verification.error!.contains("hash mismatch"), "Error should mention hash mismatch")
    }
    
    func testDetectChainLinkTampering() async throws {
        // Create a valid chain
        let event1 = try await eventManager.createEvent(
            type: .general,
            title: "First Event",
            notes: "First notes"
        )
        
        let event2 = try await eventManager.createEvent(
            type: .meeting,
            title: "Second Event",
            notes: "Second notes"
        )
        
        // Verify original chain is valid
        let originalVerification = CryptoUtils.verifyEventChain(eventManager.events)
        XCTAssertTrue(originalVerification.isValid, "Original chain should be valid")
        
        // Tamper with chain link
        var tamperedEvent2 = event2
        tamperedEvent2.chain = EventChain(
            previousEventId: event1.id,
            previousEventHash: "tampered_hash", // Wrong hash
            eventNumber: 1
        )
        
        let verification = CryptoUtils.verifyEventChain([event1, tamperedEvent2])
        XCTAssertFalse(verification.isValid, "Tampered chain should be detected")
        XCTAssertTrue(verification.error!.contains("Chain broken"), "Error should mention broken chain")
    }
    
    func testDetectEventInsertion() async throws {
        // Create original chain
        let event1 = try await eventManager.createEvent(
            type: .general,
            title: "Event 1",
            notes: "Notes 1"
        )
        
        let event3 = try await eventManager.createEvent(
            type: .general,
            title: "Event 3",
            notes: "Notes 3"
        )
        
        // Try to insert a fake event in the middle
        var fakeEvent2 = ForensicEvent(
            type: .incident,
            title: "Fake Event 2",
            notes: "This event was inserted",
            previousEvent: event1
        )
        let fakeHash = CryptoUtils.calculateEventHash(fakeEvent2)
        fakeEvent2.integrity = EventIntegrity(contentHash: fakeHash, signature: nil)
        
        // The chain should be broken because event3 doesn't link to fakeEvent2
        let verification = CryptoUtils.verifyEventChain([event1, fakeEvent2, event3])
        XCTAssertFalse(verification.isValid, "Chain with inserted event should be invalid")
    }
    
    // MARK: - Edge Cases and Stress Tests
    
    func testLargeEventChain() async throws {
        // Create a large chain to test performance and stability
        let chainSize = 100
        
        for i in 0..<chainSize {
            _ = try await eventManager.createEvent(
                type: EventType.allCases[i % EventType.allCases.count],
                title: "Event \(i)",
                notes: "Notes for event \(i) with some additional content to make it realistic"
            )
        }
        
        // Verify large chain
        let verification = CryptoUtils.verifyEventChain(eventManager.events)
        XCTAssertTrue(verification.isValid, "Large chain should be valid")
        XCTAssertEqual(eventManager.events.count, chainSize, "All events should be present")
        
        // Verify last event has correct chain number
        let lastEvent = eventManager.events.first! // Events are sorted newest first
        XCTAssertEqual(lastEvent.chain?.eventNumber, chainSize - 2, "Last event should have correct chain number")
    }
    
    func testChainWithMixedContent() async throws {
        // Create events with all possible combinations of content
        let testImage = createTestImage()
        let imageAttachment = try await attachmentManager.processImageAttachment(testImage)
        
        let fileURL = try createTestFile(content: "Mixed content test")
        let fileAttachment = try await attachmentManager.processFileAttachment(from: fileURL)
        
        let location = EventLocation(
            latitude: 51.5074,
            longitude: -0.1278,
            accuracyMeters: 10.0,
            altitudeMeters: nil,
            altitudeAccuracyMeters: nil,
            headingDegrees: nil,
            speedMPS: nil,
            capturedAt: Date(),
            source: .network,
            address: nil
        )
        
        // Event combinations
        let combinations: [(EventType, String, String, [EventAttachment], EventLocation?)] = [
            (.general, "Basic", "Basic event", [], nil),
            (.incident, "With Image", "Image attached", [imageAttachment], nil),
            (.legal, "With File", "File attached", [fileAttachment], nil),
            (.meeting, "With Location", "GPS location", [], location),
            (.observation, "With All", "Complete event", [imageAttachment, fileAttachment], location),
            (.communication, "Unicode", "émojis 🎯 and 中文", [], nil),
            (.financial, "Long Notes", String(repeating: "Long content. ", count: 50), [], nil),
            (.medical, "Special Chars", "Line 1\nLine 2\tTabbed", [imageAttachment], location)
        ]
        
        for (type, title, notes, attachments, loc) in combinations {
            _ = try await eventManager.createEvent(
                type: type,
                title: title,
                notes: notes,
                attachments: attachments,
                location: loc
            )
        }
        
        // Verify mixed content chain
        let verification = CryptoUtils.verifyEventChain(eventManager.events)
        XCTAssertTrue(verification.isValid, "Mixed content chain should be valid")
        XCTAssertEqual(eventManager.events.count, combinations.count, "All events should be created")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentEventCreation() async throws {
        // Create events concurrently and verify chain integrity
        let concurrentCount = 20
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentCount {
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
        
        XCTAssertEqual(eventManager.events.count, concurrentCount, "All concurrent events should be created")
        
        // Verify chain integrity after concurrent operations
        let verification = CryptoUtils.verifyEventChain(eventManager.events)
        XCTAssertTrue(verification.isValid, "Chain should remain valid after concurrent creation")
    }
    
    // MARK: - Performance Tests
    
    func testChainVerificationPerformance() async throws {
        // Create a substantial chain for performance testing
        for i in 0..<50 {
            _ = try await eventManager.createEvent(
                type: .general,
                title: "Performance Event \(i)",
                notes: "Performance testing content"
            )
        }
        
        measure {
            let verification = CryptoUtils.verifyEventChain(eventManager.events)
            XCTAssertTrue(verification.isValid)
        }
    }
    
    func testEventCreationPerformance() async throws {
        measure {
            Task {
                for i in 0..<20 {
                    do {
                        _ = try await eventManager.createEvent(
                            type: .general,
                            title: "Performance Event \(i)",
                            notes: "Performance testing"
                        )
                    } catch {
                        XCTFail("Event creation failed: \(error)")
                    }
                }
            }
        }
    }
}