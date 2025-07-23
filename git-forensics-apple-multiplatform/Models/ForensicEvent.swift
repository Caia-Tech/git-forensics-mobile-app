//
//  ForensicEvent.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation

struct ForensicEvent: Codable, Identifiable {
    let id: UUID
    let type: EventType
    let title: String
    let notes: String
    let createdAt: Date
    let createdAtLocal: Date
    let metadata: EventMetadata
    let chain: EventChain?
    var integrity: EventIntegrity
    let attachments: [EventAttachment]
    let location: EventLocation?
    
    let version: String
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, notes, createdAt, createdAtLocal, metadata, chain, integrity, attachments, location, version
    }
    
    init(
        type: EventType,
        title: String,
        notes: String,
        attachments: [EventAttachment] = [],
        location: EventLocation? = nil,
        previousEvent: ForensicEvent? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.notes = notes
        self.createdAt = Date()
        self.createdAtLocal = Date()
        self.metadata = EventMetadata()
        self.attachments = attachments
        self.location = location
        self.version = "1.0"
        
        // Create chain if there's a previous event
        if let previous = previousEvent {
            self.chain = EventChain(
                previousEventId: previous.id,
                previousEventHash: previous.integrity.contentHash,
                eventNumber: (previous.chain?.eventNumber ?? 0) + 1
            )
        } else {
            self.chain = nil
        }
        
        // Integrity will be calculated after initialization
        self.integrity = EventIntegrity(contentHash: "", signature: nil)
    }
}

enum EventType: String, Codable, CaseIterable {
    case meeting = "meeting"
    case incident = "incident"
    case medical = "medical"
    case legal = "legal"
    case financial = "financial"
    case observation = "observation"
    case communication = "communication"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .meeting: return "Meeting"
        case .incident: return "Incident"
        case .medical: return "Medical"
        case .legal: return "Legal"
        case .financial: return "Financial"
        case .observation: return "Observation"
        case .communication: return "Communication"
        case .general: return "General Note"
        }
    }
    
    var icon: String {
        switch self {
        case .meeting: return "person.2"
        case .incident: return "exclamationmark.triangle"
        case .medical: return "heart"
        case .legal: return "scalemass"
        case .financial: return "dollarsign"
        case .observation: return "eye"
        case .communication: return "message"
        case .general: return "doc.text"
        }
    }
}

struct EventMetadata: Codable {
    let deviceId: UUID
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    let appBuild: String
    
    init() {
        // Get or create persistent device ID
        self.deviceId = DeviceInfo.shared.deviceId
        self.deviceModel = DeviceInfo.shared.deviceModel
        self.osVersion = DeviceInfo.shared.osVersion
        self.appVersion = DeviceInfo.shared.appVersion
        self.appBuild = DeviceInfo.shared.appBuild
    }
}

struct EventChain: Codable {
    let previousEventId: UUID
    let previousEventHash: String
    let eventNumber: Int
}

struct EventIntegrity: Codable {
    let contentHash: String
    let signature: String?
}

struct EventAttachment: Codable, Identifiable {
    let id: UUID
    let filename: String
    let mimeType: String
    let sizeBytes: Int64
    let hashSHA256: String
    let createdAt: Date
    let storagePath: String
    
    init(filename: String, mimeType: String, sizeBytes: Int64, hashSHA256: String, storagePath: String) {
        self.id = UUID()
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.hashSHA256 = hashSHA256
        self.createdAt = Date()
        self.storagePath = storagePath
    }
}

struct EventLocation: Codable {
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    let altitudeMeters: Double?
    let altitudeAccuracyMeters: Double?
    let headingDegrees: Double?
    let speedMPS: Double?
    let capturedAt: Date
    let source: LocationSource
    let address: Address?
    
    enum LocationSource: String, Codable {
        case gps = "gps"
        case network = "network"
        case manual = "manual"
    }
    
    struct Address: Codable {
        let street: String?
        let city: String?
        let state: String?
        let postalCode: String?
        let country: String?
    }
}