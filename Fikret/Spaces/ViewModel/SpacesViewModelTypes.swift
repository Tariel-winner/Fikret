//
//  SpacesViewModel.swift
//  Spaces
//
//  Created by Stefan Blos on 14.02.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import Foundation
import HMSSDK
//import SendbirdChatSDK
import SwiftUI
//import Supabase
//import FirebaseFirestore
import MapKit
import Ably



// Add this response structure
struct PostLocationResponse: Codable {
    let post_id: Int64
    let page: Int
    let page_size: Int
    let total_posts: Int64
    let position: Int
}


// Post Configuration
struct PostConfig {
    static var baseURL: String {
        return "http://api.tototopo.com:8008"  // Production server
    }
    
    struct Endpoints {
        static let postLocation = "/v1/posts/{postId}/location"
        static let createPost = "/v1/post"                    // Create new post
        static let deletePost = "/v1/post"                    // Delete post (use query param for id)
        static let getPost = "/v1/post"                       // Get single post (use query param for id)
        static let timeline = "/v1/posts"                     // Get timeline posts
        static let userPosts = "/v1/user/posts"              // Get user's posts
        static let userMediaPosts = "/v1/user/media/posts"   // Get user's media posts
        static let userCommentPosts = "/v1/user/comment/posts" // Get user's commented posts
        static let followingPosts = "/v1/posts"              // Get following users' posts (use style=following)
        static let hotPosts = "/v1/posts"                    // Get hot posts (use style=hots)
        static let collections = "/v1/collections"           // Get user's collections
        static let search = "/v1/search"
          static let rooms = "/rooms"                // Search posts
    }
    
    // Content types
    struct ContentType {
        static let title = 1
        static let text = 2
        static let image = 3
        static let video = 4
        static let audio = 5
        static let link = 6
        static let attachment = 7
        static let charge = 8
    }
    
  struct Visibility {
    static let `public` = 0     // ✅ Using frontend API values
    static let `private` = 1    // ✅ Using frontend API values
    static let friend = 2       // ✅ Using frontend API values
    static let following = 3    // ✅ Using frontend API values
}
}


// PostResponse struct definition
struct PostResponse: Codable {
    let id: Int64
    let user_id: [Int64]
    let user: UserResponse
    let visitor: UserResponse  // Add visitor field
    let contents: [ContentResponse]
    let tags: [String: Int8]
    let room_id: String
    let session_id: String?  // ✅ Added session_id field
    let created_on: Int64
    let visibility: Int
    let is_top: Int
    let is_essence: Int
    let is_lock: Int
    let latest_replied_on: Int64
    let modified_on: Int64
    let attachment_price: Int64
    let ip_loc: String
    // Location fields
    let location_name: String?  // ✅ Added location name field
    let location_lat: Double?  // ✅ Added location latitude field
    let location_lng: Double?  // ✅ Added location longitude field
    let location_address: String?  // ✅ Added location address field
    let location_city: String?  // ✅ Added location city field
    let location_state: String?  // ✅ Added location state field
    let location_country: String?  // ✅ Added location country field
    
    struct UserResponse: Codable {
        let id: Int64
        let nickname: String
        let username: String
        let avatar: String
        let is_friend: Bool
        let is_following: Bool
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int64.self, forKey: .id)
            nickname = try container.decode(String.self, forKey: .nickname)
            username = try container.decode(String.self, forKey: .username)
            
            // Fix malformed avatar URLs
            let rawAvatar = try container.decode(String.self, forKey: .avatar)
            avatar = rawAvatar.fixMalformedURL()
            
            is_friend = try container.decode(Bool.self, forKey: .is_friend)
            is_following = try container.decode(Bool.self, forKey: .is_following)
        }
        
        private enum CodingKeys: String, CodingKey {
            case id, nickname, username, avatar, is_friend, is_following
        }
    }
    
    struct ContentResponse: Codable {
        let id: Int64
        let post_id: Int64
        let content: String
        let type: Int
        let sort: Int64
        let duration: String?
        let size: String?
    }
}



enum APIError: Error, CustomDebugStringConvertible {
    case unauthorized
    case failedToParse(error: Error)
    case invalidURL
    case networkError(error: Error)
    case responseError(response: APIErrorResponse)
    case unknown(error: Error)
    case missingStripeAccount
    
    var debugDescription: String {
        switch self {
        case let .unauthorized:
            return "Authorised Error"
        case let .failedToParse(error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid url"
        case let .responseError(response):
            return response.error
        case let .networkError(error):
            return "Network Error: \(error.localizedDescription)"
        case let .unknown(error):
            return "An unknown error occurred: \(error)"
        case .missingStripeAccount:
                   return "Seller has no Stripe account"
               
        }
    }
}

// MARK: - Helper Functions
func withTimeout<T>(_ operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: 30_000_000_000) // 30 second timeout
            throw APIError.networkError(error: NSError(domain: "Timeout", code: -1))
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

struct APIErrorResponse: Codable {
    let error: String
}

// Move AudioConversation struct outside of SpacesViewModel class
struct AudioConversation: Identifiable, Codable, Equatable {
    let id: Int64
    let host_id: Int64
    let user_id: Int64
    let room_id: String
    let session_id: String?  // ✅ Added session_id field
    let user_name: String
    let user_image: String
    let host_name: String
    let host_image: String
    let host_audio_url: String?  // New field for host's audio
    let visitor_audio_url: String?
    let topic: String
    let duration: String
    let size: Int64?
    let created_at: Date
    // Location fields
    let location_name: String?  // ✅ Added location name field
    let location_lat: Double?  // ✅ Added location latitude field
    let location_lng: Double?  // ✅ Added location longitude field
    let location_address: String?  // ✅ Added location address field
    let location_city: String?  // ✅ Added location city field
    let location_state: String?  // ✅ Added location state field
    let location_country: String?  // ✅ Added location country field
    
    enum CodingKeys: String, CodingKey {
        case id
        case host_id
        case user_id
        case room_id
        case session_id
        case user_name
        case user_image
        case host_name
        case host_image
        case host_audio_url
        case visitor_audio_url
        case created_at
        case topic
        case duration
        case size
        case location_name
        case location_lat
        case location_lng
        case location_address
        case location_city
        case location_state
        case location_country
    }
    
    // Implement Equatable manually to ensure proper comparison
    static func == (lhs: AudioConversation, rhs: AudioConversation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.host_id == rhs.host_id &&
               lhs.user_id == rhs.user_id &&
               lhs.room_id == rhs.room_id &&
               lhs.session_id == rhs.session_id &&
               lhs.user_name == rhs.user_name &&
               lhs.user_image == rhs.user_image &&
               lhs.host_name == rhs.host_name &&
               lhs.host_image == rhs.host_image &&
               lhs.host_audio_url == rhs.host_audio_url &&
               lhs.visitor_audio_url == rhs.visitor_audio_url &&
               lhs.topic == rhs.topic &&
               lhs.duration == rhs.duration &&
               lhs.size == rhs.size &&
               lhs.created_at == rhs.created_at &&
               lhs.location_name == rhs.location_name &&
               lhs.location_lat == rhs.location_lat &&
               lhs.location_lng == rhs.location_lng &&
               lhs.location_address == rhs.location_address &&
               lhs.location_city == rhs.location_city &&
               lhs.location_state == rhs.location_state &&
               lhs.location_country == rhs.location_country
    }
}

// Extension to convert PostResponse to AudioConversation
extension PostResponse {
    func toAudioConversation() -> AudioConversation? { // ✅ CHANGED: Return optional to handle incomplete posts
        // Get the audio content (type 5)
        let audioContent = contents.first { $0.type == PostConfig.ContentType.audio }
        
        // Get host and user info
        let hostId = user.id      // Use host's actual ID
        let visitorId = visitor.id // Use visitor's actual ID
        
        var hostAudioUrl: String?
        var visitorAudioUrl: String?
        
        if let content = audioContent?.content {
            let parts = content.split(separator: "|")
            
            for part in parts {
                let components = part.split(separator: ":", maxSplits: 1)
                if components.count == 2 {
                    let userIdStr = String(components[0])
                    let url = String(components[1])
                    
                    if let userId = Int64(userIdStr) {
                        if userId == hostId {
                            hostAudioUrl = url
                        } else if userId == visitorId {
                            visitorAudioUrl = url
                        }
                    }
                }
            }
        }
        
        // ✅ VALIDATION: Only create AudioConversation if BOTH users have audio
        guard let hostAudio = hostAudioUrl, !hostAudio.isEmpty,
              let visitorAudio = visitorAudioUrl, !visitorAudio.isEmpty else {
            print("⚠️ [POST] Skipping post \(id) - missing audio content for one or both users")
            print("  - Host audio: \(hostAudioUrl ?? "nil")")
            print("  - Visitor audio: \(visitorAudioUrl ?? "nil")")
            return nil // Return nil for incomplete posts
        }

        // Get topic from tags
        let topic = tags.keys.first ?? ""
        
        // Convert size string to Int64 if needed
        let sizeValue: Int64? = audioContent?.size.flatMap { Int64($0) }
        
        return AudioConversation(
            id: id,
            host_id: hostId,
            user_id: visitorId,
            room_id: room_id,
            session_id: session_id,
            user_name: visitor.username,
            user_image: visitor.avatar,
            host_name: user.username,
            host_image: user.avatar,
            host_audio_url: hostAudio,
            visitor_audio_url: visitorAudio,
            topic: topic,
            duration: audioContent?.duration ?? "",
            size: sizeValue,
            created_at: Date(timeIntervalSince1970: TimeInterval(created_on)),
            location_name: location_name,
            location_lat: location_lat,
            location_lng: location_lng,
            location_address: location_address,
            location_city: location_city,
            location_state: location_state,
            location_country: location_country
        )
    }
}

struct APIResponse<T: Codable>: Codable {
    let code: Int
    let msg: String
    let data: T
}

struct APIRoomResponseForCreate<T: Codable>: Codable {
    let code: Int
    let msg: String
    let data: T
}
    
    struct PaginatedListResponse<T: Codable>: Codable {
    let list: [T]
    let pager: PagerResponse
}

struct APIRoomResponse<T: Codable>: Codable {
    let code: Int
    let msg: String
    let data: APIResponseData<T>
}

struct APIResponseData<T: Codable>: Codable {
    let data: T?
    let jsonResp: JsonResponse<T>?
    
    enum CodingKeys: String, CodingKey {
        case data = "Data"
        case jsonResp = "JsonResp"
    }
}

struct JsonResponse<T: Codable>: Codable {
    let code: Int
    let msg: String
    let data: T
}

struct RoomListResponse: Codable {
    let list: [RoomResponse]
    let pager: PagerResponse
}

struct PagerResponse: Codable {
    let page: Int
    let pageSize: Int
    let totalRows: Int
    
    enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case totalRows = "total_rows"
    }
}

// Add QueueResponse struct
struct QueueResponse: Codable {
    let id: Int64
    let name: String?
    let description: String?
    let isClosed: Bool
    let participants: [QueueUser]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case isClosed = "is_closed"
        case participants
    }
}

// Update RoomResponse struct
struct RoomResponse: Codable {
    let id: Int64
    let hostId: Int64
    let hmsRoomId: String?
    let speakerIds: [Int64]
    let startTime: Int64
    let createdAt: Int64
    let updatedAt: Int64
    let queue: QueueResponse
    let isBlockedFromSpace: Int16
    let speakers: [SpeakerResponse]
    let host: String
    let hostImageUrl: String
    let hostUsername: String
    let topics: [String]?
    let isHostOnline: Bool
    let categories: [Int64]?
    let isFollowing: Bool? // ✅ ADDED: Optional following status field
    let hostLocation: String? // ✅ ADDED: Optional host location field
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // ✅ DEBUG: Check what field is being decoded as id
        print("🔍 [RoomResponse.init] Decoding id field...")
        id = try container.decode(Int64.self, forKey: .id)
        print("🔍 [RoomResponse.init] Decoded id: \(id)")
        
        hostId = try container.decode(Int64.self, forKey: .hostId)
        hmsRoomId = try container.decodeIfPresent(String.self, forKey: .hmsRoomId)
        speakerIds = try container.decode([Int64].self, forKey: .speakerIds)
        startTime = try container.decode(Int64.self, forKey: .startTime)
        
        // Handle zero timestamps from API - use current time as fallback
        let rawCreatedAt = try container.decode(Int64.self, forKey: .createdAt)
        createdAt = rawCreatedAt == 0 ? Int64(Date().timeIntervalSince1970) : rawCreatedAt
        
        let rawUpdatedAt = try container.decode(Int64.self, forKey: .updatedAt)
        updatedAt = rawUpdatedAt == 0 ? Int64(Date().timeIntervalSince1970) : rawUpdatedAt
        
        queue = try container.decode(QueueResponse.self, forKey: .queue)
        isBlockedFromSpace = try container.decode(Int16.self, forKey: .isBlockedFromSpace)
        speakers = try container.decode([SpeakerResponse].self, forKey: .speakers)
        host = try container.decode(String.self, forKey: .host)
        
        // Fix malformed host avatar URL
        let rawHostImageUrl = try container.decode(String.self, forKey: .hostImageUrl)
        hostImageUrl = rawHostImageUrl.fixMalformedURL()
        
        hostUsername = try container.decode(String.self, forKey: .hostUsername)
        topics = try container.decodeIfPresent([String].self, forKey: .topics)
        isHostOnline = try container.decode(Bool.self, forKey: .isHostOnline)
        categories = try container.decodeIfPresent([Int64].self, forKey: .categories)
        isFollowing = try container.decodeIfPresent(Bool.self, forKey: .isFollowing)
        hostLocation = try container.decodeIfPresent(String.self, forKey: .hostLocation)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case hmsRoomId = "hms_room_id"
        case speakerIds = "speaker_ids"
        case startTime = "start_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case queue
        case isBlockedFromSpace = "is_blocked_from_space"
        case speakers
        case host
        case hostImageUrl = "host_image_url"
        case hostUsername = "host_username"
        case topics
        case isHostOnline = "is_host_online"
        case categories
        case isFollowing = "is_following" // ✅ ADDED: Coding key for following status
        case hostLocation = "host_location" // ✅ ADDED: Coding key for host location
    }
}

struct SpeakerResponse: Codable {
    let userId: Int64
    let username: String
    let avatar: String
    let isOnline: Bool
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(Int64.self, forKey: .userId)
        username = try container.decode(String.self, forKey: .username)
        
        // Fix malformed speaker avatar URL
        let rawAvatar = try container.decode(String.self, forKey: .avatar)
        avatar = rawAvatar.fixMalformedURL()
        
        isOnline = try container.decode(Bool.self, forKey: .isOnline)
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case avatar
        case isOnline = "is_online"
    }
}

extension RoomResponse {
    func toSpace() -> Space {
        // Convert speakers with proper field mapping
        var convertedSpeakers = speakers.map { speaker in
            SpaceParticipant(
                id: speaker.userId,
                name: speaker.username,
                username: speaker.username,
                imageURL: speaker.avatar,
                peerID: nil,
                topic: nil,
                isInvited: true,
                isOnline: speaker.isOnline
            )
        }
        
        // Add host to speakers array if not already present
        let hostParticipant = SpaceParticipant(
            id: hostId,
            name: host,
            username: hostUsername,
            imageURL: hostImageUrl,
            peerID: nil,
            topic: nil,
            isInvited: true,
            isOnline: isHostOnline
        )
        
        // Only add host if not already in speakers
        if !convertedSpeakers.contains(where: { $0.id == hostId }) {
            convertedSpeakers.insert(hostParticipant, at: 0)
        }
        
        // ✅ DEBUG: Log the actual values to see what we're getting
        print("🔍 [RoomResponse.toSpace] Creating Space with:")
        print("  - id: \(id)")
        print("  - hostId: \(hostId)")
        print("  - hmsRoomId: \(hmsRoomId ?? "nil")")
        
        return Space(
            id: id,
            hostId: hostId,
            hmsRoomId: hmsRoomId,
            speakerIdList: speakerIds,
            startTime: Date(timeIntervalSince1970: TimeInterval(startTime)),
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(updatedAt)),
            speakers: convertedSpeakers,
            queue: queue.toQueue(),
            host: host,
            hostImageUrl: hostImageUrl,
            hostUsername: hostUsername,
            isBlockedFromSpace: isBlockedFromSpace == 1,
            topics: topics,
            categories: categories,
            isHostOnline: isHostOnline,
            isFollowing: isFollowing, // ✅ ADDED: Pass following status to Space model
            hostLocation: hostLocation // ✅ ADDED: Pass host location to Space model
        )
    }
}



// Request Models
struct CreateRoomRequest: Codable {
    let hmsRoomId: String
    let topics: [String]
    
    enum CodingKeys: String, CodingKey {
        case hmsRoomId = "hms_room_id"
        case topics
    }
    
    init(hmsRoomId: String, topics: [String]) {
        self.hmsRoomId = hmsRoomId
        self.topics = topics
    }
}

struct UpdateRoomRequest: Codable {
    let roomId: Int64
    let speakerIds: [Int64]
    let topics: [String]
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case speakerIds = "speaker_ids"
        case topics
    }
}

// Helper extension for Queue conversion
extension QueueResponse {
    func toQueue() -> Queue {
        return Queue(
            id: id,
            name: name,
            description: description,
            isClosed: isClosed,
            participants: participants ?? []
        )
    }
}

// Room API Configuration
struct RoomAPI {
    static var baseURL: String {
        return "http://api.tototopo.com:8008"  // Production server
    }
    
    struct Endpoints {
        static let rooms = "/v1/rooms"
         static let sessionRegister = "/v1/session/register"
    }
}

struct SessionMapping: Codable {
    let roomId: String
    let sessionId: String
    let peerId: String
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case sessionId = "session_id"
        case peerId = "peer_id"
        case userId = "user_id"
    }
}

struct SessionRegistrationRequest: Codable {
    let sessions: [SessionMapping]
}

// Response model for session registration
struct SessionRegistrationResponse: Codable {
    let success: Bool
    let message: String
    let count: Int
}

// API Response wrapper
struct APISessionRegistrationResponse: Codable {
    let code: Int
    let msg: String
    let data: SessionRegistrationResponse
}

struct APIRoomResponseData<T: Codable>: Codable {
    let data: T?
    let jsonResp: JsonRoomResponse<T>?
    
    enum CodingKeys: String, CodingKey {
        case data = "Data"
        case jsonResp = "JsonResp"
    }
}

struct JsonRoomResponse<T: Codable>: Codable {
    let code: Int
    let msg: String
    let data: T
}

// Add CommentResponse struct and related types
struct CommentResponse: Codable {
    let id: Int64
    let post_id: Int64
    let user_id: Int64
    let user: UserInfo
    let contents: [CommentContent]
    let replies: [ReplyProps]
    let ip_loc: String
    let is_essence: Int8
    let thumbs_up_count: Int32
    let is_thumbs_up: Int8
    let is_thumbs_down: Int8
    let created_on: Int64
    let modified_on: Int64?
    let deleted_on: Int64?
    let is_del: Int8?
}

struct UserInfo: Codable {
    let id: Int64
    let username: String
    let nickname: String
    let avatar: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        nickname = try container.decode(String.self, forKey: .nickname)
        
        // Fix malformed avatar URLs
        let rawAvatar = try container.decode(String.self, forKey: .avatar)
        avatar = rawAvatar.fixMalformedURL()
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, username, nickname, avatar
    }
}

struct CommentContent: Codable {
    let id: Int64
    let comment_id: Int64
    let user_id: Int64
    let content: String
    let type: Int8
    let sort: Int64
}

struct ReplyProps: Codable {
    let id: Int64
    let comment_id: Int64
    let user_id: Int64
    let at_user_id: Int64
    let content: String
    let created_on: Int64
    let modified_on: Int64?
    let deleted_on: Int64?
    let is_del: Int8?
}

struct CommentListResponse: Codable {
    let list: [CommentResponse]
    let pager: PagerProps
}

struct PagerProps: Codable {
    let page: Int
    let page_size: Int
    var total: Int
}

// Add this new struct before the SpacesViewModel class
struct PostState {
    var post: AudioConversation
    var comments: [CommentResponse]
    var isLoadingComments: Bool
    var commentError: String?
    var commentPagination: PaginationState
    
    init(post: AudioConversation) {
        self.post = post
        self.comments = []
        self.isLoadingComments = false
        self.commentError = nil
        self.commentPagination = PaginationState()
    }
}

// Add a reusable pagination state structure
struct PaginationState {
    var currentPage: Int
    var pageSize: Int
    var totalItems: Int
    var hasMoreData: Bool
    var hasPreviousData: Bool  // Add this for bidirectional pagination
    var isLoading: Bool
    var pager: PagerResponse?
    var commentPager: PagerProps?  // Add this for comment pagination
    
    init(pageSize: Int = 20) {
        self.currentPage = 1
        self.pageSize = pageSize
        self.totalItems = 0
        self.hasMoreData = true
        self.hasPreviousData = false  // Start with false since we're on page 1
        self.isLoading = false
        self.pager = nil
        self.commentPager = nil
    }
    
    mutating func update(with pager: PagerResponse) {
        self.pager = pager
        self.totalItems = pager.totalRows
        self.hasMoreData = (pager.page * pager.pageSize) < pager.totalRows
        self.hasPreviousData = pager.page > 1  // Can load previous if not on first page
    }
    
    mutating func update(with pager: PagerProps) {
        self.commentPager = pager
        self.totalItems = pager.total
        self.hasMoreData = (pager.page * pager.page_size) < pager.total
        self.hasPreviousData = pager.page > 1  // Can load previous if not on first page
    }
    
    mutating func decrementTotal() {
        if let pager = pager {
            // For post pagination
            self.totalItems -= 1
            self.hasMoreData = (pager.page * pager.pageSize) < self.totalItems
        } else if let commentPager = commentPager {
            // For comment pagination
            self.totalItems -= 1
            self.hasMoreData = (commentPager.page * commentPager.page_size) < self.totalItems
        }
    }
    
    mutating func reset() {
        self.currentPage = 1
        self.hasMoreData = true
        self.hasPreviousData = false
        self.isLoading = false
        self.pager = nil
        self.commentPager = nil
    }
}

// Add these state structures before the SpacesViewModel class
struct UserPostsState {
    var posts: [AudioConversation]
    var postStates: [Int64: PostState]
    var pagination: PaginationState
    var error: String?
    var isLoading: Bool
    
    init(pageSize: Int = 20) {
        self.posts = []
        self.postStates = [:]
        self.pagination = PaginationState(pageSize: pageSize)
        self.error = nil
        self.isLoading = false
    }
    
    mutating func reset() {
        self.posts = []
        self.postStates = [:]
        self.pagination.reset()
        self.error = nil
        self.isLoading = false
    }
}

// Add TikTok-style conversations feed state
struct ConversationsFeedState {
    var posts: [AudioConversation]
    var pagination: PaginationState
    var error: String?
    var isLoading: Bool
    var isLoadingMore: Bool
    
    init(pageSize: Int = 20) {
        self.posts = []
        self.pagination = PaginationState(pageSize: pageSize)
        self.error = nil
        self.isLoading = false
        self.isLoadingMore = false
    }
    
    mutating func reset() {
        self.posts = []
        self.pagination.reset()
        self.error = nil
        self.isLoading = false
        self.isLoadingMore = false
    }

     
}


