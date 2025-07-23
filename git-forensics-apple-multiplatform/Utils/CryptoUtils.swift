//
//  CryptoUtils.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation
import CryptoKit

enum CryptoUtils {
    
    /// Calculate SHA-256 hash of a ForensicEvent
    static func calculateEventHash(_ event: ForensicEvent) -> String {
        // Create canonical representation for consistent hashing
        let canonical = CanonicalEvent(
            id: event.id.uuidString,
            type: event.type.rawValue,
            title: event.title,
            notes: event.notes,
            createdAt: ISO8601DateFormatter().string(from: event.createdAt),
            attachments: event.attachments.map { attachment in
                CanonicalAttachment(
                    id: attachment.id.uuidString,
                    hash: attachment.hashSHA256
                )
            },
            location: event.location.map { location in
                CanonicalLocation(
                    latitude: location.latitude,
                    longitude: location.longitude,
                    accuracy: location.accuracyMeters,
                    capturedAt: ISO8601DateFormatter().string(from: location.capturedAt)
                )
            },
            chain: event.chain.map { chain in
                CanonicalChain(
                    previousEventId: chain.previousEventId.uuidString,
                    previousEventHash: chain.previousEventHash,
                    eventNumber: chain.eventNumber
                )
            }
        )
        
        // Encode to JSON with sorted keys
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        
        do {
            let jsonData = try encoder.encode(canonical)
            return sha256Hash(of: jsonData)
        } catch {
            // This should never happen in production
            fatalError("Failed to encode event for hashing: \(error)")
        }
    }
    
    /// Calculate SHA-256 hash of data
    static func sha256Hash(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Calculate SHA-256 hash of a file
    static func sha256HashOfFile(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return sha256Hash(of: data)
    }
    
    /// Verify event chain integrity
    static func verifyEventChain(_ events: [ForensicEvent]) -> (isValid: Bool, error: String?) {
        guard !events.isEmpty else {
            return (true, nil)
        }
        
        // Sort events by chain number or creation date
        let sortedEvents = events.sorted { event1, event2 in
            if let chain1 = event1.chain, let chain2 = event2.chain {
                return chain1.eventNumber < chain2.eventNumber
            }
            return event1.createdAt < event2.createdAt
        }
        
        for (index, event) in sortedEvents.enumerated() {
            // Verify content hash
            let calculatedHash = calculateEventHash(event)
            if calculatedHash != event.integrity.contentHash {
                return (false, "Event \(index + 1) hash mismatch. Expected: \(event.integrity.contentHash), Got: \(calculatedHash)")
            }
            
            // Verify chain (except for first event)
            if index > 0, let chain = event.chain {
                let previousEvent = sortedEvents[index - 1]
                if chain.previousEventHash != previousEvent.integrity.contentHash {
                    return (false, "Chain broken at event \(index + 1). Previous hash mismatch.")
                }
                if chain.previousEventId != previousEvent.id {
                    return (false, "Chain broken at event \(index + 1). Previous ID mismatch.")
                }
            }
        }
        
        return (true, nil)
    }
}

// MARK: - Canonical Structures for Consistent Hashing

private struct CanonicalEvent: Codable {
    let id: String
    let type: String
    let title: String
    let notes: String
    let createdAt: String
    let attachments: [CanonicalAttachment]
    let location: CanonicalLocation?
    let chain: CanonicalChain?
}

private struct CanonicalAttachment: Codable {
    let id: String
    let hash: String
}

private struct CanonicalLocation: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let capturedAt: String
}

private struct CanonicalChain: Codable {
    let previousEventId: String
    let previousEventHash: String
    let eventNumber: Int
}