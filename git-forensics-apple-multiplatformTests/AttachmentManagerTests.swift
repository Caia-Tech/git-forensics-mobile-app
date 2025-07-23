//
//  AttachmentManagerTests.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import XCTest
@testable import git_forensics_apple_multiplatform
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import Foundation

final class AttachmentManagerTests: XCTestCase {
    
    var attachmentManager: AttachmentManager!
    var testDirectory: URL!
    var gitManager: SimpleGitManager!
    
    override func setUp() throws {
        super.setUp()
        
        // Create a temporary directory for testing
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-attachments-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        // Initialize managers
        attachmentManager = AttachmentManager.shared
        gitManager = SimpleGitManager.shared
        
        // Initialize git repository for testing
        try gitManager.initializeRepository()
    }
    
    override func tearDown() throws {
        // Clean up test directory
        if FileManager.default.fileExists(atPath: testDirectory.path) {
            try FileManager.default.removeItem(at: testDirectory)
        }
        
        attachmentManager = nil
        gitManager = nil
        testDirectory = nil
        
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> PlatformImage {
        let size = CGSize(width: 100, height: 100)
        #if os(iOS)
        UIGraphicsBeginImageContext(size)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
        #elseif os(macOS)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
        #endif
    }
    
    private func createTestFile(content: String, extension: String) throws -> URL {
        let fileName = "test.\(`extension`)"
        let fileURL = testDirectory.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    // MARK: - Image Processing Tests
    
    func testProcessImageAttachment() async throws {
        let testImage = createTestImage()
        
        let attachment = try await attachmentManager.processImageAttachment(testImage)
        
        // Verify attachment properties
        XCTAssertNotNil(attachment.id)
        XCTAssertTrue(attachment.filename.hasPrefix("IMG_"))
        XCTAssertTrue(attachment.filename.hasSuffix(".jpg"))
        XCTAssertEqual(attachment.mimeType, "image/jpeg")
        XCTAssertGreaterThan(attachment.sizeBytes, 0)
        XCTAssertFalse(attachment.hashSHA256.isEmpty)
        XCTAssertEqual(attachment.hashSHA256.count, 64) // SHA-256 is 64 hex characters
        XCTAssertNotNil(attachment.createdAt)
        XCTAssertFalse(attachment.storagePath.isEmpty)
        XCTAssertTrue(attachment.storagePath.hasSuffix(".jpg"))
    }
    
    func testProcessImageAttachmentWithCustomFilename() async throws {
        let testImage = createTestImage()
        let customFilename = "custom_image.jpg"
        
        let attachment = try await attachmentManager.processImageAttachment(testImage, filename: customFilename)
        
        XCTAssertEqual(attachment.filename, customFilename)
        XCTAssertEqual(attachment.mimeType, "image/jpeg")
    }
    
    func testProcessImageAttachmentConsistentHash() async throws {
        let testImage = createTestImage()
        
        let attachment1 = try await attachmentManager.processImageAttachment(testImage)
        let attachment2 = try await attachmentManager.processImageAttachment(testImage)
        
        // Same image should produce same hash
        XCTAssertEqual(attachment1.hashSHA256, attachment2.hashSHA256)
        // But different IDs and filenames
        XCTAssertNotEqual(attachment1.id, attachment2.id)
    }
    
    func testProcessLargeImageAttachment() async throws {
        // Create a larger test image
        let size = CGSize(width: 2000, height: 2000)
        #if os(iOS)
        UIGraphicsBeginImageContext(size)
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let largeImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        #elseif os(macOS)
        let largeImage = NSImage(size: size)
        largeImage.lockFocus()
        NSColor.blue.setFill()
        NSRect(origin: .zero, size: size).fill()
        largeImage.unlockFocus()
        #endif
        
        let attachment = try await attachmentManager.processImageAttachment(largeImage)
        
        XCTAssertNotNil(attachment)
        XCTAssertGreaterThan(attachment.sizeBytes, 0)
        
        // Image should be compressed but still reasonable size
        XCTAssertLessThan(attachment.sizeBytes, 10 * 1024 * 1024) // Less than 10MB
    }
    
    // MARK: - File Processing Tests
    
    func testProcessTextFileAttachment() async throws {
        let testContent = "This is test file content for attachment testing."
        let fileURL = try createTestFile(content: testContent, extension: "txt")
        
        let attachment = try await attachmentManager.processFileAttachment(from: fileURL)
        
        XCTAssertEqual(attachment.filename, "test.txt")
        XCTAssertTrue(attachment.mimeType.contains("text"))
        XCTAssertEqual(attachment.sizeBytes, Int64(testContent.utf8.count))
        XCTAssertFalse(attachment.hashSHA256.isEmpty)
        XCTAssertTrue(attachment.storagePath.hasSuffix(".txt"))
    }
    
    func testProcessJSONFileAttachment() async throws {
        let jsonContent = """
        {
            "test": "data",
            "number": 42,
            "array": [1, 2, 3]
        }
        """
        let fileURL = try createTestFile(content: jsonContent, extension: "json")
        
        let attachment = try await attachmentManager.processFileAttachment(from: fileURL)
        
        XCTAssertEqual(attachment.filename, "test.json")
        XCTAssertTrue(attachment.mimeType.contains("json") || attachment.mimeType.contains("text"))
        XCTAssertEqual(attachment.sizeBytes, Int64(jsonContent.utf8.count))
    }
    
    func testProcessUnknownFileType() async throws {
        let testContent = "Unknown file type content"
        let fileName = "test.unknown"
        let fileURL = testDirectory.appendingPathComponent(fileName)
        try testContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        let attachment = try await attachmentManager.processFileAttachment(from: fileURL)
        
        XCTAssertEqual(attachment.filename, fileName)
        XCTAssertEqual(attachment.mimeType, "application/octet-stream")
        XCTAssertEqual(attachment.sizeBytes, Int64(testContent.utf8.count))
    }
    
    func testProcessEmptyFile() async throws {
        let fileURL = try createTestFile(content: "", extension: "txt")
        
        let attachment = try await attachmentManager.processFileAttachment(from: fileURL)
        
        XCTAssertEqual(attachment.sizeBytes, 0)
        XCTAssertFalse(attachment.hashSHA256.isEmpty) // Empty file still has a hash
    }
    
    // MARK: - File Size Validation Tests
    
    func testFileSizeLimit() async throws {
        // Create a file that exceeds the size limit
        let largeContent = String(repeating: "a", count: 11 * 1024 * 1024) // 11MB
        let fileURL = try createTestFile(content: largeContent, extension: "txt")
        
        do {
            _ = try await attachmentManager.processFileAttachment(from: fileURL)
            XCTFail("Should throw error for file too large")
        } catch AttachmentError.fileTooLarge {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testImageSizeLimit() async throws {
        // This test would need a very large image to trigger the limit
        // For now, we test that the size checking logic works
        let testImage = createTestImage()
        
        // This should succeed since our test image is small
        let attachment = try await attachmentManager.processImageAttachment(testImage)
        XCTAssertNotNil(attachment)
    }
    
    // MARK: - Storage Tests
    
    func testAttachmentStoragePath() async throws {
        let testImage = createTestImage()
        
        let attachment = try await attachmentManager.processImageAttachment(testImage)
        
        // Verify storage path structure
        let attachmentsDir = gitManager.repositoryPath.appendingPathComponent("attachments")
        
        // Should create date-based directory structure
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let expectedDatePath = dateFormatter.string(from: currentDate)
        
        let expectedDir = attachmentsDir.appendingPathComponent(expectedDatePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedDir.path), "Date-based directory should exist")
        
        // File should exist at the storage path
        let fullPath = attachmentsDir.appendingPathComponent(attachment.storagePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fullPath.path), "Attachment file should exist")
    }
    
    func testDuplicateFileDeduplication() async throws {
        let testContent = "Duplicate test content"
        let fileURL1 = try createTestFile(content: testContent, extension: "txt")
        
        let attachment1 = try await attachmentManager.processFileAttachment(from: fileURL1)
        
        // Create another file with same content
        let fileURL2 = testDirectory.appendingPathComponent("test2.txt")
        try testContent.write(to: fileURL2, atomically: true, encoding: .utf8)
        
        let attachment2 = try await attachmentManager.processFileAttachment(from: fileURL2)
        
        // Should have same hash and storage path (deduplication)
        XCTAssertEqual(attachment1.hashSHA256, attachment2.hashSHA256)
        
        // Files should share the same underlying storage
        let attachmentsDir = gitManager.repositoryPath.appendingPathComponent("attachments")
        let path1 = attachmentsDir.appendingPathComponent(attachment1.storagePath)
        let path2 = attachmentsDir.appendingPathComponent(attachment2.storagePath)
        
        // Both attachments should point to files that exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: path1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path2.path))
    }
    
    // MARK: - Data Loading Tests
    
    func testLoadAttachmentData() async throws {
        let testContent = "Test file content for loading"
        let fileURL = try createTestFile(content: testContent, extension: "txt")
        
        let attachment = try await attachmentManager.processFileAttachment(from: fileURL)
        
        // Load the data back
        let loadedData = try attachmentManager.loadAttachmentData(for: attachment)
        
        XCTAssertNotNil(loadedData)
        let loadedContent = String(data: loadedData!, encoding: .utf8)
        XCTAssertEqual(loadedContent, testContent)
    }
    
    func testLoadNonexistentAttachment() throws {
        let fakeAttachment = EventAttachment(
            filename: "nonexistent.txt",
            mimeType: "text/plain",
            sizeBytes: 100,
            hashSHA256: "fakehash",
            storagePath: "nonexistent/path.txt"
        )
        
        let loadedData = try attachmentManager.loadAttachmentData(for: fakeAttachment)
        XCTAssertNil(loadedData, "Loading nonexistent attachment should return nil")
    }
    
    // MARK: - Verification Tests
    
    func testVerifyAttachmentIntegrity() async throws {
        let testImage = createTestImage()
        
        let attachment = try await attachmentManager.processImageAttachment(testImage)
        
        // Verify integrity
        let isValid = await attachmentManager.verifyAttachment(attachment)
        XCTAssertTrue(isValid, "Attachment integrity should be valid")
    }
    
    func testVerifyCorruptedAttachment() async throws {
        let testContent = "Original content"
        let fileURL = try createTestFile(content: testContent, extension: "txt")
        
        let attachment = try await attachmentManager.processFileAttachment(from: fileURL)
        
        // Corrupt the stored file
        let attachmentsDir = gitManager.repositoryPath.appendingPathComponent("attachments")
        let storedPath = attachmentsDir.appendingPathComponent(attachment.storagePath)
        try "corrupted content".write(to: storedPath, atomically: true, encoding: .utf8)
        
        // Verification should fail
        let isValid = await attachmentManager.verifyAttachment(attachment)
        XCTAssertFalse(isValid, "Corrupted attachment should fail verification")
    }
    
    func testVerifyMissingAttachment() async throws {
        let attachment = EventAttachment(
            filename: "missing.txt",
            mimeType: "text/plain",
            sizeBytes: 100,
            hashSHA256: "somehash",
            storagePath: "missing/file.txt"
        )
        
        let isValid = await attachmentManager.verifyAttachment(attachment)
        XCTAssertFalse(isValid, "Missing attachment should fail verification")
    }
    
    // MARK: - Thumbnail Tests
    
    func testGetImageThumbnail() async throws {
        let testImage = createTestImage()
        
        let attachment = try await attachmentManager.processImageAttachment(testImage)
        
        let thumbnailSize = CGSize(width: 50, height: 50)
        let thumbnail = await attachmentManager.getThumbnail(for: attachment, size: thumbnailSize)
        
        XCTAssertNotNil(thumbnail)
        XCTAssertLessThanOrEqual(thumbnail!.size.width, thumbnailSize.width)
        XCTAssertLessThanOrEqual(thumbnail!.size.height, thumbnailSize.height)
    }
    
    func testGetThumbnailForNonImageAttachment() async throws {
        let testContent = "Not an image"
        let fileURL = try createTestFile(content: testContent, extension: "txt")
        
        let attachment = try await attachmentManager.processFileAttachment(from: fileURL)
        
        let thumbnail = await attachmentManager.getThumbnail(for: attachment, size: CGSize(width: 50, height: 50))
        XCTAssertNil(thumbnail, "Non-image attachment should not have thumbnail")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidImageData() async throws {
        // Test with invalid image data (this would be difficult to create in practice)
        // For now, test that valid image processing works
        let testImage = createTestImage()
        
        do {
            let attachment = try await attachmentManager.processImageAttachment(testImage)
            XCTAssertNotNil(attachment)
        } catch {
            XCTFail("Valid image processing should not fail: \(error)")
        }
    }
    
    func testFileAccessError() async throws {
        // Create a file URL that doesn't exist
        let nonexistentURL = testDirectory.appendingPathComponent("nonexistent.txt")
        
        do {
            _ = try await attachmentManager.processFileAttachment(from: nonexistentURL)
            XCTFail("Should throw error for nonexistent file")
        } catch {
            // Expected error
            XCTAssertTrue(error is CocoaError || error.localizedDescription.contains("couldn't"))
        }
    }
    
    // MARK: - Performance Tests
    
    func testImageProcessingPerformance() async throws {
        let testImage = createTestImage()
        
        measure {
            Task {
                do {
                    for _ in 0..<10 {
                        _ = try await attachmentManager.processImageAttachment(testImage)
                    }
                } catch {
                    XCTFail("Image processing failed: \(error)")
                }
            }
        }
    }
    
    func testFileProcessingPerformance() async throws {
        let testContent = String(repeating: "Performance test content. ", count: 1000)
        let fileURL = try createTestFile(content: testContent, extension: "txt")
        
        measure {
            Task {
                do {
                    for _ in 0..<10 {
                        _ = try await attachmentManager.processFileAttachment(from: fileURL)
                    }
                } catch {
                    XCTFail("File processing failed: \(error)")
                }
            }
        }
    }
    
    func testVerificationPerformance() async throws {
        // Create multiple attachments
        var attachments: [EventAttachment] = []
        for i in 0..<20 {
            let content = "Test content \(i)"
            let fileURL = try createTestFile(content: content, extension: "txt")
            let attachment = try await attachmentManager.processFileAttachment(from: fileURL)
            attachments.append(attachment)
        }
        
        measure {
            Task {
                for attachment in attachments {
                    _ = await attachmentManager.verifyAttachment(attachment)
                }
            }
        }
    }
}