import Foundation
import SwiftUI

// MARK: - Real Trending Topics Service (Reddit API)
class TrendingTopicsService: ObservableObject {
    static let shared = TrendingTopicsService()
    
    // MARK: - Spinner Wheel State
    private var currentCategoryIndex: Int = 0
    private var currentDepth: Int = 0
    private var userCategories: [String] = []
    private var topicsPerSpin: Int = 2
    
    // Default fallback categories when user has none set
    private let defaultCategories = ["gaming", "technology", "entertainment", "sports"]
    
    // MARK: - Public Methods
    
    /// Configure user's selected categories for the spinner wheel
    func setUserCategories(_ categories: [String]) {
        // Only reset position if categories have actually changed
        if userCategories != categories {
            userCategories = categories
            currentCategoryIndex = 0
            currentDepth = 0
            print("🎯 [SPINNER] Set NEW user categories: \(categories) - Reset position")
        } else {
            print("🎯 [SPINNER] Categories unchanged: \(categories) - Keeping current position (index: \(currentCategoryIndex), depth: \(currentDepth))")
        }
    }
    
    /// Get multiple trending topics for spinner wheel (4 options per spin)
    func getNextTrendingTopics(count: Int = 4) async -> [TrendingTopic] {
        var topics: [TrendingTopic] = []
        let categoriesToUse = getCategoriesToUse()
        
        print("🎲 [SPINNER] Getting \(count) trending topics for spin...")
        
        // Get topics from current category and depth range
        if let categoryTopics = await fetchMultipleTrendingTopics(
            category: categoriesToUse[currentCategoryIndex],
            depth: currentDepth,
            count: count
        ) {
            topics.append(contentsOf: categoryTopics)
        }
        
        // If we don't have enough topics from the primary category, fill from other categories
        if topics.count < count {
            let remainingCount = count - topics.count
            print("🔄 [SPINNER] Need \(remainingCount) more topics, trying other categories...")
            
            let additionalTopics = await fetchAdditionalTopics(
                excludeCategory: categoriesToUse[currentCategoryIndex],
                depth: currentDepth,
                count: remainingCount
            )
            topics.append(contentsOf: additionalTopics)
        }
        
        // Advance to next category for next spin
        currentCategoryIndex = (currentCategoryIndex + 1) % categoriesToUse.count
        
        // If we've cycled through all categories, go deeper
        if currentCategoryIndex == 0 {
            currentDepth += 1
            print("🔄 [SPINNER] Completed cycle, going deeper to depth \(currentDepth)")
        }
        
        print("✅ [SPINNER] Returning \(topics.count) topics for this spin")
        return Array(topics.prefix(count)) // Ensure we don't exceed requested count
    }
    
    /// Reset spinner wheel to start from the beginning
    func resetSpinnerWheel() {
        currentCategoryIndex = 0
        currentDepth = 0
        print("🔄 [SPINNER] Reset wheel to start position")
    }
    
    // MARK: - Private Methods (Spinner Wheel Logic)
    
    /// Determine which categories to use based on user configuration
    private func getCategoriesToUse() -> [String] {
        if userCategories.isEmpty {
            // No categories set - use default trending categories
            return defaultCategories
        }
        return userCategories
    }
    
    /// Fetch multiple trending topics from specific category
    private func fetchMultipleTrendingTopics(category: String, depth: Int, count: Int) async -> [TrendingTopic]? {
        do {
            // Calculate position range based on depth
            let startIndex = depth * topicsPerSpin
            let limit = startIndex + count + 10 // Get extra for filtering
            
            print("🔍 [SPINNER] Fetching \(count) topics from r/\(category) at depth \(depth) (positions \(startIndex)+)")
            
            // Try trending/top first for best quality
            var topics = try await fetchTrendingFromSubreddit(subreddit: category, sortBy: "top", timeframe: "day", limit: limit)
            
            // If not enough topics, try hot
            if topics.count < startIndex + count {
                print("🔄 [SPINNER] Not enough top topics, trying hot for r/\(category)")
                let hotTopics = try await fetchTrendingFromSubreddit(subreddit: category, sortBy: "hot", timeframe: nil, limit: limit)
                topics.append(contentsOf: hotTopics)
                
                // Remove duplicates
                topics = Array(Set(topics)).sorted { Int($0.trendingScore) ?? 0 > Int($1.trendingScore) ?? 0 }
            }
            
            // Get topics from the requested depth range
            let endIndex = min(startIndex + count, topics.count)
            if startIndex < topics.count {
                let selectedTopics = Array(topics[startIndex..<endIndex])
                print("✅ [SPINNER] Selected \(selectedTopics.count) topics from r/\(category)")
                return selectedTopics
            } else {
                print("⚠️ [SPINNER] r/\(category) doesn't have enough topics at depth \(depth)")
                return nil
            }
            
        } catch {
            print("❌ [SPINNER] Error fetching multiple topics from r/\(category): \(error)")
            return nil
        }
    }
    
    /// Fetch additional topics from other categories to fill the requirement
    private func fetchAdditionalTopics(excludeCategory: String, depth: Int, count: Int) async -> [TrendingTopic] {
        var additionalTopics: [TrendingTopic] = []
        let categoriesToUse = getCategoriesToUse()
        
        // Try other user categories first
        let otherCategories = categoriesToUse.filter { $0 != excludeCategory }
        
        for category in otherCategories {
            if additionalTopics.count >= count { break }
            
            if let categoryTopics = await fetchMultipleTrendingTopics(
                category: category,
                depth: 0, // Start from most trending for additional topics
                count: count - additionalTopics.count
            ) {
                additionalTopics.append(contentsOf: categoryTopics)
                print("✅ [SPINNER] Added \(categoryTopics.count) topics from r/\(category)")
            }
        }
        
        // If still not enough, try default categories
        if additionalTopics.count < count {
            let defaultsToTry = defaultCategories.filter { category in
                !categoriesToUse.contains(category) && category != excludeCategory
            }
            
            for category in defaultsToTry {
                if additionalTopics.count >= count { break }
                
                if let categoryTopics = await fetchMultipleTrendingTopics(
                    category: category,
                    depth: 0,
                    count: count - additionalTopics.count
                ) {
                    additionalTopics.append(contentsOf: categoryTopics)
                    print("✅ [SPINNER] Added \(categoryTopics.count) topics from fallback r/\(category)")
                }
            }
        }
        
        // Last resort: r/all
        if additionalTopics.count < count {
            if let allTopics = await fetchMultipleTrendingTopics(
                category: "all",
                depth: 0,
                count: count - additionalTopics.count
            ) {
                additionalTopics.append(contentsOf: allTopics)
                print("✅ [SPINNER] Added \(allTopics.count) topics from r/all as last resort")
            }
        }
        
        return Array(additionalTopics.prefix(count))
    }
    
    /// Fetch trending topics from subreddit with sorting options
    private func fetchTrendingFromSubreddit(subreddit: String, sortBy: String, timeframe: String?, limit: Int) async throws -> [TrendingTopic] {
        var urlString = "https://www.reddit.com/r/\(subreddit)/\(sortBy).json?limit=\(limit)"
        
        if let timeframe = timeframe {
            urlString += "&t=\(timeframe)"
        }
        
        guard let url = URL(string: urlString) else {
            throw TrendingTopicsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TrendingTopicsError.networkError
        }
        
        let redditResponse = try JSONDecoder().decode(RedditResponse.self, from: data)
        
        let topics = redditResponse.data.children.compactMap { post -> TrendingTopic? in
            // Filter out NSFW and low-quality posts
            guard !post.data.over18,
                  post.data.score > 50, // Higher threshold for trending
                  !post.data.title.isEmpty,
                  post.data.title.count > 10 else {
                return nil
            }
            
            // Clean title
            let cleanTitle = cleanRedditTitle(post.data.title)
            
            return TrendingTopic(
                title: cleanTitle,
                description: "Trending in r/\(post.data.subreddit)",
                category: post.data.subreddit,
                trendingScore: "\(post.data.score)",
                source: "Reddit"
            )
        }
        
        return topics
    }
    
    /// Clean Reddit post titles
    private func cleanRedditTitle(_ title: String) -> String {
        return title
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Data Models

struct TrendingTopic: Identifiable, Hashable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let category: String
    let trendingScore: String
    let source: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(category)
    }
    
    static func == (lhs: TrendingTopic, rhs: TrendingTopic) -> Bool {
        return lhs.title == rhs.title && lhs.category == rhs.category
    }
}

// MARK: - Reddit Response Models

struct RedditResponse: Codable {
    let data: RedditData
}

struct RedditData: Codable {
    let children: [RedditChild]
}

struct RedditChild: Codable {
    let data: RedditPost
}

struct RedditPost: Codable {
    let title: String
    let score: Int
    let subreddit: String
    let numComments: Int?
    let over18: Bool
    
    enum CodingKeys: String, CodingKey {
        case title, score, subreddit, numComments
        case over18 = "over_18"
    }
}

// MARK: - Errors

enum TrendingTopicsError: Error, LocalizedError {
    case invalidURL
    case networkError
    case invalidData
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .invalidData:
            return "Invalid data received"
        case .noData:
            return "No data available"
        }
    }
}