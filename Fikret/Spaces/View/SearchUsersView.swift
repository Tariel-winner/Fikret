import PhotosUI
import SwiftUI
import AVFoundation
import AVKit
import PhotosUI
import CoreLocation
//import Supabase




struct SearchUsersView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: SpacesViewModel
    @EnvironmentObject var tweetData: TweetData
    let onDismiss: () -> Void
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var users: [SearchUserProfile] = []
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var hasMoreData = true
    @State private var selectedUser: UserProfile?
    @State private var showUserProfile = false
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
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: viewModel.isInSpace)
                    
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
        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: viewModel.isInSpace)
        .zIndex(999)
    }
}

    // Keep the debouncer
    private let searchDebouncer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let pageSize = 8
    
    private func dismissView() {
        onDismiss()
    }
    
    private func loadUsers(reset: Bool = false) async {
        guard !isLoading else { return }
        
        print("🔍 Loading users - Reset: \(reset), Search text: \(searchText)")
        isLoading = true
        
        if reset {
            currentPage = 0
            users = []
            hasMoreData = true
        }
        
        do {
            let searchResults = try await tweetData.searchUsers(keyword: searchText)
            print("✅ Fetched \(searchResults.count) users")
            
            await MainActor.run {
                if reset {
                    users = searchResults
                } else {
                    users.append(contentsOf: searchResults)
                }
                hasMoreData = searchResults.count > 0
                currentPage += 1
            }
            
        } catch {
            print("❌ Error loading users: \(error)")
            print("Error details: \(error.localizedDescription)")
            await MainActor.run {
                if reset {
                    users = []
                }
                hasMoreData = false
            }
        }
        
        isLoading = false
    }
    
    var body: some View {
        ZStack {
            // Primary background (handles status bar too)
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search Header
                SearchHeader(searchText: $searchText) {
                    dismissView()
                }
                
                // User List
                UserListView(
                    users: users,
                    isLoading: isLoading,
                    hasMoreData: hasMoreData,
                    searchText: searchText,
                    selectedTab: .followers,
                    onLoadMore: {
                        Task {
                            await loadUsers()
                        }
                    }
                )
            }
        }
        .transition(.opacity) // Smooth fade animation
        .onChange(of: searchText) { newValue in
            print("🔍 Search text changed to: \(newValue)")
            debouncedSearchText = newValue
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if debouncedSearchText == newValue {
                    print("⏱️ Debounced search for: \(newValue)")
                    await loadUsers(reset: true)
                }
            }
        }
        .onAppear {
            // Reload users when view appears
            Task {
                await loadUsers(reset: true)
            }
        }
        .overlay {
            // ✅ FLOATING INDICATOR: Appears above ALL views including fullscreen covers
            if viewModel.isInSpace && viewModel.isHost {
                floatingIndicator
                    .zIndex(99999) // Higher than any presentation layer
            }
        }
        .sheet(isPresented: $showSpacesSheet) {
            // ✅ LOCAL SHEET: Uses local state for proper context handling
            SpacesListeningNowView(showConfirmationModal: .constant(false))
                .environmentObject(viewModel)
                .environmentObject(tweetData)
        }
    }
}




// Search Header Component
private struct SearchHeader: View {
    @Binding var searchText: String
    let onDismiss: () -> Void
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search users", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
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
        .padding(.horizontal)
        .padding(.vertical, 12)
        .onAppear {
            // ✅ NATIVE: Auto-focus search field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }
}

// User Row Component
struct UserRow: View {
    let user: SearchUserProfile
    @EnvironmentObject var tweetData: TweetData
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @State private var isFollowing: Bool
    @State private var isLoading = false
    @State private var showProfile = false
    
    init(user: SearchUserProfile) {
        self.user = user
        _isFollowing = State(initialValue: user.isFollowing ?? false)
    }
    
    var body: some View {
        Button {
            showProfile = true
        } label: {
            HStack(spacing: 12) {
                // User Avatar - Same logic as TwitterProfileView
                if !user.avatar.isEmpty {
                    CachedAsyncImage(url: user.avatar.safeURL()) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        case .failure:
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        case .empty:
                            ProgressView()
                                .frame(width: 44, height: 44)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // ✅ UPDATED: Use same beautiful default avatar design as TwitterProfileView
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
                            .frame(width: 22, height: 22)
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .shadow(radius: 3)
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
        .fullScreenCover(isPresented: $showProfile) {
            TwitterProfileView(
                userId: user.id,
                username: user.username,
                initialProfile: user
            )
            .environmentObject(tweetData)
            .environmentObject(spacesViewModel)
        }
        .onChange(of: tweetData.otherUsers[user.id]?.isFollowing) { newValue in
            if let newValue = newValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isFollowing = newValue
                }
            }
        }
    }
}
