//
//  TwitterMessageView.swift
//  TwitterClone
//
//  Created by Rohit Sridharan on 29/03/23.
//

import SwiftUI
//
//  TwitterMessageView.swift
//  TwitterClone
//
//  Created by Rohit Sridharan on 29/03/23.
//

import SwiftUI

struct TwitterMessageView: View {
    @Binding var isProfilePictureClicked: Bool
    @EnvironmentObject var tweets: TweetData
    @State private var selectedTab = 0
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom minimal top bar with tabs
                HStack(spacing: 0) {
                    TabButton(title: "For you", isSelected: selectedTab == 0) {
                        withAnimation { selectedTab = 0 }
                    }
                    
                    TabButton(title: "Following", isSelected: selectedTab == 1) {
                        withAnimation { selectedTab = 1 }
                    }
                }
                .padding(.top, 50) // Safe area padding
                .background(Color.black.opacity(0.01)) // Nearly transparent for touch handling
                
                // Main Content
                TabView(selection: $selectedTab) {
                    // For You Tab
                    ShortVideoFeed()
                        .tag(0)
                    
                    // Following Tab
                    ShortVideoFeed(isFollowing: true)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark) // Force dark mode
    }
}

// Tab Button with TikTok style
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : .gray)
                
                // Indicator
                Circle()
                    .fill(.white)
                    .frame(width: 4, height: 4)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .frame(width: 100)
        .padding(.vertical, 8)
    }
}

// Short Video Feed with TikTok style
struct ShortVideoFeed: View {
    var isFollowing: Bool = false
    @State private var currentIndex = 0
    
    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(0..<10) { index in
                ShortVideoCard(index: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }
}

// Short Video Card with TikTok style
struct ShortVideoCard: View {
    let index: Int
    @State private var isLiked = false
    @State private var showComments = false
    @State private var isBookmarked = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video Content (placeholder)
                Color.black
                    .overlay(
                        Text("Video \(index + 1)")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.3))
                    )
                
                // Overlay gradient for bottom content
                LinearGradient(
                    colors: [.clear, .black.opacity(0.4)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                // Content Overlay
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        // Left side - Author info and caption
                        VStack(alignment: .leading, spacing: 10) {
                            // Author
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 40, height: 40)
                                Text("@username")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Button(action: {}) {
                                    Text("Follow")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            // Caption
                            Text("This is a short video caption #twitter #shorts")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                        .padding(.bottom, 20)
                        
                        // Right side - Action buttons
                        VStack(spacing: 20) {
                            ActionButton(
                                icon: isLiked ? "heart.fill" : "heart",
                                count: "45.2K",
                                color: isLiked ? .red : .white
                            ) {
                                withAnimation { isLiked.toggle() }
                            }
                            
                            ActionButton(
                                icon: "bubble.right",
                                count: "1.2K",
                                color: .white
                            ) {
                                showComments = true
                            }
                            
                            ActionButton(
                                icon: "bookmark",
                                count: "3.4K",
                                color: isBookmarked ? .yellow : .white
                            ) {
                                withAnimation { isBookmarked.toggle() }
                            }
                            
                            ActionButton(
                                icon: "arrowshape.turn.up.right",
                                count: "Share",
                                color: .white
                            ) {}
                        }
                        .padding(.trailing)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsSheet()
                .preferredColorScheme(.dark)
        }
    }
}

// Action Button
struct ActionButton: View {
    let icon: String
    var count: String? = nil
    var color: Color = .white
    let action: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                
                if let count = count {
                    Text(count)
                       // .font(TwitterStyle.captionFont)
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// Comments Sheet with improved visuals
struct CommentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @FocusState private var isFocused: Bool
    @State private var selectedFilter = CommentFilter.trending
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CommentFilter.allCases, id: \.self) { filter in
                                CommentFilterPill(filter: filter, isSelected: selectedFilter == filter) {
                                    withAnimation { selectedFilter = filter }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(.ultraThinMaterial)
                    
                    // Comments List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(0..<20) { index in
                                CommentCellEnhanced(index: index)
                            }
                        }
                        .padding()
                    }
                }
                
                // Comment Input Bar
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        // User Avatar
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                            )
                        
                        // Comment Input
                        ZStack(alignment: .leading) {
                            if commentText.isEmpty {
                                Text("Add a comment...")
                                    .foregroundColor(.gray)
                            }
                            TextEditor(text: $commentText)
                                .frame(minHeight: 36, maxHeight: 100)
                                .focused($isFocused)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(18)
                        
                        // Post Button
                        Button(action: {
                            // Post comment
                            commentText = ""
                            isFocused = false
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(commentText.isEmpty ? .gray : .blue)
                        }
                        .disabled(commentText.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
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

// Enhanced Comment Cell
struct CommentCellEnhanced: View {
    let index: Int
    @State private var isLiked = false
    @State private var showReplies = false
    @State private var isBookmarked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Info
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("User \(index)")
                        .font(.system(size: 15, weight: .semibold))
                    
                    Text("@username\(index)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("2h")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                }
            }
            
            // Comment Content
            Text("This is a sample comment with some meaningful content. Maybe including some #hashtags and @mentions to make it more interesting! 🎉")
                .font(.system(size: 15))
            
            // Action Buttons
            HStack(spacing: 24) {
                // Like Button
                Button(action: { withAnimation { isLiked.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                        Text(isLiked ? "1,234" : "1,233")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Reply Button
                Button(action: { showReplies.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.gray)
                        Text("56")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Bookmark Button
                Button(action: { withAnimation { isBookmarked.toggle() } }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isBookmarked ? .blue : .gray)
                }
                
                // Share Button
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 4)
            
            // Replies Section (if any)
            if showReplies {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<2) { replyIndex in
                        ReplyCell(replyIndex: replyIndex)
                    }
                }
                .padding(.leading, 48)
            }
        }
        .padding(.vertical, 8)
    }
}

// Reply Cell
struct ReplyCell: View {
    let replyIndex: Int
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User Info
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                
                Text("Replier \(replyIndex)")
                    .font(.system(size: 13, weight: .semibold))
                
                Text("· 1h")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Reply Content
            Text("This is a reply to the comment above! 👍")
                .font(.system(size: 13))
            
            // Like Button
            Button(action: { withAnimation { isLiked.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 12))
                        .foregroundColor(isLiked ? .red : .gray)
                    Text("23")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// Comment Filter
enum CommentFilter: String, CaseIterable {
    case trending = "Trending"
    case newest = "Newest"
    case following = "Following"
}

// Comment Filter Pill
struct CommentFilterPill: View {
    let filter: CommentFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(filter.rawValue)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? .blue : Color.gray.opacity(0.2))
                )
        }
    }
}

struct TwitterMessageView_Previews: PreviewProvider {
    static var previews: some View {
        TwitterMessageView(isProfilePictureClicked: .constant(false))
    }
}
