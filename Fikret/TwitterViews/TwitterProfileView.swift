import SwiftUI
//import Stripe
import PhotosUI
import UIKit


struct TwitterProfileView: View {
    let userId: Int64
    let username: String?
    let initialProfile: SearchUserProfile?
    let targetPostId: Int64?
    let targetPostLocation: PostLocationResponse?
    let onDismiss: (() -> Void)?
    @EnvironmentObject var tweetData: TweetData
    @EnvironmentObject var audioManager: WebMAudioPlaybackManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    @State private var userProfile: UserProfile?
    @State private var isLoading = false
    @State private var showLiveSession = false
    @State private var activeSheet: SheetType?
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @State private var showCreateSpace = false
    @State private var didFetchProfile = false
    @State private var shouldScrollToTarget = false
    @State private var targetPostLoaded = false
    @State private var isTargetPostReady = false
    @State private var animateLoading = false
    // Animation States
    @State private var animateProfile = false
    @State private var headerOffset: CGFloat = 0
    
    @State private var showFollowersList = false
    @State private var showFollowingList = false
    @State private var listType: UserListType = .followers
    
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var showReactionSheet = false
    @State private var showSpacesSheet = false
    
    // ✅ LOCAL: Profile coordinator for infinite navigation
    @State private var profileSheetCoordinator = ProfileSheetCoordinator()
    
    // Profile image update states
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isUpdatingAvatar = false
    



    enum SheetType: Identifiable {
        case createSpace
        
        var id: Int {
            switch self {
            case .createSpace: return 1
            }
        }
    }
    
    init(userId: Int64, username: String? = nil, initialProfile: SearchUserProfile? = nil, targetPostId: Int64? = nil, targetPostLocation: PostLocationResponse? = nil, onDismiss: (() -> Void)? = nil) {
        self.userId = userId
        self.username = username
        self.initialProfile = initialProfile
        self.targetPostId = targetPostId
        self.targetPostLocation = targetPostLocation
        self.onDismiss = onDismiss
        
    }
    

          // Design Constants - Moved to be accessible by components
    enum Design {
        static let headerHeight: CGFloat = 240
        static let avatarSize: CGFloat = 110
        static let avatarOffset: CGFloat = -55
        static let contentPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 16
        static let shadowRadius: CGFloat = 8
        static let buttonHeight: CGFloat = 50
        static let liveButtonPadding: CGFloat = 20
        static let liveIndicatorSize: CGFloat = 12
        
        static let backgroundColor = Color(.systemBackground)
        static let accentGradient = LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let secondaryColor = Color(.secondarySystemBackground)
    }
    
    
    
    private var isCurrentUserProfile: Bool {
        guard let currentUserId = tweetData.user?.id else {
            return false
        }
        return currentUserId == userId
    }
    
    // Helper function to get online status for other users (defaults to false if not available)
    private func getOnlineStatus(for userId: Int64) -> Bool {
        // Only check for other users, not current user
        guard !isCurrentUserProfile else { return false }
        
        // Get from tweetData.otherUsers directly for reactive updates
        return tweetData.otherUsers[userId]?.isOnline ?? false
    }
    
    
    private func refreshProfile() async {
        isLoading = true
        do {
            if userId == tweetData.user?.id {
                // ✅ CURRENT USER: Only refresh if we don't have data or if it's stale
                if userProfile == nil {
                    let profile = try await tweetData.forceRefreshCurrentUserProfile()
                    await MainActor.run {
                        self.userProfile = profile
                    }
                    print("✅ [PROFILE] Loaded current user profile with categories: \(profile.categories ?? [])")
                } else {
                    print("✅ [PROFILE] Using existing current user profile data")
                }
            } else {
                // ✅ OTHER USER: Use getOtherUserProfile (handles caching)
                if let username = username {
                    let profile = try await tweetData.getOtherUserProfile(username: username)
                    await MainActor.run {
                        self.userProfile = profile
                    }
                } else {
                    // No username - this shouldn't happen
                    print("❌ No username for other user with userId: \(userId)")
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("❌ Error refreshing profile: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
  
    
    // Update profile image
    private func updateProfileImage(_ image: UIImage) async {
        guard isCurrentUserProfile else { return }
        
        // Show loading state
        await MainActor.run {
            isUpdatingAvatar = true
        }
        
            print("📸 [PROFILE] Updating profile image...")
            
            // Convert image to JPEG data
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                print("❌ [PROFILE] Failed to convert image to data")
                await MainActor.run {
                    isUpdatingAvatar = false
                }
                return
            }
            
        // Update avatar using TweetData method - error handling is done there
        do {
            try await tweetData.updateAvatar(avatarData: imageData)
            print("✅ [PROFILE] Profile image updated successfully")
        } catch {
            print("❌ [PROFILE] Failed to update profile image: \(error)")
            // Error handling and rollback is managed by TweetData.updateAvatar
        }
        
        await MainActor.run {
            isUpdatingAvatar = false
            selectedImage = nil // Clear selected image
        }
    }


    private var floatingIndicator: some View {
    VStack {
        Spacer()
        
        // ✅ NATIVE SHEET: Make entire floating indicator tappable
        Button(action: {
            showSpacesSheet = true
        }) {
            HStack {
                HStack(spacing: 12) {
                    // Live indicator
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: spacesViewModel.isInSpace)
                    
                    // Call info
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Space")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Tap to return")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // ✅ FIXED: Arrow icon is now just visual, not a separate button
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.9), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
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
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Above tab bar
        }
        .buttonStyle(PlainButtonStyle()) // ✅ ADDED: Prevents default button styling
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: spacesViewModel.isInSpace)
        .zIndex(999)
    }
}

    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Back and Settings buttons with glass effect
                    HStack {
                        // Back button - Show when not current user OR when presented in sheet OR when in NavigationStack (sheet presentation)
                        if !isCurrentUserProfile || onDismiss != nil || presentationMode.wrappedValue.isPresented {
                            Button {
                                if let onDismiss = onDismiss {
                                    onDismiss()
                                } else {
                                    dismiss()
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(Design.accentGradient)
                                }
                            }
                            .scaleEffect(animateProfile ? 1 : 0.8)
                            .zIndex(1)
                            .padding(.top, 8)
                            .padding(.leading, 8)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .id("back-button")
                
              
                
                // Profile Header Section
                ProfileHeaderSection(
                    user: isCurrentUserProfile ? tweetData.user : userProfile,
                    isCurrentUserProfile: isCurrentUserProfile,
                    userId: userId,
                    animateProfile: animateProfile,
                    headerOffset: headerOffset,
                    isUpdatingAvatar: isUpdatingAvatar,
                    showImagePicker: $showImagePicker,
                    selectedImage: $selectedImage,
                    onUpdateProfileImage: updateProfileImage,
                    getOnlineStatus: getOnlineStatus
                )
                .id("profile-header")
                

               
               
                
                // Profile Info
                if let user = isCurrentUserProfile ? tweetData.user : userProfile {
                    VStack(spacing: Design.contentPadding) {
                        // Name and Username with gradient - username stays centered
                        ZStack {
                            // Username stays in center (original position)
                            VStack(spacing: 4) {
                                Text(user.nickname)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(Design.accentGradient)
                                
                                Text("@\(user.username ?? "")")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Reaction Button positioned absolutely to the right
                            HStack {
                                Spacer()
                                Button(action: {
                                    showReactionSheet = true
                                }) {
                                    // Fixed-size container to prevent layout shifts
                                    ZStack {
                                        // Main button circle
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 50, height: 50)
                                        
                                        // Heart icon
                                        Image(systemName: "heart.text.square.fill")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.red, .pink],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                        
                                        // Always show reaction count (0 if no reactions)
                                        VStack {
                                            HStack {
                                                Spacer()
                                                Text((user.reactionCounts?.values.reduce(0, +) ?? 0).formattedCount)
                                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 2)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color.red.opacity(0.9))
                                                    )
                                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                            }
                                            Spacer()
                                        }
                                        .offset(x: 8, y: -8)
                                    }
                                    // Fixed frame size to prevent any layout shifts
                                    .frame(width: 60, height: 60)
                                    .contentShape(Rectangle())
                                }
                                .scaleEffect(animateProfile ? 1 : 0.8)
                                .padding(.trailing, 20)
                            }
                        }
                        // Fixed height container to prevent layout shifts
                        .frame(height: 80)
                        .padding(.top, abs(Design.avatarOffset) + Design.contentPadding)
                        .scaleEffect(animateProfile ? 1 : 0.9)
                        
                        // Follow Button (if not current user's profile)
                        if !isCurrentUserProfile {
                            FollowButton(
                                isFollowing: user.isFollowing ?? false,
                                userId: userId,
                                userProfile: $userProfile,
                                onFollowToggle: {
                                    // ✅ REMOVED: Unnecessary refreshProfile call
                                    // TweetData.followUser/unfollowUser already updates both users' state correctly
                                    // The UI will automatically reflect the changes through @Published properties
                                    print("✅ [FOLLOW] Follow/Unfollow completed - state updated automatically")
                                }
                            )
                            .scaleEffect(animateProfile ? 1 : 0.9)
                            .padding(.top, 8)
                        }
                        
                        // Bio with custom styling
                     /*   if let bio = user.status {
                            Text(bio)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: Design.cornerRadius)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.05), radius: 8)
                                )
                        }*/
                        
                        // Enhanced Stats Row with tap gestures
                        HStack(spacing: Design.contentPadding * 2) {
                            Button(action: {
                                listType = .followers
                                showFollowersList = true
                            }) {
                                ProfileStatView(
                                    count: user.follows,
                                    label: "Followers"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .scaleEffect(showFollowersList ? 0.95 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: showFollowersList)
                            
                            Divider()
                                .frame(height: 30)
                                .background(Design.accentGradient)
                            
                            Button(action: {
                                listType = .following
                                showFollowingList = true
                            }) {
                                ProfileStatView(
                                    count: user.followings,
                                    label: "Following"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .scaleEffect(showFollowingList ? 0.95 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: showFollowingList)
                            

                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 30)
                        .background(
                            RoundedRectangle(cornerRadius: Design.cornerRadius)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 10)
                        )
                        .scaleEffect(animateProfile ? 1 : 0.9)
                        
                        // Modern Interests/Categories Section
                        UserInterestsSection(
                            userId: userId,
                            isCurrentUser: isCurrentUserProfile
                        )
                        .padding(.top, 16)
                        
                        // Enhanced Location Display with better formatting
                        if let locationData = user.phone, !locationData.isEmpty {
                            LocationDisplayView(locationText: locationData)
                        }
                        
                        if let website = user.activation, !website.isEmpty {
                            Link(destination: URL(string: website) ?? URL(string: "https://twitter.com")!) {
                                HStack {
                                    Image(systemName: "link")
                                        .foregroundStyle(Design.accentGradient)
                                    Text(website)
                                        .foregroundStyle(Design.accentGradient)
                                }
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                )
                            }
                        }
                        

                    }
                    .padding()
                    .id("profile-info")
                }
                
                // Active Space Card
                // if let userSpace = spacesViewModel.spaces.first(where: { space in
                //     let isHost = space.hostId == userId
                //     return isHost
                // }) {
                //     SpaceCard(space: userSpace)
                //         .padding()
                //         .transition(.scale.combined(with: .opacity))
                // }

                if let user = isCurrentUserProfile ? tweetData.user : userProfile {
                    UserPostsSection(
                        userId: userId,
                        username: user.username ?? "",
                        targetPostId: targetPostId,
                        targetPostLocation: targetPostLocation,
                        scrollProxy: proxy
                    )
                        .padding(.top, 20)
                        .id("posts-section")
                } else {
                    Text("Loading user data...")
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                }
            }
        }
        .coordinateSpace(name: "main-scroll")
        .navigationBarHidden(true) // ✅ FIXED: Hide navigation bar to keep tabs visible during profile navigation
        .id("TwitterProfileView-\(userId)-\(targetPostId?.description ?? "nil")")
         .fullScreenCover(isPresented: $showFollowersList) {
            FollowersFollowingsView(
                listType: .followers,
                username: isCurrentUserProfile ? tweetData.user?.username ?? "" : username ?? "",
                isPresented: $showFollowersList
            )
            .environmentObject(tweetData)
        }
        .fullScreenCover(isPresented: $showFollowingList) {
            FollowersFollowingsView(
                listType: .following,
                username: isCurrentUserProfile ? tweetData.user?.username ?? "" : username ?? "",
                isPresented: $showFollowingList
            )
            .environmentObject(tweetData)
        }
        .fullScreenCover(isPresented: $showReactionSheet) {
            ReactionDetailView(
                userId: userId,
                isCurrentUser: isCurrentUserProfile,
                profileSheetCoordinator: $profileSheetCoordinator
            )
            .environmentObject(tweetData)
        }
        .onAppear {
            // Prevent multiple onAppear calls
            guard !didFetchProfile else { return }
            
            // Set flag immediately to prevent multiple calls
            didFetchProfile = true
            
            // Handle navigation state for user profile switching
            let currentUsername = isCurrentUserProfile ? tweetData.user?.username : username
            spacesViewModel.handleUserProfileNavigation(fromUsername: nil, toUsername: currentUsername)
            
            // Start animations
            withAnimation(.easeInOut(duration: 1)) {
                animateProfile = true
            }
            
            // ✅ REMOVED: Unnecessary animation timers that cause infinite loops
            // These were just cosmetic animations for gradient direction and avatar scale
            // They're not essential for functionality and were causing view lifecycle issues
            
            // ✅ OPTIMIZED: Only load profile if we don't have it yet
            if userProfile == nil {
                Task {
                    await refreshProfile()
                }
            } else {
                print("✅ [PROFILE] Using existing profile data, skipping API call")
            }
        }
        // ✅ ADDED: Make view reactive to tweetData.user changes
        .onChange(of: tweetData.user) { newUser in
            if isCurrentUserProfile && newUser != nil {
                print("🔄 [PROFILE] tweetData.user changed, view will update")
            }
        }
        .onDisappear {
            // Clear posts state for this user to prevent conflicts
           /* if let username = username {
                spacesViewModel.clearUserPosts(username: username)
            }*/
            
            // ✅ FIXED: Don't cleanup audio manager here - let it be managed centrally
            // audioManager.cleanup() // REMOVED - causes infinite loop
        }
        // ✅ FIXED: Add beautiful "finish conversation first" overlay
        .overlay {
            if spacesViewModel.showFinishConversationOverlay {
                ZStack {
                    // Beautiful background blur
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                spacesViewModel.showFinishConversationOverlay = false
                            }
                        }
                    
                    // Modern card design
                    VStack(spacing: 24) {
                        // Icon with animation
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.2), .blue.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "waveform.and.mic")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .scaleEffect(spacesViewModel.showFinishConversationOverlay ? 1.0 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: spacesViewModel.showFinishConversationOverlay)
                        
                        // Text content
                        VStack(spacing: 12) {
                            Text("Finish Your Conversation First")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("You're currently in a live space. Please finish or leave the conversation before playing other audio content.")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            // Return to space button
                            Button(action: {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    spacesViewModel.showFinishConversationOverlay = false
                                    spacesViewModel.showSpaceView = true
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Return to Space")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            
                            // Leave space button
                            Button(action: {
                                Task {
                                    await spacesViewModel.spaceButtonTapped()
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        spacesViewModel.showFinishConversationOverlay = false
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Leave Space")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.8))
                                )
                                .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                        }
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.9),
                                        Color.black.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.2), .clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 40)
                    .scaleEffect(spacesViewModel.showFinishConversationOverlay ? 1.0 : 0.9)
                    .opacity(spacesViewModel.showFinishConversationOverlay ? 1.0 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: spacesViewModel.showFinishConversationOverlay)
                }
                .zIndex(1001)
            }
        }
        // ✅ REMOVED: Profile navigation moved to ReactionDetailView
        // Note: Spaces overlay moved to TwitterTabView for better UX
        // Note: Spaces overlay logic moved to TwitterTabView for better UX
        .overlay {
            // ✅ FLOATING INDICATOR: Only for other user profiles
            if !isCurrentUserProfile && spacesViewModel.isInSpace && spacesViewModel.isHost {
                floatingIndicator
                    .zIndex(99999) // Higher than any presentation layer
            }
        }
        .sheet(isPresented: !isCurrentUserProfile ? $showSpacesSheet : .constant(false)) {
            // ✅ LOCAL SHEET: Only for other user profiles
            SpacesListeningNowView(showConfirmationModal: .constant(false))
                .environmentObject(spacesViewModel)
                .environmentObject(tweetData)
        }

    }
}

// MARK: - Location Display View
struct LocationDisplayView: View {
    let locationText: String
    
    // Design Constants
    enum Design {
        static let accentGradient = LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .foregroundStyle(Design.accentGradient)
            
            VStack(alignment: .leading, spacing: 2) {
                // Primary location (most specific part)
                Text(primaryLocationText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Secondary location (additional context)
                if let secondaryText = secondaryLocationText {
                    Text(secondaryText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Location Parsing Logic
    
    /// Extract the most specific location part (address > city > street > first component)
    private var primaryLocationText: String {
        let components = parseLocationComponents(locationText)
        
        // Priority: address (if complete) > city > street > first component > full text
        if let address = components.address, !address.isEmpty {
            return address
        } else if let city = components.city, !city.isEmpty {
            return city
        } else if let street = components.street, !street.isEmpty {
            return street
        } else if let firstComponent = components.firstComponent, !firstComponent.isEmpty {
            return firstComponent
        }
        
        return locationText
    }
    
    /// Extract secondary location context (state, country, or remaining parts)
    private var secondaryLocationText: String? {
        let components = parseLocationComponents(locationText)
        var secondaryParts: [String] = []
        
        // Add state if available and different from primary
        if let state = components.state, !state.isEmpty, state != primaryLocationText {
            secondaryParts.append(state)
        }
        
        // Add country if available and different from primary
        if let country = components.country, !country.isEmpty, country != primaryLocationText {
            secondaryParts.append(country)
        }
        
        // Add remaining components if they provide additional context
        if !components.remainingComponents.isEmpty {
            let filteredRemaining = components.remainingComponents.filter { 
                $0 != primaryLocationText && 
                $0 != components.state && 
                $0 != components.country 
            }
            if !filteredRemaining.isEmpty {
                secondaryParts.append(contentsOf: filteredRemaining)
            }
        }
        
        return secondaryParts.isEmpty ? nil : secondaryParts.joined(separator: ", ")
    }
    
    /// Parse location text into structured components
    private func parseLocationComponents(_ text: String) -> LocationComponents {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmedText.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var result = LocationComponents()
        
        if components.isEmpty {
            return result
        }
        
        // Set first component
        result.firstComponent = components.first
        
        // Check if this looks like a complete address (has street, city, state, country)
        if components.count >= 4 {
            // If we have 4+ components, treat the first part as street/address
            if isStreet(components[0].lowercased()) || components[0].contains(where: { $0.isNumber }) {
                result.address = components[0] // Street/address part
                result.city = components.count > 2 ? components[components.count - 3] : nil
                result.state = components.count > 1 ? components[components.count - 2] : nil
                result.country = components.last
            }
        }
        
        // Try to identify city, state, country, and street from individual components
        for (index, component) in components.enumerated() {
            let lowercasedComponent = component.lowercased()
            
            // Check for country indicators
            if isCountry(lowercasedComponent) {
                result.country = component
            }
            // Check for state/province indicators
            else if isState(lowercasedComponent) {
                result.state = component
            }
            // Check for city indicators
            else if isCity(lowercasedComponent, index: index, totalComponents: components.count) {
                result.city = component
            }
            // Check for street indicators
            else if isStreet(lowercasedComponent) {
                result.street = component
            }
            // Add to remaining components
            else {
                result.remainingComponents.append(component)
            }
        }
        
        return result
    }
    
    /// Check if a component looks like a country
    private func isCountry(_ component: String) -> Bool {
        let countryIndicators = ["china", "usa", "united states", "uk", "united kingdom", "canada", "australia", "germany", "france", "japan", "india", "brazil", "russia", "mexico", "spain", "italy", "korea", "thailand", "vietnam", "philippines", "indonesia", "malaysia", "singapore", "taiwan", "hong kong"]
        return countryIndicators.contains(component)
    }
    
    /// Check if a component looks like a state/province
    private func isState(_ component: String) -> Bool {
        let stateIndicators = ["california", "texas", "florida", "new york", "pennsylvania", "illinois", "ohio", "georgia", "north carolina", "michigan", "new jersey", "virginia", "washington", "arizona", "massachusetts", "tennessee", "indiana", "missouri", "maryland", "wisconsin", "colorado", "minnesota", "south carolina", "alabama", "louisiana", "kentucky", "oregon", "oklahoma", "connecticut", "utah", "iowa", "nevada", "arkansas", "mississippi", "kansas", "new mexico", "nebraska", "west virginia", "idaho", "hawaii", "new hampshire", "maine", "montana", "rhode island", "delaware", "south dakota", "north dakota", "alaska", "vermont", "wyoming", "ontario", "quebec", "british columbia", "alberta", "manitoba", "saskatchewan", "nova scotia", "new brunswick", "newfoundland", "prince edward island", "northwest territories", "yukon", "nunavut", "xinjiang", "tibet", "inner mongolia", "guangdong", "jiangsu", "shandong", "henan", "sichuan", "hubei", "hunan", "anhui", "hebei", "jiangxi", "liaoning", "fujian", "shaanxi", "shanxi", "hebei", "guangxi", "yunnan", "guizhou", "gansu", "qinghai", "hainan", "taiwan", "hong kong", "macau"]
        return stateIndicators.contains(component)
    }
    
    /// Check if a component looks like a city
    private func isCity(_ component: String, index: Int, totalComponents: Int) -> Bool {
        // If it's the first component and not clearly a country/state, it's likely a city
        if index == 0 && totalComponents > 1 {
            return !isCountry(component) && !isState(component)
        }
        
        // If it's in the middle and not a country/state, it could be a city
        if index > 0 && index < totalComponents - 1 {
            return !isCountry(component) && !isState(component)
        }
        
        return false
    }
    
    /// Check if a component looks like a street
    private func isStreet(_ component: String) -> Bool {
        let streetIndicators = ["street", "st", "road", "rd", "avenue", "ave", "boulevard", "blvd", "drive", "dr", "lane", "ln", "way", "place", "pl", "court", "ct", "circle", "cir", "square", "sq", "parkway", "pkwy", "highway", "hwy", "route", "rt"]
        
        // Check if it contains street indicators
        for indicator in streetIndicators {
            if component.contains(indicator) {
                return true
            }
        }
        
        // Check if it starts with a number (common for street addresses)
        if let firstChar = component.first, firstChar.isNumber {
            return true
        }
        
        return false
    }
}

// MARK: - Location Components Structure
private struct LocationComponents {
    var firstComponent: String?
    var address: String?
    var city: String?
    var state: String?
    var country: String?
    var street: String?
    var remainingComponents: [String] = []
}

}

// MARK: - Diagonal Pattern Overlay Component
struct DiagonalPatternOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let spacing: CGFloat = 20
                
                for x in stride(from: 0, through: width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + height, y: height))
                }
            }
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.2), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
    }
}

// MARK: - Profile Header Section Component

struct ProfileHeaderSection: View {
    let user: UserProfile?
    let isCurrentUserProfile: Bool
    let userId: Int64
    let animateProfile: Bool
    let headerOffset: CGFloat
    let isUpdatingAvatar: Bool
    @Binding var showImagePicker: Bool
    @Binding var selectedImage: UIImage?
    let onUpdateProfileImage: (UIImage) async -> Void
    let getOnlineStatus: (Int64) -> Bool
    

       // Design Constants - Moved to be accessible by components
    enum Design {
        static let headerHeight: CGFloat = 240
        static let avatarSize: CGFloat = 110
        static let avatarOffset: CGFloat = -55
        static let contentPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 16
        static let shadowRadius: CGFloat = 8
        static let buttonHeight: CGFloat = 50
        static let liveButtonPadding: CGFloat = 20
        static let liveIndicatorSize: CGFloat = 12
        
        static let backgroundColor = Color(.systemBackground)
        static let accentGradient = LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let secondaryColor = Color(.secondarySystemBackground)
    }
    

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                Spacer()
            }
            
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: Design.headerHeight)
            .overlay(
                DiagonalPatternOverlay()
            )
            .offset(y: headerOffset)
            
            if let user = user {
                // Profile Avatar with animations
                ZStack {
                    // Outer ring animation
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: Design.avatarSize + 20, height: Design.avatarSize + 20)
                        .rotationEffect(.degrees(animateProfile ? 360 : 0))
                    
                    // Profile Image - Always show current avatar, overlay loading state when updating
                    CachedAsyncImage(url: user.avatar.safeURL()) { phase in
                        switch phase {
                        case .empty:
                            // Loading placeholder
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: Design.avatarSize+20, height: Design.avatarSize+20)
                                .overlay(ProgressView().tint(.gray))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: Design.avatarSize + 20, height: Design.avatarSize + 20)
                                .clipShape(Circle())
                        case .failure(_):
                            // Error placeholder
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: Design.avatarSize + 20, height: Design.avatarSize + 20)
                                .overlay(
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .padding(20)
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: Design.avatarSize+20, height: Design.avatarSize+20)
                        }
                    }
                    .id("avatar-\(user.avatar)-\(isUpdatingAvatar ? "updating" : "stable")") // Force refresh when avatar URL changes or updating state
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .shadow(color: .black.opacity(0.2), radius: Design.shadowRadius)
                    .overlay(
                        // Loading overlay when updating avatar
                        Group {
                            if isUpdatingAvatar {
                                ZStack {
                                    Color.black.opacity(0.5)
                                        .frame(width: Design.avatarSize + 20, height: Design.avatarSize + 20)
                                        .clipShape(Circle())
                                    
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(1.2)
                                }
                            }
                        }
                    )
                    .overlay(
                        // Online status indicator (ONLY for other users)
                        Group {
                            if !isCurrentUserProfile {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        // Online status dot
                                        Circle()
                                            .fill(
                                                getOnlineStatus(userId) ?
                                                LinearGradient(
                                                    colors: [.green, .green.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ) :
                                                LinearGradient(
                                                    colors: [.orange, .orange.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 20, height: 20)
                                            .overlay(
                                                Circle()
                                                    .stroke(.white, lineWidth: 3)
                                            )
                                            .shadow(color: .black.opacity(0.3), radius: 4)
                                            .overlay(
                                                // Pulse animation for online status
                                                Circle()
                                                    .stroke(
                                                        getOnlineStatus(userId) ? .green.opacity(0.6) : .clear,
                                                        lineWidth: 2
                                                    )
                                                    .frame(width: 28, height: 28)
                                                    .scaleEffect(animateProfile ? 1.2 : 1.0)
                                                    .opacity(animateProfile ? 0 : 0.8)
                                                    .animation(
                                                        getOnlineStatus(userId) ?
                                                        .easeInOut(duration: 2)
                                                        .repeatForever(autoreverses: false) : .default,
                                                        value: animateProfile
                                                    )
                                            )
                                    }
                                    .padding(.trailing, 8)
                                }
                                .padding(.bottom, 8)
                            } else {
                                // Edit indicator for current user
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        // Edit button overlay
                                        ZStack {
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .frame(width: 32, height: 32)
                                                .shadow(color: .black.opacity(0.2), radius: 4)
                                            
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        .scaleEffect(animateProfile ? 1.1 : 1.0)
                                        .animation(.easeInOut(duration: 0.3), value: animateProfile)
                                    }
                                    .padding(.trailing, 8)
                                }
                                .padding(.bottom, 8)
                            }
                        }
                    )
                }
                .offset(y: Design.avatarOffset)
                .onTapGesture {
                    if isCurrentUserProfile && !isUpdatingAvatar {
                        showImagePicker = true
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(selectedImage: $selectedImage)
                        .onDisappear {
                            // ✅ IMMEDIATELY show loading state if image was selected
                            if selectedImage != nil {
                                // Note: isUpdatingAvatar is managed by parent view
                            }
                        }
                }
                .onChange(of: selectedImage) { newImage in
                    if let image = newImage {
                        Task {
                            await onUpdateProfileImage(image)
                        }
                    }
                }
            }
        }
    }
}

// Add this extension for number formatting
extension Int {
    var formattedCount: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        } else {
            return "\(self)"
        }
    }
}



// Add after the ProfileButtonStyle struct
struct UserPostsSection: View {
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @EnvironmentObject var tweetData: TweetData
    @EnvironmentObject var audioManager: WebMAudioPlaybackManager

    let userId: Int64
    let username: String
    let targetPostId: Int64?
    let targetPostLocation: PostLocationResponse?
    let scrollProxy: ScrollViewProxy
    
    @State private var targetPostIndex: Int?
    @State private var isTargetPostReady = false
    @State private var animateLoading = false
    @State private var didLoadPosts = false
    @State private var scrollOffset: CGFloat = 0
    @State private var lastScrollCheck = Date()
    @State private var isPaginationTriggered = false
    @State private var scrollViewHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    
    private var effectiveUsername: String {
        userId == tweetData.user?.id ? tweetData.user?.username ?? "" : username
    }
    
    private var isAuthenticatedUser: Bool {
        userId == tweetData.user?.id
    }
    
    private var currentState: UserPostsState {
        isAuthenticatedUser ? spacesViewModel.authenticatedUserPosts :
        spacesViewModel.otherUserPosts[effectiveUsername] ?? UserPostsState()
    }
    
    private var posts: [AudioConversation] {
        currentState.posts
    }
    
    private var isLoading: Bool {
        currentState.isLoading
    }
    
    private var hasMoreData: Bool {
        currentState.pagination.hasMoreData
    }
    
    private var canLoadPrevious: Bool {
        currentState.pagination.hasPreviousData && !currentState.pagination.isLoading
    }
    
    private var canLoadMore: Bool {
        currentState.pagination.hasMoreData && !currentState.pagination.isLoading
    }
    
    private var shouldShowPaginationIndicators: Bool {
        canLoadPrevious || canLoadMore
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Audio Conversations")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .padding(.horizontal)
            
            if posts.isEmpty && !isLoading {
                // Empty state
                emptyStateView
            } else if posts.isEmpty && isLoading {
                // Modern Instagram-style loading - only show when loading and no posts yet
                VStack(spacing: 24) {
                    // Pulsing loading indicator
                    ZStack {
                        // Outer pulsing circle
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 60, height: 60)
                            .scaleEffect(animateLoading ? 1.2 : 0.8)
                            .opacity(animateLoading ? 0 : 1)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                                value: animateLoading
                            )
                        
                        // Inner pulsing circle
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            .frame(width: 40, height: 40)
                            .scaleEffect(animateLoading ? 1.4 : 0.6)
                            .opacity(animateLoading ? 0 : 1)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(0.3),
                                value: animateLoading
                            )
                        
                        // Center icon
                        Image(systemName: "waveform")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Skeleton post preview
                    VStack(spacing: 16) {
                        // Post header skeleton
                        HStack(spacing: 12) {
                            // Avatar skeleton
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 14)
                                    .frame(width: 120)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 12)
                                    .frame(width: 80)
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                        }
                        
                        // Post content skeleton
                        VStack(spacing: 8) {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 18)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    animateLoading = true
                }
            } else {
                // Instagram-style feed with clean scroll detection
                    VStack(spacing: 16) {
                        // Load previous trigger (at top) - Modern minimal design
                        if canLoadPrevious {
                            HStack {
                                Spacer()
                                if isLoading {
                                    // Modern pulsing loading indicator
                                    ZStack {
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                            .frame(width: 24, height: 24)
                                            .scaleEffect(animateLoading ? 1.2 : 0.8)
                                            .opacity(animateLoading ? 0 : 1)
                                            .animation(
                                                .easeInOut(duration: 1.2)
                                                .repeatForever(autoreverses: false),
                                                value: animateLoading
                                            )
                                        
                                        Circle()
                                            .stroke(Color.white.opacity(0.6), lineWidth: 2)
                                            .frame(width: 16, height: 16)
                                            .scaleEffect(animateLoading ? 1.4 : 0.6)
                                            .opacity(animateLoading ? 0 : 1)
                                            .animation(
                                                .easeInOut(duration: 1.2)
                                                .repeatForever(autoreverses: false)
                                                .delay(0.3),
                                                value: animateLoading
                                            )
                                    }
                                } else {
                                    // Minimal arrow indicator
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                        .scaleEffect(animateLoading ? 1.1 : 1.0)
                                        .animation(.easeInOut(duration: 0.3), value: animateLoading)
                                }
                                Spacer()
                            }
                            .frame(height: 40)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(20)
                            .id("load-previous-trigger")
                            .onAppear {
                                animateLoading = true
                            }
                        }
                        
                        // Show all posts with target post highlighted
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            AudioPostCard(post: post)
                                .frame(height: 300)
                                .id(post.id)
                                .overlay(
                                    HighlightedPostBorder(isHighlighted: targetPostId == post.id)
                                )
                                .padding(.bottom, 16) // ✅ SIMPLIFIED: Fixed spacing between posts
                        }
                        

                        
                        // Load more trigger (at bottom) - Modern minimal design
                        if canLoadMore {
                            HStack {
                                Spacer()
                                if isLoading {
                                    // Modern pulsing loading indicator
                                    ZStack {
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                            .frame(width: 24, height: 24)
                                            .scaleEffect(animateLoading ? 1.2 : 0.8)
                                            .opacity(animateLoading ? 0 : 1)
                                            .animation(
                                                .easeInOut(duration: 1.2)
                                                .repeatForever(autoreverses: false),
                                                value: animateLoading
                                            )
                                        
                                        Circle()
                                            .stroke(Color.white.opacity(0.6), lineWidth: 2)
                                            .frame(width: 16, height: 16)
                                            .scaleEffect(animateLoading ? 1.4 : 0.6)
                                            .opacity(animateLoading ? 0 : 1)
                                            .animation(
                                                .easeInOut(duration: 1.2)
                                                .repeatForever(autoreverses: false)
                                                .delay(0.3),
                                                value: animateLoading
                                            )
                                    }
                                } else {
                                    // Minimal arrow indicator
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                        .scaleEffect(animateLoading ? 1.1 : 1.0)
                                        .animation(.easeInOut(duration: 0.3), value: animateLoading)
                                }
                                Spacer()
                            }
                            .frame(height: 40)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(20)
                            .id("load-more-trigger")
                            .onAppear {
                                animateLoading = true
                            }
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: posts) { newPosts in
                        // Handle posts updates
                        handlePostsUpdate()
                        
                        // Handle audio state when posts change
                        handlePostsAudioStateChange(newPosts: newPosts)
                    }
                .background(
                    // Instagram-style scroll tracking - clean and reliable
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                scrollViewHeight = geometry.size.height
                                scrollOffset = geometry.frame(in: .global).minY
                            }
                            .onChange(of: geometry.frame(in: .global).minY) { newValue in
                                scrollOffset = newValue
                                contentHeight = geometry.size.height
                                
                                // Instagram-style pagination triggers
                                handleScrollPagination()
                            }
                    }
                )
            }
        }
        .onAppear {
            print("📱 [UI] UserPostsSection onAppear - userId: \(userId)")
            
            // Prevent multiple loads
            guard !didLoadPosts else {
                print("📱 [UI] Posts already loaded for userId: \(userId), skipping...")
                return
            }
            
            print("📱 [UI] Loading posts for user: \(effectiveUsername)")
            
            // ✅ FIXED: Check if we already have posts data before making API call
            let currentState = isAuthenticatedUser ? spacesViewModel.authenticatedUserPosts : spacesViewModel.otherUserPosts[effectiveUsername] ?? UserPostsState()
            
            // Determine which page to load based on whether we have a target post
            let pageToLoad = targetPostLocation?.page ?? 1
            print("📱 [UI] Loading posts from page: \(pageToLoad)")
            
            // ✅ FIXED: Only force refresh if we don't have data
            // For targeted page loads, we'll let loadUserPosts handle the logic
            let shouldForceRefresh = currentState.posts.isEmpty
            
            Task {
                await spacesViewModel.loadUserPosts(
                    username: effectiveUsername,
                    page: pageToLoad,
                    forceRefresh: shouldForceRefresh
                )
                didLoadPosts = true
            }
        }
        .onDisappear {
            print("📱 [UI] UserPostsSection onDisappear - userId: \(userId)")
            
            // Reset local state to allow fresh load on next appear
            didLoadPosts = false
            isTargetPostReady = false
            targetPostIndex = nil
            animateLoading = false
            
            // Clear posts state for this specific user to prevent conflicts
          /*  spacesViewModel.clearUserPosts(username: effectiveUsername)
            */
            // ✅ FIXED: Don't cleanup audio manager here - let it be managed centrally
            // audioManager.cleanup() // REMOVED - causes infinite loop
        }

    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.5))
            Text("No audio conversations yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    

    
    private func loadMorePosts() {
        
        guard !currentState.pagination.isLoading && canLoadMore else {
            print("❌ [UI] Cannot load more posts - guard failed")
            isPaginationTriggered = false // Reset flag
            return
        }
        
        print("✅ [UI] Loading more posts...")
        Task { @MainActor in
            await spacesViewModel.loadMorePosts(username: effectiveUsername)
            // Reset flag after pagination completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isPaginationTriggered = false
            }
        }
    }
    
    private func loadPreviousPosts() {
        print("📱 [UI] loadPreviousPosts triggered")
        print("📱 [UI] Current pagination - currentPage: \(currentState.pagination.currentPage), canLoadPrevious: \(canLoadPrevious)")
        
        guard !currentState.pagination.isLoading && canLoadPrevious else {
            print("❌ [UI] Cannot load previous posts - guard failed")
            isPaginationTriggered = false // Reset flag
            return
        }
        
        print("✅ [UI] Loading previous posts...")
        Task { @MainActor in
            await spacesViewModel.loadPreviousPosts(username: effectiveUsername)
            // Reset flag after pagination completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isPaginationTriggered = false
            }
        }
    }
    
    // Instagram-style scroll pagination handler
    private func handleScrollPagination() {
        // Prevent too frequent checks
        let now = Date()
        guard now.timeIntervalSince(lastScrollCheck) > 0.3 && !isPaginationTriggered else {
            return
        }
        lastScrollCheck = now
        
    
        
        // Instagram-style: Trigger load previous when near top (first 20% of content)
        if canLoadPrevious && !currentState.pagination.isLoading {
            let topThreshold = contentHeight * 0.2
            if scrollOffset > -topThreshold {
                print("📱 [SCROLL] ✅ TRIGGERING LOAD PREVIOUS - near top")
                isPaginationTriggered = true
                withAnimation(.easeInOut(duration: 0.3)) {
                    animateLoading = true
                }
                loadPreviousPosts()
                return
            }
        }
        
        // Instagram-style: Trigger load more when near bottom (last 20% of content)
        if canLoadMore && !currentState.pagination.isLoading {
            let bottomThreshold = contentHeight * 0.8
            let screenBottom = UIScreen.main.bounds.height
            if scrollOffset < -(bottomThreshold - screenBottom) {
                print("📱 [SCROLL] ✅ TRIGGERING LOAD MORE - near bottom")
                isPaginationTriggered = true
                withAnimation(.easeInOut(duration: 0.3)) {
                    animateLoading = true
                }
                loadMorePosts()
                return
            }
        }
      
    }
    
    private func handlePostsUpdate() {
        // Guard against unnecessary updates
        guard !posts.isEmpty || targetPostId != nil else { return }
       
        // Update target post index when posts change
        if let targetId = targetPostId {
            targetPostIndex = posts.firstIndex { $0.id == targetId }
            print("📱 [UI] Target post index: \(targetPostIndex ?? -1)")
            
            if targetPostIndex != nil {
                // Mark as ready after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isTargetPostReady = true
                }
            }
        } else {
            // No target post - show content immediately
            isTargetPostReady = true
        }
    }
    
    private func handlePostsAudioStateChange(newPosts: [AudioConversation]) {
        if audioManager.isPlaying {
            let currentPlayingId = audioManager.playingConversationId
            let isCurrentPostStillInList = currentPlayingId != nil && newPosts.contains { $0.id == currentPlayingId }
            
            if !isCurrentPostStillInList {
                print("🎵 Stop - post not in list")
                audioManager.pause()
            }
        }
        
        // Profile posts: Use cache-aware preparation for better performance
        // Note: Profile posts don't need preloading logic like feeds do
        // We only prepare the first 3 posts to avoid excessive preparation
        // and rely on SAPlayer's built-in caching for previously listened content
        let postsToPrepare = Array(newPosts.prefix(3))
        for post in postsToPrepare {
            if !audioManager.isPreparedForConversation(post.id) {
                print("🎧 [PROFILE] Cache-aware preparation for post \(post.id)")
                audioManager.prepareAudioWithCachePriority(post)
            }
        }
    }
}

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}



// MARK: - Supporting Types

struct AudioPostCard: View {
    // MARK: - Properties
    let post: AudioConversation
    // Use EnvironmentObject for proper dependency injection
    @EnvironmentObject var audioManager: WebMAudioPlaybackManager
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    
    init(post: AudioConversation) {
        self.post = post
    }
    
    // ✅ SIMPLIFIED: State for UI overlay - only what's needed
    @State private var showPlayOverlay = false
    @State private var showSeekIndicator = false
    @State private var seekProgress: Double = 0
    
    // ✅ SIMPLIFIED: Seek indicator logic
    private var shouldShowSeekIndicator: Bool {
        return showSeekIndicator && audioManager.isCurrentlyPlaying(post.id)
    }
    
    // MARK: - Main View
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            speakersSection
            footerSection
        }
        .background(postBackground)
        .overlay(playbackOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
        .contentShape(Rectangle())
        .onTapGesture {
            print("🎵 Tap post \(post.id)")
            togglePlayback()
        }
        .onAppear {
            if !audioManager.isPreparedForConversation(post.id) {
                print("🎧 [PROFILE] Cache-aware preparation for post \(post.id)")
                audioManager.prepareAudioWithCachePriority(post)
            }
        }
        .onDisappear {
            if audioManager.isCurrentlyPlaying(post.id) {
                audioManager.pause()
            }
            
            // Reset seek indicator when post disappears
            if showSeekIndicator {
                showSeekIndicator = false
            }
        }
        .onChange(of: post.id) { newPostId in
            // Hide overlay when post changes to prevent stale overlays
            if showPlayOverlay {
                withAnimation(.easeOut(duration: 0.2)) {
                    showPlayOverlay = false
                }
            }
            
            // Reset seek indicator when post changes
            if showSeekIndicator {
                withAnimation(.easeOut(duration: 0.2)) {
                    showSeekIndicator = false
                }
            }
            
            
            if audioManager.isCurrentlyPlaying(post.id) && post.id != newPostId {
                audioManager.switchToConversation(post)
            } else if !audioManager.isPreparedForConversation(newPostId) {
                audioManager.prepareAudioWithCachePriority(post)
            }
        }
        .id(post.id)
        .onChange(of: audioManager.isCurrentlyPlaying(post.id)) { isPlaying in
            // Reset seek indicator when audio stops playing
            if !isPlaying && showSeekIndicator {
                withAnimation(.easeOut(duration: 0.2)) {
                    showSeekIndicator = false
                }
            }
        }

    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            locationSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var speakersSection: some View {
        GeometryReader { geometry in
            HStack(spacing: geometry.size.width * 0.1) {
                Spacer()
                speakerView(for: .host, geometry: geometry)
                speakerView(for: .visitor, geometry: geometry)
                Spacer()
            }
            .padding(.vertical, geometry.size.height * 0.05)
        }
        .frame(height: 160)
    }
    

    
    private var footerSection: some View {
        VStack(spacing: 4) {
            // Enhanced Progress bar with larger touch area
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track (always visible)
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 3)
                    
                    // Progress bar - show progress for prepared conversations
                    Rectangle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: geometry.size.width * CGFloat(getProgressForPost()), height: 3)
                        .onAppear {
                            // Debug logging for progress calculation
                            let progress = getProgressForPost()
                            if progress > 0 {
                                print("🎵 [UI] Progress bar for post \(post.id) - progress: \(progress * 100)%")
                            }
                        }
                    
                    // Seek preview (ONLY when dragging - fixed visibility issue)
                    if shouldShowSeekIndicator {
                        Rectangle()
                            .fill(Color.blue.opacity(0.9))
                            .frame(width: geometry.size.width * CGFloat(seekProgress), height: 3)
                            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: seekProgress)
                    }
                    
                    // Seek handle (ONLY when dragging - fixed visibility issue)
                    if shouldShowSeekIndicator {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .offset(x: max(0, min(geometry.size.width * CGFloat(seekProgress) - 6, geometry.size.width - 12)))
                            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: seekProgress)
                            .shadow(color: .blue.opacity(0.6), radius: 3, x: 0, y: 2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 2) // More sensitive for better touch detection
                        .onChanged { value in
                            // ✅ FIXED: Ensure post is prepared before allowing seeking
                            guard audioManager.isPreparedForConversation(post.id) else { return }
                            
                            // ✅ FIXED: Calculate seek progress based on full slider width
                            // This ensures the entire slider width corresponds to the full duration of this specific post
                            let dragLocation = value.location.x
                            let sliderWidth = geometry.size.width
                            let clampedLocation = max(0, min(dragLocation, sliderWidth))
                            let newProgress = clampedLocation / sliderWidth
                            
                            // Update seek state for visual feedback
                            self.seekProgress = newProgress
                            
                            // Show seek indicator if not already showing
                            if !self.showSeekIndicator {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    self.showSeekIndicator = true
                                }
                                // Haptic feedback when seeking starts
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        }
                        .onEnded { value in
                            // ✅ FIXED: Ensure post is prepared before allowing seeking
                            guard audioManager.isPreparedForConversation(post.id) else { return }
                            
                            // ✅ FIXED: Calculate final seek progress based on full slider width
                            // This ensures seeking works correctly for posts of any duration
                            let dragLocation = value.location.x
                            let sliderWidth = geometry.size.width
                            let clampedLocation = max(0, min(dragLocation, sliderWidth))
                            let finalProgress = clampedLocation / sliderWidth
                            
                            print("🎵 [SEEK] Post \(post.id) - seeking to \(finalProgress * 100)% of full duration")
                            
                            // ✅ FIXED: Simplified seeking logic - no delays
                            if !audioManager.isCurrentlyPlaying(post.id) {
                                print("🎵 Seeking and starting playback for \(post.id) at \(finalProgress * 100)%")
                                audioManager.seek(to: finalProgress)
                                audioManager.play() // Play immediately after seek
                            } else {
                                print("🎵 Seeking for currently playing \(post.id) to \(finalProgress * 100)%")
                                audioManager.seek(to: finalProgress)
                            }
                            
                            // Haptic feedback when seeking completes
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            // Hide seek indicator with animation
                            withAnimation(.easeOut(duration: 0.2)) {
                                self.showSeekIndicator = false
                            }
                        }
                )
            }
            .frame(height: 44) // ✅ SIGNIFICANTLY INCREASED touch area from 8px to 44px
            
            // Time display - same as TikTokStyleAudioPostCard
            HStack {
                Text(formatTime(audioManager.currentTime))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Optional: Add subtle visual indicator for touch area (only when not dragging)
            if !shouldShowSeekIndicator {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12) // ✅ INCREASED vertical padding for better touch area
    }
    
    // MARK: - Helper Views
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Instagram-style location display
            if hasLocationData {
                HStack(spacing: 8) {
                    // Location pin icon
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        // Primary location (city, state or name)
                        Text(primaryLocationText)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        // Secondary location (address or country)
                        if let secondaryText = secondaryLocationText {
                            Text(secondaryText)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                }
            } else {
                // Fallback to topic if no location data
                HStack(spacing: 8) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text(post.topic.isEmpty ? "Audio Conversation" : post.topic)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.8),
                            Color.black.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
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
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Location Helper Properties
    
    private var hasLocationData: Bool {
        return post.location_name != nil || 
               post.location_city != nil || 
               post.location_address != nil ||
               post.location_country != nil
    }
    
    private var primaryLocationText: String {
        // Priority: location_name > city > address > country
        if let locationName = post.location_name, !locationName.isEmpty {
            return locationName
        } else if let city = post.location_city, !city.isEmpty {
            return city
        } else if let address = post.location_address, !address.isEmpty {
            return address
        } else if let country = post.location_country, !country.isEmpty {
            return country
        }
        return "Unknown Location"
    }
    
    private var secondaryLocationText: String? {
        // Show additional location details
        var components: [String] = []
        
        if let city = post.location_city, !city.isEmpty, post.location_name != city {
            components.append(city)
        }
        
        if let state = post.location_state, !state.isEmpty {
            components.append(state)
        }
        
        if let country = post.location_country, !country.isEmpty, post.location_name != country {
            components.append(country)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    // Removed timeDisplay - focusing on TikTok-style seeking only
    
    @ViewBuilder
    private func speakerView(for type: SpeakerType, geometry: GeometryProxy) -> some View {
        let speaker = type == .host ?
            (name: post.host_name ?? "Host", image: post.host_image) :
            (name: post.user_name ?? "Guest", image: post.user_image)
        
        // ✅ UPDATED: Pass speaker type, post ID, and speaker IDs for active speaker detection
        SpeakerView(
            name: speaker.name,
            image: speaker.image,
            speakerType: type, // ✅ Pass speaker type
            postId: post.id,   // ✅ Pass post ID for audio manager lookup
            hostId: post.host_id ?? 0, // ✅ Pass host ID for active speaker detection
            userId: post.user_id ?? 0, // ✅ Pass user ID for active speaker detection
            size: min(geometry.size.width * 0.2, 100)
        )
        .frame(width: geometry.size.width * 0.25)
    }
    
    private var postBackground: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.95),
                Color.black.opacity(0.9)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
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
    
    @ViewBuilder
    private var playbackOverlay: some View {
        if showPlayOverlay {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Play/Pause icon - show what will happen when tapped
                // If currently playing, show pause icon (what will happen when tapped)
                // If not playing, show play icon (what will happen when tapped)
                let iconName = audioManager.isCurrentlyPlaying(post.id) ? "pause.circle.fill" : "play.circle.fill"
                Image(systemName: iconName)
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .transition(.opacity.combined(with: .scale))
        }
    }
    
    // MARK: - Helper Methods
    
    /**
     Gets the progress for this post from the centralized audio manager.
     The audio manager handles all progress calculation logic.
     */
    private func getProgressForPost() -> Double {
        // ✅ SIMPLIFIED: Just access the centralized progress from audio manager
        // All progress calculation logic is now handled in the audio manager
        return audioManager.getProgressForConversation(post.id)
    }
    
    // MARK: - Audio Playback
    

    

    
    private func togglePlayback() {
        print("🎵 Toggle \(post.id)")
        
        let hasHostAudio = post.host_audio_url != nil && !post.host_audio_url!.isEmpty
        let hasVisitorAudio = post.visitor_audio_url != nil && !post.visitor_audio_url!.isEmpty
        let hasAudio = hasHostAudio || hasVisitorAudio
        
        guard hasAudio else {
            print("❌ No audio for \(post.id)")
            return
        }
        
        guard !spacesViewModel.isAudioSessionBlocked else {
            print("🔇 Audio blocked")
            return
        }
        
        // Show overlay immediately
        withAnimation(.spring(response: 0.3)) {
            showPlayOverlay = true
        }
        
        // Schedule overlay to disappear after a consistent delay
        scheduleOverlayHide()
        
        // ✅ SIMPLIFIED: Use existing manager methods
        if audioManager.isCurrentlyPlaying(post.id) {
            print("⏸️ Pausing \(post.id)")
            audioManager.pause()
        } else {
            print("▶️ Playing \(post.id)")
            
            // Check if we need to prepare first
            if !audioManager.isPreparedForConversation(post.id) {
                print("⚠️ [PROFILE] Not prepared for \(post.id), preparing first...")
                audioManager.prepareAudioWithCachePriority(post)
            } else {
                // ✅ FIXED: Simplified logic - just play directly
                // The SAPlayerDualAudio engine now handles completion and rescheduling automatically
                print("✅ [PROFILE] Already prepared for \(post.id), playing directly")
                audioManager.play()
            }
        }
    }
    

    

    
    private func isSpeaking(type: SpeakerType) -> Bool {
        // Only show speaking animation if this post is currently playing
        guard audioManager.isCurrentlyPlaying(post.id) else {
            return false
        }
        
        let audioLevel = type == .host ? audioManager.hostAudioLevel : audioManager.visitorAudioLevel
        // ✅ FIXED: Adjusted thresholds for WebM audio (WebM typically has lower levels than live audio)
        let speakingThreshold: Float = 0.05  // Lower threshold for WebM
        let bothSpeakersThreshold: Float = 0.08  // Lower threshold for both speakers
        
        // ✅ FIXED: Get speaker ID in the correct format
        let speakerId = type == .host ? Int64(post.host_id ?? 0) : Int64(post.user_id ?? 0)
        let activeSpeakerId = audioManager.activeSpeakerId
        let bothSpeakersActive = audioManager.bothSpeakersActive
        
        // ✅ DEBUG: Log audio levels for troubleshooting
        if audioLevel > 0.01 { // Only log when there's actual audio activity
            print("🎵 [SPEAKING] Post \(post.id) - Type: \(type), Level: \(audioLevel), Threshold: \(speakingThreshold)")
            print("🎵 [SPEAKING] Speaker ID: \(speakerId), Active Speaker ID: \(activeSpeakerId ?? 0)")
            print("🎵 [SPEAKING] Both Speakers Active: \(bothSpeakersActive)")
        }
        
        if bothSpeakersActive {
            // Both speakers are active - use higher threshold
            return audioLevel > bothSpeakersThreshold
        } else {
            // Single speaker active - check if this is the active speaker
            let isActiveSpeaker = activeSpeakerId == speakerId
            let isAboveThreshold = audioLevel > speakingThreshold
            
            // ✅ FIXED: More robust active speaker detection
            if isActiveSpeaker && isAboveThreshold {
                return true
            } else if !isActiveSpeaker && audioLevel > speakingThreshold * 0.5 {
                // Show some activity even for non-active speakers if they have audio
                return true
            }
            return false
        }
    }
    
    // Removed formatTime function - no longer needed
    
    /**
     Schedules the overlay to hide after a consistent delay.
     This ensures overlay timing is consistent across all interactions.
     */
    private func scheduleOverlayHide() {
        // Cancel any existing timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                showPlayOverlay = false
            }
        }
    }
    
    /**
     Formats time in MM:SS format for display.
     */
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SpeakerView: View {
    let name: String
    let image: String?
    let speakerType: SpeakerType
    let postId: Int64
    let hostId: Int64
    let userId: Int64
    let size: CGFloat
    
    // ✅ CRITICAL: Direct access to audio manager for reactive updates
    @EnvironmentObject var audioManager: WebMAudioPlaybackManager
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar with speaking indicator
            ZStack {
                // Avatar
                if let imageUrl = image {
                    CachedAsyncImage(url: imageUrl.safeURL()) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioManager.hostAudioLevel)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioManager.visitorAudioLevel)
                        case .failure:
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFill()
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioManager.hostAudioLevel)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioManager.visitorAudioLevel)
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // ✅ UPDATED: Use same beautiful default avatar design as Spaces views
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: size * 0.5, height: size * 0.5)
                            .foregroundColor(.white)
                    }
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .shadow(radius: 3)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioManager.hostAudioLevel)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioManager.visitorAudioLevel)
                }
                
                // Speaking indicator ring
                if audioManager.isCurrentlyPlaying(postId) &&
                   (speakerType == .host ? audioManager.hostAudioLevel : audioManager.visitorAudioLevel) > 0.01 &&
                   audioManager.activeSpeakerId == (speakerType == .host ? hostId : userId) {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: size + 10, height: size + 10)
                        .scaleEffect(1.05)
                        .opacity(1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: speakerType == .host ? audioManager.hostAudioLevel : audioManager.visitorAudioLevel)
                }
            }
            
            // Name with speaking indicator
            Text(name)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: size * 1.5)
                .opacity(
                    audioManager.isCurrentlyPlaying(postId) &&
                    (speakerType == .host ? audioManager.hostAudioLevel : audioManager.visitorAudioLevel) > 0.01 &&
                    audioManager.activeSpeakerId == (speakerType == .host ? hostId : userId)
                    ? 1 : 0.7
                )
                .animation(.easeInOut(duration: 0.2), value: speakerType == .host ? audioManager.hostAudioLevel : audioManager.visitorAudioLevel)
            
            // Audio wave animation
            if audioManager.isCurrentlyPlaying(postId) {
                let audioLevel = speakerType == .host ? audioManager.hostAudioLevel : audioManager.visitorAudioLevel
                let speakerId = speakerType == .host ? hostId : userId
                let isActiveSpeaker = audioManager.activeSpeakerId == speakerId
                
                // Only show animation for the ACTIVE speaker
                if isActiveSpeaker && audioLevel > 0.01 {
                    AudioDetectionAnimation(
                        audioLevel: audioLevel,
                        progress: 0.5
                    )
                    .frame(height: 13)
                    .opacity(1)
                    .animation(.easeInOut(duration: 0.2), value: audioLevel)
                }
            }
        }
    }
}

// MARK: - Supporting Types
enum SpeakerType {
    case host, visitor
}

// MARK: - Audio Visualizer Component
struct AudioVisualizerView: View {
    let isPlaying: Bool
    let progress: Double
    @Binding var showControls: Bool
    @Binding var isScrubbing: Bool
    @Binding var dragProgress: Double
    let onSeek: () -> Void
    let onPlayPause: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                
                // Audio visualization bars
                HStack(spacing: 2) {
                    ForEach(0..<20) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(isPlaying ? 0.7 : 0.3),
                                        .white.opacity(isPlaying ? 0.4 : 0.1)
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 2, height: isPlaying ? CGFloat.random(in: 10...30) : 15)
                            .animation(
                                .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.05),
                                value: isPlaying
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            let newProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                            withAnimation(.interactiveSpring()) {
                                isScrubbing = true
                                dragProgress = newProgress
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut) {
                                isScrubbing = false
                                onSeek()
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            onPlayPause()
                        }
                )
                
                // Progress indicator
                if showControls || isScrubbing {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 2)
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: geometry.size.width * CGFloat(isScrubbing ? dragProgress : progress))
                                .frame(height: 2),
                            alignment: .leading
                        )
                        .overlay(
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 8, height: 8)
                                .offset(x: geometry.size.width * CGFloat(isScrubbing ? dragProgress : progress) - 4),
                            alignment: .leading
                        )
                        .position(x: geometry.size.width / 2, y: geometry.size.height - 8)
                }
            }
        }
    }
}

// MARK: - Reaction Detail View
struct ReactionDetailView: View {
    let userId: Int64
    let isCurrentUser: Bool
    @Binding var profileSheetCoordinator: ProfileSheetCoordinator
    
    @EnvironmentObject var tweetData: TweetData
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTabIndex = 0
    @State private var animateAppearance = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSpacesSheet = false
    

    private var floatingIndicator: some View {
    VStack {
        Spacer()
        
        // ✅ NATIVE SHEET: Make entire floating indicator tappable
        Button(action: {
            showSpacesSheet = true
        }) {
            HStack {
                HStack(spacing: 12) {
                    // Live indicator
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: spacesViewModel.isInSpace)
                    
                    // Call info
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Space")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Tap to return")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // ✅ FIXED: Arrow icon is now just visual, not a separate button
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.9), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
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
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Above tab bar
        }
        .buttonStyle(PlainButtonStyle()) // ✅ ADDED: Prevents default button styling
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: spacesViewModel.isInSpace)
        .zIndex(999)
    }
}

    // Get user profile for reaction counts
    private var userProfile: UserProfile? {
        if isCurrentUser {
            return tweetData.user
        } else {
            return tweetData.otherUsers[userId]
        }
    }
    
    // Get reaction types with counts
    private var reactionTypesWithCounts: [ReactionType] {
        guard let profile = userProfile,
              let reactionCounts = profile.reactionCounts else {
            print("🔄 [DETAIL] No profile or reactionCounts available")
            return []
        }
        
        let types = reactionCounts.compactMap { (reactionTypeId: Int64, count: Int) -> ReactionType? in
            guard count > 0 else { return nil }
            return ReactionType.staticReactions.first { $0.id == reactionTypeId }
        }.sorted { reactionCounts[$0.id] ?? 0 > reactionCounts[$1.id] ?? 0 } // ✅ Sort by count (descending)
        
        print("🔄 [DETAIL] reactionTypesWithCounts - count: \(types.count), types: \(types.map { "\($0.name)(\($0.id))" })")
        return types
    }
    
    // ✅ REMOVED: getReactionState method moved to ReactionUsersListView
    // Each list view manages its own reaction state for better encapsulation
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Tabs
                if !reactionTypesWithCounts.isEmpty {
                    tabSection
                    
                    // Content
                    TabView(selection: $selectedTabIndex) {
                        ForEach(Array(reactionTypesWithCounts.enumerated()), id: \.element.id) { index, reactionType in
                            ReactionUsersListView(
                                userId: userId,
                                reactionType: reactionType,
                                isCurrentUser: isCurrentUser,
                                isActiveTab: selectedTabIndex == index, // ✅ Pass active tab state
                                profileSheetCoordinator: profileSheetCoordinator
                            )
                            .tag(index)
                        }
                    }
                    .onChange(of: selectedTabIndex) { newValue in
                        print("🔄 [TABVIEW] TabView selection changed to: \(newValue)")
                    }
                    .animation(.easeInOut(duration: 0.3), value: selectedTabIndex)
                } else {
                    emptyStateView
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
            .navigationBarHidden(true) // ✅ FIXED: Hide navigation bar to keep tabs visible during profile navigation
        }
        .onAppear {
            // ✅ SIMPLIFIED: Only handle appearance animations
            // Data loading is handled by individual ReactionUsersListView instances
            print("🔄 [DETAIL] ReactionDetailView onAppear - selectedTabIndex: \(selectedTabIndex)")
            
            // ✅ FIXED: Ensure selectedTabIndex is properly initialized
            if selectedTabIndex >= reactionTypesWithCounts.count && !reactionTypesWithCounts.isEmpty {
                selectedTabIndex = 0
                print("🔄 [DETAIL] Fixed initial selectedTabIndex to 0")
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateAppearance = true
            }
        }
        .onChange(of: selectedTabIndex) { newValue in
            print("🔄 [TAB] selectedTabIndex changed to: \(newValue)")
        }
        // ✅ REMOVED: onChange(of: reactionTypesWithCounts) - this was causing the bug!
        // The computed property was being recalculated on every view update,
        // which triggered the onChange and reset selectedTabIndex incorrectly
        .onDisappear {
            // ✅ ADDED: Cleanup animation state when view disappears
            animateAppearance = false
            print("🔄 [DETAIL] Cleanup animation state on disappear")
        }
        .alert("Error", isPresented: $showError) {
            Button("Retry") {
                // ✅ FIXED: No action needed here since ReactionUsersListView handles its own retry
                // The error will be handled by the individual list views
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        // ✅ DIRECT: Profile navigation with coordinator in ReactionDetailView
        .fullScreenCover(isPresented: $profileSheetCoordinator.isPresented) {
            if let profile = profileSheetCoordinator.activeProfile {
                TwitterProfileView(
                    userId: profile.userId,
                    username: profile.username,
                    initialProfile: nil
                )
                .environmentObject(tweetData)
                .interactiveDismissDisabled()
            }
        }
        .overlay {
            // ✅ FLOATING INDICATOR: Appears above ALL views including fullscreen covers
            if spacesViewModel.isInSpace && spacesViewModel.isHost {
               floatingIndicator
                    .zIndex(99999) // Higher than any presentation layer
            }
        }
        .sheet(isPresented: $showSpacesSheet) {
            // ✅ LOCAL SHEET: Uses local state for proper context handling
            SpacesListeningNowView(showConfirmationModal: .constant(false))
                .environmentObject(spacesViewModel)
                .environmentObject(tweetData)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Modern Navigation bar with glass effect
            HStack {
                Button(action: {
                    dismiss()
                }) {
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
                    Text("Reactions")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Received from others")
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
            
            // Modern User info card
            if let profile = userProfile {
                HStack(spacing: 20) {
                    // Enhanced Avatar with gradient border
                    ZStack {
                        // Gradient background circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                        
                        CachedAsyncImage(url: profile.avatar.safeURL()) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 64, height: 64)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                            case .failure:
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 64, height: 64)
                                    .foregroundColor(.gray)
                            case .empty:
                                ProgressView()
                                    .frame(width: 64, height: 64)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.nickname)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .primary.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("@\(profile.username)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        if let reactionCounts = profile.reactionCounts {
                            let totalReactions = reactionCounts.values.reduce(0, +)
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.red)
                                
                                Text("\(totalReactions.formattedCount) total reactions")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                )
                .padding(.horizontal, 20)
                .scaleEffect(animateAppearance ? 1 : 0.9)
                .opacity(animateAppearance ? 1 : 0)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Tab Section
    private var tabSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(reactionTypesWithCounts.enumerated()), id: \.element.id) { index, reactionType in
                    let isSelected = selectedTabIndex == index
                    let count = userProfile?.getReactionCount(for: reactionType.id) ?? 0
                    
                    // Debug print for tab selection
                    let _ = print("🔄 [TAB] tabSection - index: \(index), reactionType: \(reactionType.name), isSelected: \(isSelected), selectedTabIndex: \(selectedTabIndex), totalTabs: \(reactionTypesWithCounts.count)")
                    
                    ModernReactionTabButton(
                        reactionType: reactionType,
                        isSelected: isSelected,
                        count: count
                    ) {
                        print("🔄 [TAB] Tab tapped - index: \(index), reactionType: \(reactionType.name)")
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedTabIndex = index
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground).opacity(0.95),
                    Color(.systemGray6).opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.2)),
            alignment: .bottom
        )
    }



    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Modern Icon with animation
            ZStack {
                // Outer pulsing circle
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateAppearance ? 1.2 : 1.0)
                    .opacity(animateAppearance ? 0 : 0.6)
                    .animation(
                        .easeInOut(duration: 2)
                        .repeatForever(autoreverses: false),
                        value: animateAppearance
                    )
                
                // Inner gradient circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                
                Image(systemName: "heart.slash")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No Reactions Yet")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("When people react to your conversations, you'll see them here")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .scaleEffect(animateAppearance ? 1 : 0.9)
        .opacity(animateAppearance ? 1 : 0)
    }
    
    // MARK: - Helper Methods
    // ✅ REMOVED: loadInitialData method to prevent duplicate loading
    // All loading is now handled by ReactionUsersListView.loadUsersIfNeeded()
}

// MARK: - Modern Reaction Tab Button
struct ModernReactionTabButton: View {
    let reactionType: ReactionType
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Reaction icon with background
                ZStack {
                    Circle()
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [Color(hex: reactionType.color), Color(hex: reactionType.color).opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(
                            color: isSelected ? Color(hex: reactionType.color).opacity(0.3) : .clear,
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    
                    Text(reactionType.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                // Reaction name and count
                VStack(spacing: 4) {
                    Text(reactionType.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                    
                    // Count with background circle - ALWAYS SHOW COUNT
                    ZStack {
                        Circle()
                            .fill(
                                isSelected ?
                                LinearGradient(
                                    colors: [Color(hex: reactionType.color).opacity(0.2), Color(hex: reactionType.color).opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Text(count.formattedCount)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(isSelected ? Color(hex: reactionType.color) : .secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
                                .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                isSelected ?
                                LinearGradient(
                                    colors: [
                                        Color(hex: reactionType.color).opacity(0.1),
                                        Color(hex: reactionType.color).opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [.clear, .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        isSelected ? Color(hex: reactionType.color).opacity(0.3) : Color.gray.opacity(0.1),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                    )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Debug print to track selection state
            print("🔄 [TAB] ModernReactionTabButton - reactionType: \(reactionType.name), isSelected: \(isSelected), count: \(count), color: \(reactionType.color)")
        }
    }
}



    // MARK: - Reaction Users List View
struct ReactionUsersListView: View {
    let userId: Int64
    let reactionType: ReactionType
    let isCurrentUser: Bool
    let isActiveTab: Bool // ✅ New parameter to track active tab
    let profileSheetCoordinator: ProfileSheetCoordinator
    
    @EnvironmentObject var tweetData: TweetData
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isPaginationTriggered = false
    
    // Get current reaction state
    private var reactionState: PaginationData? {
        if isCurrentUser {
            return tweetData.currentUserReactionState.reactionTypes[reactionType.id]
        } else {
            return tweetData.otherUsersReactionState[userId]?.reactionTypes[reactionType.id]
        }
    }
    
    // ✅ ADDED: Helper to get user profile for reaction count checks
    private var userProfile: UserProfile? {
        if isCurrentUser {
            return tweetData.user
        } else {
            return tweetData.otherUsers[userId]
        }
    }
    
    private var users: [ReactionUserProfile] {
        reactionState?.users ?? []
    }
    
    private var hasMoreData: Bool {
        reactionState?.hasMoreData ?? false
    }
    
    // Single loading state from PaginationData (handles both initial and pagination)
    private var isLoading: Bool {
        reactionState?.isLoading ?? false
    }
    
    // Check if this is initial load (no users yet)
    private var isInitialLoad: Bool {
        users.isEmpty && isLoading
    }
    
    // Check if this is pagination load (has users, loading more)
    private var isPaginationLoad: Bool {
        !users.isEmpty && isLoading
    }
    
    // ✅ ENHANCED: Robust initial load check with better logic
    private var shouldLoadInitialData: Bool {
        // Only load if:
        // 1. We have no users
        // 2. Not already loading
        // 3. Reaction count > 0
        // 4. Either:
        //    a. This is the active tab, or
        //    b. The view just appeared (first load)
        let hasNoUsers = users.isEmpty
        let notLoading = !isLoading
        let hasReactions = (userProfile?.getReactionCount(for: reactionType.id) ?? 0) > 0
        
        return hasNoUsers && notLoading && hasReactions
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(reactionType.icon) \(reactionType.name)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isInitialLoad {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Users List
            if users.isEmpty && !isInitialLoad {
                emptyStateView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Top anchor for scroll control
                            Color.clear
                                .frame(height: 1)
                                .id("top")
                            
                            ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                                ReactionUserRow(user: user, profileSheetCoordinator: profileSheetCoordinator)
                                    .onAppear {
                                        // Trigger load more when the last item appears
                                        if index == users.count - 1 && hasMoreData && !isLoading && !isPaginationTriggered {
                                            print("🔄 [UI] Last item appeared, triggering load more for reaction type: \(reactionType.name)")
                                            isPaginationTriggered = true
                                            loadMoreUsers()
                                        }
                                    }
                            }
                            
                            // Loading indicator at bottom
                            if isPaginationLoad {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Spacer()
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }

                    .onChange(of: isActiveTab) { newValue in
                        if newValue {
                            // ✅ Scroll to top when tab becomes active
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("top", anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            // ✅ ENHANCED: Use robust initial load check
            // This prevents unnecessary reloads and ensures proper loading conditions
            if shouldLoadInitialData {
                loadUsersIfNeeded()
            }
        }
        .onChange(of: isActiveTab) { newValue in
            if newValue {
                // ✅ Reset scroll state when tab becomes active
                resetScrollState()
                print("🔄 [UI] Tab switched to reaction type: \(reactionType.name)")
                
                // ✅ FIXED: Only load if not already loaded (prevents redundant calls)
                // onAppear will handle the loading, so we don't need to call it here
            }
        }
        .onDisappear {
            // ✅ ADDED: Cleanup scroll states when view disappears
            // This prevents memory leaks and ensures clean state for next appearance
            resetScrollState()
        }
        .alert("Error", isPresented: $showError) {
            Button("Retry") {
                // ✅ FIXED: No action needed here since ReactionUsersListView handles its own retry
                // The error will be handled by the individual list views
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Modern reaction-specific empty state
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(reactionType.color).opacity(0.15), Color(reactionType.color).opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(reactionType.color).opacity(0.2), radius: 15, x: 0, y: 8)
                
                Text(reactionType.icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(Color(reactionType.color))
            }
            
            VStack(spacing: 8) {
                Text("No \(reactionType.name) reactions yet")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Be the first to give this reaction!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Methods
    
    /// Reset pagination state when switching tabs
    private func resetScrollState() {
        isPaginationTriggered = false
    }
    
    private func loadUsersIfNeeded() {
        // ✅ SIMPLIFIED: Logic now handled by shouldLoadInitialData
        // This method is only called when we know we should load
        let reactionCount = userProfile?.getReactionCount(for: reactionType.id) ?? 0
        
        print("🔄 [UI] Loading users for reaction type: \(reactionType.name) (count: \(reactionCount))")
        print("🔄 [UI] Loading for user ID: \(userId)")
        Task {
            do {
                // ✅ FIXED: Properly pass userId to loadReactionUsers
                try await tweetData.loadReactionUsers(userId: userId, reactionTypeId: reactionType.id)
            } catch {
                // ✅ ADDED: Handle errors properly
                await MainActor.run {
                    showError = true
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func loadMoreUsers() {
        print("🔄 [UI] Loading more users for reaction type: \(reactionType.name)")
        print("🔄 [UI] Loading more for user ID: \(userId)")
        
        guard !isLoading && hasMoreData else {
            print("ℹ️ [UI] Cannot load more users - guard failed")
            isPaginationTriggered = false // Reset flag
            return
        }
        
        Task {
            do {
                // ✅ FIXED: Properly pass userId to loadMoreReactionUsers
                try await tweetData.loadMoreReactionUsers(userId: userId, reactionTypeId: reactionType.id)
                // Reset flag after pagination completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isPaginationTriggered = false
                }
            } catch {
                // ✅ ADDED: Handle pagination errors
                await MainActor.run {
                    isPaginationTriggered = false
                    showError = true
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    

}



// ✅ ADDED: Sheet Coordinator for Infinite Navigation
class ProfileSheetCoordinator: ObservableObject {
    @Published var activeProfile: (userId: Int64, username: String)? = nil
    @Published var isPresented = false
    
    func presentProfile(userId: Int64, username: String) {
        activeProfile = (userId, username)
        isPresented = true
    }
    
    func dismiss() {
        isPresented = false
        activeProfile = nil
    }
}

// ✅ REMOVED: ReactionDetailSheet - replaced with modern ReactionDetailView


// MARK: - Reaction User Row
struct ReactionUserRow: View {
    let user: ReactionUserProfile
    let profileSheetCoordinator: ProfileSheetCoordinator
    @EnvironmentObject var tweetData: TweetData
    @State private var isFollowing: Bool
    @State private var isLoading = false
    
    init(user: ReactionUserProfile, profileSheetCoordinator: ProfileSheetCoordinator) {
        self.user = user
        self.profileSheetCoordinator = profileSheetCoordinator
        _isFollowing = State(initialValue: user.isFollowing ?? false)
        
        // ✅ ADDED: Log initial isFollowing value from ReactionUserProfile
        print("🔍 [DEBUG] ReactionUserRow init - User ID: \(user.id), Username: \(user.username), isFollowing: \(user.isFollowing?.description ?? "nil"), Initial State: \(user.isFollowing ?? false)")
    }
    
    var body: some View {
        Button {
            profileSheetCoordinator.presentProfile(userId: user.id, username: user.username)
        } label: {
            HStack(spacing: 12) {
                // Avatar
                avatarView
                
                // User info
                userInfoView
                
                Spacer()
                
                // Follow button (if not current user)
                if user.id != TweetData.shared.user?.id {
                    followButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundView)
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: tweetData.otherUsers[user.id]?.isFollowing) { newValue in
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
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(radius: 4)
            case .failure:
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)
            case .empty:
                ProgressView()
                    .frame(width: 50, height: 50)
            @unknown default:
                EmptyView()
            }
        }
    }
    
    private var userInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(user.nickname)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("@\(user.username)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private var followButton: some View {
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
                    
                    // ✅ REMOVED: Redundant state update - followUser/unfollowUser already update otherUsers state
                    // The onChange modifier will automatically pick up the changes
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
                    .scaleEffect(0.8)
            } else {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isFollowing ? .secondary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
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
        RoundedRectangle(cornerRadius: 16)
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



