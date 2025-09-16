//
//  StringExtensions.swift
//  Fikret
//
//  Created by System on 2025-01-25.
//  Copyright © 2025 Fikret. All rights reserved.
//

import Foundation

// MARK: - URL Validation Extension
extension String {
    /// Fixes malformed URLs by removing duplicate protocol prefixes
    func fixMalformedURL() -> String {
        // Handle empty or invalid URLs
        guard !self.isEmpty else { return "" }
        
        // Fix double https:// issue
        if self.hasPrefix("https://https://") {
            return String(self.dropFirst(8)) // Remove the first "https://"
        }
        
        // Fix double http:// issue
        if self.hasPrefix("http://http://") {
            return String(self.dropFirst(7)) // Remove the first "http://"
        }
        
        // Fix mixed http://https:// issue
        if self.hasPrefix("http://https://") {
            return String(self.dropFirst(7)) // Remove the "http://" part
        }
        
        return self
    }
    
    /// Creates a safe URL by fixing malformed URLs first
    func safeURL() -> URL? {
        let fixedURL = self.fixMalformedURL()
        return URL(string: fixedURL)
    }
} 