import Foundation
import CoreLocation

struct TweetModel: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let name: String
    let profilepicture: String
    let tweet: String
    let mediaUrls: [MediaItem]?
    let location: LocationData?
    let createdAt: Date
    let likes: Int
    let comments: Int
    let retweets: Int
    var isLiked: Bool = false
    var isRetweeted: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case name
        case profilepicture
        case tweet
        case mediaUrls = "media_urls"
        case location
        case createdAt = "created_at"
        case likes
        case comments
        case retweets
        case isLiked = "is_liked"
        case isRetweeted = "is_retweeted"
    }
}

// Media types that can be attached to a tweet
struct MediaItem: Codable {
    let type: MediaType
    let url: String
    let thumbnailUrl: String?
    let width: Int?
    let height: Int?
    let duration: Double? // For videos
    
    enum MediaType: String, Codable {
        case image
        case video
        case gif
    }
}

