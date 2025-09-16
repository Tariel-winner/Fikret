import SwiftUI

// MARK: - Followers/Followings Fullscreen View
struct FollowersFollowingsView: View {
    let listType: UserListType
    let username: String
    @Binding var isPresented: Bool
    
    @EnvironmentObject var tweetData: TweetData
    @Environment(\.dismiss) private var dismiss
    
    // ✅ SIMPLIFIED: Local pagination state (no published variables)
    @State private var users: [FollowUser] = []
    @State private var currentPage: Int = 1
    @State private var hasMoreData: Bool = true
    @State private var isLoading: Bool = false
    @State private var totalCount: Int64 = 0
    
    // ✅ SIMPLIFIED: Local search and tab state
    @State private var searchText: String = ""
    @State private var selectedTab: UserListType
    @State private var animateAppearance: Bool = false
    
    private let pageSize: Int = 20
    
    init(listType: UserListType, username: String, isPresented: Binding<Bool>) {
        self.listType = listType
        self.username = username
        self._isPresented = isPresented
        self._selectedTab = State(initialValue: listType)
    }
    
    private var title: String {
        switch selectedTab {
        case .followers: return "Followers"
        case .following: return "Following"
        }
    }
    
    // ✅ FIXED: Client-side filtering since API doesn't support search
    private var filteredUsers: [FollowUser] {
        if searchText.isEmpty {
            return users
        }
        return users.filter { user in
            user.nickname.localizedCaseInsensitiveContains(searchText) ||
            user.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with close button
                headerSection
                
                // Tab bar for switching between followers/following
                UserListTabBar(
                    selectedTab: $selectedTab,
                    onTabChange: {
                        // ✅ SIMPLIFIED: loadUsers(reset: true) already calls resetPagination()
                        loadUsers(reset: true)
                    }
                )
                
                // Search bar (client-side filtering only)
                SearchBarForProfile(text: $searchText, onClear: {
                    searchText = ""
                })
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // ✅ SIMPLIFIED: Simple loading and data display logic
                if isLoading && users.isEmpty {
                    // Simple loading indicator
                    VStack(spacing: 20) {
                        ProgressView()
                            .tint(.primary)
                            .scaleEffect(1.2)
                        Text("Loading \(selectedTab == .followers ? "followers" : "following")...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredUsers.isEmpty && !isLoading {
                    // No data state
                    UserListEmptyState(
                        searchText: searchText,
                        selectedTab: selectedTab
                    )
                } else {
                    // Data loaded - show user list
                    FollowUserListViewForProfile(
                        users: filteredUsers,
                        isLoading: isLoading,
                        hasMoreData: hasMoreData,
                        searchText: searchText,
                        selectedTab: selectedTab,
                        onLoadMore: loadMoreUsers
                    )
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGray6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarHidden(true)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateAppearance = true
            }
            // ✅ SIMPLIFIED: Load initial data
            loadUsers(reset: true)
        }
        // ✅ REMOVED: onChange for searchText since we're doing client-side filtering
        // No need to reload from API when search changes
    }
    
    // Header section
    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .scaleEffect(animateAppearance ? 1 : 0.8)
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Tap to see details")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Placeholder for balance
            Circle()
                .fill(.clear)
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
    
    // ✅ SIMPLIFIED: Reset pagination state without animations
    private func resetPagination() {
        currentPage = 1
        hasMoreData = true
        users = []
        totalCount = 0
        // ✅ FIXED: Don't reset isLoading here - let loadUsers handle it
    }
    
    // ✅ SIMPLIFIED: Load users with pagination (no search API calls)
    private func loadUsers(reset: Bool = false) {
        guard reset || (!isLoading && hasMoreData) else { return }
        
        isLoading = true
        if reset {
            resetPagination()
        }
        
        Task {
            do {
                let response: (users: [FollowUser], total: Int64)
                
                switch selectedTab {
                case .followers:
                    response = try await tweetData.getUserFollowings(  // ✅ FIXED: getUserFollowings for followers (who follow this user)
                        username: username,
                        page: currentPage,
                        pageSize: pageSize
                    )
                case .following:
                    response = try await tweetData.getUserFollows(     // ✅ FIXED: getUserFollows for following (who this user follows)
                        username: username,
                        page: currentPage,
                        pageSize: pageSize
                    )
                }
                
                await MainActor.run {
                    // ✅ SIMPLIFIED: Update state without complex animations
                    if reset {
                        users = response.users
                        currentPage = 1
                    } else {
                        users.append(contentsOf: response.users)
                        currentPage += 1
                    }
                    
                    totalCount = response.total
                    hasMoreData = response.users.count == pageSize
                    isLoading = false
                }
                
                print("✅ Loaded \(response.users.count) \(selectedTab == .followers ? "followers" : "following") (page: \(currentPage-1), total: \(response.total))")
                
            } catch {
                print("❌ Error loading \(selectedTab == .followers ? "followers" : "following"): \(error)")
                await MainActor.run {
                    // ✅ SIMPLIFIED: Reset state on error
                    isLoading = false
                    if reset {
                        users = []
                        hasMoreData = false
                        currentPage = 1
                    }
                }
            }
        }
    }
    
    // ✅ SIMPLIFIED: Load more users for pagination
    private func loadMoreUsers() {
        loadUsers(reset: false)
    }
}



// ... existing code ...

// MARK: - FollowUser-specific Components

// FollowUser Row Component
struct FollowUserRowForProfile: View {
    let user: FollowUser
    @EnvironmentObject var tweetData: TweetData
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @State private var isFollowing: Bool
    @State private var isLoading = false
    @State private var showProfile = false
    
    init(user: FollowUser) {
        self.user = user
        _isFollowing = State(initialValue: user.isFollowing)
    }
    
    var body: some View {
        Button {
            showProfile = true
        } label: {
            HStack(spacing: 12) {
                // Avatar
                avatarView
                
                // User info
                userInfoView
                
                Spacer()
                
                // Follow button (if not current user)
                if tweetData.user?.id != user.userId {
                    followButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundView)
        }
        .buttonStyle(PlainButtonStyle())
        .fullScreenCover(isPresented: $showProfile) {
            TwitterProfileView(
                userId: user.userId,
                username: user.username,
                initialProfile: nil
            )
            .environmentObject(tweetData)
            .environmentObject(spacesViewModel)
        }
        .onChange(of: tweetData.otherUsers[user.userId]?.isFollowing) { newValue in
            if let newValue = newValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isFollowing = newValue
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var avatarView: some View {
        CachedAsyncImage(url: user.avatar.safeURL()) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(radius: 4)
            case .failure:
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundColor(.gray)
            case .empty:
                ProgressView()
                    .frame(width: 44, height: 44)
            @unknown default:
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    )
            }
        }
    }
    
    private var userInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(user.nickname)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("@\(user.username)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    private var followButton: some View {
        Button {
            Task {
                isLoading = true
                let newFollowState = !isFollowing
                
                // Optimistically update UI state
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isFollowing = newFollowState
                    }
                }
                
                do {
                    if newFollowState {
                        try await tweetData.followUser(userId: user.userId)
                    } else {
                        try await tweetData.unfollowUser(userId: user.userId)
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
                    .tint(.primary)
                    .scaleEffect(0.8)
            } else {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isFollowing ? .secondary : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(followButtonBackground)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
        .onTapGesture {
            // Stop event propagation to prevent profile navigation
        }
    }
    
    private var followButtonBackground: some View {
        Capsule()
            .fill(
                isFollowing ?
                LinearGradient(
                    colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                ) :
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
    }
}

// FollowUser List View Component
struct FollowUserListViewForProfile: View {
    let users: [FollowUser]
    let isLoading: Bool
    let hasMoreData: Bool
    let searchText: String
    let selectedTab: UserListType
    let onLoadMore: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(users) { user in
                    FollowUserRowForProfile(user: user)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .onAppear {
                            let isLastUser = user.userId == users.last?.userId
                                                      let shouldLoadMore = !isLoading && hasMoreData
                            if isLastUser && shouldLoadMore {
                                                            onLoadMore()
                                                        }
                                                      
                        }
                }
                
                if isLoading && !users.isEmpty {
                    // ✅ IMPROVED: Pagination loading state - only show when loading more data
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.primary)
                            .scaleEffect(1.2)

                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
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

// ... existing code ...
