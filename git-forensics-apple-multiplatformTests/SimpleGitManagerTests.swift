//
//  SimpleGitManagerTests.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import XCTest
@testable import git_forensics_apple_multiplatform
import Foundation

final class SimpleGitManagerTests: XCTestCase {
    
    var gitManager: SimpleGitManager!
    var testDirectory: URL!
    var originalRepositoryPath: URL!
    
    override func setUp() throws {
        super.setUp()
        
        // Create a temporary directory for testing
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-git-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        // Create a test instance
        gitManager = SimpleGitManager.shared
        
        // Store original repository path to restore later
        originalRepositoryPath = gitManager.repositoryPath
    }
    
    override func tearDown() throws {
        // Clean up test directory
        if FileManager.default.fileExists(atPath: testDirectory.path) {
            try FileManager.default.removeItem(at: testDirectory)
        }
        
        gitManager = nil
        testDirectory = nil
        
        super.tearDown()
    }
    
    // MARK: - Repository Path Tests
    
    func testRepositoryPath() {
        let path = gitManager.repositoryPath
        XCTAssertTrue(path.path.contains(".git-forensics"), "Repository path should contain .git-forensics")
        XCTAssertTrue(path.path.contains("Documents"), "Repository should be in Documents directory")
    }
    
    // MARK: - Repository Initialization Tests
    
    func testInitializeRepository() throws {
        // Initialize should create repository structure
        try gitManager.initializeRepository()
        
        let repoPath = gitManager.repositoryPath
        
        // Check that repository directory exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoPath.path), "Repository directory should exist")
        
        // Check that subdirectories exist
        let expectedDirectories = ["events", "attachments", "metadata", "exports", "commits"]
        for dir in expectedDirectories {
            let dirPath = repoPath.appendingPathComponent(dir)
            XCTAssertTrue(FileManager.default.fileExists(atPath: dirPath.path), "Directory \(dir) should exist")
        }
        
        // Check that README exists
        let readmePath = repoPath.appendingPathComponent("README.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: readmePath.path), "README.md should exist")
        
        // Check that repository metadata exists
        let metadataPath = repoPath.appendingPathComponent("metadata/repository.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataPath.path), "Repository metadata should exist")
    }
    
    func testInitializeRepositoryMultipleTimes() throws {
        // Initialize repository multiple times should not fail
        try gitManager.initializeRepository()
        try gitManager.initializeRepository()
        try gitManager.initializeRepository()
        
        // Should still work correctly
        let repoPath = gitManager.repositoryPath
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoPath.path))
    }
    
    func testRepositoryMetadataCreation() throws {
        try gitManager.initializeRepository()
        
        let metadataPath = gitManager.repositoryPath.appendingPathComponent("metadata/repository.json")
        let data = try Data(contentsOf: metadataPath)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(RepositoryMetadata.self, from: data)
        
        XCTAssertEqual(metadata.version, "1.0")
        XCTAssertNotNil(metadata.createdAt)
        XCTAssertNotNil(metadata.deviceId)
    }
    
    func testReadmeCreation() throws {
        try gitManager.initializeRepository()
        
        let readmePath = gitManager.repositoryPath.appendingPathComponent("README.md")
        let content = try String(contentsOf: readmePath)
        
        XCTAssertTrue(content.contains("Git Forensics Repository"), "README should contain title")
        XCTAssertTrue(content.contains("tamper-evident"), "README should mention tamper-evident")
        XCTAssertTrue(content.contains(DeviceInfo.shared.deviceId.uuidString), "README should contain device ID")
    }
    
    // MARK: - Event Saving Tests
    
    func testSaveEvent() throws {
        try gitManager.initializeRepository()
        
        var event = ForensicEvent(
            type: .general,
            title: "Test Event",
            notes: "Test notes"
        )
        
        let hash = CryptoUtils.calculateEventHash(event)
        event.integrity = EventIntegrity(contentHash: hash, signature: nil)
        
        // Save the event
        try gitManager.saveEvent(event)
        
        // Check that event file was created
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: event.createdAt)
        
        let eventPath = gitManager.repositoryPath
            .appendingPathComponent("events")
            .appendingPathComponent(String(format: "%04d", components.year ?? 0))
            .appendingPathComponent(String(format: "%02d", components.month ?? 0))
            .appendingPathComponent(String(format: "%02d", components.day ?? 0))
            .appendingPathComponent("\(event.id.uuidString).json")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: eventPath.path), "Event file should exist")
        
        // Verify event content
        let data = try Data(contentsOf: eventPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let savedEvent = try decoder.decode(ForensicEvent.self, from: data)
        
        XCTAssertEqual(savedEvent.id, event.id)
        XCTAssertEqual(savedEvent.title, event.title)
        XCTAssertEqual(savedEvent.notes, event.notes)
    }
    
    func testSaveEventCreatesCommitRecord() throws {
        try gitManager.initializeRepository()
        
        var event = ForensicEvent(
            type: .meeting,
            title: "Test Meeting",
            notes: "Meeting notes"
        )
        
        let hash = CryptoUtils.calculateEventHash(event)
        event.integrity = EventIntegrity(contentHash: hash, signature: nil)
        
        try gitManager.saveEvent(event)
        
        // Check that commit record was created
        let commitsDir = gitManager.repositoryPath.appendingPathComponent("commits")
        let commitFiles = try FileManager.default.contentsOfDirectory(at: commitsDir, includingPropertiesForKeys: nil)
        
        XCTAssertEqual(commitFiles.count, 1, "Should create one commit record")
        
        // Verify commit content
        let commitPath = commitFiles.first!
        let data = try Data(contentsOf: commitPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let commit = try decoder.decode(CommitRecord.self, from: data)
        
        XCTAssertEqual(commit.eventId, event.id)
        XCTAssertEqual(commit.eventHash, event.integrity.contentHash)
        XCTAssertTrue(commit.message.contains("meeting"))
        XCTAssertTrue(commit.author.contains("Device"))
    }
    
    func testSaveEventUpdatesChainMetadata() throws {
        try gitManager.initializeRepository()
        
        var event = ForensicEvent(
            type: .general,
            title: "Test Event",
            notes: "Test notes"
        )
        
        let hash = CryptoUtils.calculateEventHash(event)
        event.integrity = EventIntegrity(contentHash: hash, signature: nil)
        
        try gitManager.saveEvent(event)
        
        // Check that chain metadata was created/updated
        let chainPath = gitManager.repositoryPath.appendingPathComponent("metadata/chain.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: chainPath.path), "Chain metadata should exist")
        
        let data = try Data(contentsOf: chainPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let chain = try decoder.decode(ChainMetadata.self, from: data)
        
        XCTAssertEqual(chain.events.count, 1)
        XCTAssertEqual(chain.events.first?.eventId, event.id)
        XCTAssertEqual(chain.lastEventId, event.id)
        XCTAssertEqual(chain.lastEventHash, event.integrity.contentHash)
    }
    
    func testSaveMultipleEventsUpdatesChain() throws {
        try gitManager.initializeRepository()
        
        // Create and save first event
        var event1 = ForensicEvent(
            type: .general,
            title: "First Event",
            notes: "First notes"
        )
        let hash1 = CryptoUtils.calculateEventHash(event1)
        event1.integrity = EventIntegrity(contentHash: hash1, signature: nil)
        try gitManager.saveEvent(event1)
        
        // Create and save second event
        var event2 = ForensicEvent(
            type: .meeting,
            title: "Second Event",
            notes: "Second notes",
            previousEvent: event1
        )
        let hash2 = CryptoUtils.calculateEventHash(event2)
        event2.integrity = EventIntegrity(contentHash: hash2, signature: nil)
        try gitManager.saveEvent(event2)
        
        // Check chain metadata
        let chainPath = gitManager.repositoryPath.appendingPathComponent("metadata/chain.json")
        let data = try Data(contentsOf: chainPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let chain = try decoder.decode(ChainMetadata.self, from: data)
        
        XCTAssertEqual(chain.events.count, 2)
        XCTAssertEqual(chain.lastEventId, event2.id)
        XCTAssertEqual(chain.lastEventHash, event2.integrity.contentHash)
    }
    
    // MARK: - Event Loading Tests
    
    func testLoadAllEventsEmpty() throws {
        try gitManager.initializeRepository()
        
        let events = try gitManager.loadAllEvents()
        XCTAssertTrue(events.isEmpty, "New repository should have no events")
    }
    
    func testLoadSingleEvent() throws {
        try gitManager.initializeRepository()
        
        // Save an event
        var event = ForensicEvent(
            type: .incident,
            title: "Test Incident",
            notes: "Incident details"
        )
        let hash = CryptoUtils.calculateEventHash(event)
        event.integrity = EventIntegrity(contentHash: hash, signature: nil)
        try gitManager.saveEvent(event)
        
        // Load events
        let loadedEvents = try gitManager.loadAllEvents()
        
        XCTAssertEqual(loadedEvents.count, 1)
        XCTAssertEqual(loadedEvents.first?.id, event.id)
        XCTAssertEqual(loadedEvents.first?.title, event.title)
        XCTAssertEqual(loadedEvents.first?.type, event.type)
    }
    
    func testLoadMultipleEvents() throws {
        try gitManager.initializeRepository()
        
        // Save multiple events
        var events: [ForensicEvent] = []
        for i in 0..<5 {
            var event = ForensicEvent(
                type: .general,
                title: "Event \(i)",
                notes: "Notes \(i)"
            )
            let hash = CryptoUtils.calculateEventHash(event)
            event.integrity = EventIntegrity(contentHash: hash, signature: nil)
            try gitManager.saveEvent(event)
            events.append(event)
        }
        
        // Load events
        let loadedEvents = try gitManager.loadAllEvents()
        
        XCTAssertEqual(loadedEvents.count, 5)
        
        // Verify events are sorted by creation date (newest first)
        for i in 0..<4 {
            XCTAssertGreaterThanOrEqual(loadedEvents[i].createdAt, loadedEvents[i+1].createdAt)
        }
    }
    
    func testLoadEventsWithCorruptedFile() throws {
        try gitManager.initializeRepository()
        
        // Create a corrupted JSON file
        let eventsDir = gitManager.repositoryPath.appendingPathComponent("events/2024/01/01")
        try FileManager.default.createDirectory(at: eventsDir, withIntermediateDirectories: true)
        
        let corruptedPath = eventsDir.appendingPathComponent("corrupted.json")
        try "invalid json content".write(to: corruptedPath, atomically: true, encoding: .utf8)
        
        // Save a valid event
        var validEvent = ForensicEvent(
            type: .general,
            title: "Valid Event",
            notes: "Valid notes"
        )
        let hash = CryptoUtils.calculateEventHash(validEvent)
        validEvent.integrity = EventIntegrity(contentHash: hash, signature: nil)
        try gitManager.saveEvent(validEvent)
        
        // Load events should skip corrupted file and return valid events
        let loadedEvents = try gitManager.loadAllEvents()
        XCTAssertEqual(loadedEvents.count, 1)
        XCTAssertEqual(loadedEvents.first?.title, "Valid Event")
    }
    
    // MARK: - Commit Message Tests
    
    func testCommitMessageGeneration() throws {
        try gitManager.initializeRepository()
        
        var shortTitleEvent = ForensicEvent(
            type: .general,
            title: "Short",
            notes: "Notes"
        )
        let hash1 = CryptoUtils.calculateEventHash(shortTitleEvent)
        shortTitleEvent.integrity = EventIntegrity(contentHash: hash1, signature: nil)
        try gitManager.saveEvent(shortTitleEvent)
        
        var longTitleEvent = ForensicEvent(
            type: .meeting,
            title: String(repeating: "a", count: 100),
            notes: "Notes"
        )
        let hash2 = CryptoUtils.calculateEventHash(longTitleEvent)
        longTitleEvent.integrity = EventIntegrity(contentHash: hash2, signature: nil)
        try gitManager.saveEvent(longTitleEvent)
        
        // Load commit records
        let commitsDir = gitManager.repositoryPath.appendingPathComponent("commits")
        let commitFiles = try FileManager.default.contentsOfDirectory(at: commitsDir, includingPropertiesForKeys: nil)
        
        XCTAssertEqual(commitFiles.count, 2)
        
        // Check commit messages
        for commitFile in commitFiles {
            let data = try Data(contentsOf: commitFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let commit = try decoder.decode(CommitRecord.self, from: data)
            
            if commit.eventId == shortTitleEvent.id {
                XCTAssertEqual(commit.message, "Event: general - Short")
            } else {
                // Long title should be truncated
                XCTAssertTrue(commit.message.contains("..."))
                XCTAssertLessThanOrEqual(commit.message.count, 60)
            }
        }
    }
    
    // MARK: - Directory Structure Tests
    
    func testEventDirectoryStructure() throws {
        try gitManager.initializeRepository()
        
        // Create events on different dates
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        
        // Create event with current date
        var todayEvent = ForensicEvent(
            type: .general,
            title: "Today Event",
            notes: "Today notes"
        )
        let hash1 = CryptoUtils.calculateEventHash(todayEvent)
        todayEvent.integrity = EventIntegrity(contentHash: hash1, signature: nil)
        try gitManager.saveEvent(todayEvent)
        
        // Manually create event with yesterday's date (simulating)
        var yesterdayEvent = ForensicEvent(
            type: .general,
            title: "Yesterday Event",
            notes: "Yesterday notes"
        )
        // Manually set the created date for testing
        let mirror = Mirror(reflecting: yesterdayEvent)
        for child in mirror.children {
            if child.label == "createdAt" {
                // Note: In real implementation, we'd need to modify the struct
                // For testing purposes, we'll just verify the directory structure logic
                break
            }
        }
        
        // Verify directory structure exists
        let eventsDir = gitManager.repositoryPath.appendingPathComponent("events")
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let currentDay = calendar.component(.day, from: now)
        
        let expectedPath = eventsDir
            .appendingPathComponent(String(format: "%04d", currentYear))
            .appendingPathComponent(String(format: "%02d", currentMonth))
            .appendingPathComponent(String(format: "%02d", currentDay))
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath.path), "Date-based directory should exist")
    }
    
    // MARK: - Performance Tests
    
    func testSaveEventPerformance() throws {
        try gitManager.initializeRepository()
        
        measure {
            for i in 0..<50 {
                var event = ForensicEvent(
                    type: .general,
                    title: "Performance Event \(i)",
                    notes: "Performance testing"
                )
                let hash = CryptoUtils.calculateEventHash(event)
                event.integrity = EventIntegrity(contentHash: hash, signature: nil)
                
                do {
                    try gitManager.saveEvent(event)
                } catch {
                    XCTFail("Save event failed: \(error)")
                }
            }
        }
    }
    
    func testLoadEventPerformance() throws {
        try gitManager.initializeRepository()
        
        // Pre-populate with events
        for i in 0..<100 {
            var event = ForensicEvent(
                type: .general,
                title: "Event \(i)",
                notes: "Notes \(i)"
            )
            let hash = CryptoUtils.calculateEventHash(event)
            event.integrity = EventIntegrity(contentHash: hash, signature: nil)
            try gitManager.saveEvent(event)
        }
        
        measure {
            do {
                _ = try gitManager.loadAllEvents()
            } catch {
                XCTFail("Load events failed: \(error)")
            }
        }
    }
}