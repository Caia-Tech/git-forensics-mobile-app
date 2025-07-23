//
//  GitManager.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation

#if os(macOS)
// Process is not available in sandboxed macOS apps
#endif

class GitManager {
    static let shared = GitManager()
    
    private let fileManager = FileManager.default
    private let repositoryName = ".git-forensics"
    
    private init() {}
    
    /// Get the path to the Git repository
    var repositoryPath: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(repositoryName)
    }
    
    /// Initialize a new Git repository if it doesn't exist
    func initializeRepository() throws {
        let repoPath = repositoryPath
        
        // Create repository directory if it doesn't exist
        if !fileManager.fileExists(atPath: repoPath.path) {
            try fileManager.createDirectory(at: repoPath, withIntermediateDirectories: true)
            
            // Initialize git repository
            let result = shell("cd '\(repoPath.path)' && git init")
            if !result.success {
                throw GitError.initializationFailed(result.error ?? "Unknown error")
            }
            
            // Configure git user (device-specific)
            let deviceId = DeviceInfo.shared.deviceId.uuidString
            _ = shell("cd '\(repoPath.path)' && git config user.name 'Device \(deviceId.prefix(8))'")
            _ = shell("cd '\(repoPath.path)' && git config user.email '\(deviceId)@device.local'")
            
            // Create directory structure
            try createDirectoryStructure()
            
            // Create initial commit
            let readme = """
            # Git Forensics Repository
            
            This repository contains tamper-evident records created by Git Forensics Mobile.
            
            Device ID: \(deviceId)
            Created: \(ISO8601DateFormatter().string(from: Date()))
            """
            
            let readmePath = repoPath.appendingPathComponent("README.md")
            try readme.write(to: readmePath, atomically: true, encoding: .utf8)
            
            _ = shell("cd '\(repoPath.path)' && git add README.md")
            _ = shell("cd '\(repoPath.path)' && git commit -m 'Initial repository creation'")
        }
    }
    
    /// Create the directory structure for events and attachments
    private func createDirectoryStructure() throws {
        let directories = ["events", "attachments", "metadata", "exports"]
        
        for dir in directories {
            let dirPath = repositoryPath.appendingPathComponent(dir)
            try fileManager.createDirectory(at: dirPath, withIntermediateDirectories: true)
            
            // Add .gitkeep to maintain empty directories
            let gitkeepPath = dirPath.appendingPathComponent(".gitkeep")
            try "".write(to: gitkeepPath, atomically: true, encoding: .utf8)
        }
    }
    
    /// Save an event to the repository and commit it
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
        
        // Git add and commit
        let relativePath = eventPath.path.replacingOccurrences(of: repositoryPath.path + "/", with: "")
        let addResult = shell("cd '\(repositoryPath.path)' && git add '\(relativePath)'")
        
        if !addResult.success {
            throw GitError.addFailed(addResult.error ?? "Failed to add file")
        }
        
        // Create commit message
        let commitMessage = createCommitMessage(for: event)
        let commitResult = shell("cd '\(repositoryPath.path)' && git commit -m '\(commitMessage)'")
        
        if !commitResult.success {
            throw GitError.commitFailed(commitResult.error ?? "Failed to commit")
        }
    }
    
    /// Create a commit message for an event
    private func createCommitMessage(for event: ForensicEvent) -> String {
        let title = event.title.count > 50 ? String(event.title.prefix(47)) + "..." : event.title
        let notes = event.notes.count > 200 ? String(event.notes.prefix(197)) + "..." : event.notes
        
        var message = """
        Event: \(event.type.rawValue) - \(title)
        ID: \(event.id.uuidString)
        Time: \(ISO8601DateFormatter().string(from: event.createdAt))
        Hash: \(event.integrity.contentHash)
        """
        
        if event.title.count > 50 {
            message += "\n\n\(event.title)"
        }
        
        if !event.notes.isEmpty {
            message += "\n\(notes)"
        }
        
        return message.replacingOccurrences(of: "'", with: "'\"'\"'") // Escape single quotes
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
        
        // Recursively find all .json files in events directory
        let enumerator = fileManager.enumerator(at: eventsDir, includingPropertiesForKeys: nil)
        
        while let fileURL = enumerator?.nextObject() as? URL {
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
        
        // Sort by creation date (newest first)
        events.sort { $0.createdAt > $1.createdAt }
        
        return events
    }
    
    /// Execute a shell command - disabled in sandboxed environments
    private func shell(_ command: String) -> (success: Bool, output: String?, error: String?) {
        // Shell commands are not available in sandboxed iOS/macOS environments
        // This is a stub implementation for Git functionality
        return (false, nil, "Shell commands not available in sandboxed environments")
    }
}

enum GitError: LocalizedError {
    case initializationFailed(String)
    case addFailed(String)
    case commitFailed(String)
    case repositoryNotFound
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Failed to initialize repository: \(message)"
        case .addFailed(let message):
            return "Failed to add file: \(message)"
        case .commitFailed(let message):
            return "Failed to commit: \(message)"
        case .repositoryNotFound:
            return "Repository not found"
        }
    }
}