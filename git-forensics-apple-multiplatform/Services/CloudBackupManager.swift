//
//  CloudBackupManager.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Cloud Provider Types

enum CloudProvider: String, CaseIterable {
    case github = "GitHub"
    case gitlab = "GitLab"
    
    var displayName: String { rawValue }
    var icon: String {
        switch self {
        case .github: return "cloud"
        case .gitlab: return "cloud.fill"
        }
    }
    
    var baseURL: String {
        switch self {
        case .github: return "https://api.github.com"
        case .gitlab: return "https://gitlab.com/api/v4"
        }
    }
    
    var oauthURL: String {
        switch self {
        case .github: return "https://github.com/login/oauth/authorize"
        case .gitlab: return "https://gitlab.com/oauth/authorize"
        }
    }
}

// MARK: - Backup Status

enum BackupStatus {
    case notConnected
    case connecting
    case syncing(progress: Double)
    case synced(lastSync: Date)
    case error(String)
    
    var displayText: String {
        switch self {
        case .notConnected:
            return "Not connected"
        case .connecting:
            return "Connecting..."
        case .syncing(let progress):
            return "Uploading \(Int(progress * 100))%..."
        case .synced(let lastSync):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Backed up \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        case .error(let message):
            return message
        }
    }
    
    var icon: String {
        switch self {
        case .notConnected: return "cloud.slash"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .syncing: return "arrow.up.circle"
        case .synced: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .notConnected: return .gray
        case .connecting: return .blue
        case .syncing: return .orange
        case .synced: return .green
        case .error: return .red
        }
    }
}

// MARK: - Cloud Backup Manager

@MainActor
class CloudBackupManager: ObservableObject {
    static let shared = CloudBackupManager()
    
    @Published var isConnected = false
    @Published var currentProvider: CloudProvider?
    @Published var backupStatus: BackupStatus = .notConnected
    @Published var lastSyncDate: Date?
    @Published var syncProgress: Double = 0.0
    @Published var autoSync = true
    @Published var includeAttachments = false
    @Published var repositoryName: String = ""
    @Published var repositoryURL: String = ""
    
    // OAuth tokens stored in Keychain
    @AppStorage("cloudBackup.provider") private var storedProvider: String = ""
    @AppStorage("cloudBackup.repoName") private var storedRepoName: String = ""
    @AppStorage("cloudBackup.repoURL") private var storedRepoURL: String = ""
    @AppStorage("cloudBackup.autoSync") private var storedAutoSync: Bool = true
    @AppStorage("cloudBackup.includeAttachments") private var storedIncludeAttachments: Bool = false
    
    private var accessToken: String?
    private var refreshToken: String?
    private let keychain = KeychainManager.shared
    private let githubAPI = GitHubAPIService.shared
    private var currentUser: GitHubUser?
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration
    
    private func loadConfiguration() {
        if let provider = CloudProvider(rawValue: storedProvider) {
            currentProvider = provider
            repositoryName = storedRepoName
            repositoryURL = storedRepoURL
            autoSync = storedAutoSync
            includeAttachments = storedIncludeAttachments
            
            // Load tokens from keychain
            if let token = keychain.getToken(for: provider) {
                accessToken = token
                currentUser = keychain.getUserInfo(for: provider)
                isConnected = true
                backupStatus = .synced(lastSync: Date()) // TODO: Load actual last sync date
            }
        }
    }
    
    private func saveConfiguration() {
        storedProvider = currentProvider?.rawValue ?? ""
        storedRepoName = repositoryName
        storedRepoURL = repositoryURL
        storedAutoSync = autoSync
        storedIncludeAttachments = includeAttachments
    }
    
    // MARK: - Authentication
    
    func connectWithToken(_ token: String, provider: CloudProvider) async throws {
        currentProvider = provider
        backupStatus = .connecting
        
        do {
            // Validate token and get user info
            let user = try await githubAPI.validateToken(token)
            currentUser = user
            accessToken = token
            
            // Store in keychain
            guard keychain.setToken(token, for: provider),
                  keychain.setUserInfo(user, for: provider) else {
                throw CloudBackupError.authenticationFailed
            }
            
            // Generate repository name
            let deviceName = DeviceInfo.shared.deviceModel.replacingOccurrences(of: " ", with: "-").lowercased()
            let dateString = ISO8601DateFormatter().string(from: Date()).prefix(10)
            repositoryName = "forensic-records-\(deviceName)-\(dateString)"
            
            // Create repository
            try await createRepository()
            
            // Update state
            isConnected = true
            backupStatus = .synced(lastSync: Date())
            saveConfiguration()
            
        } catch let error as GitHubAPIError {
            backupStatus = .error(error.localizedDescription ?? "Connection failed")
            throw error
        } catch {
            backupStatus = .error("Connection failed")
            throw CloudBackupError.authenticationFailed
        }
    }
    
    func connectProvider(_ provider: CloudProvider) async throws {
        // This method is kept for compatibility with existing UI
        // In practice, we'll use connectWithToken for real authentication
        throw CloudBackupError.authenticationFailed
    }
    
    func disconnect() {
        guard let provider = currentProvider else { return }
        
        // Clear tokens from keychain
        keychain.deleteToken(for: provider)
        keychain.deleteUserInfo(for: provider)
        
        // Reset state
        isConnected = false
        currentProvider = nil
        currentUser = nil
        accessToken = nil
        refreshToken = nil
        repositoryName = ""
        repositoryURL = ""
        backupStatus = .notConnected
        
        saveConfiguration()
    }
    
    // MARK: - Repository Management
    
    private func createRepository() async throws {
        guard let provider = currentProvider,
              let token = accessToken,
              let user = currentUser else { 
            throw CloudBackupError.authenticationFailed
        }
        
        // Only support GitHub for now
        guard provider == .github else {
            throw CloudBackupError.repositoryCreationFailed
        }
        
        do {
            // Check if repository already exists
            if let existingRepo = try? await githubAPI.getRepository(
                owner: user.login,
                name: repositoryName,
                token: token
            ) {
                repositoryURL = existingRepo.htmlURL
                return // Repository already exists, use it
            }
            
            // Create new repository
            let description = "Tamper-evident forensic records backup from \(DeviceInfo.shared.deviceModel)"
            let repository = try await githubAPI.createRepository(
                name: repositoryName,
                description: description,
                token: token
            )
            
            repositoryURL = repository.htmlURL
            
            // Create initial README
            let readme = """
            # Forensic Records Backup
            
            This repository contains tamper-evident forensic records created by Git Forensics Mobile.
            
            ## Verification
            
            Each event is cryptographically linked using SHA-256 hashes. Any modification to the records will be immediately detectable.
            
            ## Privacy
            
            This is a private repository. Only you have access to these records unless you explicitly share them.
            
            ## Device Information
            
            - **Device**: \(DeviceInfo.shared.deviceModel)
            - **Created**: \(ISO8601DateFormatter().string(from: Date()))
            - **User**: \(user.name ?? user.login)
            
            ---
            
            Created by [Git Forensics Mobile](https://github.com/caiatech/git-forensics-mobile)
            """
            
            // Create initial README file
            _ = try await githubAPI.createFile(
                owner: user.login,
                repo: repositoryName,
                path: "README.md",
                content: readme.data(using: .utf8)!,
                message: "Initial commit: Setup forensic records repository",
                token: token
            )
            
        } catch let error as GitHubAPIError {
            throw error
        } catch {
            throw CloudBackupError.repositoryCreationFailed
        }
    }
    
    // MARK: - Sync Operations
    
    func syncNow() async throws {
        guard isConnected else {
            throw CloudBackupError.notConnected
        }
        
        backupStatus = .syncing(progress: 0)
        
        // Get events that need syncing
        let events = EventManager.shared.events
        let totalEvents = events.count
        
        for (index, event) in events.enumerated() {
            // Update progress
            let progress = Double(index + 1) / Double(totalEvents)
            await MainActor.run {
                self.syncProgress = progress
                self.backupStatus = .syncing(progress: progress)
            }
            
            // Upload event
            try await uploadEvent(event)
            
            // Small delay to prevent rate limiting
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Update status
        lastSyncDate = Date()
        backupStatus = .synced(lastSync: Date())
    }
    
    private func uploadEvent(_ event: ForensicEvent) async throws {
        guard let token = accessToken,
              let user = currentUser else {
            throw CloudBackupError.authenticationFailed
        }
        
        // Convert event to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let eventData = try encoder.encode(event)
        
        // Create file path
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: event.createdAt)
        let year = components.year ?? 0
        let month = String(format: "%02d", components.month ?? 0)
        let day = String(format: "%02d", components.day ?? 0)
        let filePath = "events/\(year)/\(month)/\(day)/\(event.id.uuidString).json"
        
        // Create commit message
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: event.createdAt)
        let commitMessage = "Add forensic event: \(event.title) (\(dateString))"
        
        do {
            // Check if file already exists (for updates)
            if let existingFile = try await githubAPI.getFile(
                owner: user.login,
                repo: repositoryName,
                path: filePath,
                token: token
            ) {
                // Update existing file
                _ = try await githubAPI.updateFile(
                    owner: user.login,
                    repo: repositoryName,
                    path: filePath,
                    content: eventData,
                    message: "Update \(commitMessage)",
                    sha: existingFile.sha ?? "",
                    token: token
                )
            } else {
                // Create new file
                _ = try await githubAPI.createFile(
                    owner: user.login,
                    repo: repositoryName,
                    path: filePath,
                    content: eventData,
                    message: commitMessage,
                    token: token
                )
            }
        } catch let error as GitHubAPIError {
            throw error
        } catch {
            throw CloudBackupError.networkError
        }
    }
    
    // MARK: - Auto Sync
    
    func handleEventCreated(_ event: ForensicEvent) {
        guard autoSync && isConnected else { return }
        
        Task {
            do {
                backupStatus = .syncing(progress: 0.5)
                try await uploadEvent(event)
                backupStatus = .synced(lastSync: Date())
            } catch {
                backupStatus = .error("Backup failed - will retry")
                // TODO: Add retry logic
            }
        }
    }
    
    // MARK: - Share Evidence
    
    func generateShareLink(for events: [ForensicEvent]) async throws -> URL {
        guard isConnected else {
            throw CloudBackupError.notConnected
        }
        
        // TODO: Create a public gist or temporary branch with selected events
        // For now, return a placeholder URL
        return URL(string: repositoryURL)!
    }
}

// MARK: - Errors

enum CloudBackupError: LocalizedError {
    case notConnected
    case authenticationFailed
    case networkError
    case rateLimited
    case repositoryCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Please connect to a cloud backup service first"
        case .authenticationFailed:
            return "Could not connect to your account. Please try again."
        case .networkError:
            return "No internet connection. Your records will backup when connected."
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .repositoryCreationFailed:
            return "Could not create backup location. Please try again."
        }
    }
}

