//
//  SpacesPaginationManager.swift
//  Fikret
//
//  Created by AI Assistant on 2025-01-18.
//  Copyright © 2025 Fikret. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Spaces Pagination Manager Extension
extension SpacesViewModel {
    
    // MARK: - Published Properties for UI (already in main class)
    // These are already defined in the main SpacesViewModel class:
    // @Published var spaces: [Space] = []
    // @Published var isLoadingMoreSpaces = false
    // @Published var lastViewedSpaceIndex: Int = 0
    // @Published var lastViewedSpacePage: Int = 1
    // @Published var isLoadingSpaces = false
    // @Published var loadErrorSpaces: String? = nil
    
    // MARK: - Private Properties (already in main class)
    // These are already defined in the main SpacesViewModel class:
    // private var spaceLoadRetryCount = 0
    // private let spaceMaxRetries = 3
    // private let spacePageSize: Int = 20
    // private var currentPageSpaces = 0
    // private var hasMoreDataSpaces = true
    
    // MARK: - Public Methods
    
    /// Load spaces feed with pagination
    @MainActor
    func loadSpacesFeed(spacePage: Int = 1, spacePageSize: Int = 20, forceRefresh: Bool = false) async {
        print("\n🔄 [loadSpacesFeed] Starting feed load")
        print("📊 Parameters:")
        print("- Space Page: \(spacePage)")
        print("- Space Page Size: \(spacePageSize)")
        print("- Force Refresh: \(forceRefresh)")
        print("- Current spaces count: \(spaces.count)")
        
        // Reset error state
        loadErrorSpaces = nil
        
        // Handle loading states with weak self
        if spacePage == 1 {
            if isLoadingSpaces {
                print("⏸ [loadSpacesFeed] Already loading initial page, skipping...")
                return
            }
            isLoadingSpaces = true
        } else {
            if isLoadingMoreSpaces {
                print("⏸ [loadSpacesFeed] Already loading more, skipping...")
                return
            }
            isLoadingMoreSpaces = true
        }
        
        do {
            print("🌐 [loadSpacesFeed] Making API request...")
            let fetchedSpaces = try await withTimeout { [weak self] in
                guard let self = self else { throw APIError.unknown(error: NSError(domain: "SelfDeallocated", code: -1)) }
                return try await self.listRooms(spacePage: spacePage, spacePageSize: spacePageSize)
            }
            
            print("\n✅ [loadSpacesFeed] Successfully fetched \(fetchedSpaces.count) spaces")
            print("📝 Fetched spaces details:")
            for (index, space) in fetchedSpaces.enumerated() {
                print("\nSpace \(index + 1):")
                print("- ID: \(space.id)")
                print("- Host: \(space.host ?? "nil")")
                print("- Host ID: \(space.hostId)")
                print("- Host Username: \(space.hostUsername ?? "nil")")
                print("- Topics: \(space.topics ?? [])")
                print("- Speakers count: \(space.speakers.count)")
                print("- Queue participants: \(space.queue.participants.count)")
                print("- Created At: \(space.createdAt)")
                print("- Updated At: \(space.updatedAt)")
                print("- Is Host Online: \(space.isHostOnline)")
            }
            
            // Reset retry count on success
            spaceLoadRetryCount = 0
            
            // Update local state
            if spacePage == 1 || forceRefresh {
                print("🔄 [loadSpacesFeed] First page or force refresh - appending to existing spaces")
                print("📊 Before update - spaces count: \(spaces.count)")
                // Apply deduplication even for first page/refresh to handle backend duplicates
                var seenIds = Set<Int64>()
                let uniqueSpaces = fetchedSpaces.filter { space in
                    // Remove duplicates within the same batch based on space ID
                    return seenIds.insert(space.id).inserted
                }
                print("📊 Deduplication results: \(fetchedSpaces.count) -> \(uniqueSpaces.count) spaces")
                
                // ✅ FIXED: Append instead of replace to preserve user's own space
                let newSpaces = uniqueSpaces.filter { newSpace in
                    !spaces.contains { $0.id == newSpace.id }
                }
                print("📊 Filtered out \(uniqueSpaces.count - newSpaces.count) duplicate spaces")
                spaces.append(contentsOf: newSpaces)
                print("📊 After update - spaces count: \(spaces.count)")
            } else {
                print("🔄 [loadSpacesFeed] Appending new spaces")
                print("📊 Before append - spaces count: \(spaces.count)")
                // Ensure no duplicates
                let newSpaces = fetchedSpaces.filter { newSpace in
                    !spaces.contains { $0.id == newSpace.id }
                }
                print("📊 Filtered out \(fetchedSpaces.count - newSpaces.count) duplicate spaces")
                spaces.append(contentsOf: newSpaces)
                print("📊 After append - spaces count: \(spaces.count)")
            }
            
            // Update pagination state
            print("🔍 UPDATING PAGINATION STATE:")
            print("  - Before update - currentPageSpaces: \(currentPageSpaces)")
            print("  - Before update - hasMoreDataSpaces: \(hasMoreDataSpaces)")
            print("  - New page: \(spacePage)")
            print("  - Spaces count: \(fetchedSpaces.count)")
            print("  - Page size: \(spacePageSize)")
            print("  - Has more data: \(fetchedSpaces.count == spacePageSize)")
            
            hasMoreDataSpaces = fetchedSpaces.count == spacePageSize
            currentPageSpaces = spacePage
            lastViewedSpacePage = spacePage
            
            // Mark this page as loaded
            loadedPagesSpaces.insert(spacePage)
            
            // Optimize position restoration
            if spacePage == lastViewedSpacePage && lastViewedSpaceIndex >= spaces.count {
                let neededItems = lastViewedSpaceIndex - spaces.count + 1
                let pagesToLoad = Int(ceil(Double(neededItems) / Double(spacePageSize)))
                print("🔄 Need to load \(pagesToLoad) more pages to restore position")
                
                for pageToLoad in (spacePage + 1)...(spacePage + pagesToLoad) {
                    guard hasMoreDataSpaces else { break }
                    print("📄 Loading additional page \(pageToLoad) for position restoration")
                    let additionalSpaces = try await withTimeout { [weak self] in
                        guard let self = self else { throw APIError.unknown(error: NSError(domain: "SelfDeallocated", code: -1)) }
                        return try await self.listRooms(spacePage: pageToLoad, spacePageSize: spacePageSize)
                    }
                    
                    print("✅ Loaded \(additionalSpaces.count) additional spaces")
                    
                    // Filter out duplicates
                    let uniqueSpaces = additionalSpaces.filter { newSpace in
                        !spaces.contains { $0.id == newSpace.id }
                    }
                    print("📊 Filtered out \(additionalSpaces.count - uniqueSpaces.count) duplicate spaces from additional page")
                    spaces.append(contentsOf: uniqueSpaces)
                    hasMoreDataSpaces = additionalSpaces.count == spacePageSize
                }
            }
            
            print("📊 Updated spaces pagination state:")
            print("- Current Spaces Page: \(currentPageSpaces)")
            print("- Has More Spaces Data: \(hasMoreDataSpaces)")
            print("- Total Spaces: \(spaces.count)")
            print("- Loaded Pages: \(loadedPagesSpaces)")
            print("🔍 FINAL PAGINATION STATE:")
            print("  - currentPageSpaces: \(currentPageSpaces)")
            print("  - hasMoreDataSpaces: \(hasMoreDataSpaces)")
            print("  - loadedPagesSpaces: \(loadedPagesSpaces)")
            
            // Reset spaces retry count on success
            spaceLoadRetryCount = 0
           
        } catch {
            print("❌ Error loading spaces feed: \(error)")
            handleSpacesNetworkError(error)
            
            // Handle retries
            if spaceLoadRetryCount < spaceMaxRetries {
                spaceLoadRetryCount += 1
                print("🔄 Retrying load (attempt \(spaceLoadRetryCount) of \(spaceMaxRetries))")
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(spaceLoadRetryCount)) * 1_000_000_000))
                await loadSpacesFeed(spacePage: spacePage, spacePageSize: spacePageSize, forceRefresh: forceRefresh)
                return
            }
            
            // If we're loading page 1, clear the spaces array
            if spacePage == 1 {
                spaces = []
            }
        }
        
        // Reset loading states
        if spacePage == 1 {
            isLoadingSpaces = false
        } else {
            isLoadingMoreSpaces = false
        }
        print("✅ Spaces feed load completed")
    }
    
    /// Refresh spaces feed (reset and reload)
    @MainActor
    func refreshFeed() async {
        print("\n=== 🔄 REFRESHING SPACES FEED ===")
        print("📊 Current Spaces State:")
        print("- Current Spaces Page: \(currentPageSpaces)")
        print("- Has More Spaces Data: \(hasMoreDataSpaces)")
        print("- Spaces Count: \(spaces.count)")
        
        // Reset all spaces pagination state
        currentPageSpaces = 0
        hasMoreDataSpaces = true
        lastViewedSpaceIndex = 0
        lastViewedSpacePage = 1
        loadedPagesSpaces.removeAll()
        
        // loadSpacesFeed will handle setting isLoadingSpaces = true and false
        await loadSpacesFeed(spacePage: 1, forceRefresh: true)
        print("✅ Spaces feed refresh completed")
    }
    
    /// Load next page of spaces
    @MainActor
    func loadNextPage() async {
        print("\n=== 📄 LOAD NEXT PAGE SPACES CALLED ===")
        print("🔍 CURRENT STATE:")
        print("  - isLoadingSpaces: \(isLoadingSpaces)")
        print("  - isLoadingMoreSpaces: \(isLoadingMoreSpaces)")
        print("  - hasMoreDataSpaces: \(hasMoreDataSpaces)")
        print("  - currentPageSpaces: \(currentPageSpaces)")
        
        guard !isLoadingSpaces && !isLoadingMoreSpaces && hasMoreDataSpaces else {
            print("⏸️ Skipping load next page spaces:")
            print("- Spaces isLoading: \(isLoadingSpaces)")
            print("- Spaces isLoadingMore: \(isLoadingMoreSpaces)")
            print("- Spaces hasMoreData: \(hasMoreDataSpaces)")
            return
        }
        
        // Prevent loading the same page multiple times
        let nextSpacePage = currentPageSpaces + 1
        
        // Validate that we have a valid next page (should always be valid since we increment by 1)
        guard nextSpacePage > currentPageSpaces else {
            print("⚠️ Invalid next page calculation:")
            print("  - currentPageSpaces: \(currentPageSpaces)")
            print("  - calculated nextSpacePage: \(nextSpacePage)")
            return
        }
        
        print("📄 Loading next page spaces - Space Page \(nextSpacePage)")
        print("🔍 NEXT PAGE CALCULATION:")
        print("  - currentPageSpaces: \(currentPageSpaces)")
        print("  - nextSpacePage: \(nextSpacePage)")
        await loadSpacesFeed(spacePage: nextSpacePage)
    }
    
    /// Load previous page of spaces
    @MainActor
    func loadPreviousSpaces() async {
        print("\n=== ⬆️ LOAD PREVIOUS SPACES CALLED ===")
        print("🔍 PREVIOUS SPACES STATE:")
        print("  - isLoadingSpaces: \(isLoadingSpaces)")
        print("  - isLoadingMoreSpaces: \(isLoadingMoreSpaces)")
        print("  - currentPageSpaces: \(currentPageSpaces)")
        print("  - spaces.count: \(spaces.count)")
        
        // Enhanced guard conditions for loading previous spaces
        guard !isLoadingSpaces &&
              !isLoadingMoreSpaces &&
              currentPageSpaces > 1 &&
              !spaces.isEmpty else {
            print("⏸️ Skipping load previous spaces:")
            print("  - Already loading: \(isLoadingSpaces || isLoadingMoreSpaces)")
            print("  - At first page: \(currentPageSpaces <= 1)")
            print("  - No spaces: \(spaces.isEmpty)")
            return
        }
        
        let previousPage = currentPageSpaces - 1
        
        // Check if the previous page is already loaded using page tracking
        if loadedPagesSpaces.contains(previousPage) {
            print("⏸️ Skipping load previous spaces - page \(previousPage) already loaded:")
            print("  - Loaded pages: \(loadedPagesSpaces)")
            print("  - Current page: \(currentPageSpaces)")
            print("  - Previous page: \(previousPage)")
            return
        }
        
        // Validate that we have a valid previous page
        guard previousPage >= 1 else {
            print("⏸️ No valid previous page available")
            print("  - currentPageSpaces: \(currentPageSpaces)")
            print("  - calculated previousPage: \(previousPage)")
            return
        }
        
        print("⬆️ Loading previous spaces - Page \(previousPage)")
        print("🔍 PREVIOUS PAGE CALCULATION:")
        print("  - currentPageSpaces: \(currentPageSpaces)")
        print("  - previousPage: \(previousPage)")
        
        isLoadingSpaces = true
        do {
            let previousSpaces = try await listRooms(spacePage: previousPage, spacePageSize: spacePageSize)
            print("✅ Received \(previousSpaces.count) previous spaces")
            
            // Filter out duplicates before prepending
            let uniquePreviousSpaces = previousSpaces.filter { newSpace in
                !spaces.contains { $0.id == newSpace.id }
            }
            print("📊 Filtered out \(previousSpaces.count - uniquePreviousSpaces.count) duplicate previous spaces")
            
            // Prepend spaces
            spaces.insert(contentsOf: uniquePreviousSpaces, at: 0)
            
            // Update pagination state
            currentPageSpaces = previousPage
            hasMoreDataSpaces = true // Assume there might be more previous pages
            
            // Mark the previous page as loaded
            loadedPagesSpaces.insert(previousPage)
            
            print("✅ Prepended \(uniquePreviousSpaces.count) previous spaces. Current page: \(currentPageSpaces)")
            print("🔍 FINAL STATE AFTER PREPENDING:")
            print("  - currentPageSpaces: \(currentPageSpaces)")
            print("  - spaces.count: \(spaces.count)")
            print("  - hasMoreDataSpaces: \(hasMoreDataSpaces)")
            print("  - loadedPagesSpaces: \(loadedPagesSpaces)")
            
        } catch {
            print("❌ Error loading previous spaces: \(error)")
            loadErrorSpaces = error.localizedDescription
        }
        isLoadingSpaces = false
    }
    
    /// Save current position
    @MainActor
    func savePosition(index: Int) {
        lastViewedSpaceIndex = index
        lastViewedSpacePage = (index / spacePageSize) + 1
        print("💾 [savePosition] Saved position:")
        print("- Index: \(lastViewedSpaceIndex)")
        print("- Page: \(lastViewedSpacePage)")
    }
    
    /// Restore positionx
    @MainActor
    func restorePosition() -> (index: Int, page: Int) {
        print("📖 [restorePosition] Restoring position:")
        print("- Index: \(lastViewedSpaceIndex)")
        print("- Page: \(lastViewedSpacePage)")
        return (lastViewedSpaceIndex, lastViewedSpacePage)
    }
    
    /// Reset spaces loading states
    @MainActor
    func resetSpacesLoadingStates() {
        print("🔄 Resetting spaces loading states")
        isLoadingSpaces = false
        isLoadingMoreSpaces = false
    }
    
   
    
    /// Handle spaces network errors
    @MainActor
    private func handleSpacesNetworkError(_ error: Error) {
        print("❌ Spaces feed network error: \(error)")
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                loadErrorSpaces = "No internet connection. Please check your network."
            case .timedOut:
                loadErrorSpaces = "Request timed out. Please try again."
            case .cancelled:
                loadErrorSpaces = "Request was cancelled."
            default:
                loadErrorSpaces = "Network error: \(urlError.localizedDescription)"
            }
        } else {
            loadErrorSpaces = error.localizedDescription
        }
    }
    
    // MARK: - Private Methods
    

    func getRoom(hostId: Int64) async throws -> Space {
        guard let token = try KeychainManager.shared.getToken() else {
            throw APIError.unauthorized
        }
        
        // Use the correct endpoint for getting room by host ID
        let url = URL(string: "\(RoomAPI.baseURL)\(RoomAPI.Endpoints.rooms)/host/\(hostId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Add debug printing
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📦 Received JSON for host room: \(jsonString)")
        }
        
        let response = try JSONDecoder().decode(APIRoomResponseForCreate<RoomResponse>.self, from: data)
        let roomResponse = response.data
        let fetchedSpace = roomResponse.toSpace()
        
        // ✅ NEW: Sync host online status to user profiles
        await syncHostOnlineStatusToUserProfiles(spaces: [fetchedSpace])
        
        // Update all spaces with the same roomId
        await MainActor.run {
            updateSpacesWithNewData(fetchedSpace)
        }
        
        return fetchedSpace
    }
    /// List rooms from API
  func listRooms(spacePage: Int = 1, spacePageSize: Int = 20) async throws -> [Space] {
        print("\n🔄 [listRooms] Starting room list fetch")
        print("📊 Parameters:")
        print("- Space Page: \(spacePage)")
        print("- Space Page Size: \(spacePageSize)")
        
        guard let token = try KeychainManager.shared.getToken() else {
            print("❌ [listRooms] No token found")
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(RoomAPI.baseURL)\(RoomAPI.Endpoints.rooms)?page=\(spacePage)&page_size=\(spacePageSize)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🌐 [listRooms] Making request to: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Log raw response with more details
        print("\n📝 [listRooms] Raw API Response Details:")
        print("📊 HTTP Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        print("📊 Response Headers: \((response as? HTTPURLResponse)?.allHeaderFields ?? [:])")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📝 Raw JSON Response:")
            print(jsonString)
        } else {
            print("❌ Could not decode response as UTF-8 string")
        }
        
        do {
            // First try to decode the outer response structure
            let response = try JSONDecoder().decode(APIRoomResponse<RoomListResponse>.self, from: data)
            print("\n✅ [listRooms] Successfully decoded response")
            print("📊 Decoded Data:")
            print("- Code: \(response.code)")
            print("- Message: \(response.msg)")
            
            // Try to get room list from either Data or JsonResp
            let roomList: [RoomResponse]
            if let dataList = response.data.data?.list {
                print("📦 Using direct data list")
                roomList = dataList
            } else if let jsonRespList = response.data.jsonResp?.data.list {
                print("📦 Using JsonResp data list")
                roomList = jsonRespList
            } else {
                print("❌ [listRooms] No room list found in response")
                print("🔍 Response structure analysis:")
                print("- response.data.data: \(response.data.data != nil)")
                print("- response.data.jsonResp: \(response.data.jsonResp != nil)")
                if let data = response.data.data {
                    print("- data type: \(type(of: data))")
                }
                if let jsonResp = response.data.jsonResp {
                    print("- jsonResp type: \(type(of: jsonResp))")
                }
                throw APIError.unknown(error: NSError(domain: "NoRoomList", code: -1))
            }
            
            print("- Room Count: \(roomList.count)")
            
            let spaces = roomList.map { $0.toSpace() }
            print("\n🔄 [listRooms] Converted to Space objects:")
            for (index, space) in spaces.enumerated() {
                print("\nSpace \(index + 1):")
                print("- ID: \(space.id)")
                print("- Host ID: \(space.hostId)")
                print("- Host Name: \(space.host ?? "nil")")
                print("- Host Username: \(space.hostUsername ?? "nil")")
                print("- Topics: \(space.topics ?? [])")
                print("\n📢 Speakers Information:")
                print("- Total Speakers: \(space.speakers.count)")
                for (speakerIndex, speaker) in space.speakers.enumerated() {
                    print("  Speaker \(speakerIndex + 1):")
                    print("  - ID: \(speaker.id)")
                    print("  - Name: \(speaker.name ?? "nil")")
                    print("  - Username: \(speaker.username ?? "nil")")
                    print("  - Is Host: \(speaker.id == space.hostId)")
                    print("  - Is Invited: \(speaker.isInvited ?? false)")
                }
                print("\n👥 Queue Information:")
                print("- Queue ID: \(space.queue.id)")
                print("- Queue Participants: \(space.queue.participants.count)")
                print("- Is Queue Closed: \(space.queue.isClosed)")
            }
            
            // ✅ NEW: Sync host online status to user profiles
            await syncHostOnlineStatusToUserProfiles(spaces: spaces)
            
            return spaces
        } catch {
            print("❌ [listRooms] Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Missing key: \(key.stringValue), context: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch: expected \(type), context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("Value not found: expected \(type), context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
            throw error
        }
    }
    
    /// Timeout wrapper for API calls
    private func withTimeout<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        return try await withTaskCancellationHandler {
            try await operation()
        } onCancel: {
            print("⏰ API call timed out")
        }
    }
}

// MARK: - Spaces Pagination Extensions

extension SpacesViewModel {
    
    /// Check if there are more spaces to load
    var hasMoreSpaces: Bool {
        return hasMoreDataSpaces
    }
    
    /// Get current spaces page
    var currentSpacesPage: Int {
        return currentPageSpaces
    }
    
    /// Get total spaces count
    var totalSpaces: Int {
        return spaces.count
    }
    
    /// Check if spaces are currently loading
    var isSpacesLoading: Bool {
        return isLoadingSpaces
    }
    
    /// Check if more spaces are being loaded
    var isSpacesLoadingMore: Bool {
        return isLoadingMoreSpaces
    }
    
    /// Check if a specific space page is already loaded
    var isSpacePageLoaded: (Int) -> Bool {
        return { page in
            return self.loadedPagesSpaces.contains(page)
        }
    }
    
    // MARK: - User Profile Status Sync
    
    /// Sync host online status from spaces to user profiles using NotificationCenter
    /// This prevents circular dependencies by using decoupled communication
    @MainActor
    private func syncHostOnlineStatusToUserProfiles(spaces: [Space]) async {
        print("\n🔄 [syncHostOnlineStatusToUserProfiles] Starting host status sync")
        print("📊 Spaces to sync: \(spaces.count)")
        
        var updatedCount = 0
        var skippedCount = 0
        
        for space in spaces {
            let hostId = space.hostId
            let isHostOnline = space.isHostOnline
            
            print("👤 Checking host \(hostId) - Online: \(isHostOnline)")
            
            // ✅ FIXED: Use NotificationCenter to prevent circular dependency
            // Post notification for each host status update
            NotificationCenter.default.post(
                name: Notification.Name("SpaceHostStatusChanged"),
                object: nil,
                userInfo: [
                    "hostId": hostId,
                    "isOnline": isHostOnline
                ]
            )
            
            updatedCount += 1
        }
        
        print("✅ [syncHostOnlineStatusToUserProfiles] Notifications posted:")
        print("- Notifications sent: \(updatedCount)")
        print("- Total spaces processed: \(spaces.count)")
    }
}
