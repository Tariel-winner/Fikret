//
//  Message.swift
//  Phoenix-Chat-App
//
//  Created by jeazous on 9/20/21.
//

import Foundation

struct Message: Identifiable {
    let id: String
    let text: String
    let userId: String
    let timestamp: Date
    
    var isFromCurrentUser: Bool {
        // Compare with current user ID
        userId == UserDefaults.standard.string(forKey: "currentUserId")
    }
}