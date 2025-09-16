import SwiftUI

struct NotificationView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var tweetData: TweetData
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
                    ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Main content area with proper safe area handling
                    Group {
                    if notificationManager.isLoading && notificationManager.notificationState.notifications.isEmpty {
                        TikTokLoadingView(size: 60, color: .blue)
                    } else if let error = notificationManager.error, notificationManager.notificationState.notifications.isEmpty {
                        VStack(spacing: 24) {
                            // Modern error icon with animation
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange.opacity(0.2), .red.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .shadow(color: .orange.opacity(0.3), radius: 15, x: 0, y: 8)
                                
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(spacing: 12) {
                                Text("Something went wrong")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text(error)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            
                            Button(action: {
                                Task {
                                    await notificationManager.refreshNotifications()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Try Again")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.horizontal, 40)
                    } else if notificationManager.notificationState.notifications.isEmpty {
                        VStack(spacing: 24) {
                            // Modern empty state icon with animation
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 8)
                                
                                Image(systemName: "bell.slash.fill")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(spacing: 12) {
                                Text("No notifications yet")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("When you get notifications, they'll appear here")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.horizontal, 40)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(Array(notificationManager.notificationState.notifications.enumerated()), id: \.element.id) { index, notification in
                                    NotificationRowView(notification: notification)
                                        .onTapGesture {
                                            Task {
                                                await notificationManager.onNotificationTap(notification)
                                            }
                                        }
                                        .onAppear {
                                            // ✅ FIXED: Trigger load more when reaching last item
                                            if index == notificationManager.notificationState.notifications.count - 4 {
                                                Task {
                                                    await notificationManager.loadMoreNotifications()
                                                }
                                            }
                                        }
                                }
                                // ✅ IMPROVED: Show load more indicator with better logic
                                if notificationManager.notificationState.isLoading && notificationManager.notificationState.pagination.hasMoreData {
                                    HStack {
                                        Spacer()
                                        TikTokLoadingView(size: 30, color: .blue)
                                            .padding()
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 20) // Add bottom padding for tab bar
                        }
                        .refreshable {
                            await notificationManager.refreshNotifications()
                        }
                        .safeAreaInset(edge: .bottom) {
                            // Add bottom spacing for tab bar
                            Color.clear.frame(height: 0)
                        }
                        .ignoresSafeArea(.container, edges: .bottom)
                    }
                }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EmptyView()
                }
            }
            .safeAreaInset(edge: .top) {
                // Ensure proper top spacing
                Color.clear.frame(height: 0)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Force stack style on iPad
        .onAppear {
            notificationManager.updateNotificationsTabState(isInTab: true)
            Task {
                await notificationManager.onNotificationViewAppear()
            }
        }
        .onDisappear {
            notificationManager.updateNotificationsTabState(isInTab: false)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                notificationManager.error = nil
            }
        } message: {
            Text(notificationManager.error ?? "Unknown error occurred")
        }
        .onChange(of: notificationManager.error) { error in
            showingError = error != nil
        }
        // ✅ DIRECT: Profile navigation with fullScreenCover (same as ConversationFeedView.swift)
        .fullScreenCover(isPresented: $notificationManager.showUserProfile) {
            if let profileData = notificationManager.profileToShow {
                TwitterProfileView(
                    userId: profileData.userId,
                    username: profileData.username,
                    initialProfile: profileData.initialProfile
                )
                .environmentObject(tweetData)
                .environmentObject(spacesViewModel)
                .interactiveDismissDisabled()
            }
        }
        
        // ✅ DIRECT: Profile with post navigation
        .fullScreenCover(isPresented: $notificationManager.showProfileWithPost) {
            if let postData = notificationManager.postToShow {
                TwitterProfileView(
                    userId: postData.userId,
                    username: postData.username,
                    initialProfile: nil,
                    targetPostId: postData.postId,
                    targetPostLocation: postData.postLocation
                )
                .environmentObject(tweetData)
                .environmentObject(spacesViewModel)
                .interactiveDismissDisabled()
            }
        }
        
        // ✅ DIRECT: Post detail navigation
        .fullScreenCover(isPresented: $notificationManager.showPostDetail) {
            if let postId = notificationManager.postIdToShow {
                PostDetailView(postId: postId)
                    .environmentObject(tweetData)
                    .environmentObject(spacesViewModel)
            }
        }
    }
}

struct NotificationRowView: View {
    let notification: UserNotification
    @State private var isExpanded = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Modern Avatar with enhanced styling
            ZStack {
                // Avatar background with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                
                CachedAsyncImage(url: notification.sender_user?.avatar.safeURL()) { phase in
                    switch phase {
                    case .empty:
                        Color.clear
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        // Enhanced error placeholder with gradient background
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.red.opacity(0.2), .orange.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                    @unknown default:
                        // Enhanced default placeholder with gradient background
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // Modern unread indicator
                if !notification.is_read {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                        .offset(x: 18, y: -18)
                        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                // Enhanced reaction indicator for reaction notifications
                if notification.isReaction, let reactionType = notification.extractedReactionType {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 24, height: 24)
                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                        
                        Text(getReactionEmoji(for: reactionType))
                            .font(.system(size: 14))
                    }
                    .offset(x: -18, y: 18)
                }
            }
            
            // Modern Content Section
            VStack(alignment: .leading, spacing: 8) {
                // Enhanced header with username and time
                HStack {
                    Text(notification.sender_user?.nickname ?? "Unknown User")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatTimestamp(notification.created_on))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                }
                
                // Notification content
                VStack(alignment: .leading, spacing: 4) {
                    // For reaction notifications, show special reaction UI
                    if notification.isReaction {
                        reactionNotificationView
                    } else {
                        // For other notifications, show normal content
                        Text(notification.translatedBrief)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(isExpanded ? nil : 2)
                        
                        // Only show translatedContent if it's different from brief AND not empty
                        if !notification.translatedContent.isEmpty &&
                           notification.translatedContent != notification.translatedBrief &&
                           notification.translatedContent != "No content available" {
                            Text(notification.translatedContent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(isExpanded ? nil : 1)
                        }
                        
                        // Related content preview ONLY for comment/reply notifications with actual content (exclude post/conversation notifications)
                        if notification.isComment || notification.isReply {
                            if let comment = notification.comment, !comment.displayContent.isEmpty && comment.displayContent != "No content available" {
                                NotificationContentPreview(content: comment.displayContent, type: "Comment")
                            } else if let reply = notification.reply, !reply.displayContent.isEmpty && reply.displayContent != "No content available" {
                                NotificationContentPreview(content: reply.displayContent, type: "Reply")
                            }
                        }
                    }
                }
                
                // Expand/collapse button for long content
                if shouldShowExpandButton {
                    Button(isExpanded ? "Show less" : "Show more") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            // Modern glass effect background
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    notification.is_read ? Color.clear : Color.blue.opacity(0.3),
                                    notification.is_read ? Color.gray.opacity(0.1) : Color.purple.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: notification.is_read ? 1 : 2
                        )
                )
                .shadow(
                    color: notification.is_read ? .black.opacity(0.05) : .blue.opacity(0.1),
                    radius: notification.is_read ? 4 : 8,
                    x: 0,
                    y: notification.is_read ? 2 : 4
                )
        )
        .contentShape(Rectangle())
    }
    
    // MARK: - Reaction Notification View
    private var reactionNotificationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main reaction message - use the translated brief which now has natural text
            Text(notification.translatedBrief)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
            
            // Time stamp
            Text(formatTimestamp(notification.created_on))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private var shouldShowExpandButton: Bool {
        let briefLength = notification.brief.count
        let contentLength = notification.content.count
        return briefLength > 100 || contentLength > 50
    }
    
    // MARK: - Reaction Helper Methods
    private func getReactionEmoji(for reactionType: String) -> String {
        let emojiMap: [String: String] = [
            "like": "👍",
            "love": "❤️",
            "hot": "🔥",
            "smart": "🧠",
            "funny": "😂",
            "kind": "🤗",
            "brave": "💪",
            "cool": "😎",
            "sweet": "🍯",
            "strong": "💪",
            "friendly": "😊",
            "honest": "🤝",
            "generous": "🎁",
            "fit": "🏃",
            "creative": "🎨",
            "stupid": "🤦",
            "mean": "😠",
            "fake": "🎭",
            "lazy": "😴"
        ]
        return emojiMap[reactionType.lowercased()] ?? "❤️"
    }
    
    private func getReactionColor(for reactionType: String) -> String {
        let colorMap: [String: String] = [
            "like": "#4ECDC4",
            "love": "#FF6B6B",
            "hot": "#FF8C42",
            "smart": "#9B59B6",
            "funny": "#F1C40F",
            "kind": "#2ECC71",
            "brave": "#E67E22",
            "cool": "#3498DB",
            "sweet": "#F39C12",
            "strong": "#95A5A6",
            "friendly": "#9B59B6",
            "honest": "#1ABC9C",
            "generous": "#E91E63",
            "fit": "#27AE60",
            "creative": "#E91E63",
            "stupid": "#E74C3C",
            "mean": "#E74C3C",
            "fake": "#95A5A6",
            "lazy": "#95A5A6"
        ]
        return colorMap[reactionType.lowercased()] ?? "#4ECDC4"
    }
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else if timeInterval < 2592000 {
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

struct NotificationContentPreview: View {
    let content: String
    let type: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForType)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(content)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.top, 4)
    }
    
    private var iconForType: String {
        switch type {
        case "Post":
            return "doc.text"
        case "Comment":
            return "bubble.left"
        case "Reply":
            return "arrowshape.turn.up.left"
        case "Reaction":
            return "heart.fill"
        default:
            return "doc"
        }
    }
}

struct NotificationView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationView()
            .environmentObject(NotificationManager())
    }
}

// MARK: - Post Detail View
struct PostDetailView: View {
    let postId: Int64
    @EnvironmentObject var tweetData: TweetData
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @State private var post: AudioConversation?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                TikTokLoadingView(size: 60, color: .white)
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Error loading post")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else if let post = post {
                ScrollView {
                    VStack(spacing: 16) {
                        // Post header
                        HStack {
                            CachedAsyncImage(url: post.host_image.safeURL()) { phase in
                                switch phase {
                                case .empty:
                                    Color.clear
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure(_):
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.red.opacity(0.2), .orange.opacity(0.2)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                    }
                                @unknown default:
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                        
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text(post.host_name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("@\(post.user_name)") // Using user_name as fallback for username
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Post content
                        VStack(alignment: .leading, spacing: 12) {
                            Text(post.topic)
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.8)
                                .foregroundColor(.white)
                            
                            // Audio player
                            if let hostAudioUrl = post.host_audio_url, !hostAudioUrl.isEmpty {
                                AudioPostCard(post: post)
                                    .environmentObject(spacesViewModel)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Post metadata
                        HStack {
                            Text("Duration: \(post.duration)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("Created: \(formatDate(post.created_at))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            } else {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Post not found")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadPost()
        }
    }
    
    private func loadPost() {
        Task {
            do {
                // Try to find the post in the spaces view model
                if let foundPost = spacesViewModel.authenticatedUserPosts.posts.first(where: { $0.id == postId }) {
                    await MainActor.run {
                        self.post = foundPost
                        self.isLoading = false
                    }
                } else {
                    // Search in other user posts
                    for (_, userPosts) in spacesViewModel.otherUserPosts {
                        if let foundPost = userPosts.posts.first(where: { $0.id == postId }) {
                            await MainActor.run {
                                self.post = foundPost
                                self.isLoading = false
                            }
                            return
                        }
                    }
                    
                    // Post not found
                    await MainActor.run {
                        self.error = "Post not found"
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
