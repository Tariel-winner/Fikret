//
//  TwitterHomeView.swift
//  TwitterClone
//
//  Created by Rohit Sridharan on 29/03/23.
//

import SwiftUI

// First, let's add a color extension for our theme colors
extension Color {
    static let twitterTheme = TwitterThemeColors()
}

struct TwitterThemeColors {
    // Primary colors
    let primary = Color.blue // Twitter's signature blue
    let accent = Color(.systemBlue) // System blue for interactive elements
    
    // Background colors
    let background = Color(.systemBackground)
    let secondaryBackground = Color(.secondarySystemBackground)
    
    // Text colors
    let primaryText = Color(.label)
    let secondaryText = Color(.secondaryLabel)
    let tertiaryText = Color(.tertiaryLabel)
    
    // Interactive colors
    let like = Color.red
    let retweet = Color.green
    let bookmark = Color.blue
    
    // Overlay colors
    let overlay = Color.black.opacity(0.5)
    let materialBackground = Color(.systemBackground).opacity(0.9)
}

struct OffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Add this struct for sample video data
struct VideoPost {
    let thumbnailURL: String
    let videoURL: String
    let views: Int
    let duration: String
}

// Move sampleVideos to be a static property at the top level
private struct VideoData {
    static let sampleVideos: [VideoPost] = [
        VideoPost(
            thumbnailURL: "https://i.vimeocdn.com/video/1118807352-6353f6d2c9804d0058e47c444df3e8c6b3fc48e7807e8d6399c8a0593a3e5dc0-d",
            videoURL: "https://player.vimeo.com/external/530770938.sd.mp4?s=1d3c5b1ba5d7c11f144b78b3ff9833d87c47d56b&profile_id=165&oauth2_token_id=57447761",
            views: 1234,
            duration: "0:30"
        ),
        VideoPost(
            thumbnailURL: "https://i.vimeocdn.com/video/1397906993-d6844d4f544f0671fd7fcd1578e23987a7b29792d67b1db793844f6dd78e1270-d",
            videoURL: "https://player.vimeo.com/external/552481870.sd.mp4?s=c312c3f5c0094e42f3d4a8b7ef8c2d4f4708d4aa&profile_id=165&oauth2_token_id=57447761",
            views: 4567,
            duration: "0:45"
        ),
        VideoPost(
            thumbnailURL: "https://i.vimeocdn.com/video/1641841429-8beec192b3c0c44a5318eea4be75b32c0a07ff0dc3dcd3af7e5f70f86425dd01-d",
            videoURL: "https://player.vimeo.com/external/517090081.sd.mp4?s=ec0f799b86b021c34c58c87b87a9816d14cb753b&profile_id=165&oauth2_token_id=57447761",
            views: 7890,
            duration: "1:00"
        ),
        VideoPost(
            thumbnailURL: "https://i.vimeocdn.com/video/1118807352-6353f6d2c9804d0058e47c444df3e8c6b3fc48e7807e8d6399c8a0593a3e5dc0-d",
            videoURL: "https://player.vimeo.com/external/530770938.sd.mp4?s=1d3c5b1ba5d7c11f144b78b3ff9833d87c47d56b&profile_id=165&oauth2_token_id=57447761",
            views: 2345,
            duration: "0:35"
        ),
        VideoPost(
            thumbnailURL: "https://i.vimeocdn.com/video/1397906993-d6844d4f544f0671fd7fcd1578e23987a7b29792d67b1db793844f6dd78e1270-d",
            videoURL: "https://player.vimeo.com/external/552481870.sd.mp4?s=c312c3f5c0094e42f3d4a8b7ef8c2d4f4708d4aa&profile_id=165&oauth2_token_id=57447761",
            views: 6789,
            duration: "0:50"
        ),
        VideoPost(
            thumbnailURL: "https://i.vimeocdn.com/video/1641841429-8beec192b3c0c44a5318eea4be75b32c0a07ff0dc3dcd3af7e5f70f86425dd01-d",
            videoURL: "https://player.vimeo.com/external/517090081.sd.mp4?s=ec0f799b86b021c34c58c87b87a9816d14cb753b&profile_id=165&oauth2_token_id=57447761",
            views: 3456,
            duration: "0:40"
        )
    ]
}

struct TwitterHomeView: View {
    @Binding var isProfilePictureClicked: Bool
    @EnvironmentObject var tweets: TweetData
    @Namespace private var animation
    @State private var selectedPost: TweetModel?
    @State private var showFullScreen = false
    @State private var currentIndex = 0
    @State private var showEditProfile = false
    @State private var showSettings = false
    
    // Grid layout
    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Profile Header
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44) // Apple's minimum touch target
                        }
                    }
                    .padding(.horizontal)
                    
                    // Profile Image
                    AsyncImage(url: URL(string: tweets.user!.profilepicture)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 96, height: 96)
                    }
                    
                    // User Info
                    VStack(spacing: 4) {
                        Text(tweets.user!.name)
                            .font(.title3.bold())
                        Text("@\(tweets.user!.username)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    // Stats Row
                    HStack(spacing: 32) {
                        StatItem(count: "0", title: "Following")
                        StatItem(count: "0", title: "Followers")
                        StatItem(count: "0", title: "Likes")
                    }
                    .padding(.vertical, 8)
                    
                    // Edit Profile Button
                    Button {
                        showEditProfile = true
                    } label: {
                        Text("Edit profile")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 160)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                    }
                    .sheet(isPresented: $showEditProfile) {
                        EditProfileView()
                    }
                }
                .padding(.vertical)
                
                // Posts Grid
                LazyVGrid(columns: columns, spacing: 1) {
                    if tweets.tweets.isEmpty {
                        ForEach(0..<9) { _ in
                            EmptyPostThumbnail()
                                .frame(height: UIScreen.main.bounds.width / 3)
                                .clipped()
                        }
                    } else {
                        ForEach(0..<min(9, tweets.tweets.count)) { index in
                          /*  PostThumbnail(tweet: index)
                                .frame(height: UIScreen.main.bounds.width / 3)
                                .clipped()
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        currentIndex = index
                                        showFullScreen = true
                                    }
                                }*/
                        }
                    }
                }
                .padding(.top, 1)
            }
        }
       .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenPostView(
                currentIndex: $currentIndex, tweets: <#[TweetModel]#>
           //     tweets: tweets.tweets
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// Update FullScreenPostsView for better centering and full-screen display
struct FullScreenPostsView: View {
    let initialIndex: Int
    let tweets: [TweetModel]
    var namespace: Namespace.ID
    @Binding var isShowing: Bool
    @State private var currentIndex: Int
    @State private var offset: CGFloat = 0
    @GestureState private var isDragging = false
    
    init(initialIndex: Int, tweets: [TweetModel], namespace: Namespace.ID, isShowing: Binding<Bool>) {
        self.initialIndex = initialIndex
        self.tweets = tweets
        self.namespace = namespace
        self._isShowing = isShowing
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                TabView(selection: $currentIndex) {
                    ForEach(0..<9) { index in
                        FullScreenPost(
                            post: tweets[index % tweets.count],
                            postId: "post\(index)",
                            namespace: namespace,
                            isShowing: $isShowing
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .rotationEffect(.degrees(-90))
                        .tag(index)
                    }
                }
                .frame(
                    width: geometry.size.height,
                    height: geometry.size.width
                )
                .rotationEffect(.degrees(90), anchor: .topLeading)
                .offset(x: geometry.size.width)
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .updating($isDragging) { value, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        if value.translation.width > 0 {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3)) {
                            if value.translation.width > geometry.size.width * 0.3 {
                                isShowing = false
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }
}

// Update FullScreenPost to match ShortVideoCard from MessageView
struct FullScreenPost: View {
    let post: TweetModel
    let postId: String
    var namespace: Namespace.ID
    @Binding var isShowing: Bool
    @State private var isLiked = false
    @State private var showComments = false
    @State private var isBookmarked = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video Content
                AsyncImage(url: URL(string: post.profilepicture)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width)
                        .matchedGeometryEffect(id: postId, in: namespace)
                } placeholder: {
                    Rectangle()
                        .fill(Color.black)
                }
                
                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Content Overlay
                HStack(alignment: .bottom) {
                    // Left side - User info and caption
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            AsyncImage(url: URL(string: post.profilepicture)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            
                            VStack(alignment: .leading) {
                                Text("@\(post.username)")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(post.tweet)
                                    .font(.system(size: 14))
                                    .lineLimit(2)
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, 80)
                    
                    Spacer()
                    
                    // Right side - Action buttons
                    VStack(spacing: 20) {
                        VideoActionButton(
                            icon: isLiked ? "heart.fill" : "heart",
                            count: "45.2K",
                            color: isLiked ? .red : .white
                        ) {
                            withAnimation { isLiked.toggle() }
                        }
                        
                        VideoActionButton(
                            icon: "bubble.right",
                            count: "1.2K"
                        ) {
                            showComments = true
                        }
                        
                        VideoActionButton(
                            icon: isBookmarked ? "bookmark.fill" : "bookmark",
                            color: isBookmarked ? .yellow : .white
                        ) {
                            withAnimation { isBookmarked.toggle() }
                        }
                        
                        VideoActionButton(
                            icon: "arrowshape.turn.up.right",
                            action: { }
                        )
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 80)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black)
            .clipped()
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showComments) {
            CommentsView(tweet: post)
        }
    }
}

// Video Action Button (same as in MessageView)
struct VideoActionButton: View {
    let icon: String
    var count: String = ""
    var color: Color = .white
    let action: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = true
                action()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                
                if !count.isEmpty {
                    Text(count)
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// Simple Stat Item
struct StatItem: View {
    let count: String
    let title: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(count)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}

// Simple Post Thumbnail
struct PostThumbnail: View {
    let tweet: TweetModel
    
    var body: some View {
        AsyncImage(url: URL(string: tweet.profilepicture)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .overlay(alignment: .bottomLeading) {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.caption2)
                        Text("0")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .padding(6)
                    .background(.black.opacity(0.3))
                }
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
        }
    }
}

// Add this new view for empty state
struct EmptyPostThumbnail: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .overlay(
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundColor(.gray)
            )
    }
}

struct TwitterHomeView_Previews: PreviewProvider {
    static var previews: some View {
        TwitterHomeView(isProfilePictureClicked: .constant(false))
            .environmentObject(TweetData())
    }
}

struct FullScreenPost_Previews: PreviewProvider {
    @Namespace static var namespace
    
    static var previews: some View {
        FullScreenPost(
            post: TweetModel(
                profilepicture: "",  // First
                name: "Test",        // Second
                tweet: "Test tweet", // Third
                username: "test"     // Fourth
            ),
            postId: "post0",
            namespace: namespace,
            isShowing: .constant(true)
        )
        .environmentObject(TweetData())
    }
}

// Add this after VideoActionButton
struct CommentsView: View {
    let tweet: TweetModel
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Original Post
                        HStack(alignment: .top, spacing: 12) {
                            AsyncImage(url: URL(string: tweet.profilepicture)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tweet.name)
                                    .font(.headline)
                                Text("@\(tweet.username)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text(tweet.tweet)
                                    .font(.body)
                                    .padding(.top, 4)
                            }
                        }
                        .padding()
                        
                        Divider()
                        
                        // Sample Comments
                        ForEach(0..<5) { index in
                            CommentRow(index: index)
                        }
                    }
                }
                
                // Comment Input
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        TextField("Add a comment...", text: $commentText)
                            .textFieldStyle(.roundedBorder)
                            .focused($isFocused)
                        
                        Button(action: {
                            // Post comment
                            commentText = ""
                            isFocused = false
                        }) {
                            Text("Post")
                                .fontWeight(.semibold)
                                .foregroundColor(commentText.isEmpty ? .gray : Color.twitterTheme.primary)
                        }
                        .disabled(commentText.isEmpty)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Add this for sample comments
struct CommentRow: View {
    let index: Int
    @State private var isLiked = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("User \(index)")
                        .font(.subheadline.bold())
                    Text("@user\(index)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("· 2h")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text("This is a sample comment! 🎉")
                    .font(.subheadline)
                
                HStack(spacing: 16) {
                    Button(action: { isLiked.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundColor(isLiked ? .red : .gray)
                            Text("23")
                                .foregroundColor(.gray)
                        }
                        .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}



