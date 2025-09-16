import SwiftUI
import Foundation
/*

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var showingLogoutAlert = false
    @Binding var isProfilePictureClicked: Bool
    
    var body: some View {
        VStack {
            // Messages List
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                        MessageRow(message: message)
                    }
                }
                .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            // Input Area
            MessageInputView(
                text: $messageText,
                onSend: {
                    viewModel.sendMessage(messageText)
                    messageText = ""
                }
            )
        }
        .navigationBarItems(trailing: Button(action: {
                    isProfilePictureClicked.toggle()  // You can use it here if needed
                }) {
                    Image(systemName: "person.circle")
                })
           
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
           guard let lastMessage = viewModel.messages.last else { return }
           withAnimation {
               proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

// Message Row
struct MessageRow: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            Text(message.text)
                .padding()
                .background(message.isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                .cornerRadius(16)
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
    }
}

// Input View
struct MessageInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    
    var body: some View {
        HStack {
            TextField("Message", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
            }
        }
    }
}
*/
