/*import Foundation
import SwiftCentrifuge
import Combine

// MARK: - Centrifugo Service (Simplified & Reliable)
// Based on the official UIKit example for maximum reliability

enum ChannelType {
    case own
    case host
}
// Add response models
struct CentrifugoTokenResponse: Codable {
    let code: Int
    let msg: String
    let data: CentrifugoTokenData?
}

struct CentrifugoTokenData: Codable {
    let token: String
}
   

class CentrifugeService: NSObject, CentrifugeClientDelegate, CentrifugeSubscriptionDelegate {
    static let shared = CentrifugeService()
    private var client: CentrifugeClient?
    private var userChannel: CentrifugeSubscription?
    
    // ✅ SIMPLIFIED: Track visitor subscriptions directly
    private var visitorSubscriptions: [String: CentrifugeSubscription] = [:]
    
    private var connectionState: CentrifugeConnectionState = .disconnected
    
    // Centrifugo configuration
    private let centrifugoEndpoint = "ws://192.168.0.104:8000/connection/websocket"
    
    private override init() {
        super.init()
    }
    
    // MARK: - Initialization
    
    func initialize() {
        Task {
            do {
                // Try to get existing Centrifugo token first
                if let existingToken = try KeychainManager.shared.getCentrifugoToken() {
                    print("✅ Centrifugo: Using existing token from keychain")
                    await initializeClient(with: existingToken)
                } else {
                    // No existing token, fetch from API
                    print("🔄 Centrifugo: No existing token, fetching from API...")
                    let centrifugoToken = try await fetchCentrifugoToken()
                    
                    // Save to keychain for future use
                    try KeychainManager.shared.saveCentrifugoToken(centrifugoToken)
                    print("✅ Centrifugo: Token saved to keychain")
                    
                    await initializeClient(with: centrifugoToken)
                }
                
                // Auto-connect to user channel
                if let currentUser = await TweetData.shared.user {
                    print("🔄 Centrifugo: Auto-connecting to user channel for \(currentUser.username)...")
                    do {
                        _ = try await connectToUserChannel(userId: currentUser.id)
                        print("✅ Centrifugo: Auto-connected to user channel for \(currentUser.username)")
                    } catch {
                        print("❌ Centrifugo: Failed to auto-connect to user channel: \(error)")
                    }
                }
                
            } catch {
                print("❌ Centrifugo: Failed to initialize - will retry on login: \(error)")
            }
        }
    }
    
    private func initializeClient(with token: String) async {
        let config = CentrifugeClientConfig(
            token: token,
            tokenGetter: { [weak self] event, completion in
                // ✅ SIMPLIFIED: Use stored token for reconnection
                if let token = try? KeychainManager.shared.getCentrifugoToken() {
                    completion(.success(token))
                } else {
                    completion(.failure(CentrifugeError.networkError("No token available")))
                }
            }
        )
        
        client = CentrifugeClient(endpoint: centrifugoEndpoint, config: config, delegate: self)
        client?.connect()
        
        // Wait for connection to establish
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        print("✅ Centrifugo: Client initialized with token")
    }


    // Add this function to your API service class
    func fetchCentrifugoToken() async throws -> String {
        guard let token = try KeychainManager.shared.getToken() else {
            print("❌ [fetchCentrifugoToken] No auth token found")
            throw AuthError.notAuthenticated
        }
        
        let url = URL(string: "\(AuthConfig.baseURL)/v1/centrifugo/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🌐 [fetchCentrifugoToken] Making request to: \(url)")
        print("🔑 [fetchCentrifugoToken] Using token: \(String(token.prefix(10)))...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [fetchCentrifugoToken] Invalid response type")
            throw AuthError.networkError("Invalid response")
        }
        
        print("📊 [fetchCentrifugoToken] HTTP Status Code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ [fetchCentrifugoToken] HTTP error: \(httpResponse.statusCode)")
            throw AuthError.networkError("Centrifugo token fetch failed: \(httpResponse.statusCode)")
        }
        
        do {
            let tokenResponse = try JSONDecoder().decode(CentrifugoTokenResponse.self, from: data)
            
            guard tokenResponse.code == 0 else {
                print("❌ [fetchCentrifugoToken] API error: \(tokenResponse.msg)")
                throw AuthError.networkError(tokenResponse.msg)
            }
            
            guard let tokenData = tokenResponse.data else {
                print("❌ [fetchCentrifugoToken] No token data in response")
                throw AuthError.networkError("No token data in response")
            }
            
            print("✅ [fetchCentrifugoToken] Successfully received Centrifugo token")
            return tokenData.token
            
        } catch {
            print("❌ [fetchCentrifugoToken] Decoding error: \(error)")
            throw AuthError.networkError("Failed to decode response: \(error.localizedDescription)")
        }
    }
    
    // New method to initialize when user logs in or signs up
    func initializeForUser(userId: Int64, username: String) async {
        print("🔄 Centrifugo: Initializing for new user: \(username) (ID: \(userId))")
        
        // 🛡️ BULLETPROOF: Clear any existing user channel first to prevent conflicts
        if let existingChannel = userChannel {
            print("🧹 Centrifugo: Clearing existing user channel: \(existingChannel.channel)")
            existingChannel.unsubscribe()
            userChannel = nil
        }
        
        do {
            // Fetch Centrifugo token from API
            let centrifugoToken = try await fetchCentrifugoToken()
            print("🔑 Centrifugo: Fetched token from API for user: \(username)")
            
            // Save to keychain for future use
            try KeychainManager.shared.saveCentrifugoToken(centrifugoToken)
            print("✅ Centrifugo: Token saved to keychain")
            
            // Initialize client with new token
            await initializeClient(with: centrifugoToken)
            print("✅ Centrifugo: Client initialized for new user \(username)")
            
            // Auto-connect to user channel
            print("🔄 Centrifugo: Auto-connecting to user channel for new user \(username)...")
            do {
                _ = try await connectToUserChannel(userId: userId)
                print("✅ Centrifugo: Auto-connected to user channel for new user \(username)")
            } catch {
                print("❌ Centrifugo: Failed to auto-connect to user channel for new user \(username): \(error)")
            }
            
        } catch {
            print("❌ Centrifugo: Failed to initialize for user \(username): \(error)")
        }
    }
    

    // MARK: - CentrifugeClientDelegate Methods
    
    func onConnecting(_ client: CentrifugeClient, _ event: CentrifugeConnectingEvent) {
        connectionState = .connecting
        print("🔄 Centrifugo: Connecting to server...")
    }
    
    @MainActor func onConnected(_ client: CentrifugeClient, _ event: CentrifugeConnectedEvent) {
        connectionState = .connected
     
        // 🛡️ BULLETPROOF: Only auto-resubscribe if we have a current user AND the channel matches
        if let currentUser = TweetData.shared.user,
           let channelName = userChannel?.channel,
           let userIdString = channelName.split(separator: ":").last,
           let userIdInt = Int64(userIdString),
           userIdInt == currentUser.id {  // Only resubscribe if channel matches current user
            print("🔄 Centrifugo: Auto-resubscribing to existing user channel: \(channelName)")
            Task {
                do {
                    _ = try await connectToUserChannel(userId: userIdInt)
                    print("✅ Centrifugo: Auto-resubscribed to user channel: \(channelName)")
                } catch {
                    print("❌ Centrifugo: Failed to auto-resubscribe to user channel: \(channelName): \(error)")
                }
            }
        } else {
            print("ℹ️ Centrifugo: No valid user channel to resubscribe to")
            // Clear any stale userChannel reference
            if userChannel != nil {
                print("🧹 Centrifugo: Clearing stale user channel reference")
                userChannel = nil
            }
        }
    }
    
    func onDisconnected(_ client: CentrifugeClient, _ event: CentrifugeDisconnectedEvent) {
        connectionState = .disconnected
        print("❌ Centrifugo: Disconnected from server - reason: \(event.reason)")
    }
    
    // MARK: - Simplified Channel Management
    
    // MARK: - User Channel Management
    
    func connectToUserChannel(userId: Int64) async throws -> CentrifugeSubscription {
        print("🔄 Centrifugo: Connecting to user channel for user ID: \(userId)")
        
        guard let client = client else {
            print("❌ Centrifugo: Client not initialized - cannot connect to channel")
            throw CentrifugeError.clientNotInitialized
        }
        
        let channelName = "user:\(userId)"
        print("📡 Centrifugo: Connecting to channel: \(channelName)")
        
        // ✅ SIMPLIFIED: Direct connection without complex retry logic
        do {
            let sub = try client.newSubscription(channel: channelName, delegate: self)
            userChannel = sub
            print("✅ Centrifugo: Subscription created for channel: \(channelName)")
            
            sub.subscribe()
            print("🔄 Centrifugo: Subscribe called for channel: \(channelName)")
            
            print("✅ Centrifugo: Connected to own channel user:\(userId)")
            return sub
            
        } catch {
            print("❌ Centrifugo: Failed to connect to channel \(channelName): \(error)")
            throw CentrifugeError.channelCreationFailed(error)
        }
    }
    
    // MARK: - CentrifugeSubscriptionDelegate Methods
    
    func onSubscribing(_ subscription: CentrifugeSubscription, _ event: CentrifugeSubscribingEvent) {
        print("🔄 Centrifugo: Subscribing to channel \(subscription.channel)...")
    }
    
    func onSubscribed(_ subscription: CentrifugeSubscription, _ event: CentrifugeSubscribedEvent) {
        print("✅ Centrifugo: Successfully subscribed to channel \(subscription.channel)")
    }
    
    func onUnsubscribed(_ subscription: CentrifugeSubscription, _ event: CentrifugeUnsubscribedEvent) {
        print("❌ Centrifugo: Unsubscribed from channel \(subscription.channel)")
    }
    
    func onPublication(_ subscription: CentrifugeSubscription, _ event: CentrifugePublicationEvent) {
        print("\n=== 📨 CENTRIFUGO ONPUBLICATION TRIGGERED ===")
        print("📡 Channel: \(subscription.channel)")
      
        print("🔄 Calling handleUserChannelMessage...")
        
        handleUserChannelMessage(event)
        
        print("✅ handleUserChannelMessage completed")
        print("=== END ONPUBLICATION ===\n")
    }
    
    func onPresence(_ subscription: CentrifugeSubscription, _ event: CentrifugePresenceResult) {
        // Handle presence updates in real-time
        let channelName = subscription.channel
        
        // Check if this is a user channel (format: "user:123")
        if channelName.hasPrefix("user:") {
            let userIdString = String(channelName.split(separator: ":").last ?? "")
            if let hostId = Int64(userIdString) {
                // Determine if user is online based on presence data
                let isOnline = !event.presence.isEmpty
                
                // Notify SpacesViewModel of the presence update
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("HostPresenceUpdate"),
                        object: nil,
                        userInfo: [
                            "hostId": hostId,
                            "isOnline": isOnline
                        ]
                    )
                }
                
                print("👥 Centrifugo: Presence update for user:\(hostId) - \(isOnline ? "online" : "offline")")
            }
        }
    }
    
    // MARK: - Message Handling
    
    public func handleUserChannelMessage(_ event: CentrifugePublicationEvent) {
        print("\n=== 📨 CENTRIFUGO MESSAGE RECEIVED ===")
        print("📨 Raw event data: \(event.data)")
        print("📨 Event data type: \(type(of: event.data))")
     
        // Handle different data types that Centrifugo might send
        var data: [String: Any] = [:]
        
        if let dictData = event.data as? [String: Any] {
            data = dictData
        } else if let jsonData = event.data as? Data {
            // Try to parse JSON data
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    data = jsonObject
                } else {
                    print("❌ Failed to parse JSON data as dictionary")
                    return
                }
            } catch {
                print("❌ Failed to parse JSON data: \(error)")
                return
            }
        } else if let stringData = event.data as? String {
            // Try to parse string as JSON
            do {
                if let jsonData = stringData.data(using: .utf8),
                   let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    data = jsonObject
                } else {
                    print("❌ Failed to parse string data as JSON")
                    return
                }
            } catch {
                print("❌ Failed to parse string data: \(error)")
                return
            }
        } else {
            print("❌ Unsupported data type: \(type(of: event.data))")
            return
        }
        
        guard let type = data["type"] as? String else {
            print("❌ Missing message type in data: \(data)")
            return
        }
        
        // Get current user ID from channel name
        let currentUserId = userChannel?.channel.split(separator: ":").last.flatMap { Int64(String($0)) }
        print("👤 Current user ID from channel: \(currentUserId ?? -1)")
        
        // ✅ EXACT SAME LOGIC AS ABLY: Check message routing based on channelType and targetUserId
        let channelType = data["channelType"] as? String
        print("🎯 Channel Type: \(channelType ?? "unknown")")
        
        if let targetUserId = data["targetUserId"] as? Int64 {
            print("🎯 Target user ID: \(targetUserId)")
            
            // Route messages based on channelType (EXACT SAME LOGIC AS ABLY)
            switch channelType {
            case "host":
                // Message from visitor to host - host should process if targetUserId matches
                if targetUserId != currentUserId {
                    print("❌ Message not intended for current user - ignoring")
                    return
                }
                print("✅ Processing host message intended for current user")
                
            case "own":
                // Message from own channel - always process
                print("✅ Processing own channel message")
                
            default:
                // Legacy format - check targetUserId
                if targetUserId != currentUserId {
                    print("❌ Message not intended for current user - ignoring")
                    return
                }
                print("✅ Processing legacy format message")
            }
        } else {
            print("ℹ️ No target user ID specified - processing based on channelType")
            // If no targetUserId, only process own channel messages
            if channelType != "own" {
                print("❌ No targetUserId and not own channel - ignoring")
                return
            }
        }
        
        print("✅ Processing message of type: \(type)")
        print("📨 Full message data: \(data)")
        
        switch type {
        case "space_join_request":
            print("👥 Posting SpaceJoinRequest notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("SpaceJoinRequest"),
                object: nil,
                userInfo: ["data": data]
            )
        case "room_created":
            print("🏠 Posting RoomCreated notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("RoomCreated"),
                object: nil,
                userInfo: ["data": data]
            )
        case "queue_update":
            print("📋 Posting QueueUpdate notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("QueueUpdate"),
                object: nil,
                userInfo: data["data"] as? [String: Any] ?? data
            )
        case "user_update":
            print("👤 Posting UserUpdate notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("UserUpdate"),
                object: nil,
                userInfo: data
            )
        case "end_room":
            print("🔚 Posting EndRoom notification")
            NotificationCenter.default.post(
                name: NSNotification.Name("EndRoom"),
                object: nil,
                userInfo: data
            )
        default:
            print("❓ Unknown message type: \(type)")
        }
        
        print("=== END MESSAGE PROCESSING ===\n")
    }
    
    // MARK: - Accessors
    
    var chatClient: CentrifugeClient? {
        return client
    }
    
    func getSubscription(channel: String) -> CentrifugeSubscription? {
        // Check user channel first
        if let sub = userChannel, sub.channel == channel {
            return sub
        }
        
        // Check visitor subscriptions
        return visitorSubscriptions[channel]
    }
    
    // MARK: - Simplified Presence Management
    
    func ensureHostPresence(userId: Int64) {
        print("🔄 Centrifugo: Ensuring host presence for user ID: \(userId)")
        // Just subscribe to the channel - presence is automatic
        Task {
            do {
                _ = try await connectToUserChannel(userId: userId)
                print("✅ Centrifugo: Host presence ensured for user ID: \(userId)")
            } catch {
                print("❌ Centrifugo: Failed to ensure host presence for user ID: \(userId): \(error)")
            }
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupUserChannel(userId: Int64) {
        let userChannelName = "user:\(userId)"
        print("🧹 Centrifugo: Cleaning up user channel: \(userChannelName)")
        
        if let sub = userChannel, sub.channel == userChannelName {
            sub.unsubscribe()
            userChannel = nil
            print("✅ Centrifugo: Unsubscribed from own channel user:\(userId)")
        } else {
            print("ℹ️ Centrifugo: No active subscription found for channel: \(userChannelName)")
        }
    }
    
    // MARK: - App Lifecycle Methods
    
    // ✅ SIMPLIFIED: Single method for all cleanup needs
    
    func disconnectClient() {
        // 🛡️ BULLETPROOF: Clean up ALL subscriptions before disconnecting
        cleanupAllSubscriptions()
        
        client?.disconnect()
        client = nil
        connectionState = .disconnected
        print("❌ Centrifugo: Disconnected client (logout)")
    }
    
    // MARK: - Visitor Channel Management
    
    /// Create a subscription to another user's channel (for visitors)
    func createVisitorSubscription(to hostChannelName: String, onMessage: @escaping ([String: Any]) -> Void, onPresence: @escaping (CentrifugePresenceResult) -> Void = { _ in }) throws -> CentrifugeSubscription {
        guard let client = client else {
            throw CentrifugeError.clientNotInitialized
        }
        
        print("🔄 Centrifugo: Creating visitor subscription to channel: \(hostChannelName)")
        
        // ✅ SIMPLIFIED: Use self as delegate instead of creating separate delegate
        let subscription = try client.newSubscription(channel: hostChannelName, delegate: self)
        
        // Store the subscription for cleanup
        visitorSubscriptions[hostChannelName] = subscription
        
        // Subscribe to the channel
        subscription.subscribe()
        
        print("✅ Centrifugo: Visitor subscription created and subscribed for channel: \(hostChannelName)")
        return subscription
    }
    
    // MARK: - Cleanup Methods
    
    func cleanupVisitorSubscription(for channelName: String) {
        guard let subscription = visitorSubscriptions[channelName] else {
            print("ℹ️ Centrifugo: No visitor subscription found for channel: \(channelName)")
            return
        }
        
        print("🧹 Centrifugo: Cleaning up visitor subscription for channel: \(channelName)")
        subscription.unsubscribe()
        visitorSubscriptions.removeValue(forKey: channelName)
        print("✅ Centrifugo: Visitor subscription cleaned up for channel: \(channelName)")
    }
    
    // 🛡️ BULLETPROOF: Clean up ALL subscriptions (user + visitor) in one call
    func cleanupAllSubscriptions() {
        print("🛡️ Centrifugo: Cleaning up ALL subscriptions")
        
        // Clean up user channel
        if let sub = userChannel {
            let channelName = sub.channel
            sub.unsubscribe()
            userChannel = nil
            print("🧹 Centrifugo: Cleaned up user channel: \(channelName)")
        }
        
        // Clean up all visitor subscriptions directly (no need for separate method)
        for (channelName, subscription) in visitorSubscriptions {
            print("🧹 Centrifugo: Cleaning up visitor subscription for channel: \(channelName)")
            subscription.unsubscribe()
        }
        visitorSubscriptions.removeAll()
        
        print("✅ Centrifugo: ALL subscriptions cleaned up")
    }
}



// Error and Config Types
enum CentrifugeError: Error {
    case clientNotInitialized
    case channelCreationFailed(Error?)
    case channelNotFound
    case messageSendFailed
    case networkError(String)
    case subscriptionUnsubscribe(String)
    
    var localizedDescription: String {
        switch self {
        case .clientNotInitialized:
            return "Centrifugo client not initialized"
        case .channelCreationFailed(let error):
            return "Failed to create channel: \(error?.localizedDescription ?? "Unknown error")"
        case .channelNotFound:
            return "Channel not found"
        case .messageSendFailed:
            return "Failed to send message"
        case .networkError(let message):
            return "Network error: \(message)"
        case .subscriptionUnsubscribe(let channel):
            return "Subscription error on channel \(channel)"
        }
    }
}

enum CentrifugeConnectionState {
    case disconnected
    case connecting
    case connected
    case failed
}

// CentrifugeClientConfig is provided by the SwiftCentrifuge SDK
*/
