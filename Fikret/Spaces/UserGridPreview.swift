import SwiftUI

struct User: Identifiable {
    let id = UUID()
    let name: String
    let imageURL: String
    let topic: String?
    let isVerified: Bool
    let followerCount: Int
}

struct InvitedBadge: View {
    @State private var animate = false
    @State private var rotationAngle = 0.0
    @State private var glowOpacity = 0.0
    
    var body: some View {
        ZStack {
            // Glowing background
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.green.opacity(0.3), Color.green.opacity(0)]),
                        center: .center,
                        startRadius: 2,
                        endRadius: 20
                    )
                )
                .frame(width: 30, height: 30)
                .opacity(glowOpacity)
                .scaleEffect(animate ? 1.2 : 1.0)
            
            // Main badge
            ZStack {
                // Background circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                    .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Icon
                Image(systemName: "person.fill.checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotationAngle))
                    .symbolEffect(.bounce.up.byLayer, options: .repeating, value: animate)
            }
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 24, height: 24)
            )
            
            // Animated rings
            ForEach(0..<2) { index in
                Circle()
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    .frame(width: 24 + CGFloat(index * 8),
                           height: 24 + CGFloat(index * 8))
                    .scaleEffect(animate ? 1.5 : 1.0)
                    .opacity(animate ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).repeatForever(autoreverses: true)) {
                animate = true
            }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.8
            }
        }
    }
}

struct UserListCellForGrid: View {
    let user: QueueUser
    @State private var showTopicDetail = false
    @State private var isPressed = false
    @State private var isHovered = false
    @State private var showActions = false  // Add this back
    @State private var showRemoveConfirmation = false
    var onRemoveRequest: ((QueueUser) -> Void)? = nil
      // Add this function back
      private func toggleActionsPanel() {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
              showActions.toggle()
          }
      }
    var body: some View {
        VStack(spacing: 0) {
            // Main Content
            HStack(spacing: 16) {
                // Profile Image with Animation
                ProfileImageView(imageURL: user.image, isHovered: isHovered)
                
                // User Info
                VStack(alignment: .leading, spacing: 6) {
                    // Name and Badge
                    HStack(spacing: 4) {
                        Text(user.name)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                        
                        if user.isInvited {
                            InvitedBadge()
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    // Follower Count with Animation
                  //  FollowerCountView(count: user.followerCount)
                    
                    // Topic Button with Animation
                    if let topic = user.topic {
                        TopicButton(
                            topic: topic,
                            isPressed: $isPressed,
                            showTopicDetail: $showTopicDetail
                        )
                    }
                }
                
                Spacer()
                
                OptionsButton {
                    toggleActionsPanel()
                }

            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.95))
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.1),
                                Color.blue.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            
            // Expandable Actions Section
            if showActions {
                ActionsPanelView(user: user)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isHovered = isHovered
            }
        }
        .sheet(isPresented: $showTopicDetail) {
            TopicDetailView(topic: user.topic ?? "", userName: user.name)
        }
    }
}

// 1. Avatar Component
private struct AnimatedAvatar: View {
    let imageURL: String
    let animateContent: Bool
    
    var body: some View {
        ZStack {
            // Animated circles
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 100 + CGFloat(i * 20), height: 100 + CGFloat(i * 20))
                    .scaleEffect(animateContent ? 1.1 : 0.9)
                    .opacity(animateContent ? 0 : 1)
                    .animation(.easeInOut(duration: 1.5).repeatForever().delay(Double(i) * 0.2), value: animateContent)
            }
            
            AsyncImage(url: URL(string: imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .opacity(0.8)
                    )
            } placeholder: {
                ProgressView()
            }
        }
    }
}

// 2. Modal Header Component
private struct ModalHeader: View {
    let user: QueueUser
    let animateGradient: Bool
    let animateContent: Bool
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.purple.opacity(0.8), .blue.opacity(0.8), .purple.opacity(0.8)],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .opacity(0.9)
            .blur(radius: 0.5)
            
            VStack(spacing: 20) {
                AnimatedAvatar(imageURL: user.image, animateContent: animateContent)
                
                VStack(spacing: 8) {
                    Text(user.name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("has left the space")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.vertical, 40)
        }
        .frame(height: 260)
    }
}
private struct InfoModalCard: View {
    let icon: String
    let title: String
    let message: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
           .background(
               RoundedRectangle(cornerRadius: 16)
                   .fill(Color(.secondarySystemBackground))
           )
       }
   }

/*

    private struct RemoveUserConfirmationModal: View {
    @Binding var isPresented: Bool
    let userName: String
    let onConfirm: () -> Void
        @EnvironmentObject var spacesViewModel: SpacesViewModel
    var body: some View {
        VStack(spacing: 20) {
            if spacesViewModel.isHost && spacesViewModel.isInSpace {
            Text("Are you sure you want to remove the \(userName) from the fikret?")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding()
}

            HStack(spacing: 20) {
                Button("Cancel") {
                    isPresented = false
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())

                Button("Ok") {
                    onConfirm()
                    isPresented = false
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
                .clipShape(Capsule())
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.systemBackground)))
        .shadow(color: .black.opacity(0.2), radius: 10)
        .padding()
    }
    }*/

// 3. Modal Content Component
private struct ModalContent: View {
    let onInviteNext: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            InfoModalCard(
                icon: "person.fill.xmark",
                title: "User Left",
                message: "Would you like to invite the next person in queue?",
                color: .red
            )
            
            HStack(spacing: 16) {
                ActionModalButton(
                    title: "Cancel",
                    icon: "xmark.circle.fill",
                    color: .gray,
                    action: onDismiss
                )
                
                ActionModalButton(
                    title: "Invite Next",
                    icon: "person.fill.badge.plus",
                    color: .blue,
                    action: onInviteNext
                )
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
    }
}

// Main Modal View
struct UserLeftModal: View {
    let user: QueueUser
    let onInviteNext: () -> Void
    let onDismiss: () -> Void
    @State private var showModal = false
    @State private var animateGradient = false
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .blur(radius: 2)
            
            VStack(spacing: 0) {
                ModalHeader(
                    user: user,
                    animateGradient: animateGradient,
                    animateContent: animateContent
                )
                
                ModalContent(
                    onInviteNext: onInviteNext,
                    onDismiss: onDismiss
                )
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width - 40, 400))
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .offset(y: showModal ? 0 : UIScreen.main.bounds.height)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showModal = true
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateContent.toggle()
            }
        }
    }
}

struct RemoveUserQueueConfirmationModal: View {
    let user: QueueUser
    let onConfirmRemove: () -> Void
    let onDismiss: () -> Void
    @State private var showModal = false
    @State private var animateGradient = false
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .blur(radius: 2)
            
            VStack(spacing: 0) {
                // Reuse ModalHeader with different text
                ZStack {
                    LinearGradient(
                        colors: [.red.opacity(0.8), .orange.opacity(0.8), .red.opacity(0.8)], // Changed colors to red theme
                        startPoint: animateGradient ? .topLeading : .bottomTrailing,
                        endPoint: animateGradient ? .bottomTrailing : .topLeading
                    )
                    .opacity(0.9)
                    .blur(radius: 0.5)
                    
                    VStack(spacing: 20) {
                        AnimatedAvatar(imageURL: user.image, animateContent: animateContent)
                        
                        VStack(spacing: 8) {
                            Text(user.name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Remove from queue?")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 40)
                }
                .frame(height: 260)
                
                // Content Section with remove-specific messaging
                VStack(spacing: 24) {
                    InfoModalCard(
                        icon: "person.fill.xmark",
                        title: "Confirm Removal",
                        message: "This action will remove the user from the queue. This cannot be undone.",
                        color: .red
                    )
                    
                    HStack(spacing: 16) {
                        ActionModalButton(
                            title: "Cancel",
                            icon: "xmark.circle.fill",
                            color: .gray,
                            action: onDismiss
                        )
                        
                        ActionModalButton(
                            title: "Remove",
                            icon: "person.fill.xmark",
                            color: .red,
                            action: onConfirmRemove
                        )
                    }
                }
                .padding(24)
                .background(Color(.systemBackground))
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width - 40, 400))
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .offset(y: showModal ? 0 : UIScreen.main.bounds.height)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showModal = true
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateContent.toggle()
            }
        }
    }
}


private struct ActionModalButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(isPressed ? 0.95 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}
struct UserListViewForGrid: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showActions = false
    @EnvironmentObject var viewModel: SpacesViewModel
        @State private var showUserTopicModal = false
    
        @State private var selectedUserTopic: String?
    @State private var userToRemove: QueueUser?
    @State private var showRemoveConfirmation = false
    @State private var showUserLeftModal = false
        private var firstParticipant: QueueUser? {
            viewModel.selectedSpace?.queue.participants.first
        }

        var inviteButtonDisabled: Bool {
            viewModel.selectedSpace?.queue.participants.isEmpty  ?? true
        }
   
        var selectedQueue: Queue? {
            viewModel.selectedSpace?.queue
        }
    // Sample data for preview
 
    
    var filteredUsers: [QueueUser] {
        let participants = viewModel.selectedSpace?.queue.participants ?? []
        
        if searchText.isEmpty {
            return participants
        }
        
        return participants.filter { participant in
            participant.name.lowercased().contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.1),
                            Color.blue.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            NavigationView {
                VStack(spacing: 0) {
                    SearchBar(text: $searchText, isSearching: $isSearching)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    if filteredUsers.isEmpty {
                        EmptyStateView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.selectedSpace?.queue.participants ?? [], id: \.id) { participant in
                                    UserListCellForGrid(user: participant)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
                .navigationTitle("Users")
                .navigationBarTitleDisplayMode(.inline)
                .foregroundColor(.white)
                .background(Color.clear)
            }
            
            Group {
                if showUserLeftModal, let user = firstParticipant, user.hasLeft {
                    UserLeftModal(
                        user: user,
                        onInviteNext: {
                            /*Task {
                                await viewModel.inviteUserFromQueue(userId: user.id)
                            }*/
                            showUserLeftModal = false
                        },
                        onDismiss: {
                            showUserLeftModal = false
                        }
                    )
                }
                
                if showRemoveConfirmation, let user = userToRemove {
                    RemoveUserQueueConfirmationModal(
                        user: user,
                        onConfirmRemove: {
                            /*Task {
                                if let spaceId = viewModel.selectedSpace?.id {
                                    await viewModel.removeUserFromQueue(
                                        userId: user.id,
                                        spaceId: spaceId,
                                        isInvited: user.isInvited
                                    )
                                }
                            }*/
                            
                            showRemoveConfirmation = false
                            userToRemove = nil
                        },
                        onDismiss: {
                            showRemoveConfirmation = false
                            userToRemove = nil
                        }
                    )
                }
            }
            
             }
        .onAppear {
                   if let space = viewModel.selectedSpace {
                      /* Task {
                           await viewModel.listenToQueueUpdates(for: space)
                       }*/
                   }
               }
        .overlay {
            /*if viewModel.showInviteNextModal && viewModel.isHost {
                InviteNextUserModal(
                    isPresented: $viewModel.showInviteNextModal,
                    lastUser: viewModel.lastUserWhoLeft,
                    queueParticipants: viewModel.selectedSpace?.queue.participants ?? [],
                    onInviteNext: { userId in
                        /*Task {
                            await viewModel.inviteUserFromQueue(userId: userId)
                        }*/
                    }
                    )
                .onDisappear {
                          viewModel.showInviteNextModal = false // Reset the modal state
                      }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
    .animation(.spring(), value: viewModel.showInviteNextModal)
                
            }

*/
        }
               .onDisappear {
                 /*  Task {
                       await viewModel.removeQueueListeners()
                   }*/
               }
               .onChange(of: firstParticipant?.hasLeft) { hasLeft in
                           if hasLeft == true {
                               withAnimation(.spring()) {
                                   showUserLeftModal = true
                               }
                           }
                       }
    }
}


struct SearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search users...", text: $text)
                    .font(.system(size: 16))
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
    }
}

// Supporting Views
struct ProfileImageView: View {
    let imageURL: String
    let isHovered: Bool
    
    var body: some View {
        AsyncImage(url: URL(string: imageURL)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 60, height: 60)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isHovered ? 3 : 2
                            )
                    )
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3), value: isHovered)
            case .failure:
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
            @unknown default:
                EmptyView()
            }
        }
    }
}

struct VerificationBadge: View {
    @State private var animate = false
    
    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .foregroundColor(.blue)
            .font(.system(size: 14))
            .symbolEffect(.bounce, options: .repeat(2), value: animate)
            .onAppear { animate = true }
    }
}

struct FollowerCountView: View {
    let count: Int
    @State private var showCount = false
    
    var body: some View {
        Text("\(formatNumber(count)) followers")
            .font(.system(size: 14))
            .foregroundColor(.gray)
            .opacity(showCount ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    showCount = true
                }
            }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }
}

struct TopicButton: View {
    let topic: String
    @Binding var isPressed: Bool
    @Binding var showTopicDetail: Bool
    @State private var animate = false
    
    var body: some View {
        Button {
            withAnimation(.spring()) {
                isPressed = true
                animate = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                    showTopicDetail = true
                }
            }
        } label: {
            Text(topic)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.8)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: animate ? [.purple, .blue] : [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .scaleEffect(isPressed ? 0.95 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}
private struct OptionsButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text("Options")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isHovered ? Color(.systemGray5) : Color(.systemGray6))
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}


private struct ActionOptionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(isHovered ? 0.15 : 0.1))
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering && !title.contains("Invited")
        }
    }
}


struct ActionsPanelView: View {
    let user: QueueUser
    @State private var animate = false
    @State private var showActions = false
    @State private var showRemoveConfirmation = false
    @EnvironmentObject var viewModel: SpacesViewModel
    @State private var showUserLeftModal = false
    
    private var firstParticipant: QueueUser? {
        viewModel.selectedSpace?.queue.participants.first
    }

    var body: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(spacing: 20) {
                ActionOptionButton(
                    title: "Remove",
                    icon: "person.fill.xmark",
                    color: .red
                ) {
                    showRemoveConfirmation = true
                }
                
                if user.name == firstParticipant?.name {
                    ActionOptionButton(
                        title: user.isInvited ? "Invited" : "Invite",
                        icon: user.isInvited ? "checkmark.circle.fill" : "person.badge.plus",
                        color: user.isInvited ? .gray : .blue
                    ) {
                        if !user.isInvited {
                          /*  Task {
                                await viewModel.inviteUserFromQueue(userId: user.id)
                            }*/
                        }
                    }
                    .disabled(user.isInvited)
                    .opacity(user.isInvited ? 0.7 : 1.0)
                }
            }
            .padding(.horizontal)
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                animate = true
            }
        }
        .overlay {
            if showRemoveConfirmation {
                RemoveUserQueueConfirmationModal(
                    user: user,
                    onConfirmRemove: {
                        Task {
                            if let spaceId = viewModel.selectedSpace?.id {
                            /*    await viewModel.removeUserFromQueue(
                                    userId: user.id,
                                    spaceId: spaceId,
                                    isInvited: user.isInvited
                                )*/
                            }
                        }
                        showRemoveConfirmation = false
                    },
                    onDismiss: {
                        showRemoveConfirmation = false
                    }
                )
                .transition(.opacity.combined(with: .scale))
                .animation(.spring(), value: showRemoveConfirmation)
            }
        }
    }
}


    private func formatNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }


struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No users found")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Text("Try adjusting your search")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}




public  struct TopicDetailView: View {

    let topic: String
    let userName: String
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var animateGradient = false
    @State private var showContent = false
    public init(topic: String, userName: String) {
        self.topic = topic
        self.userName = userName
    }
    // Sample data for the view
    let relatedTopics = ["Machine Learning", "Data Science", "Neural Networks", "Deep Learning", "Computer Vision"]
    let posts = [
        Post(title: "Introduction to AI", likes: 1234, comments: 89, date: "2 days ago"),
        Post(title: "Future of Technology", likes: 2341, comments: 156, date: "4 days ago"),
        Post(title: "Machine Learning Basics", likes: 876, comments: 45, date: "1 week ago")
    ]
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section with animated gradient
                    headerSection
                    
                    // Stats Section
                    statsSection
                        .offset(y: -30)
                    
                    // Content Tabs
                    tabSection
                    
                    // Content based on selected tab
                    tabContent
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8)) {
                    showContent = true
                }
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
            
        }
    }
    
    private var headerSection: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [.blue, .purple, .blue],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .opacity(0.8)
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Topic Icon
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)
                        .shadow(color: .white.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: topicIcon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .symbolEffect(.bounce)
                }
                .offset(y: showContent ? 0 : -50)
                .opacity(showContent ? 1 : 0)
                
                // Topic Title and Author
                VStack(spacing: 8) {
                    Text(topic)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(.white)
                    
                    Text("Created by \(userName)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                .offset(y: showContent ? 0 : 30)
                .opacity(showContent ? 1 : 0)
            }
            .padding(.vertical, 40)
        }
        .frame(height: 280)
    }
    
    private var statsSection: some View {
        HStack(spacing: 20) {
            ForEach(stats, id: \.title) { stat in
                StatCard(stat: stat)
                    .offset(y: showContent ? 0 : 50)
                    .opacity(showContent ? 1 : 0)
            }
        }
        .padding(.horizontal)
    }
    
    private var tabSection: some View {
        HStack {
            ForEach(0..<3) { index in
                Button(action: { withAnimation { selectedTab = index } }) {
                    VStack(spacing: 8) {
                        Text(tabTitles[index])
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == index ? .primary : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == index ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
    
    private var tabContent: some View {
        VStack(spacing: 16) {
            switch selectedTab {
            case 0:
                aboutSection
            case 1:
                relatedTopicsSection
            case 2:
                postsSection
            default:
                EmptyView()
            }
        }
        .padding()
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            UserInfoCard(
                title: "Description",
                subtitle: "An in-depth exploration of \(topic)",
                detail: "Covering fundamental concepts and advanced applications.",
                icon: "text.justify"
            )
            
            UserInfoCard(
                title: "Engagement",
                subtitle: "Active Community",
                detail: "Join discussions and share your insights.",
                icon: "person.2.fill"
            )
        }
    }
    
    private var relatedTopicsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(relatedTopics, id: \.self) { topic in
                TopicCard(topic: topic)
            }
        }
    }
    
    private var postsSection: some View {
        VStack(spacing: 16) {
            ForEach(posts) { post in
                PostCard(post: post)
            }
        }
    }
    
    // Helper computed properties
    private var topicIcon: String {
        switch topic.lowercased() {
        case let t where t.contains("ai"): return "cpu.fill"
        case let t where t.contains("design"): return "paintbrush.fill"
        case let t where t.contains("photo"): return "camera.fill"
        default: return "star.fill"
        }
    }
    
    private var stats: [StatItem] {
        [
            StatItem(title: "Posts", value: "156", icon: "doc.text.fill"),
            StatItem(title: "Followers", value: "2.3K", icon: "person.2.fill"),
            StatItem(title: "Rating", value: "4.8", icon: "star.fill")
        ]
    }
    
    private var tabTitles = ["About", "Related", "Posts"]
}

// Supporting Views and Models
struct StatItem {
    let title: String
    let value: String
    let icon: String
}

struct Post: Identifiable {
    let id = UUID()
    let title: String
    let likes: Int
    let comments: Int
    let date: String
}

struct StatCard: View {
    let stat: StatItem
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: stat.icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
            
            Text(stat.value)
                .font(.system(size: 20, weight: .bold))
            
            Text(stat.title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

struct UserInfoCard: View {
    let title: String
    let subtitle: String
    let detail: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

struct TopicCard: View {
    let topic: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(topic)
                .font(.system(size: 16, weight: .medium))
                .lineLimit(2)
                .truncationMode(.tail)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct PostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(post.title)
                .font(.system(size: 18, weight: .semibold))
            
            HStack {
                Label("\(post.likes)", systemImage: "heart.fill")
                    .foregroundColor(.red)
                
                Label("\(post.comments)", systemImage: "message.fill")
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text(post.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 14))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}


// Preview
struct UserListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UserListViewForGrid()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            UserListViewForGrid()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
