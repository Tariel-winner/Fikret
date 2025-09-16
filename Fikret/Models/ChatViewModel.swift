import Foundation
/*

class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    private let chatService: ChatService
    private let soundManager = SoundManager()
     
    private func setupMessageListener() {
           // Use the correct callback from ChatService
           chatService.onMessagesUpdated = { [weak self] newMessages in
               DispatchQueue.main.async {
                   self?.messages = newMessages
               }
           }
 
        // ✅ 2. Listening for connection status
            chatService.onConnectionStatusChanged = { [weak self] isConnected in
            print("Chat connection status: \(isConnected)")
        }
       }

    init(chatService: ChatService = ChatService()) {
        self.chatService = chatService
        setupMessageListener()
        chatService.connect()
    }
    
    func sendMessage(_ text: String) {
        Task {
               // Create message outside do-catch so it's accessible in both blocks
               let newMessage = Message(
                   id: UUID().uuidString,
                   text: text,
                   userId: UserDefaults.standard.string(forKey: "currentUserId") ?? "",
                   timestamp: Date()
               )
               
               do {
                   // Add message with pending state
                   DispatchQueue.main.async {
                       self.messages.append(newMessage)
                   }
                   
                   // Try to send to server
                   try await chatService.sendMessage(text)
                   soundManager.playMessageSound()
                   
               } catch {
                   print("❌ Failed to send message: \(error)")
                   // Now newMessage is in scope
                   DispatchQueue.main.async {
                       self.messages.removeAll { $0.id == newMessage.id }
                   }
               }
           }
    }
     deinit {
        // ✅ 4. Cleanup
        chatService.disconnect()
    }
    

}
*/
