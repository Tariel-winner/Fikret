import Foundation
import SwiftUI



// MARK: - User Notification Type Enum
enum UserNotificationType: Int, Codable, CaseIterable {
    case post = 1
    case comment = 2
    case reply = 3
    case whisper = 4
    case friendRequest = 5
    case follow = 6
    case reaction = 7
    case system = 99
    
    var displayName: String {
        switch self {
        case .post:
            return "Post"
        case .comment:
            return "Comment"
        case .reply:
            return "Reply"
        case .whisper:
            return "Whisper"
        case .friendRequest:
            return "Friend Request"
        case .follow:
            return "Follow"
        case .reaction:
            return "Reaction"
        case .system:
            return "System"
        }
    }
    
    var description: String {
        switch self {
        case .post:
            return "Someone mentioned you in a post"
        case .comment:
            return "Someone commented on your post"
        case .reply:
            return "Someone replied to your comment"
        case .whisper:
            return "You received a private message"
        case .friendRequest:
            return "Someone sent you a friend request"
        case .follow:
            return "Someone started following you"
        case .reaction:
            return "Someone sent you a reaction"
        case .system:
            return "System notification"
        }
    }
    
    var iconName: String {
        switch self {
        case .post:
            return "doc.text"
        case .comment:
            return "bubble.left"
        case .reply:
            return "arrowshape.turn.up.left"
        case .whisper:
            return "message"
        case .friendRequest:
            return "person.badge.plus"
        case .follow:
            return "person.2"
        case .reaction:
            return "heart.fill"
        case .system:
            return "bell"
        }
    }
}

// MARK: - Data Models
struct UserNotification: Codable, Identifiable {
    let id: Int64
    let type: Int  // Changed from String to Int to match backend
    let brief: String
    let content: String
    let sender_user_id: Int64
    let receiver_user_id: Int64
    let post_id: Int64?
    let comment_id: Int64?
    let reply_id: Int64?
    var is_read: Bool  // Changed from 'let' to 'var' to allow modification
    let created_on: Int64
    let sender_user: NotificationUserProfile?
    let receiver_user: NotificationUserProfile?
    let post: NotificationPost?
    let comment: NotificationComment?
    let reply: NotificationCommentReply?
    
    // Computed property to get the enum type
    var notificationType: UserNotificationType {
        return UserNotificationType(rawValue: type) ?? .system
    }
    
    // Helper property for type-safe comparisons
    var isPost: Bool { notificationType == .post }
    var isComment: Bool { notificationType == .comment }
    var isReply: Bool { notificationType == .reply }
    var isWhisper: Bool { notificationType == .whisper }
    var isFriendRequest: Bool { notificationType == .friendRequest }
    var isFollow: Bool { notificationType == .follow }
    var isReaction: Bool {
        // Check both the type and content for reaction notifications
        let isReactionType = notificationType == .reaction
        let hasChinesePattern = brief.contains("给你发送了")
        let hasEnglishPattern = brief.contains("sent you")
        
        let result = isReactionType || hasChinesePattern || hasEnglishPattern
        
        print("🔍 [DEBUG] isReaction check for notification \(id):")
        print("  - notificationType: \(notificationType.rawValue) (\(isReactionType))")
        print("  - brief: '\(brief)'")
        print("  - hasChinesePattern: \(hasChinesePattern)")
        print("  - hasEnglishPattern: \(hasEnglishPattern)")
        print("  - Final result: \(result)")
        
        return result
    }
    var isSystem: Bool { notificationType == .system }
    
    // Custom decoder to handle is_read as both Bool and Int
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int64.self, forKey: .id)
        type = try container.decode(Int.self, forKey: .type)
        brief = try container.decode(String.self, forKey: .brief)
        content = try container.decode(String.self, forKey: .content)
        sender_user_id = try container.decode(Int64.self, forKey: .sender_user_id)
        receiver_user_id = try container.decode(Int64.self, forKey: .receiver_user_id)
        post_id = try container.decodeIfPresent(Int64.self, forKey: .post_id)
        comment_id = try container.decodeIfPresent(Int64.self, forKey: .comment_id)
        reply_id = try container.decodeIfPresent(Int64.self, forKey: .reply_id)
        created_on = try container.decode(Int64.self, forKey: .created_on)
        sender_user = try container.decodeIfPresent(NotificationUserProfile.self, forKey: .sender_user)
        receiver_user = try container.decodeIfPresent(NotificationUserProfile.self, forKey: .receiver_user)
        post = try container.decodeIfPresent(NotificationPost.self, forKey: .post)
        comment = try container.decodeIfPresent(NotificationComment.self, forKey: .comment)
        reply = try container.decodeIfPresent(NotificationCommentReply.self, forKey: .reply)
        
        // Handle is_read field that can be either Bool or Int
        if let boolValue = try? container.decode(Bool.self, forKey: .is_read) {
            is_read = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .is_read) {
            is_read = intValue == 1
        } else {
            // Default to false if neither works
            is_read = false
        }
    }
    
    // Custom encoder to ensure is_read is always encoded as Bool
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(brief, forKey: .brief)
        try container.encode(content, forKey: .content)
        try container.encode(sender_user_id, forKey: .sender_user_id)
        try container.encode(receiver_user_id, forKey: .receiver_user_id)
        try container.encodeIfPresent(post_id, forKey: .post_id)
        try container.encodeIfPresent(comment_id, forKey: .comment_id)
        try container.encodeIfPresent(reply_id, forKey: .reply_id)
        try container.encode(is_read, forKey: .is_read)
        try container.encode(created_on, forKey: .created_on)
        try container.encodeIfPresent(sender_user, forKey: .sender_user)
        try container.encodeIfPresent(receiver_user, forKey: .receiver_user)
        try container.encodeIfPresent(post, forKey: .post)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encodeIfPresent(reply, forKey: .reply)
    }
    
    // Coding keys
    private enum CodingKeys: String, CodingKey {
        case id, type, brief, content, sender_user_id, receiver_user_id
        case post_id, comment_id, reply_id, is_read, created_on
        case sender_user, receiver_user, post, comment, reply
    }
    
    static func from(dictionary: [String: Any]) throws -> UserNotification {
        print("🔍 Decoding notification from dictionary:")
        print("📋 Dictionary keys: \(dictionary.keys.sorted())")
        if let isReadValue = dictionary["is_read"] {
            print("📋 is_read value: \(isReadValue) (Swift type: \(Swift.type(of: isReadValue)))")
        }
        
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        let decoder = JSONDecoder()
        return try decoder.decode(UserNotification.self, from: data)
    }
}

// MARK: - Translation Helper
extension UserNotification {
    // Translate common Chinese notification texts to English
    var translatedBrief: String {
        let translated = translateNotificationText(brief)
        print("🌐 Translation: '\(brief)' -> '\(translated)'")
        return translated
    }
    
    var translatedContent: String {
        return translateNotificationText(content)
    }
    
    private func translateNotificationText(_ text: String) -> String {
        // Comprehensive translations for all notification types
        let translations: [String: String] = [
            "关注了你": "followed you",
            "用户": "User",
            "给你发送了": "sent you",
            "反应": "reaction",
            "评论了你的": "commented on your",
            "回复了你的": "replied to your",
            "给你发送了私信": "sent you a private message",
            "给你发送了好友请求": "sent you a friend request"
        ]
        
        var translatedText = text
        
        // Apply basic translations
        for (chinese, english) in translations {
            translatedText = translatedText.replacingOccurrences(of: chinese, with: english)
        }
        
        // Handle follow notifications like "用户 sdsdd 关注了你"
        if translatedText.contains("User") && translatedText.contains("followed you") {
            let components = translatedText.components(separatedBy: " ")
            if components.count >= 3 && components[0] == "User" {
                let username = components[1]
                // ✅ FIXED: Since NotificationView shows username in header, just show the action
                translatedText = "started following you"
            }
        }
        
        // ✅ FIXED: Remove any duplicate "followed you" text
        // This handles cases where the backend might send "User username followed you followed you"
        let duplicatePattern = "followed you followed you"
        if translatedText.contains(duplicatePattern) {
            translatedText = translatedText.replacingOccurrences(of: duplicatePattern, with: "followed you")
        }
        
        // Handle post mentions - the main case we care about
        if text.contains("在新发布的泡泡动态中@了你") {
            print("🌐 Found post mention pattern in original text: '\(text)'")
            // ✅ FIXED: Since NotificationView shows username in header, just show the action
            translatedText = "mentioned you in a post"
            print("🌐 Post mention translation: '\(translatedText)'")
        }
        
        // Handle reaction notifications like "tammsdsd 给你发送了 strong 反应"
        if translatedText.contains("sent you") && translatedText.contains("reaction") {
            print("🌐 Found reaction notification pattern in original text: '\(text)'")
            
            // Extract username and reaction type
            let components = translatedText.components(separatedBy: " ")
            if components.count >= 4 {
                let username = components[0]
                let reactionType = components[2] // The reaction type (strong, like, love, etc.)
                
                // Get proper reaction text based on type
                let reactionText = getReactionNotificationText(reactionType)
                
                // ✅ FIXED: Don't add @ here since NotificationView handles username display separately
                translatedText = "\(reactionText)"
                print("🌐 Reaction notification translation: '\(translatedText)'")
            }
        }
        
        // ✅ ADDITIONAL FIX: Handle reaction notifications that might have different patterns
        // This catches cases where the backend sends different formats
        if translatedText.contains("sent you a reaction") && !translatedText.contains("thinks you're") {
            print("🌐 Found 'sent you a reaction' pattern: '\(translatedText)'")
            
            // Try to extract username from the beginning
            let components = translatedText.components(separatedBy: " ")
            if components.count >= 1 {
                let username = components[0]
                
                // Try to get reaction type from the original text
                let originalComponents = text.components(separatedBy: " ")
                if originalComponents.count >= 3 {
                    let reactionType = originalComponents[2] // Usually the third word is the reaction type
                    
                    // Get proper reaction text based on type
                    let reactionText = getReactionNotificationText(reactionType)
                    
                    // ✅ FIXED: Don't add @ here since NotificationView handles username display separately
                    translatedText = "\(reactionText)"
                    print("🌐 'sent you a reaction' translation: '\(translatedText)'")
                }
            }
        }
        
        // ✅ ADDITIONAL FIX: Handle comment notifications
        if translatedText.contains("commented on your post") {
            translatedText = "commented on your post"
        }
        
        // ✅ ADDITIONAL FIX: Handle reply notifications
        if translatedText.contains("replied to your comment") {
            translatedText = "replied to your comment"
        }
        
        // ✅ ADDITIONAL FIX: Handle friend request notifications
        if translatedText.contains("sent you a friend request") {
            translatedText = "sent you a friend request"
        }
        
        // ✅ ADDITIONAL FIX: Handle whisper/private message notifications
        if translatedText.contains("sent you a private message") {
            translatedText = "sent you a private message"
        }
        
        return translatedText
    }
    
    // Helper function to get proper reaction display names
    private func getReactionDisplayName(_ reactionType: String) -> String {
        let reactionMap: [String: String] = [
            "like": "👍 like",
            "love": "❤️ love",
            "hot": "🔥 hot",
            "smart": "🧠 smart",
            "funny": "😂 funny",
            "kind": "🤗 kind",
            "brave": "💪 brave",
            "cool": "😎 cool",
            "sweet": "🍯 sweet",
            "strong": "💪 strong",
            "friendly": "😊 friendly",
            "honest": "🤝 honest",
            "generous": "🎁 generous",
            "fit": "🏃 fit",
            "creative": "🎨 creative",
            "stupid": "🤦 stupid",
            "mean": "😠 mean",
            "fake": "🎭 fake",
            "lazy": "😴 lazy"
        ]
        
        return reactionMap[reactionType.lowercased()] ?? reactionType
    }
    
    // Helper function to get natural reaction notification text
    private func getReactionNotificationText(_ reactionType: String) -> String {
        print("🔍 [DEBUG] getReactionNotificationText called with reactionType: '\(reactionType)'")
        
        let reactionMap: [String: String] = [
            "like": "likes you",
            "love": "loves you",
            "hot": "thinks you're hot",
            "smart": "thinks you're smart",
            "funny": "thinks you're funny",
            "kind": "thinks you're kind",
            "brave": "thinks you're brave",
            "cool": "thinks you're cool",
            "sweet": "thinks you're sweet",
            "strong": "thinks you're strong",
            "friendly": "thinks you're friendly",
            "honest": "thinks you're honest",
            "generous": "thinks you're generous",
            "fit": "thinks you're fit",
            "creative": "thinks you're creative",
            "stupid": "thinks you're stupid",
            "mean": "thinks you're mean",
            "fake": "thinks you're fake",
            "lazy": "thinks you're lazy"
        ]
        
        let result = reactionMap[reactionType.lowercased()] ?? "sent you a reaction"
        print("🔍 [DEBUG] getReactionNotificationText result: '\(result)' for input: '\(reactionType)'")
        
        return result
    }
    
    // Helper function to extract reaction type from notification content
    var extractedReactionType: String? {
        guard isReaction else { return nil }
        
        // Try to extract reaction type from the brief text
        let components = brief.components(separatedBy: " ")
        if components.count >= 3 {
            // Look for the reaction type (usually the third word in Chinese format)
            let potentialReactionType = components[2]
            
            // Check if it's a valid reaction type
            let validReactionTypes = ["like", "love", "hot", "smart", "funny", "kind", "brave", "cool", "sweet", "strong", "friendly", "honest", "generous", "fit", "creative", "stupid", "mean", "fake", "lazy"]
            
            if validReactionTypes.contains(potentialReactionType.lowercased()) {
                return potentialReactionType
            }
        }
        
        return nil
    }
    
    // Helper function to get reaction icon for display
    var reactionIcon: String {
        guard let reactionType = extractedReactionType else { return "heart.fill" }
        
        let iconMap: [String: String] = [
            "like": "hand.thumbsup.fill",
            "love": "heart.fill",
            "hot": "flame.fill",
            "smart": "brain.head.profile",
            "funny": "face.smiling.fill",
            "kind": "heart.circle.fill",
            "brave": "figure.strengthtraining.traditional",
            "cool": "sunglasses.fill",
            "sweet": "drop.fill",
            "strong": "figure.strengthtraining.traditional",
            "friendly": "person.2.fill",
            "honest": "hand.raised.fill",
            "generous": "gift.fill",
            "fit": "figure.run",
            "creative": "paintbrush.fill",
            "stupid": "face.dashed",
            "mean": "face.angry.fill",
            "fake": "theatermasks.fill",
            "lazy": "bed.double.fill"
        ]
        
        return iconMap[reactionType.lowercased()] ?? "heart.fill"
    }
}

struct NotificationUserProfile: Codable {
    let id: Int64
    let nickname: String
    let username: String
    let avatar: String
    let status: Int
    let is_admin: Bool?
    let is_friend: Bool?
    let is_following: Bool?
    
    // Custom decoder to handle is_admin, is_friend, is_following as both Bool and Int
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int64.self, forKey: .id)
        nickname = try container.decode(String.self, forKey: .nickname)
        username = try container.decode(String.self, forKey: .username)
        
        // Fix malformed avatar URLs (remove double https://) - same as SpacesViewModelTypes.swift
        let rawAvatar = try container.decode(String.self, forKey: .avatar)
        avatar = rawAvatar.fixMalformedURL()
        status = try container.decode(Int.self, forKey: .status)
        
        // Handle boolean fields that can be either Bool or Int
        if let boolValue = try? container.decode(Bool.self, forKey: .is_admin) {
            is_admin = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .is_admin) {
            is_admin = intValue == 1
        } else {
            is_admin = false
        }
        
        if let boolValue = try? container.decode(Bool.self, forKey: .is_friend) {
            is_friend = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .is_friend) {
            is_friend = intValue == 1
        } else {
            is_friend = false
        }
        
        if let boolValue = try? container.decode(Bool.self, forKey: .is_following) {
            is_following = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .is_following) {
            is_following = intValue == 1
        } else {
            is_following = false
        }
    }
    
    // Custom encoder to ensure boolean fields are encoded as Bool
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(username, forKey: .username)
        try container.encode(avatar, forKey: .avatar)
        try container.encode(status, forKey: .status)
        try container.encode(is_admin ?? false, forKey: .is_admin)
        try container.encode(is_friend ?? false, forKey: .is_friend)
        try container.encode(is_following ?? false, forKey: .is_following)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, nickname, username, avatar, status, is_admin, is_friend, is_following
    }
    
    // ✅ REMOVED: Helper function - now using the global fixMalformedURL() extension directly
    // The fixMalformedURL() extension is already available globally from StringExtensions.swift
}

// MARK: - Post Content Item
struct NotificationPostContent: Codable {
    let id: Int64
    let post_id: Int64
    let content: String
    let type: Int
    let sort: Int
    let duration: String?
    let size: String?
}

struct NotificationPost: Codable {
    let id: Int64
    let topic: String?
    let content: String?
    let contents: [NotificationPostContent]?  // Backend uses 'contents' as an array
    let created_on: Int64?
    let user_id: [Int64]?  // Can be an array of user IDs
    let user: NotificationUserProfile?
    let visitor: NotificationUserProfile?
    let visibility: Int?
    let comment_count: Int?
    let collection_count: Int?
    let share_count: Int?
    let upvote_count: Int?
    let is_top: Int?
    let is_essence: Int?
    let is_lock: Int?
    let latest_replied_on: Int64?
    let modified_on: Int64?
    let tags: [String: Int]?  // Tags can be a dictionary
    let attachment_price: Int?
    let ip_loc: String?
    let room_id: String?
    let session_id: String?
    
    // Computed property to get the main content
    var displayContent: String {
        if let content = content, !content.isEmpty {
            return content
        }
        
        if let contents = contents, !contents.isEmpty {
            // Extract content from the first content item
            return contents.first?.content ?? ""
        }
        
        return topic ?? ""
    }
    
    // Helper to get audio/video URLs from contents
    var mediaUrls: [String] {
        guard let contents = contents else { return [] }
        return contents.compactMap { contentItem in
            // Extract URLs from content string (format: "userId:url|userId:url")
            let urlComponents = contentItem.content.components(separatedBy: "|")
            return urlComponents.compactMap { component in
                let parts = component.components(separatedBy: ":")
                if parts.count > 1 {
                    let rawUrl = parts[1]
                    // ✅ FIXED: Apply the same malformed URL fixing to media URLs
                    return rawUrl.fixMalformedURL()
                }
                return nil
            }
        }.flatMap { $0 }
    }
}

struct NotificationComment: Codable {
    let post_id: Int64?
    let user_id: Int64?
    let content: String?
    let ip: String?
    let ip_loc: String?
    let is_essense: Int?
    let reply_count: Int?
    let thumbs_up_count: Int?
    let created_on: Int64?
    
    // Computed property to get the main content
    var displayContent: String {
        return content ?? ""
    }
}

struct NotificationCommentReply: Codable {
    let comment_id: Int64?
    let user_id: Int64?
    let at_user_id: Int64?
    let content: String?
    let ip: String?
    let ip_loc: String?
    let thumbs_up_count: Int?
    let created_on: Int64?
    
    // Computed property to get the main content
    var displayContent: String {
        return content ?? ""
    }
}

// MARK: - State Management
struct NotificationState {
    var notifications: [UserNotification] = []
    var notificationStates: [Int64: NotificationItemState] = [:]
    var pagination = NotificationPaginationState()
    var isLoading = false
    var error: String?
}

struct NotificationItemState {
    var notification: UserNotification
    var isExpanded = false
}

struct NotificationPaginationState {
    var currentPage = 1
    var hasMoreData = true
    var totalItems: Int64 = 0
}

// MARK: - Network Error
enum NotificationNetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case serverError(Int)
    case unauthorized
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidData:
            return "Invalid data format"
        case .serverError(let code):
            return "Server error: \(code)"
        case .unauthorized:
            return "Unauthorized - please login again"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
}

// MARK: - Notification Service
class NotificationService {
    static var baseURL: String {
        print("🔍 [NotificationConfig] Using production server")
        return "http://api.tototopo.com:8008/v1"  // Production server
    }
    
    // MARK: - Get Unread Count
    static func getUnreadCount() async throws -> Int64 {
        print("📡 Fetching unread count...")
        
        guard let url = URL(string: "\(baseURL)/user/msgcount/unread") else {
            throw NotificationNetworkError.invalidURL
        }
        
        // Get token from Keychain (same as TweetData)
        guard let token = try KeychainManager.shared.getToken() else {
            throw NotificationNetworkError.unauthorized
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationNetworkError.invalidResponse
        }
        
        print("📊 Unread count response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let data = json?["data"] as? [String: Any],
               let count = data["count"] as? Int64 {
                print("✅ Unread count: \(count)")
                return count
            } else {
                print("⚠️ Unexpected response format for unread count")
                throw NotificationNetworkError.invalidData
            }
        }
        
        throw NotificationNetworkError.serverError(httpResponse.statusCode)
    }
    
    // MARK: - Get Messages/Notifications
    static func getMessages(page: Int = 1, style: String = "default", pageSize: Int = 20) async throws -> [UserNotification] {
        print("📡 Fetching messages with page: \(page), style: \(style)")
        
        var components = URLComponents(string: "\(baseURL)/user/messages")!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
            URLQueryItem(name: "style", value: style)
        ]
        
        guard let url = components.url else {
            throw NotificationNetworkError.invalidURL
        }
        
        // Get token from Keychain (same as TweetData)
        guard let token = try KeychainManager.shared.getToken() else {
            throw NotificationNetworkError.unauthorized
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationNetworkError.invalidResponse
        }
        
        print("📊 Messages response status: \(httpResponse.statusCode)")
        
        // Debug: Print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔍 RAW RESPONSE:")
            print(responseString)
        }
        
        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let data = json?["data"] as? [String: Any] {
                
                // ✅ FIXED: Handle case where list is null (no notifications)
                if let list = data["list"] as? [[String: Any]] {
                    print("📋 Found \(list.count) notifications in response")
                    
                    // Debug: Print first notification structure
                    if let firstNotification = list.first {
                        print("🔍 FIRST NOTIFICATION STRUCTURE:")
                        print(firstNotification)
                    }
                    
                    let notifications = try list.map { notificationDict in
                        try UserNotification.from(dictionary: notificationDict)
                    }
                    
                    print("✅ Parsed \(notifications.count) notifications")
                    return notifications
                } else if data["list"] == nil || data["list"] is NSNull {
                    // ✅ FIXED: Handle both nil and NSNull cases
                    print("📋 No notifications found (list is null/NSNull)")
                    return []
                } else {
                    print("⚠️ Unexpected list format in response: \(String(describing: data["list"]))")
                    throw NotificationNetworkError.invalidData
                }
            } else {
                print("⚠️ Unexpected response format for messages")
                throw NotificationNetworkError.invalidData
            }
        }
        
        throw NotificationNetworkError.serverError(httpResponse.statusCode)
    }
    
    // MARK: - Mark Single Message as Read
    static func readMessage(messageId: Int64) async throws {
        print("📝 Marking message \(messageId) as read...")
        
        guard let url = URL(string: "\(baseURL)/user/message/read") else {
            throw NotificationNetworkError.invalidURL
        }
        
        // Get token from Keychain (same as TweetData)
        guard let token = try KeychainManager.shared.getToken() else {
            throw NotificationNetworkError.unauthorized
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0
        
        let body = ["id": messageId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationNetworkError.invalidResponse
        }
        
        print("📊 Read message response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            throw NotificationNetworkError.serverError(httpResponse.statusCode)
        }
        
        print("✅ Message marked as read successfully")
    }
    
    // MARK: - Mark All Messages as Read
    static func readAllMessages() async throws {
        print("📝 Marking all messages as read...")
        
        guard let url = URL(string: "\(baseURL)/user/message/readall") else {
            throw NotificationNetworkError.invalidURL
        }
        
        // Get token from Keychain (same as TweetData)
        guard let token = try KeychainManager.shared.getToken() else {
            throw NotificationNetworkError.unauthorized
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationNetworkError.invalidResponse
        }
        
        print("📊 Read all messages response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            throw NotificationNetworkError.serverError(httpResponse.statusCode)
        }
        
        print("✅ All messages marked as read successfully")
    }
}

// ✅ REMOVED: NotificationSheet enum - now using direct fullScreenCover navigation

class NotificationManager: ObservableObject {
    @Published var unreadCount: Int64 = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var notificationState = NotificationState()
    @Published var navigationError: String?
    
    // ✅ DIRECT: Profile navigation state (same as ConversationFeedView.swift)
    @Published var showUserProfile = false
    @Published var profileToShow: (userId: Int64, username: String, initialProfile: SearchUserProfile?)? = nil
    
    // ✅ DIRECT: Profile with post navigation state
    @Published var showProfileWithPost = false
    @Published var postToShow: (userId: Int64, username: String, postId: Int64, postLocation: PostLocationResponse)? = nil
    
    // ✅ DIRECT: Post detail navigation state
    @Published var showPostDetail = false
    @Published var postIdToShow: Int64? = nil
    
    // Navigation state
    @Published var selectedPostId: Int64?
    
    // TikTok-style post navigation state
    
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 20.0 // 10 seconds - optimized for Redis performance
    
    // App state tracking
    private var isAppActive = true
    private var isUserInNotificationsTab = false
    
    // ✅ FIXED: Track previous unread count to detect changes
    private var previousUnreadCount: Int64 = 0
    
    // ✅ FIXED: Track if this is the first poll (to handle app restart)
    private var isFirstPoll: Bool = true
    
    // ✅ NEW: Track if we have new notifications to reset pagination
    private var hasNewNotifications = false
    
    // ✅ NEW: Track if we've confirmed there are no notifications
    private var hasConfirmedEmptyState = false
    
    // MARK: - Initialization
    
    init() {
        print("📱 NotificationManager initialized - starting polling")
        startPolling()
    }
    
    // MARK: - Lifecycle
    
    func startPolling() {
        print("🔄 Starting 15-second notification polling...")
        
        // ✅ FIXED: Don't call stopPolling here - we manage lifecycle properly now
        // Just invalidate existing timer if it exists
        pollingTimer?.invalidate()
        
        print("📊 Using polling interval: \(pollingInterval)s")
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { _ in
            Task {
                await self.pollUnreadCount()
            }
        }
        
        // ✅ REMOVED: Initial poll - timer will handle first call after 4 minutes
        // This was causing duplicate calls and double printing
    }
    
    func stopPolling() {
        print("⏹️ Stopping notification polling...")
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    deinit {
        print("📱 NotificationManager deinit - cleaning up polling timer")
        stopPolling()
    }
    
    // ✅ SIMPLIFIED: Single interval since all states use the same timing
    
    func updateAppState(isActive: Bool) {
        print("📱 App state changed: \(isActive ? "Active" : "Backgrounded")")
        isAppActive = isActive
        
        if isActive {
            // App became active - ensure polling is running
            if pollingTimer == nil {
                print("📱 App became active - starting polling")
                startPolling()
            } else {
                print("📱 App became active - polling already running")
            }
        } else {
            // App went to background - keep polling running for notifications
            print("📱 App went to background - keeping polling running for notifications")
        }
    }
    
    func updateNotificationsTabState(isInTab: Bool) {
        print("📱 Notifications tab state: \(isInTab ? "In tab" : "Not in tab")")
        isUserInNotificationsTab = isInTab
        
        // No need to restart polling when tab state changes
        // Polling continues regardless of which tab user is in
    }
    
    // MARK: - Main User Actions
    
    func onNotificationViewAppear() async {
        print("📱 === NOTIFICATION VIEW APPEARED ===")
        
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            // ✅ FIXED: Load only if we haven't confirmed empty state OR if new notifications detected
            if (!hasConfirmedEmptyState && notificationState.notifications.isEmpty) || hasNewNotifications {
                print("📋 \(notificationState.notifications.isEmpty ? "No notifications loaded" : "New notifications detected") - fetching from API")
                
                // Reset the flag since state is already cleared in polling
                if hasNewNotifications {
                    await MainActor.run {
                        hasNewNotifications = false // Reset the flag
                    }
                }
                
                await loadFullNotifications()
            } else {
                print("📋 Using existing notifications (\(notificationState.notifications.count) items)")
            }
            
            // ✅ MINIMAL FIX: Only auto-mark if we have unread notifications
            if self.unreadCount > 0 {
                print("📝 Auto-marking unread notifications as read")
                await autoMarkAsReadOnView()
            } else {
                print("📝 No unread notifications to mark")
            }
            
            print("✅ Notifications handled efficiently")
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                print("❌ Error in notification view: \(error)")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    func onNotificationTap(_ notification: UserNotification) async {
        print("👆 [DEBUG] onNotificationTap called for notification: \(notification.id)")
        print("👆 [DEBUG] Notification type: \(notification.notificationType.displayName)")
        
        do {
           
            // Update local state immediately for responsive UI
            await MainActor.run {
                if let index = notificationState.notifications.firstIndex(where: { $0.id == notification.id }) {
                    notificationState.notifications[index].is_read = true
                }
            }
            
            
            // Navigate to related content
            print("👆 [DEBUG] About to call navigateToContent")
            navigateToContent(notification)
            
        } catch {
            print("❌ Failed to mark notification as read: \(error)")
        }
    }
    
    // MARK: - Individual Notification Actions
    
    func markNotificationAsRead(_ notificationId: Int64) async {
        print("📝 Marking individual notification as read: \(notificationId)")
        
        do {
            try await NotificationService.readMessage(messageId: notificationId)
            
            // Update local state
            await MainActor.run {
                if let index = notificationState.notifications.firstIndex(where: { $0.id == notificationId }) {
                    notificationState.notifications[index].is_read = true
                }
            }
            
           
        } catch {
            print("❌ Failed to mark notification \(notificationId) as read: \(error)")
        }
    }
    
    // MARK: - Background Polling
    
    func pollUnreadCount() async {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timeString = formatter.string(from: timestamp)
        
        print("📡 [\(timeString)] Polling unread count...")
        do {
            let newCount = try await NotificationService.getUnreadCount()
            
            await MainActor.run {
                 // ✅ FIXED: Read on main thread to avoid race condition
                
                self.unreadCount = newCount
                
                   
                
                // Update badge visibility
                if newCount > 0 {
                    // ✅ FIXED: Only post notification if count INCREASED (new notifications)
                    // ✅ FIXED: Also check if this is not the first poll
                    if  !isFirstPoll {
                        // ✅ FIXED: Set flag and clear existing notification state
                        self.hasNewNotifications = true
                        self.hasConfirmedEmptyState = false // Reset empty state flag
                        
                        // Clear existing notification state to prevent stale data
                        notificationState.notifications.removeAll()
                        notificationState.pagination.currentPage = 1
                        notificationState.pagination.hasMoreData = true
                        notificationState.pagination.totalItems = 0
                        
                        print("🔄 [NOTIFICATION] About to post RefreshCurrentUserProfile notification...")
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RefreshCurrentUserProfile"),
                            object: nil
                        )
                        print("✅ [NOTIFICATION] RefreshCurrentUserProfile notification posted successfully")
                        print("🆕 [NOTIFICATION] New notifications detected! Cleared existing state, will load fresh data on next view appear")
                    } else if isFirstPoll && newCount > 0 {
                        isFirstPoll = false
                           NotificationCenter.default.post(
                            name: NSNotification.Name("RefreshCurrentUserProfile"),
                            object: nil
                        )
                             
                                print("🆕 [NOTIFICATION] Set isFirstPoll=false (was first poll)")
                                   print("✅ [NOTIFICATION] RefreshCurrentUserProfile notification posted successfully")
                              
                             
                    } else {
                        if isFirstPoll {
                            isFirstPoll = false
                        }
                    }
                }
            }
            
        } catch {
            print("❌ Failed to poll unread count: \(error)")
            // Don't update UI on polling errors to avoid disrupting user experience
        }
    }
    
    // MARK: - Helper Methods
    
    // ✅ DEDUPLICATION: Remove duplicate notifications based on content (post_id + sender + receiver)
    private func removeDuplicateNotifications(_ notifications: [UserNotification], existingNotifications: [UserNotification] = []) -> [UserNotification] {
        print("🔍 [DEDUPLICATION] Processing \(notifications.count) notifications for duplicates...")
        
        // Create a set of existing notification content keys for fast lookup
        let existingContentKeys = Set(existingNotifications.map { createContentKey($0) })
        
        // Filter out duplicates based on content (not just ID)
        let uniqueNotifications = notifications.filter { notification in
            let contentKey = createContentKey(notification)
            let isUnique = !existingContentKeys.contains(contentKey)
            if !isUnique {
                print("🔄 [DEDUPLICATION] Removed duplicate notification content: \(contentKey) (ID: \(notification.id))")
            }
            return isUnique
        }
        
        // Also remove duplicates within the new notifications themselves
        var seenContentKeys = Set<String>()
        let finalUniqueNotifications = uniqueNotifications.filter { notification in
            let contentKey = createContentKey(notification)
            let isUnique = seenContentKeys.insert(contentKey).inserted
            if !isUnique {
                print("🔄 [DEDUPLICATION] Removed internal duplicate notification content: \(contentKey) (ID: \(notification.id))")
            }
            return isUnique
        }
        
        let duplicatesRemoved = notifications.count - finalUniqueNotifications.count
        if duplicatesRemoved > 0 {
            print("✅ [DEDUPLICATION] Removed \(duplicatesRemoved) duplicate notifications")
        } else {
            print("✅ [DEDUPLICATION] No duplicates found")
        }
        
        return finalUniqueNotifications
    }
    
    // Helper function to create a unique content key for deduplication
    private func createContentKey(_ notification: UserNotification) -> String {
        // For post notifications, use post_id + sender + receiver
        if notification.notificationType == .post, let postId = notification.post_id {
            return "post_\(postId)_\(notification.sender_user_id)_\(notification.receiver_user_id)"
        }
        // For other notification types, use type + sender + receiver + content
        return "\(notification.notificationType.rawValue)_\(notification.sender_user_id)_\(notification.receiver_user_id)_\(notification.brief)"
    }
    
    private func loadFullNotifications() async {
        print("📡 Loading full notification content...")
        
        do {
            let allNotifications = try await NotificationService.getMessages(page: 1)
            
            await MainActor.run {
                // ✅ DEDUPLICATION: Remove duplicates based on notification ID
                let uniqueNotifications = removeDuplicateNotifications(allNotifications)
                
                notificationState.notifications = uniqueNotifications
                
                // ✅ FIXED: Update pagination state for first page
                notificationState.pagination.currentPage = 1
                // ✅ FIXED: hasMoreData based on whether we got a full page
                notificationState.pagination.hasMoreData = allNotifications.count >= 20 // Assuming page size is 20
                // ✅ FIXED: totalItems represents total loaded so far (will be updated as we load more)
                notificationState.pagination.totalItems = Int64(uniqueNotifications.count)
                
                // ✅ FIXED: Set empty state flag if no notifications
                if uniqueNotifications.isEmpty {
                    hasConfirmedEmptyState = true
                    print("📋 Confirmed empty state - will not fetch again unless new notifications arrive")
                }
                
                print("📋 Loaded \(allNotifications.count) notifications, kept \(uniqueNotifications.count) unique notifications (read + unread)")
                print("📊 Pagination: page 1, hasMore: \(notificationState.pagination.hasMoreData), total: \(notificationState.pagination.totalItems)")
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                print("❌ Failed to load notifications: \(error)")
            }
        }
    }
    
    private func markAllAsRead() async {
        print("📝 Marking all notifications as read...")
        
        do {
            try await NotificationService.readAllMessages()
            
            // Update local state to reflect read status
            await MainActor.run {
                for i in 0..<notificationState.notifications.count {
                    notificationState.notifications[i].is_read = true
                }
            }
            
            // Refresh unread count (should be 0 now)
            await pollUnreadCount()
            
            print("✅ All notifications marked as read, count should be 0")
        } catch {
            print("❌ Failed to mark all as read: \(error)")
            // Don't throw here to avoid disrupting the flow
        }
    }
    
    private func autoMarkAsReadOnView() async {
        print("📝 Auto-marking all notifications as read on view...")
        
        do {
            try await NotificationService.readAllMessages()
            
            // Update local state to reflect read status
            await MainActor.run {
                for i in 0..<notificationState.notifications.count {
                    notificationState.notifications[i].is_read = true
                }
                // ✅ FIXED: Reset unread count to 0 when marked as read
                self.unreadCount = 0
                

            }
            
            // Refresh unread count (should be 0 now)
            await pollUnreadCount()
            
            print("✅ All notifications auto-marked as read on view, count should be 0")
        } catch {
            print("❌ Failed to auto-mark all as read on view: \(error)")
            // Don't throw here to avoid disrupting the flow
        }
    }
    
    private func navigateToContent(_ notification: UserNotification) {
        print("🧭 [DEBUG] navigateToContent called for notification: \(notification.id)")
        print("🧭 [DEBUG] Notification type: \(notification.notificationType.displayName)")
    
        
        switch notification.notificationType {
        case .post:
            print("🧭 [DEBUG] Processing POST notification")
            if let postId = notification.post_id {
                print("🧭 [DEBUG] Calling navigateToPost with postId: \(postId)")
                Task {
                    await navigateToPost(postId)
                }
            }
        case .comment:
            if let postId = notification.post_id, let commentId = notification.comment_id {
                navigateToComment(postId: postId, commentId: commentId)
            }
        case .reply:
            if let postId = notification.post_id, let commentId = notification.comment_id {
                navigateToComment(postId: postId, commentId: commentId)
            }
        case .whisper:
            navigateToChat(with: notification.sender_user_id)
        case .follow:
            print("🧭 [DEBUG] Processing FOLLOW notification")
            navigateToUserProfile(userId: notification.sender_user_id)
        case .reaction:
            print("🧭 [DEBUG] Processing REACTION notification")
            navigateToUserProfile(userId: notification.sender_user_id)
        case .friendRequest:
            navigateToFriendRequests()
        case .system:
            // System notifications don't need navigation
            print("ℹ️ System notification - no navigation needed")
        }
    }
    
    // MARK: - Navigation Methods
    
    private func navigateToUserProfile(userId: Int64) {
        print("👤 [DEBUG] navigateToUserProfile called with userId: \(userId)")
        
        // Get user profile data from the notification
        if let senderUser = notificationState.notifications.first(where: { $0.sender_user_id == userId })?.sender_user {
            // Convert NotificationUserProfile to UserProfile
            let userProfile = UserProfile(
                id: senderUser.id,
                nickname: senderUser.nickname,
                username: senderUser.username,
                avatar: senderUser.avatar,
                isFollowing: false,
                status: senderUser.status,
                isAdmin: false,
                isFriend: false,
                follows: 0,
                followings: 0,
                tweetsCount: 0
            )
            
            // ✅ DIRECT: Set navigation state (same as ConversationFeedView.swift)
            print("👤 [DEBUG] Setting direct profile navigation for userId: \(userId)")
            profileToShow = (userId: userId, username: senderUser.username, initialProfile: userProfile.toSearchUserProfile())
            showUserProfile = true
            
            print("✅ Navigation state set for user profile")
            print("- User ID: \(userId)")
            print("- Username: \(senderUser.username)")
            print("- Name: \(senderUser.nickname)")
        } else {
            print("❌ Could not find user profile data for ID: \(userId)")
            print("🚫 Preventing navigation - insufficient user data")
            // Don't navigate if we can't find user profile data
            return
        }
    }
    
    private func navigateToPost(_ postId: Int64) async {
        print("\n=== 🧭 NAVIGATE TO POST FLOW ===")
        print("[DEBUG] navigateToPost called with postId: \(postId)")
        
        // Get notification data for this post
        guard let notification = notificationState.notifications.first(where: { $0.post_id == postId }) else {
            print("❌ No notification found for postId: \(postId)")
            // ✅ DIRECT: Show post detail directly
            postIdToShow = postId
            showPostDetail = true
            return
        }
        
        print("[DEBUG] Found notification for postId: \(postId)")
        print("[DEBUG] Notification details:")
        print("- Type: \(notification.notificationType.displayName)")
        print("- Sender: \(notification.sender_user?.username ?? "nil")")
        print("- Sender ID: \(notification.sender_user_id)")
        
        // Get username from notification sender
        guard let username = notification.sender_user?.username else {
            print("❌ Could not determine post owner username")
            // ✅ DIRECT: Show post detail directly
            postIdToShow = postId
            showPostDetail = true
            return
        }
        
        print("[DEBUG] About to call getPostLocation with postId: \(postId), username: \(username)")
        
        do {
            // Get post location from API
            let location = try await SpacesViewModel.getPostLocation(postId: postId, username: username)
            print("[DEBUG] getPostLocation returned: page=\(location.page), position=\(location.position), total_posts=\(location.total_posts)")
            
            await MainActor.run {
                // ✅ DIRECT: Set navigation state (same as ConversationFeedView.swift)
                print("[DEBUG] Setting direct profile with post navigation with username=\(username), postId=\(postId), page=\(location.page), position=\(location.position)")
                print("🎯 [TARGET] PostLocation data:")
                print("  - Page: \(location.page)")
                print("  - Position: \(location.position)")
                print("  - Total Posts: \(location.total_posts)")
                print("  - Page Size: \(location.page_size)")
                postToShow = (userId: notification.sender_user_id, username: username, postId: postId, postLocation: location)
                showProfileWithPost = true
                selectedPostId = postId
            }
        } catch {
            print("❌ Failed to get post location: \(error)")
            await MainActor.run {
                navigationError = "Could not locate the post. Showing fallback view."
                // ✅ DIRECT: Show post detail directly
                postIdToShow = postId
                showPostDetail = true
            }
        }
    }
    
    private func navigateToComment(postId: Int64, commentId: Int64) {
        print("💬 Navigating to comment: \(commentId) in post: \(postId)")
        
        // ✅ DIRECT: Navigate to the post and scroll to the comment
        // This can be enhanced later to directly show the comment
        postIdToShow = postId
        showPostDetail = true
        
        print("✅ Navigation state set for comment")
        print("- Post ID: \(postId)")
        print("- Comment ID: \(commentId)")
    }
    
    private func navigateToChat(with userId: Int64) {
        print("💬 Navigating to chat with user: \(userId)")
        // TODO: Implement chat navigation when chat feature is available
        print("⚠️ Chat navigation not yet implemented")
    }
    
    private func navigateToFriendRequests() {
        print("👥 Navigating to friend requests")
        // TODO: Implement friend requests navigation when feature is available
        print("⚠️ Friend requests navigation not yet implemented")
    }
    
    // MARK: - Navigation State Management
    
    // ✅ DIRECT: Clear navigation state (same as ConversationFeedView.swift)
    func clearNavigationState() {
        showUserProfile = false
        showProfileWithPost = false
        showPostDetail = false
        profileToShow = nil
        postToShow = nil
        postIdToShow = nil
        selectedPostId = nil
        print("🚪 [DEBUG] Navigation state cleared")
    }
    
    func clearNavigationError() {
        navigationError = nil
    }
    
    // MARK: - UI Helpers
    
    private func showNotificationBadge(count: Int64) {
        print("🔴 Showing badge with count: \(count)")
        // The badge is automatically updated via @Published unreadCount
        // which is observed by TwitterTabView
    }
    
    private func hideNotificationBadge() {
        print("⚪ Hiding notification badge")
        // The badge is automatically updated via @Published unreadCount
        // which is observed by TwitterTabView
    }
    
    // MARK: - Additional Methods
    
    func refreshNotifications() async {
        print("🔄 Refreshing notifications...")
        await onNotificationViewAppear()
    }
    
    func loadMoreNotifications() async {
        print("📄 Loading more notifications...")
        print("📊 Current pagination state: page \(notificationState.pagination.currentPage), hasMore: \(notificationState.pagination.hasMoreData), total: \(notificationState.pagination.totalItems)")
        
        guard !notificationState.isLoading && notificationState.pagination.hasMoreData else {
            print("⚠️ Already loading (\(notificationState.isLoading)) or no more data (\(notificationState.pagination.hasMoreData))")
            return
        }
        
        await MainActor.run {
            notificationState.isLoading = true
        }
        
        do {
            let nextPage = notificationState.pagination.currentPage + 1
            let newNotifications = try await NotificationService.getMessages(page: nextPage)
            
            await MainActor.run {
                if newNotifications.isEmpty {
                    notificationState.pagination.hasMoreData = false
                } else {
                    // ✅ DEDUPLICATION: Remove duplicates from new notifications before appending
                    let uniqueNewNotifications = removeDuplicateNotifications(newNotifications, existingNotifications: notificationState.notifications)
                    
                    // ✅ FIXED: Update notificationState.notifications (single source of truth)
                    notificationState.notifications.append(contentsOf: uniqueNewNotifications)
                    notificationState.pagination.currentPage = nextPage
                    // ✅ FIXED: Update totalItems to reflect total loaded so far
                    notificationState.pagination.totalItems = Int64(notificationState.notifications.count)
                    
                    print("📋 Loaded \(newNotifications.count) new notifications, kept \(uniqueNewNotifications.count) unique notifications")
                }
                notificationState.isLoading = false
            }
            
            print("✅ Loaded more notifications successfully")
        } catch {
            await MainActor.run {
                notificationState.error = error.localizedDescription
                notificationState.isLoading = false
                print("❌ Failed to load more notifications: \(error)")
            }
        }
    }
    
    func toggleNotificationExpansion(_ notificationId: Int64) {
        print("🔄 Toggling expansion for notification: \(notificationId)")
        
        if var state = notificationState.notificationStates[notificationId] {
            state.isExpanded.toggle()
            notificationState.notificationStates[notificationId] = state
        } else {
            if let notification = notificationState.notifications.first(where: { $0.id == notificationId }) {
                let newState = NotificationItemState(notification: notification, isExpanded: true)
                notificationState.notificationStates[notificationId] = newState
            }
        }
    }
}

struct ProfileWithPostSheet: Identifiable, Equatable {
    let id = UUID()
    let username: String
    let postId: Int64
    let postLocation: PostLocationResponse
    static func == (lhs: ProfileWithPostSheet, rhs: ProfileWithPostSheet) -> Bool {
        lhs.id == rhs.id
    }
}
