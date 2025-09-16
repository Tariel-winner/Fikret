import Foundation
import AVFoundation
/*import SwiftPhoenixClient

class ChatService {
    // MARK: - Properties
    private var socket: Socket?
    private var channel: Channel?
    private let soundManager = SoundManager()
     private var isChannelJoined = false
    // Callback for message updates
    var onMessagesUpdated: (([Message]) -> Void)?
    var onConnectionStatusChanged: ((Bool) -> Void)?
   
private var currentUserId: String {
    // Generate and save if doesn't exist
    if let savedId = UserDefaults.standard.string(forKey: "currentUserId") {
        return savedId
    } else {
        let newId = "user_\(Int.random(in: 1000...9999))"
        UserDefaults.standard.set(newId, forKey: "currentUserId")
        return newId
    }
}

func connect() {
     guard socket == nil else {
            print("⚠️ Socket already exists")
            return
        }
    let socketURL = "ws://localhost:4000/socket"
 
    print("Connecting to: \(socketURL)")
    
    socket = Socket(socketURL, paramsClosure: {
        let userId = self.currentUserId ?? "unknown"
        print("Connecting with userId: \(userId)")
        return ["user_id": userId]
    })
    
    socket?.onOpen { [weak self] in
        print("🟢 Socket Connected Successfully!")
        self?.onConnectionStatusChanged?(true)
       self?.joinChannel()
    }
    
    socket?.onError { error in
        print("🔴 Socket Error: \(error)")
    }
    
    socket?.onClose {
        print("🟡 Socket Closed")
        self.onConnectionStatusChanged?(false)
    }
    
    print("Initiating connection...")
    socket?.connect()
}
    
    
    private func joinChannel() {
         guard !isChannelJoined else {
            print("⚠️ Channel already joined")
            return
        }
          print("🚪 Joining channel 'room:lobby'")
        channel = socket?.channel("room:lobby")
        
      
        
        channel?.join()
            .receive("ok") { [weak self] _ in
                print("Successfully joined channel")
                 self?.isChannelJoined = true
                self?.setupMessageHandler()
            }
            .receive("error") { error in
                print("❌ Failed to join channel: \(error)")
                 self.isChannelJoined = false
            }

            

    }
    
    // MARK: - Message Handling
    private func setupMessageHandler() {
        channel?.on("new_msg") { [weak self] message in
              print("📨 RECEIVED RAW MESSAGE: \(message.payload)") // Add logging
        
            guard let payload = message.payload as? [String: Any],
                  let text = payload["body"] as? String,
                  let userId = payload["user_id"] as? String else {
                     print("❌ Failed to parse message")
                      return }
            
        print("👤 Message from user: \(userId)") // Add logging
        
            let newMessage = Message(
                id: UUID().uuidString,
                text: text,
                userId: userId,
                timestamp: Date()
            )
            
            self?.handleNewMessage(newMessage)
        }
    }
    
    private func handleNewMessage(_ message: Message) {
         print("📝 Handling message: \(message.text) from user: \(message.userId)") // Add logging
    
        DispatchQueue.main.async { [weak self] in
            self?.soundManager.playMessageSound()
            self?.onMessagesUpdated?([message])
              print("✅ Message passed to UI") 
        }
    }
    
    func sendMessage(_ text: String) async throws {
         guard let channel = channel else {
        print("❌ Cannot send - Channel is nil!")
        return
    }
    
    print("\n🔌 CONNECTION STATE:")
    print("- Socket Connected: \(socket?.isConnected ?? false)")
    print("- Channel Joined: \(channel.isJoined)")
    
    let userId = currentUserId
    print("\n📤 STARTING MESSAGE SEND:")
    print("- Text: \(text)")
    print("- From User: \(userId)")
    print("- Channel: \(channel.topic ?? "no channel")")
    
    let payload = [
        "body": text,
        "user_id": userId,
        "timestamp": Date().timeIntervalSince1970
    ] as [String : Any]
    
    print("\n🔄 PUSHING TO SERVER:")
    print("- Payload: \(payload)")
    
    try await channel.push("new_msg", payload: payload)
        .receive("ok") { response in
            print("\n✅ SERVER RESPONSE - OK:")
            print("- Response: \(response)")
            print("- Time: \(Date())")
        }
        .receive("error") { error in
            print("\n❌ SERVER RESPONSE - ERROR:")
            print("- Error: \(error)")
            print("- Time: \(Date())")
        }
    
    print("\n🏁 SEND ATTEMPT COMPLETED")
}
    
    func retrieveMessages() {
        let payload = [:] as [String: Any]  // Empty payload or add parameters if needed
        
        channel?.push("get_messages", payload: payload)
            .receive("ok") { [weak self] response in
                if let messages = response.payload["messages"] as? [[String: Any]] {
                    let messageObjects = messages.compactMap { messageData -> Message? in
                        guard let id = messageData["id"] as? String,
                              let text = messageData["body"] as? String,
                              let userId = messageData["user_id"] as? String,
                              let timestamp = messageData["timestamp"] as? TimeInterval else {
                                  return nil
                              }
                        
                        return Message(
                            id: id,
                            text: text,
                            userId: userId,
                            timestamp: Date(timeIntervalSince1970: timestamp)
                        )
                    }
                    
                    DispatchQueue.main.async {
                        self?.onMessagesUpdated?(messageObjects)
                    }
                }
            }
            .receive("error") { error in
                print("Failed to retrieve messages: \(error)")
            }
    }
    // MARK: - Cleanup
    func disconnect() {
        channel?.leave()
        socket?.disconnect()
    }
}

// MARK: - Sound Manager
class SoundManager {
    private var player: AVAudioPlayer?
    
    func playMessageSound() {
        guard let url = Bundle.main.url(forResource: "futuristic_ringtone", withExtension: "mp3") else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Failed to play sound: \(error)")
        }
    }
}
*/
