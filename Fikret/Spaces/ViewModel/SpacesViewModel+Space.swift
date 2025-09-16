//
//  SpacesViewModel+Space.swift
//  Spaces
//
//  Created by Stefan Blos on 01.03.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//
import Foundation
import HMSSDK
//import SendbirdChatSDK  // Add this import
import SwiftUI
//import Supabase
import CryptoKit
//import FirebaseFirestore
import Ably  // Add Ably import
import LiveKit
/*
extension SpacesViewModel {
  
    @MainActor
    private func cleanupHostChannel(_ hostChannel: ARTRealtimeChannel, userId: Int64) {
        print("🧹 Cleaning up host channel...")
        hostChannel.unsubscribe()
        hostChannel.presence.unsubscribe()
        hostChannel.presence.leave(["id": userId, "role": "participant"]) { error in
            if let error = error {
                print("❌ Failed to leave presence: \(error)")
            } else {
                print("✅ Successfully left presence")
            }
        }
        hostChannel.detach { error in
            if let error = error {
                print("❌ Failed to detach from host channel: \(error)")
            } else {
                print("✅ Successfully detached from host channel")
            }
        }
    }

    @MainActor
    private func attachToHostChannel(_ hostChannel: ARTRealtimeChannel, currentUser: UserProfile) async throws {
        print("📡 [joinSpace] Attaching to host channel...")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            hostChannel.attach { error in
                if let error = error {
                    print("❌ [joinSpace] Failed to attach to host channel: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ [joinSpace] Successfully attached to host channel")
                    continuation.resume()
                }
            }
        }
        
        // Enter presence as participant
        let participantData: [String: Any] = [
            "id": currentUser.id,
            "role": "participant",
            "isOnline": true
        ]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            hostChannel.presence.enter(participantData) { error in
                if let error = error {
                    print("❌ [joinSpace] Failed to enter presence: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ [joinSpace] Entered presence as participant")
                    continuation.resume()
                }
            }
        }
        
        // Set up message subscription
        print("📡 [joinSpace] Setting up message subscription on host channel")
        hostChannel.subscribe { [weak self] message in
            print("📨 [joinSpace] Received message on host channel: \(message.name)")
            print("📦 [joinSpace] Message data: \(message.data ?? "nil")")
            
         
            
            // Process messages based on channel type
            if let data = message.data as? [String: Any] {
                let messageChannelType = data["channelType"] as? String
                let targetUserId = data["targetUserId"] as? Int64
                
                // Only process if message is for current user or from own channel
                let shouldProcess = targetUserId == currentUser.id || messageChannelType == "own"
                
                guard shouldProcess else {
                    print("📨 [joinSpace] Ignoring message - not intended for current user")
                    print("  - Target User ID: \(targetUserId ?? -1)")
                    print("  - Current User ID: \(currentUser.id)")
                    print("  - Channel Type: \(messageChannelType ?? "unknown")")
                    return
                }
                
                switch message.name {
                case "room_created":
                    print("🏠 [joinSpace] Received room created message")
                    if let roomId = data["hmsRoomId"] as? String,
                       let spaceId = data["spaceId"] as? Int64,
                       let targetUserId = data["targetUserId"] as? Int64,
                       targetUserId == currentUser.id {
                        print("✅ [joinSpace] Room created message is for current user")
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RoomCreated"),
                            object: nil,
                            userInfo: data
                        )
                    }
                case "user_update":
                    print("👤 [joinSpace] Received user update")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UserUpdate"),
                        object: nil,
                        userInfo: data
                    )
                case "end_room":
                    print("🔚 [joinSpace] Received end room")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("EndRoom"),
                        object: nil,
                        userInfo: data
                    )
                case "space_join_request":
                    // Only process join requests if we are the host
                    if let targetUserId = data["targetUserId"] as? Int64 {
                        print("👥 [joinSpace] Processing join request as host")
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SpaceJoinRequest"),
                            object: nil,
                            userInfo: ["data": data]
                        )
                    }
                default:
                    print("📨 [joinSpace] Received unknown message type: \(message.name)")
                }
            }
        }
        
        // Set up presence subscription
        print("👥 [joinSpace] Setting up presence subscription")
        hostChannel.presence.subscribe { [weak self] presence in
            print("👥 [joinSpace] Received presence update: \(presence.action)")
            self?.handleSpacePresence(presence)
        }
    }
    
    @MainActor
    private func checkHostPresence(_ hostChannel: ARTRealtimeChannel, space: Space) async throws {
        print("👥 [joinSpace] Checking host presence...")
        let members = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ARTPresenceMessage]?, Error>) in
            hostChannel.presence.get { members, error in
                if let error = error {
                    print("❌ [joinSpace] Failed to get presence: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: members)
                }
            }
        }
        
        print("👥 [joinSpace] Current presence members: \(members?.count ?? 0)")
        if let members = members {
            for member in members {
                print("- Member: \(member.clientId ?? "unknown")")
                if let data = member.data as? [String: Any] {
                    print("  Data: \(data)")
                }
            }
        }
        
        // Count active participants (excluding host)
        let activeParticipants = members?.filter { member in
            if let data = member.data as? [String: Any],
               let role = data["role"] as? String {
                return role == "participant"
            }
            return false
        } ?? []
        
        print("👥 [joinSpace] Active participants: \(activeParticipants.count)")
        
        // If there are already 2 participants, prevent joining
        if activeParticipants.count >= 2 {
            print("❌ [joinSpace] Space is full (2 participants already present)")
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Space is currently full. Please try again later."])
        }
        
        // Check if host is present
        let isHostPresent = members?.contains { member in
            if let data = member.data as? [String: Any],
               let memberId = data["id"] as? Int64,
               let role = data["role"] as? String {
                return memberId == space.hostId && role == "host"
            }
            return false
        } ?? false
        
        if !isHostPresent {
            print("❌ [joinSpace] Host not present")
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Host not present"])
        }
        print("✅ [joinSpace] Host is present")
    }
    
    @MainActor
    private func waitForRoomId(spaceId: Int64) async -> String? {
        print("⏳ Waiting for room ID from host...")
        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            var observer: NSObjectProtocol?
            var hasResumed = false
            
            Task {
                observer = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("RoomCreated"),
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let self = self else { return }
                    
                    print("📨 Received RoomCreated notification")
                    print("📦 Notification userInfo: \(notification.userInfo ?? [:])")
                    
                    if let userInfo = notification.userInfo,
                       let roomId = userInfo["hmsRoomId"] as? String,
                       let spaceId = userInfo["spaceId"] as? Int64,
                       spaceId == spaceId {
                        print("✅ Room ID received: \(roomId)")
                        print("🔍 Space ID match: \(spaceId)")
                        
                        if let spaceIndex = self.spaces.firstIndex(where: { $0.id == spaceId }) {
                            var updatedSpace = self.spaces[spaceIndex]
                            updatedSpace.hmsRoomId = roomId
                            self.spaces[spaceIndex] = updatedSpace
                            self.selectedSpace = updatedSpace
                            print("✅ Updated space with room ID: \(roomId)")
                        }
                        
                        if let observer = observer {
                            NotificationCenter.default.removeObserver(observer)
                        }
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(returning: roomId)
                        }
                    }
                }
                
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    @MainActor
    func joinSpace(id: Int64) async {
        print("\n=== JOINING SPACE ===")
        print("🔄 Space ID: \(id)")
        
        guard let currentUser = await tweetData.user else {
            print("❌ No user found")
            return
        }
        
        // Use currentViewingSpace instead of selectedSpace for visitor interactions
        guard let space = currentViewingSpace else {
            print("❌ No current viewing space")
            return
        }
        print("✅ Found space and user")
        print("👤 Current user ID: \(currentUser.id)")
        
        // Store current user's channel for cleanup
        let ownChannelName = "user:\(currentUser.id)"
        let ownChannel = AblyService.shared.chatClient?.channels.get(ownChannelName)
        
        // Retrieve stored topic if available
        let storedTopic = UserDefaults.standard.string(forKey: "pendingTopic_\(space.id)_\(currentUser.id)")
        if let topic = storedTopic {
            print("📝 [joinSpace] Retrieved stored topic: \(topic)")
            self.currentTopic = topic
        }
        
        // Check if host is present before joining
        guard let ablyClient = AblyService.shared.chatClient else {
            print("❌ Ably client not available - please ensure app is properly initialized")
            return
        }
        print("✅ Ably client available")
        
        // Get host's user channel
        let hostChannelName = "user:\(space.hostId)"
        print("📡 [joinSpace] Checking host channel: \(hostChannelName)")
        
        do {
            // Get host's channel
            let hostChannel = ablyClient.channels.get(hostChannelName)
            print("📡 [joinSpace] Got host channel: \(hostChannelName)")
            
            // Check current number of users in the channel
            let members = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ARTPresenceMessage]?, Error>) in
                hostChannel.presence.get { members, error in
                    if let error = error {
                        print("❌ [joinSpace] Failed to get presence: \(error)")
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: members)
                    }
                }
            }
            
            // Count active participants (excluding host)
            let activeParticipants = members?.filter { member in
                if let data = member.data as? [String: Any],
                   let role = data["role"] as? String {
                    return role == "participant"
                }
                return false
            } ?? []
            
            print("👥 [joinSpace] Active participants: \(activeParticipants.count)")
            
            // If there are already 2 participants, show toast and return
            if activeParticipants.count >= 2 {
                print("❌ [joinSpace] Space is full (2 participants already present)")
                showToast("User already having conversation, come back later", isError: true)
                return
            }
            
            // Attach to host channel and set up subscriptions
            try await attachToHostChannel(hostChannel, currentUser: currentUser)
            
            // Send join request to host's channel with topic
            let joinRequestData: [String: Any] = [
                "spaceId": space.id,
                "userId": currentUser.id,
                "name": currentUser.username,
                "image": currentUser.avatar,
                "topic": self.currentTopic,
                "targetUserId": space.hostId,
                "channelType": "host"
            ]
            print("📤 [joinSpace] Publishing join request to host's user channel: \(hostChannelName)")
            try await hostChannel.publish("space_join_request", data: joinRequestData)
            print("✅ [joinSpace] Join request published to channel: \(hostChannelName)")
            
            // Clear stored topic after sending
            UserDefaults.standard.removeObject(forKey: "pendingTopic_\(space.id)_\(currentUser.id)")
            print("🧹 [joinSpace] Cleared stored topic")
            
            // Wait for room ID
            if let roomId = await waitForRoomId(spaceId: space.id) {
                print("🔄 Joining call...")
                await self.joinCall(roomId: roomId)
                print("✅ Call joined")
            } else {
                print("❌ Failed to get room ID")
                self.isInSpace = false
                showToast("Failed to join space - host did not create room", isError: true)
                cleanupHostChannel(hostChannel, userId: currentUser.id)
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get room ID"])
            }
            
        } catch {
            print("❌ Error in joinSpace: \(error)")
            
            // Clean up host channel
            let hostChannel = ablyClient.channels.get(hostChannelName)
            cleanupHostChannel(hostChannel, userId: currentUser.id)
            
            // Reconnect to own channel
            print("🔄 Reconnecting to own channel...")
            Task {
                do {
                    let ownChannel = try await AblyService.shared.connectToUserChannel(userId: currentUser.id)
                    print("✅ Reconnected to own channel")
                    
                    // Ensure we're subscribed to our own channel
                    AblyService.shared.subscribeToUserChannel()
                    print("✅ Subscribed to own channel messages")
                    
                    // Ensure host presence is set up
                    AblyService.shared.ensureHostPresence(userId: currentUser.id)
                    print("✅ Host presence ensured")
                } catch {
                    print("❌ Failed to reconnect to own channel: \(error)")
                }
            }
            
            if let error = error as? SpaceError {
                switch error {
                case .roomFull:
                    showToast("User already having conversation, come back later", isError: true)
                case .hostNotPresent:
                    showHostNotPresentModal = true
                default:
                    errorMessage = "Failed to join space: \(error.localizedDescription)"
                }
            } else {
                showToast("Failed to check host availability", isError: true)
            }
        }
    }
    
    @MainActor
    func leaveSpace(id: Int64) async {
        print("\n=== LEAVING SPACE ===")
        print("🔄 Space ID: \(id)")
        guard let currentUser = await tweetData.user else {
            self.showToast("User not authenticated", isError: true)
            return
        }
        
        guard let space = currentViewingSpace else {
            print("❌ No current viewing space")
            self.showToast("No space to leave", isError: true)
            return
        }

        print("✅ Found space and user")
        
        if space.hostId != currentUser.id {
            print("🔄 Updating host space state...")
            await updateHostSpaceState(isOnline: true)
            print("✅ Host space state updated")
        }
        
        // Get host's channel
        let hostChannelName = "user:\(space.hostId)"
        let hostChannel = AblyService.shared.chatClient?.channels.get(hostChannelName)
        
        // Leave presence first
        print("👋 Leaving presence...")
        hostChannel?.presence.leave(["id": currentUser.id, "role": "participant"])
        print("✅ Left presence")
        
        // Publish space leave message to host's channel
        let spaceData: [String: Any] = [
            "id": currentUser.id,
            "spaceId": space.id,
            "action": "leave",
            "role": space.hostId == currentUser.id ? "host" : "participant",
            "channelType": "host"
        ]
        print("📤 Publishing space leave message...")
        print("📤 Message data: \(spaceData)")
        try await hostChannel?.publish("user_update", data: spaceData)
        print("✅ Space leave message published")
        
        print("🔄 Leaving call...")
        await self.leaveCall(with: space.id)
        print("✅ Call left")
        
        // Clean up host channel subscriptions
        print("📡 Cleaning up host channel subscriptions: \(hostChannelName)")
        hostChannel?.unsubscribe() // First unsubscribe from messages
        hostChannel?.presence.unsubscribe() // Then unsubscribe from presence
        hostChannel?.detach { error in
            if let error = error {
                print("❌ Failed to detach from host channel: \(error)")
            } else {
                print("✅ Successfully detached from host channel")
                
                // After detaching from host's channel, reconnect to our own channel
                Task {
                    do {
                        print("🔄 Reconnecting to own user channel...")
                        let ownChannel = try await AblyService.shared.connectToUserChannel(userId: currentUser.id)
                        print("✅ Reconnected to own user channel")
                        
                        // Ensure we're subscribed to our own channel
                        AblyService.shared.subscribeToUserChannel()
                        print("✅ Subscribed to own user channel messages")
                        
                        // Ensure host presence is set up
                        AblyService.shared.ensureHostPresence(userId: currentUser.id)
                        print("✅ Host presence ensured")
                    } catch {
                        print("❌ Failed to reconnect to own user channel: \(error)")
                    }
                }
            }
        }
        
        // Update state
        Task { @MainActor in
            print("🔄 Updating local state...")
            if let userId = tweetData.user?.id {
                if let spaceIndex = self.spaces.firstIndex(where: { $0.id == space.id }) {
                    var updatedSpace = self.spaces[spaceIndex]
                    
                    // Remove user from speakers
                    updatedSpace.speakers.removeAll { $0.id == userId }
                    print("✅ User removed from speakers")
                    
                    // Update local state
                    self.spaces[spaceIndex] = updatedSpace
                    self.currentViewingSpace = updatedSpace
                }
            }
            
            self.isInSpace = false
            self.isSpaceMinimized = false
            self.showSpaceView = false
            self.currentViewingSpace = nil
            self.initialPeerCount = 0
            self.isRecording = false
            
            // Reset the wasEndedByHost flag since user left manually
            self.wasEndedByHost = false
            
            // Show toast notification for successful leave
            self.showToast("Successfully left the space", isError: false)
            
            print("✅ Local state updated")
        }
    }
    
    @MainActor
    func removeUser(userId: String) async {
        print("\n=== REMOVING USER ===")
        print("👤 User ID to remove: \(userId)")
        
        guard let space = selectedSpace else {
            print("❌ No selected space")
            return
        }
        
        // Find the target peer to remove
        if let targetPeer = hmsSDK.room?.peers.first(where: { $0.peerID.lowercased() == userId.lowercased() }) {
            print("✅ Found peer to remove")
            
            // Get host's channel
            let hostChannelName = "user:\(space.hostId)"
            let hostChannel = AblyService.shared.chatClient?.channels.get(hostChannelName)
            
            // Remove the specified peer from HMS
            hmsSDK.removePeer(targetPeer, reason: "You are violating the community rules.") { [weak self] success, error in
                if let error = error {
                    print("❌ Error removing peer: \(error.localizedDescription)")
                } else {
                    print("✅ Peer removed successfully from HMS")
                    
                    // Update state after peer removal
                    self?.updateStateAfterPeerRemoval(peerId: targetPeer.peerID)
                    
                    // Remove user from Ably channel
                    Task {
                        do {
                            // Leave presence for the removed user
                            print("👋 Removing user from Ably presence...")
                            let leaveData: [String: Any] = [
                                "id": Int64(userId) ?? 0,
                                "role": "participant",
                                "action": "leave"
                            ]
                            try await hostChannel?.presence.leave(leaveData)
                            print("✅ User removed from Ably presence")
                            
                            // Publish user removal message
                            let removalData: [String: Any] = [
                                "id": Int64(userId) ?? 0,
                                "spaceId": space.id,
                                "action": "remove",
                                "reason": "You are violating the community rules.",
                                "channelType": "host"
                            ]
                            print("📤 Publishing user removal message...")
                            try await hostChannel?.publish("user_update", data: removalData)
                            print("✅ User removal message published")
                            
                            // Clean up user's channel subscriptions if they exist
                            if let userChannel = AblyService.shared.chatClient?.channels.get("user:\(userId)") {
                                print("📡 Cleaning up user's channel subscriptions...")
                                userChannel.unsubscribe()
                                userChannel.presence.unsubscribe()
                                userChannel.detach { error in
                                    if let error = error {
                                        print("❌ Failed to detach user's channel: \(error)")
                                    } else {
                                        print("✅ Successfully detached user's channel")
                                    }
                                }
                            }
                        } catch {
                            print("❌ Error in Ably cleanup: \(error)")
                        }
                    }
                }
            }
        } else {
            print("❌ Peer not found with ID: \(userId)")
        }
    }
    
    func updateStateAfterPeerRemoval(peerId: String) {
        guard let space = selectedSpace else { return }
        if let spaceIndex = self.spaces.firstIndex(where: { $0.id == space.id }) {
            var updatedSpace = self.spaces[spaceIndex]
            
            // Remove the peer from speakers and listeners
            updatedSpace.speakers.removeAll { $0.peerID?.lowercased() == peerId.lowercased() }
            
            // Update the space
            self.spaces[spaceIndex] = updatedSpace
            selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: selectedSpace!)
            
            // Print updated state
            print("🔄 Updated [removeUser]: Speakers: \(updatedSpace.speakers.map { $0.id })")
        }
    }
    
    @MainActor
    func startSpace(id: Int64,userId: Int64) async {
        print("\n=== STARTING SPACE ===")
        print("🔄 Space ID: \(id)")
        
        guard let currentUser = tweetData.user else {
            print("❌ No user found")
            return
        }
        print("✅ User found: \(currentUser.id)")
        
        // Find host's own space
        guard let hostSpace = spaces.first(where: { $0.hostId == currentUser.id }) else {
            print("❌ Host's space not found")
            setInfoMessage(text: "Could not find your space", type: .error)
            return
        }
        print("✅ Host's space found: \(hostSpace.id)")

        // Ensure we're using host's space ID
        let spaceId = hostSpace.id
        print("🔄 Using space ID: \(spaceId)")
        
        // Ensure selectedSpace is set to host's space
        if selectedSpace?.id != hostSpace.id {
            selectedSpace = hostSpace
            print("✅ Updated selectedSpace to host's space")
        }
        
        // Get the space channel
        guard let ablyClient = AblyService.shared.chatClient else {
            print("❌ Ably client not available")
            return
        }
        print("✅ Ably client available")
        
        do {
            // Start the space and get room ID
            print("🔄 Starting call...")
            if let roomId = await startCall(with: spaceId) {
                print("✅ Call started with room ID: \(roomId)")
                
                // Update local space state with new room ID
                if let spaceIndex = self.spaces.firstIndex(where: { $0.id == hostSpace.id }) {
                    var updatedSpace = self.spaces[spaceIndex]
                    updatedSpace.hmsRoomId = roomId
                    self.spaces[spaceIndex] = updatedSpace
                    self.selectedSpace = updatedSpace
                    print("✅ Updated local space state with room ID")
                }
                
                // Get current queue state
                let currentQueue = hostSpace.queue.participants.filter { !$0.hasLeft }
                print("👥 Current queue size: \(currentQueue.count)")
                
               
                    // Use host's own channel instead of visitor's channel
                    let hostChannelName = "user:\(currentUser.id)"
                    print("🔍 Using host channel: \(hostChannelName)")
                    let hostChannel = ablyClient.channels.get(hostChannelName)
                    
                    // Ensure channel is attached before sending
                    print("🔄 Ensuring channel is attached...")
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        hostChannel.attach { error in
                            if let error = error {
                                print("❌ Failed to attach to host channel: \(error)")
                                continuation.resume(throwing: error)
                            } else {
                                print("✅ Successfully attached to host channel")
                                continuation.resume()
                            }
                        }
                    }
                    
                    // Publish room ID to host's channel with complete data structure
                    let roomData: [String: Any] = [
                        "type": "room_created",
                        "hmsRoomId": roomId,
                        "spaceId": spaceId,
                        "targetUserId": userId,
                        "hostId": currentUser.id,
                        "timestamp": Date().timeIntervalSince1970,
                        "channelType": "own"  // This ensures the message is processed by both host and target
                    ]
                    print("📤 Publishing room ID to host's channel: \(hostChannelName)")
                    print("📤 Message data: \(roomData)")
                    
                    // Verify channel state before publishing
                    print("🔍 Channel state before publishing: \(hostChannel.state)")
                    
                    try await hostChannel.publish("room_created", data: roomData)
                    print("✅ Room ID sent to host's channel")
                    
                    // Verify message was sent using async/await
                    print("🔍 Verifying message delivery...")
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        hostChannel.presence.get { members, error in
                            if let error = error {
                                print("❌ Failed to verify message delivery: \(error)")
                                continuation.resume(throwing: error)
                            } else {
                                print("👥 Channel members after sending: \(members?.count ?? 0)")
                                if let members = members {
                                    for member in members {
                                        print("- Member: \(member.clientId ?? "unknown")")
                                        if let data = member.data as? [String: Any] {
                                            print("  Data: \(data)")
                                        }
                                    }
                                }
                                continuation.resume()
                            }
                        }
                    }
                    print("✅ Message delivery verification complete")
                
                
                // Set space state immediately with proper animation context
                await MainActor.run {
                    withAnimation(.spring()) {
                        self.isInSpace = true
                        self.showQueueView = false
                        self.isSpaceMinimized = false
                        print("✅ Space state updated - isInSpace: \(self.isInSpace), showSpaceView: \(self.showSpaceView)")
                    }
                }
                
                setInfoMessage(text: "Your space has started.", type: .information)
            } else {
                print("❌ Failed to create room")
                setInfoMessage(text: "Failed to create room", type: .error)
            }
        } catch {
            print("❌ Error starting space: \(error)")
            setInfoMessage(text: "Failed to start space", type: .error)
        }
    }
    
    @MainActor
    func endSpace(with id: Int64) async {
        print("\n=== ENDING SPACE ===")
        print("🔄 Space ID: \(id)")
        
        guard let currentUser = tweetData.user else {
            print("❌ No user found")
            self.showToast("User not authenticated", isError: true)
            return
        }
        
        // Find host's own space using selectedSpace.id
        guard let selectedSpace = selectedSpace,
              let spaceIndex = spaces.firstIndex(where: { $0.id == selectedSpace.id }) else {
            print("❌ Host's space not found")
            self.showToast("Could not find your space", isError: true)
            return
        }

        print("✅ Found selected space")
        
        // Remove non-moderator speakers from the space
        var updatedSpace = spaces[spaceIndex]
        updatedSpace.speakers.removeAll { speaker in
            let isModerator = speaker.id == currentUser.id
            if !isModerator {
                print("🗑️ Removing non-moderator speaker: \(speaker.name ?? "unknown")")
            }
            return !isModerator
        }
        
        // Update the space
        spaces[spaceIndex] = updatedSpace
        
        print("\n Final Space State:")
        print("- Remaining speakers: \(updatedSpace.speakers.count)")
        print("- Speaker IDs: \(updatedSpace.speakers.map { $0.id })")
        
        // End HMS call
        print("🔄 Ending HMS call...")
        await self.endCall(id: id)
        print("✅ HMS call ended")
        
        self.initialPeerCount = 0
        self.isRecording = false
        
        // Reset the wasEndedByHost flag since host ended the space
        self.wasEndedByHost = false
        
        // Show toast notification for successful space end
                    self.showToast("Host left - conversation completed", isError: false)
        
        print("✅ Reset recording state")
        
      
    }
    
    func joinCall(roomId: String) async {
        guard let currentUser = await tweetData.user else {
            return
        }
        
        do {
            print("🔄 [joinCall] Starting to join LiveKit room")
            print("🔍 Room ID: \(roomId)")
            print("👤 User ID: \(currentUser.id)")
            
            // Create LiveKit room
            let room = Room()
            
            // Set self as delegate
            room.add(delegate: self)
            print("✅ Set LiveKit delegate")
            
            // Prepare participant metadata
            let metadataDict: [String: String] = [
                "id": String(currentUser.id),
                "name": currentUser.nickname ?? "",
                "username": currentUser.username,
                "image_url": currentUser.avatar ?? "",
                "topic": currentTopic.isEmpty ? "" : currentTopic,
                "role": "speaker"
            ]
            
            print("📝 Participant metadata: \(metadataDict)")
            
            // Convert metadata to JSON string
            let metadata = try JSONSerialization.data(withJSONObject: metadataDict, options: [])
            let metadataString = String(data: metadata, encoding: .utf8) ?? ""
            
            // Generate token
            let token = generateLiveKitToken(roomId: roomId, userId: currentUser.id, role: "speaker")
            print("🔑 Generated token for room: \(roomId)")
            
            // Connect to LiveKit server
            print("🔄 Connecting to LiveKit server...")
            try await room.connect(
                url: "ws://localhost:7880",
                token: token
            )
            print("✅ Connected to LiveKit server")
            
            // Set participant attributes with metadata
            print("🔄 Setting participant attributes...")
            try await room.localParticipant.set(attributes: [
                "role": "speaker",
                "isOnline": "true",
                "metadata": metadataString
            ])
            print("✅ Successfully set participant attributes")
            
            // Create and publish audio track
            print("🔄 Creating and publishing audio track...")
            let audioTrack = try await LocalAudioTrack.createTrack()
            try await room.localParticipant.publish(audioTrack: audioTrack)
            print("✅ Successfully published audio track")
            
            // Store room reference
            self.liveKitRoom = room
            print("✅ Stored room reference")
            
            await MainActor.run {
                self.isInSpace = true
                self.showQueueView = false
                self.recordingTimeRemaining = 420
            }
            
        } catch {
            print("🔍[joinCall] Error joining space: \(error)")
            self.currentViewingSpace = nil
            setInfoMessage(text: "Failed to join LiveKit room: \(error.localizedDescription)", type: .error)
        }
    }
    
    func leaveCall(with id: Int64) async {
        print("\n=== LEAVING SPACE ===")
        print("🔄 Space ID: \(id)")
        
        await liveKitRoom?.disconnect()
        liveKitRoom = nil
        
        // Clear currentViewingSpace since we're leaving as a visitor
        self.currentViewingSpace = nil
        print("✅ Cleared currentViewingSpace")
        
        // Reset track data
        self.ownTrack = nil
        self.otherTracks = []
        self.recordingTimeRemaining = 420
    }
    
    func endCall(id: Int64) async {
        print("🔄 DEBUG[endCall]: Starting endCall for space ID: \(id)")
        guard let room = liveKitRoom else {
            print("⚠️ Cannot end room - not connected")
            self.ownTrack = nil
            self.otherTracks = []
            print("🔄 DEBUG[endCall]: Reset track data")
            
            // Update the state in the end.
            self.selectedSpace = nil
            self.showSpaceView = false
            self.isSpaceMinimized = false
            isInSpace = false
            return
        }
        
        await room.disconnect()
        liveKitRoom = nil
        
        // Reset track data
        self.ownTrack = nil
        self.otherTracks = []
        print("🔄 DEBUG[endCall]: Reset track data")
        
        // Update the state
        self.showSpaceView = false
        self.isInSpace = false
        self.selectedSpace = nil
        self.showQueueView = false
        self.recordingTimeRemaining = 420
    }
    
    func startCall(with id: Int64) async -> String? {
        guard let userId = await tweetData.user?.id, let username = await tweetData.user?.username else {
            print("❌ Cannot start space - no user found")
            return nil
        }
        
        do {
            print("\n=== STARTING CALL ===")
            print("🔍 Starting call with ID: \(id)")
            print("👤 User ID: \(userId)")
            print("👤 Username: \(username)")
            
            // Retrieve stored topic for this space
            var topicToUse = ""
            if let storedTopic = UserDefaults.standard.string(forKey: "hostTopic_\(id)") {
                print("📝 [startCall] Retrieved stored topic: \(storedTopic)")
                topicToUse = storedTopic
                UserDefaults.standard.removeObject(forKey: "hostTopic_\(id)")
                print("🧹 [startCall] Cleared stored topic")
            }
            
            // Create LiveKit room
            let room = Room()
            
            // Set self as delegate
            room.add(delegate: self)
            print("✅ Set LiveKit delegate")
            
            print("✅ Created LiveKit room instance")
            
            // Prepare host metadata
            let metadataDict: [String: String] = [
                "id": String(userId),
                "name": tweetData.user?.nickname ?? "",
                "username": username,
                "image_url": tweetData.user?.avatar ?? "",
                "topic": topicToUse.isEmpty ? "" : topicToUse,
                "role": "host"
            ]
            print("📝 Prepared metadata: \(metadataDict)")
            
            // Convert metadata to JSON string
            let metadata = try JSONSerialization.data(withJSONObject: metadataDict, options: [])
            let metadataString = String(data: metadata, encoding: .utf8) ?? ""
            print("✅ Converted metadata to JSON string")
            
            // Generate token
            let roomId = String(id)
            let token = generateLiveKitToken(roomId: roomId, userId: userId, role: "host")
            print("🔑 Generated LiveKit token")
            
            // Configure room options for audio-only
            let roomOptions = RoomOptions(
                adaptiveStream: true,
                dynacast: false,
                stopLocalTrackOnUnpublish: true
            )
            
            // Configure connection options
            let connectOptions = ConnectOptions(
                autoSubscribe: true
            )
            
            // Connect to LiveKit server as host
            print("🔄 Attempting to connect to LiveKit server...")
            print("📡 Server URL: ws://localhost:7880")
            print("🔑 Token: \(token)")
            
            try await room.connect(
                url: "ws://localhost:7880",
                token: token,
                connectOptions: connectOptions,
                roomOptions: roomOptions
            )
            print("✅ Successfully connected to LiveKit server")
            
            // Set participant attributes with metadata
            print("🔄 Setting participant attributes...")
            try await room.localParticipant.set(attributes: [
                "role": "host",
                "isOnline": "true",
                "metadata": metadataString
            ])
            print("✅ Successfully set participant attributes")
            
            // Create and publish audio track
            print("🔄 Creating and publishing audio track...")
            let audioTrack = try await LocalAudioTrack.createTrack()
            try await room.localParticipant.publish(audioTrack: audioTrack)
            print("✅ Successfully published audio track")
            
            // Store room reference
            self.liveKitRoom = room
            print("✅ Stored room reference")
            
            // Return room ID
            print("✅ Returning room ID: \(id)")
            return String(id)
            
        } catch {
            await MainActor.run {
                print("❌ Error in startCall: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                setInfoMessage(text: "Failed to start LiveKit room: \(error.localizedDescription)", type: .error)
            }
            return nil
        }
    }
    
    // Helper function to generate LiveKit token
    private func generateLiveKitToken(roomId: String, userId: Int64, role: String) -> String {
        // For development, we're using the default devkey/secret
        let apiKey = "devkey"
        let apiSecret = "secret"
        
        // Create token claims with video grant for audio-only
        let claims: [String: Any] = [
            "iss": apiKey,
            "sub": String(userId),
            "nbf": Int(Date().timeIntervalSince1970),
            "exp": Int(Date().timeIntervalSince1970) + 86400, // 24 hours
            "video": [
                "room": roomId,
                "roomJoin": true,
                "canPublish": true,
                "canSubscribe": true,
                "canPublishData": true,
                "canPublishAudio": true,
                "canPublishVideo": false,
                "canPublishSources": ["microphone"]  // Only allow microphone for audio-only rooms
            ]
        ]
        
        // Create JWT header
        let header: [String: String] = [
            "alg": "HS256",
            "typ": "JWT"
        ]
        
        // Encode header and payload
        let headerData = try! JSONSerialization.data(withJSONObject: header, options: [])
        let payloadData = try! JSONSerialization.data(withJSONObject: claims, options: [])
        
        let headerBase64 = base64UrlEncode(headerData)
        let payloadBase64 = base64UrlEncode(payloadData)
        
        // Create signature
        let toSign = "\(headerBase64).\(payloadBase64)"
        let secretData = Data(apiSecret.utf8)
        let symmetricKey = SymmetricKey(data: secretData)
        let signature = HMAC<SHA256>.authenticationCode(for: Data(toSign.utf8), using: symmetricKey)
        let signatureBase64 = base64UrlEncode(Data(signature))
        
        // Combine to create the JWT
        let token = "\(headerBase64).\(payloadBase64).\(signatureBase64)"
        
        // Print token for debugging
        print("🔑 Generated LiveKit token: \(token)")
        if let decoded = decodeJWT(token: token) {
            print("🔍 Decoded token claims: \(decoded)")
        }
        
        return token
    }
    
    func createJWT(header: [String: String], payload: [String: Any], secret: String) throws -> String {
        // Encode header and payload to JSON
        let headerData = try JSONSerialization.data(withJSONObject: header, options: [])
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        // Base64Url encode header and payload
        let headerBase64 = base64UrlEncode(headerData)
        let payloadBase64 = base64UrlEncode(payloadData)
        
        // Create the signing input
        let toSign = "\(headerBase64).\(payloadBase64)"
        
        // Use the raw secret key for signing (do not decode it)
        let secretData = Data(secret.utf8)
        let symmetricKey = SymmetricKey(data: secretData)
        let signature = HMAC<SHA256>.authenticationCode(for: Data(toSign.utf8), using: symmetricKey)
        let signatureBase64 = base64UrlEncode(Data(signature))
        
        // Combine to create the JWT
        return "\(headerBase64).\(payloadBase64).\(signatureBase64)"
    }
    
    func base64UrlEncode(_ data: Data) -> String {
        let base64 = data.base64EncodedString()
        let base64Url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64Url
    }
    
    private func createRoom(roomId: Int64, managementToken: String) async throws -> CreateRoomResponse {
        print("🔄 Sending request to create room with ID: \(roomId)")
        print("🔍 Management Token: \(managementToken)") // Print the management token
        
        // Decode the JWT token to inspect its payload
        if let jwtPayload = decodeJWT(token: managementToken) {
            print("🔍 Decoded JWT Payload: \(jwtPayload)")
        } else {
            print("❌ Failed to decode JWT payload")
        }
        
        let url = URL(string: "https://api.100ms.live/v2/rooms")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(managementToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": String(roomId),  // Convert roomId to string
            "template_id": "67abcc6f8102660b706ad008"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        // Print the full request for debugging
        print("🔍 Full Request:")
        print("URL: \(request.url?.absoluteString ?? "N/A")")
        print("Method: \(request.httpMethod ?? "N/A")")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let httpBody = request.httpBody, let bodyString = String(data: httpBody, encoding: .utf8) {
            print("Body: \(bodyString)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Print the response details
        if let httpResponse = response as? HTTPURLResponse {
            print("🔍 Response Status Code: \(httpResponse.statusCode)")
            print("🔍 Response Headers: \(httpResponse.allHeaderFields)")
        }
        
        // Print the response body for debugging
        if let responseBody = String(data: data, encoding: .utf8) {
            print("🔍 Response Body: \(responseBody)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ Failed to create room, HTTP status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create room"])
        }
        
        let roomResponse = try JSONDecoder().decode(CreateRoomResponse.self, from: data)
        print("✅ Room created: \(roomResponse)")
        return roomResponse
    }
    
    // Helper function to decode JWT payload
    private func decodeJWT(token: String) -> [String: Any]? {
        let components = token.components(separatedBy: ".")
        guard components.count == 3 else {
            return nil
        }
        
        let payloadBase64 = components[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if necessary
        let padding = payloadBase64.count % 4
        let paddedPayloadBase64 = payloadBase64 + String(repeating: "=", count: padding)
        
        if let payloadData = Data(base64Encoded: paddedPayloadBase64),
           let payload = try? JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any] {
            return payload
        }
        
        return nil
    }
    
    struct CreateRoomRequest: Codable {
        let roomId: String
    }
    
    // Define the structure of the response from the ms-token function
    struct TokenResponse: Codable {
        let token: String
    }
    
    // Define the structure of the response from the createRoom function
    struct CreateRoomResponse: Codable {
        let id: String
        let name: String
        let enabled: Bool
        let description: String?
        let customer_id: String
        let app_id: String
        let recording_info: RecordingInfo?
        let template_id: String
        let template: String
        let region: String
        let created_at: String
        let updated_at: String
        let large_room: Bool
    }
    
    // Define the structure for recording information
    struct RecordingInfo: Codable {
        let enabled: Bool?
    }
    
   
}
*/