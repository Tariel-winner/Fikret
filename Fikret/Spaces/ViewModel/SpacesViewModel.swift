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
import LiveKit


public class SpacesViewModel: ObservableObject, /*RoomDelegate, */ HMSUpdateListener {
    // MARK: - Shared Instance (Same Pattern as TweetData)
    static let shared = SpacesViewModel()
    
    // MARK: - User's Own Space Persistence
    private let userDefaults = UserDefaults.standard
    private let userOwnSpaceKey = "userOwnSpace"
    
    // MARK: - Loading and Pagination Properties
    @Published var authenticatedUserPosts = UserPostsState()
    @Published var otherUserPosts: [String: UserPostsState] = [:] // username: UserPostsState
    @Published var postStates: [Int64: PostState] = [:] // Store post states with comments
    private var audioLevelTimer: Timer?
    
    // ✅ OPTIMIZED: Cached sets for O(1) lookups
    private var authenticatedUserPostIds: Set<Int64> = []
    private var otherUserPostIds: [String: Set<Int64>] = [:]
    var queueParticipantIds: [Int64: Set<Int64>] = [:] // spaceId: Set<userId>
    
    // ✅ OPTIMIZED: Caches for space lookups
    var spaceIdsToIndex: [Int64: Int] = [:] // spaceId: arrayIndex for O(1) space lookups
    var hostIdToSpaceId: [Int64: Int64] = [:] // hostId: spaceId for O(1) host space lookups
    
    // ✅ CACHE VALIDATION: Periodic validation timer
    private var cacheValidationTimer: Timer?
    private var cacheValidationInterval: TimeInterval = 300 // 5 minutes
    
    // TikTok-style pagination for conversations feed
    @Published var conversationsFeed: ConversationsFeedState = ConversationsFeedState()
    @Published var isLoadingConversations = false
    @Published var isLoadingMoreConversations = false
    @Published var lastViewedConversationIndex: Int = 0
    @Published var lastViewedConversationPage: Int = 1
    @Published var currentPageConversations = 0
    @Published var hasMoreDataConversations = true
    @Published var loadedPagesConversations: Set<Int> = Set<Int>()
    var conversationLoadRetryCount = 0
    let conversationMaxRetries = 3
    let conversationPageSize: Int = 20

    // TikTok-style pagination for spaces feed
    @Published var isLoadingMoreSpaces = false
    @Published var lastViewedSpaceIndex: Int = 0
    @Published var lastViewedSpacePage: Int = 1
    @Published var isLoadingSpaces = false
    @Published var loadErrorSpaces: String? = nil
    @Published var loadedPagesSpaces: Set<Int> = Set<Int>()
    var spaceLoadRetryCount = 0
    let spaceMaxRetries = 3
    let spacePageSize: Int = 20
    @Published var currentPageSpaces = 0
    @Published var hasMoreDataSpaces = true


    @Published var isTimerCompleted: Bool = false
    @Published var isJoining: Bool = false // ✅ ADDED: Track joining state for smooth navigation
    
    // MARK: - Ably Properties
    var spaceChannel: ARTRealtimeChannel?
    var presenceChannel: ARTRealtimeChannel?
    var joinLock: [Int64: Bool] = [:] // Lock to prevent multiple joins
    
    // MARK: - Real-time Host Status Management
    
    // ✅ NO CACHE NEEDED: We only use real-time WebSocket data
    // If WebSocket unavailable, we don't show misleading cached status
    
    // Track active presence subscription (only one host monitored at a time)
    var activePresenceSubscriptions: Int64? = nil
    
    // This variable is declared but never set!
@Published var currentSpaceSessionStartTime: Date? = nil
    @Published var isSidePanelVisible = false
    @Published var isSpaceSuperMinimized = false
    @Published var isQueueSuperMinimized = false
    @Published var fannedOutSpaces: [Space] = []
    @Published var isSpiderfied: Bool = false
    @Published var spiderfyCenter: CLLocationCoordinate2D? = nil
   // @Published var talkCards: [TalkCard] = []
    @Published var  isLoading = false
    let tweetData: TweetData
    let locationService: LocationService
    
    // MARK: - Audio Session Management
    @Published var isAudioSessionActive = false
    @Published var showFinishConversationOverlay = false
    

           // Transitioning animations state
      @Published var speakerPositions: [Int64: CGSize] = [:]
      @Published var enteringSpeakerIds: Set<Int64> = []
      @Published var leavingSpeakerIds: Set<Int64> = []
      
      // ✅ ADDED: Helper methods for speaker animation states
      func isSpeakerEntering(_ speakerId: Int64) -> Bool {
          return enteringSpeakerIds.contains(speakerId)
      }
      
      func isSpeakerLeaving(_ speakerId: Int64) -> Bool {
          return leavingSpeakerIds.contains(speakerId)
      }

    init(tweetData: TweetData = TweetData.shared, locationService: LocationService = LocationService.shared) {
        print("🚀 [INIT] SpacesViewModel init started")
        self.tweetData = tweetData
        self.locationService = locationService
        // Initialize other properties
        self.spaces = []
        self.isLoading = false
        print("📱 [INIT] f \(spaces.count) spaces")
        
        // Set up other async tasks first (don't depend on user authentication)
        Task { @MainActor in
            print("🔄 [INIT] Setting up notification handlers...")
            await setupNotificationHandlers()
            
            print("🔄 [INIT] Setting up notification observers...")
            setupNotificationObservers()
            
            print("🔄 [INIT] Setting up app lifecycle handling...")
            setupAppLifecycleHandling()
            
            print("🔄 [INIT] Starting periodic cache validation...")
            startPeriodicCacheValidation()
            
            print("✅ [INIT] All async setup tasks completed")
        }
        
        // ✅ FIXED: Listen for authentication complete notification instead of unreliable while loop
        NotificationCenter.default.addObserver(
            forName: Notification.Name("UserAuthenticationComplete"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let userId = notification.userInfo?["userId"] as? Int64,
                   let username = notification.userInfo?["username"] as? String {
                    print("🔔 [AUTH] Received authentication complete notification for user: \(username) (ID: \(userId))")
                    
                    // Load user's own space now that authentication is complete
                    await self.ensureUserOwnSpaceAvailable()
                    print("✅ [AUTH] User's own space check completed - Spaces count: \(self.spaces.count) - \(self.spaces.map { $0.id })")
                }
            }
        }
        
        print("🚀 [INIT] SpacesViewModel init completed")
    }
    
    // MARK: - Audio Session Management
    
    /// Pause all background audio when entering a space
    func pauseAllBackgroundAudio() {
        print("🔇 [AudioSession] Pausing all background audio")
        isAudioSessionActive = true
        
        // Notify all WebMAudioPlaybackManager instances to pause
        NotificationCenter.default.post(name: .pauseAllBackgroundAudio, object: nil)
    }
    
    /// Resume background audio when leaving a space
    func resumeBackgroundAudio() {
        print("🔊 [AudioSession] Resuming background audio")
        isAudioSessionActive = false
        
        // Notify all WebMAudioPlaybackManager instances to resume
        NotificationCenter.default.post(name: .resumeBackgroundAudio, object: nil)
    }
    
    /// Force stop all audio (emergency stop)
    func forceStopAllAudio() {
        print("🛑 [AudioSession] Force stopping all audio")
        isAudioSessionActive = false
        
        // Notify all WebMAudioPlaybackManager instances to stop
        NotificationCenter.default.post(name: .forceStopAllAudio, object: nil)
    }
    
    /// Check if audio session is blocked (space is active)
    var isAudioSessionBlocked: Bool {
        let isBlocked = isAudioSessionActive || isInSpace
        
        // ✅ FIXED: Show beautiful overlay when space is minimized and user tries to play audio
        if isInSpace && !showSpaceView && !showFinishConversationOverlay {
            DispatchQueue.main.async {
                self.showFinishConversationOverlay = true
                
                // Auto-hide overlay after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if self.showFinishConversationOverlay {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            self.showFinishConversationOverlay = false
                        }
                    }
                }
            }
        }
        
        return isBlocked
    }









// Update the getTimeline method to initialize post states
func getTimeline(page: Int = 1, pageSize: Int = 20) async throws -> [Space] {
    let conversations = try await withTimeout { [weak self] in
        guard let self = self else { throw APIError.unknown(error: NSError(domain: "SelfDeallocated", code: -1)) }
        return try await self.listRooms(spacePage: page, spacePageSize: pageSize)
            
    }
    
 
    
    return conversations
}

// Add methods to manage user posts state

@MainActor
func loadUserPosts(username: String, page: Int = 1, forceRefresh: Bool = false) async {
    print("📱 [PAGINATION] loadUserPosts - username: \(username), page: \(page)")
    
    // Determine if this is the authenticated user's profile
    let isAuthenticatedUser = username == tweetData.user?.username
   
    // Get or create the appropriate state
    var state: UserPostsState
    if isAuthenticatedUser {
        state = authenticatedUserPosts
    } else {
        state = otherUserPosts[username] ?? UserPostsState()
    }
    
    // Reset state if force refresh OR if this is a targeted page load (page > 1) and we don't have any posts yet
    if forceRefresh {
        state = UserPostsState()
    }
    
    // For targeted pages, we need to ensure we have all previous pages loaded
    // If we're loading page 3 but only have page 1, we need to load page 2 first
    if page > 1 && state.posts.isEmpty {
        print("📱 [ORDER] Loading targeted page \(page) but no existing posts - resetting state")
        state = UserPostsState()
    }
    
    // Update loading state
    state.isLoading = true
    state.error = nil
    
    // Update the appropriate state immediately to show loading UI
    if isAuthenticatedUser {
        authenticatedUserPosts = state
    } else {
        otherUserPosts[username] = state
    }
    
    do {
        // Get posts and pagination info from API
        let (posts, paginationInfo) = try await SpacesViewModel.getUserPostsWithPagination(username: username, page: page)
        
        // Log API response order
        print("📱 [API] Posts from API (page \(page)): \(posts.map { $0.id })")
        
        // Handle different page loading scenarios
        if page == 1 {
            // For first page, replace all posts
            state.posts = posts
            
            // Update postStates for new posts
            for post in posts {
                if state.postStates[post.id] == nil {
                    state.postStates[post.id] = PostState(post: post)
                } else {
                    var existingState = state.postStates[post.id]!
                    existingState.post = post
                    state.postStates[post.id] = existingState
                }
            }
            
            // Update pagination state using actual API data
            state.pagination.currentPage = paginationInfo.page
            state.pagination.totalItems = Int(paginationInfo.totalRows)
            state.pagination.pageSize = paginationInfo.pageSize
            
            // Calculate hasMoreData and hasPreviousData correctly
            let totalPages = (state.pagination.totalItems + state.pagination.pageSize - 1) / state.pagination.pageSize
            state.pagination.hasMoreData = page < totalPages
            state.pagination.hasPreviousData = page > 1  // Can load previous if not on first page
            
        } else {
            // For targeted pages, we need to handle appending correctly
            // Check if we have a gap in pages (e.g., we have page 1 but loading page 3)
            let expectedPostCount = (page - 1) * state.pagination.pageSize
            let actualPostCount = state.posts.count
            
            if actualPostCount < expectedPostCount {
                print("📱 [ORDER] Warning: Loading page \(page) but only have \(actualPostCount) posts (expected \(expectedPostCount))")
                print("📱 [ORDER] This might indicate missing pages - replacing posts to maintain order")
                // Replace posts to maintain correct order
                state.posts = posts
            } else {
                print("📱 [ORDER] Loading page \(page) - appending to existing posts")
                // Simply append the new posts to maintain the order from API
                state.posts.append(contentsOf: posts)
            }
            
            // Update postStates for new posts
            for post in posts {
                if state.postStates[post.id] == nil {
                    state.postStates[post.id] = PostState(post: post)
                } else {
                    var existingState = state.postStates[post.id]!
                    existingState.post = post
                    state.postStates[post.id] = existingState
                }
            }
            
            // Update pagination state for targeted page using actual API data
            state.pagination.currentPage = paginationInfo.page
            state.pagination.totalItems = Int(paginationInfo.totalRows)
            state.pagination.pageSize = paginationInfo.pageSize
            
            // Calculate hasMoreData and hasPreviousData correctly
            let totalPages = (state.pagination.totalItems + state.pagination.pageSize - 1) / state.pagination.pageSize
            state.pagination.hasMoreData = page < totalPages
            state.pagination.hasPreviousData = page > 1  // Can load previous if not on first page
        }
        
        // Final pagination state update
        state.pagination.isLoading = false
        
        // Log final state
        print("📱 [STATE] Final posts order: \(state.posts.map { "ID:\($0.id)" })")
        print("📱 [STATE] Posts count: \(state.posts.count)")
        print("📱 [PAGINATION] currentPage: \(state.pagination.currentPage), hasMoreData: \(state.pagination.hasMoreData), hasPreviousData: \(state.pagination.hasPreviousData), totalItems: \(state.pagination.totalItems)")
        
        // ✅ OPTIMIZED: Update cached sets for O(1) lookups
        if isAuthenticatedUser {
            authenticatedUserPostIds = Set(state.posts.map { $0.id })
            authenticatedUserPosts = state
        } else {
            otherUserPostIds[username] = Set(state.posts.map { $0.id })
            otherUserPosts[username] = state
        }
        
    } catch {
        print("❌ Error loading posts: \(error)")
        state.error = error.localizedDescription
        state.isLoading = false
        
        if isAuthenticatedUser {
            authenticatedUserPosts = state
        } else {
            otherUserPosts[username] = state
        }
    }
}

// Add method to clear user posts state
@MainActor
func clearUserPosts(username: String) {
    if username == tweetData.user?.username {
        authenticatedUserPosts = UserPostsState()
        // ✅ OPTIMIZED: Clear cached set for O(1) lookups
        authenticatedUserPostIds.removeAll()
    } else {
        otherUserPosts.removeValue(forKey: username)
        // ✅ OPTIMIZED: Clear cached set for O(1) lookups
        otherUserPostIds.removeValue(forKey: username)
    }
    
    // ✅ OPTIMIZED: Use cached sets for O(1) lookup instead of O(n²) nested linear searches
    let postIdsToRemove: [Int64]
    if username == tweetData.user?.username {
        postIdsToRemove = Array(postStates.keys.filter { authenticatedUserPostIds.contains($0) })
    } else {
        let userPostIds = otherUserPostIds[username] ?? Set()
        postIdsToRemove = Array(postStates.keys.filter { userPostIds.contains($0) })
    }
    
    for postId in postIdsToRemove {
        postStates.removeValue(forKey: postId)
    }
}

// Add method to clear all user posts (useful for app lifecycle events)
@MainActor
func clearAllUserPosts() {
    // Clear authenticated user posts
    authenticatedUserPosts = UserPostsState()
    
    // Clear all other user posts
    otherUserPosts.removeAll()
    
    // Clear all post states
    postStates.removeAll()
    
    // ✅ OPTIMIZED: Clear cached sets for O(1) lookups
    authenticatedUserPostIds.removeAll()
    otherUserPostIds.removeAll()
    queueParticipantIds.removeAll()
    
    // ✅ OPTIMIZED: Clear space lookup caches
    spaceIdsToIndex.removeAll()
    hostIdToSpaceId.removeAll()
}

// Add method to check if there are more posts to load
@MainActor func hasMorePosts(username: String) -> Bool {
    if username == tweetData.user?.username {
        return authenticatedUserPosts.pagination.hasMoreData
    } else {
        return otherUserPosts[username]?.pagination.hasMoreData ?? false
    }
}

// Add method to check if there are previous posts to load
@MainActor func hasPreviousPosts(username: String) -> Bool {
    if username == tweetData.user?.username {
        return authenticatedUserPosts.pagination.hasPreviousData
    } else {
        return otherUserPosts[username]?.pagination.hasPreviousData ?? false
    }
}

// Add method to get current page
    @MainActor func getCurrentPage(username: String) -> Int {
    if username == tweetData.user?.username {
        return authenticatedUserPosts.pagination.currentPage
    } else {
        return otherUserPosts[username]?.pagination.currentPage ?? 1
    }
}

// Add method to get total posts count
    @MainActor func getTotalPosts(username: String) -> Int {
    if username == tweetData.user?.username {
        return authenticatedUserPosts.pagination.totalItems
    } else {
        return otherUserPosts[username]?.pagination.totalItems ?? 0
    }
}

// Add method to get pagination info for debugging
@MainActor func getPaginationInfo(username: String) -> (currentPage: Int, totalItems: Int, hasMoreData: Bool, isLoading: Bool) {
    if username == tweetData.user?.username {
        let pagination = authenticatedUserPosts.pagination
        return (pagination.currentPage, pagination.totalItems, pagination.hasMoreData, pagination.isLoading)
    } else {
        let pagination = otherUserPosts[username]?.pagination ?? PaginationState()
        return (pagination.currentPage, pagination.totalItems, pagination.hasMoreData, pagination.isLoading)
    }
}

// Add method to load previous posts (bidirectional loading)
@MainActor
func loadPreviousPosts(username: String) async {
    print("📱 [PAGINATION] loadPreviousPosts - username: \(username)")
    
    let isAuthenticatedUser = username == tweetData.user?.username
    var state = isAuthenticatedUser ? authenticatedUserPosts : (otherUserPosts[username] ?? UserPostsState())
    
    // Check if we can load previous posts
    guard !state.pagination.isLoading && state.pagination.hasPreviousData else {
        print("❌ Cannot load previous posts - hasPreviousData: \(state.pagination.hasPreviousData)")
        return
    }
    
    state.pagination.isLoading = true
    if isAuthenticatedUser {
        authenticatedUserPosts = state
    } else {
        otherUserPosts[username] = state
    }
    
    do {
        let previousPage = state.pagination.currentPage - 1
        print("📱 [PAGINATION] Loading previous page: \(previousPage)")
        let (posts, paginationInfo) = try await SpacesViewModel.getUserPostsWithPagination(username: username, page: previousPage)
        
        print("📱 [API] Previous posts from API (page \(previousPage)): \(posts.map { $0.id })")
        
        // ✅ OPTIMIZED: Use cached set for O(1) lookup instead of O(n) linear search
        let currentPostIds = isAuthenticatedUser ? authenticatedUserPostIds : (otherUserPostIds[username] ?? Set())
        
        // Merge previous posts with existing ones
        // Insert posts in reverse order to maintain correct chronological order
        for post in posts.reversed() {
            if !currentPostIds.contains(post.id) {
                // Prepend the post to maintain API order
                state.posts.insert(post, at: 0)
                state.postStates[post.id] = PostState(post: post)
            } else {
                if let existingIndex = state.posts.firstIndex(where: { $0.id == post.id }) {
                    state.posts[existingIndex] = post
                    if var existingState = state.postStates[post.id] {
                        existingState.post = post
                        state.postStates[post.id] = existingState
                    }
                }
            }
        }
        
        // Update pagination state using API data
        state.pagination.currentPage = paginationInfo.page
        state.pagination.totalItems = Int(paginationInfo.totalRows)
        state.pagination.pageSize = paginationInfo.pageSize
        
        let totalPages = (state.pagination.totalItems + state.pagination.pageSize - 1) / state.pagination.pageSize
        state.pagination.hasMoreData = state.pagination.currentPage < totalPages
        state.pagination.hasPreviousData = state.pagination.currentPage > 1  // Update hasPreviousData
        state.pagination.isLoading = false
        
        print("📱 [STATE] After loading previous - posts order: \(state.posts.map { $0.id })")
        print("📱 [STATE] Posts count: \(state.posts.count)")
        print("📱 [PAGINATION] currentPage: \(state.pagination.currentPage), hasMoreData: \(state.pagination.hasMoreData)")
        
        // ✅ OPTIMIZED: Update cached sets for O(1) lookups
        if isAuthenticatedUser {
            authenticatedUserPostIds = Set(state.posts.map { $0.id })
            authenticatedUserPosts = state
        } else {
            otherUserPostIds[username] = Set(state.posts.map { $0.id })
            otherUserPosts[username] = state
        }
    } catch {
        print("❌ Error loading previous posts: \(error)")
        state.error = error.localizedDescription
        state.pagination.isLoading = false
        if isAuthenticatedUser {
            authenticatedUserPosts = state
        } else {
            otherUserPosts[username] = state
        }
    }
}

// Add method to load more posts (existing method)
@MainActor
func loadMorePosts(username: String) async {
    print("📱 [PAGINATION] loadMorePosts - username: \(username)")
    
    let isAuthenticatedUser = username == tweetData.user?.username
    var state = isAuthenticatedUser ? authenticatedUserPosts : (otherUserPosts[username] ?? UserPostsState())
    
    // Check if we can load more
    guard !state.pagination.isLoading && state.pagination.hasMoreData else {
        print("❌ Cannot load more posts - hasMoreData: \(state.pagination.hasMoreData)")
        return
    }
    
    state.pagination.isLoading = true
    if isAuthenticatedUser {
        authenticatedUserPosts = state
    } else {
        otherUserPosts[username] = state
    }
    
    do {
        let nextPage = state.pagination.currentPage + 1
        print("📱 [PAGINATION] Loading next page: \(nextPage)")
        let (posts, paginationInfo) = try await SpacesViewModel.getUserPostsWithPagination(username: username, page: nextPage)
        
        print("📱 [API] Next posts from API (page \(nextPage)): \(posts.map { $0.id })")
        
        // ✅ OPTIMIZED: Use cached set for O(1) lookup instead of O(n) linear search
        let currentPostIds = isAuthenticatedUser ? authenticatedUserPostIds : (otherUserPostIds[username] ?? Set())
        
        // Merge new posts with existing ones
        for post in posts {
            if currentPostIds.contains(post.id) {
                // Update existing post
                if let existingIndex = state.posts.firstIndex(where: { $0.id == post.id }) {
                    state.posts[existingIndex] = post
                    if var existingState = state.postStates[post.id] {
                        existingState.post = post
                        state.postStates[post.id] = existingState
                    }
                }
            } else {
                // Add new post - maintain API order
                state.posts.append(post)
                state.postStates[post.id] = PostState(post: post)
            }
        }
        
        // Update pagination with proper logic using API data
        state.pagination.currentPage = paginationInfo.page
        state.pagination.totalItems = Int(paginationInfo.totalRows)
        state.pagination.pageSize = paginationInfo.pageSize
        
        let totalPages = (state.pagination.totalItems + state.pagination.pageSize - 1) / state.pagination.pageSize
        state.pagination.hasMoreData = state.pagination.currentPage < totalPages
        state.pagination.hasPreviousData = state.pagination.currentPage > 1  // Update hasPreviousData
        state.pagination.isLoading = false
        
        print("📱 [STATE] After loading more - posts order: \(state.posts.map { $0.id })")
        print("📱 [STATE] Posts count: \(state.posts.count)")
        print("📱 [PAGINATION] currentPage: \(state.pagination.currentPage), hasMoreData: \(state.pagination.hasMoreData), hasPreviousData: \(state.pagination.hasPreviousData)")
        
        // ✅ OPTIMIZED: Update cached sets for O(1) lookups
        if isAuthenticatedUser {
            authenticatedUserPostIds = Set(state.posts.map { $0.id })
            authenticatedUserPosts = state
        } else {
            otherUserPostIds[username] = Set(state.posts.map { $0.id })
            otherUserPosts[username] = state
        }
    } catch {
        print("❌ Error loading more posts: \(error)")
        state.error = error.localizedDescription
        state.pagination.isLoading = false
        if isAuthenticatedUser {
            authenticatedUserPosts = state
        } else {
            otherUserPosts[username] = state
        }
    }
}

    // Refresh posts for a user
@MainActor
func refreshPosts(username: String) async {
        let isAuthenticatedUser = username == tweetData.user?.username
        var state = isAuthenticatedUser ? authenticatedUserPosts : (otherUserPosts[username] ?? UserPostsState())
        
        state.reset()
        if isAuthenticatedUser {
            authenticatedUserPosts = state
        } else {
            otherUserPosts[username] = state
        }
        
        await loadMorePosts(username: username)
}


// Simple API response structure for responses without data
struct SimpleAPIResponse: Codable {
    let code: Int
    let msg: String
}

// Method to register multiple sessions at once
func registerSessions(_ sessions: [SessionMapping]) async throws -> SessionRegistrationResponse {
    guard let token = try KeychainManager.shared.getToken() else {
        throw APIError.unauthorized
    }
    
    let url = URL(string: "\(RoomAPI.baseURL)\(RoomAPI.Endpoints.sessionRegister)")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Create request body
    let requestBody = SessionRegistrationRequest(sessions: sessions)
    
    let jsonData = try JSONEncoder().encode(requestBody)
    request.httpBody = jsonData
    
    // Add debug printing
    if let jsonString = String(data: jsonData, encoding: .utf8) {
        print("📤 Sending session registration for \(sessions.count) sessions: \(jsonString)")
    }
    
    let (data, _) = try await URLSession.shared.data(for: request)
    
    // Add debug printing
    if let jsonString = String(data: data, encoding: .utf8) {
        print("📦 Received session registration response: \(jsonString)")
    }
    
    // First check if this is a simple success response without data
    if let simpleResponse = try? JSONDecoder().decode(SimpleAPIResponse.self, from: data) {
        print("📋 Simple API response - Code: \(simpleResponse.code), Message: \(simpleResponse.msg)")
        if simpleResponse.code == 200 {
            // Success response without data - return empty response
            return SessionRegistrationResponse(success: true, message: simpleResponse.msg, count: 0)
        } else {
            throw APIError.invalidURL
        }
    }
    
    // Try to decode as full response with data
    let response = try JSONDecoder().decode(APISessionRegistrationResponse.self, from: data)
    
    if response.code != 0 {
        throw APIError.invalidURL
    }
    
    return response.data
}

// Convenience method for single session (backward compatibility)
func registerSession(roomId: String, sessionId: String, peerId: String, userId: String) async throws -> SessionRegistrationResponse {
    let session = SessionMapping(
        roomId: roomId,
        sessionId: sessionId,
        peerId: peerId,
        userId: userId
    )
    return try await registerSessions([session])
}

    
    func getMyRoom() async throws -> Space {
        guard let token = try KeychainManager.shared.getToken() else {
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(RoomAPI.baseURL)\(RoomAPI.Endpoints.rooms)/user")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Add debug printing
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📦 Received JSON for my room: \(jsonString)")
        }
        
        let response = try JSONDecoder().decode(APIRoomResponseForCreate<RoomResponse>.self, from: data)
        let roomResponse = response.data
        let fetchedSpace = roomResponse.toSpace()
        
        // ✅ PERSISTENT STORAGE: Save the fetched space to UserDefaults
        await MainActor.run {
            saveUserOwnSpace(fetchedSpace)
            updateSpacesWithNewData(fetchedSpace)
            print("✅ [PERSISTENCE] User's own space updated from API and saved to UserDefaults")
        }
        
        return fetchedSpace
    }
    
    // Helper function to avoid code duplication
 func updateSpacesWithNewData(_ fetchedSpace: Space) {
        // ✅ FIXED: Find spaces with the same ID (not hmsRoomId) to prevent wrong replacements
        if let index = spaces.firstIndex(where: { $0.id == fetchedSpace.id }) {
            // Update existing space with new data
            spaces[index] = fetchedSpace
            
            // If this is the selected space, update it too
            if selectedSpace?.id == fetchedSpace.id {
                selectedSpace = fetchedSpace
            }
        } else {
            // If no space with this ID exists, append the new space
            spaces.append(fetchedSpace)
        }
    }
    
    // Create Room
    func createRoom(hmsRoomId: String, topics: [String], categories: [Int64]? = nil) async throws -> Space {
        guard let token = try KeychainManager.shared.getToken() else {
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(RoomAPI.baseURL)\(RoomAPI.Endpoints.rooms)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create request body directly as dictionary
        var body: [String: Any] = [
            "hms_room_id": hmsRoomId,
            "topics": topics
        ]
        
        // Add categories if provided
        if let categories = categories {
            body["categories"] = categories
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(APIRoomResponseForCreate<RoomResponse>.self, from: data)
        print("🔍 [createRoom] Response: \(response.data)")
        let space = response.data.toSpace()
        
        // ✅ PERSISTENT STORAGE: Save user's own space to UserDefaults
        await MainActor.run {
            saveUserOwnSpace(space)
            print("✅ [PERSISTENCE] User's own space saved to UserDefaults")
            print("📋 Space ID: \(space.id)")
            print("📋 HMS Room ID: \(space.hmsRoomId ?? "nil")")
            print("📋 Host ID: \(space.hostId)")
        }
        
 
        
        return space
    }
    
    // Update Room
    func updateRoom(id: Int64, speakerIds: [Int64], topics: [String]) async throws -> Space {
        guard let token = try KeychainManager.shared.getToken() else {
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(RoomAPI.baseURL)\(RoomAPI.Endpoints.rooms)/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = UpdateRoomRequest(
            roomId: id,
            speakerIds: speakerIds,
            topics: topics
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(APIRoomResponse<RoomResponse>.self, from: data)
        let roomResponse = response.data.jsonResp!.data
        return roomResponse.toSpace()
    }
    
 
    
    func getHotPosts(page: Int = 1, pageSize: Int = 20) async throws -> [AudioConversation] {
        guard let token = try KeychainManager.shared.getToken() else {
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(PostConfig.baseURL)\(PostConfig.Endpoints.hotPosts)?style=hots&page=\(page)&page_size=\(pageSize)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(APIResponse<[PostResponse]>.self, from: data)
        // ✅ FILTER: Only include posts with complete audio content for both users
        return response.data.compactMap { $0.toAudioConversation() }
    }
    
    struct CreateTweetRequest: Codable {
        let contents: [PostContent]
        let tags: [String]
        let users: [String]
        let attachmentPrice: Int64
        let visibility: Int
        let roomId: String
        let sessionId: String?
        let locationData: LocationData? // ✅ ADDED: Location data field
        
        enum CodingKeys: String, CodingKey {
            case contents
            case tags
            case users
            case attachmentPrice = "attachment_price"
            case visibility
            case roomId = "room_id"
            case sessionId = "session_id"
            case locationData = "locationData" // ✅ ADDED: Location data coding key
        }
    }
    
    struct PostContent: Codable {
        let content: String
        let type: Int
        let sort: Int64
        let duration: String?
        let size: String?
    }
    
    // API call functions
    func createAudioTweet(roomId: String, sessionId: String, visitorUsername:String, audioContent: String, duration: String, size: String, tag: String, visibility: Int = PostConfig.Visibility.public, locationData: LocationData? = nil) async throws -> Bool {
        guard let token = try KeychainManager.shared.getToken() else {
            throw APIError.unauthorized
        }
       
        let request = CreateTweetRequest(
            contents: [
                PostContent(
                    content: audioContent,
                    type: PostConfig.ContentType.audio,
                    sort: 0,
                    duration: duration,
                    size: size
                )
            ],
            tags: [tag],
            users: [visitorUsername], // Will be filled by backend based on roomId
            attachmentPrice: 0,
            visibility: visibility,
            roomId: roomId,
            sessionId: sessionId,
            locationData: locationData // ✅ ADDED: Pass location data to request
        )
        
        let url = URL(string: "\(PostConfig.baseURL)\(PostConfig.Endpoints.createPost)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // ✅ PROPER: Check HTTP status code first (standard HTTP success)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(error: NSError(domain: "HTTPResponse", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]))
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidURL
        }
        
        // Decode the API response
        let apiResponse = try JSONDecoder().decode(APIResponse<PostResponse>.self, from: data)
        
        // ✅ SAFE: Check if we have data (creation succeeded)
        return apiResponse.data != nil
    }
    
    static func getPost(id: Int64) async throws -> AudioConversation? {
        guard let token = try KeychainManager.shared.getToken() else {
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(PostConfig.baseURL)\(PostConfig.Endpoints.getPost)?id=\(id)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let response = try JSONDecoder().decode(APIResponse<PostResponse>.self, from: data)
        
        // ✅ OPTIONAL: Return the conversation if valid, nil if incomplete audio content
        return response.data.toAudioConversation()
    }
    




static func getPostLocation(postId: Int64, username: String) async throws -> PostLocationResponse {
    print("\n=== 📱 GET POST LOCATION API CALL ===")
    print("🆔 Post ID: \(postId)")
    print("👤 Username: \(username)")
    
    guard let token = try KeychainManager.shared.getToken() else {
        print("❌ No token found")
        throw APIError.unauthorized
    }
    
    // --- FIX: Always replace {postId} before URL creation ---
    let endpointBefore = PostConfig.Endpoints.postLocation
    let endpoint = endpointBefore.replacingOccurrences(of: "{postId}", with: String(postId))
    let urlString = "\(PostConfig.baseURL)\(endpoint)?username=\(username)"
    print("DEBUG: endpoint before replacement: \(endpointBefore)")
    print("DEBUG: endpoint after replacement: \(endpoint)")
    print("DEBUG: urlString: \(urlString)")
    let url = URL(string: urlString)!
    print("🌐 Request URL: \(url)")
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "GET"
    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    
    // Log raw response
    if let httpResponse = response as? HTTPURLResponse {
        print("\n📡 HTTP Response:")
        print("- Status Code: \(httpResponse.statusCode)")
        print("- Headers: \(httpResponse.allHeaderFields)")
    }
   
    do {
        // Decode the response with the correct structure
        let response = try JSONDecoder().decode(APIResponse<PostLocationResponse>.self, from: data)
        
        print("\n✅ DECODED RESPONSE:")
        print("- Page: \(response.data.page)")
        print("- Position: \(response.data.position)")
        print("- Total Posts: \(response.data.total_posts)")
        print("- Full Response: \(response.data)")
        
        return response.data
        
    } catch {
        print("\n❌ Decoding Error:")
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("Missing key: \(key.stringValue)")
                print("Context: \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                print("Type mismatch: expected \(type)")
                print("Context: \(context.debugDescription)")
                print("Coding path: \(context.codingPath)")
            case .valueNotFound(let type, let context):
                print("Value not found: expected \(type)")
                print("Context: \(context.debugDescription)")
            case .dataCorrupted(let context):
                print("Data corrupted: \(context.debugDescription)")
            @unknown default:
                print("Unknown decoding error")
            }
        }
        throw error
    }
}

   static func getUserPosts(username: String, page: Int = 1, pageSize: Int = 20) async throws -> [AudioConversation] {
        let (posts, _) = try await getUserPostsWithPagination(username: username, page: page, pageSize: pageSize)
        return posts
    }
    
    static func getUserPostsWithPagination(username: String, page: Int = 1, pageSize: Int = 20) async throws -> (posts: [AudioConversation], pagination: PagerResponse) {
        print("\n=== 📱 GET USER POSTS API CALL ===")
        print("👤 Username: \(username)")
        print("📄 Page: \(page)")
        print("📊 Page Size: \(pageSize)")
        
        guard let token = try KeychainManager.shared.getToken() else {
            print("❌ No token found")
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(PostConfig.baseURL)\(PostConfig.Endpoints.userPosts)?username=\(username)&page=\(page)&page_size=\(pageSize)")!
        print("🌐 Request URL: \(url)")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // Log raw response
        if let httpResponse = response as? HTTPURLResponse {
            print("\n📡 HTTP Response:")
            print("- Status Code: \(httpResponse.statusCode)")
            print("- Headers: \(httpResponse.allHeaderFields)")
        }
      
        
        do {
            // Decode the response with the correct structure
            let response = try JSONDecoder().decode(APIResponse<PaginatedListResponse<PostResponse>>.self, from: data)
        
            // Convert posts to AudioConversations - filter out incomplete posts
            let conversations = response.data.list.compactMap { $0.toAudioConversation() }
            print("📱 [API] Post order from API (page \(page)): \(conversations.map { "ID:\($0.id)" })")
            
            // Log pagination info if available
            let pager = response.data.pager
            print("📱 [API] Pagination - page: \(pager.page), totalRows: \(pager.totalRows), pageSize: \(pager.pageSize)")
            
            return (conversations, pager)
            
        } catch {
            print("\n❌ Decoding Error:")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Missing key: \(key.stringValue)")
                    print("Context: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch: expected \(type)")
                    print("Context: \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("Value not found: expected \(type)")
                    print("Context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
            throw error
        }
    }
    
    static func getFollowingPosts(page: Int = 1, pageSize: Int = 20) async throws -> [AudioConversation] {
        guard let token = try KeychainManager.shared.getToken() else {
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(PostConfig.baseURL)\(PostConfig.Endpoints.followingPosts)?style=following&page=\(page)&page_size=\(pageSize)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let response = try JSONDecoder().decode(APIResponse<[PostResponse]>.self, from: data)
        
        // ✅ FILTER: Only include posts with complete audio content for both users
        return response.data.compactMap { $0.toAudioConversation() }
    }
    
    static func deletePost(id: Int64) async throws {
        guard let token = try KeychainManager.shared.getToken() else {
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(PostConfig.baseURL)\(PostConfig.Endpoints.deletePost)?id=\(id)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.unauthorized
        }
    }
    
    
    
    // Optional: Add convenience methods to handle state changes
    func toggleSpaceSuperMinimized() {
        isSpaceSuperMinimized.toggle()
    }
    
    func toggleQueueSuperMinimized() {
        isQueueSuperMinimized.toggle()
    }
    
    // Update existing methods to handle super minimized state
    func dismissSpace() {
        showSpaceView = false
        isSpaceSuperMinimized = false  // Reset when fully dismissing
    }
    
    func dismissQueue() {
        showQueueView = false
        isQueueSuperMinimized = false  // Reset when fully dismissing
    }
    
    
    
    
    
    
    
    
    
    var pendingImageUploads: [String: URL] = [:] // spaceId: localImageURL
    // Add this property
    var recordingParticipants: Set<SpaceParticipant> = [] // Using Set to ensure uniqueness
    static var cachedManagementToken: String?
    static var managementTokenExpiry: Date?
    @Published var currentTopic: String = ""
    @MainActor
    func setTopic(_ topic: String) {
        print("🎯 [setTopic] Setting topic: '\(topic)'")
        currentTopic = topic
        print("✅ [setTopic] Current topic is now: '\(currentTopic)'")
    }
    
    // Add a method to clear the topic
    @MainActor
    func clearTopic() {
        print("🧹 Clearing topic")
        currentTopic = ""
    }

    var isRecording = false
    var recordingId: String?
    @Published var recordingTimeRemaining: TimeInterval = 420 // 7 minutes in seconds
    @Published var isRecordingActive: Bool = false
    @Published var recordingStartTime: Date?
    var recordingTimer: Timer?
    @Published var peerImages: [String: UIImage] = [:]
    @Published var isSpaceMinimized = false
    @Published var sheetDetent: PresentationDetent = .fraction(0.9)
    var isSendBirdConnected = false // Track connection status
    @Published var isAccountVerified: Bool = false
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var verificationAttempts = 0
    let maxVerificationAttempts = 3
    @Published var onboardingURL: URL? = nil
    @Published var activeSpeakerId: String?      // Tracks the currently active speaker's ID
    @Published var isQueueMinimized = false
    // Inside SpacesViewModel class
    @Published var isProcessingQueue = false
    @Published var selectedQueue: Queue?
    @Published var ownTrack: HMSAudioTrack?
    @Published var otherTracks: Set<HMSAudioTrack> = []
///@Published var ownTrack: TrackPublication?  // Instead of Track
//@Published var otherTracks: Set<TrackPublication> = []  // Instead of Set<Track>
  //  @Published var liveKitRoom: Room?  // Add LiveKit room property*/
    @Published var isAudioMuted = false
    @Published var isCurrentUserMuted = false



    var currentPage = 0
    var hasMoreData = true
    let pageSize = 20
    var initialPeerCount: Int = 0
    @Published var showSpaceView = false
    @Published var showQueueView = false
    @Published var showHostNotPresentModal = false
    @Published var showRoomFullModal = false
    var activeSpaceParticipants: [Int64: Int] = [:] // spaceId: count
    
    
    // private var queueListener: ListenerRegistration?
    //private var usersListener: ListenerRegistration?
    @Published var speakerIds: Set<Int64> = []
    @Published var  showInviteNextModal = false
    @Published var  showRemoveUserModal = false
    @Published var  selectedUserForRemoval: SpaceParticipant?
    //var hmsSDK = HMSSDK.build()
    let hmsSDK: HMSSDK = HMSSDK.build()
    // Space-related properties
    @Published var spaces: [Space] = [] {
        didSet {
            // ✅ OPTIMIZED: Update space caches when spaces array changes
            // Dispatch to main actor since updateSpaceCaches is @MainActor
            Task { @MainActor in
                updateSpaceCaches()
            }
        }
    }
    @Published var selectedSpace: Space?
    @Published var currentViewingSpace: Space? {
        didSet {
            print("\n=== 🔄 CURRENT VIEWING SPACE CHANGED ===")
            if let newSpace = currentViewingSpace {
                print("📱 New Space Details:")
                print("- ID: \(newSpace.id)")
                print("- Host: \(newSpace.host ?? "nil")")
                print("- Speakers: \(newSpace.speakers.count)")
                print("- Speaker IDs: \(newSpace.speakers.map { $0.id })")
                print("- HMS Room ID: \(newSpace.hmsRoomId ?? "nil")")
            } else {
                print("❌ Space cleared (set to nil)")
            }
            print("=== ✅ CHANGE LOGGED ===\n")
        }
    }
    @Published var lastUserWhoLeft: QueueUser?
    // ✅ SIMPLE IN-APP TOAST NOTIFICATION SYSTEM
    @Published var showToastNotification = false
    @Published var toastMessage = ""
    @Published var toastIsError = false
    var pollingTimer: Timer? // To handle polling
    //@Published var canvasItems: [CanvasItem] = []
    
    var currentLocation: LocationContext?
    var nearbyLocations: [LocationContext] = []
    struct LocationContext: Equatable {
        let latitude: Double
        let longitude: Double
        let radius: Double
        let zoomLevel: Int
        let spaceCount: Int
        
        var latBand: Int {
            Int(floor(latitude / 20.0) * 20.0)
        }
        
        static func == (lhs: LocationContext, rhs: LocationContext) -> Bool {
            lhs.latitude == rhs.latitude &&
            lhs.longitude == rhs.longitude &&
            lhs.radius == rhs.radius &&
            lhs.zoomLevel == rhs.zoomLevel
        }
    }
    func startPolling() {
        pollingTimer?.invalidate() // Stop any existing timer
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in // Changed from 30 to 300 seconds
            Task {
               // await self?.loadLiveSpaces()
            }
        }
    }
    // ✅ SIMPLE TOAST NOTIFICATION METHOD
    func showToast(_ message: String, isError: Bool = false) {
        DispatchQueue.main.async {
            self.toastMessage = message
            self.toastIsError = isError
            self.showToastNotification = true
            
            // Auto-hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.showToastNotification = false
            }
        }
    }
    func stopPolling() {
        pollingTimer?.invalidate() // Stop polling
        pollingTimer = nil
    }
    
    
    
    @Published var isInSpace = false {
        didSet {
            print("🔍 [isInSpace] Changed from \(oldValue) to \(isInSpace)")
            print("🔍 [isInSpace] Stack trace: \(Thread.callStackSymbols.prefix(5).joined(separator: "\n"))")
            
            // Audio session management
            if isInSpace && !oldValue {
                // Entering space - pause all background audio
                pauseAllBackgroundAudio()
            } else if !isInSpace && oldValue {
                // Leaving space - resume background audio
                resumeBackgroundAudio()
            }
        }
    }
    @Published var wasManuallyTapped = false
    @Published var wasEndedByHost = false
    
    // Replace the existing isInSpace with this computed property
    
    func updateQueueLocally(_ queue: Queue, for spaceId: Int64, isInvited: Bool = false) {
        DispatchQueue.main.async {
            if let spaceIndex = self.spaces.firstIndex(where: { $0.id == spaceId }) {
                // ✅ Update queue participants
                self.spaces[spaceIndex].queue.participants = queue.participants
                
                // ✅ OPTIMIZED: Update cached queue participant set for O(1) lookup
                self.queueParticipantIds[spaceId] = Set(queue.participants.map { $0.id })
                
                // ✅ Preserve or update `isBlockedFromSpace`
                if isInvited {
                    self.spaces[spaceIndex].isBlockedFromSpace = true
                } else {
                    self.spaces[spaceIndex].isBlockedFromSpace = self.spaces[spaceIndex].isBlockedFromSpace
                }
                
                // ✅ CRITICAL: Force cache update after modifying array element in place
                self.updateSpaceCaches()
                
                // ✅ Update selectedSpace if needed
                if let selectedSpace = self.selectedSpace, selectedSpace.id == spaceId {
                    self.selectedSpace?.update(with: self.spaces[spaceIndex], preservingFieldsFrom: selectedSpace)
                    // ✅ REMOVED: Unnecessary objectWillChange.send() - @Published properties auto-trigger updates
                }
            }
        }
    }
      @MainActor
    var isHost: Bool {
          guard let userId = tweetData.user?.id,
                let hostId = selectedSpace?.hostId
          else { return false }
          return userId == hostId || wasManuallyTapped
      }
    
    @MainActor var isInQueue: Bool {
        guard let userId = tweetData.user?.id,
              let selectedSpace = selectedSpace else { return false }
        return selectedSpace.queue.participants.contains { $0.id == userId }
    }
    
    
    
    @Published var  showPreview = false
    @Published var reconnecting = false
    @Published var infoMessage: InfoMessage?
    @Published var sortedParticipants: [QueueUser] = []
    func updateSortedParticipants() {
        sortedParticipants = selectedSpace?.queue.participants
            .sorted(by: { $0.position < $1.position }) ?? []
    }
    // SendBird properties
    //  private var sendbird: SendbirdChat?
    let SENDBIRD_APP_ID = "D7CF7A75-9950-4D5F-962B-DFEA28A0E327"
    
    /// Sorts the spaces by date
    var sortedSpaces: [Space] {
        Array(spaces).sorted { space1, space2 in
            space1.startDate > space2.startDate
        }
    }
    
    
    
 
    // In SpacesViewModel
    @Published var isHandlingRoomCreation = false
    @MainActor
    var isSpeaker: Bool {
        guard
            let userId = tweetData.user?.id,
            let space = selectedSpace else {
            return false
        }
        
        return space.speakers.contains { $0.id == userId }
    }
    
    @MainActor func spaceCardTapped(space: Space) {
        print("🔄 [spaceCardTapped] Function called")
        print("🔄 [spaceCardTapped] Selected Space ID: \(space.id)")
        
        print("🔄 [spaceCardTapped] Is Host: \(isHost)")
        print("🔄 [spaceCardTapped] Is Speaker: \(isSpeaker)")
        print("🔄 [spaceCardTapped] Show Space View: \(showSpaceView)")
        print("🔄 [spaceCardTapped] Show Queue View: \(showQueueView)")
        
        if selectedSpace?.id != space.id {
            selectedSpace = space
            print("🔄 [spaceCardTapped] Updated Selected Space ID: \(space.id)")
        }
        
        // Automatically leave previous space when joining new one
        if isHost || isSpeaker {
            showSpaceView = true
            showQueueView = false
            sheetDetent = .fraction(0.9)
            // ✅ FIXED: Always show space at full size initially
            isSpaceMinimized = false
            print("🔄 [spaceCardTapped] Showing Space View at full size")
        } else {
            showQueueView = true
            showSpaceView = false
            print("🔄 [spaceCardTapped] Showing Queue View")
        }
    }
    
    
    
    @MainActor
    func queueCloseTapped() async {
        
        guard let space = selectedSpace else { return }
       
        showQueueView = false
    
        
    }
    @MainActor
    func spaceCloseTapped() async {
        
        guard let space = selectedSpace else {
            print("🔍 spaceCloseTapped: No space currently selected")
            return
        }
        
        self.showSpaceView = false
        
    }
   
    enum InfoMessageType {
        case information, error
    }
    
    struct InfoMessage: Identifiable {
        var id = UUID()
        var text: String
        var type: InfoMessageType = .information
    }
    
    
   @MainActor
   func queueButtonTapped(topic: String? = nil) async {
        print("\n=== QUEUE BUTTON TAPPED ===")
        print("🔄 Topic: \(topic ?? "nil")")
        print("🔄 Current topic state: \(currentTopic)")
        
        guard !isProcessingQueue else {
            print("⚠️ Already processing queue operation")
            return
        }
        isProcessingQueue = true
        defer { isProcessingQueue = false }
        
        guard let space = selectedSpace else {
            print("❌ No space selected")
            setInfoMessage(text: "No space selected", type: .error)
            return
        }
        print("✅ Space found: \(space.id)")
        
        guard let userId = tweetData.user?.id else {
            print("❌ User not authenticated")
            setInfoMessage(text: "User not authenticated", type: .error)
            return
        }
        print("✅ User authenticated: \(userId)")
        
        // ✅ OPTIMIZED: Use cached set for O(1) lookup instead of O(n) linear search
        if queueParticipantIds[space.id]?.contains(userId) == true,
           let queueUser = space.queue.participants.first(where: { $0.id == userId }) {
            print("👤 User found in queue")
            print("📋 Queue position: \(queueUser.position)")
            print("🎯 Is invited: \(queueUser.isInvited)")
            
            if queueUser.isInvited {
                print("🎯 User is invited, joining space with topic: \(currentTopic)")
               do {
        try await joinSpace(id: space.id)
    } catch {
        print("❌ Error joining space: \(error)")
       
    }
            } else {
                do {
                    print("🚫 User leaving queue, clearing topic")
                    clearTopic()
              //      try await leaveQueue()
                    showQueueView = false
                    print("✅ Successfully left queue")
                } catch {
                    print("❌ Failed to leave queue: \(error)")
                    setInfoMessage(text: "Failed to leave queue", type: .error)
                }
            }
        } else {
            print("👤 User not in queue, attempting to join")
            do {
                print("🔍 Current topic state after setting: \(currentTopic)")
               // try await joinQueue(topic: currentTopic)
                print("✅ Successfully joined queue")
            } catch {
                print("❌ Failed to join queue: \(error)")
                setInfoMessage(text: "Failed to join queue", type: .error)
                clearTopic()
            }
        }
    }

    

    @MainActor
    func spaceButtonTapped() async {
      
          guard let space = selectedSpace else {
              setInfoMessage(text: "Couldn't find space currently. Please try again later.", type: .error)
              print("❌ spaceButtonTapped: No space currently selected")
              return
          }

          if isInSpace {
              if isHost {

                  await endSpace(with: space.id)
                  

              } else {
                 
                  
                  await leaveSpace(id: space.id)
                 
        }
          } else {
             
              if isHost {
                 
                  //await startSpace(id: space.id)
              } else {
                
                  do {
            try await joinSpace(id: space.id)
        } catch {
            print("❌ Error joining space: \(error)")
        }
              }
        }
    }
    
    // ✅ REMOVED: toggleAudioMute function - use toggleMuteParticipant instead
    // This function has been replaced by toggleMuteParticipant which handles both local and remote muting



    // Helper function to get active spaces only
   
    // Helper function to get planned spaces
  
    
    // Helper function to format Date to ISO8601 string
     func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    
    

    
    @Published var loadError: String? = nil

    
    struct RoomData: Codable {
        let id: String?
        let name: String?
        let enabled: Bool?
        let description: String?
        let customer_id: String?
        let app_id: String?
        let recording_info: RecordingInfo?
        let template_id: String?
        let template: String?
        let region: String?
        let created_at: String?
        let updated_at: String?
        let large_room: Bool?
    }
    
    
    struct PeersResponse: Codable {
        let peers: [String: PeerData]
    }
    
    struct PeerData: Codable {
        let id: String
        let name: String
        let user_id: String
        let metadata: Metadata
        let role: String
    }
    
    struct Metadata: Codable {
        let profilePicture: String?
        // Add other fields as needed
        
        enum CodingKeys: String, CodingKey {
            case profilePicture = "profilePicture"
            // Add other keys as needed
        }
    }

    @Published var activeSpeakerLevels: [String: Float] = [:]   // peerID -> audio level
    @Published var activeSpeakerIdsSet: Set<String> = []       // convenience set of active peerIDs
    
    // MARK: - Notification State
    @Published var notificationState = NotificationState()
    
    // MARK: - App Lifecycle Handling for Conversations
    
    // Add app lifecycle handling
    private var appLifecycleObservers: [NSObjectProtocol] = []
    
    private func setupAppLifecycleHandling() {
        // Save position when app goes to background
        let willResignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveConversationPositionOnBackground()
            self?.handleAppBackground()
        }
        
        // Restore position when app comes to foreground
        let didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restoreConversationPositionOnForeground()
            self?.handleAppForeground()
        }
        
        appLifecycleObservers = [willResignObserver, didBecomeActiveObserver]
    }
    
    private func cleanupAppLifecycleHandling() {
        appLifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        appLifecycleObservers.removeAll()
    }
    
    // MARK: - Periodic Cache Validation
    
    /// Starts periodic cache validation timer
    @MainActor
    private func startPeriodicCacheValidation() {
        print("🔄 [CACHE VALIDATION] Starting periodic cache validation (every \(cacheValidationInterval) seconds)")
        
        // Stop any existing timer
        stopPeriodicCacheValidation()
        
        // Start new timer
        cacheValidationTimer = Timer.scheduledTimer(withTimeInterval: cacheValidationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performPeriodicCacheValidation()
            }
        }
        
        // Perform initial validation
        performPeriodicCacheValidation()
    }
    
    /// Stops periodic cache validation timer
    @MainActor
    private func stopPeriodicCacheValidation() {
        cacheValidationTimer?.invalidate()
        cacheValidationTimer = nil
        print("🔄 [CACHE VALIDATION] Stopped periodic cache validation")
    }
    
    /// Performs periodic cache validation
    @MainActor
    private func performPeriodicCacheValidation() {
      
        // Only validate if we have data to validate
        let hasSpaces = !spaces.isEmpty
        let hasPosts = !authenticatedUserPosts.posts.isEmpty || !otherUserPosts.isEmpty
        
        if hasSpaces || hasPosts {
            validateAllCaches()
        }
    }
    
    @MainActor
    private func saveConversationPositionOnBackground() {
        print("📱 App going to background - saving conversation position")
        // ✅ REMOVED: Unnecessary objectWillChange.send() - @Published properties auto-trigger updates
    }
    
    @MainActor
    private func restoreConversationPositionOnForeground() {
        print("📱 App coming to foreground - restoring conversation position")
        // ✅ REMOVED: Unnecessary objectWillChange.send() - @Published properties auto-trigger updates
    }
    
    // Add app lifecycle handling for user posts state
    @MainActor
    private func handleAppBackground() {
        print("📱 App going to background - handling cleanup")
        
        // Stop periodic cache validation to save resources
        stopPeriodicCacheValidation()
        
        // Clear all user posts state to prevent memory issues and stale data
        clearAllUserPosts()
        
        // Clear image cache to free memory
        clearImageCache()
        
        print("📱 App background cleanup completed")
    }
    
 
    
    @MainActor
    private func handleAppForeground() {
        print("📱 App coming to foreground - handling user posts state")
        
        // Restart periodic cache validation
        startPeriodicCacheValidation()
        
        // State will be reloaded when user navigates back to profiles
        // This ensures fresh data after app backgrounding
    }
    
    // State synchronization for conversations feed
    @MainActor
    func syncConversationFeedState() {
        print("🔄 Syncing conversation feed state")
        // ✅ REMOVED: Unnecessary objectWillChange.send() - @Published properties auto-trigger updates
    }
    
    // MARK: - Manual Cache Validation (for debugging)
    
    /// Manually triggers cache validation (useful for debugging)
    @MainActor
    func validateCachesNow() {
        print("🔍 [MANUAL CACHE VALIDATION] Triggered manually")
        validateAllCaches()
    }
    
    /// Gets cache statistics for debugging
    @MainActor
    func getCacheStatistics() -> [String: Any] {
        let stats: [String: Any] = [
            "spaces_count": spaces.count,
            "space_cache_size": spaceIdsToIndex.count,
            "host_cache_size": hostIdToSpaceId.count,
            "auth_posts_count": authenticatedUserPosts.posts.count,
            "auth_posts_cache_size": authenticatedUserPostIds.count,
            "other_users_count": otherUserPosts.count,
            "other_posts_cache_size": otherUserPostIds.count,
            "queue_cache_size": queueParticipantIds.count,
            "validation_timer_active": cacheValidationTimer != nil,
            "validation_interval_seconds": cacheValidationInterval
        ]
        
        print("📊 [CACHE STATISTICS] \(stats)")
        return stats
    }
    
    /// Updates the cache validation interval and restarts the timer
    @MainActor
    func updateCacheValidationInterval(_ interval: TimeInterval) {
        print("🔄 [CACHE VALIDATION] Updating validation interval to \(interval) seconds")
        cacheValidationInterval = interval
        startPeriodicCacheValidation()
    }
    
    /// Enables or disables periodic cache validation
    @MainActor
    func setPeriodicCacheValidationEnabled(_ enabled: Bool) {
        if enabled {
            print("🔄 [CACHE VALIDATION] Enabling periodic cache validation")
            startPeriodicCacheValidation()
        } else {
            print("🔄 [CACHE VALIDATION] Disabling periodic cache validation")
            stopPeriodicCacheValidation()
        }
    }
    
    // MARK: - User's Own Space Persistence Methods
    
    /// Saves the user's own space to UserDefaults
    @MainActor
    private func saveUserOwnSpace(_ space: Space) {
        do {
            let encoder = JSONEncoder()
            let spaceData = try encoder.encode(space)
            userDefaults.set(spaceData, forKey: userOwnSpaceKey)
            print("✅ [PERSISTENCE] User's own space saved successfully")
        } catch {
            print("❌ [PERSISTENCE] Failed to save user's own space: \(error)")
        }
    }
    
    /// Loads the user's own space from UserDefaults and adds it to spaces array
    /// If not found in UserDefaults, tries to fetch from API and save it
    @MainActor
    private func loadUserOwnSpace() {
        guard let spaceData = userDefaults.data(forKey: userOwnSpaceKey) else {
            print("ℹ️ [PERSISTENCE] No saved user space found in UserDefaults")
            
            // ✅ FALLBACK: Try to fetch user's own space from API and save it
            Task {
                await fetchAndSaveUserOwnSpace()
            }
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let savedSpace = try decoder.decode(Space.self, from: spaceData)
            
            // Check if this space is already in the spaces array
            if !spaces.contains(where: { $0.id == savedSpace.id }) {
                spaces.append(savedSpace)
                print("✅ [PERSISTENCE] User's own space loaded and added to spaces array")
                print("📋 Space ID: \(savedSpace.id)")
                print("📋 HMS Room ID: \(savedSpace.hmsRoomId ?? "nil")")
                print("📋 Host ID: \(savedSpace.hostId)")
            } else {
                print("ℹ️ [PERSISTENCE] User's own space already exists in spaces array")
            }
        } catch {
            print("❌ [PERSISTENCE] Failed to load user's own space: \(error)")
            // Clear corrupted data
            userDefaults.removeObject(forKey: userOwnSpaceKey)
            
            // ✅ FALLBACK: Try to fetch user's own space from API and save it
            Task {
                await fetchAndSaveUserOwnSpace()
            }
        }
    }
    
    /// Fetches user's own space from API and saves it to UserDefaults
    @MainActor
    private func fetchAndSaveUserOwnSpace() async {
        // Check if user is authenticated before making API call
        guard let token = try? KeychainManager.shared.getToken(),
              let userId = tweetData.user?.id else {
            print("ℹ️ [PERSISTENCE] User not authenticated, skipping API fetch")
            return
        }
        
        print("🔄 [PERSISTENCE] Fetching user's own space from API...")
        
        do {
            let fetchedSpace = try await getMyRoom()
            print("✅ [PERSISTENCE] Successfully fetched user's own space from API")
            print("📋 Space ID: \(fetchedSpace.id)")
            print("📋 HMS Room ID: \(fetchedSpace.hmsRoomId ?? "nil")")
            print("📋 Host ID: \(fetchedSpace.hostId)")
            
            // Space is automatically saved to UserDefaults in getMyRoom() method
            // and added to spaces array via updateSpacesWithNewData()
            
        } catch {
            print("❌ [PERSISTENCE] Failed to fetch user's own space from API: \(error)")
            print("ℹ️ [PERSISTENCE] User may not have a space yet or API is unavailable")
        }
    }
    
    /// Clears the user's own space from UserDefaults (useful for logout)
    @MainActor
    func clearUserOwnSpace() {
        userDefaults.removeObject(forKey: userOwnSpaceKey)
        print("🧹 [PERSISTENCE] User's own space cleared from UserDefaults")
    }
    
    /// Gets the user's own space from the spaces array
    @MainActor
    func getUserOwnSpace() -> Space? {
        guard let userId = tweetData.user?.id else {
            print("❌ [PERSISTENCE] No current user ID available")
            return nil
        }
        
        return spaces.first { $0.hostId == userId }
    }
    
    /// Updates the user's own space in both memory and persistent storage
    @MainActor
    func updateUserOwnSpace(_ updatedSpace: Space) {
        // Update in memory
        if let index = spaces.firstIndex(where: { $0.hostId == updatedSpace.hostId }) {
            spaces[index] = updatedSpace
            print("✅ [PERSISTENCE] User's own space updated in memory")
        }
        
        // Update in persistent storage
        saveUserOwnSpace(updatedSpace)
        print("✅ [PERSISTENCE] User's own space updated in persistent storage")
    }
    
    /// Refreshes the user's own space from the API and updates persistent storage
    @MainActor
    func refreshUserOwnSpace() async {
        do {
            print("🔄 [PERSISTENCE] Refreshing user's own space from API...")
            let updatedSpace = try await getMyRoom()
            print("✅ [PERSISTENCE] User's own space refreshed successfully")
        } catch {
            print("❌ [PERSISTENCE] Failed to refresh user's own space: \(error)")
        }
    }
    
    /// Ensures user's own space is available (loads from UserDefaults or fetches from API)
    @MainActor
    func ensureUserOwnSpaceAvailable() async {
        print("🔍 [PERSISTENCE] Starting ensureUserOwnSpaceAvailable - Current spaces count: \(spaces.count)")
        
        // First check if we already have the user's space in memory
        if let existingSpace = getUserOwnSpace() {
            print("✅ [PERSISTENCE] User's own space already available in memory")
            print("📋 Space ID: \(existingSpace.id)")
            return
        }
        
        // If not in memory, try to load from UserDefaults
        if let spaceData = userDefaults.data(forKey: userOwnSpaceKey) {
            do {
                let decoder = JSONDecoder()
                let savedSpace = try decoder.decode(Space.self, from: spaceData)
                
                if !spaces.contains(where: { $0.id == savedSpace.id }) {
                    spaces.append(savedSpace)
                    print("✅ [PERSISTENCE] User's own space loaded from UserDefaults")
                }
                return
            } catch {
                print("❌ [PERSISTENCE] Corrupted data in UserDefaults, clearing...")
                userDefaults.removeObject(forKey: userOwnSpaceKey)
            }
        }
        
        // If not in UserDefaults, fetch from API
        print("🔄 [PERSISTENCE] User's own space not found, fetching from API...")
        await fetchAndSaveUserOwnSpace()
    }

    // Add method to handle user profile navigation state
    @MainActor
    func handleUserProfileNavigation(fromUsername: String?, toUsername: String?) {
        print("🔄 [NAVIGATION] User profile navigation")
        print("🔄 [NAVIGATION] From: \(fromUsername ?? "nil")")
        print("🔄 [NAVIGATION] To: \(toUsername ?? "nil")")
        
        // Clear previous user's state if different from new user
        if let fromUsername = fromUsername,
           let toUsername = toUsername,
           fromUsername != toUsername {
            print("🔄 [NAVIGATION] Different users - clearing previous state")
            clearUserPosts(username: fromUsername)
        }
        
        // Ensure new user starts with clean state
        if let toUsername = toUsername {
            print("🔄 [NAVIGATION] Preparing clean state for: \(toUsername)")
            // The actual loading will happen in the view's onAppear
        }
    }
    
    // ✅ OPTIMIZED: Cache maintenance methods for space lookups
    
    /// Updates space caches when spaces array changes
    @MainActor
    private func updateSpaceCaches() {
        spaceIdsToIndex.removeAll()
        hostIdToSpaceId.removeAll()
        
        for (index, space) in spaces.enumerated() {
            spaceIdsToIndex[space.id] = index
           
                hostIdToSpaceId[space.hostId ] = space.id
    
        }
        
        print("✅ Updated space caches for O(1) lookups")
    }
    
    /// Gets space index using cached lookup
    @MainActor
    func getSpaceIndex(for spaceId: Int64) -> Int? {
        return spaceIdsToIndex[spaceId]
    }
    
    /// Gets host space using cached lookup
    @MainActor
    func getHostSpace(for hostId: Int64) -> Space? {
        guard let spaceId = hostIdToSpaceId[hostId],
              let index = spaceIdsToIndex[spaceId] else {
            return nil
        }
        return spaces[index]
    }
    
    /// Safely updates a space and ensures cache consistency
    @MainActor
    private func updateSpace(_ space: Space, at index: Int) {
        spaces[index] = space
        // ✅ Cache is automatically updated via didSet
    }
    
    /// Safely updates a space by ID and ensures cache consistency
    @MainActor
    private func updateSpace(_ space: Space) {
        if let index = getSpaceIndex(for: space.id) {
            updateSpace(space, at: index)
        }
    }
    
    /// Validates cache consistency and logs any issues
    @MainActor
    private func validateSpaceCaches() {
        var inconsistencies: [String] = []
        
        // Check spaceIdsToIndex consistency
        for (spaceId, cachedIndex) in spaceIdsToIndex {
            if cachedIndex >= spaces.count || spaces[cachedIndex].id != spaceId {
                inconsistencies.append("spaceIdsToIndex: spaceId \(spaceId) points to wrong index \(cachedIndex)")
            }
        }
        
        // Check hostIdToSpaceId consistency
        for (hostId, cachedSpaceId) in hostIdToSpaceId {
            if !spaces.contains(where: { $0.id == cachedSpaceId && $0.hostId == hostId }) {
                inconsistencies.append("hostIdToSpaceId: hostId \(hostId) points to wrong spaceId \(cachedSpaceId)")
            }
        }
        
        if !inconsistencies.isEmpty {
            print("⚠️ [CACHE VALIDATION] Found \(inconsistencies.count) inconsistencies:")
            for inconsistency in inconsistencies {
                print("  - \(inconsistency)")
            }
            print("🔄 [CACHE VALIDATION] Rebuilding caches...")
            updateSpaceCaches()
        } else {
            print("✅ [CACHE VALIDATION] All caches are consistent")
        }
    }
    
    /// Validates all caches and logs any issues
    @MainActor
    private func validateAllCaches() {
        print("🔍 [CACHE VALIDATION] Validating all caches...")
        
        // Validate space caches
        validateSpaceCaches()
        
        // Validate post caches
        var postCacheInconsistencies: [String] = []
        
        // Check authenticated user post cache
        let expectedAuthPostIds = Set(authenticatedUserPosts.posts.map { $0.id })
        if authenticatedUserPostIds != expectedAuthPostIds {
            postCacheInconsistencies.append("authenticatedUserPostIds mismatch")
        }
        
        // Check other user post caches
        for (username, state) in otherUserPosts {
            let expectedPostIds = Set(state.posts.map { $0.id })
            let cachedPostIds = otherUserPostIds[username] ?? Set()
            if expectedPostIds != cachedPostIds {
                postCacheInconsistencies.append("otherUserPostIds mismatch for \(username)")
            }
        }
        
        // Check queue participant caches
        var queueCacheInconsistencies: [String] = []
        for space in spaces {
            let expectedQueueIds = Set(space.queue.participants.map { $0.id })
            let cachedQueueIds = queueParticipantIds[space.id] ?? Set()
            if expectedQueueIds != cachedQueueIds {
                queueCacheInconsistencies.append("queueParticipantIds mismatch for space \(space.id)")
            }
        }
        
        if !postCacheInconsistencies.isEmpty {
            print("⚠️ [CACHE VALIDATION] Found \(postCacheInconsistencies.count) post cache inconsistencies:")
            for inconsistency in postCacheInconsistencies {
                print("  - \(inconsistency)")
            }
            print("🔄 [CACHE VALIDATION] Rebuilding post caches...")
            rebuildPostCaches()
        }
        
        if !queueCacheInconsistencies.isEmpty {
            print("⚠️ [CACHE VALIDATION] Found \(queueCacheInconsistencies.count) queue cache inconsistencies:")
            for inconsistency in queueCacheInconsistencies {
                print("  - \(inconsistency)")
            }
            print("🔄 [CACHE VALIDATION] Rebuilding queue caches...")
            rebuildQueueCaches()
        }
        
        if postCacheInconsistencies.isEmpty && queueCacheInconsistencies.isEmpty {
            print("✅ [CACHE VALIDATION] All caches are consistent")
        }
    }
    
    /// Rebuilds all post caches from current state
    @MainActor
    private func rebuildPostCaches() {
        // Rebuild authenticated user post cache
        authenticatedUserPostIds = Set(authenticatedUserPosts.posts.map { $0.id })
        
        // Rebuild other user post caches
        otherUserPostIds.removeAll()
        for (username, state) in otherUserPosts {
            otherUserPostIds[username] = Set(state.posts.map { $0.id })
        }
        
        print("✅ [CACHE VALIDATION] Rebuilt post caches")
    }
    
    /// Rebuilds all queue caches from current state
    @MainActor
    private func rebuildQueueCaches() {
        queueParticipantIds.removeAll()
        for space in spaces {
            queueParticipantIds[space.id] = Set(space.queue.participants.map { $0.id })
        }
        
        print("✅ [CACHE VALIDATION] Rebuilt queue caches")
    }
    
    // Add method to validate pagination state consistency
    @MainActor
    func validatePaginationState(username: String) -> Bool {
        let isAuthenticatedUser = username == tweetData.user?.username
        let state = isAuthenticatedUser ? authenticatedUserPosts : (otherUserPosts[username] ?? UserPostsState())
        
        // Check for basic consistency
        let isValid = state.pagination.currentPage >= 1 &&
                     state.pagination.pageSize > 0 &&
                     state.pagination.totalItems >= 0 &&
                     state.posts.count <= state.pagination.totalItems
        
        if !isValid {
            print("⚠️ [VALIDATION] Invalid pagination state for user: \(username)")
            print("⚠️ [VALIDATION] Current page: \(state.pagination.currentPage)")
            print("⚠️ [VALIDATION] Page size: \(state.pagination.pageSize)")
            print("⚠️ [VALIDATION] Total items: \(state.pagination.totalItems)")
            print("⚠️ [VALIDATION] Posts count: \(state.posts.count)")
        }
        
        return isValid
    }




}



// Add these logging methods to SpacesViewModel
extension SpacesViewModel {
    func logStoryData(_ space: Space) {
        NSLog("🎴 Space Story Data:")
        NSLog("🆔 Space ID: \(space.id)")
        NSLog("👤 Host Image: \(space.hostImageUrl ?? "nil")")
    }
    
    func logStorySelection(_ space: Space) {
        NSLog("🎯 Story Selected:")
        NSLog("🆔 Space ID: \(space.id)")
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let userOnlineStatusChanged = Notification.Name("UserOnlineStatusChanged")
    static let spaceHostStatusChanged = Notification.Name("SpaceHostStatusChanged")
}

// MARK: - Notification Observers
extension SpacesViewModel {
    
    // ✅ ADDED: Complete notification observer setup
    func setupNotificationObservers() {
        // Listen for user profile updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserProfileUpdate),
            name: .userProfileDidUpdate,
            object: nil
        )
        
        // Listen for user online status changes from TweetData
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserOnlineStatusChange),
            name: .userOnlineStatusChanged,
            object: nil
        )
        
        // Listen for user follow status changes from TweetData
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserFollowStatusChange),
            name: .userFollowStatusChanged,
            object: nil
        )
    }
    
    @objc private func handleUserProfileUpdate(_ notification: Foundation.Notification) {
        guard let user = notification.userInfo?["user"] as? UserProfile else { return }
        
        Task { @MainActor in
            await updateHostSpaceWithUserData(user: user)
        }
    }
    
    // ✅ ADDED: Handle user online status changes from TweetData
    @objc private func handleUserOnlineStatusChange(_ notification: Foundation.Notification) {
        guard let userId = notification.userInfo?["userId"] as? Int64,
              let isOnline = notification.userInfo?["isOnline"] as? Bool else { return }
        
        Task { @MainActor in
            await updateSpacesWithUserOnlineStatus(userId: userId, isOnline: isOnline)
        }
    }
    
    // ✅ ADDED: Handle user follow status changes from TweetData
    @objc private func handleUserFollowStatusChange(_ notification: Foundation.Notification) {
        guard let userId = notification.userInfo?["userId"] as? Int64,
              let isFollowing = notification.userInfo?["isFollowing"] as? Bool else { return }
        
        Task { @MainActor in
            await updateSpacesWithUserFollowStatus(userId: userId, isFollowing: isFollowing)
        }
    }
    
    // ✅ ADDED: Update spaces when user online status changes
    @MainActor
 func updateSpacesWithUserOnlineStatus(userId: Int64, isOnline: Bool) async {
        print("\n🔄 [SpacesViewModel] Updating spaces for user \(userId) online status: \(isOnline)")
        
        var updatedCount = 0
        
        // Find all spaces where this user is the host
        for (index, space) in spaces.enumerated() {
            if space.hostId == userId {
                print("🔄 Updating space \(space.id) host status - Host \(userId) is \(isOnline ? "online" : "offline")")
                
                // Update the space's host online status using the update method
                var updatedSpace = space
                updatedSpace.updateHostOnlineStatus(isOnline)
                spaces[index] = updatedSpace
                
                // Update selectedSpace if this is the selected space
                if selectedSpace?.id == space.id {
                    var updatedSelectedSpace = selectedSpace!
                    updatedSelectedSpace.updateHostOnlineStatus(isOnline)
                    selectedSpace = updatedSelectedSpace
                    print("✅ Updated selected space host status")
                }
                
                // Update currentViewingSpace if this is the current viewing space
                if currentViewingSpace?.id == space.id {
                    var updatedCurrentViewingSpace = currentViewingSpace!
                    updatedCurrentViewingSpace.updateHostOnlineStatus(isOnline)
                    currentViewingSpace = updatedCurrentViewingSpace
                    print("✅ Updated current viewing space host status")
                }
                
                updatedCount += 1
            }
        }
        
        print("✅ [SpacesViewModel] Updated \(updatedCount) spaces for user \(userId)")
    }
    
    // ✅ ADDED: Update spaces when user follow status changes
    @MainActor
    private func updateSpacesWithUserFollowStatus(userId: Int64, isFollowing: Bool) async {
        print("\n🔄 [SpacesViewModel] Updating spaces for user \(userId) follow status: \(isFollowing)")
        
        var updatedCount = 0
        
        // Find all spaces where this user is the host
        for (index, space) in spaces.enumerated() {
            if space.hostId == userId {
                print("🔄 Updating space \(space.id) follow status - Host \(userId) is \(isFollowing ? "followed" : "unfollowed")")
                
                // Update the space's isFollowing status using the update method
                var updatedSpace = space
                updatedSpace.updateFollowStatus(isFollowing)
                spaces[index] = updatedSpace
                
                // Update selectedSpace if this is the selected space
                if selectedSpace?.id == space.id {
                    var updatedSelectedSpace = selectedSpace!
                    updatedSelectedSpace.updateFollowStatus(isFollowing)
                    selectedSpace = updatedSelectedSpace
                    print("✅ Updated selected space follow status")
                }
                
                // Update currentViewingSpace if this is the current viewing space
                if currentViewingSpace?.id == space.id {
                    var updatedCurrentViewingSpace = currentViewingSpace!
                    updatedCurrentViewingSpace.updateFollowStatus(isFollowing)
                    currentViewingSpace = updatedCurrentViewingSpace
                    print("✅ Updated current viewing space follow status")
                }
                
                updatedCount += 1
            }
        }
        
        print("✅ [SpacesViewModel] Updated \(updatedCount) spaces for user \(userId)")
    }
    
    // ✅ ADDED: Handle speaker list changes with smooth animations
    func handleSpeakersListChange(oldSpeakers: [SpaceParticipant], newSpeakers: [SpaceParticipant], geometry: GeometryProxy) {
        // ✅ SIMPLIFIED: Use the coordinated animation approach from extension
        // Calculate everything first
        let newPositions = calculatePositions(newSpeakers, geometry)
        let newEnteringIds = findNewSpeakers(newSpeakers)
        let newLeavingIds = findLeavingSpeakers(newSpeakers)
        
        // Then animate everything together
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            speakerPositions = newPositions
            enteringSpeakerIds = newEnteringIds
            leavingSpeakerIds = newLeavingIds
        }
        
        // Cleanup after animation
        cleanupLeavingSpeakers()
    }
    
}
