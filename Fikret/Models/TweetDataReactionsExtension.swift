import SwiftUI
//import Supabase


import Security
import Foundation


// MARK: - Reaction Models
struct UserReaction: Identifiable, Codable {
    let id: Int64
    let reactorUser: ReactionUserProfile
    let targetUserId: Int64?  // Keep for backward compatibility
    let targetUser: ReactionUserProfile?  // New field with full target user profile
    let reactionTypeId: Int64
    let reactionName: String
    let reactionIcon: String
    let createdOn: Int64
    
    enum CodingKeys: String, CodingKey {
        case id = "reaction_id"
        case reactorUser = "reactor_user"
        case targetUserId = "target_user_id"
        case targetUser = "target_user"
        case reactionTypeId = "reaction_type_id"
        case reactionName = "reaction_name"
        case reactionIcon = "reaction_icon"
        case createdOn = "created_on"
    }
    
    // Computed property to get target user ID from either field
    var targetUserID: Int64 {
        return targetUserId ?? targetUser?.id ?? 0
    }
    
    // Computed property to get target user profile
    var targetUserProfile: ReactionUserProfile? {
        return targetUser
    }
}

// MARK: - Reaction Response Models
struct ReactionCountsResponse: Codable {
    let code: Int
    let msg: String
    let data: ReactionCountsData
    
    struct ReactionCountsData: Codable {
        let reactionCounts: [String: Int]
        
        enum CodingKeys: String, CodingKey {
            case reactionCounts = "reaction_counts"
        }
    }
}

// Separate struct for reaction API response (with optional follows/followings)
struct ReactionUserProfile: Identifiable, Codable {
    let id: Int64
    let username: String
    var nickname: String
    var avatar: String
    let status: Int
    let isAdmin: Bool
    var isFriend: Bool?
    var isFollowing: Bool?
    let createdOn: Int64?
    var follows: Int?      // ✅ FIXED: Made optional for reaction API
    var followings: Int?   // ✅ FIXED: Made optional for reaction API
    let tweetsCount: Int?
    var categories: [Int64]?
    var reactionCounts: [Int64: Int]?
    var isOnline: Bool?
    let phone: String?
    let activation: String?
    let balance: Int64?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case nickname
        case avatar
        case status
        case isAdmin = "is_admin"
        case isFriend = "is_friend"
        case isFollowing = "is_following"
        case createdOn = "created_on"
        case follows
        case followings
        case tweetsCount = "tweets_count"
        case categories
        case reactionCounts = "reaction_counts"
        case isOnline = "is_online"
        case phone
        case activation
        case balance
    }
    
    // Convert to UserProfile for consistency
    func toUserProfile() -> UserProfile {
        return UserProfile(
            id: id,
            nickname: nickname,
            username: username,
            avatar: avatar,
            isFollowing: isFollowing ?? false,
            status: status,
            isAdmin: isAdmin,
            isFriend: isFriend ?? false,
            follows: follows ?? 0,
            followings: followings ?? 0,
            tweetsCount: tweetsCount,
            createdOn: createdOn,
            categories: categories,
            reactionCounts: reactionCounts,
            isOnline: isOnline,
            phone: phone,
            activation: activation,
            balance: balance
        )
    }
}

struct ReactionUsersResponse: Codable {
    let code: Int
    let msg: String
    let data: ReactionUsersData
    
    struct ReactionUsersData: Codable {
        let users: [ReactionUserProfile]
        let total: Int
    }
}

struct ReactionTimelineResponse: Codable {
    let code: Int
    let msg: String
    let data: ReactionTimelineData
    
    struct ReactionTimelineData: Codable {
        let list: [UserReaction]
        let pager: PagerInfo
    }
}

struct PagerInfo: Codable {
    let page: Int
    let pageSize: Int
    let totalRows: Int
    
    enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case totalRows = "total_rows"
    }
}

struct CreateReactionResponse: Codable {
    let code: Int
    let msg: String
    let data: CreateReactionData?
    
    struct CreateReactionData: Codable {
        let status: Bool
        let reactionTypeId: Int64
        let reactionName: String
        let reactionIcon: String
        
        enum CodingKeys: String, CodingKey {
            case status
            case reactionTypeId = "reaction_type_id"
            case reactionName = "reaction_name"
            case reactionIcon = "reaction_icon"
        }
    }
}

// Alternative response structure for different backend formats
struct SimpleCreateReactionResponse: Codable {
    let success: Bool
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
    }
}

// MARK: - Reaction Models and Service

// MARK: - Reaction Types
struct ReactionType: Identifiable, Codable, Hashable {
    let id: Int64
    let name: String
    let description: String
    let icon: String
    let color: String
    let isPositive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "reaction_type_id"
        case name = "reaction_name"
        case description
        case icon = "reaction_icon"
        case color
        case isPositive = "is_positive"
    }
    
    // Static reactions for fallback and immediate UI rendering
    static let staticReactions: [ReactionType] = [
        // Positive reactions (isPositive = true)
        ReactionType(id: 1, name: "like", description: "Basic approval, neutral positive", icon: "👍", color: "#4ECDC4", isPositive: true),
        ReactionType(id: 2, name: "love", description: "Strong emotional connection, affection", icon: "❤️", color: "#FF6B6B", isPositive: true),
        ReactionType(id: 3, name: "hot", description: "Attractive, good-looking", icon: "🔥", color: "#FF8C42", isPositive: true),
        ReactionType(id: 4, name: "smart", description: "Intelligent, clever", icon: "🧠", color: "#6C5CE7", isPositive: true),
        ReactionType(id: 5, name: "funny", description: "Humorous, entertaining", icon: "😂", color: "#FFEAA7", isPositive: true),
        ReactionType(id: 6, name: "kind", description: "Compassionate, helpful", icon: "🤗", color: "#00B894", isPositive: true),
        ReactionType(id: 7, name: "brave", description: "Courageous, bold", icon: "💪", color: "#F39C12", isPositive: true),
        ReactionType(id: 8, name: "cool", description: "Awesome, impressive", icon: "😎", color: "#74B9FF", isPositive: true),
        ReactionType(id: 9, name: "sweet", description: "Nice, pleasant", icon: "🍯", color: "#FFD93D", isPositive: true),
        ReactionType(id: 10, name: "strong", description: "Resilient, powerful", icon: "💪", color: "#2D3436", isPositive: true),
        ReactionType(id: 11, name: "friendly", description: "Approachable, sociable", icon: "😊", color: "#A29BFE", isPositive: true),
        ReactionType(id: 12, name: "honest", description: "Truthful, trustworthy", icon: "🤝", color: "#00CEC9", isPositive: true),
        ReactionType(id: 13, name: "generous", description: "Giving, selfless", icon: "🎁", color: "#FD79A8", isPositive: true),
        ReactionType(id: 14, name: "fit", description: "Athletic, in good shape", icon: "🏃", color: "#00B894", isPositive: true),
        ReactionType(id: 15, name: "creative", description: "Artistic, innovative", icon: "🎨", color: "#E84393", isPositive: true),
        
        // Negative reactions (isPositive = false)
        ReactionType(id: 16, name: "stupid", description: "Not smart, poor thinking", icon: "🤦", color: "#E17055", isPositive: false),
        ReactionType(id: 17, name: "mean", description: "Unkind, cruel", icon: "😠", color: "#FF7675", isPositive: false),
        ReactionType(id: 18, name: "fake", description: "Dishonest, inauthentic", icon: "🎭", color: "#636E72", isPositive: false),
        ReactionType(id: 19, name: "lazy", description: "Not hardworking", icon: "😴", color: "#B2BEC3", isPositive: false)
    ]
}

// MARK: - Reaction Service
extension TweetData {
    
    // MARK: - Reaction Endpoints Configuration
    struct ReactionEndpoints {
        static let createReaction = "/v1/user/reaction"
        static let getUserReactionCounts = "/v1/user/reactions"           // ✅ Returns counts
        static let getReactionUsersList = "/v1/user/reaction/users"       // ✅ Returns list
        static let getGivenReactionCounts = "/v1/user/given-reactions"    // ✅ Returns counts
        static let getGivenReactionUsersList = "/v1/user/given-reaction/users" // ✅ Returns list
        static let getReactionsToTwoUsersList = "/v1/user/reactions/to-two-users" // ✅ Returns list
        static let getGlobalTimelineList = "/v1/user/reactions/timeline/global" // ✅ Returns list
        static let getUserTimelineList = "/v1/user/reactions/timeline/user" // ✅ Returns list
    }
    
    // MARK: - Create User Reaction (with Optimistic Updates)
    func createUserReaction(targetUserId: Int64, reactionTypeId: Int64) async throws {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        guard let currentUser = self.user else {
            throw AuthError.notAuthenticated
        }
        
        // ✅ ENHANCED VALIDATION: Check parameters before making API call
        print("\n=== 🔍 PARAMETER VALIDATION ===")
        print("🔍 Validating reaction parameters:")
        print("  - targetUserId: \(targetUserId)")
        print("  - reactionTypeId: \(reactionTypeId)")
        print("  - currentUser.id: \(currentUser.id)")
        print("  - currentUser.username: \(currentUser.username ?? "Unknown")")
        
        // Validate target user ID
        guard targetUserId > 0 else {
            print("❌ VALIDATION ERROR: targetUserId must be greater than 0")
            throw AuthError.networkError("Invalid target user ID: \(targetUserId)")
        }
        
        // Validate reaction type ID
        guard reactionTypeId > 0 else {
            print("❌ VALIDATION ERROR: reactionTypeId must be greater than 0")
            throw AuthError.networkError("Invalid reaction type ID: \(reactionTypeId)")
        }
        
        // Check if reaction type exists in static reactions
        let validReactionTypes = ReactionType.staticReactions.map { $0.id }
        guard validReactionTypes.contains(reactionTypeId) else {
            print("❌ VALIDATION ERROR: reactionTypeId \(reactionTypeId) not found in valid reaction types: \(validReactionTypes)")
            throw AuthError.networkError("Invalid reaction type ID: \(reactionTypeId). Valid types: \(validReactionTypes)")
        }
        
        // Prevent self-reaction
        guard targetUserId != currentUser.id else {
            print("❌ VALIDATION ERROR: Cannot react to yourself")
            throw AuthError.networkError("Cannot react to yourself")
        }
        
        print("✅ All parameters validated successfully")
        print("=== END VALIDATION ===\n")
        
        // Store original state for potential rollback
        let originalOtherUser = otherUsers[targetUserId]
        let originalOtherUserReactionState = otherUsersReactionState[targetUserId]
        
        // OPTIMISTIC UPDATE: Update UI immediately
        await MainActor.run {
            // 1. Update target user's reaction counts in otherUsers (reactions received)
            if var targetUser = otherUsers[targetUserId] {
                var updatedReactionCounts = targetUser.reactionCounts ?? [:]
                
                // ✅ OPTIMIZED: Fast O(1) lookup to find if current user already has a reaction
                var oldReactionTypeId: Int64?
                
                // Use Set for O(1) lookup instead of linear search
                if let targetUserState = otherUsersReactionState[targetUserId] {
                    let currentUserId = currentUser.id
                    
                    // Create a Set of user IDs for each reaction type for fast lookup
                    for (existingReactionTypeId, _) in updatedReactionCounts {
                        let existingUsers = targetUserState.getPaginationData(reactionTypeId: existingReactionTypeId).users
                        let existingUserIds = Set(existingUsers.map { $0.id })
                        
                        // O(1) lookup instead of O(n) linear search
                        if existingUserIds.contains(currentUserId) {
                            oldReactionTypeId = existingReactionTypeId
                            break
                        }
                    }
                }
                
                // ✅ OPTIMIZED: Decrement old reaction count if user had a previous reaction
                if let oldReactionType = oldReactionTypeId {
                    updatedReactionCounts[oldReactionType] = max(0, (updatedReactionCounts[oldReactionType] ?? 1) - 1)
                    print("✅ Optimistic update: Decremented old reaction count for type \(oldReactionType)")
                    
                    // ✅ OPTIMIZED: Remove user from old reaction list using Set for O(1) lookup
                    if var targetUserState = otherUsersReactionState[targetUserId] {
                        var oldReactionData = targetUserState.getPaginationData(reactionTypeId: oldReactionType)
                        
                        // Use Set for O(1) removal instead of O(n) linear search
                        let currentUserId = currentUser.id
                        oldReactionData.users.removeAll { $0.id == currentUserId }
                        
                        targetUserState.updatePaginationData(reactionTypeId: oldReactionType, data: oldReactionData)
                        otherUsersReactionState[targetUserId] = targetUserState
                        print("✅ Optimistic update: Removed user from old reaction list (type \(oldReactionType))")
                    }
                }
                
                // ✅ OPTIMIZED: Increment new reaction count
                updatedReactionCounts[reactionTypeId] = (updatedReactionCounts[reactionTypeId] ?? 0) + 1
                targetUser.reactionCounts = updatedReactionCounts
                otherUsers[targetUserId] = targetUser
                print("✅ Optimistic update: Target user reaction count updated (new reaction type \(reactionTypeId))")
            }
            
            // Note: Current user's reactionCounts should NOT change
            // reactionCounts = reactions RECEIVED by the user
            // When current user gives a reaction, they're not receiving one
            
            // ✅ OPTIMIZED: Update target user's reaction users list (if state exists)
            if var targetUserState = otherUsersReactionState[targetUserId] {
                var reactionData = targetUserState.getPaginationData(reactionTypeId: reactionTypeId)
                
                // ✅ OPTIMIZED: Check if current user already exists using Set for O(1) lookup
                let currentUserId = currentUser.id
                let existingUserIds = Set(reactionData.users.map { $0.id })
                
                if existingUserIds.contains(currentUserId) {
                    // ✅ OPTIMIZED: Remove existing reaction using index lookup
                    if let existingIndex = reactionData.users.firstIndex(where: { $0.id == currentUserId }) {
                        reactionData.users.remove(at: existingIndex)
                    print("✅ Optimistic update: Removed existing reaction from current reaction list")
                    }
                }
                
                // ✅ OPTIMIZED: Add current user to the beginning of the list (convert to ReactionUserProfile)
                let currentUserReactionProfile = ReactionUserProfile(
                    id: currentUser.id,
                    username: currentUser.username,
                    nickname: currentUser.nickname,
                    avatar: currentUser.avatar,
                    status: currentUser.status,
                    isAdmin: currentUser.isAdmin,
                    isFriend: currentUser.isFriend,
                    isFollowing: currentUser.isFollowing,
                    createdOn: currentUser.createdOn,
                    follows: currentUser.follows,
                    followings: currentUser.followings,
                    tweetsCount: currentUser.tweetsCount,
                    categories: currentUser.categories,
                    reactionCounts: currentUser.reactionCounts,
                    isOnline: currentUser.isOnline,
                    phone: currentUser.phone,
                    activation: currentUser.activation,
                    balance: currentUser.balance
                )
                reactionData.users.insert(currentUserReactionProfile, at: 0)
                
                // Check if we need to adjust pagination
                let pageSize = 20
                let newTotalCount = reactionData.users.count
                let newCurrentPage = (newTotalCount + pageSize - 1) / pageSize // Ceiling division
                
                // If we exceeded the current page, adjust
                if newCurrentPage > reactionData.currentPage {
                    reactionData.currentPage = newCurrentPage
                    print("✅ Optimistic update: Adjusted current page to \(newCurrentPage) for \(newTotalCount) users")
                }
                
                // Update hasMoreData based on whether we have a full page
                reactionData.hasMoreData = newTotalCount % pageSize == 0
                
                targetUserState.updatePaginationData(reactionTypeId: reactionTypeId, data: reactionData)
                otherUsersReactionState[targetUserId] = targetUserState
                print("✅ Optimistic update: Added current user to target user's reaction list")
            }
        }
        
        // API CALL
        let url = URL(string: "\(AuthConfig.baseURL)\(ReactionEndpoints.createReaction)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "target_user_id": targetUserId,
            "reaction_type_id": reactionTypeId
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // ✅ ENHANCED DEBUGGING: Log detailed request information
        print("\n=== 🔍 REACTION CREATION DEBUG ===")
        print("📤 Request URL: \(url)")
        print("📤 Request Method: \(request.httpMethod ?? "Unknown")")
        print("📤 Request Headers:")
        print("  - Authorization: Bearer \(String(token.prefix(20)))...")
        print("  - Content-Type: \(request.value(forHTTPHeaderField: "Content-Type") ?? "Unknown")")
        print("📤 Request Body:")
        print("  - target_user_id: \(targetUserId) (type: \(type(of: targetUserId)))")
        print("  - reaction_type_id: \(reactionTypeId) (type: \(type(of: reactionTypeId)))")
        print("📤 Request Body JSON: \(String(data: request.httpBody!, encoding: .utf8) ?? "Failed to encode")")
        print("📤 Current User ID: \(currentUser.id)")
        print("📤 Current User Username: \(currentUser.username ?? "Unknown")")
        print("=== END DEBUG ===\n")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.networkError("Invalid response")
            }
            
            print("📥 Received response for reaction creation")
            print("📊 HTTP Status Code: \(httpResponse.statusCode)")
            
            // Print raw response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📝 Raw Response JSON: \(jsonString)")
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ HTTP Error: Status code \(httpResponse.statusCode)")
                
                // Try to decode error response for better error message
                if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🔍 Error Response Structure: \(errorResponse)")
                    
                    if let errorCode = errorResponse["code"] {
                        print("🔍 Error Code: \(errorCode)")
                    }
                    
                    if let errorMsg = errorResponse["msg"] as? String {
                        print("🔍 Error Message: \(errorMsg)")
                        throw AuthError.networkError("Failed to create reaction (\(httpResponse.statusCode)): \(errorMsg)")
                    } else {
                        print("🔍 No error message found in response")
                        throw AuthError.networkError("Failed to create reaction: \(httpResponse.statusCode)")
                    }
                } else {
                    print("🔍 Could not decode error response as JSON")
                    throw AuthError.networkError("Failed to create reaction: \(httpResponse.statusCode)")
                }
            }
            
            // Try to decode the response with better error handling
            do {
                let createResponse = try JSONDecoder().decode(CreateReactionResponse.self, from: data)
                guard createResponse.code == 0 else {
                    throw AuthError.networkError(createResponse.msg)
                }
                
                print("✅ Reaction created successfully (standard format), keeping optimistic update")
            } catch let decodingError {
                print("❌ JSON Decoding Error: \(decodingError)")
                print("❌ Expected structure: CreateReactionResponse with code, msg, and optional data.success")
                
                // Try alternative response format
                do {
                    let simpleResponse = try JSONDecoder().decode(SimpleCreateReactionResponse.self, from: data)
                    if simpleResponse.success {
                        print("✅ Reaction created successfully (simple format), keeping optimistic update")
                    } else {
                        throw AuthError.networkError(simpleResponse.message ?? "Reaction creation failed")
                    }
                } catch let simpleDecodingError {
                    print("❌ Simple format decoding also failed: \(simpleDecodingError)")
                    
                    // Try to decode as raw JSON for manual inspection
                    if let simpleResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("🔍 Raw response structure: \(simpleResponse)")
                        
                        // Check if it's a simple success response
                        if let success = simpleResponse["success"] as? Bool, success {
                            print("✅ Reaction created successfully (raw JSON success), keeping optimistic update")
                        } else if let message = simpleResponse["message"] as? String {
                            throw AuthError.networkError("Backend response: \(message)")
                        } else if let error = simpleResponse["error"] as? String {
                            throw AuthError.networkError("Backend error: \(error)")
                        } else {
                            throw AuthError.networkError("Unexpected response format from backend")
                        }
                    } else {
                        throw AuthError.networkError("Failed to decode response: \(decodingError.localizedDescription)")
                    }
                }
            }
            
        } catch {
            print("❌ Failed to create reaction, reverting optimistic update")
            
            // REVERT OPTIMISTIC UPDATE: Restore original state on failure
            await MainActor.run {
                // 1. Revert target user's reaction counts
                if let originalUser = originalOtherUser {
                    otherUsers[targetUserId] = originalUser
                }
                
                // 2. Revert target user's reaction users list
                if let originalState = originalOtherUserReactionState {
                    otherUsersReactionState[targetUserId] = originalState
                } else {
                    otherUsersReactionState.removeValue(forKey: targetUserId)
                }
                
                print("🔄 Reverted optimistic updates due to API failure")
            }
            
            throw error
        }
    }
    
    
    // MARK: - Get Reaction Users List (who reacted to a user)
    func getReactionUsersList(userId: Int64? = nil, reactionTypeId: Int64, limit: Int = 20, offset: Int = 0) async throws -> (users: [ReactionUserProfile], total: Int) {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        // Build URL with optional user_id parameter
        var urlComponents = URLComponents(string: "\(AuthConfig.baseURL)\(ReactionEndpoints.getReactionUsersList)")!
        var queryItems = [
            URLQueryItem(name: "reaction_type_id", value: "\(reactionTypeId)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: "\(userId)"))
        }
        
        urlComponents.queryItems = queryItems
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let targetUser = userId
    
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Failed to get reaction users list: \(httpResponse.statusCode)")
        }
        
        // Print raw response for debugging (only in debug builds)
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 [DEBUG] Raw API Response for reaction users:")
            print(jsonString)
        }
        #endif
        
        do {
            let usersResponse = try JSONDecoder().decode(ReactionUsersResponse.self, from: data)
            guard usersResponse.code == 0 else {
                throw AuthError.networkError(usersResponse.msg)
            }
            
            // ✅ ADDED: Log isFollowing field for each user to verify API response
            print("🔍 [DEBUG] Reaction users API response - isFollowing field check:")
            for (index, user) in usersResponse.data.users.enumerated() {
                print("  User \(index + 1): ID=\(user.id), Username=\(user.username), isFollowing=\(user.isFollowing?.description ?? "nil")")
            }
            
            print("✅ Retrieved \(usersResponse.data.users.count) users (total: \(usersResponse.data.total))")
            return (usersResponse.data.users, usersResponse.data.total)
        } catch {
            print("❌ [DEBUG] Decoding error: \(error)")
            print("❌ [DEBUG] Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Get Given Reaction Counts (reactions sent by a user)
 /*   func getGivenReactionCounts(userId: Int64? = nil) async throws -> [String: Int] {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        // Build URL with optional user_id parameter
        var urlComponents = URLComponents(string: "\(AuthConfig.baseURL)\(ReactionEndpoints.getGivenReactionCounts)")!
        if let userId = userId {
            urlComponents.queryItems = [URLQueryItem(name: "user_id", value: "\(userId)")]
        }
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let targetUser = userId ?? "auth_user"
        print("📤 Getting reaction counts given by user: \(targetUser)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Failed to get given reaction counts: \(httpResponse.statusCode)")
        }
        
        let reactionsResponse = try JSONDecoder().decode(ReactionCountsResponse.self, from: data)
        guard reactionsResponse.code == 0 else {
            throw AuthError.networkError(reactionsResponse.msg)
        }
        
        print("✅ Retrieved \(reactionsResponse.data.reactionCounts.count) reaction types given by user")
        return reactionsResponse.data.reactionCounts
    }
    
    // MARK: - Get Given Reaction Users List (users a user has reacted to)
    func getGivenReactionUsersList(userId: Int64? = nil, reactionTypeId: Int64, limit: Int = 20, offset: Int = 0) async throws -> (users: [ReactionUserProfile], total: Int) {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        // Build URL with optional user_id parameter
        var urlComponents = URLComponents(string: "\(AuthConfig.baseURL)\(ReactionEndpoints.getGivenReactionUsersList)")!
        var queryItems = [
            URLQueryItem(name: "reaction_type_id", value: "\(reactionTypeId)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: "\(userId)"))
        }
        
        urlComponents.queryItems = queryItems
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let targetUser = userId ?? "auth_user"
        print("📤 Getting users that user \(targetUser) has reacted to with type: \(reactionTypeId)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Failed to get given reaction users list: \(httpResponse.statusCode)")
        }
        
        let usersResponse = try JSONDecoder().decode(ReactionUsersResponse.self, from: data)
        guard usersResponse.code == 0 else {
            throw AuthError.networkError(usersResponse.msg)
        }
        
        // Store users in otherUsers dictionary for caching (convert to UserProfile)
        await MainActor.run {
            for user in usersResponse.data.users {
                self.otherUsers[user.id] = user.toUserProfile()
            }
        }
        
        print("✅ Retrieved \(usersResponse.data.users.count) users (total: \(usersResponse.data.total))")
        return (usersResponse.data.users, usersResponse.data.total)
    }
    */
    // MARK: - Get Reactions Between Two Users List
    func getReactionsToTwoUsersList(user1Id: Int64, user2Id: Int64, page: Int = 1, pageSize: Int = 20) async throws -> (reactions: [UserReaction], pager: PagerInfo) {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        let url = URL(string: "\(AuthConfig.baseURL)\(ReactionEndpoints.getReactionsToTwoUsersList)?user1_id=\(user1Id)&user2_id=\(user2Id)&page=\(page)&page_size=\(pageSize)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📤 Getting reactions between users \(user1Id) and \(user2Id)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Failed to get reactions between users list: \(httpResponse.statusCode)")
        }
        
        let timelineResponse = try JSONDecoder().decode(ReactionTimelineResponse.self, from: data)
        guard timelineResponse.code == 0 else {
            throw AuthError.networkError(timelineResponse.msg)
        }
        
        
        print("✅ Retrieved \(timelineResponse.data.list.count) reactions between users")
        return (timelineResponse.data.list, timelineResponse.data.pager)
    }
    
    // MARK: - Get Global Reaction Timeline List
    func getGlobalReactionTimelineList(page: Int = 1, pageSize: Int = 20) async throws -> (reactions: [UserReaction], pager: PagerInfo) {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        let url = URL(string: "\(AuthConfig.baseURL)\(ReactionEndpoints.getGlobalTimelineList)?page=\(page)&page_size=\(pageSize)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📤 Getting global reaction timeline")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Failed to get global timeline list: \(httpResponse.statusCode)")
        }
        
        let timelineResponse = try JSONDecoder().decode(ReactionTimelineResponse.self, from: data)
        guard timelineResponse.code == 0 else {
            throw AuthError.networkError(timelineResponse.msg)
        }
        
        print("✅ Retrieved \(timelineResponse.data.list.count) reactions from global timeline")
        return (timelineResponse.data.list, timelineResponse.data.pager)
    }
    
    // MARK: - Get User Reaction Timeline List
    func getUserReactionTimelineList(userId: Int64, page: Int = 1, pageSize: Int = 20) async throws -> (reactions: [UserReaction], pager: PagerInfo) {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        let url = URL(string: "\(AuthConfig.baseURL)\(ReactionEndpoints.getUserTimelineList)?user_id=\(userId)&page=\(page)&page_size=\(pageSize)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📤 Getting reaction timeline for user: \(userId)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Failed to get user timeline list: \(httpResponse.statusCode)")
        }
        
        let timelineResponse = try JSONDecoder().decode(ReactionTimelineResponse.self, from: data)
        guard timelineResponse.code == 0 else {
            throw AuthError.networkError(timelineResponse.msg)
        }
        
        
        print("✅ Retrieved \(timelineResponse.data.list.count) reactions from user timeline")
        return (timelineResponse.data.list, timelineResponse.data.pager)
    }
    
    // MARK: - Convenience Methods
    
    /// Get reaction type by ID from static reactions
    func getReactionType(_ reactionTypeId: Int64) -> ReactionType? {
        return ReactionType.staticReactions.first { $0.id == reactionTypeId }
    }
    
    /// Get reaction type name by ID
    func getReactionTypeName(_ reactionTypeId: Int64) -> String {
        return getReactionType(reactionTypeId)?.name ?? "unknown"
    }
    
    /// Get reaction type icon by ID
    func getReactionTypeIcon(_ reactionTypeId: Int64) -> String {
        return getReactionType(reactionTypeId)?.icon ?? "❓"
    }
    
    /// Get reaction type color by ID
    func getReactionTypeColor(_ reactionTypeId: Int64) -> String {
        return getReactionType(reactionTypeId)?.color ?? "#000000"
    }
    
    /// Get reaction type description by ID
    func getReactionTypeDescription(_ reactionTypeId: Int64) -> String {
        return getReactionType(reactionTypeId)?.description ?? "Unknown reaction"
    }
    
    /// Check if reaction type is positive
    func isReactionTypePositive(_ reactionTypeId: Int64) -> Bool {
        return getReactionType(reactionTypeId)?.isPositive ?? true
    }
    
    /// Get all positive reactions
    func getPositiveReactions() -> [ReactionType] {
        return ReactionType.staticReactions.filter { $0.isPositive }
    }
    
    /// Get all negative reactions
    func getNegativeReactions() -> [ReactionType] {
        return ReactionType.staticReactions.filter { !$0.isPositive }
    }
    
    /// Get all reactions
    func getAllReactions() -> [ReactionType] {
        return ReactionType.staticReactions
    }
    
    /// Format reaction count for display
    func formatReactionCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    // MARK: - Reaction Type Conversion Methods (Frontend Conversion)
    
    /// Get reaction type by ID from static reactions (frontend conversion)
    func getReactionTypeById(_ reactionTypeId: Int64) -> ReactionType? {
        // ✅ OPTIMIZED: Use cached Dictionary for O(1) lookup instead of O(n) linear search
        return TweetData.staticReactionsDict[reactionTypeId]
    }
    
    /// Get reaction type name by ID (frontend conversion)
    func getReactionTypeNameById(_ reactionTypeId: Int64) -> String {
        return getReactionTypeById(reactionTypeId)?.name ?? "Unknown Reaction"
    }
    
    /// Get reaction type icon by ID (frontend conversion)
    func getReactionTypeIconById(_ reactionTypeId: Int64) -> String {
        return getReactionTypeById(reactionTypeId)?.icon ?? "❓"
    }
    
    /// Get reaction type color by ID (frontend conversion)
    func getReactionTypeColorById(_ reactionTypeId: Int64) -> String {
        return getReactionTypeById(reactionTypeId)?.color ?? "#000000"
    }
    
    /// Get reaction type description by ID (frontend conversion)
    func getReactionTypeDescriptionById(_ reactionTypeId: Int64) -> String {
        return getReactionTypeById(reactionTypeId)?.description ?? "Unknown reaction type"
    }
    
    /// Check if reaction type is positive by ID (frontend conversion)
    func isReactionTypePositiveById(_ reactionTypeId: Int64) -> Bool {
        return getReactionTypeById(reactionTypeId)?.isPositive ?? true
    }
    
    /// Convert reaction counts dictionary to ReactionType objects (frontend conversion)
    func convertReactionCountsToReactionTypes(_ reactionCounts: [Int64: Int]) -> [ReactionType: Int] {
        var converted: [ReactionType: Int] = [:]
        
        for (reactionTypeId, count) in reactionCounts {
            if let reactionType = getReactionTypeById(reactionTypeId) {
                converted[reactionType] = count
            }
        }
        
        return converted
    }
    
    /// Get all reaction types that have counts (frontend conversion)
    func getReactionTypesWithCounts(_ reactionCounts: [Int64: Int]) -> [ReactionType] {
        var reactionTypes: [ReactionType] = []
        
        for (reactionTypeId, _) in reactionCounts {
            if let reactionType = getReactionTypeById(reactionTypeId) {
                reactionTypes.append(reactionType)
            }
        }
        
        return reactionTypes
    }
    
    /// Get reaction count for specific reaction type (frontend conversion)
    func getReactionCount(_ reactionCounts: [Int64: Int], for reactionTypeId: Int64) -> Int {
        return reactionCounts[reactionTypeId] ?? 0
    }
}

// MARK: - UserProfile Reaction Extensions

extension UserProfile {
    /// Get reaction count for specific reaction type (frontend conversion)
    func getReactionCount(for reactionTypeId: Int64) -> Int {
        return reactionCounts?[reactionTypeId] ?? 0
    }
    
    /// Get all reaction types that have counts (frontend conversion)
    func getReactionTypesWithCounts() -> [ReactionType] {
        guard let reactionCounts = reactionCounts else { return [] }
        
        // ✅ OPTIMIZED: Use Dictionary for O(1) lookup instead of O(n) linear search
        let staticReactionsDict = Dictionary(uniqueKeysWithValues: ReactionType.staticReactions.map { ($0.id, $0) })
        
        var reactionTypes: [ReactionType] = []
        for (reactionTypeId, _) in reactionCounts {
            if let reactionType = staticReactionsDict[reactionTypeId] {
                reactionTypes.append(reactionType)
            }
        }
        
        return reactionTypes
    }
    
    /// Convert reaction counts to ReactionType objects with counts (frontend conversion)
    func getReactionTypesWithCountsDictionary() -> [ReactionType: Int] {
        guard let reactionCounts = reactionCounts else { return [:] }
        
        // ✅ OPTIMIZED: Use Dictionary for O(1) lookup instead of O(n) linear search
        let staticReactionsDict = Dictionary(uniqueKeysWithValues: ReactionType.staticReactions.map { ($0.id, $0) })
        
        var converted: [ReactionType: Int] = [:]
        for (reactionTypeId, count) in reactionCounts {
            if let reactionType = staticReactionsDict[reactionTypeId] {
                converted[reactionType] = count
            }
        }
        
        return converted
    }
    
    /// Check if user has any reactions (frontend conversion)
    var hasReactions: Bool {
        return reactionCounts?.isEmpty == false
    }
    
    /// Get total reaction count (frontend conversion)
    var totalReactionCount: Int {
        return reactionCounts?.values.reduce(0, +) ?? 0
    }
}

// MARK: - TweetData Reaction Users Loading Methods (with State Management)

extension TweetData {
    /// Load initial reaction users for a specific user and reaction type
    func loadReactionUsers(userId: Int64, reactionTypeId: Int64) async throws {
        // Determine if this is current user or other user
        let isCurrentUser = userId == self.user?.id
        
        print("\n=== 🔄 LOADING REACTION USERS ===")
        print("👤 User ID: \(userId) (isCurrentUser: \(isCurrentUser))")
        print("🎯 Reaction Type ID: \(reactionTypeId)")
        print("🔍 API Call Details:")
        print("  - Endpoint: \(ReactionEndpoints.getReactionUsersList)")
        print("  - User ID Parameter: \(userId)")
        print("  - Reaction Type ID: \(reactionTypeId)")
        print("  - Limit: 20, Offset: 0")
        
        // Check if we already have cached data
        let existingUsers: [ReactionUserProfile]
        let hasCachedData: Bool
        
        if isCurrentUser {
            existingUsers = currentUserReactionState.getPaginationData(reactionTypeId: reactionTypeId).users
            hasCachedData = !existingUsers.isEmpty
            print("📊 [CACHE] Current user state - existing users: \(existingUsers.count), hasCachedData: \(hasCachedData)")
        } else {
            existingUsers = otherUsersReactionState[userId]?.getPaginationData(reactionTypeId: reactionTypeId).users ?? []
            hasCachedData = !existingUsers.isEmpty
            print("📊 [CACHE] Other user state - existing users: \(existingUsers.count), hasCachedData: \(hasCachedData)")
        }
        
        // If we have cached data, return it immediately
        if hasCachedData {
            print("✅ [CACHE] Using cached data for user \(userId), reaction type \(reactionTypeId) - \(existingUsers.count) users")
            return
        }
        
        // Check if already loading
        if isCurrentUser {
            if currentUserReactionState.isLoading(reactionTypeId: reactionTypeId) {
                print("🔄 [CACHE] Already loading reaction users for current user, reaction type: \(reactionTypeId)")
                return
            }
        } else {
            if let userState = otherUsersReactionState[userId],
               userState.isLoading(reactionTypeId: reactionTypeId) {
                print("🔄 [CACHE] Already loading reaction users for user \(userId), reaction type: \(reactionTypeId)")
                return
            }
        }
        
        // Set loading state
        await MainActor.run {
            if isCurrentUser {
                var currentData = currentUserReactionState.getPaginationData(reactionTypeId: reactionTypeId)
                currentData.isLoading = true
                currentData.error = nil
                currentUserReactionState.updatePaginationData(reactionTypeId: reactionTypeId, data: currentData)
                print("🔄 [STATE] Set loading state for current user, reaction type: \(reactionTypeId)")
            } else {
                if otherUsersReactionState[userId] == nil {
                    otherUsersReactionState[userId] = ReactionUsersPaginationState()
                    print("🔄 [STATE] Created new pagination state for user: \(userId)")
                }
                var userData = otherUsersReactionState[userId]!.getPaginationData(reactionTypeId: reactionTypeId)
                userData.isLoading = true
                userData.error = nil
                otherUsersReactionState[userId]!.updatePaginationData(reactionTypeId: reactionTypeId, data: userData)
                print("🔄 [STATE] Set loading state for user \(userId), reaction type: \(reactionTypeId)")
            }
        }
        
        do {
            print("📡 [API] Making API call to fetch reaction users...")
            // Fetch first page
            let (users, total) = try await getReactionUsersList(userId: userId, reactionTypeId: reactionTypeId, limit: 20, offset: 0)
            
            // Update state with results
            await MainActor.run {
                if isCurrentUser {
                    var currentData = currentUserReactionState.getPaginationData(reactionTypeId: reactionTypeId)
                    currentData.users = users
                    currentData.currentPage = 1
                    currentData.hasMoreData = users.count < total
                    currentData.isLoading = false
                    currentData.error = nil
                    currentUserReactionState.updatePaginationData(reactionTypeId: reactionTypeId, data: currentData)
                    print("✅ [STATE] Updated current user state - users: \(users.count), total: \(total), hasMoreData: \(users.count < total)")
                    print("✅ [API] Loaded \(users.count) reaction users for current user, reaction type: \(reactionTypeId)")
                } else {
                    if otherUsersReactionState[userId] == nil {
                        otherUsersReactionState[userId] = ReactionUsersPaginationState()
                    }
                    var userData = otherUsersReactionState[userId]!.getPaginationData(reactionTypeId: reactionTypeId)
                    userData.users = users
                    userData.currentPage = 1
                    userData.hasMoreData = users.count < total
                    userData.isLoading = false
                    userData.error = nil
                    otherUsersReactionState[userId]!.updatePaginationData(reactionTypeId: reactionTypeId, data: userData)
                    print("✅ [STATE] Updated user \(userId) state - users: \(users.count), total: \(total), hasMoreData: \(users.count < total)")
                    print("✅ [API] Loaded \(users.count) reaction users for user \(userId), reaction type: \(reactionTypeId)")
                }
                
                // ✅ ADDED: Update reaction user indices cache after loading new users
                updateReactionUserIndicesCache()
            }
        } catch {
            // Update state with error
            await MainActor.run {
                if isCurrentUser {
                    var currentData = currentUserReactionState.getPaginationData(reactionTypeId: reactionTypeId)
                    currentData.isLoading = false
                    currentData.error = error.localizedDescription
                    currentUserReactionState.updatePaginationData(reactionTypeId: reactionTypeId, data: currentData)
                    print("❌ [STATE] Updated current user state with error: \(error.localizedDescription)")
                    print("❌ [API] Failed to load reaction users for current user, reaction type: \(reactionTypeId) - \(error)")
                } else {
                    if otherUsersReactionState[userId] == nil {
                        otherUsersReactionState[userId] = ReactionUsersPaginationState()
                    }
                    var userData = otherUsersReactionState[userId]!.getPaginationData(reactionTypeId: reactionTypeId)
                    userData.isLoading = false
                    userData.error = error.localizedDescription
                    otherUsersReactionState[userId]!.updatePaginationData(reactionTypeId: reactionTypeId, data: userData)
                    print("❌ [STATE] Updated user \(userId) state with error: \(error.localizedDescription)")
                    print("❌ [API] Failed to load reaction users for user \(userId), reaction type: \(reactionTypeId) - \(error)")
                }
            }
            throw error
        }
    }
    
    /// Load more reaction users (pagination) for a specific user and reaction type
    func loadMoreReactionUsers(userId: Int64, reactionTypeId: Int64) async throws {
        // Determine if this is current user or other user
        let isCurrentUser = userId == self.user?.id
        
        print("\n=== 📄 LOADING MORE REACTION USERS ===")
        print("👤 User ID: \(userId) (isCurrentUser: \(isCurrentUser))")
        print("🎯 Reaction Type ID: \(reactionTypeId)")
        print("🔍 Pagination Details:")
   
        
        // Get current state
        let currentPage: Int
        let hasMoreData: Bool
        let isLoading: Bool
        
        if isCurrentUser {
            currentPage = currentUserReactionState.getCurrentPage(reactionTypeId: reactionTypeId)
            hasMoreData = currentUserReactionState.hasMoreData(reactionTypeId: reactionTypeId)
            isLoading = currentUserReactionState.isLoading(reactionTypeId: reactionTypeId)
            print("📊 [STATE] Current user state - page: \(currentPage), hasMoreData: \(hasMoreData), isLoading: \(isLoading)")
        } else {
            guard let userState = otherUsersReactionState[userId] else {
                print("❌ No state found for user \(userId), loading initial data first")
                try await loadReactionUsers(userId: userId, reactionTypeId: reactionTypeId)
                return
            }
            currentPage = userState.getCurrentPage(reactionTypeId: reactionTypeId)
            hasMoreData = userState.hasMoreData(reactionTypeId: reactionTypeId)
            isLoading = userState.isLoading(reactionTypeId: reactionTypeId)
            print("📊 [STATE] User \(userId) state - page: \(currentPage), hasMoreData: \(hasMoreData), isLoading: \(isLoading)")
        }
        
        // Check if we can load more
        guard hasMoreData && !isLoading else {
            if !hasMoreData {
                print("ℹ️ [CACHE] No more data available for user \(userId), reaction type: \(reactionTypeId)")
            } else {
                print("🔄 [CACHE] Already loading more data for user \(userId), reaction type: \(reactionTypeId)")
            }
            return
        }
        
        print("✅ [CACHE] Proceeding with pagination - current page: \(currentPage)")
        
        // Set loading state
        await MainActor.run {
            if isCurrentUser {
                var currentData = currentUserReactionState.getPaginationData(reactionTypeId: reactionTypeId)
                currentData.isLoading = true
                currentUserReactionState.updatePaginationData(reactionTypeId: reactionTypeId, data: currentData)
                print("🔄 [STATE] Set pagination loading state for current user, reaction type: \(reactionTypeId)")
            } else {
                var userData = otherUsersReactionState[userId]!.getPaginationData(reactionTypeId: reactionTypeId)
                userData.isLoading = true
                otherUsersReactionState[userId]!.updatePaginationData(reactionTypeId: reactionTypeId, data: userData)
                print("🔄 [STATE] Set pagination loading state for user \(userId), reaction type: \(reactionTypeId)")
            }
        }
        
        do {
            // Calculate offset for next page
            let offset = currentPage * 20
            print("📡 [API] Making pagination API call - page: \(currentPage + 1), offset: \(offset)")
            
            // Fetch next page
            let (newUsers, total) = try await getReactionUsersList(userId: userId, reactionTypeId: reactionTypeId, limit: 20, offset: offset)
            
            // Update state with results
            await MainActor.run {
                if isCurrentUser {
                    var currentData = currentUserReactionState.getPaginationData(reactionTypeId: reactionTypeId)
                    let previousCount = currentData.users.count
                    currentData.users.append(contentsOf: newUsers)
                    currentData.currentPage = currentPage + 1
                    currentData.hasMoreData = currentData.users.count < total
                    currentData.isLoading = false
                    currentData.error = nil
                    currentUserReactionState.updatePaginationData(reactionTypeId: reactionTypeId, data: currentData)
                    print("✅ [STATE] Updated current user state - added \(newUsers.count) users (total: \(currentData.users.count)), page: \(currentData.currentPage), hasMoreData: \(currentData.hasMoreData)")
                    print("✅ [API] Loaded \(newUsers.count) more reaction users for current user, reaction type: \(reactionTypeId) (total: \(currentData.users.count))")
                } else {
                    var userData = otherUsersReactionState[userId]!.getPaginationData(reactionTypeId: reactionTypeId)
                    let previousCount = userData.users.count
                    userData.users.append(contentsOf: newUsers)
                    userData.currentPage = currentPage + 1
                    userData.hasMoreData = userData.users.count < total
                    userData.isLoading = false
                    userData.error = nil
                    otherUsersReactionState[userId]!.updatePaginationData(reactionTypeId: reactionTypeId, data: userData)
                    print("✅ [STATE] Updated user \(userId) state - added \(newUsers.count) users (total: \(userData.users.count)), page: \(userData.currentPage), hasMoreData: \(userData.hasMoreData)")
                    print("✅ [API] Loaded \(newUsers.count) more reaction users for user \(userId), reaction type: \(reactionTypeId) (total: \(userData.users.count))")
                }
            }
        } catch {
            // Update state with error
            await MainActor.run {
                if isCurrentUser {
                    var currentData = currentUserReactionState.getPaginationData(reactionTypeId: reactionTypeId)
                    currentData.isLoading = false
                    currentData.error = error.localizedDescription
                    currentUserReactionState.updatePaginationData(reactionTypeId: reactionTypeId, data: currentData)
                    print("❌ [STATE] Updated current user state with pagination error: \(error.localizedDescription)")
                    print("❌ [API] Failed to load more reaction users for current user, reaction type: \(reactionTypeId) - \(error)")
                } else {
                    var userData = otherUsersReactionState[userId]!.getPaginationData(reactionTypeId: reactionTypeId)
                    userData.isLoading = false
                    userData.error = error.localizedDescription
                    otherUsersReactionState[userId]!.updatePaginationData(reactionTypeId: reactionTypeId, data: userData)
                    print("❌ [STATE] Updated user \(userId) state with pagination error: \(error.localizedDescription)")
                    print("❌ [API] Failed to load more reaction users for user \(userId), reaction type: \(reactionTypeId) - \(error)")
                }
            }
            throw error
        }
    }
    
    /// Reset reaction users state for a specific user and reaction type
    func resetReactionUsers(userId: Int64, reactionTypeId: Int64) {
        let isCurrentUser = userId == self.user?.id
        
        print("\n=== 🔄 RESETTING REACTION USERS STATE ===")
        print("👤 User ID: \(userId) (isCurrentUser: \(isCurrentUser))")
        print("🎯 Reaction Type ID: \(reactionTypeId)")
        
        if isCurrentUser {
            currentUserReactionState.resetPaginationData(reactionTypeId: reactionTypeId)
            print("✅ [STATE] Reset reaction users state for current user, reaction type: \(reactionTypeId)")
        } else {
            otherUsersReactionState[userId]?.resetPaginationData(reactionTypeId: reactionTypeId)
            print("✅ [STATE] Reset reaction users state for user \(userId), reaction type: \(reactionTypeId)")
        }
    }
    
    /// Reset all reaction users state for a specific user
    func resetAllReactionUsersForUser(userId: Int64) {
        let isCurrentUser = userId == self.user?.id
        
        print("\n=== 🔄 RESETTING ALL REACTION USERS STATE ===")
        print("👤 User ID: \(userId) (isCurrentUser: \(isCurrentUser))")
        
        if isCurrentUser {
            currentUserReactionState.resetAllData()
            print("✅ [STATE] Reset all reaction users state for current user")
        } else {
            otherUsersReactionState.removeValue(forKey: userId)
            print("✅ [STATE] Reset all reaction users state for user \(userId)")
        }
    }
    
    /// Update follow status in reaction users state when it changes
    /// ✅ OPTIMIZED: O(1) lookup using cached user indices
    func updateFollowStatusInReactionState(userId: Int64, isFollowing: Bool) {
        print("🔄 [TweetData] Updating follow status in reaction state for user \(userId) to \(isFollowing)")
        
        // ✅ OPTIMIZED: Use cached user indices for O(1) lookup
        guard let userIndices = reactionUserIndices[userId] else {
            print("⚠️ No cached indices found for user \(userId), skipping reaction state update")
            return
        }
        
        // Update in current user's reaction state
        for (reactionTypeId, userIndex) in userIndices.currentUserIndices {
            if var paginationData = currentUserReactionState.reactionTypes[reactionTypeId] {
                paginationData.users[userIndex].isFollowing = isFollowing
                currentUserReactionState.reactionTypes[reactionTypeId] = paginationData
                print("✅ Updated follow status in current user reaction state for reaction type \(reactionTypeId)")
            }
        }
        
        // Update in other users' reaction states
        for (otherUserId, indices) in userIndices.otherUserIndices {
            for (reactionTypeId, userIndex) in indices {
                if var paginationData = otherUsersReactionState[otherUserId]?.reactionTypes[reactionTypeId] {
                    paginationData.users[userIndex].isFollowing = isFollowing
                    otherUsersReactionState[otherUserId]?.reactionTypes[reactionTypeId] = paginationData
                    print("✅ Updated follow status in other user \(otherUserId) reaction state for reaction type \(reactionTypeId)")
                }
            }
        }
    }
}

// ✅ REMOVED: PaginationData and ReactionUsersPaginationState moved to main TweetData.swift file
// These types are now defined in the main TweetData class to avoid circular dependencies

// ReactionsFeed logic below 

// MARK: - Reactions Feed State
struct ReactionsFeedState {
    var reactions: [UserReaction]
    var error: String?
    
    init() {
        self.reactions = []
        self.error = nil
    }
    
    mutating func reset() {
        self.reactions = []
        self.error = nil
    }
}

// MARK: - Reactions Feed Pagination Manager Extension
extension TweetData {
    
    // MARK: - Public Methods
    
    /// Load reactions feed with pagination
    @MainActor
    func loadReactionsFeed(reactionPage: Int = 1, forceRefresh: Bool = false) async {
        // Prevent infinite loading if we've already tried and got empty results
        if reactionPage == 1 && !forceRefresh && reactionsFeed.reactions.isEmpty && currentPageReactions > 0 {
            print("⏸️ Skipping load - already tried and got empty results")
            return
        }
        print("\n=== 🎯 LOADING REACTIONS FEED ===")
        print("📄 Reaction Page: \(reactionPage)")
        print("🔄 Force Refresh: \(forceRefresh)")
        print("📊 Current reaction count: \(reactionsFeed.reactions.count)")
        print("🔍 PAGINATION STATE:")
        print("  - currentPageReactions: \(currentPageReactions)")
        print("  - hasMoreDataReactions: \(hasMoreDataReactions)")
     
        // Reset reaction error state
        reactionsFeed.error = nil
        
        // Handle reaction loading states
        if reactionPage == 1 {
            if isLoadingReactions {
                print("⏸️ Already loading initial reaction page, skipping...")
                return
            }
            isLoadingReactions = true
            print("🔄 Started loading initial reaction page")
        } else {
            if isLoadingMoreReactions {
                print("⏸️ Already loading more reactions, skipping...")
                return
            }
            isLoadingMoreReactions = true
            print("🔄 Started loading more reactions")
        }
        
        do {
            print("📡 Fetching reactions from API...")
            let (reactions, pager) = try await getGlobalReactionTimelineList(page: reactionPage, pageSize: reactionPageSize)
            print("✅ Received \(reactions.count) reactions")
            
            // Update reaction state with new reactions
            if reactionPage == 1 || forceRefresh {
                print("📝 Replacing all reactions (first page or force refresh)")
                reactionsFeed.reactions = reactions
            } else {
                print("📝 Appending new reactions (page \(reactionPage))")
                // Filter out duplicate reactions
                let newReactions = reactions.filter { newReaction in
                    !reactionsFeed.reactions.contains { $0.id == newReaction.id }
                }
                print("📊 Filtered out \(reactions.count - newReactions.count) duplicate reactions")
                reactionsFeed.reactions.append(contentsOf: newReactions)
            }
            
            // Update reaction pagination state
            print("🔍 UPDATING PAGINATION STATE:")
            print("  - Before update - currentPageReactions: \(currentPageReactions)")
            print("  - Before update - hasMoreDataReactions: \(hasMoreDataReactions)")
            print("  - New page: \(reactionPage)")
            print("  - Reaction count: \(reactions.count)")
            print("  - Page size: \(reactionPageSize)")
            print("  - Has more data: \(reactions.count == reactionPageSize)")
            
            currentPageReactions = reactionPage
            hasMoreDataReactions = reactions.count == reactionPageSize
            
            // Mark this page as loaded
            loadedPagesReactions.insert(reactionPage)
            
            print("📊 Updated reaction pagination state:")
            print("- Current Reaction Page: \(currentPageReactions)")
            print("- Has More Reaction Data: \(hasMoreDataReactions)")
            print("- Total Reactions: \(reactionsFeed.reactions.count)")
            print("- Loaded Pages: \(loadedPagesReactions)")
            print("🔍 FINAL PAGINATION STATE:")
            print("  - currentPageReactions: \(currentPageReactions)")
            print("  - hasMoreDataReactions: \(hasMoreDataReactions)")
            print("  - loadedPagesReactions: \(loadedPagesReactions)")
            
            // Reset reaction retry count on success
            reactionLoadRetryCount = 0
            
            // Clean up old reactions to prevent memory issues
            cleanupOldReactions()
            
        } catch {
            print("❌ Error loading reactions feed: \(error)")
            handleReactionNetworkError(error)
            
            // Handle reaction retries
            if reactionLoadRetryCount < reactionMaxRetries {
                reactionLoadRetryCount += 1
                print("🔄 Retrying reaction load (attempt \(reactionLoadRetryCount) of \(reactionMaxRetries))")
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(reactionLoadRetryCount)) * 1_000_000_000))
                await loadReactionsFeed(reactionPage: reactionPage, forceRefresh: forceRefresh)
                return
            }
            
            // If we're loading reaction page 1, clear the reactions array
            if reactionPage == 1 {
                reactionsFeed.reactions = []
            }
            
            // Reset reaction loading states on error (after all retries exhausted)
            if reactionPage == 1 {
                isLoadingReactions = false
            } else {
                isLoadingMoreReactions = false
            }
            
            print("❌ Reactions feed load failed after all retries")
            return
        }
        
        // Reset reaction loading states on success
        if reactionPage == 1 {
            isLoadingReactions = false
        } else {
            isLoadingMoreReactions = false
        }
        
        print("✅ Reactions feed load completed")
    }
    
    /// Refresh reactions feed (reset and reload)
    @MainActor
    func refreshReactionsFeed() async {
        print("\n=== 🔄 REFRESHING REACTIONS FEED ===")
        print("📊 Current Reaction State:")
        print("- Current Reaction Page: \(currentPageReactions)")
        print("- Has More Reaction Data: \(hasMoreDataReactions)")
        print("- Reaction Count: \(reactionsFeed.reactions.count)")
        
        // Reset all reaction pagination state
        reactionsFeed.reset()
        currentPageReactions = 0
        hasMoreDataReactions = true
        loadedPagesReactions.removeAll()
        
        await loadReactionsFeed(reactionPage: 1, forceRefresh: true)
        print("✅ Reactions feed refresh completed")
    }
    
    /// Load more reactions (next page)
    @MainActor
    func loadMoreReactionsFeed() async {
        print("\n=== 📄 LOAD MORE REACTIONS CALLED ===")
        print("🔍 CURRENT STATE:")
        print("  - isLoadingReactions: \(isLoadingReactions)")
        print("  - isLoadingMoreReactions: \(isLoadingMoreReactions)")
        print("  - hasMoreDataReactions: \(hasMoreDataReactions)")
        print("  - currentPageReactions: \(currentPageReactions)")
        
        guard !isLoadingReactions && !isLoadingMoreReactions && hasMoreDataReactions else {
            print("⏸️ Skipping load more reactions:")
            print("- Reaction isLoading: \(isLoadingReactions)")
            print("- Reaction isLoadingMore: \(isLoadingMoreReactions)")
            print("- Reaction hasMoreData: \(hasMoreDataReactions)")
            return
        }
        
        // Prevent loading the same page multiple times
        let nextReactionPage = currentPageReactions + 1
        
        // Validate that we have a valid next page (should always be valid since we increment by 1)
        guard nextReactionPage > currentPageReactions else {
            print("⚠️ Invalid next page calculation:")
            print("  - currentPageReactions: \(currentPageReactions)")
            print("  - calculated nextReactionPage: \(nextReactionPage)")
            return
        }
        
        print("📄 Loading more reactions - Reaction Page \(nextReactionPage)")
        print("🔍 NEXT PAGE CALCULATION:")
        print("  - currentPageReactions: \(currentPageReactions)")
        print("  - nextReactionPage: \(nextReactionPage)")
        await loadReactionsFeed(reactionPage: nextReactionPage)
    }
    
    /// Load previous reactions (previous page)
    @MainActor
    func loadPreviousReactionsFeed() async {
        print("\n=== ⬆️ LOAD PREVIOUS REACTIONS CALLED ===")
        print("🔍 PREVIOUS REACTIONS STATE:")
        print("  - isLoadingReactions: \(isLoadingReactions)")
        print("  - isLoadingMoreReactions: \(isLoadingMoreReactions)")
        print("  - currentPageReactions: \(currentPageReactions)")
        print("  - reactionsFeed.reactions.count: \(reactionsFeed.reactions.count)")
        
        // Enhanced guard conditions for loading previous reactions
        guard !isLoadingReactions &&
              !isLoadingMoreReactions &&
              currentPageReactions > 1 &&
              !reactionsFeed.reactions.isEmpty else {
            print("⏸️ Skipping load previous reactions:")
            print("  - Already loading: \(isLoadingReactions || isLoadingMoreReactions)")
            print("  - At first page: \(currentPageReactions <= 1)")
            print("  - No reactions: \(reactionsFeed.reactions.isEmpty)")
            return
        }
        
        let previousPage = currentPageReactions - 1
        
        // Check if the previous page is already loaded using page tracking
        if loadedPagesReactions.contains(previousPage) {
            print("⏸️ Skipping load previous reactions - page \(previousPage) already loaded:")
            print("  - Loaded pages: \(loadedPagesReactions)")
            print("  - Current page: \(currentPageReactions)")
            print("  - Previous page: \(previousPage)")
            return
        }
        
        // Validate that we have a valid previous page
        guard previousPage >= 1 else {
            print("⏸️ No valid previous page available")
            print("  - currentPageReactions: \(currentPageReactions)")
            print("  - calculated previousPage: \(previousPage)")
            return
        }
        
        print("⬆️ Loading previous reactions - Page \(previousPage)")
        print("🔍 PREVIOUS PAGE CALCULATION:")
        print("  - currentPageReactions: \(currentPageReactions)")
        print("  - previousPage: \(previousPage)")
        
        isLoadingReactions = true
        do {
            let (previousReactions, _) = try await getGlobalReactionTimelineList(page: previousPage, pageSize: reactionPageSize)
            print("✅ Received \(previousReactions.count) previous reactions")
            
            // Filter out duplicates before prepending
            let uniquePreviousReactions = previousReactions.filter { newReaction in
                !reactionsFeed.reactions.contains { $0.id == newReaction.id }
            }
            print("📊 Filtered out \(previousReactions.count - uniquePreviousReactions.count) duplicate previous reactions")
            
            // Prepend reactions
            reactionsFeed.reactions.insert(contentsOf: uniquePreviousReactions, at: 0)
            
            // Update pagination state
            currentPageReactions = previousPage
            hasMoreDataReactions = true // Assume there might be more previous pages
            
            // Mark the previous page as loaded
            loadedPagesReactions.insert(previousPage)
            
            print("✅ Prepended \(uniquePreviousReactions.count) previous reactions. Current page: \(currentPageReactions)")
            print("🔍 FINAL STATE AFTER PREPENDING:")
            print("  - currentPageReactions: \(currentPageReactions)")
            print("  - reactionsFeed.reactions.count: \(reactionsFeed.reactions.count)")
            print("  - hasMoreDataReactions: \(hasMoreDataReactions)")
            print("  - loadedPagesReactions: \(loadedPagesReactions)")
            
        } catch {
            print("❌ Error loading previous reactions: \(error)")
            reactionsFeed.error = error.localizedDescription
        }
        isLoadingReactions = false
    }
    
    /// Save reaction position for restoration
    @MainActor
    func saveReactionPosition(index: Int) {
        // Ensure index is valid
        let validIndex = max(0, index)
        lastViewedReactionIndex = validIndex
        lastViewedReactionPage = (validIndex / reactionPageSize) + 1
        print("💾 Saved reaction position:")
        print("- Reaction Index: \(lastViewedReactionIndex)")
        print("- Reaction Page: \(lastViewedReactionPage)")
    }
    
    /// Restore reaction position
    @MainActor
    func restoreReactionPosition() -> (index: Int, page: Int) {
        // Ensure we never return negative index
        let validIndex = max(0, lastViewedReactionIndex)
        print("📖 Restoring reaction position:")
        print("- Reaction Index: \(validIndex)")
        print("- Reaction Page: \(lastViewedReactionPage)")
        return (validIndex, lastViewedReactionPage)
    }
    
    /// Reset reaction loading states
    @MainActor
    func resetReactionLoadingStates() {
        print("🔄 Resetting reaction loading states")
        isLoadingReactions = false
        isLoadingMoreReactions = false
    }
    
    // MARK: - Private Methods
    
    /// Clean up old reactions to prevent memory issues
    @MainActor
    private func cleanupOldReactions() {
        let maxReactionPosts = 1000
        if reactionsFeed.reactions.count > maxReactionPosts {
            print("🧹 Cleaning up old reaction posts - keeping last \(maxReactionPosts/2) reaction posts")
            reactionsFeed.reactions = Array(reactionsFeed.reactions.suffix(maxReactionPosts/2))
        }
    }
    
    /// Handle reaction network errors
    @MainActor
    private func handleReactionNetworkError(_ error: Error) {
        print("❌ Reaction feed network error: \(error)")
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                reactionsFeed.error = "No internet connection. Please check your network."
            case .timedOut:
                reactionsFeed.error = "Request timed out. Please try again."
            case .cancelled:
                reactionsFeed.error = "Request was cancelled."
            default:
                reactionsFeed.error = "Network error: \(urlError.localizedDescription)"
            }
        } else {
            reactionsFeed.error = error.localizedDescription
        }
    }
}

// MARK: - Reaction Feed Pagination Extensions

extension TweetData {
    
    /// Check if there are more reactions to load
    var hasMoreReactionsFeed: Bool {
        return hasMoreDataReactions
    }
    
    /// Get current reaction page
    var currentReactionPage: Int {
        return currentPageReactions
    }
    
    /// Get total reaction count
    var totalReactionCount: Int {
        return reactionsFeed.reactions.count
    }
    
    /// Check if reactions are currently loading
    var isReactionsFeedLoading: Bool {
        return isLoadingReactions
    }
    
    /// Check if more reactions are being loaded
    var isReactionsFeedLoadingMore: Bool {
        return isLoadingMoreReactions
    }
    
    /// Check if a specific reaction page is already loaded
    var isReactionPageLoaded: (Int) -> Bool {
        return { page in
            return self.loadedPagesReactions.contains(page)
        }
    }
    
    // MARK: - Convenience Properties for UI
    
    /// Get reactions for UI display
    var reactionsFeedReactions: [UserReaction] {
        return reactionsFeed.reactions
    }
    
    /// Get loading state for UI (alias for consistency)
    var reactionsFeedIsLoading: Bool {
        return isLoadingReactions
    }
    
    /// Get has more data state for UI (alias for consistency)
    var reactionsFeedHasMoreData: Bool {
        return hasMoreDataReactions
    }
    
    /// Get current index for UI
    var reactionsFeedCurrentIndex: Int {
        return lastViewedReactionIndex
    }
    
    /// Set current index for UI
    func setCurrentReactionFeedIndex(_ index: Int) {
        lastViewedReactionIndex = index
        saveReactionPosition(index: index)
    }
}

