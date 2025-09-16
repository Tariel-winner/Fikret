import SwiftUI
import PhotosUI
/*
struct UserProfileView: View {
    let userId: String
    @EnvironmentObject var tweetData: TweetData
    @State private var userProfile: UserProfile?
    @State private var isLoading = false
    @State private var showLiveSession = false
    @Environment(\.dismiss) private var dismiss
    @State private var showPhotoPicker = false
    
    private var isCurrentUserProfile: Bool {
        guard let currentUser = tweetData.user else {
            print("❌ DEBUG: Current user is nil")
            return false
        }
        
        print("""
        🔍 DEBUG: User ID Comparison
        Current User ID: \(currentUser.id)
        Profile User ID: \(userId)
        Match: \(String(currentUser.id) == userId)
        """)
        
        return String(currentUser.id) == userId
    }
    
    private enum Design {
        static let headerHeight: CGFloat = 200
        static let avatarSize: CGFloat = 90
        static let avatarOffset: CGFloat = -45
        static let contentPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 5
        
        static let backgroundColor = Color(.systemBackground)
        static let accentColor = Color.blue
        static let secondaryColor = Color(.secondarySystemBackground)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    Spacer()
                }
                
                // Header
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        gradient: Gradient(colors: [.blue.opacity(0.8), .purple.opacity(0.6)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: Design.headerHeight)
                    
                    // Profile Avatar
                    if let user = userProfile {
                        Button {
                            if isCurrentUserProfile {
                                showPhotoPicker = true
                            }
                        } label: {
                            AsyncImage(url: user.avatar.safeURL()) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .padding(20)
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: Design.avatarSize, height: Design.avatarSize)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Design.backgroundColor, lineWidth: 4))
                            .shadow(radius: Design.shadowRadius)
                            .offset(y: Design.avatarOffset)
                            .overlay(
                                isCurrentUserProfile ?
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 30, y: 30)
                                : nil
                            )
                        }
                        .disabled(!isCurrentUserProfile)
                    }
                }
                
                // Profile Info
                if let user = userProfile {
                    VStack(spacing: Design.contentPadding) {
                        // Name and Username
                        VStack(spacing: 4) {
                            Text(user.nickname)
                                .font(.title2.bold())
                            
                            Text("@\(user.username)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, abs(Design.avatarOffset) + Design.contentPadding)
                        
                        // Live Session Button - only visible for profile owner
                        if isCurrentUserProfile {
                            Button {
                                print("🔵 DEBUG: Live button tapped")
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showLiveSession = true
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("Go Live")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                            }
                        }
                        
                        // Follow/Unfollow Button (if not own profile)
                        if !isCurrentUserProfile {
                            Button(action: {
                                Task {
                                    await toggleFollow()
                                }
                            }) {
                                Text(user.isFollowing! ? "Unfollow" : "Follow")
                                    .font(.headline)
                                    .foregroundColor(user.isFollowing! ? .primary : .white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 8)
                                    .background(user.isFollowing! ? Design.secondaryColor : Design.accentColor)
                                    .cornerRadius(20)
                            }
                            .disabled(isLoading)
                        }
                        
                        // Stats Row
                        HStack(spacing: Design.contentPadding * 2) {
                            NavigationLink(destination: UserListModalView(userId: user.id, username: user.username, type: .following)
                                .environmentObject(tweetData)
                                .navigationBarBackButtonHidden(true)) {
                                    ProfileStatsView(count: user.followings, label: "Following")
                            }
                            
                            Divider()
                                .frame(height: 20)
                            
                            NavigationLink(destination: UserListModalView(userId: user.id, username: user.username, type: .followers)
                                .environmentObject(tweetData)
                                .navigationBarBackButtonHidden(true)) {
                                    ProfileStatsView(count: user.follows, label: "Followers")
                            }
                            
                            Divider()
                                .frame(height: 20)
                            
                            ProfileStatsView(count: user.tweetsCount ?? 0, label: "Tweets")
                        }
                        .padding()
                        .background(Design.secondaryColor)
                        .cornerRadius(Design.cornerRadius)
                        
                        // Status and Admin Badge
                        HStack(spacing: 8) {
                            if user.status == 1 {
                                Label("Active", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            
                            if user.isAdmin {
                                Label("Admin", systemImage: "star.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
        }
        .gesture(DragGesture().onEnded { gesture in
            if gesture.translation.width > 100 {
                dismiss()
            }
        })
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await loadUserProfile()
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            if isCurrentUserProfile {
                UpdatePhotoView()
                    .environmentObject(tweetData)
            }
        }
    }
    
    private func loadUserProfile() async {
        do {
            guard let userId = Int64(userId) else {
                print("❌ Invalid user ID format")
                return
            }
            
            if isCurrentUserProfile {
                // If it's the current user's profile, use the cached profile
                userProfile = tweetData.user
            } else {
                // For other users, fetch their profile
                userProfile = try await tweetData.getOtherUserProfile(username: "")
            }
        } catch {
            print("❌ Error loading profile: \(error)")
        }
    }
    
    private func toggleFollow() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let userId = Int64(userId) else {
                print("❌ Invalid user ID format")
                return
            }
            
            if userProfile?.isFollowing == true {
                try await tweetData.unfollowUser(userId: userId)
            } else {
                try await tweetData.followUser(userId: userId)
            }
            
            // Refresh the profile to get updated follow status
            await loadUserProfile()
        } catch {
            print("❌ Error toggling follow: \(error)")
        }
    }
}

// Helper view for displaying profile stats
struct ProfileStatsView: View {
    let count: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - User List Modal View
struct UserListModalView: View {
    let userId: Int64
    let username: String
    let type: UserListType
    @EnvironmentObject var tweetData: TweetData
    @Environment(\.dismiss) private var dismiss
    @State private var users: [UserProfile] = []
    @State private var totalCount: Int64 = 0
    @State private var currentPage = 1
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMoreData = true
    @State private var offset: CGFloat = 0
    
    private let pageSize = 20
    
    enum UserListType {
        case followers
        case following
        
        var title: String {
            switch self {
            case .followers: return "Followers"
            case .following: return "Following"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
           /*     HStack {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = UIScreen.main.bounds.width
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(type.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(totalCount)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding()*/
                
                // User List
             /*   ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(users, id: \.id) { user in
                            NavigationLink(destination: UserProfileView(userId: user.id)
                                .environmentObject(tweetData)
                                .navigationBarBackButtonHidden(true)) {
                                UserRows(user: user)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onAppear {
                                if user.id == users.last?.id && hasMoreData && !isLoadingMore {
                                    Task {
                                        await loadMoreUsers()
                                    }
                                }
                            }
                        }
                        
                        if isLoadingMore {
                            ProgressView()
                                .tint(.white)
                                .padding()
                        }
                    }
                }*/
            }
        }
        .offset(x: offset)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    if gesture.translation.width > 0 {
                        offset = gesture.translation.width
                    }
                }
                .onEnded { gesture in
                    if gesture.translation.width > UIScreen.main.bounds.width * 0.3 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = UIScreen.main.bounds.width
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                offset = 0
            }
            Task {
                await loadUsers()
            }
        }
    }
    
    private func loadUsers() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let (fetchedUsers, total) = try await fetchUsers(page: 1)
            await MainActor.run {
                users = fetchedUsers
                totalCount = total
                hasMoreData = fetchedUsers.count == pageSize
                currentPage = 1
            }
        } catch {
            print("❌ Error loading users: \(error)")
        }
    }
    
    private func loadMoreUsers() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            let (fetchedUsers, _) = try await fetchUsers(page: currentPage + 1)
            await MainActor.run {
                users.append(contentsOf: fetchedUsers)
                hasMoreData = fetchedUsers.count == pageSize
                currentPage += 1
            }
        } catch {
            print("❌ Error loading more users: \(error)")
        }
    }
    
    private func fetchUsers(page: Int) async throws -> ([UserProfile], Int64) {
        switch type {
        case .followers:
            return try await tweetData.getUserFollowers(username: username, page: page, pageSize: pageSize)
        case .following:
            return try await tweetData.getUserFollowing(username: username, page: page, pageSize: pageSize)
        }
    }
}

// MARK: - User Row Component
struct UserRows: View {
    let user: UserProfile
    @EnvironmentObject var tweetData: TweetData
    @State private var isLoading = false
    
    var body: some View {
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
                        await toggleFollow()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(user.isFollowing! ? "Following" : "Follow")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(user.isFollowing! ? .gray : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(user.isFollowing! ? Color.white.opacity(0.1) : Color.blue)
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
    
    private func toggleFollow() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if user.isFollowing! {
                try await tweetData.unfollowUser(userId: user.id)
            } else {
                try await tweetData.followUser(userId: user.id)
            }
        } catch {
            print("❌ Error toggling follow: \(error)")
        }
    }
}

// MARK: - Update Photo View
struct UpdatePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tweetData: TweetData
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var tempAvatarURL: String?
    
    private enum Design {
        static let cornerRadius: CGFloat = 20
        static let shadowRadius: CGFloat = 10
        static let imageSize: CGFloat = 200
        static let buttonHeight: CGFloat = 50
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Profile Image Preview
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: Design.imageSize, height: Design.imageSize)
                        
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: Design.imageSize - 10, height: Design.imageSize - 10)
                                .clipShape(Circle())
                        } else if let tempAvatarURL = tempAvatarURL {
                            AsyncImage(url: URL(string: tempAvatarURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                                    .tint(.white)
                            }
                            .frame(width: Design.imageSize - 10, height: Design.imageSize - 10)
                            .clipShape(Circle())
                        } else if let user = tweetData.user {
                            AsyncImage(url: user.avatar.safeURL()) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                                    .tint(.white)
                            }
                            .frame(width: Design.imageSize - 10, height: Design.imageSize - 10)
                            .clipShape(Circle())
                        }
                    }
                    .shadow(color: .black.opacity(0.3), radius: Design.shadowRadius)
                    
                    // Photo Picker Button
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Choose Photo")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: Design.buttonHeight)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .disabled(isLoading)
                    
                    // Save Button
                    Button {
                        Task {
                            await savePhoto()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save Changes")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Design.buttonHeight)
                    .background(
                        Capsule()
                            .fill(profileImage != nil ? Color.blue : Color.gray)
                    )
                    .foregroundColor(.white)
                    .disabled(profileImage == nil || isLoading)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("Update Profile Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Revert the optimistic update if user cancels
                        if let originalUser = tweetData.user {
                            Task {
                                await MainActor.run {
                                    tweetData.user = originalUser
                                }
                            }
                        }
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        profileImage = image
                        errorMessage = ""
                        
                        // Create a temporary URL for the selected image
                        if let imageData = image.jpegData(compressionQuality: 0.8) {
                            let base64String = imageData.base64EncodedString()
                            tempAvatarURL = "data:image/jpeg;base64,\(base64String)"
                            
                            // Optimistically update the user's avatar
                            if var updatedUser = tweetData.user {
                                updatedUser.avatar = tempAvatarURL!
                                tweetData.user = updatedUser
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func savePhoto() async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }
        
        do {
            guard let imageData = profileImage?.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "UpdatePhotoView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
            }
            
            // Keep the optimistic update while uploading
            try await tweetData.updateAvatar(avatarData: imageData)
            
            // Refresh user profile after successful update
            if let token = try? KeychainManager.shared.getToken() {
                try? await tweetData.getUserProfile()
            }
            
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        } catch {
            print("❌ Error updating profile photo: \(error)")
            await MainActor.run {
                errorMessage = "Failed to update profile photo: \(error.localizedDescription)"
                isLoading = false
                
                // Revert the optimistic update on error
                if let originalUser = tweetData.user {
                    tweetData.user = originalUser
                }
            }
        }
    }
}
*/
