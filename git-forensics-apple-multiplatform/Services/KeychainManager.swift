//
//  KeychainManager.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.caiatech.git-forensics.tokens"
    
    private init() {}
    
    // MARK: - Token Management
    
    func getToken(for provider: CloudProvider) -> String? {
        let key = tokenKey(for: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                print("Keychain read error: \(status)")
            }
            return nil
        }
        
        guard let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    func setToken(_ token: String, for provider: CloudProvider) -> Bool {
        let key = tokenKey(for: provider)
        
        // First try to update existing item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if updateStatus == errSecSuccess {
            return true
        }
        
        // If update failed, try to add new item
        if updateStatus == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: token.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
        
        print("Keychain write error: \(updateStatus)")
        return false
    }
    
    func deleteToken(for provider: CloudProvider) -> Bool {
        let key = tokenKey(for: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - User Info Management
    
    func getUserInfo(for provider: CloudProvider) -> GitHubUser? {
        let key = userInfoKey(for: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return try? JSONDecoder().decode(GitHubUser.self, from: data)
    }
    
    func setUserInfo(_ user: GitHubUser, for provider: CloudProvider) -> Bool {
        let key = userInfoKey(for: provider)
        
        guard let userData = try? JSONEncoder().encode(user) else {
            return false
        }
        
        // First try to update existing item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: userData
        ]
        
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if updateStatus == errSecSuccess {
            return true
        }
        
        // If update failed, try to add new item
        if updateStatus == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: userData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
        
        return false
    }
    
    func deleteUserInfo(for provider: CloudProvider) -> Bool {
        let key = userInfoKey(for: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Helper Methods
    
    private func tokenKey(for provider: CloudProvider) -> String {
        return "\(provider.rawValue.lowercased())-token"
    }
    
    private func userInfoKey(for provider: CloudProvider) -> String {
        return "\(provider.rawValue.lowercased())-user"
    }
    
    // MARK: - Clear All Data
    
    func clearAllData() {
        CloudProvider.allCases.forEach { provider in
            _ = deleteToken(for: provider)
            _ = deleteUserInfo(for: provider)
        }
    }
}