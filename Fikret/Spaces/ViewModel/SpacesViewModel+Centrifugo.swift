/*import Foundation
import SwiftCentrifuge
import SwiftUI

// MARK: - REST API Based Host Status Management
// This extension now uses REST API calls for host status instead of WebSocket monitoring,
// following the same pattern as Discord and WhatsApp for better scalability.
// 
// FLOW SUMMARY:
// 1. User views a space → getHostStatus(hostId) is called
// 2. REST API call to fetch current host status
// 3. Status is cached briefly (30 seconds) for efficiency
// 4. UI updates with current status from API response
// 5. Join request failures automatically mark host as offline
// 
// Key optimizations:
// - ✅ REST API calls instead of WebSocket subscriptions (no channel limits)
// - ✅ Smart caching with short timeout (30 seconds)
// - ✅ Automatic offline detection on join request failures
// - ✅ Scalable approach like Discord/WhatsApp
// - ✅ No WebSocket connection management overhead

extension SpacesViewModel {
    // MARK: - Initialization
    @MainActor
    func setupNotificationHandlers() async {
        let notifications = [
            ("SpaceJoinRequest", handleSpaceJoinRequest),
            ("RoomCreated", handleRoomCreated),
            ("UserUpdate", handleUserUpdate),
            ("EndRoom", handleRoomEnd)
            // ✅ REMOVED: HostPresenceUpdate - now using REST API approach
        ]
        
        for (name, handler) in notifications {
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let data = userInfo["data"] as? [String: Any] else { return }
                Task { @MainActor in
                    await handler(data)
                }
            }
        }
    }

 
    
    private func routeMessageToNotification(data: [String: Any]) {
        guard let type = data["type"] as? String else { return }
        
        let notificationName: NSNotification.Name
        switch type {
        case "space_join_request": notificationName = .init("SpaceJoinRequest")
        case "room_created": notificationName = .init("RoomCreated")
        case "user_update": notificationName = .init("UserUpdate")
        case "end_room": notificationName = .init("EndRoom")
        default: return
        }
        
        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: ["data": data]
        )
    }
    
    // MARK: - Simplified Presence Management
    
    @MainActor
    func updateHostSpaceState(isOnline: Bool) async {
        guard let userId = tweetData.user?.id,
              let ownSpace = getHostSpace(for: userId) else {
            return
        }
        
        do {
            if isOnline {
                // Just subscribe to channel - presence is automatic
                try await CentrifugeService.shared.connectToUserChannel(userId: userId)
            } else {
                CentrifugeService.shared.cleanupUserChannel(userId: userId)
            }
            
            // ✅ OPTIMIZED: Use existing update method for host online status
            if let spaceIndex = getSpaceIndex(for: ownSpace.id) {
                var tempSpace = spaces[spaceIndex]
                tempSpace.isHostOnline = isOnline
                spaces[spaceIndex].update(with: tempSpace, preservingFieldsFrom: spaces[spaceIndex])
                
                if spaces[spaceIndex].id == selectedSpace?.id {
                    selectedSpace = spaces[spaceIndex]
                }
            }
        } catch {
            print("❌ Spaces: Failed to update host state")
        }
    }
    
    // ✅ SIMPLIFIED: No cleanup needed - Centrifugo service handles everything automatically
    
    // MARK: - Message Handlers
    @MainActor private func handleSpaceJoinRequest(data: [String: Any]) {
        print("\n=== 🎯 HOST RECEIVED SPACE JOIN REQUEST ===")
        print("📦 Raw received data: \(data)")
        
        guard let spaceId = data["spaceId"] as? Int64,
              let userId = data["userId"] as? Int64,
              let name = data["name"] as? String,
              let image = data["image"] as? String,
              let topic = data["topic"] as? String else {
            print("❌ [handleSpaceJoinRequest] Missing required data:")
            print("  - spaceId: \(data["spaceId"] as? Int64 ?? -1)")
            print("  - userId: \(data["userId"] as? Int64 ?? -1)")
            print("  - name: \(data["name"] as? String ?? "nil")")
            print("  - image: \(data["image"] as? String ?? "nil")")
            print("  - topic: \(data["topic"] as? String ?? "nil")")
            return
        }
        
        print("✅ All required data present:")
        print("  - Space ID: \(spaceId)")
        print("  - User ID: \(userId)")
        print("  - Name: \(name)")
        print("  - Topic: \(topic)")
        
        // Update space state
        if let spaceIndex = getSpaceIndex(for: spaceId) {
            print("📊 Found space at index: \(spaceIndex)")
            var updatedSpace = spaces[spaceIndex]
            
            // Check if we're the host of this space
            if let currentUserId = tweetData.user?.id,
               currentUserId == updatedSpace.hostId {
                print("✅ [handleSpaceJoinRequest] Current user is host of this space")
                
                // Update selected space if needed
                if selectedSpace?.id != spaceId {
                    print("🔄 [handleSpaceJoinRequest] Updating selected space to match current space")
                    selectedSpace = updatedSpace
                }
                
                // Start the space if it's the first user
                if updatedSpace.speakers.count == 1 {
                    Task { @MainActor in
                        await startSpace(id: spaceId,userId: userId)
                    }
                }
            }
        }
    }

    @MainActor private func handleRoomCreated(data: [String: Any]) {
        print("\n=== 🏠 HOST RECEIVED ROOM CREATED MESSAGE ===")
        print("📦 Raw received data: \(data)")
        
        guard let roomId = data["hmsRoomId"] as? String,
              let spaceId = data["spaceId"] as? Int64 else {
            print("❌ Missing required data in room created message")
            print("  - hmsRoomId: \(data["hmsRoomId"] ?? "nil")")
            print("  - spaceId: \(data["spaceId"] ?? "nil")")
            return
        }
        
        print("✅ Room created data:")
        print("  - Room ID: \(roomId)")
        print("  - Space ID: \(spaceId)")
        
        // Check if we're already in this room
        if let currentSpace = selectedSpace,
           currentSpace.hmsRoomId == roomId {
            print("⚠️ Already in this room - ignoring duplicate message")
            return
        }
        
        // Check if we're already processing a room creation
        if isHandlingRoomCreation {
            print("🔄 [handleRoomCreated] Already handling room creation, skipping")
            return
        }
        
        print("✅ [handleRoomCreated] All required data present")
        print("  - Room ID: \(roomId)")
        print("  - Space ID: \(spaceId)")
        
        // Set room creation flag
        isHandlingRoomCreation = true
        
        // Update space state with room ID
        if let spaceIndex = getSpaceIndex(for: spaceId) {
            print("📊 Found space at index: \(spaceIndex)")
            
            // ✅ OPTIMIZED: Use existing update method for HMS room ID
            var tempSpace = spaces[spaceIndex]
            tempSpace.hmsRoomId = roomId
            spaces[spaceIndex].update(with: tempSpace, preservingFieldsFrom: spaces[spaceIndex])
            
            if spaces[spaceIndex].id == selectedSpace?.id {
                selectedSpace?.update(with: spaces[spaceIndex], preservingFieldsFrom: selectedSpace!)
            }
            
            print("✅ Updated space with room ID: \(roomId)")
            
            // Join the call with the new room ID
            Task { @MainActor in
                print("🔄 Joining call with room ID: \(roomId)")
                await self.joinCall(roomId: roomId)
                // Reset room creation flag after joining
                isHandlingRoomCreation = false
                print("✅ Reset room creation flag")
            }
        } else {
            print("❌ Space not found with ID: \(spaceId)")
            // Reset room creation flag if space not found
            isHandlingRoomCreation = false
        }
        
        print("=== END ROOM CREATED PROCESSING ===\n")
    }

    @MainActor private func handleUserUpdate(data: [String: Any]) async {
        guard let userId = data["id"] as? Int64,
              let spaceId = data["spaceId"] as? Int64 else {
            print("❌ [handleUserUpdate] Invalid data format")
            return
        }
        
        if let spaceIndex = getSpaceIndex(for: spaceId) {
            if let action = data["action"] as? String {
                switch action {
                case "remove":
                    // ✅ OPTIMIZED: Use existing update method for speakers
                    var tempSpace = spaces[spaceIndex]
                    tempSpace.speakers.removeAll { $0.id == userId }
                    spaces[spaceIndex].update(with: tempSpace, preservingFieldsFrom: spaces[spaceIndex])
                    
                    // If this is the current user being removed, leave the space
                    if let currentUserId = await tweetData.user?.id, currentUserId == userId {
                        Task {
                            await leaveSpace(id: spaceId)
                        }
                    }
                    
                default:
                    print("⚠️ [handleUserUpdate] Unknown action: \(action)")
                    break
                }
            }
            
            // Update selectedSpace if it's the same space
            if selectedSpace?.id == spaceId {
                selectedSpace?.update(with: spaces[spaceIndex], preservingFieldsFrom: selectedSpace!)
            }
            
            print("✅ [handleUserUpdate] Space updated successfully")
            
            // Notify UI of changes
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } else {
            print("❌ [handleUserUpdate] Space not found with ID: \(spaceId)")
        }
    }

    @MainActor private func handleRoomEnd(data: [String: Any]) {
        print("🔚 [handleRoomEnd] Processing room end")
        guard let spaceId = data["spaceId"] as? Int64 else {
            print("❌ [handleRoomEnd] Invalid data format")
            return
        }
        
        print("✅ [handleRoomEnd] Room ended for space: \(spaceId)")
        
        if let spaceIndex = getSpaceIndex(for: spaceId) {
            // ✅ OPTIMIZED: Use existing update method to clear HMS room ID
            var tempSpace = spaces[spaceIndex]
            tempSpace.hmsRoomId = nil
            spaces[spaceIndex].update(with: tempSpace, preservingFieldsFrom: spaces[spaceIndex])
            
            if selectedSpace?.id == spaceId {
                selectedSpace?.update(with: spaces[spaceIndex], preservingFieldsFrom: selectedSpace!)
                isInSpace = false
                showSpaceView = false
                
                // Only set wasEndedByHost to true for non-hosts (visitors)
                if !isHost {
                    wasEndedByHost = true
                }
            }
        }
    }
    
    // ✅ REMOVED: handleHostPresenceUpdate - now using REST API approach
    
    // MARK: - Status Management
    
    @MainActor
    func setupUserOnlineStatus() {
        guard let currentUserId = tweetData.user?.id else { return }
        // Just connect to user channel - presence is automatic
        Task {
            try? await CentrifugeService.shared.connectToUserChannel(userId: currentUserId)
        }
    }
    
    @MainActor
    func removeUserOnlineStatus() {
        guard let currentUserId = tweetData.user?.id else { return }
        CentrifugeService.shared.cleanupUserChannel(userId: currentUserId)
    }
    
    
    func checkHostStatusPassive(hostId: Int64) async throws -> (isOnline: Bool, currentSpaceId: Int64?) {
        // ✅ SIMPLIFIED: Always check the Space model first - it's our single source of truth
        if let spaceId = hostIdToSpaceId[hostId],
           let spaceIndex = spaceIdsToIndex[hostId] {
            let space = spaces[spaceIndex]
            print("📡 Using Space model host status for space \(spaceId): \(space.isHostOnline ? "online" : "offline")")
            return (space.isHostOnline, spaceId)
        }
        
        // If no space found, start monitoring
        if activePresenceSubscriptions != hostId {
            startMonitoringHostStatus(hostId: hostId)
        }
        
        // ❌ NO CACHE FALLBACK: If WebSocket unavailable, we don't know the real status
        // Returning false would be misleading - better to indicate "unknown" status
        print("⚠️ No space found for host \(hostId) and no real-time data available")
        return (false, nil) // Indicates "unknown" status
    }
    
    // MARK: - Real-time Presence Updates
    
    /// Handle real-time presence updates from WebSocket connections
    /// This is called automatically when users come online/offline
    @MainActor
    func handlePresenceUpdate(hostId: Int64, isOnline: Bool) {
        // ✅ NO CACHE NEEDED: We only use real-time WebSocket data
        // Update UI immediately with real-time status
        updateHostStatusInSpaces(hostId: hostId, isOnline: isOnline)
        
        print("🔄 Real-time presence update: Host \(hostId) is \(isOnline ? "online" : "offline")")
    }
    
    // MARK: - Real-time Status Monitoring
    
    /// Start monitoring host status in real-time for the current viewing space
    func startHostStatusMonitoring(for hostId: Int64) {
        print("🔄 Starting host status monitoring for host: \(hostId)")
        
        // Stop monitoring any previous host
        if let previousHostId = activePresenceSubscriptions {
            stopMonitoringHostStatus(hostId: previousHostId)
        }
        
        // Start monitoring the new host
        startMonitoringHostStatus(hostId: hostId)
        
        print("✅ Host status monitoring active for host: \(hostId)")
    }
    
    /// Stop monitoring host status for a single host
    func stopHostStatusMonitoring(for hostId: Int64) {
        stopMonitoringHostStatus(hostId: hostId)
    }
    
    /// Start monitoring a specific host's status
    private func startMonitoringHostStatus(hostId: Int64) {
        guard let centrifugeClient = CentrifugeService.shared.chatClient else {
            return
        }
        
        let userChannelName = "user:\(hostId)"
        let sub = try? centrifugeClient.newSubscription(channel: userChannelName, delegate: CentrifugeService.shared)
        guard let sub = sub else {
            return
        }
        
        // Note: onPresence is handled by CentrifugeService delegate
        // The subscription will automatically handle presence updates through the delegate
        
        // Subscribe to presence updates
        do {
            try sub.subscribe()
            activePresenceSubscriptions = hostId
        } catch {
            print("❌ Spaces: Failed to monitor host \(hostId)")
        }
    }
    
    /// Stop monitoring a specific host's status
    private func stopMonitoringHostStatus(hostId: Int64) {
        // Always allow stopping monitoring, regardless of which host is currently monitored
        // This is safer and more flexible than the previous guard check
        
        // If this is the currently monitored host, clear it
        if activePresenceSubscriptions == hostId {
            activePresenceSubscriptions = nil
            print("🛑 Stopped monitoring currently active host: \(hostId)")
        } else {
            print("🛑 Requested to stop monitoring host \(hostId), but currently monitoring host: \(activePresenceSubscriptions ?? 0)")
        }
    }
    
    /// Update host status in spaces array - always update Space model as single source of truth
    @MainActor
    private func updateHostStatusInSpaces(hostId: Int64, isOnline: Bool) {
        // ✅ SIMPLIFIED: Always update Space model - it's our single source of truth
        if let spaceId = hostIdToSpaceId[hostId],
           let spaceIndex = spaceIdsToIndex[spaceId] {
            
            // Always update the Space model's isHostOnline field
            var tempSpace = spaces[spaceIndex]
            tempSpace.isHostOnline = isOnline
            spaces[spaceIndex].update(with: tempSpace, preservingFieldsFrom: spaces[spaceIndex])
            
            print("🔄 Updated host status in Space model: Host \(hostId) is \(isOnline ? "online" : "offline")")
        }
        
        // Notify UI of changes
        objectWillChange.send()
    }
    
    /// Get host status (always prioritizing Space model as single source of truth)
    func getHostStatus(hostId: Int64) -> Bool {
        // ✅ SIMPLIFIED: Always check Space model first - it's our single source of truth
        if let spaceId = hostIdToSpaceId[hostId],
           let spaceIndex = spaceIdsToIndex[hostId] {
            return spaces[spaceIndex].isHostOnline
        }
        
        // ❌ NO CACHE FALLBACK: If no space found, we don't know the real status
        // Returning false would be misleading - better to indicate "unknown" status
        print("⚠️ No space found for host \(hostId) - cannot determine status")
        return false // Indicates "unknown" status
    }
    
    /// Get the currently monitored host ID (if any)
    func getCurrentlyMonitoredHost() -> Int64? {
        return activePresenceSubscriptions
    }
    
    /// Clear active presence subscription
    func clearHostStatusCache() {
        // ✅ NO CACHE TO CLEAR: We only use real-time WebSocket data
        activePresenceSubscriptions = nil
        print("🔄 Cleared active presence subscription")
    }
} 
*/
