//
//  GitHubAPIService.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation
import CryptoKit

// MARK: - GitHub API Models

struct GitHubUser: Codable {
    let login: String
    let id: Int
    let name: String?
    let email: String?
}

struct GitHubRepository: Codable {
    let id: Int
    let name: String
    let fullName: String
    let htmlURL: String
    let isPrivate: Bool
    let defaultBranch: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "full_name"
        case htmlURL = "html_url"
        case isPrivate = "private"
        case defaultBranch = "default_branch"
    }
}

struct GitHubCreateRepoRequest: Codable {
    let name: String
    let description: String
    let isPrivate: Bool
    let autoInit: Bool
    
    enum CodingKeys: String, CodingKey {
        case name, description
        case isPrivate = "private"
        case autoInit = "auto_init"
    }
}

struct GitHubFile: Codable {
    let name: String
    let path: String
    let sha: String?
    let size: Int
    let url: String
    let htmlURL: String
    let downloadURL: String?
    
    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, url
        case htmlURL = "html_url"
        case downloadURL = "download_url"
    }
}

struct GitHubCreateFileRequest: Codable {
    let message: String
    let content: String // Base64 encoded
    let branch: String?
    let sha: String? // For updates
}

struct GitHubCommitResponse: Codable {
    let content: GitHubFile
    let commit: GitHubCommit
}

struct GitHubCommit: Codable {
    let sha: String
    let url: String
    let message: String
}

// MARK: - GitHub API Service

class GitHubAPIService {
    static let shared = GitHubAPIService()
    
    private let baseURL = "https://api.github.com"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Authentication
    
    func validateToken(_ token: String) async throws -> GitHubUser {
        let url = URL(string: "\(baseURL)/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw GitHubAPIError.invalidToken
            }
            throw GitHubAPIError.apiError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }
    
    // MARK: - Repository Management
    
    func createRepository(name: String, description: String, token: String) async throws -> GitHubRepository {
        let url = URL(string: "\(baseURL)/user/repos")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let createRequest = GitHubCreateRepoRequest(
            name: name,
            description: description,
            isPrivate: true,
            autoInit: false // We'll create our own initial commit
        )
        
        request.httpBody = try JSONEncoder().encode(createRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.networkError
        }
        
        guard httpResponse.statusCode == 201 else {
            if httpResponse.statusCode == 422 {
                throw GitHubAPIError.repositoryExists
            }
            throw GitHubAPIError.apiError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        return try JSONDecoder().decode(GitHubRepository.self, from: data)
    }
    
    func getRepository(owner: String, name: String, token: String) async throws -> GitHubRepository {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(name)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw GitHubAPIError.repositoryNotFound
            }
            throw GitHubAPIError.apiError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        return try JSONDecoder().decode(GitHubRepository.self, from: data)
    }
    
    // MARK: - File Operations
    
    func createFile(
        owner: String,
        repo: String,
        path: String,
        content: Data,
        message: String,
        token: String
    ) async throws -> GitHubCommitResponse {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let base64Content = content.base64EncodedString()
        let createRequest = GitHubCreateFileRequest(
            message: message,
            content: base64Content,
            branch: nil,
            sha: nil
        )
        
        request.httpBody = try JSONEncoder().encode(createRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.networkError
        }
        
        guard httpResponse.statusCode == 201 else {
            throw GitHubAPIError.apiError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        return try JSONDecoder().decode(GitHubCommitResponse.self, from: data)
    }
    
    func updateFile(
        owner: String,
        repo: String,
        path: String,
        content: Data,
        message: String,
        sha: String,
        token: String
    ) async throws -> GitHubCommitResponse {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let base64Content = content.base64EncodedString()
        let updateRequest = GitHubCreateFileRequest(
            message: message,
            content: base64Content,
            branch: nil,
            sha: sha
        )
        
        request.httpBody = try JSONEncoder().encode(updateRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GitHubAPIError.apiError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        return try JSONDecoder().decode(GitHubCommitResponse.self, from: data)
    }
    
    func getFile(
        owner: String,
        repo: String,
        path: String,
        token: String
    ) async throws -> GitHubFile? {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.networkError
        }
        
        if httpResponse.statusCode == 404 {
            return nil // File doesn't exist
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GitHubAPIError.apiError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        return try JSONDecoder().decode(GitHubFile.self, from: data)
    }
}

// MARK: - Errors

enum GitHubAPIError: LocalizedError {
    case networkError
    case invalidToken
    case repositoryExists
    case repositoryNotFound
    case rateLimited
    case apiError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed. Please check your internet connection."
        case .invalidToken:
            return "Invalid GitHub token. Please check your personal access token."
        case .repositoryExists:
            return "A repository with this name already exists."
        case .repositoryNotFound:
            return "Repository not found. It may have been deleted or you don't have access."
        case .rateLimited:
            return "Too many requests. Please wait a moment before trying again."
        case .apiError(let code, let message):
            return "GitHub API error (\(code)): \(message)"
        }
    }
}