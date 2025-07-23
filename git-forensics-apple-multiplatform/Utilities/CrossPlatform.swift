//
//  CrossPlatform.swift
//  git-forensics-apple-multiplatform
//
//  Copyright © 2025 Caia Tech. All rights reserved.
//  Contact: owner@caiatech.com
//

import SwiftUI

#if os(iOS)
import UIKit
public typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#endif

// Cross-platform image extensions
extension PlatformImage {
    #if os(macOS)
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    
    func pngData() -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapImage.representation(using: .png, properties: [:])
    }
    #endif
}

// Cross-platform color
extension Color {
    #if os(macOS)
    static let systemBackground = Color(NSColor.windowBackgroundColor)
    static let secondarySystemBackground = Color(NSColor.controlBackgroundColor)
    static let label = Color(NSColor.labelColor)
    static let secondaryLabel = Color(NSColor.secondaryLabelColor)
    #endif
}

// Cross-platform image view
struct PlatformImageView: View {
    let image: PlatformImage
    
    var body: some View {
        #if os(iOS)
        Image(uiImage: image)
        #elseif os(macOS)
        Image(nsImage: image)
        #endif
    }
}