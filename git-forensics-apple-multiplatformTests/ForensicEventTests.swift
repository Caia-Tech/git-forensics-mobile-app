//
//  ForensicEventTests.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import XCTest
@testable import git_forensics_apple_multiplatform
import Foundation

final class ForensicEventTests: XCTestCase {
    
    // MARK: - ForensicEvent Creation Tests
    
    func testBasicEventCreation() {
        let event = ForensicEvent(
            type: .general,
            title: "Test Event",
            notes: "Test notes"
        )
        
        XCTAssertEqual(event.type, .general)
        XCTAssertEqual(event.title, "Test Event")
        XCTAssertEqual(event.notes, "Test notes")
        XCTAssertNotNil(event.id)
        XCTAssertNotNil(event.createdAt)
        XCTAssertNotNil(event.createdAtLocal)
        XCTAssertNotNil(event.metadata)
        XCTAssertEqual(event.version, "1.0")
        XCTAssertTrue(event.attachments.isEmpty)
        XCTAssertNil(event.location)
        XCTAssertNil(event.chain)
    }
    
    func testEventWithAttachments() {
        let attachment1 = EventAttachment(
            filename: "test1.jpg",
            mimeType: "image/jpeg",
            sizeBytes: 1024,
            hashSHA256: "hash1",
            storagePath: "path1"
        )
        
        let attachment2 = EventAttachment(
            filename: "test2.pdf",
            mimeType: "application/pdf",
            sizeBytes: 2048,
            hashSHA256: "hash2",
            storagePath: "path2"
        )
        
        let event = ForensicEvent(
            type: .legal,
            title: "Event with attachments",
            notes: "Has multiple attachments",
            attachments: [attachment1, attachment2]
        )
        
        XCTAssertEqual(event.attachments.count, 2)
        XCTAssertEqual(event.attachments[0].filename, "test1.jpg")
        XCTAssertEqual(event.attachments[1].filename, "test2.pdf")
    }
    
    func testEventWithLocation() {
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
        
        let event = ForensicEvent(
            type: .observation,
            title: "Event with location",
            notes: "GPS coordinates included",
            location: location
        )
        
        XCTAssertNotNil(event.location)
        XCTAssertEqual(event.location?.latitude, 37.7749)
        XCTAssertEqual(event.location?.longitude, -122.4194)
        XCTAssertEqual(event.location?.source, .gps)
    }
    
    func testEventChainCreation() {
        // Create first event
        let firstEvent = ForensicEvent(
            type: .general,
            title: "First Event",
            notes: "Initial event"
        )
        
        // Create second event linked to first
        let secondEvent = ForensicEvent(
            type: .meeting,
            title: "Second Event",
            notes: "Linked to first",
            previousEvent: firstEvent
        )
        
        XCTAssertNil(firstEvent.chain, "First event should not have chain")
        XCTAssertNotNil(secondEvent.chain, "Second event should have chain")
        XCTAssertEqual(secondEvent.chain?.previousEventId, firstEvent.id)
        XCTAssertEqual(secondEvent.chain?.eventNumber, 1)
    }
    
    func testLongEventChain() {
        // Create a chain of 5 events
        var events: [ForensicEvent] = []
        var previousEvent: ForensicEvent? = nil
        
        for i in 0..<5 {
            let event = ForensicEvent(
                type: .general,
                title: "Event \(i)",
                notes: "Event number \(i)",
                previousEvent: previousEvent
            )
            events.append(event)
            previousEvent = event
        }
        
        // Verify chain structure
        XCTAssertNil(events[0].chain, "First event should have no chain")
        
        for i in 1..<5 {
            XCTAssertNotNil(events[i].chain, "Event \(i) should have chain")
            XCTAssertEqual(events[i].chain?.eventNumber, i - 1, "Event \(i) should have correct event number")
            XCTAssertEqual(events[i].chain?.previousEventId, events[i-1].id, "Event \(i) should link to previous event")
        }
    }
    
    // MARK: - EventType Tests
    
    func testEventTypeDisplayNames() {
        let expectedDisplayNames: [EventType: String] = [
            .meeting: "Meeting",
            .incident: "Incident",
            .medical: "Medical",
            .legal: "Legal",
            .financial: "Financial",
            .observation: "Observation",
            .communication: "Communication",
            .general: "General Note"
        ]
        
        for (type, expectedName) in expectedDisplayNames {
            XCTAssertEqual(type.displayName, expectedName, "Display name for \(type) should be \(expectedName)")
        }
    }
    
    func testEventTypeIcons() {
        let expectedIcons: [EventType: String] = [
            .meeting: "person.2",
            .incident: "exclamationmark.triangle",
            .medical: "heart",
            .legal: "scalemass",
            .financial: "dollarsign",
            .observation: "eye",
            .communication: "message",
            .general: "doc.text"
        ]
        
        for (type, expectedIcon) in expectedIcons {
            XCTAssertEqual(type.icon, expectedIcon, "Icon for \(type) should be \(expectedIcon)")
        }
    }
    
    func testEventTypeRawValues() {
        // Ensure raw values are stable (important for serialization)
        XCTAssertEqual(EventType.meeting.rawValue, "meeting")
        XCTAssertEqual(EventType.incident.rawValue, "incident")
        XCTAssertEqual(EventType.medical.rawValue, "medical")
        XCTAssertEqual(EventType.legal.rawValue, "legal")
        XCTAssertEqual(EventType.financial.rawValue, "financial")
        XCTAssertEqual(EventType.observation.rawValue, "observation")
        XCTAssertEqual(EventType.communication.rawValue, "communication")
        XCTAssertEqual(EventType.general.rawValue, "general")
    }
    
    // MARK: - EventAttachment Tests
    
    func testAttachmentCreation() {
        let attachment = EventAttachment(
            filename: "document.pdf",
            mimeType: "application/pdf",
            sizeBytes: 1024000,
            hashSHA256: "abcdef1234567890",
            storagePath: "attachments/2024/01/01/abcdef1234567890.pdf"
        )
        
        XCTAssertNotNil(attachment.id)
        XCTAssertEqual(attachment.filename, "document.pdf")
        XCTAssertEqual(attachment.mimeType, "application/pdf")
        XCTAssertEqual(attachment.sizeBytes, 1024000)
        XCTAssertEqual(attachment.hashSHA256, "abcdef1234567890")
        XCTAssertEqual(attachment.storagePath, "attachments/2024/01/01/abcdef1234567890.pdf")
        XCTAssertNotNil(attachment.createdAt)
    }
    
    func testAttachmentEquality() {
        let attachment1 = EventAttachment(
            filename: "test.jpg",
            mimeType: "image/jpeg",
            sizeBytes: 1024,
            hashSHA256: "hash123",
            storagePath: "path"
        )
        
        let attachment2 = EventAttachment(
            filename: "test.jpg",
            mimeType: "image/jpeg",
            sizeBytes: 1024,
            hashSHA256: "hash123",
            storagePath: "path"
        )
        
        // IDs should be different but other properties same
        XCTAssertNotEqual(attachment1.id, attachment2.id)
        XCTAssertEqual(attachment1.filename, attachment2.filename)
        XCTAssertEqual(attachment1.hashSHA256, attachment2.hashSHA256)
    }
    
    // MARK: - EventLocation Tests
    
    func testLocationCreation() {
        let captureDate = Date()
        let address = EventLocation.Address(
            street: "123 Main St",
            city: "San Francisco",
            state: "CA",
            postalCode: "94102",
            country: "US"
        )
        
        let location = EventLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            accuracyMeters: 5.0,
            altitudeMeters: 100.0,
            altitudeAccuracyMeters: 10.0,
            headingDegrees: 90.0,
            speedMPS: 1.5,
            capturedAt: captureDate,
            source: .gps,
            address: address
        )
        
        XCTAssertEqual(location.latitude, 37.7749)
        XCTAssertEqual(location.longitude, -122.4194)
        XCTAssertEqual(location.accuracyMeters, 5.0)
        XCTAssertEqual(location.altitudeMeters, 100.0)
        XCTAssertEqual(location.altitudeAccuracyMeters, 10.0)
        XCTAssertEqual(location.headingDegrees, 90.0)
        XCTAssertEqual(location.speedMPS, 1.5)
        XCTAssertEqual(location.capturedAt, captureDate)
        XCTAssertEqual(location.source, .gps)
        XCTAssertNotNil(location.address)
        XCTAssertEqual(location.address?.street, "123 Main St")
        XCTAssertEqual(location.address?.city, "San Francisco")
    }
    
    func testLocationSources() {
        let sources: [EventLocation.LocationSource] = [.gps, .network, .manual]
        let rawValues = ["gps", "network", "manual"]
        
        for (source, expectedRaw) in zip(sources, rawValues) {
            XCTAssertEqual(source.rawValue, expectedRaw)
        }
    }
    
    // MARK: - EventMetadata Tests
    
    func testMetadataCreation() {
        let metadata = EventMetadata()
        
        XCTAssertNotNil(metadata.deviceId)
        XCTAssertFalse(metadata.deviceModel.isEmpty)
        XCTAssertFalse(metadata.osVersion.isEmpty)
        XCTAssertFalse(metadata.appVersion.isEmpty)
        XCTAssertFalse(metadata.appBuild.isEmpty)
    }
    
    // MARK: - Codable Tests
    
    func testEventSerialization() throws {
        let originalEvent = ForensicEvent(
            type: .legal,
            title: "Test Serialization",
            notes: "Testing JSON encoding/decoding"
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(originalEvent)
        XCTAssertFalse(jsonData.isEmpty, "JSON data should not be empty")
        
        // Decode from JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let decodedEvent = try decoder.decode(ForensicEvent.self, from: jsonData)
        
        // Verify all fields match
        XCTAssertEqual(decodedEvent.id, originalEvent.id)
        XCTAssertEqual(decodedEvent.type, originalEvent.type)
        XCTAssertEqual(decodedEvent.title, originalEvent.title)
        XCTAssertEqual(decodedEvent.notes, originalEvent.notes)
        XCTAssertEqual(decodedEvent.version, originalEvent.version)
        XCTAssertEqual(decodedEvent.attachments.count, originalEvent.attachments.count)
    }
    
    func testEventWithAttachmentsSerialization() throws {
        let attachment = EventAttachment(
            filename: "test.jpg",
            mimeType: "image/jpeg",
            sizeBytes: 1024,
            hashSHA256: "testhash",
            storagePath: "path/to/file"
        )
        
        let originalEvent = ForensicEvent(
            type: .incident,
            title: "Event with attachments",
            notes: "Testing attachment serialization",
            attachments: [attachment]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(originalEvent)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedEvent = try decoder.decode(ForensicEvent.self, from: jsonData)
        
        XCTAssertEqual(decodedEvent.attachments.count, 1)
        XCTAssertEqual(decodedEvent.attachments[0].filename, "test.jpg")
        XCTAssertEqual(decodedEvent.attachments[0].hashSHA256, "testhash")
    }
    
    func testEventWithLocationSerialization() throws {
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
        
        let originalEvent = ForensicEvent(
            type: .observation,
            title: "Event with location",
            notes: "Testing location serialization",
            location: location
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(originalEvent)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedEvent = try decoder.decode(ForensicEvent.self, from: jsonData)
        
        XCTAssertNotNil(decodedEvent.location)
        XCTAssertEqual(decodedEvent.location?.latitude, 37.7749)
        XCTAssertEqual(decodedEvent.location?.longitude, -122.4194)
        XCTAssertEqual(decodedEvent.location?.source, .gps)
    }
    
    // MARK: - Edge Cases
    
    func testEventWithEmptyStrings() {
        let event = ForensicEvent(
            type: .general,
            title: "",
            notes: ""
        )
        
        XCTAssertEqual(event.title, "")
        XCTAssertEqual(event.notes, "")
        XCTAssertNotNil(event.id)
    }
    
    func testEventWithLongStrings() {
        let longTitle = String(repeating: "a", count: 1000)
        let longNotes = String(repeating: "b", count: 10000)
        
        let event = ForensicEvent(
            type: .general,
            title: longTitle,
            notes: longNotes
        )
        
        XCTAssertEqual(event.title.count, 1000)
        XCTAssertEqual(event.notes.count, 10000)
    }
    
    func testEventWithSpecialCharacters() {
        let specialTitle = "Title with émojis 🔒 and spëcial çharacters"
        let specialNotes = "Notes with newlines\nand tabs\tand unicode: 中文"
        
        let event = ForensicEvent(
            type: .general,
            title: specialTitle,
            notes: specialNotes
        )
        
        XCTAssertEqual(event.title, specialTitle)
        XCTAssertEqual(event.notes, specialNotes)
        
        // Test serialization with special characters
        XCTAssertNoThrow(try JSONEncoder().encode(event))
    }
}