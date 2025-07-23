//
//  SimpleGitManager.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation

class SimpleGitManager {
    static let shared = SimpleGitManager()
    
    private let fileManager = FileManager.default
    private let repositoryName = ".git-forensics"
    
    private init() {}
    
    /// Get the path to the repository
    var repositoryPath: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(repositoryName)
    }
    
    /// Initialize repository structure
    func initializeRepository() throws {
        let repoPath = repositoryPath
        
        // Create repository directory if it doesn't exist
        if !fileManager.fileExists(atPath: repoPath.path) {
            try fileManager.createDirectory(at: repoPath, withIntermediateDirectories: true)
            
            // Create directory structure
            try createDirectoryStructure()
            
            // Create repository metadata
            let metadata = RepositoryMetadata(
                version: "1.0",
                createdAt: Date(),
                deviceId: DeviceInfo.shared.deviceId
            )
            
            let metadataPath = repoPath.appendingPathComponent("metadata/repository.json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            
            let metadataData = try encoder.encode(metadata)
            try metadataData.write(to: metadataPath)
            
            // Create initial README
            let readme = """
            # Git Forensics Repository
            
            This repository contains tamper-evident records created by Git Forensics Mobile.
            
            Device ID: \(DeviceInfo.shared.deviceId)
            Created: \(ISO8601DateFormatter().string(from: Date()))
            Version: 1.0
            
            ## Structure
            - `/events` - Forensic event records
            - `/attachments` - File attachments with hashes
            - `/metadata` - Repository metadata and chain information
            
            ## Verification
            Each event is cryptographically linked to the previous one, creating an immutable chain.
            """
            
            let readmePath = repoPath.appendingPathComponent("README.md")
            try readme.write(to: readmePath, atomically: true, encoding: .utf8)
        }
    }
    
    /// Create the directory structure
    private func createDirectoryStructure() throws {
        let directories = ["events", "attachments", "metadata", "exports", "commits"]
        
        for dir in directories {
            let dirPath = repositoryPath.appendingPathComponent(dir)
            if !fileManager.fileExists(atPath: dirPath.path) {
                try fileManager.createDirectory(at: dirPath, withIntermediateDirectories: true)
            }
        }
    }
    
    /// Save an event to the repository
    func saveEvent(_ event: ForensicEvent) throws {
        // Create date-based directory structure
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: event.createdAt)
        
        let eventDir = repositoryPath
            .appendingPathComponent("events")
            .appendingPathComponent(String(format: "%04d", components.year ?? 0))
            .appendingPathComponent(String(format: "%02d", components.month ?? 0))
            .appendingPathComponent(String(format: "%02d", components.day ?? 0))
        
        try fileManager.createDirectory(at: eventDir, withIntermediateDirectories: true)
        
        // Save event JSON
        let eventPath = eventDir.appendingPathComponent("\(event.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        
        let eventData = try encoder.encode(event)
        try eventData.write(to: eventPath)
        
        // Create commit record
        try createCommitRecord(for: event)
        
        // Update chain metadata
        try updateChainMetadata(with: event)
    }
    
    /// Create a commit record (simulating Git commit)
    private func createCommitRecord(for event: ForensicEvent) throws {
        let commit = CommitRecord(
            id: UUID(),
            timestamp: Date(),
            eventId: event.id,
            eventHash: event.integrity.contentHash,
            message: createCommitMessage(for: event),
            author: "Device \(DeviceInfo.shared.deviceId.uuidString.prefix(8))"
        )
        
        let commitsDir = repositoryPath.appendingPathComponent("commits")
        let commitPath = commitsDir.appendingPathComponent("\(commit.id.uuidString).json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let commitData = try encoder.encode(commit)
        try commitData.write(to: commitPath)
    }
    
    /// Update chain metadata
    private func updateChainMetadata(with event: ForensicEvent) throws {
        let metadataPath = repositoryPath.appendingPathComponent("metadata/chain.json")
        
        var chain: ChainMetadata
        
        if fileManager.fileExists(atPath: metadataPath.path) {
            let data = try Data(contentsOf: metadataPath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            chain = try decoder.decode(ChainMetadata.self, from: data)
        } else {
            chain = ChainMetadata(events: [], lastEventId: nil, lastEventHash: nil)
        }
        
        // Add event to chain
        chain.events.append(ChainEntry(
            eventId: event.id,
            eventHash: event.integrity.contentHash,
            timestamp: event.createdAt,
            eventNumber: event.chain?.eventNumber ?? 1
        ))
        chain.lastEventId = event.id
        chain.lastEventHash = event.integrity.contentHash
        
        // Save updated chain
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let chainData = try encoder.encode(chain)
        try chainData.write(to: metadataPath)
    }
    
    /// Create a commit message for an event
    private func createCommitMessage(for event: ForensicEvent) -> String {
        let title = event.title.count > 50 ? String(event.title.prefix(47)) + "..." : event.title
        return "Event: \(event.type.rawValue) - \(title)"
    }
    
    /// Load all events from the repository
    func loadAllEvents() throws -> [ForensicEvent] {
        var events: [ForensicEvent] = []
        let eventsDir = repositoryPath.appendingPathComponent("events")
        
        guard fileManager.fileExists(atPath: eventsDir.path) else {
            return events
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Recursively find all .json files
        if let enumerator = fileManager.enumerator(at: eventsDir, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "json" {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let event = try decoder.decode(ForensicEvent.self, from: data)
                        events.append(event)
                    } catch {
                        print("Failed to decode event at \(fileURL): \(error)")
                    }
                }
            }
        }
        
        // Sort by creation date (newest first)
        events.sort { $0.createdAt > $1.createdAt }
        
        return events
    }
}

// MARK: - Supporting Types

struct RepositoryMetadata: Codable {
    let version: String
    let createdAt: Date
    let deviceId: UUID
}

struct CommitRecord: Codable {
    let id: UUID
    let timestamp: Date
    let eventId: UUID
    let eventHash: String
    let message: String
    let author: String
}

struct ChainMetadata: Codable {
    var events: [ChainEntry]
    var lastEventId: UUID?
    var lastEventHash: String?
}

struct ChainEntry: Codable {
    let eventId: UUID
    let eventHash: String
    let timestamp: Date
    let eventNumber: Int
}