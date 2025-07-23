//
//  CryptoUtilsTests.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import XCTest
@testable import git_forensics_apple_multiplatform
import Foundation

final class CryptoUtilsTests: XCTestCase {
    
    // MARK: - SHA-256 Hash Tests
    
    func testSHA256HashConsistency() {
        // Test that the same data produces the same hash
        let testData = "Hello, World!".data(using: .utf8)!
        let hash1 = CryptoUtils.sha256Hash(of: testData)
        let hash2 = CryptoUtils.sha256Hash(of: testData)
        
        XCTAssertEqual(hash1, hash2, "Same data should produce identical hashes")
        XCTAssertEqual(hash1.count, 64, "SHA-256 hash should be 64 characters (32 bytes in hex)")
    }
    
    func testSHA256HashDifferentData() {
        // Test that different data produces different hashes
        let data1 = "Hello, World!".data(using: .utf8)!
        let data2 = "Hello, World?".data(using: .utf8)!
        
        let hash1 = CryptoUtils.sha256Hash(of: data1)
        let hash2 = CryptoUtils.sha256Hash(of: data2)
        
        XCTAssertNotEqual(hash1, hash2, "Different data should produce different hashes")
    }
    
    func testSHA256HashEmptyData() {
        // Test empty data hash
        let emptyData = Data()
        let hash = CryptoUtils.sha256Hash(of: emptyData)
        
        // Known SHA-256 hash of empty string
        let expectedHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        XCTAssertEqual(hash, expectedHash, "Empty data should produce known SHA-256 hash")
    }
    
    func testSHA256HashKnownValues() {
        // Test known values for verification
        let testCases = [
            ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
            ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
            ("hello", "2cf24dba4f21d4288094c4e84c4e2d0572d4c2e4d5d5ddcd12c1e1b3e4d5e6c7")
        ]
        
        for (input, expected) in testCases {
            let data = input.data(using: .utf8)!
            let hash = CryptoUtils.sha256Hash(of: data)
            XCTAssertEqual(hash, expected, "Hash of '\(input)' should match expected value")
        }
    }
    
    // MARK: - Event Hash Tests
    
    func testEventHashCalculation() {
        // Create a test event
        let event = ForensicEvent(
            type: .general,
            title: "Test Event",
            notes: "Test notes"
        )
        
        let hash1 = CryptoUtils.calculateEventHash(event)
        let hash2 = CryptoUtils.calculateEventHash(event)
        
        XCTAssertEqual(hash1, hash2, "Same event should produce identical hashes")
        XCTAssertEqual(hash1.count, 64, "Event hash should be 64 characters")
        XCTAssertFalse(hash1.isEmpty, "Event hash should not be empty")
    }
    
    func testEventHashUniqueness() {
        // Create two different events
        let event1 = ForensicEvent(
            type: .general,
            title: "Test Event 1",
            notes: "Test notes"
        )
        
        let event2 = ForensicEvent(
            type: .general,
            title: "Test Event 2",
            notes: "Test notes"
        )
        
        let hash1 = CryptoUtils.calculateEventHash(event1)
        let hash2 = CryptoUtils.calculateEventHash(event2)
        
        XCTAssertNotEqual(hash1, hash2, "Different events should produce different hashes")
    }
    
    func testEventHashWithAttachments() {
        // Create event with attachments
        let attachment = EventAttachment(
            filename: "test.jpg",
            mimeType: "image/jpeg",
            sizeBytes: 1024,
            hashSHA256: "abcd1234",
            storagePath: "path/to/file"
        )
        
        let eventWithoutAttachment = ForensicEvent(
            type: .general,
            title: "Test Event",
            notes: "Test notes"
        )
        
        let eventWithAttachment = ForensicEvent(
            type: .general,
            title: "Test Event",
            notes: "Test notes",
            attachments: [attachment]
        )
        
        let hash1 = CryptoUtils.calculateEventHash(eventWithoutAttachment)
        let hash2 = CryptoUtils.calculateEventHash(eventWithAttachment)
        
        XCTAssertNotEqual(hash1, hash2, "Events with and without attachments should have different hashes")
    }
    
    func testEventHashWithLocation() {
        // Create event with location
        let location = EventLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            accuracyMeters: 5.0,
            altitudeMeters: 100.0,
            altitudeAccuracyMeters: 10.0,
            headingDegrees: 45.0,
            speedMPS: 0.0,
            capturedAt: Date(),
            source: .gps,
            address: nil
        )
        
        let eventWithoutLocation = ForensicEvent(
            type: .general,
            title: "Test Event",
            notes: "Test notes"
        )
        
        let eventWithLocation = ForensicEvent(
            type: .general,
            title: "Test Event",
            notes: "Test notes",
            location: location
        )
        
        let hash1 = CryptoUtils.calculateEventHash(eventWithoutLocation)
        let hash2 = CryptoUtils.calculateEventHash(eventWithLocation)
        
        XCTAssertNotEqual(hash1, hash2, "Events with and without location should have different hashes")
    }
    
    // MARK: - Chain Verification Tests
    
    func testEmptyChainVerification() {
        // Empty chain should be valid
        let result = CryptoUtils.verifyEventChain([])
        XCTAssertTrue(result.isValid, "Empty chain should be valid")
        XCTAssertNil(result.error, "Empty chain should have no error")
    }
    
    func testSingleEventChainVerification() {
        // Single event should be valid
        var event = ForensicEvent(
            type: .general,
            title: "Test Event",
            notes: "Test notes"
        )
        
        // Calculate and set the hash
        let hash = CryptoUtils.calculateEventHash(event)
        event.integrity = EventIntegrity(contentHash: hash, signature: nil)
        
        let result = CryptoUtils.verifyEventChain([event])
        XCTAssertTrue(result.isValid, "Single event with correct hash should be valid")
        XCTAssertNil(result.error, "Valid single event should have no error")
    }
    
    func testInvalidEventHashDetection() {
        // Event with incorrect hash should be detected
        var event = ForensicEvent(
            type: .general,
            title: "Test Event",
            notes: "Test notes"
        )
        
        // Set an incorrect hash
        event.integrity = EventIntegrity(contentHash: "invalid_hash", signature: nil)
        
        let result = CryptoUtils.verifyEventChain([event])
        XCTAssertFalse(result.isValid, "Event with incorrect hash should be invalid")
        XCTAssertNotNil(result.error, "Invalid event should have an error")
        XCTAssertTrue(result.error!.contains("hash mismatch"), "Error should mention hash mismatch")
    }
    
    func testValidEventChain() {
        // Create a valid chain of events
        var event1 = ForensicEvent(
            type: .general,
            title: "First Event",
            notes: "First notes"
        )
        let hash1 = CryptoUtils.calculateEventHash(event1)
        event1.integrity = EventIntegrity(contentHash: hash1, signature: nil)
        
        var event2 = ForensicEvent(
            type: .meeting,
            title: "Second Event",
            notes: "Second notes",
            previousEvent: event1
        )
        let hash2 = CryptoUtils.calculateEventHash(event2)
        event2.integrity = EventIntegrity(contentHash: hash2, signature: nil)
        
        let result = CryptoUtils.verifyEventChain([event1, event2])
        XCTAssertTrue(result.isValid, "Valid event chain should be verified")
        XCTAssertNil(result.error, "Valid chain should have no error")
    }
    
    func testBrokenEventChain() {
        // Create a chain with broken link
        var event1 = ForensicEvent(
            type: .general,
            title: "First Event",
            notes: "First notes"
        )
        let hash1 = CryptoUtils.calculateEventHash(event1)
        event1.integrity = EventIntegrity(contentHash: hash1, signature: nil)
        
        var event2 = ForensicEvent(
            type: .meeting,
            title: "Second Event",
            notes: "Second notes",
            previousEvent: event1
        )
        let hash2 = CryptoUtils.calculateEventHash(event2)
        event2.integrity = EventIntegrity(contentHash: hash2, signature: nil)
        
        // Break the chain by modifying the first event's hash
        event1.integrity = EventIntegrity(contentHash: "broken_hash", signature: nil)
        
        let result = CryptoUtils.verifyEventChain([event1, event2])
        XCTAssertFalse(result.isValid, "Broken chain should be detected")
        XCTAssertNotNil(result.error, "Broken chain should have an error")
    }
    
    func testChainOrderIndependence() {
        // Chain verification should work regardless of input order
        var event1 = ForensicEvent(
            type: .general,
            title: "First Event",
            notes: "First notes"
        )
        let hash1 = CryptoUtils.calculateEventHash(event1)
        event1.integrity = EventIntegrity(contentHash: hash1, signature: nil)
        
        var event2 = ForensicEvent(
            type: .meeting,
            title: "Second Event",
            notes: "Second notes",
            previousEvent: event1
        )
        let hash2 = CryptoUtils.calculateEventHash(event2)
        event2.integrity = EventIntegrity(contentHash: hash2, signature: nil)
        
        // Test both orders
        let result1 = CryptoUtils.verifyEventChain([event1, event2])
        let result2 = CryptoUtils.verifyEventChain([event2, event1])
        
        XCTAssertEqual(result1.isValid, result2.isValid, "Chain verification should be order-independent")
    }
    
    // MARK: - Performance Tests
    
    func testHashPerformance() {
        let testData = String(repeating: "a", count: 10000).data(using: .utf8)!
        
        measure {
            for _ in 0..<100 {
                _ = CryptoUtils.sha256Hash(of: testData)
            }
        }
    }
    
    func testEventHashPerformance() {
        let event = ForensicEvent(
            type: .general,
            title: "Performance Test Event",
            notes: String(repeating: "This is a long note for performance testing. ", count: 100)
        )
        
        measure {
            for _ in 0..<50 {
                _ = CryptoUtils.calculateEventHash(event)
            }
        }
    }
    
    func testChainVerificationPerformance() {
        // Create a chain of 100 events
        var events: [ForensicEvent] = []
        var previousEvent: ForensicEvent? = nil
        
        for i in 0..<100 {
            var event = ForensicEvent(
                type: .general,
                title: "Event \(i)",
                notes: "Notes for event \(i)",
                previousEvent: previousEvent
            )
            let hash = CryptoUtils.calculateEventHash(event)
            event.integrity = EventIntegrity(contentHash: hash, signature: nil)
            events.append(event)
            previousEvent = event
        }
        
        measure {
            _ = CryptoUtils.verifyEventChain(events)
        }
    }
}