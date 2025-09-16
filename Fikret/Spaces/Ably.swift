import Ably

// Service to handle user channels and queue management
class AblyService {
    static let shared = AblyService()
    private var client: ARTRealtime?
    private var userChannel: ARTRealtimeChannel?
    
    func initialize(userId: Int64? = nil) {
        print("🔄 Initializing Ably service")
        let options = ARTClientOptions()
        options.key = "gFTVVQ.DTafDw:NafNW_xTpSGkVJUqomr55lSMnkXKFayyC176JKZfJec"
        
        // Set client ID to a unique identifier
        if let userId = userId {
            options.clientId = "user:\(userId)"
            print("👤 Setting Ably client ID to: user:\(userId)")
        } else if let userId = UserDefaults.standard.string(forKey: "currentUserId") {
            options.clientId = "user:\(userId)"
            print("👤 Setting Ably client ID to: user:\(userId) (from UserDefaults)")
        }
        
        client = ARTRealtime(options: options)
        print("✅ Ably client initialized with ID: \(client?.clientId ?? "unknown")")
        
        // Basic connection logging
        client?.connection.on { stateChange in
            print("Ably connection state: \(stateChange.current)")
        }
        
        // ✅ FIXED: Automatically connect to user's own channel when initializing
        if let userId = userId {
            print("📡 Auto-connecting to user's own channel: user:\(userId)")
            Task {
                do {
                    try await connectToUserChannel(userId: userId)
                    print("✅ Successfully connected to own channel during initialization")
                } catch {
                    print("❌ Failed to connect to own channel during initialization: \(error)")
                }
            }
        }
    }
    
    // Mimicking StreamChat's client access
    var chatClient: ARTRealtime? {
        return client
    }
    
    // Connect to an existing user channel (passive by default)
    func connectToUserChannel(userId: Int64) async throws -> ARTRealtimeChannel {
        print("🔄 Connecting to user channel for user: \(userId)")
        
        guard let client = client else {
            print("❌ Ably client not initialized")
            throw AblyError.clientNotInitialized
        }
        
        let channelName = "user:\(userId)"
        let channel = client.channels.get(channelName)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ARTRealtimeChannel, Error>) in
            channel.attach { error in
                if let error = error {
                    print("❌ User channel attach failed: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ User channel connected successfully: \(channelName)")
                    self.userChannel = channel
                    
                    // Setup persistent subscriptions
                    self.setupMessageSubscription(channel: channel)
                    self.setupPresenceMonitoring(channel: channel)
                    
                    // Enter presence as host for own channel
                    let hostData: [String: Any] = [
                        "id": userId,
                        "role": "host",
                        "isOnline": true
                    ]
                    
                    print("📤 Entering presence as host with data: \(hostData)")
                    channel.presence.enter(hostData) { error in
                        if let error = error {
                            print("❌ Failed to enter presence as host: \(error)")
                            continuation.resume(throwing: error)
                        } else {
                            print("✅ Successfully entered presence as host")
                            continuation.resume(returning: channel)
                        }
                    }
                }
            }
        }
    }
    
    private func setupMessageSubscription(channel: ARTRealtimeChannel) {
        print("📡 Setting up message subscription for channel: \(channel.name)")
        
        channel.subscribe { [weak self] message in
            print("📨 Raw message received on channel: \(channel.name)")
            print("🔍 Message type: \(message.name)")
            print("🔍 Message data: \(message.data ?? "nil")")
            self?.handleUserChannelMessage(message)
        }
        print("✅ Successfully subscribed to channel: \(channel.name)")
    }
    
    private func setupPresenceMonitoring(channel: ARTRealtimeChannel) {
        print("🔄 Setting up presence monitoring for channel: \(channel.name)")
        
        channel.presence.subscribe { presence in
            print("📡 Presence event received:")
            print("  - Action: \(presence.action)")
            print("  - Client ID: \(presence.clientId ?? "unknown")")
            
            if let data = presence.data as? [String: Any] {
                print("  - Data: \(data)")
            }
            
            switch presence.action {
            case .enter:
                print("👥 Visitor entered channel: \(presence.clientId ?? "unknown")")
            case .leave:
                print("👋 Visitor left channel: \(presence.clientId ?? "unknown")")
            case .update:
                print("🔄 Presence updated for: \(presence.clientId ?? "unknown")")
            default:
                print("📡 Other presence action: \(presence.action)")
                break
            }
        }
    }
    
    // Subscribe to channel messages (call this when host becomes active)
    func subscribeToUserChannel() {
        guard let channel = userChannel else { return }
        
        print("📡 Subscribing to user channel: \(channel.name)")
        setupMessageSubscription(channel: channel)
    }
    
    // Unsubscribe from channel messages (call this when host becomes inactive)
    func unsubscribeFromUserChannel() {
        guard let channel = userChannel else { return }
        
        print("📡 Unsubscribing from user channel: \(channel.name)")
        channel.unsubscribe()
    }
    
    public func handleUserChannelMessage(_ message: ARTMessage) {
        print("\n=== HANDLING USER CHANNEL MESSAGE ===")
        print("👤 Current client ID: \(client?.clientId ?? "unknown")")
        print("📦 Message data: \(message.data ?? "nil")")
        print("🔍 Channel name: \(userChannel?.name ?? "unknown")")
        print("🔍 Message name: \(message.name)")
 
        if let data = message.data as? [String: Any] {
            // Extract target user ID from message if present
            let targetUserId = data["targetUserId"] as? Int64
            
            // Get current user ID from client ID
            let currentUserId = client?.clientId?.split(separator: ":").last.flatMap { Int64($0) }
            
            // Get channel type from message data
            let messageChannelType = data["channelType"] as? String
            
            print("🔍 Message details:")
            print("  - Target User ID: \(targetUserId ?? -1)")
            print("  - Current User ID: \(currentUserId ?? -1)")
            print("  - Message Type: \(message.name)")
            print("  - Channel Type: \(messageChannelType ?? "unknown")")
            print("  - Message Data: \(data)")
            
            // For host channel messages, we want to process messages where we are the target
            // For own channel messages, we process messages where we are the target
            let shouldProcess = targetUserId == currentUserId || messageChannelType == "own"
            
            guard shouldProcess else {
                print("📨 Ignoring message - not intended for current user")
                print("  - Target User ID: \(targetUserId ?? -1)")
                print("  - Current User ID: \(currentUserId ?? -1)")
                print("  - Channel Type: \(messageChannelType ?? "unknown")")
                return
            }
            
            print("✅ Processing message for current user")
            switch message.name {
            case "space_join_request":
                print("👥 Received space join request")
                print("📦 Join request data: \(data)")
                
                // Store topic in UserDefaults for the host to use in startSpace
                if let topic = data["topic"] as? String,
                   let spaceId = data["spaceId"] as? Int64 {
                    print("📝 Storing topic for space \(spaceId): \(topic)")
                    UserDefaults.standard.set(topic, forKey: "hostTopic_\(spaceId)")
                }
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("SpaceJoinRequest"),
                    object: nil,
                    userInfo: ["data": data]
                )
            case "room_created":
                print("🏠 Received room created message")
                print("📦 Room created data: \(data)")
                
                // Verify required fields
                guard let roomId = data["hmsRoomId"] as? String,
                      let spaceId = data["spaceId"] as? Int64,
                      let targetUserId = data["targetUserId"] as? Int64,
                      let hostId = data["hostId"] as? Int64 else {
                    print("❌ Invalid room_created message format")
                    print("Expected fields: hmsRoomId, spaceId, targetUserId, hostId")
                    print("Received data: \(data)")
                    return
                }
                
                // Get current user ID from client ID
                let currentUserId = client?.clientId?.split(separator: ":").last.flatMap { Int64($0) }
                
                print("🔍 Message verification:")
                print("  - Room ID: \(roomId)")
                print("  - Space ID: \(spaceId)")
                print("  - Target User ID: \(targetUserId)")
                print("  - Host ID: \(hostId)")
                print("  - Current User ID: \(currentUserId ?? -1)")
                
                // Only process if message is for current user
                guard targetUserId == currentUserId else {
                    print("📨 Ignoring room_created message - not intended for current user")
                    print("  - Target User ID: \(targetUserId)")
                    print("  - Current User ID: \(currentUserId ?? -1)")
                    return
                }
                
                print("✅ Processing room_created message for current user")
                NotificationCenter.default.post(
                    name: NSNotification.Name("RoomCreated"),
                    object: nil,
                    userInfo: data
                )
                print("✅ RoomCreated notification posted")
            case "queue_update":
                print("📊 Received queue update")
                // Handle nested data structure
                if let nestedData = data["data"] as? [String: Any] {
                    print("📦 Queue update nested data: \(nestedData)")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("QueueUpdate"),
                        object: nil,
                        userInfo: nestedData
                    )
                } else {
                    // Handle direct data structure (backward compatibility)
                    NotificationCenter.default.post(
                        name: NSNotification.Name("QueueUpdate"),
                        object: nil,
                        userInfo: data
                    )
                }
            case "user_update":
                print("👤 Received user update")
                NotificationCenter.default.post(
                    name: NSNotification.Name("UserUpdate"),
                    object: nil,
                    userInfo: data
                )
            case "end_room":
                print("🔚 Received end room")
                NotificationCenter.default.post(
                    name: NSNotification.Name("EndRoom"),
                    object: nil,
                    userInfo: data
                )
            default:
                print("📨 Received unknown message type: \(message.name)")
            }
        }
    }
    
    // Create a unique channel for a user
    func createUserChannel(userId: Int64) async throws -> ARTRealtimeChannel {
        print("🔄 Creating user channel for user: \(userId)")
        
        guard let client = client else {
            print("❌ Ably client not initialized")
            throw AblyError.clientNotInitialized
        }
        
        let channelName = "user:\(userId)"
        let channel = client.channels.get(channelName)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            channel.attach { error in
                if let error = error {
                    print("❌ User channel attach failed: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ User channel created successfully: \(channelName)")
                    self.userChannel = channel
                    continuation.resume()
                }
            }
        }
        
        return channel
    }
    
    // Add new method to ensure host presence
    func ensureHostPresence(userId: Int64) {
        print("🔄 Ensuring host presence for user: \(userId)")
        guard let client = client else {
            print("❌ Ably client not initialized")
            return
        }
        
        print("👤 Current Ably client ID: \(client.clientId ?? "unknown")")
        
        let channelName = "user:\(userId)"
        let channel = client.channels.get(channelName)
        
        // First attach to the channel
        channel.attach { [weak self] error in
            if let error = error {
                print("❌ Failed to attach to channel: \(error)")
                return
            }
            
            print("✅ Successfully attached to channel: \(channelName)")
            
            // Enter presence as host
            let hostData: [String: Any] = [
                "id": userId,
                "role": "host",
                "isOnline": true
            ]
            
            print("📤 Entering presence with data: \(hostData)")
            channel.presence.enter(hostData) { error in
                if let error = error {
                    print("❌ Failed to enter presence as host: \(error)")
                    print("❌ Error details - Code: \(error.code), Message: \(error.message)")
                } else {
                    print("✅ Successfully entered presence as host")
                    
                    // Verify presence after entering
                    channel.presence.get { members, error in
                        if let error = error {
                            print("❌ Failed to verify presence: \(error)")
                        } else {
                            print("👥 Current presence members: \(members?.count ?? 0)")
                            if let members = members {
                                for member in members {
                                    print("- Member: \(member.clientId ?? "unknown")")
                                    if let data = member.data as? [String: Any] {
                                        print("  Data: \(data)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ✅ SIMPLE: Reconnect only if needed - checks if user is already subscribed to their channel
    func reconnectIfNeeded() {
        print("🔍 Checking if Ably reconnection is needed...")
        
        // Check if client exists and is connected
        guard let client = client else {
            print("❌ Ably client not initialized - calling initialize()")
            initialize()
            return
        }
        
        // Check if user channel exists
        guard let userChannel = userChannel else {
            print("❌ No user channel found - need to reconnect")
            reconnectUserChannel()
            return
        }
        
        // Check if channel is attached
        if userChannel.state != .attached {
            print("❌ User channel not attached (state: \(userChannel.state)) - reconnecting")
            reconnectUserChannel()
            return
        }
        
        print("✅ Ably connection is healthy - no reconnection needed")
    }
    
    // Helper method to reconnect user channel
    private func reconnectUserChannel() {
        print("🔄 Reconnecting user channel...")
        
        // Get current user ID from client ID
        guard let clientId = client?.clientId,
              let userIdString = clientId.split(separator: ":").last,
              let userId = Int64(userIdString) else {
            print("❌ Could not extract user ID from client ID: \(client?.clientId ?? "unknown")")
            return
        }
        
        // Reconnect to user channel
        Task {
            do {
                try await connectToUserChannel(userId: userId)
                print("✅ Successfully reconnected to user channel")
            } catch {
                print("❌ Failed to reconnect to user channel: \(error)")
            }
        }
    }
}

// Custom errors for Ably operations
enum AblyError: Error {
    case clientNotInitialized
    case channelCreationFailed(Error?)
    case channelNotFound
    case messageSendFailed
}

