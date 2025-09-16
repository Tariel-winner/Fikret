import Foundation
import Ably
import SwiftUI

extension SpacesViewModel {
    // MARK: - Initialization
    @MainActor
    func setupNotificationHandlers() {
        // Handle space join requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SpaceJoinRequest"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let data = userInfo["data"] as? [String: Any] else {
                print("❌ [SpaceJoinRequest] Invalid notification data")
                return
            }
            print("✅ [SpaceJoinRequest] Received notification, processing...")
            self.handleSpaceJoinRequest(data: data)
        }
        
        // Handle room creation
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RoomCreated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let data = userInfo["data"] as? [String: Any] else { return }
            self.handleRoomCreated(data: data)
        }
        
        // Handle user updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let data = userInfo["data"] as? [String: Any] else { return }
            self.handleUserUpdate(data: data)
        }
        
        // Handle room end
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("EndRoom"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let data = userInfo["data"] as? [String: Any] else { return }
            self.handleRoomEnd(data: data)
        }
    }

    @MainActor
    func updateHostSpaceState(isOnline: Bool) async {
        print("🔄 [updateHostSpaceState] Starting host state update")
        print("🔄 [updateHostSpaceState] Is online: \(isOnline)")
        
        guard let userId = tweetData.user?.id,
              let ownSpace = spaces.first(where: { $0.hostId == userId }) else {
            print("❌ [updateHostSpaceState] No user ID or own space found")
            return
        }
        
        print("👤 [updateHostSpaceState] User ID: \(userId)")
        print("🏠 [updateHostSpaceState] Space ID: \(ownSpace.id)")
        
        do {
            guard let ablyClient = AblyService.shared.chatClient else {
                print("❌ [updateHostSpaceState] Ably client not initialized")
                return
            }
            
            // Use own user channel for presence
            let userChannelName = "user:\(userId)"
            print("📡 [updateHostSpaceState] Using user channel: \(userChannelName)")
            let userChannel = ablyClient.channels.get(userChannelName)
            
            if isOnline {
                print("📤 [updateHostSpaceState] Entering presence as host")
                let hostData: [String: Any] = [
                    "id": userId,
                    "role": "host",
                    "isOnline": true
                ]
                userChannel.presence.enter(hostData)
            } else {
                print("📤 [updateHostSpaceState] Leaving presence")
                userChannel.presence.leave(["id": userId, "role": "host"])
            }
            
            // Update local state
            if let spaceIndex = spaces.firstIndex(where: { $0.id == ownSpace.id }) {
                print("🔄 [updateHostSpaceState] Updating local space state")
                var updatedSpace = spaces[spaceIndex]
                updatedSpace.isHostOnline = isOnline
                spaces[spaceIndex] = updatedSpace
                
                if updatedSpace.id == selectedSpace?.id {
                    print("🔄 [updateHostSpaceState] Updating selected space")
                    selectedSpace = updatedSpace
                }
            }
            
            print("✅ [updateHostSpaceState] Successfully updated host state")
            
        } catch {
            print("❌ [updateHostSpaceState] Error: \(error)")
        }
    }
 
    func handleSpacePresence(_ presence: ARTPresenceMessage) {
        guard let data = presence.data as? [String: Any],
              let channelName = presence.clientId,
              let spaceId = Int64(channelName.split(separator: ":").last ?? ""),
              let spaceIndex = spaces.firstIndex(where: { $0.id == spaceId }) else { return }
        
        switch presence.action {
        case .enter:
            if let userId = data["id"] as? Int64,
               let role = data["role"] as? String,
               role == "host" {
                // Update host online state
                var updatedSpace = spaces[spaceIndex]
                updatedSpace.isHostOnline = true
                spaces[spaceIndex] = updatedSpace
                
                if updatedSpace.id == selectedSpace?.id {
                    selectedSpace = updatedSpace
                }
            }
        case .leave:
            if let userId = data["id"] as? Int64,
               let role = data["role"] as? String,
               role == "host" {
                // Update host offline state
                var updatedSpace = spaces[spaceIndex]
                updatedSpace.isHostOnline = false
                spaces[spaceIndex] = updatedSpace
                
                if updatedSpace.id == selectedSpace?.id {
                    selectedSpace = updatedSpace
                }
                
                // Handle host state change
                Task {
                    await handleHostStateChange(spaceId: spaceId, hostId: userId, isOnline: false)
                }
            }
        case .update:
            // Handle presence update if needed
            break
        @unknown default:
            // Handle any future cases
            break
        }
    }
    
    // MARK: - New Methods
    func setupActiveChannelForSpace(space: Space) {
        guard let ablyClient = AblyService.shared.chatClient else { return }
        
        // Use host's user channel
        let hostChannelName = "user:\(space.hostId)"
        let hostChannel = ablyClient.channels.get(hostChannelName)
        
        // Set up presence monitoring
        hostChannel.presence.subscribe { [weak self] presence in
            self?.handleSpacePresence(presence)
        }
        
        print("📊 Created active channel for space \(space.id)")
    }
    
    func checkAndCleanupSpaceChannel(space: Space) {
        // Get current presence members from host's user channel
        let userChannelName = "user:\(space.hostId)"
        print("📡 [checkAndCleanupSpaceChannel] Checking host's user channel: \(userChannelName)")
        if let userChannel = AblyService.shared.chatClient?.channels.get(userChannelName) {
            userChannel.presence.get { [weak self] members, error in
                guard let self = self,
                      let members = members else { return }
                
                // If only host is present, cleanup channel
                if members.count <= 1 {
                    self.cleanupSpaceChannel()
                    print("📊 Cleaned up channel for space \(space.id) - no active participants")
                }
            }
        }
    }
    
    func checkHostCurrentState(hostId: Int64) async throws -> (isInQueue: Bool, isInSpace: Bool, spaceId: Int64?) {
        guard let ablyClient = AblyService.shared.chatClient else {
            throw NSError(domain: "AblyError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ably client not initialized"])
        }
        
        // Check all presence channels for the host
        let otherHostSpaces = self.spaces.filter { $0.hostId != hostId } // Exclude own space
        var isInQueue = false
        var isInSpace = false
        var currentSpaceId: Int64?
        
        for space in otherHostSpaces {
            let presenceChannelName = "presence:\(space.id)"
            let presenceChannel = ablyClient.channels.get(presenceChannelName)
            
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    presenceChannel.presence.get { members, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        if let members = members,
                           let hostMember = members.first(where: { member in
                               if let data = member.data as? [String: Any],
                                  let memberId = data["id"] as? Int64 {
                                   return memberId == hostId
                               }
                               return false
                           }) {
                            if let data = hostMember.data as? [String: Any],
                               let role = data["role"] as? String {
                                if role == "host" {
                                    isInSpace = true
                                    currentSpaceId = space.id
                                } else if role == "participant" {
                                    isInQueue = true
                                    currentSpaceId = space.id
                                }
                            }
                        }
                        continuation.resume()
                    }
                }
            } catch {
                print("❌ Error checking presence for space \(space.id): \(error)")
            }
        }
        
        return (isInQueue, isInSpace, currentSpaceId)
    }

    func cleanupSpaceChannel() {
        spaceChannel?.unsubscribe()
        spaceChannel = nil
    }
    
    func handleHostStateChange(spaceId: Int64, hostId: Int64, isOnline: Bool) async {
        // If host goes offline (joins another space), we need to handle the queue state
        if !isOnline {
            do {
                let hostState = try await checkHostCurrentState(hostId: hostId)
                if hostState.isInSpace || hostState.isInQueue {
                    // Host is in another space/queue, update their own space
                    if let ownSpace = spaces.first(where: { $0.hostId == hostId }) {
                        var updatedSpace = ownSpace
                        updatedSpace.isHostOnline = false
                        
                        if let spaceIndex = spaces.firstIndex(where: { $0.id == ownSpace.id }) {
                            spaces[spaceIndex] = updatedSpace
                            
                            if updatedSpace.id == selectedSpace?.id {
                                selectedSpace = updatedSpace
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error checking host state: \(error)")
            }
        }
    }

    // MARK: - Message Handlers
    @MainActor private func handleSpaceJoinRequest(data: [String: Any]) {
        print("\n=== HANDLING SPACE JOIN REQUEST ===")
        print("🔍 [handleSpaceJoinRequest] Starting join request processing")
        print("📦 [handleSpaceJoinRequest] Raw received data: \(data)")
        
        // Log all keys in the data
        print("🔑 [handleSpaceJoinRequest] Available keys in data:")
        data.keys.forEach { key in
            print("  - \(key): \(data[key] ?? "nil")")
        }
        
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
        
        print("✅ [handleSpaceJoinRequest] All required data present")
        print("  - Space ID: \(spaceId)")
        print("  - User ID: \(userId)")
        print("  - Name: \(name)")
        print("  - Topic: \(topic)")
        
        // Update space state
        if let spaceIndex = spaces.firstIndex(where: { $0.id == spaceId }) {
            print("📊 [handleSpaceJoinRequest] Found space at index: \(spaceIndex)")
            
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
                    print("🎯 [handleSpaceJoinRequest] First user joined - initiating space start")
                    print("🎯 [handleSpaceJoinRequest] Selected space before start: \(selectedSpace?.id ?? -1)")
                    
                    Task { @MainActor in
                        print("🎯 [handleSpaceJoinRequest] Starting space with ID: \(spaceId)")
                        await startSpace(id: spaceId,userId: userId)
                    }
                } else {
                    print("📊 [handleSpaceJoinRequest] Not first user")
                }
            } else {
                print("📊 [handleSpaceJoinRequest] Not host of this space - updating space only")
                // If not host, update the space in the array
                var updatedSpace = spaces[spaceIndex]
                spaces[spaceIndex] = updatedSpace
            }
        } else {
            print("❌ [handleSpaceJoinRequest] Space not found with ID: \(spaceId)")
            print("📊 [handleSpaceJoinRequest] Available spaces: \(spaces.map { $0.id })")
        }
    }

    private func handleRoomCreated(data: [String: Any]) {
        print("\n=== HANDLING ROOM CREATED ===")
        print("🔍 [handleRoomCreated] Starting room creation processing")
        print("📦 [handleRoomCreated] Received data: \(data)")
        
        guard let roomId = data["hmsRoomId"] as? String,
              let spaceId = data["spaceId"] as? Int64 else {
            print("❌ [handleRoomCreated] Missing required data:")
            print("  - hmsRoomId: \(data["hmsRoomId"] as? String ?? "nil")")
            print("  - spaceId: \(data["spaceId"] as? Int64 ?? -1)")
            return
        }
        
        // Check if we're already in this room
        if let currentSpace = selectedSpace,
           currentSpace.hmsRoomId == roomId {
            print("🔄 [handleRoomCreated] Already in this room, skipping")
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
        if let spaceIndex = spaces.firstIndex(where: { $0.id == spaceId }) {
            print("📊 [handleRoomCreated] Found space at index: \(spaceIndex)")
            var updatedSpace = spaces[spaceIndex]
            print("📊 [handleRoomCreated] Previous room ID: \(updatedSpace.hmsRoomId ?? "nil")")
            
            updatedSpace.hmsRoomId = roomId
            spaces[spaceIndex] = updatedSpace
            
            if updatedSpace.id == selectedSpace?.id {
                print("🔄 [handleRoomCreated] Updating selected space")
                print("🔄 [handleRoomCreated] Selected space before update: \(selectedSpace?.hmsRoomId ?? "nil")")
                selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: selectedSpace!)
                print("✅ [handleRoomCreated] Selected space updated with new room ID: \(selectedSpace?.hmsRoomId ?? "nil")")
            }
            
            print("✅ [handleRoomCreated] Successfully updated space with room ID")
            print("📊 [handleRoomCreated] Current space state:")
            print("  - Space ID: \(updatedSpace.id)")
            print("  - Room ID: \(updatedSpace.hmsRoomId ?? "nil")")
            
            // Join the call with the new room ID
            print("🔄 [handleRoomCreated] Joining call with room ID: \(roomId)")
            Task { @MainActor in
                 try await  self.joinCall(roomId: roomId)
                // Reset room creation flag after joining
                isHandlingRoomCreation = false
            }
        } else {
            print("❌ [handleRoomCreated] Space not found with ID: \(spaceId)")
            print("📊 [handleRoomCreated] Available spaces: \(spaces.map { $0.id })")
            // Reset room creation flag if space not found
            isHandlingRoomCreation = false
        }
    }

    @MainActor private func handleUserUpdate(data: [String: Any]) {
        print("👤 [handleUserUpdate] Processing user update")
        print("📦 [handleUserUpdate] Raw data: \(data)")
        
        guard let userId = data["id"] as? Int64,
              let spaceId = data["spaceId"] as? Int64 else {
            print("❌ [handleUserUpdate] Invalid data format")
            return
        }
        
        print("✅ [handleUserUpdate] Processing update for user \(userId) in space \(spaceId)")
        
        if let spaceIndex = spaces.firstIndex(where: { $0.id == spaceId }) {
            var updatedSpace = spaces[spaceIndex]
            
            if let action = data["action"] as? String {
                print("🔍 [handleUserUpdate] Action: \(action)")
                
                switch action {
                case "remove":
                    print("🚫 [handleUserUpdate] Processing remove action for user \(userId)")
                    
               
                    
                default:
                    print("⚠️ [handleUserUpdate] Unknown action: \(action)")
                    break
                }
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
      
    }



      @MainActor
    func processPresenceMembers(_ members: [ARTPresenceMessage]?, targetSpaceId: Int64) {
        // ✅ 100% RACE CONDITION PROTECTION: Use passed targetSpaceId instead of searching
        print("🎯 [MONITORING] Processing presence for target space ID: \(targetSpaceId)")
        
        // Find the space using the guaranteed targetSpaceId
        guard let spaceIndex = spaces.firstIndex(where: { $0.id == targetSpaceId }) else {
            print("❌ [MONITORING] Target space not found with ID: \(targetSpaceId)")
            return
        }
        
        // ✅ CHECK: Look for spaceId in members to determine if participants exist
        var foundSpaceIdInMembers = false
        print("🔍 [MONITORING] Checking \(members?.count ?? 0) members for spaceId: \(targetSpaceId)")
        
        for member in members ?? [] {
            if let data = member.data as? [String: Any],
               let memberSpaceId = data["spaceId"] as? Int64 {
                print("🔍 [MONITORING] Member has spaceId: \(memberSpaceId)")
                if memberSpaceId == targetSpaceId {
                    foundSpaceIdInMembers = true
                    print("✅ [MONITORING] Found matching spaceId in member")
                    break
                }
            }
        }
        
        // ✅ EARLY RETURN: If no spaceId found in members, it means only host exists
        if !foundSpaceIdInMembers {
            print("🎯 [MONITORING] No spaceId found in members - only host exists in space \(targetSpaceId)")
            
            // ✅ IMMEDIATE CLEANUP: Clear topics and keep only host
            var updatedSpace = spaces[spaceIndex]
            
            // Clear topics
            updatedSpace.topics = []
            currentTopic = ""
            
            // Keep only the host in speakers array
            updatedSpace.speakers = updatedSpace.speakers.filter { speaker in
                speaker.id == updatedSpace.hostId
            }
            
            // Update the space
            spaces[spaceIndex] = updatedSpace
            
            // Update currentViewingSpace if it matches
            if currentViewingSpace?.id == updatedSpace.id {
                currentViewingSpace?.update(with: updatedSpace, preservingFieldsFrom: currentViewingSpace!)
            }
            
            print("✅ [MONITORING] Cleanup complete - only host remains in space \(targetSpaceId)")
            print("✅ [MONITORING] Topics cleared, speakers: \(updatedSpace.speakers.count)")
            return
        }
        
        // ✅ NORMAL FLOW: Participants exist, proceed with normal processing
        print("🎯 [MONITORING] Participants found, processing normally for space ID: \(targetSpaceId)")
        
        // Get current participants from presence
        let currentParticipants = members?.filter { member in
            if let data = member.data as? [String: Any],
               let role = data["role"] as? String {
                return role == "participant"
            }
            return false
        } ?? []
        
        // ✅ FIXED: Simpler logic - keep host, replace non-host participants
        var updatedSpace = spaces[spaceIndex]
        
        // Keep only the host in speakers array
        updatedSpace.speakers = updatedSpace.speakers.filter { speaker in
            speaker.id == updatedSpace.hostId
        }
        
        // Add current participants from presence (if any exist)
        var foundTopic: String? = nil
        
        for member in currentParticipants {
            if let data = member.data as? [String: Any],
               let userId = data["id"] as? Int64,
               let name = data["name"] as? String,
               let image = data["image"] as? String {
                
                let participantTopic = data["topic"] as? String
                let participant = SpaceParticipant(
                    id: userId,
                    name: name,
                    username: name,
                    imageURL: image,
                    peerID: nil,
                    topic: participantTopic,
                    isOnline: true
                )
                updatedSpace.speakers.append(participant)
                
                // ✅ FIXED: Store the first topic we find from participants
                if foundTopic == nil, let topic = participantTopic, !topic.isEmpty {
                    foundTopic = topic
                    print("🎯 [MONITORING] Found topic from participant: \(topic)")
                }
                
                print("✅ [MONITORING] Added participant: \(name) (ID: \(userId))")
                
                // ✅ ADDED: Update spaces with user online status when processing presence
                Task {
                    await updateSpacesWithUserOnlineStatus(userId: userId, isOnline: true)
                }
            }
        }
        
        // ✅ FIXED: Update the space's topic if we found one from participants
        if let topic = foundTopic {
            updatedSpace.topics = [topic] // Update the space's topics array
            currentTopic = topic // ✅ FIXED: Also update currentTopic for UI display
        } else {
            // ✅ FIXED: Clear topic when no participants (only host)
            updatedSpace.topics = []
            currentTopic = ""
        }
        
        // Update the space
        spaces[spaceIndex] = updatedSpace
        
        // ✅ FIXED: Update currentViewingSpace if it matches the updated space
        if currentViewingSpace?.id == updatedSpace.id {
            currentViewingSpace?.update(with: updatedSpace, preservingFieldsFrom: currentViewingSpace!)
        }
        
        print("✅ [MONITORING] Updated speakers for space \(targetSpaceId) - Total: \(updatedSpace.speakers.count)")
        print("✅ [MONITORING] Speaker IDs: \(updatedSpace.speakers.map { $0.id })")
    }
    
}
