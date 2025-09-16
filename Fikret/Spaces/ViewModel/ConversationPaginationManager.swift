//
//  ConversationPaginationManager.swift
//  Fikret
//
//  Created by AI Assistant on 2025-01-18.
//  Copyright © 2025 Fikret. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Conversation Pagination Manager Extension
extension SpacesViewModel {
    
    // MARK: - Published Properties for UI (already in main class)
    // These are already defined in the main SpacesViewModel class:
    // @Published var conversationsFeed: ConversationsFeedState = ConversationsFeedState()
    // @Published var isLoadingMoreConversations = false
    // @Published var lastViewedConversationIndex: Int = 0
    // @Published var lastViewedConversationPage: Int = 1
    
    // MARK: - Private Properties (already in main class)
    // These are already defined in the main SpacesViewModel class:
    // private var conversationLoadRetryCount = 0
    // private let conversationMaxRetries = 3
    // private let conversationPageSize: Int = 20
    
    // MARK: - Public Methods
    
    /// Load conversations feed with pagination
    @MainActor
    func loadConversationsFeed(conversationPage: Int = 1, forceRefresh: Bool = false) async {
        // Prevent infinite loading if we've already tried and got empty results
        if conversationPage == 1 && !forceRefresh && conversationsFeed.posts.isEmpty && currentPageConversations > 0 {
            print("⏸️ Skipping load - already tried and got empty results")
            return
        }
        print("\n=== 🎵 LOADING CONVERSATIONS FEED ===")
        print("📄 Conversation Page: \(conversationPage)")
        print("🔄 Force Refresh: \(forceRefresh)")
        print("📊 Current conversation posts count: \(conversationsFeed.posts.count)")
        print("🔍 PAGINATION STATE:")
        print("  - currentPageConversations: \(currentPageConversations)")
        print("  - hasMoreDataConversations: \(hasMoreDataConversations)")
        print("  - conversationLoadRetryCount: \(conversationLoadRetryCount)")
        
        // Reset conversation error state
        conversationsFeed.error = nil
        
        // Handle conversation loading states
        if conversationPage == 1 {
            if isLoadingConversations {
                print("⏸️ Already loading initial conversation page, skipping...")
                return
            }
            isLoadingConversations = true
            print("🔄 Started loading initial conversation page")
        } else {
            if isLoadingMoreConversations {
                print("⏸️ Already loading more conversations, skipping...")
                return
            }
            isLoadingMoreConversations = true
            print("🔄 Started loading more conversations")
        }
        
        do {
            print("📡 Fetching conversations from API...")
            let conversationPosts = try await SpacesViewModel.getConversationTimeline(conversationPage: conversationPage, conversationPageSize: conversationPageSize)
            print("✅ Received \(conversationPosts.count) conversations")
            
            // Update conversation state with new posts
            if conversationPage == 1 || forceRefresh {
                print("📝 Replacing all conversation posts (first page or force refresh)")
                conversationsFeed.posts = conversationPosts
            } else {
                print("📝 Appending new conversation posts (page \(conversationPage))")
                // Filter out duplicate conversations
                let newConversationPosts = conversationPosts.filter { newPost in
                    !conversationsFeed.posts.contains { $0.id == newPost.id }
                }
                print("📊 Filtered out \(conversationPosts.count - newConversationPosts.count) duplicate conversation posts")
                conversationsFeed.posts.append(contentsOf: newConversationPosts)
            }
            
            // Update conversation pagination state
            print("🔍 UPDATING PAGINATION STATE:")
            print("  - Before update - currentPageConversations: \(currentPageConversations)")
            print("  - Before update - hasMoreDataConversations: \(hasMoreDataConversations)")
            print("  - New page: \(conversationPage)")
            print("  - Conversation posts count: \(conversationPosts.count)")
            print("  - Page size: \(conversationPageSize)")
            print("  - Has more data: \(conversationPosts.count == conversationPageSize)")
            
            currentPageConversations = conversationPage
            hasMoreDataConversations = conversationPosts.count == conversationPageSize
            
            // Mark this page as loaded
            loadedPagesConversations.insert(conversationPage)
            
            print("📊 Updated conversation pagination state:")
            print("- Current Conversation Page: \(currentPageConversations)")
            print("- Has More Conversation Data: \(hasMoreDataConversations)")
            print("- Total Conversation Posts: \(conversationsFeed.posts.count)")
            print("- Loaded Pages: \(loadedPagesConversations)")
            print("🔍 FINAL PAGINATION STATE:")
            print("  - currentPageConversations: \(currentPageConversations)")
            print("  - hasMoreDataConversations: \(hasMoreDataConversations)")
            print("  - loadedPagesConversations: \(loadedPagesConversations)")
            
            // Reset conversation retry count on success
            conversationLoadRetryCount = 0
            
            // Clean up old conversation posts to prevent memory issues
            cleanupOldConversations()
            
        } catch {
            print("❌ Error loading conversations feed: \(error)")
            handleConversationNetworkError(error)
            
            // Handle conversation retries
            if conversationLoadRetryCount < conversationMaxRetries {
                conversationLoadRetryCount += 1
                print("🔄 Retrying conversation load (attempt \(conversationLoadRetryCount) of \(conversationMaxRetries))")
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(conversationLoadRetryCount)) * 1_000_000_000))
                await loadConversationsFeed(conversationPage: conversationPage, forceRefresh: forceRefresh)
                return
            }
            
            // If we're loading conversation page 1, clear the posts array
            if conversationPage == 1 {
                conversationsFeed.posts = []
            }
            
            // Reset conversation loading states on error (after all retries exhausted)
            if conversationPage == 1 {
                isLoadingConversations = false
            } else {
                isLoadingMoreConversations = false
            }
            
            print("❌ Conversations feed load failed after all retries")
            return
        }
        
        // Reset conversation loading states on success
        if conversationPage == 1 {
            isLoadingConversations = false
        } else {
            isLoadingMoreConversations = false
        }
        
        print("✅ Conversations feed load completed")
    }
    
    /// Refresh conversations feed (reset and reload)
    @MainActor
    func refreshConversationsFeed() async {
        print("\n=== 🔄 REFRESHING CONVERSATIONS FEED ===")
        print("📊 Current Conversation State:")
        print("- Current Conversation Page: \(currentPageConversations)")
        print("- Has More Conversation Data: \(hasMoreDataConversations)")
        print("- Conversation Posts Count: \(conversationsFeed.posts.count)")
        
        // Reset all conversation pagination state
        conversationsFeed.reset()
        currentPageConversations = 0
        hasMoreDataConversations = true
        loadedPagesConversations.removeAll()
        
        await loadConversationsFeed(conversationPage: 1, forceRefresh: true)
        print("✅ Conversations feed refresh completed")
    }
    
    /// Load more conversations (next page)
    @MainActor
    func loadMoreConversations() async {
        print("\n=== 📄 LOAD MORE CONVERSATIONS CALLED ===")
        print("🔍 CURRENT STATE:")
        print("  - isLoadingConversations: \(isLoadingConversations)")
        print("  - isLoadingMoreConversations: \(isLoadingMoreConversations)")
        print("  - hasMoreDataConversations: \(hasMoreDataConversations)")
        print("  - currentPageConversations: \(currentPageConversations)")
        
        guard !isLoadingConversations && !isLoadingMoreConversations && hasMoreDataConversations else {
            print("⏸️ Skipping load more conversations:")
            print("- Conversation isLoading: \(isLoadingConversations)")
            print("- Conversation isLoadingMore: \(isLoadingMoreConversations)")
            print("- Conversation hasMoreData: \(hasMoreDataConversations)")
            return
        }
        
        // Prevent loading the same page multiple times
        let nextConversationPage = currentPageConversations + 1
        // This check is redundant since nextConversationPage is always currentPageConversations + 1
        // But we can keep it for safety in case the logic changes
        
        // Validate that we have a valid next page (should always be valid since we increment by 1)
        guard nextConversationPage > currentPageConversations else {
            print("⚠️ Invalid next page calculation:")
            print("  - currentPageConversations: \(currentPageConversations)")
            print("  - calculated nextConversationPage: \(nextConversationPage)")
            return
        }
        
        print("📄 Loading more conversations - Conversation Page \(nextConversationPage)")
        print("🔍 NEXT PAGE CALCULATION:")
        print("  - currentPageConversations: \(currentPageConversations)")
        print("  - nextConversationPage: \(nextConversationPage)")
        await loadConversationsFeed(conversationPage: nextConversationPage)
    }
    
    /// Load previous conversations (previous page)
    @MainActor
    func loadPreviousConversations() async {
        print("\n=== ⬆️ LOAD PREVIOUS CONVERSATIONS CALLED ===")
        print("🔍 PREVIOUS CONVERSATIONS STATE:")
        print("  - isLoadingConversations: \(isLoadingConversations)")
        print("  - isLoadingMoreConversations: \(isLoadingMoreConversations)")
        print("  - currentPageConversations: \(currentPageConversations)")
        print("  - conversationsFeed.posts.count: \(conversationsFeed.posts.count)")
        
        // Enhanced guard conditions for loading previous conversations
        guard !isLoadingConversations &&
              !isLoadingMoreConversations &&
              currentPageConversations > 1 &&
              !conversationsFeed.posts.isEmpty else {
            print("⏸️ Skipping load previous conversations:")
            print("  - Already loading: \(isLoadingConversations || isLoadingMoreConversations)")
            print("  - At first page: \(currentPageConversations <= 1)")
            print("  - No posts: \(conversationsFeed.posts.isEmpty)")
            return
        }
        
        let previousPage = currentPageConversations - 1
        
        // Check if the previous page is already loaded using page tracking
        if loadedPagesConversations.contains(previousPage) {
            print("⏸️ Skipping load previous conversations - page \(previousPage) already loaded:")
            print("  - Loaded pages: \(loadedPagesConversations)")
            print("  - Current page: \(currentPageConversations)")
            print("  - Previous page: \(previousPage)")
            return
        }
        
        // Validate that we have a valid previous page
        guard previousPage >= 1 else {
            print("⏸️ No valid previous page available")
            print("  - currentPageConversations: \(currentPageConversations)")
            print("  - calculated previousPage: \(previousPage)")
            return
        }
        
        print("⬆️ Loading previous conversations - Page \(previousPage)")
        print("🔍 PREVIOUS PAGE CALCULATION:")
        print("  - currentPageConversations: \(currentPageConversations)")
        print("  - previousPage: \(previousPage)")
        
        isLoadingConversations = true
        do {
            let previousConversations = try await SpacesViewModel.getConversationTimeline(conversationPage: previousPage, conversationPageSize: conversationPageSize)
            print("✅ Received \(previousConversations.count) previous conversations")
            
            // Filter out duplicates before prepending
            let uniquePreviousConversations = previousConversations.filter { newPost in
                !conversationsFeed.posts.contains { $0.id == newPost.id }
            }
            print("📊 Filtered out \(previousConversations.count - uniquePreviousConversations.count) duplicate previous conversations")
            
            // Prepend conversations
            conversationsFeed.posts.insert(contentsOf: uniquePreviousConversations, at: 0)
            
            // Update pagination state
            currentPageConversations = previousPage
            hasMoreDataConversations = true // Assume there might be more previous pages
            
            // Mark the previous page as loaded
            loadedPagesConversations.insert(previousPage)
            
            print("✅ Prepended \(uniquePreviousConversations.count) previous conversations. Current page: \(currentPageConversations)")
            print("🔍 FINAL STATE AFTER PREPENDING:")
            print("  - currentPageConversations: \(currentPageConversations)")
            print("  - conversationsFeed.posts.count: \(conversationsFeed.posts.count)")
            print("  - hasMoreDataConversations: \(hasMoreDataConversations)")
            print("  - loadedPagesConversations: \(loadedPagesConversations)")
            
        } catch {
            print("❌ Error loading previous conversations: \(error)")
            conversationsFeed.error = error.localizedDescription
        }
        isLoadingConversations = false
    }
    
    /// Save conversation position for restoration
    @MainActor
    func saveConversationPosition(index: Int) {
        // Ensure index is valid
        let validIndex = max(0, index)
        lastViewedConversationIndex = validIndex
        lastViewedConversationPage = (validIndex / conversationPageSize) + 1
        print("💾 Saved conversation position:")
        print("- Conversation Index: \(lastViewedConversationIndex)")
        print("- Conversation Page: \(lastViewedConversationPage)")
    }
    
    /// Restore conversation position
    @MainActor
    func restoreConversationPosition() -> (index: Int, page: Int) {
        // Ensure we never return negative index
        let validIndex = max(0, lastViewedConversationIndex)
        print("📖 Restoring conversation position:")
        print("- Conversation Index: \(validIndex)")
        print("- Conversation Page: \(lastViewedConversationPage)")
        return (validIndex, lastViewedConversationPage)
    }
    
    
    
    /// Reset conversation loading states
    @MainActor
    func resetConversationLoadingStates() {
        print("🔄 Resetting conversation loading states")
        isLoadingConversations = false
        isLoadingMoreConversations = false
    }
    
    // MARK: - Private Methods
    

    
    /// Get timeline conversations from API
    static func getConversationTimeline(conversationPage: Int = 1, conversationPageSize: Int = 20) async throws -> [AudioConversation] {
        print("\n=== 📱 GET CONVERSATION TIMELINE API CALL ===")
        print("📄 Conversation Page: \(conversationPage)")
        print("📊 Conversation Page Size: \(conversationPageSize)")
        
        guard let token = try KeychainManager.shared.getToken() else {
            print("❌ No token found")
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(PostConfig.baseURL)/v1/posts?style=newest&page=\(conversationPage)&page_size=\(conversationPageSize)")!
        print("🌐 Request URL: \(url)")
        print("🔑 Token length: \(token.count) characters")
        print("🔑 Token (first 50 chars): \(String(token.prefix(50)))...")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30.0
        
        print("📤 Request Details:")
        print("- Method: GET")
        print("- URL: \(url)")
        print("- Authorization: Bearer [\(token.count) chars]")
        print("- Accept: application/json")
        print("- Content-Type: application/json")
        print("- Timeout: 30 seconds")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // Log raw response data first
        print("\n📡 RAW RESPONSE DATA:")
        print("- Data size: \(data.count) bytes")
        if let rawString = String(data: data, encoding: .utf8) {
            print("- Raw response body: \(rawString)")
        } else {
            print("- Raw response body: [Unable to decode as UTF-8]")
        }
        
        // Log HTTP response details
        if let httpResponse = response as? HTTPURLResponse {
            print("\n📡 HTTP Response:")
            print("- Status Code: \(httpResponse.statusCode)")
            print("- Headers: \(httpResponse.allHeaderFields)")
            
            // Check if it's an error response and handle it properly
            if httpResponse.statusCode >= 400 {
                print("❌ HTTP Error Response")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📦 Error Response Body:")
                    print(jsonString)
                }
                
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw APIError.responseError(response: errorResponse)
                } else {
                    throw APIError.networkError(error: NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
                }
            }
        }
        
        
        do {
            // Decode the response with the correct structure
            let response = try JSONDecoder().decode(APIResponse<PaginatedListResponse<PostResponse>>.self, from: data)
            print("\n✅ Successfully decoded conversation timeline response")
            print("📊 Response Details:")
            print("- Code: \(response.code)")
            print("- Message: \(response.msg)")
            print("- Total Conversation Posts: \(response.data.list.count)")
            print("- Conversation Page: \(response.data.pager.page)")
            print("- Conversation Page Size: \(response.data.pager.pageSize)")
            print("- Total Conversation Rows: \(response.data.pager.totalRows)")
            
            // Convert posts to AudioConversations - filter out incomplete posts
            let conversations = response.data.list.compactMap { $0.toAudioConversation() }
            print("🔄 Converted \(conversations.count) posts to AudioConversations (filtered from \(response.data.list.count) total)")
            
            // Log conversation details for debugging
            for (index, conversation) in conversations.enumerated() {
                print("\nConversation \(index + 1):")
                print("- ID: \(conversation.id)")
                print("- Host: \(conversation.host_name)")
                print("- User: \(conversation.user_name)")
                print("- Topic: \(conversation.topic)")
                print("- Duration: \(conversation.duration)")
                print("- Created At: \(conversation.created_at)")
            }
            
            return conversations
            
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
    
    /// Clean up old conversations to prevent memory issues
    @MainActor
    private func cleanupOldConversations() {
        let maxConversationPosts = 100
        if conversationsFeed.posts.count > maxConversationPosts {
            print("🧹 Cleaning up old conversation posts - keeping last \(maxConversationPosts/2) conversation posts")
            conversationsFeed.posts = Array(conversationsFeed.posts.suffix(maxConversationPosts/2))
        }
    }
    
    /// Handle conversation network errors
    @MainActor
    private func handleConversationNetworkError(_ error: Error) {
        print("❌ Conversation feed network error: \(error)")
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                conversationsFeed.error = "No internet connection. Please check your network."
            case .timedOut:
                conversationsFeed.error = "Request timed out. Please try again."
            case .cancelled:
                conversationsFeed.error = "Request was cancelled."
            default:
                conversationsFeed.error = "Network error: \(urlError.localizedDescription)"
            }
        } else {
            conversationsFeed.error = error.localizedDescription
        }
    }
}

// MARK: - Conversation Pagination Extensions

extension SpacesViewModel {
    
    /// Check if there are more conversations to load
    var hasMoreConversations: Bool {
        return hasMoreDataConversations
    }
    
    /// Get current conversation page
    var currentConversationPage: Int {
        return currentPageConversations
    }
    
    /// Get total conversation posts count
    var totalConversationPosts: Int {
        return conversationsFeed.posts.count
    }
    
    /// Check if conversations are currently loading
    var isConversationsLoading: Bool {
        return isLoadingConversations
    }
    
    /// Check if more conversations are being loaded
    var isConversationsLoadingMore: Bool {
        return isLoadingMoreConversations
    }
    
    /// Check if a specific conversation page is already loaded
    var isConversationPageLoaded: (Int) -> Bool {
        return { page in
            return self.loadedPagesConversations.contains(page)
        }
    }
}
