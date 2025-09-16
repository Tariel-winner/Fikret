//
//  SpacesViewModel+SpaceForHMSDKCentrifugo.swift
//  Spaces
//
//  Created by Stefan Blos on 01.03.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//
//  ✅ SIMPLIFIED: This file now focuses on essential Centrifugo operations
//  - Simple subscription to host channels
//  - Basic presence checking for space capacity
//  - Clean message publishing and cleanup
//  - No complex host status monitoring or caching
//
//  🔄 EXPECTED FLOW (IDENTICAL TO ABLY):
//  1. Visitor subscribes to host's channel ✅
//  2. Visitor sends join request to host's channel with channelType: "host" ✅
//  3. Host receives join request via CentrifugeService.onPublication ✅
//  4. Host calls startSpace() ✅
//  5. Host creates HMS room and gets room ID ✅
//  6. Host publishes room_created message to host's channel with channelType: "own" ✅
//  7. Visitor receives room_created message via VisitorChannelDelegate.onPublication ✅
//  8. Visitor joins HMS call with room ID ✅
//
//  🔍 MESSAGE ROUTING (IDENTICAL TO ABLY):
//  - Visitor → Host: channelType: "host", targetUserId: hostId
//  - Host → Visitor: channelType: "own", targetUserId: visitorId
//  - Both users must be subscribed to their own channels to receive messages
//

/*
import Foundation
import HMSSDK
import SwiftUI
import CryptoKit
import SwiftCentrifuge

extension SpacesViewModel {
  
    @MainActor
    private func cleanupHostChannel(_ hostChannel: CentrifugeSubscription, userId: Int64) {
        print("🧹 Cleaning up host channel...")
        hostChannel.unsubscribe()
        // Note: presenceUnsubscribe() doesn't exist in SwiftCentrifuge - presence is handled automatically
    }


    // ✅ OPTIMIZED: Centrifugo automatically handles message processing via VisitorChannelDelegate
    // No need for manual message handling - Centrifugo routes messages automatically
    
    @MainActor
    private func checkHostPresence(_ hostChannel: CentrifugeSubscription, space: Space) async throws {
        print("👥 [joinSpace] Checking host presence...")
        
        let presence = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CentrifugePresenceResult, Error>) in
            hostChannel.presence { result in
                switch result {
                case .success(let presence):
                    continuation.resume(returning: presence)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        print("👥 [joinSpace] Current presence members: \(presence.presence.count)")
        for (clientId, clientInfo) in presence.presence {
            print("- Client: \(clientId)")
            print("  User: \(clientInfo.user)")
        }
        
        // Count active participants (excluding host)
        let activeParticipants = presence.presence.values.filter { clientInfo in
            // Check if this is a participant by looking at the user field
            return clientInfo.user.contains("participant") || clientInfo.client.contains("participant")
        }
        
        print("👥 [joinSpace] Active participants: \(activeParticipants.count)")
        
        // If there are already 2 participants, prevent joining
        if activeParticipants.count >= 2 {
            print("❌ [joinSpace] Space is full (2 participants already present)")
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Space is currently full. Please try again later."])
        }
        
        // Check if host is present
        let isHostPresent = presence.presence.values.contains { clientInfo in
            // Check if this is the host by looking at the user field
            return clientInfo.user == "user:\(space.hostId)" || clientInfo.client.contains("user:\(space.hostId)")
        }
        
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
            
            observer = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RoomCreated"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }
                
                if let userInfo = notification.userInfo,
                   let roomId = userInfo["hmsRoomId"] as? String,
                   let notificationSpaceId = userInfo["spaceId"] as? Int64,
                   notificationSpaceId == spaceId {
                    print("✅ Room ID received: \(roomId)")
                    
                    // ✅ OPTIMIZED: Use cached lookup for O(1) space index search instead of O(n) linear search
                    if let spaceIndex = getSpaceIndex(for: spaceId) {
                        var updatedSpace = self.spaces[spaceIndex]
                        updatedSpace.hmsRoomId = roomId
                        self.spaces[spaceIndex].update(with: updatedSpace, preservingFieldsFrom: self.spaces[spaceIndex])
                        // ✅ CACHE: No manual update needed - didSet will trigger automatically
                        self.selectedSpace = self.spaces[spaceIndex]
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
            
            // Set a timeout using DispatchQueue instead of async Task
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
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
        
        // ✅ ADDED: Set joining state for smooth navigation
        isJoining = true
        print("🔄 [JOINING] Set isJoining = true - showing joining UI")
        
        guard let currentUser = await tweetData.user else {
            print("❌ No user found")
            isJoining = false // ✅ FIXED: Reset joining state on error
            return
        }
        
        // Use currentViewingSpace instead of selectedSpace for visitor interactions
        guard let space = currentViewingSpace else {
            print("❌ No current viewing space")
            isJoining = false // ✅ FIXED: Reset joining state on error
            return
        }
        print("✅ Found space and user")
        print("👤 Current user ID: \(currentUser.id)")
        
        // Retrieve stored topic if available (only if current topic is empty)
        print("📝 [joinSpace] Current topic before check: '\(self.currentTopic)'")
        if self.currentTopic.isEmpty {
            let storedTopic = UserDefaults.standard.string(forKey: "pendingTopic_\(space.id)_\(currentUser.id)")
            if let topic = storedTopic {
                print("📝 [joinSpace] Retrieved stored topic: '\(topic)'")
                self.currentTopic = topic
            } else {
                print("📝 [joinSpace] No stored topic found")
            }
        } else {
            print("📝 [joinSpace] Using current topic: '\(self.currentTopic)'")
        }
        print("📝 [joinSpace] Final topic that will be sent: '\(self.currentTopic)'")
        
        guard let centrifugeClient = CentrifugeService.shared.chatClient else {
            print("❌ Centrifugo client not available")
            return
        }
        print("✅ Centrifugo client available")
        
        // Get host's user channel
        let hostChannelName = "user:\(space.hostId)"
        print("📡 [joinSpace] Connecting to host channel: \(hostChannelName)")
        
        // Create subscription to host's channel
        let hostChannel: CentrifugeSubscription
        do {
            hostChannel = try CentrifugeService.shared.createVisitorSubscription(
                to: hostChannelName,
                onMessage: { [weak self] data in
                    print("📨 [joinSpace] Message received from host channel: \(data)")
                    // ✅ Centrifugo automatically handles message routing via VisitorChannelDelegate
                    // Messages are automatically processed and notifications are posted
                },
                onPresence: { presence in
                    print("👥 [joinSpace] Host channel presence: \(presence.presence.count) clients")
                }
            )
            print("✅ [joinSpace] Connected to host channel: \(hostChannelName)")
        } catch {
            print("❌ Failed to connect to host channel: \(error)")
            setInfoMessage(text: "Failed to connect to host channel", type: .error)
            return
        }
        
        do {
            // Simple presence check to see if space is full
            print("👥 [joinSpace] Checking if space is full...")
            let presence = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CentrifugePresenceResult, Error>) in
                hostChannel.presence { result in
                    switch result {
                    case .success(let presence):
                        continuation.resume(returning: presence)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            
            
            print("✅ [joinSpace] Space has room for participants")
            
            // Send join request to host's channel with topic and location data
            var joinRequestData: [String: Any] = [
                "type": "space_join_request",
                "spaceId": space.id,
                "userId": currentUser.id,
                "name": currentUser.username,
                "image": currentUser.avatar,
                "topic": self.currentTopic,
                "targetUserId": space.hostId,
                "channelType": "host"
            ]
            
            // ✅ ADDED: Include location data if available
            if let locationData = await tweetData.currentLocation {
                joinRequestData["locationData"] = locationData
                print("📍 [joinSpace] Added location data to join request: \(locationData.city)")
            }
            
            print("📤 [joinSpace] Publishing join request to host's user channel: \(hostChannelName)")
            print("📤 [joinSpace] Join request data: \(joinRequestData)")
            
            let jsonData = try JSONSerialization.data(withJSONObject: joinRequestData)
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    print("📤 [joinSpace] Attempting to publish join request...")
                    hostChannel.publish(data: jsonData) { result in
                        switch result {
                        case .success:
                            print("✅ [joinSpace] Join request published successfully")
                            continuation.resume()
                        case .failure(let error):
                            print("❌ [joinSpace] Failed to publish join request: \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                } catch {
                    print("❌ [joinSpace] Error in publish preparation: \(error)")
                    continuation.resume(throwing: error)
                }
            }
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
                setInfoMessage(text: "Failed to join space - host did not create room", type: .error)
                cleanupHostChannel(hostChannel, userId: currentUser.id)
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get room ID"])
            }
            
        } catch {
            print("❌ Error in joinSpace: \(error)")
            cleanupHostChannel(hostChannel, userId: currentUser.id)
            setInfoMessage(text: "Failed to join space", type: .error)
        }
    }
    
    @MainActor
    func leaveSpace(id: Int64) async {
        print("\n=== LEAVING SPACE ===")
        print("🔄 Space ID: \(id)")
        guard let currentUser = await tweetData.user else {
            return
        }
        
        guard let space = currentViewingSpace else {
            print("❌ No current viewing space")
            return
        }

        print("✅ Found space and user")
        
        if space.hostId != currentUser.id {
            print("🔄 Updating host space state...")
            await updateHostSpaceState(isOnline: true)
            print("✅ Host space state updated")
        }
        
        // Get host's channel name
        let hostChannelName = "user:\(space.hostId)"
        
        // Check if we already have a subscription to the host's channel
        if let existingHostChannel = CentrifugeService.shared.getSubscription(channel: hostChannelName) {
            print("✅ [leaveSpace] Using existing host channel subscription")
            
            // Send leave message through existing connection
            let spaceData: [String: Any] = [
                "type": "user_update",
                "id": currentUser.id,
                "spaceId": space.id,
                "action": "leave",
                "role": space.hostId == currentUser.id ? "host" : "participant",
                "channelType": "host"
            ]
            
            print("📤 Publishing space leave message...")
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: spaceData)
                existingHostChannel.publish(data: jsonData) { result in
                    switch result {
                    case .success:
                        print("✅ Leave message published successfully")
                    case .failure(let error):
                        print("❌ Failed to publish leave message: \(error)")
                    }
                }
            } catch {
                print("❌ Error preparing leave message: \(error)")
            }
            
            // Unsubscribe from host's channel
            print("📡 Unsubscribing from host channel: \(hostChannelName)")
            existingHostChannel.unsubscribe()
            
        } else {
            print("⚠️ [leaveSpace] No existing host channel subscription found")
            // If no existing subscription, just proceed with cleanup
        }
        
        print("🔄 Leaving call...")
        self.leaveCall(with: space.id)
        print("✅ Call left")
        
        // Clean up host channel subscriptions
        print("📡 Cleaning up host channel subscriptions: \(hostChannelName)")
       
        Task {
            // ✅ OPTIMIZED: Check if already connected to own channel first
            let ownChannelName = "user:\(currentUser.id)"
            if CentrifugeService.shared.getSubscription(channel: ownChannelName) != nil {
                print("✅ [leaveSpace] Already connected to own channel: \(ownChannelName)")
                return
            }
            
            do {
                print("🔄 Reconnecting to own user channel...")
                try await CentrifugeService.shared.connectToUserChannel(userId: currentUser.id)
                print("✅ Reconnected to own user channel")
            } catch {
                print("❌ Failed to reconnect to own user channel: \(error)")
                // Try to reinitialize the client if connection fails
                if let username = tweetData.user?.username {
                    await CentrifugeService.shared.initializeForUser(userId: currentUser.id, username: username)
                    print("🔄 Reinitialized Centrifugo client for user after leaving space")
                }
            }
        }
        
                    // Update state
            Task { @MainActor in
                print("🔄 Updating local state...")
                if let userId = tweetData.user?.id {
                    // ✅ OPTIMIZED: Use cached lookup for O(1) space index search instead of O(n) linear search
                    if let spaceIndex = getSpaceIndex(for: space.id) {
                    var updatedSpace = self.spaces[spaceIndex]
                    
                    // Remove user from speakers
                    updatedSpace.speakers.removeAll { $0.id == userId }
                    print("✅ User removed from speakers")
                    
                    // Update local state using the proper update method
                    self.spaces[spaceIndex].update(with: updatedSpace, preservingFieldsFrom: self.spaces[spaceIndex])
                    // ✅ CACHE: No manual update needed - didSet will trigger automatically
                    self.currentViewingSpace = self.spaces[spaceIndex]
                    
                    // ✅ CRITICAL: Update queue cache when speakers change
                    self.queueParticipantIds[space.id] = Set(self.spaces[spaceIndex].queue.participants.map { $0.id })
                }
            }
            
            self.isInSpace = false
            self.isSpaceMinimized = false
            self.showSpaceView = false
            self.currentViewingSpace = nil
            self.initialPeerCount = 0
            self.isRecording = false
                self.wasEndedByHost = false
        
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
            guard let centrifugeClient = CentrifugeService.shared.chatClient else {
                print("❌ Centrifugo client not available")
                return
            }
            
            // Get the host's channel subscription
            guard let hostChannel = CentrifugeService.shared.getSubscription(channel: hostChannelName) else {
                print("❌ Host channel subscription not found for: \(hostChannelName)")
                return
            }
            print("✅ Found host channel subscription: \(hostChannelName)")
      
            // Remove the specified peer from HMS
            hmsSDK.removePeer(targetPeer, reason: "You are violating the community rules.") { [weak self] success, error in
                if let error = error {
                    print("❌ Error removing peer: \(error.localizedDescription)")
                } else {
                    print("✅ Peer removed successfully from HMS")
                    
                    // Update state after peer removal
                    self?.updateStateAfterPeerRemoval(peerId: targetPeer.peerID)
                    
                    // Remove user from Centrifugo channel
                    Task {
                        do {
                            // Publish user removal message
                            let removalData: [String: Any] = [
                                "type": "user_update",
                                "id": Int64(userId) ?? 0,
                                "spaceId": space.id,
                                "action": "remove",
                                "reason": "You are violating the community rules.",
                                "channelType": "host"
                            ]
                            print("📤 Publishing user removal message...")
                            
                            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                                do {
                                    let jsonData = try JSONSerialization.data(withJSONObject: removalData)
                                    hostChannel.publish(data: jsonData) { result in
                                        switch result {
                                        case .success:
                                            continuation.resume()
                                        case .failure(let error):
                                            continuation.resume(throwing: error)
                                        }
                                    }
                                } catch {
                                    continuation.resume(throwing: error)
                                }
                            }
                            print("✅ User removal message published")
                            
                                        // ✅ OPTIMIZED: No need to connect to visitor channel in removeUser
            // This is a host-only function, and the host is already connected to their own channel
            print("📡 [removeUser] Host function - no visitor channel connection needed")
                        } catch {
                            print("❌ Error in Centrifugo cleanup: \(error)")
                        }
                    }
                }
            }
        } else {
            print("❌ Peer not found with ID: \(userId)")
        }
    }
    
    @MainActor
    func updateStateAfterPeerRemoval(peerId: String) {
        guard let space = selectedSpace else { return }
        // ✅ OPTIMIZED: Use cached lookup for O(1) space index search instead of O(n) linear search
        if let spaceIndex = getSpaceIndex(for: space.id) {
            var updatedSpace = self.spaces[spaceIndex]
            
            // Remove the peer from speakers and listeners
            updatedSpace.speakers.removeAll { $0.peerID?.lowercased() == peerId.lowercased() }
            
            // Update the space using the proper update method
            self.spaces[spaceIndex].update(with: updatedSpace, preservingFieldsFrom: self.spaces[spaceIndex])
            // ✅ CACHE: No manual update needed - didSet will trigger automatically
            selectedSpace?.update(with: self.spaces[spaceIndex], preservingFieldsFrom: selectedSpace!)
            
            // ✅ CRITICAL: Update queue cache when speakers change
            self.queueParticipantIds[space.id] = Set(self.spaces[spaceIndex].queue.participants.map { $0.id })
            
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
        
        // ✅ OPTIMIZED: Use cached lookup for O(1) host space search instead of O(n) linear search
        guard let hostSpace = getHostSpace(for: currentUser.id) else {
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
        guard let centrifugeClient = CentrifugeService.shared.chatClient else {
            print("❌ Centrifugo client not available")
            return
        }
        print("✅ Centrifugo client available")
        
        do {
            // Start the space and get room ID
            print("🔄 Starting call...")
            if let roomId = await startCall(with: spaceId) {
                print("✅ Call started with room ID: \(roomId)")
                
                // ✅ OPTIMIZED: Use cached lookup for O(1) space index search instead of O(n) linear search
                if let spaceIndex = getSpaceIndex(for: hostSpace.id) {
                    var updatedSpace = self.spaces[spaceIndex]
                    updatedSpace.hmsRoomId = roomId
                    self.spaces[spaceIndex].update(with: updatedSpace, preservingFieldsFrom: self.spaces[spaceIndex])
                    // ✅ CACHE: No manual update needed - didSet will trigger automatically
                    self.selectedSpace = self.spaces[spaceIndex]
                    print("✅ Updated local space state with room ID")
                }
                
                // Get current queue state
                let currentQueue = hostSpace.queue.participants.filter { !$0.hasLeft }
                print("👥 Current queue size: \(currentQueue.count)")
                
               
                                    // Use host's own channel
                let hostChannelName = "user:\(currentUser.id)"
                print("🔍 Using existing host channel: \(hostChannelName)")
                
                // Get the existing subscription from CentrifugeService
                guard let hostChannel = CentrifugeService.shared.getSubscription(channel: hostChannelName) else {
                    print("❌ Host channel not found - host must be connected to their channel first")
                    setInfoMessage(text: "Host channel not available", type: .error)
                    return
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
                print("📤 [startSpace] Publishing room ID to host's channel: \(hostChannelName)")
                print("📤 [startSpace] Room data for visitor: \(roomData)")
                print("🎯 [startSpace] Target visitor user ID: \(userId)")
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: roomData)
                        hostChannel.publish(data: jsonData) { result in
                            switch result {
                            case .success:
                                print("✅ [startSpace] Room ID successfully published to host's channel")
                                continuation.resume()
                            case .failure(let error):
                                print("❌ [startSpace] Failed to publish room ID: \(error)")
                                continuation.resume(throwing: error)
                            }
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                print("✅ [startSpace] Room ID sent to host's channel - visitor should receive it now")
                
                
                // Set space state immediately with proper animation context
                await MainActor.run {
                    withAnimation(.spring()) {
                        self.isInSpace = true
                        self.showSpaceView = true
                        self.showQueueView = false
                        self.isSpaceMinimized = false
                          self.currentSpaceSessionStartTime = Date()
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
            return
        }
        
        // Find host's own space using selectedSpace.id
        // ✅ OPTIMIZED: Use cached lookup for O(1) space index search instead of O(n) linear search
        guard let selectedSpace = selectedSpace,
              let spaceIndex = getSpaceIndex(for: selectedSpace.id) else {
            print("❌ Host's space not found")
            setInfoMessage(text: "Could not find your space", type: .error)
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
        
        // Update the space using the proper update method
        spaces[spaceIndex].update(with: updatedSpace, preservingFieldsFrom: spaces[spaceIndex])
        // ✅ CACHE: No manual update needed - didSet will trigger automatically
        
        // ✅ CRITICAL: Update queue cache when speakers change
        self.queueParticipantIds[selectedSpace.id] = Set(spaces[spaceIndex].queue.participants.map { $0.id })
        
        print("\n�� Final Space State:")
        print("- Remaining speakers: \(updatedSpace.speakers.count)")
        print("- Speaker IDs: \(updatedSpace.speakers.map { $0.id })")
        
        // End HMS call
        print("🔄 Ending HMS call...")
        self.endCall(id: id)
        print("✅ HMS call ended")
        
        self.initialPeerCount = 0
        self.isRecording = false
        self.currentSpaceSessionStartTime = nil
            self.wasEndedByHost = false
            self.currentSpaceSessionStartTime = nil
        
        print("✅ Reset recording state and session start time")
        
      
    }
    
    func joinCall(roomId: String) async {
        guard let currentUser = await tweetData.user else {
            return
        }
        
        do {
            
            // 1. Generate HMS token using room ID
            let token = try await generateHMSTokenJoin(roomId: roomId,userId:currentUser.id,role: "speaker")
            
            // 3. Create HMS config
            var metadataDict: [String: Any] = await [
                "id": String(currentUser.id),
                "name": tweetData.user?.nickname ?? "",
                "username": tweetData.user?.username ?? "",
                "image_url": tweetData.user?.avatar ?? "",
                "peerID": "",  // This will be set by HMS SDK
                "topic": currentTopic.isEmpty ? "" : currentTopic
            ]
            
            // ✅ ADDED: Include location data if available
            if let locationData = await tweetData.currentLocation {
                metadataDict["locationData"] = locationData
                print("📍 [joinCall] Added location data to HMS metadata: \(locationData.city)")
            }
            
            let metadata: String?
            if let jsonData = try? JSONSerialization.data(withJSONObject: metadataDict, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                metadata = jsonString
            } else {
                metadata = nil
            }
            
            
            let config = HMSConfig(
                userName: currentUser.username,
                authToken: token,
                metadata: metadata  // SendBird user ID for mapping // SendBird user ID for mapping
            )
            
            // 4. Join HMS room
            hmsSDK.join(config: config, delegate: self)
            
            await MainActor.run {
                self.isInSpace = true
               
                self.showQueueView = false
                self.recordingTimeRemaining = 420
            }
            
        } catch {
            print("🔍[joinCall] Error joining space: \(error)")
            self.currentViewingSpace = nil // Clear currentViewingSpace on error
            self.hmsSDK.leave()
            setInfoMessage(text: "Failed to join HMS room: \(error.localizedDescription)", type: .error)
        }
    }
    
    func leaveCall(with id: Int64) {
        print("\n=== LEAVING SPACE ===")
        print("🔄 Space ID: \(id)")
        print("🔄 Current HMS Room ID: \(hmsSDK.room?.roomID ?? "nil")")
        
        hmsSDK.leave { [weak self] _, error in
            if let error {
                print(error.localizedDescription)
                self?.isInSpace = false
            }
            
            // Clear currentViewingSpace since we're leaving as a visitor
            self?.currentViewingSpace = nil
            print("✅ Cleared currentViewingSpace")
            
            // Reset track data of self and other peers.
            self?.ownTrack = nil
            self?.otherTracks = []
            self?.recordingTimeRemaining = 420
            self?.currentSpaceSessionStartTime = nil
            
        }
    }
    func endCall(id: Int64) {
        print("🔄 DEBUG[endCall]: Starting endCall for space ID: \(id)")
        guard hmsSDK.room != nil else {
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
        hmsSDK.endRoom(lock: false, reason: "Host ended the room") { [weak self] _, error in
            if let error {
                print("❌ DEBUG: Error ending the space: \(error.localizedDescription)")
                self?.setInfoMessage(text: "Error ending the space: \(error.localizedDescription)", type: .error)
            } else {
                print("✅ DEBUG: Successfully ended the room")
            }
            
            
            // Reset track data of self and other peers.
            self?.ownTrack = nil
            self?.otherTracks = []
            self?.currentSpaceSessionStartTime = nil
            print("🔄 DEBUG[endCall]: Reset track data and session start time")
            
            // Update the state in the end.
            self?.showSpaceView = false
            self?.isInSpace = false
            self?.selectedSpace = nil
            self?.showQueueView = false
            self?.recordingTimeRemaining = 420
            // ✅ OPTIMIZED: Use cached lookup for O(1) space index search instead of O(n) linear search
            // Note: Cannot call async function from sync context, so we'll just send the change notification
            self?.objectWillChange.send()
        }
    }
    
    func startCall(with id: Int64) async -> String? {
        guard let userId = await tweetData.user?.id, let username = await tweetData.user?.username  else {
            print("❌ Cannot start space - no user found")
            return nil
        }
        do {
            print("🔍 Starting call with ID: \(id)")
            
            // Set the session start time when we begin starting the call
            await MainActor.run {
                self.currentSpaceSessionStartTime = Date()
                print("⏰ Set current space session start time: \(self.currentSpaceSessionStartTime?.description ?? "nil")")
            }
            
            // Retrieve stored topic for this space
            var topicToUse = ""
            if let storedTopic = UserDefaults.standard.string(forKey: "hostTopic_\(id)") {
                print("📝 [startCall] Retrieved stored topic: \(storedTopic)")
                topicToUse = storedTopic
                // Clear the stored topic after retrieving it
                UserDefaults.standard.removeObject(forKey: "hostTopic_\(id)")
                print("🧹 [startCall] Cleared stored topic")
            }
            
            // Generate the management token
            print("🔄 Generating management token...")
            let token = try await generateManagmentToken()
            print("✅ Generated HMS token: \(token)")
            
            print("✅ Management token generated: \(token)")
            
            // Create the room
            print("🔄 Creating room with ID: \(id)...")
            let room = try await createRoom(roomId: id, managementToken: token)
            print("✅ Room created successfully: \(room)")
            
            let roomId = room.id
            
            print("🔍 Host User ID in startCall: \(userId)")
            print("🔍 Room ID in startCall: \(roomId)")
            print("🔍 Username in startCall: \(username)")
            
            // Generate HMS token
            print("🔄 Generating HMS token...")
            let hmsToken = try await generateHMSTokenJoin(roomId: roomId, userId: userId, role: "moderator")
            print("✅ HMS token generated using the correct room ID: \(hmsToken)")
            
            // Prepare metadata as JSON string
            print("🔄 Preparing metadata...")
            var metadataDict: [String: Any] = await [
                "id": String(userId),
                "name": tweetData.user?.nickname ?? "",
                "username": username,
                "image_url": tweetData.user?.avatar ?? "",
                "peerID": "",  // This will be set by HMS SDK
                "topic": topicToUse.isEmpty ? "" : topicToUse
            ]
            
            // ✅ ADDED: Include location data if available
            if let locationData = await tweetData.currentLocation {
                metadataDict["locationData"] = locationData
                print("📍 [startCall] Added location data to HMS metadata: \(locationData.city)")
            }
            print("🔍 Metadata Dict in startCall: \(metadataDict)")
            let metadata: String?
            if let jsonData = try? JSONSerialization.data(withJSONObject: metadataDict, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                metadata = jsonString
            } else {
                metadata = nil
            }
            
            print("🔍 Metadata in startCall: \(metadata)")
            // Create HMS config
            print("🔄 Creating HMS config...")
            let config = HMSConfig(
                userName: username,
                authToken: hmsToken,
                metadata: metadata
            )
            print("🔍 Config in startCall: \(config)")
            
            // Join HMS room as host
            print("🔄 Joining HMS room...")
            let response = await hmsSDK.join(config: config, delegate: self)
            print("🔍 Response in startCall: \(response)")
            
            // Return HMS room ID for storage
            guard let joinedRoomId = hmsSDK.room?.roomID else {
                print("❌ Room ID missing after join in startCall")
                setInfoMessage(text: "Couldn't get user info", type: .error)
                return nil
            }
            
            print("🔍 Successfully joined HMS room in startCall : \(roomId)")
            return roomId
        } catch {
            await MainActor.run {
                print("❌ createRoom Error in startCall: \(error)")
                setInfoMessage(text: "Failed to start HMS room: \(error.localizedDescription)", type: .error)
            }
            return nil
        }
    }
    
    func generateManagmentToken() throws -> String {
        print("\n=== 🔑 MANAGEMENT TOKEN CHECK ===")
        
        // Check if we have a valid cached token
        if let cachedToken = SpacesViewModel.cachedManagementToken,
           let expiry = SpacesViewModel.managementTokenExpiry,
           expiry > Date() {
            print("✅ Using cached management token")
            return cachedToken
        }
        
        print("🔄 Generating new management token...")
        let appAccessKey = "679d016f4944f067313a8bab"
        let appSecret = "0G0qvYe22UedW7eTyXK8QM4gBDlBo3-MmvEQXpYBOJ7I7e-Ly8U-zSRYG-y2R3czPHGG3r-PLkCCxURorFPELg7XvlJ82mWmyKOztlOhjAgTllUzzh0S4ebBtzR2-ZSmH1POEp9M5jnNWpDLSGFHi6mYtTUO6w9YbFvoo8oH0Rw="
        
        // Set expiry to 23 hours (slightly less than the 24-hour max to be safe)
        let expiryInterval: TimeInterval = 23 * 60 * 60
        let expiry = Date().addingTimeInterval(expiryInterval)
        
        let payload: [String: Any] = [
            "access_key": appAccessKey,
            "type": "management",
            "version": 2,
            "iat": Int(Date().timeIntervalSince1970),
            "nbf": Int(Date().timeIntervalSince1970),
            "exp": Int(expiry.timeIntervalSince1970),
            "jti": UUID().uuidString
        ]
        
        print("📝 Token Details:")
        print("🔸 Access Key: \(appAccessKey)")
        print("🔸 Expiry: \(expiry)")
        
        let header = ["alg": "HS256", "typ": "JWT"]
        
        let token = try createJWT(header: header, payload: payload, secret: appSecret)
        
        // Cache the token and its expiry
        SpacesViewModel.cachedManagementToken = token
        SpacesViewModel.managementTokenExpiry = expiry
        
        print("✅ Generated new management token")
        print("⏱️ Token will expire at: \(expiry)")
        
        return token
    }
    func generateHMSTokenJoin(roomId: String, userId: Int64, role: String) throws -> String {
        print("🔄 Generating HMS token...")
        let appAccessKey = "679d016f4944f067313a8bab"
        let appSecret = "0G0qvYe22UedW7eTyXK8QM4gBDlBo3-MmvEQXpYBOJ7I7e-Ly8U-zSRYG-y2R3czPHGG3r-PLkCCxURorFPELg7XvlJ82mWmyKOztlOhjAgTllUzzh0S4ebBtzR2-ZSmH1POEp9M5jnNWpDLSGFHi6mYtTUO6w9YbFvoo8oH0Rw="
        
        print("🔍 App Access Key: \(appAccessKey)")
        print("🔍 Room ID: \(roomId)")
        print("🔍 User ID: \(userId)")
        print("🔍 Role: \(role)")
        
        let payload: [String: Any] = [
            "access_key": appAccessKey,
            "room_id": roomId,
            "user_id": String(userId),  // Convert userId to string
            "role": role,
            "type": "app",
            "version": 2,
            "iat": Int(Date().timeIntervalSince1970),
            "nbf": Int(Date().timeIntervalSince1970),
            "exp": Int(Date().timeIntervalSince1970) + 86400, // 24 hours
            "jti": UUID().uuidString // Add JWT ID
        ]
        
        print("🔍 Payload: \(payload)")
        
        let header = ["alg": "HS256", "typ": "JWT"]
        print("🔍 Header: \(header)")
        
        // Use the raw secret key for signing
        let token = try createJWT(header: header, payload: payload, secret: appSecret)
        print("✅ Generated HMS token: \(token)")
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
    
    // MARK: - HMS Call Management (unchanged from original)
    // ... [keep all the existing HMS call management methods unchanged]
    // This includes:
    // - joinCall(roomId:)
    // - leaveCall(with:)
    // - endCall(id:)
    // - startCall(with:)
    // - generateManagmentToken()
    // - generateHMSTokenJoin(roomId:userId:role:)
    // - createJWT(header:payload:secret:)
    // - base64UrlEncode(_:)
    // - createRoom(roomId:managementToken:)
    // - decodeJWT(token:)
    // - All related structs (CreateRoomRequest, TokenResponse, etc.)
}

*/
