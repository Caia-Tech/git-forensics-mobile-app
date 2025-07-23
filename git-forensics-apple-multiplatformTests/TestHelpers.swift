//
//  TestHelpers.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation
import XCTest
@testable import git_forensics_apple_multiplatform

// MARK: - Test Data Factories

struct TestDataFactory {
    
    static func createBasicEvent() -> ForensicEvent {
        return ForensicEvent(
            type: .general,
            title: "Test Event",
            notes: "Test notes"
        )
    }
    
    static func createEventWithAttachments() -> (ForensicEvent, [EventAttachment]) {
        let attachments = [
            createTestAttachment(filename: "test1.jpg", mimeType: "image/jpeg"),
            createTestAttachment(filename: "test2.pdf", mimeType: "application/pdf")
        ]
        
        let event = ForensicEvent(
            type: .incident,
            title: "Event with attachments",
            notes: "Multiple attachments",
            attachments: attachments
        )
        
        return (event, attachments)
    }
    
    static func createEventWithLocation() -> (ForensicEvent, EventLocation) {
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
            address: EventLocation.Address(
                street: "123 Test St",
                city: "San Francisco",
                state: "CA",
                postalCode: "94102",
                country: "US"
            )
        )
        
        let event = ForensicEvent(
            type: .observation,
            title: "Event with location",
            notes: "GPS coordinates included",
            location: location
        )
        
        return (event, location)
    }
    
    static func createTestAttachment(filename: String, mimeType: String) -> EventAttachment {
        return EventAttachment(
            filename: filename,
            mimeType: mimeType,
            sizeBytes: 1024,
            hashSHA256: "test_hash_\(UUID().uuidString.prefix(32))",
            storagePath: "test/path/\(filename)"
        )
    }
    
    static func createEventChain(length: Int) -> [ForensicEvent] {
        var events: [ForensicEvent] = []
        var previousEvent: ForensicEvent? = nil
        
        for i in 0..<length {
            var event = ForensicEvent(
                type: EventType.allCases[i % EventType.allCases.count],
                title: "Chain Event \(i)",
                notes: "Event \(i) in test chain",
                previousEvent: previousEvent
            )
            
            // Calculate and set hash
            let hash = CryptoUtils.calculateEventHash(event)
            event.integrity = EventIntegrity(contentHash: hash, signature: nil)
            
            events.append(event)
            previousEvent = event
        }
        
        return events
    }
}

// MARK: - Test Assertions

extension XCTestCase {
    
    func assertEventChainValid(_ events: [ForensicEvent], file: StaticString = #file, line: UInt = #line) {
        let verification = CryptoUtils.verifyEventChain(events)
        XCTAssertTrue(verification.isValid, "Event chain should be valid", file: file, line: line)
        XCTAssertNil(verification.error, "Valid chain should have no error: \(verification.error ?? "")", file: file, line: line)
    }
    
    func assertEventChainInvalid(_ events: [ForensicEvent], expectedError: String? = nil, file: StaticString = #file, line: UInt = #line) {
        let verification = CryptoUtils.verifyEventChain(events)
        XCTAssertFalse(verification.isValid, "Event chain should be invalid", file: file, line: line)
        XCTAssertNotNil(verification.error, "Invalid chain should have error", file: file, line: line)
        
        if let expected = expectedError {
            XCTAssertTrue(verification.error!.contains(expected), "Error should contain '\(expected)': \(verification.error!)", file: file, line: line)
        }
    }
    
    func assertEventHashValid(_ event: ForensicEvent, file: StaticString = #file, line: UInt = #line) {
        let calculatedHash = CryptoUtils.calculateEventHash(event)
        XCTAssertEqual(calculatedHash, event.integrity.contentHash, "Event hash should match calculated hash", file: file, line: line)
    }
    
    func assertEventsEqual(_ event1: ForensicEvent, _ event2: ForensicEvent, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(event1.id, event2.id, file: file, line: line)
        XCTAssertEqual(event1.type, event2.type, file: file, line: line)
        XCTAssertEqual(event1.title, event2.title, file: file, line: line)
        XCTAssertEqual(event1.notes, event2.notes, file: file, line: line)
        XCTAssertEqual(event1.attachments.count, event2.attachments.count, file: file, line: line)
    }
}

// MARK: - Mock Classes for Testing

class MockDeviceInfo {
    static let testDeviceId = UUID()
    static let testDeviceModel = "TestDevice1,1"
    static let testOSVersion = "17.0"
    static let testAppVersion = "1.0"
    static let testAppBuild = "1"
}

// MARK: - Test Utilities

struct TestUtilities {
    
    static func createTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("git-forensics-test-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    static func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    static func createTestFile(content: String, extension: String, in directory: URL) throws -> URL {
        let fileName = "test-\(UUID().uuidString).\(`extension`)"
        let fileURL = directory.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    static func createTestImage(size: CGSize = CGSize(width: 10, height: 10), color: UIColor = .red) -> UIImage {
        UIGraphicsBeginImageContext(size)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
    
    static func verifyJSONSerialization<T: Codable>(_ object: T, type: T.Type) throws -> T {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        
        let data = try encoder.encode(object)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(type, from: data)
    }
    
    static func measureAsync<T>(operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Async operation took \(timeElapsed) seconds")
        return result
    }
}

// MARK: - Performance Testing Helpers

class PerformanceTestHelper {
    
    static func measureEventCreation(count: Int, eventManager: EventManager) async -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<count {
            do {
                _ = try await eventManager.createEvent(
                    type: .general,
                    title: "Performance Event \(i)",
                    notes: "Performance testing event"
                )
            } catch {
                print("Performance test event creation failed: \(error)")
            }
        }
        
        return CFAbsoluteTimeGetCurrent() - startTime
    }
    
    static func measureChainVerification(events: [ForensicEvent]) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = CryptoUtils.verifyEventChain(events)
        return CFAbsoluteTimeGetCurrent() - startTime
    }
    
    static func measureHashCalculation(event: ForensicEvent, iterations: Int = 1000) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            _ = CryptoUtils.calculateEventHash(event)
        }
        
        return CFAbsoluteTimeGetCurrent() - startTime
    }
}

// MARK: - Test Constants

struct TestConstants {
    static let maxFileSize: Int64 = 10 * 1024 * 1024 // 10MB
    static let maxTitleLength = 200
    static let maxNotesLength = 10000
    static let sha256Length = 64
    
    static let testStrings = [
        "Simple ASCII text",
        "Text with émojis 🔒🛡️💼",
        "Unicode text: 中文 العربية Русский",
        "Special chars: !@#$%^&*()_+-=[]{}|;':\",./<>?",
        "Newlines\nand\ttabs",
        String(repeating: "a", count: 1000), // Long string
        "" // Empty string
    ]
}

// MARK: - Mock Implementations for Testing

class MockAttachmentManager {
    var shouldFailProcessing = false
    var processingDelay: TimeInterval = 0
    
    func processImageAttachment(_ image: UIImage, filename: String? = nil) async throws -> EventAttachment {
        if shouldFailProcessing {
            throw AttachmentError.compressionFailed
        }
        
        if processingDelay > 0 {
            try await Task.sleep(for: .seconds(processingDelay))
        }
        
        return TestDataFactory.createTestAttachment(
            filename: filename ?? "test.jpg",
            mimeType: "image/jpeg"
        )
    }
}

class MockLocationManager {
    var shouldFailLocationRequest = false
    var mockLocation: EventLocation?
    
    func getCurrentLocation() async throws -> EventLocation {
        if shouldFailLocationRequest {
            throw LocationError.unavailable
        }
        
        return mockLocation ?? EventLocation(
            latitude: 0.0,
            longitude: 0.0,
            accuracyMeters: 5.0,
            altitudeMeters: nil,
            altitudeAccuracyMeters: nil,
            headingDegrees: nil,
            speedMPS: nil,
            capturedAt: Date(),
            source: .gps,
            address: nil
        )
    }
}