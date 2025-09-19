import SwiftUI

// ✅ ADDED: Profile destination for NavigationStack navigation
struct ProfileDestination: Hashable {
    let userId: Int64
    let username: String
}

struct TwitterTabView: View {
    @State private var selectedTab = 1
    @State private var previousTab = 1 // ✅ ADDED: Track previous tab for navigation blocking
    @State var isOpen = false
    @State private var showingBroadcast = false
    @EnvironmentObject var tweets: TweetData
    @EnvironmentObject var notificationManager: NotificationManager
    
    // ✅ ADDED: Render counting to debug re-rendering issues
    @State private var renderCount = 0
    @State private var lastRenderTime = Date()
    
    // ✅ ADDED: Per-tab render counting to identify which tab causes re-renders
    @State private var homeTabRenderCount = 0
    @State private var liveTabRenderCount = 0
    @State private var notificationsTabRenderCount = 0
    
    @EnvironmentObject var inviteManager: InviteManager
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @State private var isConnected = false
   
    // ✅ FIXED: Add state to track overlay drag offset for responsive feel
   
    // ✅ ADDED: State to track navigation blocked toast
    @State private var showNavigationBlockedToast = false
      // @EnvironmentObject var appSettings: AppSettings
    private var currentUserId: Int64? {
        return tweets.user?.id
    }
    
private var notificationBadgeValue: Int {
        return notificationManager.unreadCount > 0 ? Int(notificationManager.unreadCount) : 0
    }
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
            // Home Tab - No nested NavigationStack needed
            if let userId = currentUserId {
                TwitterProfileView(userId: userId)
                    .environmentObject(spacesViewModel)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar) // Hide navigation bar to show tabs
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(0)
                .onAppear {
                    // ✅ ADDED: Home tab render counting
                    homeTabRenderCount += 1
                    print("🏠 [HOME TAB] Rendered #\(homeTabRenderCount) times")
                    
                    // Set white tab bar for profile view
                    let appearance = UITabBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = .white
                    appearance.stackedLayoutAppearance.normal.iconColor = .gray
                    appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
                    appearance.stackedLayoutAppearance.selected.iconColor = .black
                    appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.black]
                    UITabBar.appearance().standardAppearance = appearance
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
            } else {
                // Fallback view when user is not authenticated
                Text("Please sign in")
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(0)
            }
            
            // Live Tab - No nested NavigationStack needed
            ConversationFeedView()
                .environmentObject(spacesViewModel)
                .environmentObject(tweets)
                .environmentObject(notificationManager)
                .environmentObject(inviteManager)
                .tabItem {
                    Label("Live", systemImage: "video.bubble.fill")
                }
                .tag(1)
                .onAppear {
                    // ✅ ADDED: Live tab render counting
                    liveTabRenderCount += 1
                    print("🎥 [LIVE TAB] Rendered #\(liveTabRenderCount) times")
                }
            
            
            // Notifications Tab - No nested NavigationStack needed
            Group {
                if notificationBadgeValue > 0 {
                    NotificationView()
                        .environmentObject(spacesViewModel)
                        .environmentObject(tweets)
                        .tabItem {
                            Label("Notifications", systemImage: "bell")
                        }
                        .tag(2)
                        .badge(notificationBadgeValue)
                } else {
                    NotificationView()
                        .environmentObject(spacesViewModel)
                        .environmentObject(tweets)
                        .tabItem {
                            Label("Notifications", systemImage: "bell")
                        }
                        .tag(2)
                        // No badge when count is 0
                }
            }
                .onAppear {
                    // ✅ ADDED: Notifications tab render counting
                    notificationsTabRenderCount += 1
                    print("🔔 [NOTIFICATIONS TAB] Rendered #\(notificationsTabRenderCount) times")
                    
                    // Set light tab bar for notifications view
                    let appearance = UITabBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = .white
                    appearance.stackedLayoutAppearance.normal.iconColor = .gray
                    appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
                    appearance.stackedLayoutAppearance.selected.iconColor = .black
                    appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.black]
                    UITabBar.appearance().standardAppearance = appearance
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                    
                    // ✅ REMOVED: Don't start polling here - main view handles it
                    // This was causing duplicate timer starts and resets
                }
                .onDisappear {
                    // Stop polling when notifications tab disappears (optional - you might want to keep it running)
                    // notificationManager.stopPolling()
                }
        }
        .onChange(of: selectedTab) { newValue in
            // ✅ ADDED: Render counting for tab changes
            renderCount += 1
            let now = Date()
            let timeSinceLastRender = now.timeIntervalSince(lastRenderTime)
            lastRenderTime = now
            
            print("🔄 [RENDER] Tab change triggered render #\(renderCount)")
            print("⏱️ [RENDER] Time since last render: \(String(format: "%.3f", timeSinceLastRender))s")
            print("📱 [TAB] Tab change attempt: \(selectedTab) -> \(newValue)")
            print("📊 [TAB] isInSpace: \(spacesViewModel.isInSpace), isHost: \(spacesViewModel.isHost)")
            
            // ✅ BLOCKED: Prevent tab switching when in space as participant
            
            if spacesViewModel.isInSpace && !spacesViewModel.isHost {
                print("🚫 Navigation blocked - showing toast")
                // Show toast and revert to previous tab
                showNavigationBlockedToast = true
                withAnimation(.spring()) {
                    selectedTab = previousTab
                }
                return
            }
            
            // Update previous tab for next change
            previousTab = newValue
            
            // Update tab bar appearance when tab changes
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            
            if newValue == 0 || newValue == 2 {
                // White appearance for profile and notifications view
                appearance.backgroundColor = .white
                appearance.stackedLayoutAppearance.normal.iconColor = .gray
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
                appearance.stackedLayoutAppearance.selected.iconColor = .black
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.black]
            } else {
                // Dark appearance for live view
                appearance.backgroundColor = .black
                appearance.stackedLayoutAppearance.normal.iconColor = .gray
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
                appearance.stackedLayoutAppearance.selected.iconColor = .white
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
            }
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        // ✅ REMOVED: allowsHitTesting - now handling navigation blocking at tab change level
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToMapWithLocation"))) { _ in
            // Switch to the Live tab
            withAnimation {
                selectedTab = 1
            }
        }
        .environmentObject(tweets)
        .environmentObject(notificationManager)
        .environmentObject(inviteManager)
        .environmentObject(spacesViewModel)
        
        .overlay {
            // ✅ UNIFIED: Navigation Blocked Toast - Shared with ConversationFeedView
            if showNavigationBlockedToast {
                UnifiedNavigationBlockedToast()
                    .zIndex(1000)
            }
        }
      
      //  .environmentObject(appSettings)
     /*   .fullScreenCover(isPresented: $showingBroadcast) {
            BroadcastView(isPresented: $showingBroadcast)
                .edgesIgnoringSafeArea(.all)
                .preferredColorScheme(.dark)
                .onAppear {
                    UITabBar.appearance().isHidden = true
                }
                .onDisappear {
                    UITabBar.appearance().isHidden = false
                }
        }*/
        .onAppear {
            // ✅ ADDED: Render counting
            renderCount += 1
            let now = Date()
            let timeSinceLastRender = now.timeIntervalSince(lastRenderTime)
            lastRenderTime = now
            
            print("🔄 [RENDER] TwitterTabView rendered #\(renderCount)")
            print("⏱️ [RENDER] Time since last render: \(String(format: "%.3f", timeSinceLastRender))s")
            
            // ✅ ADDED: Per-tab render summary
            print("📊 [RENDER SUMMARY] Total: \(renderCount)")
            print("  🏠 Home: \(homeTabRenderCount)")
            print("  🎥 Live: \(liveTabRenderCount)")
            print("  🔔 Notifications: \(notificationsTabRenderCount)")
            
            // Save current user ID if available
            if let userId = currentUserId {
                print("👤 Saving current user ID: \(userId)")
                UserDefaults.standard.set(String(userId), forKey: "currentUserId")
            }
                        
            // ✅ REMOVED: Don't start polling here - NotificationManager handles its own lifecycle
            // This was causing duplicate start/stop calls
        }
        .onDisappear {
            // ✅ REMOVED: Don't stop polling here - NotificationManager handles its own lifecycle
            // This was causing conflicts with the manager's internal state management
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissNavigationBlockedToast"))) { _ in
            // Dismiss the toast when notification is received
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showNavigationBlockedToast = false
            }
        }



        }
        // ✅ ADDED: Navigation destination for profile navigation
        .navigationDestination(for: ProfileDestination.self) { destination in
            TwitterProfileView(
                userId: destination.userId,
                username: destination.username,
                initialProfile: nil
            )
            .environmentObject(spacesViewModel)
            .environmentObject(tweets)
        }
        // ✅ REMOVED: Old notification-based navigation - now using NavigationStack directly
    }
    
   
    
  
}

// ✅ UNIFIED: Navigation Blocked Toast Component - Shared between ConversationFeedView and TwitterTabView
struct UnifiedNavigationBlockedToast: View {
    @State private var isVisible = false
    
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("Please finish your conversation first")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 50)
        .onAppear {
            // Show toast with animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
            
            // Auto-hide toast after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isVisible = false
                }
                
                // Notify that toast should be dismissed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DismissNavigationBlockedToast"),
                        object: nil
                    )
                }
            }
        }
    }
}

struct TwitterTabView_Previews: PreviewProvider {
    static var previews: some View {
        TwitterTabView()
            .preferredColorScheme(.dark)
            .environmentObject(TweetData())
    }
}
