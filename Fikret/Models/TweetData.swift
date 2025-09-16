import SwiftUI
//import Supabase
import Ably
import CoreLocation
import Security
import Foundation


// Configuration
struct AuthConfig {
    static var baseURL: String {
        print("🔍 [AuthConfig] Using production server")
        return "http://api.tototopo.com:8008"  // Production server
    }
    
    struct Endpoints {
        static let userFollows = "/v1/user/follows"           // Users that the specified user follows
        static let userFollowings = "/v1/user/followings"
        static let register = "/v1/auth/register"
        static let login = "/v1/auth/login"
        static let userInfo = "/v1/user/info"
        static let profile = "/v1/user/profile"
        static let changePassword = "/v1/user/password"
        static let changeNickname = "/v1/user/nickname"
        static let changeAvatar = "/v1/user/avatar"
        static let categories = "/v1/user/categories"
        static let captcha = "/v1/captcha"
        static let bindPhone = "/v1/user/phone"
        static let activate = "/v1/user/activate"
        static let userOnlineStatus = "/v1/user/online-status" // Add this line
    }
}


// Request model for checking user online status
struct UserOnlineStatusRequest: Codable {
    let userId: Int64
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

// Response model for user online status
struct UserOnlineStatusResponse: Codable {
    let code: Int
    let msg: String
    let data: UserOnlineStatusData?
}

struct UserOnlineStatusData: Codable {
    let userId: Int64
    let isOnline: Bool?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isOnline = "is_online"
    }
}

    struct UserProfileResponse: Codable {
        let code: Int
        let msg: String
        let data: UserProfileData?
        
        struct UserProfileData: Codable {
            let id: Int64
            let nickname: String
            let username: String
            let status: Int
            let avatar: String
            let isAdmin: Bool
            let isFriend: Bool
            let isFollowing: Bool
            let createdOn: Int64
            let follows: Int
            let followings: Int
            let tweetsCount: Int
            var categories: [Int64]?
            let reactionCounts: [String: Int]? // NEW: Reactions received by this user (API returns String keys)
            let phone: String?
            let activation: String?
            let balance: Int64?
            let isOnline: Bool? // NEW: User's online status
            
            enum CodingKeys: String, CodingKey {
                case id, nickname, username, status, avatar
                case isAdmin = "is_admin"
                case isFriend = "is_friend"
                case isFollowing = "is_following"
                case createdOn = "created_on"
                case follows, followings
                case tweetsCount = "tweets_count"
                case categories // NEW
                case reactionCounts = "reaction_counts" // NEW
                case phone, activation, balance
                case isOnline = "is_online" // NEW: User's online status
            }
            
            // ✅ FIXED: Custom decoder to fix malformed avatar URLs at the source
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(Int64.self, forKey: .id)
                nickname = try container.decode(String.self, forKey: .nickname)
                username = try container.decode(String.self, forKey: .username)
                status = try container.decode(Int.self, forKey: .status)
                
                // ✅ FIXED: Fix malformed avatar URL at the source
                let rawAvatar = try container.decode(String.self, forKey: .avatar)
                avatar = rawAvatar.fixMalformedURL()
                
                isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
                isFriend = try container.decode(Bool.self, forKey: .isFriend)
                isFollowing = try container.decode(Bool.self, forKey: .isFollowing)
                createdOn = try container.decode(Int64.self, forKey: .createdOn)
                follows = try container.decode(Int.self, forKey: .follows)
                followings = try container.decode(Int.self, forKey: .followings)
                tweetsCount = try container.decode(Int.self, forKey: .tweetsCount)
                categories = try container.decodeIfPresent([Int64].self, forKey: .categories)
                reactionCounts = try container.decodeIfPresent([String: Int].self, forKey: .reactionCounts)
                phone = try container.decodeIfPresent(String.self, forKey: .phone)
                activation = try container.decodeIfPresent(String.self, forKey: .activation)
                balance = try container.decodeIfPresent(Int64.self, forKey: .balance)
                isOnline = try container.decodeIfPresent(Bool.self, forKey: .isOnline)
            }
        }
    }
    

struct UserProfile: Identifiable, Codable, Equatable {
    let id: Int64
    let username: String
    var nickname: String
    var avatar: String
    let status: Int
    let isAdmin: Bool
    var isFriend: Bool?
    var isFollowing: Bool?
    let createdOn: Int64? // Made optional since reaction API might not include this field
    var follows: Int      // ✅ FIXED: Made non-optional since API always returns this
    var followings: Int   // ✅ FIXED: Made non-optional since API always returns this
    let tweetsCount: Int? // Made optional since reaction API might not include this field
    // NEW: Add categories field
    var categories: [Int64]?
    // NEW: Add reaction data field (only reactions received)
    var reactionCounts: [Int64: Int]? // Reactions received by this user (API returns Int keys)
    // NEW: Add online status field
    var isOnline: Bool?
    // Optional fields that might not always be present
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
        case categories // NEW
        case reactionCounts = "reaction_counts" // NEW
        case isOnline = "is_online" // NEW: User's online status
        case phone
        case activation
        case balance
    }
    
    // Manual initializer for direct property initialization
    init(id: Int64, nickname: String, username: String, avatar: String, isFollowing: Bool,
         status: Int, isAdmin: Bool, isFriend: Bool, follows: Int, followings: Int, tweetsCount: Int?,
         createdOn: Int64? = 0, categories: [Int64]? = nil, reactionCounts: [Int64: Int]? = nil, isOnline: Bool? = nil, phone: String? = nil, activation: String? = nil, balance: Int64? = nil) {
        self.id = id
        self.nickname = nickname
        self.username = username
        self.avatar = avatar
        self.isFollowing = isFollowing
        self.status = status
        self.isAdmin = isAdmin
        self.isFriend = isFriend
        self.follows = follows
        self.followings = followings
        self.tweetsCount = tweetsCount
        self.createdOn = createdOn
        self.categories = categories // NEW
        self.reactionCounts = reactionCounts // NEW
        self.isOnline = isOnline // NEW: User's online status
        self.phone = phone
        self.activation = activation
        self.balance = balance
    }
    
    // Decoder initializer for JSON decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        nickname = try container.decode(String.self, forKey: .nickname)
        username = try container.decode(String.self, forKey: .username)
        // Fix malformed avatar URLs (remove double https://)
        let rawAvatar = try container.decode(String.self, forKey: .avatar)
        avatar = UserProfile.fixAvatarURL(rawAvatar)
        isFollowing = try container.decodeIfPresent(Bool.self, forKey: .isFollowing)
        status = try container.decode(Int.self, forKey: .status)
        isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
        isFriend = try container.decodeIfPresent(Bool.self, forKey: .isFriend)
        follows = try container.decode(Int.self, forKey: .follows)
        followings = try container.decode(Int.self, forKey: .followings)
        tweetsCount = try container.decodeIfPresent(Int.self, forKey: .tweetsCount)
        createdOn = try container.decodeIfPresent(Int64.self, forKey: .createdOn)
        categories = try container.decodeIfPresent([Int64].self, forKey: .categories) // NEW
        // Convert [String: Int] from API to [Int64: Int] for internal use
        if let stringReactionCounts = try container.decodeIfPresent([String: Int].self, forKey: .reactionCounts) {
            reactionCounts = Dictionary(uniqueKeysWithValues: stringReactionCounts.compactMap { key, value in
                guard let int64Key = Int64(key) else { return nil }
                return (int64Key, value)
            })
        } else {
            reactionCounts = nil
        }
        isOnline = try container.decodeIfPresent(Bool.self, forKey: .isOnline) // NEW: User's online status
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        activation = try container.decodeIfPresent(String.self, forKey: .activation)
        balance = try container.decodeIfPresent(Int64.self, forKey: .balance)
        print("🔍 Decoded user \(nickname) with isFollowing: \(String(describing: isFollowing))")
    }
    
    // Helper function to fix malformed avatar URLs
    private static func fixAvatarURL(_ url: String) -> String {
        return url.fixMalformedURL()
    }
    
    // Convert UserProfile to ReactionUserProfile
    func toReactionUserProfile() -> ReactionUserProfile {
        return ReactionUserProfile(
            id: id,
            username: username,
            nickname: nickname,
            avatar: avatar,
            status: status,
            isAdmin: isAdmin,
            isFriend: isFriend,
            isFollowing: isFollowing,
            createdOn: createdOn,
            follows: follows,
            followings: followings,
            tweetsCount: tweetsCount,
            categories: categories,
            reactionCounts: reactionCounts,
            isOnline: isOnline,
            phone: phone,
            activation: activation,
            balance: balance
        )
    }
    
    // Convert UserProfile to SearchUserProfile
    func toSearchUserProfile() -> SearchUserProfile {
        return SearchUserProfile(
            id: id,
            username: username,
            nickname: nickname,
            avatar: avatar,
            status: status,
            isAdmin: isAdmin,
            isFriend: isFriend,
            isFollowing: isFollowing,
            createdOn: createdOn,
            follows: follows,
            followings: followings,
            tweetsCount: tweetsCount,
            categories: categories,
            reactionCounts: reactionCounts,
            isOnline: isOnline,
            phone: phone,
            activation: activation,
            balance: balance
        )
    }
}


class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.your.app"
    private let account = "authToken"
    private let usernameAccount = "username"
    
    private init() {}
    
    func saveToken(_ token: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        // First delete any existing token
        SecItemDelete(query as CFDictionary)
        
        // Add the new token
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainError("Failed to save token to keychain")
        }
    }
    
    func getToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func saveUsername(_ username: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: usernameAccount,
            kSecValueData as String: username.data(using: .utf8)!
        ]
        
        // First delete any existing username
        SecItemDelete(query as CFDictionary)
        
        // Add the new username
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainError("Failed to save username to keychain")
        }
    }
    
    func getUsername() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: usernameAccount,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let username = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return username
    }
    
    func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthError.keychainError("Failed to delete token from keychain")
        }
    }
    
    func deleteUsername() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: usernameAccount
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthError.keychainError("Failed to delete username from keychain")
        }
    }
    

}



enum AuthError: Error {
    case invalidInput
    case networkError(String)
    case otpVerificationFailed
    case signupFailed(String)
    case loginFailed(String)
    case refreshTokenFailed(String)
    case unauthorized(String)
    case keychainError(String)
    case avatarUploadFailed(String)
    case notAuthenticated
    case contactAccessDenied(String)
    case notificationPermissionDenied(String)
    case deviceTokenNotFound(String)
}


// MARK: - Contact Item Model
struct ContactItem: Codable {
    let name: String
    let phone: String
    let email: String?
    
    init(name: String, phone: String, email: String? = nil) {
        self.name = name
        self.phone = phone
        self.email = email
    }
}

// MARK: - Device Info Model
struct DeviceInfo: Codable {
    let deviceToken: String
    let platform: String
    let deviceID: String
    let deviceName: String
    
    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
        case platform
        case deviceID = "device_id"
        case deviceName = "device_name"
    }
}



// MARK: - Auth Models
struct LoginResponse: Codable {
    let code: Int
    let msg: String
    let data: LoginData?
    
    struct LoginData: Codable {
        let token: String
    }
}

struct RegisterResponse: Codable {
    let code: Int
    let msg: String
    let data: RegisterData?
    
    struct RegisterData: Codable {
        let id: Int64
        let username: String
        let categories: [Int64]?
        let contactsUploaded: Int64?
        let contactsMatched: Int64?
        let deviceRegistered: Bool?
        
        enum CodingKeys: String, CodingKey {
            case id
            case username
            case categories
            case contactsUploaded = "contacts_uploaded"
            case contactsMatched = "contacts_matched"
            case deviceRegistered = "device_registered"
        }
    }
}


// Response type for user search
struct UserSearchResponse: Codable {
    let code: Int
    let msg: String
    let data: SearchData
    
    struct SearchData: Codable {
        let suggests: [SearchUserProfile]
    }
}

// Separate struct for search API response (with optional follows/followings)
struct SearchUserProfile: Identifiable, Codable {
    let id: Int64
    let username: String
    var nickname: String
    var avatar: String
    let status: Int
    let isAdmin: Bool
    var isFriend: Bool?
    var isFollowing: Bool?
    let createdOn: Int64?
    var follows: Int?      // ✅ FIXED: Made optional for search API
    var followings: Int?   // ✅ FIXED: Made optional for search API
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




// Category model
struct Category: Identifiable, Codable, Hashable {
    let id: Int64
    let name: String
    let description: String
    let icon: String
    let color: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, color
    }
    
    // Static categories optimized for trending content
    static let staticCategories: [Category] = [
        // ENTERTAINMENT & VIRAL (High trending potential)
        Category(id: 1, name: "Comedy", description: "Funny and entertaining content", icon: "😂", color: "#FFEAA7"),
        Category(id: 2, name: "Music", description: "Music and audio content", icon: "🎵", color: "#FF6B6B"),
        Category(id: 3, name: "Movies", description: "Movie reviews and discussions", icon: "🎬", color: "#6C5CE7"),
        Category(id: 4, name: "TV Shows", description: "TV show content and discussions", icon: "📺", color: "#A29BFE"),
        Category(id: 5, name: "Gaming", description: "Video games and gaming content", icon: "🎮", color: "#4ECDC4"),
        Category(id: 6, name: "Viral", description: "Viral content and memes", icon: "🔥", color: "#FF4757"),
        Category(id: 7, name: "Celebrities", description: "Celebrity news and gossip", icon: "⭐", color: "#FFA502"),
        
        // NEWS & CURRENT EVENTS (Always trending)
        Category(id: 8, name: "News", description: "Current events and breaking news", icon: "📰", color: "#2D3436"),
        Category(id: 9, name: "Politics", description: "Political discussions and content", icon: "🗳️", color: "#636E72"),
        Category(id: 10, name: "Weather", description: "Weather events and natural disasters", icon: "🌦️", color: "#74B9FF"),
        
        // TECHNOLOGY & INNOVATION (High trending)
        Category(id: 11, name: "Technology", description: "Tech news and product launches", icon: "💻", color: "#45B7D1"),
        Category(id: 12, name: "AI", description: "Artificial intelligence and automation", icon: "🤖", color: "#6C5CE7"),
        Category(id: 13, name: "Social Media", description: "Platform updates and influencer content", icon: "📱", color: "#FF6B9D"),
        
        // FINANCE & CRYPTO (Market trending)
        Category(id: 14, name: "Finance", description: "Market news and financial advice", icon: "💰", color: "#00CEC9"),
        Category(id: 15, name: "Crypto", description: "Cryptocurrency and blockchain", icon: "₿", color: "#F39C12"),
        
        // SPORTS & EVENTS (Regular trending)
        Category(id: 16, name: "Sports", description: "Sports events and athlete news", icon: "⚽", color: "#96CEB4"),
        Category(id: 17, name: "Esports", description: "Competitive gaming and tournaments", icon: "🏆", color: "#4ECDC4"),
        
        // LIFESTYLE & CULTURE (Trending topics)
        Category(id: 18, name: "Fashion", description: "Fashion trends and style", icon: "👗", color: "#A29BFE"),
        Category(id: 19, name: "Beauty", description: "Beauty trends and tutorials", icon: "💄", color: "#FF69B4"),
        Category(id: 20, name: "Food", description: "Food trends and viral recipes", icon: "🍕", color: "#FF8C42"),
        Category(id: 21, name: "Travel", description: "Travel destinations and experiences", icon: "✈️", color: "#74B9FF"),
        
        // CREATIVE & ARTS (Trending content)
        Category(id: 22, name: "Creative Arts", description: "Art, photography, and design", icon: "🎨", color: "#E84393"),
        Category(id: 23, name: "Dance", description: "Dance trends and performances", icon: "💃", color: "#FF6B9D"),
        Category(id: 24, name: "Music Production", description: "Music creation and production", icon: "🎧", color: "#FF6B6B"),
        
        // HEALTH & FITNESS (Popular topics)
        Category(id: 25, name: "Health & Wellness", description: "Health trends and wellness tips", icon: "🏥", color: "#E17055"),
        Category(id: 26, name: "Fitness", description: "Workout trends and fitness content", icon: "💪", color: "#00B894"),
        
        // BUSINESS & CAREER (Professional trending)
        Category(id: 27, name: "Business", description: "Business news and entrepreneurship", icon: "💼", color: "#00B894"),
        Category(id: 28, name: "Career", description: "Career advice and job market trends", icon: "📈", color: "#2D3436"),
        
        // SCIENCE & EDUCATION (Knowledge trending)
        Category(id: 29, name: "Science", description: "Scientific discoveries and breakthroughs", icon: "🔬", color: "#6C5CE7"),
        Category(id: 30, name: "Learning", description: "Educational content and tutorials", icon: "📚", color: "#DDA0DD"),
        
        // LIFESTYLE & PERSONAL (Relatable content)
        Category(id: 31, name: "Relationships", description: "Dating and relationship advice", icon: "💕", color: "#FD79A8"),
        Category(id: 32, name: "Family", description: "Parenting and family content", icon: "👨‍👩‍👧‍👦", color: "#FF7675"),
        Category(id: 33, name: "Pets", description: "Pet videos and animal content", icon: "🐕", color: "#FDCB6E"),
        
        // AUTOMOTIVE & TRANSPORTATION (Enthusiast content)
        Category(id: 34, name: "Automotive", description: "Car reviews and automotive news", icon: "🚗", color: "#E17055"),
        
        // ENVIRONMENT & SUSTAINABILITY (Growing trend)
        Category(id: 35, name: "Environment", description: "Climate change and sustainability", icon: "🌍", color: "#00B894")
    ]
}

// Category list response
struct CategoryListResponse: Codable {
    let code: Int
    let msg: String
    let data: CategoryListData
    
    struct CategoryListData: Codable {
        let categories: [Category]
    }
}


// Response struct for set user categories
struct SetUserCategoriesResponse: Codable {
    let code: Int
    let msg: String
    let data: SetUserCategoriesData?
    
    struct SetUserCategoriesData: Codable {
        let success: Bool
    }
}


// ... existing code ...

// Response for followers/followings with pagination
struct FollowListResponse: Codable {
    let code: Int
    let msg: String
    let data: FollowListData?
    
    struct FollowListData: Codable {
        let list: [FollowUser]
        let pager: FollowPagerInfo  // ✅ FIXED: Renamed to avoid conflict
    }
}

// Individual follow user data
struct FollowUser: Codable, Identifiable  {
    let userId: Int64
    let username: String
    let nickname: String
    let avatar: String
    let phone: String?
    let isFollowing: Bool
    let createdOn: Int64

    // ✅ ADDED: id property for Identifiable conformance
    var id: Int64 { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username, nickname, avatar, phone
        case isFollowing = "is_following"
        case createdOn = "created_on"
    }
}

// ✅ FIXED: Renamed to avoid conflict with existing PagerInfo
struct FollowPagerInfo: Codable {
    let page: Int
    let pageSize: Int
    let totalRows: Int64
    
    enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case totalRows = "total_rows"
    }
}

// ... existing code ...







@MainActor
final class TweetData: ObservableObject {
    static let shared = TweetData()
    
    // ✅ OPTIMIZED: Cached Dictionary for O(1) reaction type lookups
    static let staticReactionsDict: [Int64: ReactionType] = Dictionary(uniqueKeysWithValues: ReactionType.staticReactions.map { ($0.id, $0) })
    
    // ✅ OPTIMIZED: Cached Dictionary for O(1) category lookups
    static let staticCategoriesDict: [Int64: Category] = Dictionary(uniqueKeysWithValues: Category.staticCategories.map { ($0.id, $0) })

    @Published var user: UserProfile? {
        didSet {
            if let user = user {
                  // Notify observers about user profile change
                  NotificationCenter.default.post(
                      name: Foundation.Notification.Name.userProfileDidUpdate,
                      object: nil,
                      userInfo: ["user": user]
                  )
            }
        }
    }

    @Published var allCategories: [Category] = []
    @Published var isLoadingCategories: Bool = false
    


    // MARK: - Reaction Users State (Separate from UserProfile)
    @Published var currentUserReactionState: ReactionUsersPaginationState = ReactionUsersPaginationState()
    @Published var otherUsersReactionState: [Int64: ReactionUsersPaginationState] = [:]
    


    
    // MARK: - Reactions Feed State
    @Published var reactionsFeed: ReactionsFeedState = ReactionsFeedState()
    @Published var isLoadingReactions = false
    @Published var isLoadingMoreReactions = false
    @Published var lastViewedReactionIndex: Int = 0
    @Published var lastViewedReactionPage: Int = 1
    @Published var currentPageReactions = 0
    @Published var hasMoreDataReactions = true
    @Published var loadedPagesReactions: Set<Int> = Set<Int>()
    
    var reactionLoadRetryCount = 0
    let reactionMaxRetries = 3
    let reactionPageSize: Int = 20





    @Published var tweets: [TweetModel] = []
    @Published var otherUsers: [Int64: UserProfile] = [:]
    @Published var isAuthenticated: Bool = false
    @Published var appInfo: AppInfo?
    @Published var merchant: MerchantInfo?
    @Published var isFollowLoading: Bool = false
    @Published var tempToken: String?
    
    

    private let userDefaults = UserDefaults.standard
    private let userDataKey = "persistedUserData"
    private let otherUsersKey = "persistedOtherUsers"
    private let categoriesKey = "cachedCategories"
    private let categoriesUpdateKey = "categoriesLastUpdate"
     private var lastProfileFetch: [Int64: Date] = [:]
    private let profileFetchDebounce: TimeInterval = 300 // 5 minutes for other users
    
    // ✅ OPTIMIZED: Cached username lookup dictionary for O(1) access
    private var usernameToUserIdCache: [String: Int64] = [:]
    
    // ✅ OPTIMIZED: Cached category dictionary for O(1) access
    private var categoriesDict: [Int64: Category] = [:]
    
    // ✅ ADDED: Cached user indices for reaction state O(1) lookups
    @Published var reactionUserIndices: [Int64: (currentUserIndices: [Int64: Int], otherUserIndices: [Int64: [Int64: Int]])] = [:]
    



// Get users that a specific user follows (paginated)
func getUserFollows(username: String, page: Int = 1, pageSize: Int = 20) async throws -> (users: [FollowUser], total: Int64) {
    guard let token = try KeychainManager.shared.getToken() else {
        throw AuthError.notAuthenticated
    }
    
    print("[API] Getting users that '\(username)' follows, page: \(page), pageSize: \(pageSize)")
    
    let url = URL(string: "\(AuthConfig.baseURL)\(AuthConfig.Endpoints.userFollows)")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    // Add query parameters
    var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    urlComponents.queryItems = [
        URLQueryItem(name: "username", value: username),
        URLQueryItem(name: "page", value: "\(page)"),
        URLQueryItem(name: "page_size", value: "\(pageSize)")
    ]
    request.url = urlComponents.url
    
    print("�� Making request to: \(urlComponents.url?.absoluteString ?? "")")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw AuthError.networkError("Invalid response")
    }
    
    guard httpResponse.statusCode == 200 else {
        throw AuthError.networkError("Get follows failed: \(httpResponse.statusCode)")
    }
    
    print("📥 Received follows response")
    if let jsonString = String(data: data, encoding: .utf8) {
        print("📝 Response JSON: \(jsonString)")
    }
    
    let followResponse = try JSONDecoder().decode(FollowListResponse.self, from: data)
    
    guard followResponse.code == 0 else {
        throw AuthError.networkError(followResponse.msg)
    }
    
    guard let followData = followResponse.data else {
        throw AuthError.networkError("No follow data in response")
    }
    
    print("✅ Successfully decoded follows: \(followData.list.count) users, total: \(followData.pager.totalRows)")
    
     await MainActor.run {
            if let currentUser = self.user, currentUser.username == username {
                // Update current user
                var updatedUser = currentUser
                updatedUser.followings = Int(followData.pager.totalRows)
                self.user = updatedUser
                self.persistUserData(updatedUser)
                print("✅ [SYNC] Updated current user following count: \(followData.pager.totalRows)")
            } else if let otherUser = self.otherUsers.values.first(where: { $0.username == username }) {
                // Update other user
                var updatedUser = otherUser
                updatedUser.followings = Int(followData.pager.totalRows)
                self.otherUsers[updatedUser.id] = updatedUser
                print("✅ [SYNC] Updated other user following count: \(followData.pager.totalRows)")
            }
        }

    return (users: followData.list, total: followData.pager.totalRows)
}

// Get users who follow a specific user (paginated)
func getUserFollowings(username: String, page: Int = 1, pageSize: Int = 20) async throws -> (users: [FollowUser], total: Int64) {
    guard let token = try KeychainManager.shared.getToken() else {
        throw AuthError.notAuthenticated
    }
    
    print("[API] Getting users who follow '\(username)', page: \(page), pageSize: \(pageSize)")
    
    let url = URL(string: "\(AuthConfig.baseURL)\(AuthConfig.Endpoints.userFollowings)")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    // Add query parameters
    var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    urlComponents.queryItems = [
        URLQueryItem(name: "username", value: username),
        URLQueryItem(name: "page", value: "\(page)"),
        URLQueryItem(name: "page_size", value: "\(pageSize)")
    ]
    request.url = urlComponents.url
    
    print("�� Making request to: \(urlComponents.url?.absoluteString ?? "")")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw AuthError.networkError("Invalid response")
    }
    
    guard httpResponse.statusCode == 200 else {
        throw AuthError.networkError("Get followings failed: \(httpResponse.statusCode)")
    }
    
    print("📥 Received followings response")
    if let jsonString = String(data: data, encoding: .utf8) {
        print("📝 Response JSON: \(jsonString)")
    }
    
    let followingResponse = try JSONDecoder().decode(FollowListResponse.self, from: data)
    
    guard followingResponse.code == 0 else {
        throw AuthError.networkError(followingResponse.msg)
    }
    
    guard let followingData = followingResponse.data else {
        throw AuthError.networkError("No following data in response")
    }
    
    print("✅ Successfully decoded followings: \(followingData.list.count) users, total: \(followingData.pager.totalRows)")
    
      await MainActor.run {
            if let currentUser = self.user, currentUser.username == username {
                // Update current user
                var updatedUser = currentUser
                updatedUser.follows = Int(followingData.pager.totalRows)
                self.user = updatedUser
                self.persistUserData(updatedUser)
                print("✅ [SYNC] Updated current user followers count: \(followingData.pager.totalRows)")
            } else if let otherUser = self.otherUsers.values.first(where: { $0.username == username }) {
                // Update other user
                var updatedUser = otherUser
                updatedUser.follows = Int(followingData.pager.totalRows)
                self.otherUsers[updatedUser.id] = updatedUser
                print("✅ [SYNC] Updated other user followers count: \(followingData.pager.totalRows)")
            }
        }

    return (users: followingData.list, total: followingData.pager.totalRows)
}


func setUserCategories(categoryIDs: [Int64]) async throws {
    guard let token = try KeychainManager.shared.getToken() else {
        throw AuthError.unauthorized("No authentication token found")
    }
    
    guard let user = self.user else {
        throw AuthError.notAuthenticated
    }
    
    // Store original categories for potential rollback
    let originalCategories = user.categories
    
    // OPTIMISTIC UPDATE: Update UI immediately
    await MainActor.run {
        if var updatedUser = self.user {
            updatedUser.categories = categoryIDs
            self.user = updatedUser
            self.persistUserData(updatedUser)
            print("✅ Optimistic update: User categories updated immediately")
        }
    }
    
    let url = URL(string: "\(AuthConfig.baseURL)\(AuthConfig.Endpoints.categories)")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Remove uid from request body - backend gets it from token
    let requestBody = [
        "category_ids": categoryIDs
    ] as [String: Any]
    
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    
    print("📤 Setting user categories for user: \(user.id)")
    print("📋 Categories: \(categoryIDs)")
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        print("📥 Received response")
        print("📊 HTTP Status Code: \(httpResponse.statusCode)")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📝 Response JSON: \(jsonString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            // Try to decode error response for better error message
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = errorResponse["msg"] as? String {
                throw AuthError.networkError("Failed to set categories (\(httpResponse.statusCode)): \(errorMsg)")
            } else {
                throw AuthError.networkError("Failed to set categories: \(httpResponse.statusCode)")
            }
        }
        
        let setCategoriesResponse = try JSONDecoder().decode(SetUserCategoriesResponse.self, from: data)
        guard setCategoriesResponse.code == 0 else {
            throw AuthError.networkError(setCategoriesResponse.msg)
        }
        
        // SUCCESS: Keep the optimistic update, no need to update again
        print("✅ Successfully set user categories, keeping optimistic update")
        
    } catch {
        print("❌ Error setting user categories: \(error)")
        
        // REVERT OPTIMISTIC UPDATE: Restore original state on failure
        await MainActor.run {
            if var updatedUser = self.user {
                updatedUser.categories = originalCategories
                self.user = updatedUser
                self.persistUserData(updatedUser)
                print("🔄 Reverted optimistic update due to API failure")
            }
        }
        
        throw AuthError.networkError("Failed to set user categories: \(error.localizedDescription)")
    }
}

    // This method checks if enough time has passed since the last fetch for a given userId
    func shouldFetchProfile(userId: Int64) -> Bool {
        if userId == 0 { return true } // Always fetch if we don't have a user yet
        
        // For current user: Always use cached data
        if userId == self.user?.id {
            print("[Cache] Using cached data for current user: \(userId)")
                return false
            }
        
        // For other users: Use 5-minute cache
        let now = Date()
        if let lastTime = lastProfileFetch[userId], now.timeIntervalSince(lastTime) < profileFetchDebounce {
            print("[Cache] Using cached data for other user: \(userId) (last fetch: \(Int(now.timeIntervalSince(lastTime))) seconds ago)")
            return false
        }
        print("[Cache] Cache expired for other user: \(userId), fetching fresh data")
        lastProfileFetch[userId] = now
        return true
    }
    
    // Force refresh current user profile (bypasses cache)
    func forceRefreshCurrentUserProfile(forceRefresh: Bool = true) async throws -> UserProfile {
        print("[Cache] Force refreshing current user profile with forceRefresh: \(forceRefresh)")
        
        // Clear the last fetch time to force a fresh API call
        if let userId = self.user?.id {
            lastProfileFetch.removeValue(forKey: userId)
            print("[Cache] Cleared cache for current user: \(userId)")
        }
        
        return try await getUserProfile(forceRefresh: forceRefresh)
    }
    
    // Check if we have cached profile data for current user
    var hasCachedCurrentUserProfile: Bool {
        return self.user != nil
    }
    
    // Get cached profile data for current user (if available)
    func getCachedCurrentUserProfile() -> UserProfile? {
        return self.user
    }
    // Add computed property for auth validation
    var hasValidAuth: Bool {
        do {
            if let token = try KeychainManager.shared.getToken(),
               let username = try KeychainManager.shared.getUsername(),
               user != nil {
                return true
            }
        } catch {
            print("❌ Error checking auth state: \(error)")
        }
        return false
    }

    // ✅ REMOVED: Persistent storage for other users - use state-only approach
    // Other users are now stored only in memory during the session
    // This prevents stale data and reduces storage bloat

    init() {
        restoreUserData()
        // ✅ FIXED: Remove persistent storage for other users - use state-only
        
        // ✅ OPTIMIZED: Initialize caches for O(1) lookups
        initializeCaches()
        
        // ✅ MINIMAL: Listen for profile refresh notifications
        print("🔔 [TweetData] Setting up observer for RefreshCurrentUserProfile notification")
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshCurrentUserProfile"),
            object: nil,
            queue: .main
        ) { _ in
            print("🔔 [TweetData] Notification received in observer closure")
            Task {
                await self.handleProfileRefreshNotification(forceRefresh: true)
            }
        }
        print("✅ [TweetData] Observer setup complete for RefreshCurrentUserProfile")
        
        // ✅ ADDED: Listen for space host status changes from SpacesViewModel
        NotificationCenter.default.addObserver(
            forName: Notification.Name("SpaceHostStatusChanged"),
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                await self.handleSpaceHostStatusChange(notification)
            }
        }
        
        // ✅ FIXED: Background sync on app start
        Task {
            await self.backgroundSyncProfileOnStart()
        }
        
      
    }
    
    // ✅ OPTIMIZED: Initialize all caches for O(1) lookups
    private func initializeCaches() {
        
        // Initialize categories dictionary with static categories
        categoriesDict = TweetData.staticCategoriesDict
        
        // Initialize username cache from existing otherUsers
        usernameToUserIdCache = Dictionary(uniqueKeysWithValues: otherUsers.values.map { ($0.username, $0.id) })
        
        // ✅ ADDED: Initialize reaction user indices cache
        updateReactionUserIndicesCache()
        
        print("✅ Initialized caches for O(1) lookups")
    }
    
    // ✅ ADDED: Update reaction user indices cache for O(1) lookups
     func updateReactionUserIndicesCache() {
        reactionUserIndices.removeAll()
        
        // Build indices for all users in reaction state
        let allUserIds = Set(currentUserReactionState.reactionTypes.values.flatMap { $0.users.map { $0.id } } +
                           otherUsersReactionState.values.flatMap { $0.reactionTypes.values.flatMap { $0.users.map { $0.id } } })
        
        for userId in allUserIds {
            let indices = buildUserIndicesInReactionState(userId: userId)
            reactionUserIndices[userId] = indices
        }
        
        print("✅ Updated reaction user indices cache for \(allUserIds.count) users")
    }
    
    // ✅ ADDED: Build user indices for a specific user
     func buildUserIndicesInReactionState(userId: Int64) -> (currentUserIndices: [Int64: Int], otherUserIndices: [Int64: [Int64: Int]]) {
        var currentUserIndices: [Int64: Int] = [:]
        var otherUserIndices: [Int64: [Int64: Int]] = [:]
        
        // Build user index cache for current user reaction state
        for (reactionTypeId, paginationData) in currentUserReactionState.reactionTypes {
            if let userIndex = paginationData.users.firstIndex(where: { $0.id == userId }) {
                currentUserIndices[reactionTypeId] = userIndex
            }
        }
        
        // Build user index cache for other users reaction state
        for (otherUserId, reactionState) in otherUsersReactionState {
            var userIndices: [Int64: Int] = [:]
            for (reactionTypeId, paginationData) in reactionState.reactionTypes {
                if let userIndex = paginationData.users.firstIndex(where: { $0.id == userId }) {
                    userIndices[reactionTypeId] = userIndex
                }
            }
            if !userIndices.isEmpty {
                otherUserIndices[otherUserId] = userIndices
            }
        }
        
        return (currentUserIndices, otherUserIndices)
    }
    
    // Handle profile refresh notification
    func handleProfileRefreshNotification(forceRefresh: Bool = true) async {
        print("👤 [NOTIFICATION] Received RefreshCurrentUserProfile notification with forceRefresh: \(forceRefresh)")
        
        do {
            print("🔄 [BACKGROUND] Refreshing current user profile...")
            let updatedProfile = try await self.forceRefreshCurrentUserProfile(forceRefresh: forceRefresh)
            print("✅ [BACKGROUND] Profile refreshed successfully:")
            print("  - User ID: \(updatedProfile.id)")
            print("  - Username: \(updatedProfile.username)")
            print("  - Followers: \(updatedProfile.follows ?? 0)")
            print("  - Following: \(updatedProfile.followings ?? 0)")
        } catch {
            print("❌ [BACKGROUND] Failed to refresh profile: \(error)")
        }
    }
    
    // ✅ ADDED: Handle space host status changes from SpacesViewModel
    @MainActor
    private func handleSpaceHostStatusChange(_ notification: Foundation.Notification) async {
        guard let hostId = notification.userInfo?["hostId"] as? Int64,
              let isOnline = notification.userInfo?["isOnline"] as? Bool else { return }
        
        print("\n🔄 [TweetData] Received space host status change notification")
        print("👤 Host ID: \(hostId)")
        print("📊 Online Status: \(isOnline)")
        
        // Only update if we already have this user's profile
        if let existingProfile = otherUsers[hostId] {
            // Check if online status actually changed
            if existingProfile.isOnline != isOnline {
                print("🔄 Updating existing profile for host \(hostId) - Online: \(isOnline)")
                
                // Create updated profile with new online status
                let updatedProfile = UserProfile(
                    id: existingProfile.id,
                    nickname: existingProfile.nickname,
                    username: existingProfile.username,
                    avatar: existingProfile.avatar,
                    isFollowing: existingProfile.isFollowing ?? false,
                    status: existingProfile.status,
                    isAdmin: existingProfile.isAdmin,
                    isFriend: existingProfile.isFriend ?? false,
                    follows: existingProfile.follows ?? 0,
                    followings: existingProfile.followings ?? 0,
                    tweetsCount: existingProfile.tweetsCount ?? 0,
                    createdOn: existingProfile.createdOn,
                    categories: existingProfile.categories,
                    reactionCounts: existingProfile.reactionCounts,
                    isOnline: isOnline, // ✅ Updated online status
                    phone: existingProfile.phone,
                    activation: existingProfile.activation,
                    balance: existingProfile.balance
                )
                
                otherUsers[hostId] = updatedProfile
                print("✅ Successfully updated user \(hostId) online status to: \(isOnline)")
            } else {
                print("✅ Host \(hostId) online status unchanged - Online: \(isOnline)")
            }
        } else {
            // Skip creating new profiles - only update existing ones
            print("⏭️ Skipping host \(hostId) - No existing profile found")
        }
    }
    
    // Background sync profile on app start (compare persistent vs API)
    private func backgroundSyncProfileOnStart() async {
        print("🔄 [BACKGROUND] Starting background profile sync...")
        
        // Only sync if we have persistent data
        guard let currentUser = self.user else {
            print("📱 [BACKGROUND] No persistent data found, skipping background sync")
            return
        }
        
        do {
            print("🌐 [BACKGROUND] Fetching fresh profile data from API...")
            let freshProfile = try await self.fetchProfileFromAPI()
            
            // Compare persistent data with fresh API data
            let hasChanges = self.hasProfileChanges(current: currentUser, fresh: freshProfile)
            
            if hasChanges {
                print("🔄 [BACKGROUND] Profile changes detected, updating...")
                print("  - Old followers: \(currentUser.follows ?? 0)")
                print("  - New followers: \(freshProfile.follows ?? 0)")
                print("  - Old following: \(currentUser.followings ?? 0)")
                print("  - New following: \(freshProfile.followings ?? 0)")
                
                await MainActor.run {
                    self.user = freshProfile
                    self.persistUserData(freshProfile)
                    print("✅ [BACKGROUND] Profile updated with fresh data")
                }
                
                // ✅ ADDED: Sync with spaces if this user is a host (using existing method)
                if let isOnline = freshProfile.isOnline {
                    await self.syncUserStatusWithSpacesDirect(userId: freshProfile.id, isOnline: isOnline)
                }
            } else {
                print("✅ [BACKGROUND] Profile data is up to date")
            }
            
        } catch {
            print("❌ [BACKGROUND] Background sync failed: \(error)")
            // Don't throw - this is background sync, shouldn't affect UI
        }
    }
    
    // Fetch profile from API without using cache logic
    private func fetchProfileFromAPI() async throws -> UserProfile {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.notAuthenticated
        }
        
        guard let username = try KeychainManager.shared.getUsername() else {
            throw AuthError.notAuthenticated
        }
        
        let url = URL(string: "\(AuthConfig.baseURL)/v1/user/profile")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let urlWithParams = url.appending(queryItems: [URLQueryItem(name: "username", value: username)])
        request.url = urlWithParams
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Profile fetch failed: \(httpResponse.statusCode)")
        }
        
        let profileResponse = try JSONDecoder().decode(UserProfileResponse.self, from: data)
        
        guard profileResponse.code == 0 else {
            throw AuthError.networkError(profileResponse.msg)
        }
        
        guard let profileData = profileResponse.data else {
            throw AuthError.networkError("No profile data in response")
        }
        
        return UserProfile(
            id: profileData.id,
            nickname: profileData.nickname,
            username: profileData.username,
            avatar: profileData.avatar,
            isFollowing: profileData.isFollowing,
            status: profileData.status,
            isAdmin: profileData.isAdmin,
            isFriend: profileData.isFriend,
            follows: profileData.follows,
            followings: profileData.followings,
            tweetsCount: profileData.tweetsCount,
            createdOn: profileData.createdOn,
            categories: profileData.categories,
            reactionCounts: profileData.reactionCounts?.reduce(into: [Int64: Int]()) { result, element in
                if let int64Key = Int64(element.key) {
                    result[int64Key] = element.value
                }
            }, // Convert [String: Int] to [Int64: Int]
            isOnline: profileData.isOnline, // ✅ ADDED: Include online status from API response
            phone: profileData.phone,
            activation: profileData.activation,
            balance: profileData.balance
        )
    }
    
    // Compare current profile with fresh API data
    private func hasProfileChanges(current: UserProfile, fresh: UserProfile) -> Bool {
        // Check key fields that might change frequently
        let changes = [
            current.follows != fresh.follows,
            current.followings != fresh.followings,
            current.tweetsCount != fresh.tweetsCount,
            current.nickname != fresh.nickname,
            current.avatar != fresh.avatar,
            current.status != fresh.status,
            current.categories != fresh.categories,
            current.reactionCounts != fresh.reactionCounts // NEW
        ]
        
        let hasChanges = changes.contains(true)
        
        if hasChanges {
            print("🔄 [BACKGROUND] Changes detected:")
            if current.follows != fresh.follows {
                print("  - Followers: \(current.follows ?? 0) → \(fresh.follows ?? 0)")
            }
            if current.followings != fresh.followings {
                print("  - Following: \(current.followings ?? 0) → \(fresh.followings ?? 0)")
            }
            if current.tweetsCount != fresh.tweetsCount {
                print("  - Tweets: \(current.tweetsCount ?? 0) → \(fresh.tweetsCount ?? 0)")
            }
            if current.nickname != fresh.nickname {
                print("  - Nickname: \(current.nickname) → \(fresh.nickname)")
            }
        }
        
        return hasChanges
    }
    
    // Cleanup observer when TweetData is deallocated
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Location Methods
    
  

     func persistUserData(_ user: UserProfile) {
        if let encoded = try? JSONEncoder().encode(user) {
            userDefaults.set(encoded, forKey: userDataKey)
        }
    }

    private func restoreUserData() {
        if let savedData = userDefaults.data(forKey: userDataKey),
           let decodedUser = try? JSONDecoder().decode(UserProfile.self, from: savedData) {
            self.user = decodedUser
            self.isAuthenticated = true
        }
    }

    private func clearPersistedUserData() {
        userDefaults.removeObject(forKey: userDataKey)
    }

    var hasValidToken: Bool {
        get {
            do {
                if let token = try KeychainManager.shared.getToken() {
                    // If we have a token but no user data, try to restore it
                    if self.user == nil {
                        restoreUserData()
                    }
                    if !self.isAuthenticated {
                        self.isAuthenticated = true
                    }
                    return true
                }
            } catch {
                print("❌ Error checking token: \(error)")
            }
            if self.isAuthenticated {
                self.isAuthenticated = false
            }
            return false
        }
    }

    // Update checkPersistentAuthentication to handle both token and user data
    func checkPersistentAuthentication() async {
        print("\n🔄 Checking persistent authentication...")
        
        do {
            // Check for token and username in keychain
            if let token = try KeychainManager.shared.getToken(),
               let username = try KeychainManager.shared.getUsername() {
                print("✅ Found stored credentials:")
                print("- Username: \(username)")
                print("- Token: \(token)")
                
                // ✅ FIXED: Use persistent data immediately, background sync will update if needed
                if self.user == nil {
                    print("🔄 No user data found, fetching profile...")
                    let profile = try await getUserProfile()
                    
                    await MainActor.run {
                        print("✅ User profile fetched successfully")
                        self.user = profile
                        self.isAuthenticated = true
                        self.persistUserData(profile)
                    }
                } else {
                    print("✅ Using persistent data immediately (background sync will check for updates)")
                    await MainActor.run {
                        self.isAuthenticated = true
                    }
                }
            } else {
                print("❌ No stored credentials found")
                await MainActor.run {
                    self.user = nil
                    self.isAuthenticated = false
                    self.clearPersistedUserData()
                }
            }
        } catch {
            print("❌ Error checking persistent authentication: \(error)")
            await MainActor.run {
                self.user = nil
                self.isAuthenticated = false
                self.clearPersistedUserData()
            }
        }
        
        // Log final auth state
        print("📱 Final auth state:")
        print("- hasValidAuth: \(self.hasValidAuth)")
        print("- isAuthenticated: \(self.isAuthenticated)")
        print("- User exists: \(self.user != nil)")
        
        // ✅ ADDED: Post notification when authentication is complete
        if self.isAuthenticated && self.user != nil {
            print("🔔 [AUTH] Posting authentication complete notification")
            NotificationCenter.default.post(
                name: Notification.Name("UserAuthenticationComplete"),
                object: nil,
                userInfo: [
                    "userId": self.user!.id,
                    "username": self.user!.username
                ]
            )
        }
    }

    // Update login to persist user data
    private func login(username: String, password: String) async throws -> LoginResponse {
        let url = URL(string: "\(AuthConfig.baseURL)/v1/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "username": username,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        print("📤 Sending login request for username: \(username)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("📥 Received response")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📝 Response JSON: \(jsonString)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.loginFailed("Login failed: \(httpResponse.statusCode)")
        }
        
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        guard loginResponse.code == 0 else {
            throw AuthError.loginFailed(loginResponse.msg)
        }
        
        guard let loginData = loginResponse.data else {
            throw AuthError.loginFailed("No data in response")
        }
        
        // 🔑 TOKEN LOGGING - Print full token for debugging
        print("🔑 TOKEN RECEIVED:")
        print("🔑 Full Token: \(loginData.token)")
        print("🔑 Token Length: \(loginData.token.count) characters")
        print("🔑 Token Prefix: \(loginData.token.prefix(20))...")
        print("🔑 Token Suffix: ...\(loginData.token.suffix(20))")
        
        // Save token and username to keychain
        try KeychainManager.shared.saveToken(loginData.token)
        try KeychainManager.shared.saveUsername(username)
        
        print("💾 Token and username saved to keychain")
        
        // After successful login and getting user profile
        let userProfile = try await getUserProfile()
        
        // ✅ FIXED: Save userProfile to persistent storage first
        await MainActor.run {
            self.user = userProfile
            self.isAuthenticated = true
            self.persistUserData(userProfile)
            
            // ✅ ALSO SAVE: Save userId to "currentUserId" for AblyService fallback
            UserDefaults.standard.set(String(userProfile.id), forKey: "currentUserId")
            
            print("💾 User profile saved to persistent storage")
            print("💾 User ID saved to currentUserId: \(userProfile.id)")
        }
        
        // ✅ DIRECT: Pass userId directly to AblyService (no timing issues)
        AblyService.shared.initialize(userId: userProfile.id)
        print("✅ Ably client initialized for logged in user: \(userProfile.username) with ID: \(userProfile.id)")
        
        return loginResponse
    }

    // Update logout to clear persisted data
    func logout() async {
        do {
            // Disconnect Ably client on logout
            // Note: AblyService doesn't have a disconnect method, it handles cleanup automatically
            
            try KeychainManager.shared.deleteToken()
            try KeychainManager.shared.deleteUsername()
            
            // ✅ ALSO CLEAR: Clear currentUserId for AblyService
            UserDefaults.standard.removeObject(forKey: "currentUserId")
            
            await MainActor.run {
                self.user = nil
                self.isAuthenticated = false
                self.clearPersistedUserData()
                
                // ✅ CLEAR SPACES: Clear user's own space from SpacesViewModel
                SpacesViewModel.shared.clearUserOwnSpace()
                print("🧹 [LOGOUT] User's own space cleared from persistent storage")
            }
        } catch {
            print("❌ Error during logout: \(error)")
        }
    }

    // Add method to update authentication state
    func updateAuthenticationState() {
        if let _ = try? KeychainManager.shared.getToken() {
            self.isAuthenticated = true
        } else {
            self.isAuthenticated = false
        }
    }

    // Follow a user


    // Response type for paginated user list
    struct UserListResponse: Codable {
        let code: Int
        let msg: String
        let data: UserListData
    }

    struct UserListData: Codable {
        let contacts: [UserProfile]
        let total: Int64
    }


    // Fetch user online status from API
func fetchUserOnlineStatus(userId: Int64) async throws -> Bool {
    guard let token = try KeychainManager.shared.getToken() else {
        throw AuthError.notAuthenticated
    }
    
    let url = URL(string: "\(AuthConfig.baseURL)\(AuthConfig.Endpoints.userOnlineStatus)")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    // Add user_id as query parameter
    let urlWithParams = url.appending(queryItems: [URLQueryItem(name: "user_id", value: "\(userId)")])
    request.url = urlWithParams
    
    print("🌐 [fetchUserOnlineStatus] Making request to: \(urlWithParams)")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw AuthError.networkError("Invalid response")
    }
    
    print("📊 [fetchUserOnlineStatus] HTTP Status Code: \(httpResponse.statusCode)")
    
    guard httpResponse.statusCode == 200 else {
        throw AuthError.networkError("User online status fetch failed: \(httpResponse.statusCode)")
    }
    
    let statusResponse = try JSONDecoder().decode(UserOnlineStatusResponse.self, from: data)
    
    guard statusResponse.code == 0 else {
        throw AuthError.networkError(statusResponse.msg)
    }
    
    guard let statusData = statusResponse.data else {
        throw AuthError.networkError("No status data in response")
    }
    
    print("✅ [fetchUserOnlineStatus] User \(userId) online status: \(statusData.isOnline)")
    
    // ✅ UPDATE OTHER USERS STATE: If user profile already exists, update their online status
    await updateExistingUserOnlineStatus(userId: userId, isOnline: statusData.isOnline ?? false)
    
    // ✅ SYNC WITH SPACES STATE: Use NotificationCenter to prevent circular dependencies
    await syncUserStatusWithSpacesDirect(userId: userId, isOnline: statusData.isOnline ?? false)
    
    return statusData.isOnline ?? false
}

// MARK: - Direct State Updates (Same Pattern as SpacesPaginationManager)

/// Sync user online status with spaces state using NotificationCenter
/// This prevents circular dependencies by using decoupled communication
@MainActor
 func syncUserStatusWithSpacesDirect(userId: Int64, isOnline: Bool) async {
    print("\n🔄 [syncUserStatusWithSpacesDirect] Syncing user \(userId) online status with spaces")
    print("📊 User online status: \(isOnline)")
    
    // ✅ FIXED: Use NotificationCenter to prevent circular dependency
    // This is the clean architecture solution - decoupled communication
    NotificationCenter.default.post(
        name: Notification.Name("UserOnlineStatusChanged"),
        object: nil,
        userInfo: [
            "userId": userId,
            "isOnline": isOnline
        ]
    )
    
    print("✅ [syncUserStatusWithSpacesDirect] Posted notification for user \(userId)")
}

/// Sync user follow status with spaces state using NotificationCenter
/// This prevents circular dependencies by using decoupled communication
@MainActor
private func syncUserFollowStatusWithSpacesDirect(userId: Int64, isFollowing: Bool) async {
    print("\n🔄 [syncUserFollowStatusWithSpacesDirect] Syncing user \(userId) follow status with spaces")
    print("📊 User follow status: \(isFollowing)")
    
    // ✅ FIXED: Use NotificationCenter to prevent circular dependency
    // This is the clean architecture solution - decoupled communication
    NotificationCenter.default.post(
        name: Notification.Name("UserFollowStatusChanged"),
        object: nil,
        userInfo: [
            "userId": userId,
            "isFollowing": isFollowing
        ]
    )
    
    print("✅ [syncUserFollowStatusWithSpacesDirect] Posted notification for user \(userId)")
}
    
    /// Update existing user's online status in otherUsers state
    /// Only updates if user profile already exists (same pattern as SpacesPaginationManager)
    @MainActor
    func updateExistingUserOnlineStatus(userId: Int64, isOnline: Bool) async {
        print("\n🔄 [updateExistingUserOnlineStatus] Checking if user \(userId) exists for status update")
        
        // Only update if we already have this user's profile
        if let existingProfile = otherUsers[userId] {
            // Check if online status actually changed
            if existingProfile.isOnline != isOnline {
                print("🔄 Updating existing profile for user \(userId) - Online: \(isOnline)")
                
                // Create updated profile with new online status
                let updatedProfile = UserProfile(
                    id: existingProfile.id,
                    nickname: existingProfile.nickname,
                    username: existingProfile.username,
                    avatar: existingProfile.avatar,
                    isFollowing: existingProfile.isFollowing ?? false,
                    status: existingProfile.status,
                    isAdmin: existingProfile.isAdmin,
                    isFriend: existingProfile.isFriend ?? false,
                    follows: existingProfile.follows ?? 0,
                    followings: existingProfile.followings ?? 0,
                    tweetsCount: existingProfile.tweetsCount ?? 0,
                    createdOn: existingProfile.createdOn,
                    categories: existingProfile.categories,
                    reactionCounts: existingProfile.reactionCounts,
                    isOnline: isOnline, // ✅ Updated online status
                    phone: existingProfile.phone,
                    activation: existingProfile.activation,
                    balance: existingProfile.balance
                )
                
                otherUsers[userId] = updatedProfile
                print("✅ Successfully updated user \(userId) online status to: \(isOnline)")
            } else {
                print("✅ User \(userId) online status unchanged - Online: \(isOnline)")
            }
        } else {
            // Skip creating new profiles - only update existing ones (same pattern as SpacesPaginationManager)
            print("⏭️ Skipping user \(userId) - No existing profile found for status update")
        }
    }

    //

    func followUser(userId: Int64) async throws {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        let url = URL(string: "\(AuthConfig.baseURL)/v1/user/follow")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["user_id": userId]
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("👥 Following user with ID: \(userId)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Follow failed: \(httpResponse.statusCode)")
        }
        
        // Update local user data and persist
        await MainActor.run {
            // Update current user's following count
            if var updatedUser = self.user {
                updatedUser.followings = updatedUser.followings + 1
                self.user = updatedUser
                self.persistUserData(updatedUser)
            }
            
            // Update other user's followers count (state-only)
            if var otherUser = self.otherUsers[userId] {
                otherUser.follows = otherUser.follows + 1
                otherUser.isFollowing = true
                self.otherUsers[userId] = otherUser
                // ✅ OPTIMIZED: Update username cache for O(1) lookup
                self.usernameToUserIdCache[otherUser.username] = otherUser.id
                // ✅ FIXED: No persistence for other users - state-only
            }
            
            // ✅ ADDED: Update follow status in reaction state
            updateFollowStatusInReactionState(userId: userId, isFollowing: true)
        }
        
        // ✅ ADDED: Sync follow status with spaces
        await syncUserFollowStatusWithSpacesDirect(userId: userId, isFollowing: true)
        
        print("✅ Successfully followed user")
    }

    // Unfollow a user
    func unfollowUser(userId: Int64) async throws {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        let url = URL(string: "\(AuthConfig.baseURL)/v1/user/unfollow")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["user_id": userId]
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("👥 Unfollowing user with ID: \(userId)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Unfollow failed: \(httpResponse.statusCode)")
        }
        
        // Update local user data and persist
        await MainActor.run {
            // Update current user's following count
            if var updatedUser = self.user {
                updatedUser.followings = max(0, updatedUser.followings - 1)
                self.user = updatedUser
                self.persistUserData(updatedUser)
            }
            
            // Update other user's followers count (state-only)
            if var otherUser = self.otherUsers[userId] {
                otherUser.follows = max(0, otherUser.follows - 1)
                otherUser.isFollowing = false
                self.otherUsers[userId] = otherUser
                // ✅ OPTIMIZED: Update username cache for O(1) lookup
                self.usernameToUserIdCache[otherUser.username] = otherUser.id
                // ✅ FIXED: No persistence for other users - state-only
            }
            
            // ✅ ADDED: Update follow status in reaction state
            updateFollowStatusInReactionState(userId: userId, isFollowing: false)
        }
        
        // ✅ ADDED: Sync follow status with spaces
        await syncUserFollowStatusWithSpacesDirect(userId: userId, isFollowing: false)
        
        print("✅ Successfully unfollowed user")
    }

    func searchUsers(keyword: String) async throws -> [SearchUserProfile] {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        let url = URL(string: "\(AuthConfig.baseURL)/v1/suggest/users?k=\(keyword)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🔍 Searching users with keyword: \(keyword)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Search failed: \(httpResponse.statusCode)")
        }
        
        print("📥 Received search response")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📝 Response JSON: \(jsonString)")
        }
        
                    do {
                let searchResponse = try JSONDecoder().decode(UserSearchResponse.self, from: data)
                guard searchResponse.code == 0 else {
                    throw AuthError.networkError(searchResponse.msg)
                }
                
             
                
                // ✅ ADDED: Sync with spaces if any users are hosts (using existing method)
                for user in searchResponse.data.suggests {
                    if let isOnline = user.isOnline {
                        await self.syncUserStatusWithSpacesDirect(userId: user.id, isOnline: isOnline)
                    }
                }
                
                print("✅ Successfully decoded and stored \(searchResponse.data.suggests.count) users")
                return searchResponse.data.suggests
        } catch {
            print("❌ Error decoding search response: \(error)")
            throw AuthError.networkError("Failed to decode search response: \(error.localizedDescription)")
        }
    }

    // Function to get another user's profile with caching logic
    func getOtherUserProfile(username: String) async throws -> UserProfile {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        // ✅ OPTIMIZED: Use cached username lookup for O(1) access instead of O(n) linear search
        let userId = usernameToUserIdCache[username] ?? 0
        
        // Check if we should use cached data (same logic as getUserProfile)
        if userId != 0 {
            guard shouldFetchProfile(userId: userId) else {
                print("[Cache] Using cached profile data for other user: \(username) (userId: \(userId))")
                return otherUsers[userId]!
            }
        }
        
        print("[API] Making fresh API call for other user: \(username)")
        
        let url = URL(string: "\(AuthConfig.baseURL)/v1/user/profile")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Add username as query parameter
        let urlWithParams = url.appending(queryItems: [URLQueryItem(name: "username", value: username)])
        request.url = urlWithParams
        
        print("🌐 Making request to: \(urlWithParams)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ Server returned status code: \(httpResponse.statusCode)")
            throw AuthError.signupFailed("Failed to get user profile: \(httpResponse.statusCode)")
        }
        
        print("📥 Received response data")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📝 Response JSON: \(jsonString)")
        }
        
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(UserProfileResponse.self, from: data)
            
            guard response.code == 0 else {
                throw AuthError.networkError(response.msg)
            }
            
            guard let profileData = response.data else {
                throw AuthError.networkError("No profile data in response")
            }
            
            // Convert the response data to UserProfile
            let userProfile = UserProfile(
                id: profileData.id,
                nickname: profileData.nickname,
                username: profileData.username,
                avatar: profileData.avatar,
                isFollowing: profileData.isFollowing,
                status: profileData.status,
                isAdmin: profileData.isAdmin,
                isFriend: profileData.isFriend,
                follows: profileData.follows,
                followings: profileData.followings,
                tweetsCount: profileData.tweetsCount,
                createdOn: profileData.createdOn,
                categories: profileData.categories,
                reactionCounts: profileData.reactionCounts?.reduce(into: [Int64: Int]()) { result, element in
                    if let int64Key = Int64(element.key) {
                        result[int64Key] = element.value
                    }
                }, // Convert [String: Int] to [Int64: Int]
                isOnline: profileData.isOnline, // ✅ ADDED: Include online status from API response
                phone: profileData.phone,
                activation: profileData.activation,
                balance: profileData.balance
            )
            
            print("✅ Successfully decoded UserProfile for username: \(username)")
            print("👤 User details:")
            print("- ID: \(userProfile.id)")
            print("- Username: \(userProfile.username)")
            print("- Nickname: \(userProfile.nickname)")
            print("- Is Following: \(userProfile.isFollowing ?? false)")
            print("- Is Online: \(userProfile.isOnline ?? false)")
            
            // Store the profile in the otherUsers dictionary (state-only)
            await MainActor.run {
                self.otherUsers[userProfile.id] = userProfile
                // ✅ OPTIMIZED: Update username cache for O(1) lookup
                self.usernameToUserIdCache[userProfile.username] = userProfile.id
                // ✅ FIXED: No persistence for other users - state-only
                print("✅ Stored profile for user: \(userProfile.id) with isFollowing: \(userProfile.isFollowing ?? false)")
            }
            
            // ✅ ADDED: Sync with spaces if this user is a host (using existing method)
            if let isOnline = userProfile.isOnline {
                await self.syncUserStatusWithSpacesDirect(userId: userProfile.id, isOnline: isOnline)
            }
            
            return userProfile
        } catch {
            print("❌ Decoding error: \(error)")
            throw AuthError.networkError("Failed to decode user profile: \(error.localizedDescription)")
        }
    }

    func getUserProfile(forceRefresh: Bool = false) async throws -> UserProfile {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.notAuthenticated
        }
        
        guard let username = try KeychainManager.shared.getUsername() else {
            throw AuthError.notAuthenticated
        }
        
        let userId = self.user?.id ?? 0
        
        // ✅ ADDED: Skip cache check when forceRefresh is true
        if !forceRefresh {
            // Check if we should use cached data
            guard shouldFetchProfile(userId: userId) else {
                print("[Cache] Using cached profile data for userId: \(userId)")
                return self.user!
            }
        } else {
            print("[Cache] Force refresh requested - skipping cache check")
        }
        
        print("[API] Making fresh API call for userId: \(userId)")
        
        let url = URL(string: "\(AuthConfig.baseURL)/v1/user/profile")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Add username as query parameter
        let urlWithParams = url.appending(queryItems: [URLQueryItem(name: "username", value: username)])
        request.url = urlWithParams
        
        print("🌐 Making request to: \(urlWithParams)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Profile fetch failed: \(httpResponse.statusCode)")
        }
        
        print("📥 Received profile response")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📝 Response JSON: \(jsonString)")
        }
        
        let profileResponse = try JSONDecoder().decode(UserProfileResponse.self, from: data)
        
        guard profileResponse.code == 0 else {
            throw AuthError.networkError(profileResponse.msg)
        }
        
        guard let profileData = profileResponse.data else {
            throw AuthError.networkError("No profile data in response")
        }
        
        // Convert the response data to UserProfile
        let userProfile = UserProfile(
            id: profileData.id,
            nickname: profileData.nickname,
            username: profileData.username,
            avatar: profileData.avatar,
            isFollowing: profileData.isFollowing,
            status: profileData.status,
            isAdmin: profileData.isAdmin,
            isFriend: profileData.isFriend,
            follows: profileData.follows,
            followings: profileData.followings,
            tweetsCount: profileData.tweetsCount,
            createdOn: profileData.createdOn,
            categories: profileData.categories,
            reactionCounts: profileData.reactionCounts?.reduce(into: [Int64: Int]()) { result, element in
                if let int64Key = Int64(element.key) {
                    result[int64Key] = element.value
                }
            }, // Convert [String: Int] to [Int64: Int]
            isOnline: profileData.isOnline, // ✅ ADDED: Include online status from API response
            phone: profileData.phone,
            activation: profileData.activation,
            balance: profileData.balance
        )
 
        if let categories = userProfile.categories {
            print("- Categories: \(categories)")
        }
        if let reactionCounts = userProfile.reactionCounts {
            print("- Reaction Counts: \(reactionCounts)")
        }
        if let phone = userProfile.phone {
            print("- Phone: \(phone)")
        }
        if let activation = userProfile.activation {
            print("- Activation: \(activation)")
        }
        if let balance = userProfile.balance {
            print("- Balance: \(balance)")
        }
        if let isOnline = userProfile.isOnline {
            print("- Is Online: \(isOnline)")
        }
        
        // ✅ FIXED: Update stored user data and persist it
        await MainActor.run {
            self.user = userProfile
            self.persistUserData(userProfile)
            print("✅ Profile data updated and persisted")
        }
        
        // ✅ ADDED: Sync with spaces if this user is a host (using existing method)
        if let isOnline = userProfile.isOnline {
            await self.syncUserStatusWithSpacesDirect(userId: userProfile.id, isOnline: isOnline)
        }
        
        return userProfile
    }

      


    // MARK: - Auth Functions
    func registerUser(
        username: String,
        password: String,
        categories: [Int64]? = nil,
        contacts: [ContactItem]? = nil,
        device: DeviceInfo? = nil
    ) async throws -> RegisterResponse.RegisterData {
        let url = URL(string: "\(AuthConfig.baseURL)/v1/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var parameters: [String: Any] = [
            "username": username,
            "password": password
        ]
        
        // Add categories if provided
        if let categories = categories {
            parameters["categories"] = categories
        }
        
        // Add contacts if provided
        if let contacts = contacts {
            // Convert ContactItem objects to dictionaries for JSON serialization
            let contactsDict = contacts.map { contact in
                var dict: [String: Any] = [
                    "name": contact.name,
                    "phone": contact.phone
                ]
                if let email = contact.email {
                    dict["email"] = email
                }
                return dict
            }
            parameters["contacts"] = contactsDict
        }
        
        // Add device info if provided
        if let device = device {
            // Convert DeviceInfo to dictionary for JSON serialization
            let deviceDict: [String: Any] = [
                "device_token": device.deviceToken,
                "platform": device.platform,
                "device_id": device.deviceID,
                "device_name": device.deviceName
            ]
            parameters["device"] = deviceDict
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        print("📤 Sending registration request for username: \(username)")
        print("📱 Device: \(device?.platform ?? "none")")
        print("👥 Contacts: \(contacts?.count ?? 0)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        print("📥 Received response")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📝 Response JSON: \(jsonString)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.signupFailed("Registration failed: \(httpResponse.statusCode)")
        }
        
        let registerResponse = try JSONDecoder().decode(RegisterResponse.self, from: data)
        
        guard registerResponse.code == 0 else {
            throw AuthError.signupFailed(registerResponse.msg)
        }
        
        guard let registerData = registerResponse.data else {
            throw AuthError.signupFailed("No data in response")
        }
        
        return registerData
    }

  

    // Update user avatar
    func updateAvatar(avatarData: Data) async throws {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        // ✅ STORE ORIGINAL AVATAR: For potential rollback on failure
        let originalAvatar = self.user?.avatar ?? ""
        print("📸 [AVATAR] Storing original avatar for rollback: \(originalAvatar)")
        
        // Step 1: Upload file to attachment endpoint
        print("\n📤 STEP 1: Uploading file to attachment endpoint")
        let uploadUrl = URL(string: "\(AuthConfig.baseURL)/v1/attachment")!
        var uploadRequest = URLRequest(url: uploadUrl)
        uploadRequest.httpMethod = "POST"
        
        // Create boundary for multipart form data
        let boundary = UUID().uuidString
        uploadRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        var body = Data()
        
        // Add type field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"type\"\r\n\r\n".data(using: .utf8)!)
        body.append("public/avatar\r\n".data(using: .utf8)!)
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(avatarData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        uploadRequest.httpBody = body
        
        print("🔍 Step 1 Request details:")
        print("- URL: \(uploadUrl)")
        print("- Method: POST")
        print("- Content-Type: multipart/form-data; boundary=\(boundary)")
        print("- File size: \(avatarData.count) bytes")
        print("- Type: public/avatar")
        
        let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
        
        if let httpResponse = uploadResponse as? HTTPURLResponse {
            print("📥 Step 1 HTTP Status Code: \(httpResponse.statusCode)")
        }
        
        print("📥 Step 1 Response:")
        if let jsonString = String(data: uploadData, encoding: .utf8) {
            print("📝 Response JSON: \(jsonString)")
        }
        
        // Decode upload response
        let uploadResponseDict = try JSONSerialization.jsonObject(with: uploadData) as? [String: Any]
        print("🔍 Step 1 Decoded response: \(String(describing: uploadResponseDict))")
        
        // Check upload response code
        if let code = uploadResponseDict?["code"] as? Int {
            if code != 0 {
                let msg = uploadResponseDict?["msg"] as? String ?? "Unknown error"
                print("❌ Step 1 failed with code: \(code)")
                throw AuthError.avatarUploadFailed(msg)
            }
        }
        
        // Get file URL from response
        guard let dataDict = uploadResponseDict?["data"] as? [String: Any],
              let rawFileUrl = dataDict["content"] as? String else {
            print("❌ Step 1 failed: No file URL in response")
            throw AuthError.avatarUploadFailed("Failed to get file URL from response")
        }
        
        // ✅ FIXED: Fix URL in data layer using StringExtensions
        let fileUrl = rawFileUrl.fixMalformedURL()
        
        print("✅ Step 1 successful")
        print("📎 Raw File URL: \(rawFileUrl)")
        print("📎 Fixed File URL: \(fileUrl)")
        
        // Step 2: Update user's avatar
        print("\n📤 STEP 2: Updating user's avatar")
        let avatarUrl = URL(string: "\(AuthConfig.baseURL)/v1/user/avatar")!
        var avatarRequest = URLRequest(url: avatarUrl)
        avatarRequest.httpMethod = "POST"
        avatarRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        avatarRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create request body - Send raw URL to backend (it expects the malformed format)
        let avatarBody = ["avatar": rawFileUrl]
        avatarRequest.httpBody = try JSONSerialization.data(withJSONObject: avatarBody)
        
        print("🔍 Step 2 Request details:")
        print("- URL: \(avatarUrl)")
        print("- Method: POST")
        print("- Content-Type: application/json")
        print("- Avatar URL (raw for backend): \(rawFileUrl)")
        
        let (avatarData, avatarResponse) = try await URLSession.shared.data(for: avatarRequest)
        
        if let httpResponse = avatarResponse as? HTTPURLResponse {
            print("📥 Step 2 HTTP Status Code: \(httpResponse.statusCode)")
        }
        
        print("📥 Step 2 Response:")
        if let jsonString = String(data: avatarData, encoding: .utf8) {
            print("📝 Response JSON: \(jsonString)")
        }
        
        // Decode avatar update response
        let avatarResponseDict = try JSONSerialization.jsonObject(with: avatarData) as? [String: Any]
        print("🔍 Step 2 Decoded response: \(String(describing: avatarResponseDict))")
        
        // Check avatar update response code
        if let code = avatarResponseDict?["code"] as? Int {
            if code != 0 {
                let msg = avatarResponseDict?["msg"] as? String ?? "Unknown error"
                print("❌ Step 2 failed with code: \(code)")
                
                // ✅ ROLLBACK: Restore original avatar on Step 2 failure
                await MainActor.run {
                    if var updatedUser = self.user {
                        updatedUser.avatar = originalAvatar
                        self.user = updatedUser
                        self.persistUserData(updatedUser)
                        print("🔄 [AVATAR] Rolled back to original avatar due to Step 2 failure")
                    }
                }
                
                throw AuthError.avatarUploadFailed(msg)
            }
        }
        
        print("✅ Step 2 successful")
        print("✅ Avatar upload process completed successfully")
        print("- Final Avatar URL: \(fileUrl)")
        
        // Update local user data and persist
        await MainActor.run {
            if var updatedUser = self.user {
                updatedUser.avatar = fileUrl
                self.user = updatedUser
                self.persistUserData(updatedUser)
                print("✅ Avatar URL updated and persisted")
            }
        }
    }




   // Configuration
struct AuthConfig {
    static var baseURL: String {
        return "http://api.tototopo.com:8008"  // Production server
    }
    
    struct Endpoints {
        static let userFollows = "/v1/user/follows"           // Users that the specified user follows
        static let userFollowings = "/v1/user/followings"
        static let register = "/v1/auth/register"
        static let login = "/v1/auth/login"
        static let userInfo = "/v1/user/info"
        static let profile = "/v1/user/profile"
        static let changePassword = "/v1/user/password"
        static let changeNickname = "/v1/user/nickname"
        static let changeAvatar = "/v1/user/avatar"
        static let categories = "/v1/user/categories"
        static let captcha = "/v1/captcha"
        static let bindPhone = "/v1/user/phone"
        static let activate = "/v1/user/activate"
        static let userOnlineStatus = "/v1/user/online-status" // Add this line
    }
}

// MARK: - Auth Models
struct ServerResponse<T: Codable>: Codable {
    let code: Int
    let msg: String
    let data: T?
}



struct LoginResponse: Codable {
    let code: Int
    let msg: String
    let data: LoginData?
    
    struct LoginData: Codable {
        let token: String
    }
}

// Add this empty response struct for error cases
struct EmptyResponse: Codable {}

func signUp(email: String, password: String, username: String, name: String, avatarData: Data?, categories: [Int64]? = nil, contacts: [ContactItem]? = nil, device: DeviceInfo? = nil) async throws -> UserProfile {
    print("\n📝 Starting signup process...")
    
    guard !username.isEmpty, !password.isEmpty else {
        throw AuthError.invalidInput
    }
    
    // Step 1: Register user
    print("🌐 Step 1: Registering user...")
    let registerResponse = try await registerUser(username: username, password: password, categories: categories, contacts: contacts, device: device)
    print("✅ Registration successful")
    
    // Step 2: Login to get token
    print("�� Step 2: Logging in...")
    let loginResponse = try await login(username: username, password: password)
    
    guard let loginData = loginResponse.data else {
        throw AuthError.loginFailed("No login data")
    }
    
    print("✅ Login successful")
    
    // Step 3: Save credentials
    print("🔐 Step 3: Saving credentials...")
    try KeychainManager.shared.saveToken(loginData.token)
    try KeychainManager.shared.saveUsername(username)
    print("✅ Credentials saved")
    
    // Step 4: Upload avatar if provided
    var avatarUrl = ""
    if let avatarData = avatarData {
        print("📸 Step 4: Uploading avatar...")
        avatarUrl = try await uploadAvatar(token: loginData.token, avatarData: avatarData)
        print("✅ Avatar uploaded")
    }
    
    // Step 5: Create user profile
    print("👤 Step 5: Creating user profile...")
    let userProfile = UserProfile(
        id: registerResponse.id,
        nickname: name,
        username: username,
        avatar: avatarUrl,
        isFollowing: false,
        status: 1,
        isAdmin: false,
        isFriend: false,
        follows: 0,
        followings: 0,
        tweetsCount: 0,
        createdOn: Int64(Date().timeIntervalSince1970),
        categories: categories,
        reactionCounts: nil,
        isOnline: true,
        phone: nil,
        activation: nil,
        balance: 0
    )
    print("✅ User profile created")
    
    // Step 6: Save to state (with error handling)
    print("💾 Step 6: Saving user profile to state...")
    do {
        await MainActor.run {
            self.user = userProfile
            self.isAuthenticated = true
            self.persistUserData(userProfile)
            UserDefaults.standard.set(String(userProfile.id), forKey: "currentUserId")
        }
        print("✅ User profile saved to state")
    } catch {
        print("❌ Failed to save user profile to state: \(error)")
        throw AuthError.signupFailed("Failed to save user state: \(error.localizedDescription)")
    }
    
    // Step 7: Initialize Ably (with error handling)
    print("🔌 Step 7: Initializing Ably service...")
    do {
        AblyService.shared.initialize(userId: userProfile.id)
        print("✅ Ably service initialized")
    } catch {
        print("❌ Failed to initialize Ably service: \(error)")
        throw AuthError.signupFailed("Failed to initialize Ably service: \(error.localizedDescription)")
    }
    
    print("🎉 Signup completed successfully!")
    return userProfile
}

private func uploadAvatar(token: String, avatarData: Data) async throws -> String {
    // Step 1: Upload file to attachment endpoint
    print("\n📤 STEP 1: Uploading file to attachment endpoint")
    let uploadUrl = URL(string: "\(AuthConfig.baseURL)/v1/attachment")!
    var uploadRequest = URLRequest(url: uploadUrl)
    uploadRequest.httpMethod = "POST"
    
    // Create boundary for multipart form data
    let boundary = UUID().uuidString
    uploadRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    uploadRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    // Create multipart form data
    var body = Data()
    
    // Add type field
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"type\"\r\n\r\n".data(using: .utf8)!)
    body.append("public/avatar\r\n".data(using: .utf8)!)
    
    // Add file data
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    body.append(avatarData)
    body.append("\r\n".data(using: .utf8)!)
    
    // Add closing boundary
    body.append("--\(boundary)--\r\n".data(using: .utf8)!)
    
    uploadRequest.httpBody = body
    
    print("🔍 Step 1 Request details:")
    print("- URL: \(uploadUrl)")
    print("- Method: POST")
    print("- Content-Type: multipart/form-data; boundary=\(boundary)")
    print("- File size: \(avatarData.count) bytes")
    print("- Type: public/avatar")
    
    let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
    
    if let httpResponse = uploadResponse as? HTTPURLResponse {
        print("📥 Step 1 HTTP Status Code: \(httpResponse.statusCode)")
    }
    
    print("📥 Step 1 Response:")
    if let jsonString = String(data: uploadData, encoding: .utf8) {
        print("📝 Response JSON: \(jsonString)")
    }
    
    // Decode upload response
    let uploadResponseDict = try JSONSerialization.jsonObject(with: uploadData) as? [String: Any]
    print("🔍 Step 1 Decoded response: \(String(describing: uploadResponseDict))")
    
    // Check upload response code
    if let code = uploadResponseDict?["code"] as? Int {
        if code != 0 {
            let msg = uploadResponseDict?["msg"] as? String ?? "Unknown error"
            print("❌ Step 1 failed with code: \(code)")
            throw AuthError.avatarUploadFailed(msg)
        }
    }
    
    // Get file URL from response
    guard let dataDict = uploadResponseDict?["data"] as? [String: Any],
          let rawFileUrl = dataDict["content"] as? String else {
        print("❌ Step 1 failed: No file URL in response")
        throw AuthError.avatarUploadFailed("Failed to get file URL from response")
    }
    
    // ✅ FIXED: Fix URL in data layer using StringExtensions
    let fileUrl = rawFileUrl.fixMalformedURL()
    
    print("✅ Step 1 successful")
    print("📎 Raw File URL: \(rawFileUrl)")
    print("📎 Fixed File URL: \(fileUrl)")
    
    // Step 2: Update user's avatar
    print("\n📤 STEP 2: Updating user's avatar")
    let avatarUrl = URL(string: "\(AuthConfig.baseURL)/v1/user/avatar")!
    var avatarRequest = URLRequest(url: avatarUrl)
    avatarRequest.httpMethod = "POST"
    avatarRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    avatarRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Create request body - Send raw URL to backend (it expects the malformed format)
    let avatarBody = ["avatar": rawFileUrl]
    avatarRequest.httpBody = try JSONSerialization.data(withJSONObject: avatarBody)
    
    print("🔍 Step 2 Request details:")
    print("- URL: \(avatarUrl)")
    print("- Method: POST")
    print("- Content-Type: application/json")
    print("- Avatar URL (raw for backend): \(rawFileUrl)")
    
    let (avatarData, avatarResponse) = try await URLSession.shared.data(for: avatarRequest)
    
    if let httpResponse = avatarResponse as? HTTPURLResponse {
        print("📥 Step 2 HTTP Status Code: \(httpResponse.statusCode)")
    }
    
    print("📥 Step 2 Response:")
    if let jsonString = String(data: avatarData, encoding: .utf8) {
        print("📝 Response JSON: \(jsonString)")
    }
    
    // Decode avatar update response
    let avatarResponseDict = try JSONSerialization.jsonObject(with: avatarData) as? [String: Any]
    print("🔍 Step 2 Decoded response: \(String(describing: avatarResponseDict))")
    
    // Check avatar update response code
    if let code = avatarResponseDict?["code"] as? Int {
        if code != 0 {
            let msg = avatarResponseDict?["msg"] as? String ?? "Unknown error"
            print("❌ Step 2 failed with code: \(code)")
            throw AuthError.avatarUploadFailed(msg)
        }
    }
    
    print("✅ Step 2 successful")
    print("✅ Avatar upload process completed successfully")
    print("- Final Avatar URL: \(fileUrl)")
    
    return fileUrl
}
    // Modified signUp function to get full profile data
  

    // Update user nickname
    func updateNickname(nickname: String) async throws {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        let url = URL(string: "\(AuthConfig.baseURL)/v1/user/nickname")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["nickname": nickname]
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Failed to update nickname: \(httpResponse.statusCode)")
        }
        
        // Update local user data and persist
        await MainActor.run {
            if var updatedUser = self.user {
                updatedUser.nickname = nickname
                self.user = updatedUser
                self.persistUserData(updatedUser)
            }
        }
    }

    // Update user password
    func updatePassword(oldPassword: String, newPassword: String) async throws {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        let url = URL(string: "\(AuthConfig.baseURL)/v1/user/password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "old_password": oldPassword,
            "password": newPassword
        ]
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Failed to update password: \(httpResponse.statusCode)")
        }
    }

    // Bind phone number
    func bindPhoneNumber(phone: String, captcha: String) async throws {
        guard let token = try KeychainManager.shared.getToken() else {
            throw AuthError.unauthorized("No authentication token found")
        }
        
        let url = URL(string: "\(AuthConfig.baseURL)/v1/user/phone")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "phone": phone,
            "captcha": captcha
        ]
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Failed to bind phone: \(httpResponse.statusCode)")
        }
    }

    // Tweet model
    struct Tweet: Codable, Identifiable {
        let id: String
        let userId: String
        let content: String
        let createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case content
            case createdAt = "created_at"
        }
    }

    struct ProfileData: Codable {
        let user_id: String
        let username: String
        let name: String
        let bio: String?
        let location: String?
        let website: String?
        let profilepicture: String?
        let stripe_connect_id: String?
        let notifications_enabled: Bool?
        let stripe_account_verified: Bool?
        let created_at: String?
        let updated_at: String?
    }

    struct FollowsData: Codable {
        let followers_count: Int
        let following_count: Int
        let following: [String]  // Array of user IDs that this user is following
    }
}
// Define a notification name
extension Notification.Name {
    static let userDidUpdate = Notification.Name("UserDidUpdate")
    static let userProfileDidUpdate = Foundation.Notification.Name("userProfileDidUpdate")
    static let userFollowStatusChanged = Notification.Name("UserFollowStatusChanged")
}

// MARK: - Category Models and Methods for TweetData


extension TweetData {
    
    // MARK: - Published Properties for State Management
    
    // MARK: - Category API Methods
    
    /// Get static categories for signup (no API calls)
    func getStaticCategories() -> [Category] {
        print("🏷️ Using static categories for signup")
        return Category.staticCategories
    }
    
    /// Get all available categories with hybrid approach (API + static fallback) - for monthly refresh
    func getAllCategories() async throws -> [Category] {
        // Check if we should use cached categories or fetch from API
        if shouldUseCachedCategories() {
            print("🏷️ Using cached categories (last updated: \(getLastCategoriesUpdateDate()))")
            return getCachedCategories()
        }
        
        // Try to fetch from API first
        do {
        guard let token = try KeychainManager.shared.getToken() else {
                print("🏷️ No token available, using static categories")
                return Category.staticCategories
        }
        
        let url = URL(string: "\(AuthConfig.baseURL)/v1/categories")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
            print("🏷️ Fetching categories from API for monthly refresh")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AuthError.networkError("Failed to get categories: \(httpResponse.statusCode)")
        }
        
        print("📥 Received categories response")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📝 Response JSON: \(jsonString)")
        }
        
            let categoriesResponse = try JSONDecoder().decode(CategoryListResponse.self, from: data)
            guard categoriesResponse.code == 0 else {
                throw AuthError.networkError(categoriesResponse.msg)
            }
            
            print("✅ Successfully fetched \(categoriesResponse.data.categories.count) categories from API")
            
            // Cache the categories and update timestamp
            cacheCategories(categoriesResponse.data.categories)
            
            // Update state
            await MainActor.run {
                self.allCategories = categoriesResponse.data.categories
                // ✅ OPTIMIZED: Update cached category dictionary for O(1) lookup
                self.categoriesDict = Dictionary(uniqueKeysWithValues: categoriesResponse.data.categories.map { ($0.id, $0) })
            }
            
            return categoriesResponse.data.categories
            
        } catch {
            print("❌ API fetch failed: \(error.localizedDescription), using static categories")
            return Category.staticCategories
        }
    }
    

    
   
    
    // MARK: - Convenience Methods
    
    /// Load all categories with loading state
    func loadAllCategories() async {
        await MainActor.run {
            self.isLoadingCategories = true
        }
        
        do {
            _ = try await getAllCategories()
        } catch {
            print("❌ Error loading categories: \(error)")
        }
        
        await MainActor.run {
            self.isLoadingCategories = false
        }
    }
    

    

    
    /// Get category by ID from all categories
    func getCategoryById(_ categoryId: Int64) -> Category? {
        // ✅ OPTIMIZED: Use cached Dictionary for O(1) lookup instead of O(n) linear search
        return categoriesDict[categoryId] ?? TweetData.staticCategoriesDict[categoryId]
    }
    
    /// Get category name by ID
    func getCategoryNameById(_ categoryId: Int64) -> String {
        return getCategoryById(categoryId)?.name ?? "Unknown Category"
    }
    

    

    
 
    
    // MARK: - Category Caching Methods
    
    /// Check if we should use cached categories (monthly update)
    private func shouldUseCachedCategories() -> Bool {
        let lastUpdate = getLastCategoriesUpdateDate()
        let calendar = Calendar.current
        let now = Date()
        
        // Check if it's been less than a month since last update
        if let lastUpdate = lastUpdate {
            let components = calendar.dateComponents([.month], from: lastUpdate, to: now)
            return components.month == 0 // Same month
        }
        
        return false // No cached data, should fetch
    }
    

    
    /// Get the last categories update date
    private func getLastCategoriesUpdateDate() -> Date? {
        return userDefaults.object(forKey: categoriesUpdateKey) as? Date
    }
    
    /// Cache categories to UserDefaults
    private func cacheCategories(_ categories: [Category]) {
        do {
            let data = try JSONEncoder().encode(categories)
            userDefaults.set(data, forKey: categoriesKey)
            userDefaults.set(Date(), forKey: categoriesUpdateKey)
            print("✅ Categories cached successfully")
        } catch {
            print("❌ Failed to cache categories: \(error)")
        }
    }
    
    /// Get cached categories from UserDefaults
    private func getCachedCategories() -> [Category] {
        guard let data = userDefaults.data(forKey: categoriesKey) else {
            print("🏷️ No cached categories found")
            return Category.staticCategories
        }
        
        do {
            let categories = try JSONDecoder().decode([Category].self, from: data)
            print("✅ Retrieved \(categories.count) cached categories")
            return categories
        } catch {
            print("❌ Failed to decode cached categories: \(error)")
            return Category.staticCategories
        }
    }
    
    /// Force refresh categories (ignore cache)
    func forceRefreshCategories() async throws -> [Category] {
        print("🔄 Force refreshing categories...")
        userDefaults.removeObject(forKey: categoriesKey)
        userDefaults.removeObject(forKey: categoriesUpdateKey)
        return try await getAllCategories()
    }
    

    
}

// MARK: - Category Extensions

extension Category {
    /// Get emoji icon for the category
    var emojiIcon: String {
        return icon.isEmpty ? "🏷️" : icon
    }
    
    /// Get color as UIColor (you'll need to implement this based on your UI framework)
    var uiColor: String {
        return color.isEmpty ? "#007AFF" : color
    }
}

// MARK: - Category Selection Helper

struct CategorySelection: Identifiable {
    let id = UUID()
    let category: Category
    var isSelected: Bool
    
    init(category: Category, isSelected: Bool = false) {
        self.category = category
        self.isSelected = isSelected
    }
}

// MARK: - Category State Management

extension TweetData {
    /// Create category selections from all categories with current user selections
    func createCategorySelections() -> [CategorySelection] {
        // ✅ FIXED: Use direct access to user categories instead of removed cache
        let userCategoryIds = user?.categories ?? []
        return allCategories.map { category in
            CategorySelection(
                category: category,
                isSelected: userCategoryIds.contains(category.id)
            )
        }
    }
}

// MARK: - Reaction Users Pagination State

// MARK: - Pagination Data (for individual reaction types)
struct PaginationData {
    var users: [ReactionUserProfile] = []
    var currentPage: Int = 0
    var hasMoreData: Bool = true
    var isLoading: Bool = false
    var error: String?
    var retryCount: Int = 0
    let maxRetries: Int = 3
    let pageSize: Int = 20
    
    mutating func reset() {
        users = []
        currentPage = 0
        hasMoreData = true
        isLoading = false
        error = nil
        retryCount = 0
    }
}

// MARK: - Reaction Users Pagination State (contains all reaction types for a user)
struct ReactionUsersPaginationState {
    // Contains all 20 reaction types for a user
    var reactionTypes: [Int64: PaginationData] = [:]
    
    // MARK: - Convenience Methods
    
    /// Get pagination data for specific reaction type
    func getPaginationData(reactionTypeId: Int64) -> PaginationData {
        return reactionTypes[reactionTypeId] ?? PaginationData()
    }
    
    /// Update pagination data for specific reaction type
    mutating func updatePaginationData(reactionTypeId: Int64, data: PaginationData) {
        reactionTypes[reactionTypeId] = data
    }
    
    /// Reset pagination data for specific reaction type
    mutating func resetPaginationData(reactionTypeId: Int64) {
        reactionTypes[reactionTypeId] = PaginationData()
    }
    
    /// Reset all pagination data
    mutating func resetAllData() {
        reactionTypes.removeAll()
    }
    
    /// Get users for specific reaction type
    func getUsers(reactionTypeId: Int64) -> [ReactionUserProfile] {
        return getPaginationData(reactionTypeId: reactionTypeId).users
    }
    
    /// Check if loading for specific reaction type
    func isLoading(reactionTypeId: Int64) -> Bool {
        return getPaginationData(reactionTypeId: reactionTypeId).isLoading
    }
    
    /// Check if has more data for specific reaction type
    func hasMoreData(reactionTypeId: Int64) -> Bool {
        return getPaginationData(reactionTypeId: reactionTypeId).hasMoreData
    }
    
    /// Get current page for specific reaction type
    func getCurrentPage(reactionTypeId: Int64) -> Int {
        return getPaginationData(reactionTypeId: reactionTypeId).currentPage
    }
    
    /// Get all reaction type IDs that have data
    func getAllReactionTypeIds() -> [Int64] {
        return Array(reactionTypes.keys)
    }
    
    /// Check if has any reaction data
    func hasReactionData() -> Bool {
        return !reactionTypes.isEmpty
    }
}

// MARK: - Helper Functions
// ✅ REMOVED: Using StringExtensions.fixMalformedURL() instead


