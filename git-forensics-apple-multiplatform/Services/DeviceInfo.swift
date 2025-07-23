//
//  DeviceInfo.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

class DeviceInfo {
    static let shared = DeviceInfo()
    
    private init() {}
    
    /// Persistent device ID stored in UserDefaults
    lazy var deviceId: UUID = {
        let key = "GitForensicsDeviceId"
        
        if let storedId = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: storedId) {
            return uuid
        } else {
            let newId = UUID()
            UserDefaults.standard.set(newId.uuidString, forKey: key)
            return newId
        }
    }()
    
    /// Device model (e.g., "iPhone14,2")
    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    /// Human-readable device name (e.g., "iPhone 13 Pro")
    var deviceName: String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #endif
    }
    
    /// OS version (e.g., "17.2.1")
    var osVersion: String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #elseif os(macOS)
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }
    
    /// App version from bundle
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// App build number from bundle
    var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// System name (e.g., "iOS")
    var systemName: String {
        #if os(iOS)
        return UIDevice.current.systemName
        #elseif os(macOS)
        return "macOS"
        #endif
    }
    
    /// Available storage space in bytes
    var availableStorage: Int64? {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            return attributes[.systemFreeSize] as? Int64
        } catch {
            return nil
        }
    }
    
    /// Total storage space in bytes
    var totalStorage: Int64? {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            return attributes[.systemSize] as? Int64
        } catch {
            return nil
        }
    }
    
    /// Current timezone identifier
    var timeZone: String {
        TimeZone.current.identifier
    }
    
    /// Current locale identifier
    var locale: String {
        Locale.current.identifier
    }
    
    #if os(iOS)
    /// Battery level (0.0 to 1.0, or -1.0 if unknown)
    var batteryLevel: Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        UIDevice.current.isBatteryMonitoringEnabled = false
        return level
    }
    
    /// Battery state
    var batteryState: UIDevice.BatteryState {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let state = UIDevice.current.batteryState
        UIDevice.current.isBatteryMonitoringEnabled = false
        return state
    }
    
    /// Device orientation
    var orientation: UIDeviceOrientation {
        UIDevice.current.orientation
    }
    #endif
    
    /// Is device jailbroken (basic check)
    var isJailbroken: Bool {
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/private/var/lib/cydia"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Try to write to a restricted directory
        do {
            let testString = "test"
            try testString.write(toFile: "/private/test_jailbreak.txt", atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: "/private/test_jailbreak.txt")
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Device Info Extension for Forensic Events

extension DeviceInfo {
    /// Generate a comprehensive device fingerprint for forensic purposes
    func generateDeviceFingerprint() -> [String: Any] {
        var fingerprint: [String: Any] = [:]
        
        fingerprint["deviceId"] = deviceId.uuidString
        fingerprint["deviceModel"] = deviceModel
        fingerprint["deviceName"] = deviceName
        fingerprint["systemName"] = systemName
        fingerprint["osVersion"] = osVersion
        fingerprint["appVersion"] = appVersion
        fingerprint["appBuild"] = appBuild
        fingerprint["timeZone"] = timeZone
        fingerprint["locale"] = locale
        fingerprint["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        // Optional security information
        fingerprint["jailbroken"] = isJailbroken
        
        // Storage information (optional)
        if let totalStorage = totalStorage {
            fingerprint["totalStorage"] = totalStorage
        }
        if let availableStorage = availableStorage {
            fingerprint["availableStorage"] = availableStorage
        }
        
        // Battery information (iOS only)
        #if os(iOS)
        let battery = batteryLevel
        if battery >= 0 {
            fingerprint["batteryLevel"] = battery
            fingerprint["batteryState"] = batteryState.rawValue
        }
        #endif
        
        return fingerprint
    }
}