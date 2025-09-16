import SwiftUI
//import Stripe
import PhotosUI
 


// Move UserListType enum outside of TwitterProfileView
enum UserListType {
    case followers
    case following
}

// Add ProfileResponse struct for decoding Supabase response
struct ProfileResponse: Decodable {
    let id: String
    let email: String?
    let username: String
    let name: String
    let profilepicture: String
    let bio: String?
    let website: String?
    let location: String?
    let followers: Int?
    let following: Int?
    let stripe_connect_id: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case email
        case username
        case name
        case profilepicture
        case bio
        case website
        case location
        case followers
        case following
        case stripe_connect_id
    }
}

// MARK: - Comment Model
struct Comment: Identifiable, Codable {
    let id: Int64
    let postId: Int64
    let userId: Int64
    let username: String
    let userImage: String
    let content: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case username
        case userImage = "user_image"
        case content
        case createdAt = "created_at"
    }
}


// MARK: - Time Display View (Fix for compiler issue)
struct TimeDisplayView: View {
    let isScrubbing: Bool
    let currentTime: Double
    let formatTime: (Double) -> String
    
    var body: some View {
        HStack {
            // Current time only
            if isScrubbing {
                Text("--:--")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text(formatTime(currentTime))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// Modern Audio Wave Animation
struct ModernAudioWaveAnimation: View {
    let audioLevel: Float
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<8) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                .blue.opacity(0.9),
                                .purple.opacity(0.7),
                                .blue.opacity(0.5)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: max(6, CGFloat(audioLevel) * CGFloat.random(in: 15...40)))
                    .scaleEffect(y: animate ? CGFloat.random(in: 0.6...1.4) : 1, anchor: .bottom)
                    .animation(
                        Animation.easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.08),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// Update AudioDetectionAnimation for smoother visualization
struct AudioDetectionAnimation: View {
    let audioLevel: Float
    @State private var animate = false
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<10) { index in
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.8), .blue.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 3, height: max(4, CGFloat(audioLevel) * CGFloat.random(in: 8...30)))
                        .scaleEffect(y: animate ? CGFloat.random(in: 0.5...1.5) : 1, anchor: .bottom)
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: animate
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear {
            animate = true
        }
    }
}

// Add after the ProfileButtonStyle struct
struct HighlightedPostBorder: View {
    let isHighlighted: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                isHighlighted
                ? LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                : LinearGradient(colors: [.clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: isHighlighted ? 3 : 0
            )
            .scaleEffect(isHighlighted ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHighlighted)
    }
}

// Add CommentView struct
struct CommentView: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            CachedAsyncImage(url: URL(string: comment.userImage)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                case .failure:
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                case .empty:
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                @unknown default:
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(comment.username)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(comment.content)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct ProfileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Empty State View Component
struct EmptyStateViewForProfile: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}


// Search Bar Component
struct SearchBarForProfile: View {
    @Binding var text: String
    let onClear: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onClear()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
    }
}


// Tab Button Component
struct TabButtonForProfile: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    isSelected ?
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [Color.clear, Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
        }
    }
}


struct UserListRowForProfile: View {
    let user: UserProfile
    let isLast: Bool
    let isLoading: Bool
    let hasMoreData: Bool
    let onLoadMore: () -> Void
    
    @EnvironmentObject var tweetData: TweetData
    @State private var isFollowing: Bool
    @State private var isFollowingLoading = false
    
    init(user: UserProfile, isLast: Bool, isLoading: Bool, hasMoreData: Bool, onLoadMore: @escaping () -> Void) {
        self.user = user
        self.isLast = isLast
        self.isLoading = isLoading
        self.hasMoreData = hasMoreData
        self.onLoadMore = onLoadMore
        _isFollowing = State(initialValue: user.isFollowing ?? false)
    }
    
    var body: some View {
        UserRowForProfile(user: user)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onAppear {
                if isLast && !isLoading && hasMoreData {
                    onLoadMore()
                }
            }
    }
}


// User Row Component
struct UserRowForProfile: View {
    let user: UserProfile
    @EnvironmentObject var tweetData: TweetData
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @State private var isFollowing: Bool
    @State private var isLoading = false
    @State private var showProfile = false
    
    init(user: UserProfile) {
        self.user = user
        _isFollowing = State(initialValue: user.isFollowing ?? false)
    }
    
    var body: some View {
        Button {
            showProfile = true
        } label: {
            HStack(spacing: 12) {
                // User Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    AsyncImage(url: URL(string: user.avatar)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        case .empty, .failure:
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        @unknown default:
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.nickname)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("@\(user.username)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Follow Button
                if tweetData.user?.id != user.id {
                    Button {
                        Task {
                            isLoading = true
                            let newFollowState = !isFollowing
                            
                            // Optimistically update UI
                            await MainActor.run {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    isFollowing = newFollowState
                                }
                            }
                            
                            do {
                                if newFollowState {
                                    try await tweetData.followUser(userId: user.id)
                                } else {
                                    try await tweetData.unfollowUser(userId: user.id)
                                }
                            } catch {
                                print("❌ Error toggling follow: \(error)")
                                // Revert UI state on error
                                await MainActor.run {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        isFollowing = !newFollowState
                                    }
                                }
                            }
                            isLoading = false
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(isFollowing ? .gray : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(isFollowing ? Color.white.opacity(0.1) : Color.blue)
                                )
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .background(
            NavigationLink(
                destination: TwitterProfileView(
                    userId: user.id,
                    username: user.username,
                    initialProfile: user.toSearchUserProfile()
                )
                .environmentObject(tweetData)
                .environmentObject(spacesViewModel)
                .navigationBarBackButtonHidden(false),
                isActive: $showProfile
            ) {
                EmptyView()
            }
        )
        .onChange(of: tweetData.otherUsers[user.id]?.isFollowing) { newValue in
            if let newValue = newValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isFollowing = newValue
                }
            }
        }
    }
}


struct UserListRow: View {
    let user: SearchUserProfile
    let isLast: Bool
    let isLoading: Bool
    let hasMoreData: Bool
    let onLoadMore: () -> Void
    
    @EnvironmentObject var tweetData: TweetData
    @State private var isFollowing: Bool
    @State private var isFollowingLoading = false
    
    init(user: SearchUserProfile, isLast: Bool, isLoading: Bool, hasMoreData: Bool, onLoadMore: @escaping () -> Void) {
        self.user = user
        self.isLast = isLast
        self.isLoading = isLoading
        self.hasMoreData = hasMoreData
        self.onLoadMore = onLoadMore
        _isFollowing = State(initialValue: user.isFollowing ?? false)
    }
    
    var body: some View {
        UserRow(user: user)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onAppear {
                if isLast && !isLoading && hasMoreData {
                    onLoadMore()
                }
            }
    }
}

struct UserListEmptyState: View {
    let searchText: String
    let selectedTab: UserListType
    
    var body: some View {
        EmptyStateViewForProfile(
            icon: "person.2.slash",
            title: "No Users Found",
            message: searchText.isEmpty ?
                "This user has no \(selectedTab == .followers ? "followers" : "following")" :
                "No users match your search"
        )
    }
}



struct UserListView: View {
    let users: [SearchUserProfile]
    let isLoading: Bool
    let hasMoreData: Bool
    let searchText: String
    let selectedTab: UserListType
    let onLoadMore: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(users) { user in
                    UserListRow(
                        user: user,
                        isLast: user.id == users.last?.id,
                        isLoading: isLoading,
                        hasMoreData: hasMoreData,
                        onLoadMore: onLoadMore
                    )
                }
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding()
                }
                
                if !isLoading && users.isEmpty {
                    UserListEmptyState(
                        searchText: searchText,
                        selectedTab: selectedTab
                    )
                }
            }
        }
    }
}


struct UserListViewForProfile: View {
    let users: [UserProfile]
    let isLoading: Bool
    let hasMoreData: Bool
    let searchText: String
    let selectedTab: UserListType
    let onLoadMore: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(users) { user in
                    UserListRowForProfile(
                        user: user,
                        isLast: user.id == users.last?.id,
                        isLoading: isLoading,
                        hasMoreData: hasMoreData,
                        onLoadMore: onLoadMore
                    )
                }
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding()
                }
                
                if !isLoading && users.isEmpty {
                    UserListEmptyState(
                        searchText: searchText,
                        selectedTab: selectedTab
                    )
                }
            }
        }
    }
}


// Add this component before UserListSheet
struct UserListTabBar: View {
    @Binding var selectedTab: UserListType
    let onTabChange: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            TabButtonForProfile(
                title: "Followers",
                isSelected: selectedTab == .followers,
                action: {
                    selectedTab = .followers
                    onTabChange()
                }
            )
            
            TabButtonForProfile(
                title: "Following",
                isSelected: selectedTab == .following,
                action: {
                    selectedTab = .following
                    onTabChange()
                }
            )
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - TikTok Loading Components (Independent)
struct TikTokLoadingCircle: View {
    let size: CGFloat
    let color: Color
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [
                        color.opacity(0.3),
                        color.opacity(0.8),
                        color,
                        color.opacity(0.8),
                        color.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 3
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotationAngle))
            .animation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false),
                value: rotationAngle
            )
            .onAppear {
                rotationAngle = 360
            }
    }
}

struct TikTokLoadingDots: View {
    let size: CGFloat
    let color: Color
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Dot 1 - Top
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.6)
                .offset(y: -(size - 20) / 2)
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                    .delay(0.0),
                    value: isAnimating
                )
            
            // Dot 2 - Top Right
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.6)
                .offset(
                    x: (size - 20) / 2 * 0.7,
                    y: -(size - 20) / 2 * 0.7
                )
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                    .delay(0.1),
                    value: isAnimating
                )
            
            // Dot 3 - Bottom Right
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.6)
                .offset(
                    x: (size - 20) / 2 * 0.7,
                    y: (size - 20) / 2 * 0.7
                )
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                    .delay(0.2),
                    value: isAnimating
                )
            
            // Dot 4 - Bottom
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.6)
                .offset(y: (size - 20) / 2)
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                    .delay(0.3),
                    value: isAnimating
                )
            
            // Dot 5 - Bottom Left
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.6)
                .offset(
                    x: -(size - 20) / 2 * 0.7,
                    y: (size - 20) / 2 * 0.7
                )
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                    .delay(0.4),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


// MARK: - Editable Category Card
struct EditableCategoryCard: View {
    let category: Category
    let isSelected: Bool
    let index: Int
    let animateAppearance: Bool
    let onToggle: (Bool) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            onToggle(!isSelected)
        }) {
            VStack(spacing: 8) {
                // Category icon with selection indicator
                ZStack {
                    // Background circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSelected ? [
                                    Color(hex: category.color),
                                    Color(hex: category.color).opacity(0.8)
                                ] : [
                                    Color(hex: category.color).opacity(0.3),
                                    Color(hex: category.color).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    // Category icon
                    Text(category.icon)
                        .font(.system(size: 24))
                        .scaleEffect(isHovered ? 1.2 : 1.0)
                    
                    // Selection indicator
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: category.color))
                            )
                            .offset(x: 15, y: -15)
                    }
                }
                .frame(width: 50, height: 50)
                
                // Category name
                Text(category.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: isSelected ? [
                                Color(hex: category.color).opacity(0.2),
                                Color(hex: category.color).opacity(0.1)
                            ] : [
                                Color(.systemBackground),
                                Color(.secondarySystemBackground)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color(hex: category.color) : Color(.separator),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .offset(y: animateAppearance ? 0 : 50)
            .opacity(animateAppearance ? 1 : 0)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.8)
                .delay(Double(index) * 0.05),
                value: animateAppearance
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Compact Category Card
struct CompactCategoryCard: View {
    let category: Category
    let index: Int
    let animateAppearance: Bool
    let isOptimisticallyUpdating: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Category icon
            Text(category.icon)
                .font(.system(size: 16))
            
            // Category name
            Text(category.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: category.color).opacity(0.8), Color(hex: category.color).opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color(hex: category.color).opacity(0.3), radius: 4, x: 0, y: 2)
        .scaleEffect(animateAppearance ? 1 : 0.8)
        .opacity(animateAppearance ? 1 : 0)
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8)
            .delay(Double(index) * 0.1),
            value: animateAppearance
        )
        .opacity(isOptimisticallyUpdating ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isOptimisticallyUpdating)
    }
}



// MARK: - Category Edit Sheet
struct CategoryEditSheet: View {
    let userId: Int64
    let currentCategories: [Category]
    let onCategoriesUpdated: ([Category]) -> Void
    
    @EnvironmentObject var tweetData: TweetData
    @Environment(\.dismiss) private var dismiss
    
    @State private var allCategories: [Category] = []
    @State private var selectedCategoryIds: Set<Int64> = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var searchText = ""
    @State private var animateAppearance = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var filteredCategories: [Category] {
        if searchText.isEmpty {
            return allCategories
        } else {
            return allCategories.filter { category in
                category.name.localizedCaseInsensitiveContains(searchText) ||
                category.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search interests...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Categories grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(filteredCategories.enumerated()), id: \.element.id) { index, category in
                            EditableCategoryCard(
                                category: category,
                                isSelected: selectedCategoryIds.contains(category.id),
                                index: index,
                                animateAppearance: animateAppearance,
                                onToggle: { isSelected in
                                    if isSelected {
                                        // Check if we're already at the 6-category limit
                                        if selectedCategoryIds.count >= 6 {
                                            // Show warning - don't add more
                                            return
                                        }
                                        selectedCategoryIds.insert(category.id)
                                    } else {
                                        selectedCategoryIds.remove(category.id)
                                    }
                                }
                            )
                            .opacity(selectedCategoryIds.count >= 6 && !selectedCategoryIds.contains(category.id) ? 0.5 : 1.0)
                            .disabled(selectedCategoryIds.count >= 6 && !selectedCategoryIds.contains(category.id))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100) // Space for bottom buttons
                }
                
                // Bottom action buttons
                VStack(spacing: 12) {
                    // Selected count with limit
                    VStack(spacing: 4) {
                        Text("\(selectedCategoryIds.count)/6 interests selected")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedCategoryIds.count >= 6 ? .orange : .secondary)
                            .opacity(animateAppearance ? 1 : 0)
                        
                        if selectedCategoryIds.count >= 6 {
                            Text("Maximum 6 interests allowed")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.orange)
                                .opacity(animateAppearance ? 1 : 0)
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button("Save") {
                            saveCategories()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(selectedCategoryIds.isEmpty || isSaving)
                        .overlay(
                            // Optimistic update indicator
                            Group {
                                if isSaving {
                                    HStack(spacing: 6) {
                                        TikTokLoadingView(size: 16, color: .white)
                                        Text("Saving...")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                )
            }
            .navigationTitle("Edit Interests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Load static categories immediately
            loadAllCategories()
            
            // Initialize selected categories
            selectedCategoryIds = Set(currentCategories.map { $0.id })
            
            // Animate appearance
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateAppearance = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadAllCategories() {
        isLoading = true
        
        // Use static categories directly since they're being updated
        allCategories = Category.staticCategories
        isLoading = false
        
        print("✅ Loaded \(allCategories.count) static categories")
    }
    
    private func saveCategories() {
        isSaving = true
        
        Task {
            do {
                let categoryIds = Array(selectedCategoryIds)
                
                // Call model method which handles optimistic updates internally
                try await tweetData.setUserCategories(categoryIDs: categoryIds)
                
                // SUCCESS: Model already updated the state optimistically
                // Update parent component to reflect the new state
                let selectedCategories = categoryIds.compactMap { id in
                    allCategories.first { $0.id == id }
                }
                onCategoriesUpdated(selectedCategories)
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
                
                print("✅ Categories saved successfully")
            } catch {
                print("❌ Error saving categories: \(error)")
                await MainActor.run {
                    // Model already reverted the optimistic update on failure
                    // Update parent component to reflect the reverted state
                    let revertedCategories = currentCategories.compactMap { category in
                        allCategories.first { $0.id == category.id }
                    }
                    onCategoriesUpdated(revertedCategories)
                    
                    errorMessage = error.localizedDescription
                    showError = true
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Profile Category Card Component
struct ProfileCategoryCard: View {
    let category: Category
    let index: Int
    let animateAppearance: Bool
    let isOptimisticallyUpdating: Bool
    
    @State private var isHovered = false
    @State private var animateGlow = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Category icon with animated background
            ZStack {
                // Animated background circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: category.color).opacity(0.3),
                                Color(hex: category.color).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .scaleEffect(animateGlow ? 1.1 : 1.0)
                    .opacity(animateGlow ? 0.8 : 0.6)
                
                // Category icon
                Text(category.icon)
                    .font(.system(size: 24))
                    .scaleEffect(isHovered ? 1.2 : 1.0)
                
                // Optimistic update indicator
                if isOptimisticallyUpdating {
                    Circle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 17, y: -17)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 50, height: 50)
            
            // Category name
            Text(category.name)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: category.color).opacity(0.3),
                                    Color(hex: category.color).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isOptimisticallyUpdating ? 2 : 1
                        )
                )
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .offset(y: animateAppearance ? 0 : 50)
        .opacity(animateAppearance ? 1 : 0)
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8)
            .delay(Double(index) * 0.1),
            value: animateAppearance
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .onAppear {
            // Start glow animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
        }
    }
}



// Follow Button Component
struct FollowButton: View {
    @State private var isFollowing: Bool
    @State private var buttonScale: CGFloat = 1
    @State private var showConfetti = false
    @State private var confettiScale: CGFloat = 0
    @State private var isLoading = false
    let userId: Int64
    let onFollowToggle: () -> Void
    @EnvironmentObject var tweetData: TweetData
    @Binding var userProfile: UserProfile?
    
    init(isFollowing: Bool, userId: Int64, userProfile: Binding<UserProfile?>, onFollowToggle: @escaping () -> Void) {
        _isFollowing = State(initialValue: isFollowing)
        self.userId = userId
        self._userProfile = userProfile
        self.onFollowToggle = onFollowToggle
    }
    
    private let followGradient = LinearGradient(
        colors: [.blue, .purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let unfollowGradient = LinearGradient(
        colors: [Color(.systemGray4), Color(.systemGray3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        Button {
            guard !isLoading else { return }
            Task {
                isLoading = true
                
                // Optimistically update UI state
                let newFollowState = !isFollowing
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isFollowing = newFollowState
                        buttonScale = 0.9
                        if newFollowState {
                            showConfetti = true
                            confettiScale = 1.5
                        }
                    }
                }
                
                do {
                    if newFollowState {
                        try await tweetData.followUser(userId: userId)
                    } else {
                        try await tweetData.unfollowUser(userId: userId)
                    }
                    
                    // Refresh the profile data
                    await MainActor.run {
                        if let updatedProfile = tweetData.otherUsers[userId] {
                            userProfile = updatedProfile
                        }
                    }
                    
                    // Call the refresh callback to ensure UI is in sync
                    onFollowToggle()
                    
                } catch {
                    print("❌ Error following/unfollowing user: \(error)")
                    // Revert UI state on error
                    await MainActor.run {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isFollowing = !newFollowState
                        }
                    }
                }
                
                isLoading = false
                
                // Reset confetti after animation
                if showConfetti {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation {
                            showConfetti = false
                            confettiScale = 0
                        }
                    }
                }
            }
        } label: {
            ZStack {
                // Button background with animated gradient
                Capsule()
                    .fill(isFollowing ? unfollowGradient : followGradient)
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: isFollowing ? .gray.opacity(0.3) : .blue.opacity(0.3),
                            radius: 8, x: 0, y: 4)
                
                // Button content
                if isLoading {
                    ProgressView()
                        .tint(isFollowing ? .gray : .white)
                        .scaleEffect(0.8)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: isFollowing ? "checkmark.circle.fill" : "person.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .symbolEffect(.bounce, value: isFollowing)
                        
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(isFollowing ? .gray : .white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                
                // Confetti effect
                if showConfetti {
                    ForEach(0..<8) { index in
                        Circle()
                            .fill(followGradient)
                            .frame(width: 8, height: 8)
                            .offset(x: CGFloat.random(in: -50...50),
                                   y: CGFloat.random(in: -50...50))
                            .scaleEffect(confettiScale)
                            .opacity(showConfetti ? 0 : 1)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.7)
                                .delay(Double(index) * 0.05),
                                value: showConfetti
                            )
                    }
                }
            }
            .scaleEffect(buttonScale)
        }
        .buttonStyle(ProfileButtonStyle())
        .disabled(isLoading)
        .onChange(of: isFollowing) { newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                buttonScale = 1
            }
        }
        .onChange(of: userProfile?.isFollowing) { newValue in
            if let newValue = newValue {
                isFollowing = newValue
            }
        }
    }
}


// Profile Stat View Component
struct ProfileStatView: View {
    let count: Int
    let label: String
    @State private var animate = false
    @State private var hover = false
    
    private let gradientColors = [Color.blue, Color.purple, Color.blue]
    
    var body: some View {
        VStack(spacing: 6) {
            // Animated number container
            ZStack {
                // Background circle with rotating gradient
                Circle()
                    .fill(
                        AngularGradient(
                            colors: gradientColors,
                            center: .center,
                            startAngle: .degrees(animate ? 0 : 360),
                            endAngle: .degrees(animate ? 360 : 0)
                        )
                    )
                    .frame(width: 50, height: 50)
                    .blur(radius: 15)
                    .opacity(0.5)
                
                // Glass effect container
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 5)
                
                // Count text with gradient and scaling animation
                Text("\(count)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(hover ? 1.1 : 1.0)
            }
            .scaleEffect(hover ? 1.05 : 1.0)
            
            // Label with custom styling
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 3)
                )
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
        .onHover { isHovered in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                hover = isHovered
            }
        }
        .contentShape(Rectangle())
        // ✅ REMOVED: Conflicting gesture that was preventing parent button taps
        // The parent Button will handle all touch interactions
    }
}




// MARK: - Pull to Refresh Loading
struct PullToRefreshLoadingView: View {
    @State private var rotationAngle: Double = 0
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            TikTokLoadingView(size: 24, color: .white)
            
            Text("Refreshing...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}




struct ReactionPreviewCard: View {
    let reactionTypeId: Int64
    let count: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Text(getReactionEmoji(for: reactionTypeId))
                .font(.system(size: 24))
            
            Text("\(count)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 60, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private func getReactionEmoji(for reactionTypeId: Int64) -> String {
        // ✅ Use the static reaction types from TweetDataReactionsExtension
        if let reactionType = ReactionType.staticReactions.first(where: { $0.id == reactionTypeId }) {
            return reactionType.icon
        }
        return "❤️" // Default fallback
    }
}


struct TikTokLoadingGlow: View {
    let size: CGFloat
    let color: Color
    @State private var scaleValue: Double = 1.0
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.6),
                        color.opacity(0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: size / 3
                )
            )
            .frame(width: size / 2, height: size / 2)
            .scaleEffect(scaleValue)
            .animation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true),
                value: scaleValue
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    scaleValue = 0.8
                }
            }
    }
}

// MARK: - TikTok-Style Loading Animation (Main View)
struct TikTokLoadingView: View {
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 40, color: Color = .white) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        ZStack {
            // Main revolving circle
            TikTokLoadingCircle(size: size, color: color)
            
            // Inner pulsing dots
            TikTokLoadingDots(size: size, color: color)
            
            // Center glow effect
            TikTokLoadingGlow(size: size, color: color)
        }
    }
}

// MARK: - Loading State Wrapper
struct LoadingStateView<Content: View>: View {
    let isLoading: Bool
    let loadingText: String
    let content: Content
    let loadingColor: Color
    
    init(
        isLoading: Bool,
        loadingText: String = "Loading...",
        loadingColor: Color = .white,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.loadingText = loadingText
        self.loadingColor = loadingColor
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
                .opacity(isLoading ? 0.3 : 1.0)
                .disabled(isLoading)
            
            if isLoading {
                VStack(spacing: 16) {
                    TikTokLoadingView(size: 50, color: loadingColor)
                    
                    Text(loadingText)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(loadingColor)
                        .opacity(0.9)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [loadingColor.opacity(0.3), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
        }
    }
}


// MARK: - Speaker Component

// MARK: - User Interests Section




struct UserInterestsSection: View {
    let userId: Int64
    let isCurrentUser: Bool
    
    @EnvironmentObject var tweetData: TweetData

    @State private var isLoadingCategories = false
    @State private var showEditSheet = false
    @State private var isRefreshing = false
    @State private var animateAppearance = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isOptimisticallyUpdating = false
    @State private var showSuccessAnimation = false
    
    // ✅ FIXED: Reactive categories from state
    private var userCategories: [Category] {
        if isCurrentUser {
            let categoryIds = tweetData.user?.categories ?? []
            return categoryIds.compactMap { categoryId in
                Category.staticCategories.first { $0.id == categoryId }
            }
        } else {
            // For other users, access from otherUsers state
            let categoryIds = tweetData.otherUsers[userId]?.categories ?? []
            return categoryIds.compactMap { categoryId in
                Category.staticCategories.first { $0.id == categoryId }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with edit button
            HStack {
                HStack(spacing: 8) {
                    Text("Interests")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.3), .clear],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                    
                    // Optimistic update indicator
                    if isOptimisticallyUpdating {
                        HStack(spacing: 4) {
                            if showSuccessAnimation {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .scaleEffect(1.2)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showSuccessAnimation)
                            } else {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.green)
                            }
                            
                            Text(showSuccessAnimation ? "Updated!" : "Updating...")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Spacer()
                
                if isCurrentUser {
                    Button(action: {
                        showEditSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Edit")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                    .scaleEffect(animateAppearance ? 1 : 0.8)
                    .opacity(animateAppearance ? 1 : 0)
                    .disabled(isOptimisticallyUpdating)
                }
            }
            .padding(.horizontal, 16)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isOptimisticallyUpdating)
            
            // Categories - Compact horizontal scroll
            if isLoadingCategories {
                // Compact loading state
                HStack {
                    TikTokLoadingView(size: 20, color: .white)
                    Text("Loading interests...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if userCategories.isEmpty {
                // Compact empty state
                HStack(spacing: 8) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("No interests set")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    if isCurrentUser {
                        Text("• Tap Edit to add")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.1), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .padding(.horizontal, 16)
            } else {
                // Compact horizontal scrollable categories
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        LazyHStack {
                            ForEach(Array(userCategories.enumerated()), id: \.element.id) { index, category in
                                CompactCategoryCard(
                                    category: category,
                                    index: index,
                                    animateAppearance: animateAppearance,
                                    isOptimisticallyUpdating: isOptimisticallyUpdating
                                )
                                .id(index)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, max(16, (UIScreen.main.bounds.width - CGFloat(userCategories.count * 70)) / 2))
                    }
                }
                .frame(height: 40) // Fixed height to prevent layout shifts
            }
        }
        .onAppear {
            loadCategoriesFromUserProfile()
            
            // Animate appearance
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateAppearance = true
            }
        }
        .sheet(isPresented: $showEditSheet) {
            CategoryEditSheet(
                userId: userId,
                currentCategories: userCategories,
                onCategoriesUpdated: { updatedCategories in
                    // ✅ FIXED: Categories are now reactive - model handles state updates
                    // Just show optimistic update indicator
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isOptimisticallyUpdating = true
                    }
                    
                    // Clear any previous errors
                    showError = false
                    errorMessage = ""
                    
                    // Show success animation after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSuccessAnimation = true
                        }
                        
                        // Hide success animation and optimistic update indicator
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showSuccessAnimation = false
                                isOptimisticallyUpdating = false
                            }
                        }
                    }
                }
            )
            .environmentObject(tweetData)
        }
        .refreshable {
            await refreshCategories()
        }
        .alert("Error", isPresented: $showError) {
            Button("Retry") {
                loadCategoriesFromUserProfile()
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

      private func loadCategoriesFromUserProfile() {
        isLoadingCategories = true
        showError = false
        errorMessage = ""
        
        if isCurrentUser {
            // ✅ AUTH USER: Categories are now reactive - no manual loading needed
            isLoadingCategories = false
            print("✅ Auth user categories are reactive - no manual loading needed")
        } else {
            // ✅ OTHER USER: Get categories from their profile (handles caching)
            if let username = tweetData.otherUsers[userId]?.username {
                Task {
                    do {
                        let otherUserProfile = try await tweetData.getOtherUserProfile(username: username)
                        
                        if let categoryIds = otherUserProfile.categories {
                            // Convert category IDs to Category objects using static categories
                            let categories = categoryIds.compactMap { categoryId in
                                Category.staticCategories.first { $0.id == categoryId }
                            }
                            
                            await MainActor.run {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                  
                                    isLoadingCategories = false
                                }
                            }
                            print("✅ Loaded \(categories.count) categories for other user")
                        } else {
                            await MainActor.run {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                 
                                    isLoadingCategories = false
                                }
                            }
                            print("ℹ️ No categories set for other user")
                        }
                    } catch {
                        print("❌ Error loading user categories: \(error)")
                        await MainActor.run {
                            isLoadingCategories = false
                            
                            // Only show error if we don't have any categories loaded
                            if userCategories.isEmpty {
                                showError = true
                                errorMessage = "Failed to load interests: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            } else {
                // No username available, show empty state
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isLoadingCategories = false
                }
                print("ℹ️ No username available for other user categories")
            }
        }
    }
    
    private func refreshCategories() async {
        isRefreshing = true
        
        if isCurrentUser {
            // ✅ AUTH USER: Categories are reactive - no manual refresh needed
            print("✅ Auth user categories are reactive - no manual refresh needed")
        } else {
            // ✅ OTHER USER: Refresh categories using getOtherUserProfile (handles caching)
            await loadCategoriesFromUserProfile()
        }
        
        isRefreshing = false
    }
    
    
   
}


