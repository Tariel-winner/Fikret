import SwiftUI
import RiveRuntime

struct TwitterThemeColors {
    // Primary colors
    let primary = Color("AccentColor", bundle: nil)
    let accent = Color(.systemBlue)
    
    // Background colors
    let background = Color(.systemBackground)
    let secondaryBackground = Color(.secondarySystemBackground)
    
    // Text colors
    let primaryText = Color(.label)
    let secondaryText = Color(.secondaryLabel)
    
    // Interactive colors
    let like = Color.red
    let retweet = Color.green
    let share = Color.blue
    
    // Overlay colors
    let overlay = Color.black.opacity(0.5)
}

extension Color {
    static let twitterTheme = TwitterThemeColors()
}



struct TwitterHomeView: View {
    @Binding var isProfilePictureClicked: Bool
    @StateObject private var tweet = TweetData()
    @State private var selectedPost: TweetModel?
    @State  var showFullScreen = false
    @State  var showSettings = false
    @State private var showLiveSession = false
    
   private var isCurrentUserProfile: Bool {
       guard let currentUserId = tweet.user?.id,
              let profileUserId = tweet.user?.id else {
            print("❌ DEBUG TwitterHomeView: Auth check failed")
          
            print("Profile User ID: \(String(describing: tweet.user?.id))")
            return false
        }
        
        print("""
        🔍 DEBUG TwitterHomeView: User ID Comparison
        Current User ID: \(currentUserId)
        Profile User ID: \(profileUserId)
        Match: \(currentUserId == profileUserId)
        """)
        
        return currentUserId == profileUserId
    }
    
    // Grid layout
    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    // Use a simple loading indicator instead
    var loadingView: some View {
        ProgressView()
            .scaleEffect(2)
            .tint(.twitterTheme.primaryText)
    }
    
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            // Main content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header with Settings
                    HStack {
                        Spacer()
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundColor(.twitterTheme.primaryText)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Profile Section with Rive animation
                    VStack(spacing: 16) {
                        ZStack {
                            // Profile Image
                            AsyncImage(url: (tweet.user?.avatar ?? "").safeURL()) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 90, height: 90)
                                    .foregroundColor(.gray)
                            }
                            
                            // Live Session Button - only visible for profile owner
                            if isCurrentUserProfile {
                                Button {
                                     print("🔵 DEBUG: Live button tapped in TwitterHomeView")
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
                                    .offset(x: 45, y: 45) // Position at bottom-right of profile image
                                    /*.fullScreenCover(isPresented: $showLiveSession) {
                                        LiveSessionSetupView(isPresented: $showLiveSession)
                                            .transition(.move(edge: .bottom))
                                    }*/
                                }
                            }
                        }
                        
                        // User Info
                    Text(tweet.user?.username ?? "User")
                            .font(.title3.bold())
                            .foregroundColor(.twitterTheme.primaryText)
                        
                        Text("@\(tweet.user?.username ?? "username")")
                            .font(.subheadline)
                            .foregroundColor(.twitterTheme.secondaryText)
                        
                        // Stats
                    /*    HStack(spacing: 24) {
                            StatView(count: tweet.user?.following.count ?? 0, label: "Following")
                            StatView(count: tweet.user?.followers.count ?? 0, label: "Followers")
                         //   StatView(count: tweets.tweets.count, label: "Posts")
                        }
                        .padding(.top, 8)*/
                    }
                    
             
                                    .padding(.top)
            }
            
            // Loading overlay
            if isLoading {
                Color.twitterTheme.background
                    .ignoresSafeArea()
                    .overlay(
                        loadingView
                    )
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        
        .onAppear {
            // Simulate loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isLoading = false
                }
            }
        }
    }
    
  
}


struct PostThumbnail: View {
    let tweet: TweetModel
    
    var body: some View {
        AsyncImage(url: tweet.profilepicture.safeURL()) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle()
                //.fill(Color.twitterTheme.secondaryBackground)
        }
    }
}

struct FullScreenPost: View {
    let tweet: TweetModel
    @Binding var isShowing: Bool
    @State private var isLiked = false
    @State private var showComments = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Media content
                AsyncImage(url: tweet.profilepicture.safeURL()) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                
                // Tweet info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        AsyncImage(url: tweet.profilepicture.safeURL()) { image in
                            image
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        
                        VStack(alignment: .leading) {
                            Text(tweet.name)
                                .font(.headline)
                            Text("@\(tweet.username)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button {
                            isShowing = false
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    
                    Text(tweet.tweet)
                        .padding(.vertical)
                }
                .padding()
                .foregroundColor(.white)
            }
        }
    }
}
