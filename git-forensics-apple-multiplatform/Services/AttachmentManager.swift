//
//  AttachmentManager.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation
import CryptoKit
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

class AttachmentManager {
    static let shared = AttachmentManager()
    
    private let fileManager = FileManager.default
    private let gitManager = SimpleGitManager.shared
    
    private init() {}
    
    /// Maximum file size (10 MB)
    private let maxFileSize: Int64 = 10 * 1024 * 1024
    
    /// Process and save an image attachment
    func processImageAttachment(_ image: PlatformImage, filename: String? = nil) async throws -> EventAttachment {
        // Compress image to JPEG with reasonable quality
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AttachmentError.compressionFailed
        }
        
        // Check file size
        if imageData.count > maxFileSize {
            throw AttachmentError.fileTooLarge
        }
        
        // Generate filename if not provided
        let finalFilename = filename ?? "IMG_\(Date().timeIntervalSince1970).jpg"
        
        // Calculate hash
        let hash = CryptoUtils.sha256Hash(of: imageData)
        
        // Save to attachments directory
        let attachmentPath = try saveAttachmentData(imageData, hash: hash, fileExtension: "jpg")
        
        // Create attachment record
        let attachment = EventAttachment(
            filename: finalFilename,
            mimeType: "image/jpeg",
            sizeBytes: Int64(imageData.count),
            hashSHA256: hash,
            storagePath: attachmentPath.lastPathComponent
        )
        
        return attachment
    }
    
    /// Process a file attachment from a URL
    func processFileAttachment(from url: URL) async throws -> EventAttachment {
        // Start accessing security-scoped resource if needed
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Get file attributes
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Check file size
        if fileSize > maxFileSize {
            throw AttachmentError.fileTooLarge
        }
        
        // Read file data
        let fileData = try Data(contentsOf: url)
        
        // Calculate hash
        let hash = CryptoUtils.sha256Hash(of: fileData)
        
        // Determine MIME type
        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        
        // Save to attachments directory
        let attachmentPath = try saveAttachmentData(fileData, hash: hash, fileExtension: url.pathExtension)
        
        // Create attachment record
        let attachment = EventAttachment(
            filename: url.lastPathComponent,
            mimeType: mimeType,
            sizeBytes: fileSize,
            hashSHA256: hash,
            storagePath: attachmentPath.lastPathComponent
        )
        
        return attachment
    }
    
    /// Save attachment data to the repository
    private func saveAttachmentData(_ data: Data, hash: String, fileExtension: String) throws -> URL {
        let attachmentsDir = gitManager.repositoryPath.appendingPathComponent("attachments")
        
        // Create date-based subdirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let datePath = dateFormatter.string(from: Date())
        
        let targetDir = attachmentsDir.appendingPathComponent(datePath)
        try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        // Use hash as filename to prevent duplicates
        let filename = "\(hash).\(fileExtension)"
        let targetPath = targetDir.appendingPathComponent(filename)
        
        // If file already exists with same hash, no need to save again
        if !fileManager.fileExists(atPath: targetPath.path) {
            try data.write(to: targetPath)
        }
        
        return targetPath
    }
    
    /// Load attachment data
    func loadAttachmentData(for attachment: EventAttachment) throws -> Data? {
        let attachmentsDir = gitManager.repositoryPath.appendingPathComponent("attachments")
        
        // Try to find the file by searching for the hash
        if let enumerator = fileManager.enumerator(at: attachmentsDir, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent.hasPrefix(attachment.hashSHA256) {
                    return try Data(contentsOf: fileURL)
                }
            }
        }
        
        return nil
    }
    
    /// Verify attachment integrity
    func verifyAttachment(_ attachment: EventAttachment) async -> Bool {
        do {
            guard let data = try loadAttachmentData(for: attachment) else {
                return false
            }
            
            let calculatedHash = CryptoUtils.sha256Hash(of: data)
            return calculatedHash == attachment.hashSHA256
        } catch {
            return false
        }
    }
    
    /// Get thumbnail for image attachment
    func getThumbnail(for attachment: EventAttachment, size: CGSize) async -> PlatformImage? {
        guard attachment.mimeType.hasPrefix("image/") else { return nil }
        
        do {
            guard let data = try loadAttachmentData(for: attachment) else { return nil }
            #if os(iOS)
            guard let image = UIImage(data: data) else { return nil }
            return await image.byPreparingThumbnail(ofSize: size)
            #elseif os(macOS)
            guard let image = NSImage(data: data) else { return nil }
            let resizedImage = NSImage(size: size)
            resizedImage.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: size))
            resizedImage.unlockFocus()
            return resizedImage
            #endif
        } catch {
            return nil
        }
    }
}

enum AttachmentError: LocalizedError {
    case compressionFailed
    case fileTooLarge
    case unsupportedType
    case saveFailed
    case loadFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .fileTooLarge:
            return "File size exceeds 10MB limit"
        case .unsupportedType:
            return "This file type is not supported"
        case .saveFailed:
            return "Failed to save attachment"
        case .loadFailed:
            return "Failed to load attachment"
        }
    }
}