//
import PhotosUI
import SwiftUI
import AVFoundation
import AVKit
import PhotosUI
import CoreLocation

// Import AudioPlayerPool from SpacesViewModel+HMSUpdateListener
// Note: AudioPlayerPool is defined in SpacesViewModel+HMSUpdateListener.swift

// Simple Typing Area View
struct SimpleTypingAreaView: View {
    @EnvironmentObject private var spacesViewModel: SpacesViewModel
    @FocusState private var isTextFieldFocused: Bool // Add this
    let onDismiss: () -> Void
    let onJoinQueue: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Enter Topic")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Text Field
            ZStack(alignment: .trailing) {
                TextField("", text: Binding(
                    get: { spacesViewModel.currentTopic },
                    set: { spacesViewModel.setTopic($0) }
                ))
                .focused($isTextFieldFocused)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .placeholder(when: spacesViewModel.currentTopic.isEmpty) {
                    Text("Topic for conversation")
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.leading, 16)
                }
                .padding(.leading, 16)
                
                HStack(spacing: 12) {
                    // Clear Button (X)
                    if !spacesViewModel.currentTopic.isEmpty {
                        Button(action: {
                            spacesViewModel.clearTopic()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // Join Button (Arrow)
                    if !spacesViewModel.currentTopic.isEmpty {
                        Button(action: {
                            Task {
                                await onJoinQueue()
                            }
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.trailing, 12)
            }
            .frame(height: 44)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.95), Color.blue.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding()
        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
        .onAppear {
            // Auto-focus immediately when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
        .onDisappear {
            isTextFieldFocused = false
        }
    }
}

struct ConversationFeedView: View {
    @EnvironmentObject private var conversationManager: ConversationCacheManager
    @EnvironmentObject private var spacesViewModel: SpacesViewModel
    @EnvironmentObject private var audioManager: WebMAudioPlaybackManager
    @EnvironmentObject private var tweetData: TweetData
    @Namespace private var namespace
    
    @State private var selectedTab: FeedTab = .letsTalk {
        didSet {
            print("\n=== 🔄 Tab Changed ===")
            print("📊 Old tab: \(oldValue)")
            print("📊 New tab: \(selectedTab)")
        }
    }

    // ✅ REMOVED: showTypingArea - TalkButtonWithTopicInput handles its own state
    @State private var showConfirmationModal = false
    @State private var showSearchUsers = false
    @State private var showInviteSheet = false
    @State private var showNavigationBlockedToast = false
    @EnvironmentObject var inviteManager: InviteManager
    
    // Timer for checking host online status every 20 seconds
    @State private var hostStatusTimer: Timer?
    @State private var currentHostId: Int64? = nil
    enum FeedTab: String, CaseIterable {
        case conversations = "Conversations"
        case letsTalk = "Let's Talk"
    }
    

    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.black.ignoresSafeArea()
            
            // Content Layer
            VStack(spacing: 0) {
                // Tab Header
                TabHeaderView(
                    selectedTab: $selectedTab,
                    namespace: namespace,
                    onNavigationBlocked: {
                        showNavigationBlockedToast = true
                    }
                )
                
                // Feed Content
                FeedContentView(
                    selectedTab: selectedTab,
                    showNavigationBlockedToast: $showNavigationBlockedToast
                )
                    .transition(.opacity)
            }
            
            // Email invite button - always show but handle navigation blocking
            if !showSearchUsers {
            VStack {
                GeometryReader { geometry in
                    HStack {
                        Button(action: {
                            if (spacesViewModel.isInSpace && !spacesViewModel.isHost) || (spacesViewModel.isInSpace && spacesViewModel.isHost) {
                                showNavigationBlockedToast = true
                            } else {
                                showInviteSheet = true
                            }
                        }) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 20, weight: .semibold))
                            .foregroundColor((spacesViewModel.isInSpace && !spacesViewModel.isHost) || (spacesViewModel.isInSpace && spacesViewModel.isHost) ? .white.opacity(0.5) : .white)
                                    .padding(10)
                            .background(
                                LinearGradient(
                                    colors: (spacesViewModel.isInSpace && !spacesViewModel.isHost) || (spacesViewModel.isInSpace && spacesViewModel.isHost) ?
                                        [Color.gray.opacity(0.3), Color.gray.opacity(0.2)] :
                                        [Color.purple.opacity(0.9), Color.blue.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                                    .clipShape(Circle())
                                    .shadow(color: .purple.opacity(0.3), radius: 4, x: 0, y: 2)
                            .overlay(
                                        Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .accessibilityLabel("Invite Friends")
                        .disabled(spacesViewModel.isInSpace && !spacesViewModel.isHost)
                            .padding(.leading, 16)
                            Spacer()
                    }
                        .padding(.top, geometry.safeAreaInsets.top + 8) // Same as SearchButtonView
                }
                    .frame(height: 60) // Same height as SearchButtonView
                Spacer()
            }
            .zIndex(3)
            }
            
            // Search Button (TikTok style) - always show but handle navigation blocking
            SearchButtonView(
                showSearchUsers: $showSearchUsers,
                isDisabled: spacesViewModel.isInSpace && !spacesViewModel.isHost,
                onBlockedAction: {
                    showNavigationBlockedToast = true
                }
            )
            .zIndex(2)
            
            // ✅ REMOVED: Duplicate typing area overlay - TalkButtonWithTopicInput handles its own topic input
            
            if showConfirmationModal {
                ConfirmationModalOverlay(showConfirmationModal: $showConfirmationModal)
            }
            
            // ✅ UNIFIED: Navigation Blocked Toast - Shared with TwitterTabView
            if showNavigationBlockedToast {
                UnifiedNavigationBlockedToast()
                    .zIndex(1000)
            }
            
            
            // ✅ REMOVED: Conditional SearchUsersView - now using fullScreenCover
        }
        .ignoresSafeArea(.keyboard, edges: .bottom) // Let system handle keyboard avoidance
        .onAppear(perform: handleAppear)
        .onDisappear {
            // ✅ FIXED: Stop audio when view disappears
            print("🔇 Stopping audio when ConversationFeedView disappears")
            audioManager.pause()
            
            // Stop host status timer when view disappears
            print("⏰ Stopping host status timer when view disappears")
            resetHostStatusTimer()
        }
        .onChange(of: selectedTab) { newTab in
            // ✅ OPTIMIZED: Minimal tab change handling
            if selectedTab == .conversations && newTab == .letsTalk {
                audioManager.pause()
            }
            
            // Stop timer when switching away from Let's Talk tab
            if newTab != .letsTalk {
                print("⏰ Stopping host status timer - not on Let's Talk tab")
                resetHostStatusTimer()
            }
            
            handleTabChange(newTab)
        }
        .onChange(of: spacesViewModel.currentViewingSpace) { newSpace in
            print("\n=== 🔄 CURRENT VIEWING SPACE CHANGED ===")
            print("📊 New space ID: \(newSpace?.id ?? 0)")
            print("📊 New space host ID: \(newSpace?.hostId ?? 0)")
            
            // Start new timer for the new space's host with 20-second interval
            // startHostStatusTimer will handle cleanup of existing timer
            if let newSpace = newSpace {
                startHostStatusTimer(for: newSpace.hostId)
            }
        }
        // ✅ REMOVED: Duplicate SpacesListeningNowView sheet - TwitterTabView handles Spaces overlay
        // Note: Spaces overlay is now managed centrally in TwitterTabView for better UX
        .sheet(isPresented: $showInviteSheet) {
            InviteContactsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(false)
        }
        .onChange(of: showInviteSheet) { isPresented in
            // ✅ ADDED: Stop audio when InviteContactsView is presented
            if isPresented {
                print("🔇 Stopping audio when InviteContactsView is presented")
                audioManager.pause()
            }
        }
        // ✅ FIXED: Use fullScreenCover for SearchUsersView to prevent white background during transition
        .fullScreenCover(isPresented: $showSearchUsers) {
            SearchUsersView(onDismiss: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showSearchUsers = false
                }
            })
            .environmentObject(spacesViewModel)
            .environmentObject(tweetData)
            .transition(.opacity) // Smooth fade animation
        }
        .onChange(of: showSearchUsers) { isPresented in
            // ✅ ADDED: Stop audio when SearchUsersView is presented
            if isPresented {
                print("🔇 Stopping audio when SearchUsersView is presented")
                audioManager.pause()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showConfirmationModal)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSearchUsers)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showNavigationBlockedToast)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("📱 App going to background - cleaning up audio queue and saving position")
            // Clear audio queue when app goes to background
            audioManager.clearPreloadedQueue()
            
            // ✅ FIXED: Stop audio when app goes to background
            print("🔇 Stopping audio when app goes to background")
            audioManager.pause()
            
            // Stop host status timer when app goes to background
            print("⏰ Stopping host status timer when app goes to background")
            resetHostStatusTimer()
            
            // Note: Position saving is handled in ConversationsTabView
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissNavigationBlockedToast"))) { _ in
            // Dismiss the toast when notification is received
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showNavigationBlockedToast = false
            }
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
        }
    }
    // ✅ REMOVED: joinQueue and dismissTypingArea functions - TalkButtonWithTopicInput handles its own logic

// Separate Tab Header View
struct TabHeaderView: View {
    @Binding var selectedTab: ConversationFeedView.FeedTab
    let namespace: Namespace.ID
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    let onNavigationBlocked: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(ConversationFeedView.FeedTab.allCases, id: \.self) { tab in
                    Button {
                        // Check if navigation should be blocked
                        if spacesViewModel.isInSpace && !spacesViewModel.isHost {
                            onNavigationBlocked()
                        } else {
                            withAnimation(.spring()) {
                                selectedTab = tab
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.6))
                            
                            // Only show the rectangle for the selected tab
                            if selectedTab == tab {
                                Rectangle()
                                    .fill(.white)
                                    .frame(width: 40, height: 2)
                                    .matchedGeometryEffect(id: "underline", in: namespace)
                            } else {
                                Rectangle()
                                    .fill(.clear)
                                    .frame(width: 40, height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 44)
            .padding(.top, geometry.safeAreaInsets.top + 10)
            .padding(.horizontal, 12)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.8), .black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: 94)
    }
}

// ✅ OPTIMIZED: Separate Feed Content View with conditional rendering
struct FeedContentView: View {
    let selectedTab: ConversationFeedView.FeedTab
    @Binding var showNavigationBlockedToast: Bool
    @EnvironmentObject var tweetData: TweetData
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch selectedTab {
                case .conversations:
                    ConversationsTabView(
                        heightOffset: 60,
                        showNavigationBlockedToast: $showNavigationBlockedToast
                    )
                    .environmentObject(tweetData)
                case .letsTalk:
                    LetsTalkTabView(
                        heightOffset: 60,
                        showNavigationBlockedToast: $showNavigationBlockedToast
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
             .transaction { transaction in
            transaction.disablesAnimations = true // Disable animations during tab switch
        }
        }
    }
}

// Keep your existing ConversationsTabView and LetsTalkTabView implementations
// but make sure they're using the correct frame calculations:

struct ConversationsTabView: View {
    @EnvironmentObject private var conversationManager: ConversationCacheManager
    @EnvironmentObject private var spacesViewModel: SpacesViewModel
    @EnvironmentObject private var audioManager: WebMAudioPlaybackManager
    @EnvironmentObject private var tweetData: TweetData
    @State private var currentIndex = 0
    @State private var isInitialLoad = true
    @State private var isViewActive = false
    @State private var scrollOffset: CGFloat = 0
    @State private var lastContentOffset: CGFloat = 0
    @State private var isScrollingUp = false
    @State private var lastIndexChange: Int = 0
    // Removed preloadedPlayers - using SAPlayer queue system instead
    let heightOffset: CGFloat
    @Binding var showNavigationBlockedToast: Bool
    
    private let loadDebouncer = Debouncer(delay: 0.5)
    
    private var conversations: [AudioConversation] {
        return spacesViewModel.conversationsFeed.posts
    }
    
    private func handleScrollPosition() {
        // Only save position if it's different from the last saved position
        let currentPosition = spacesViewModel.restoreConversationPosition()
        if currentPosition.index != currentIndex {
            spacesViewModel.saveConversationPosition(index: currentIndex)
        }
    }
    
    // MARK: - TikTok-Style Preloading with Cache-Aware Logic
    
    /**
     Preloads conversations for smooth TikTok-style experience using SAPlayer's queue system.
     This ensures both forward and backward navigation work efficiently.
     
     - Parameter index: The current conversation index
     */
    private func preloadConversations(for index: Int) {
        guard conversations.indices.contains(index) else {
            print("⚠️ [FEED] Invalid index \(index) for conversations count \(conversations.count)")
            return
        }
        
        // Preload next 2 conversations for smooth forward swiping
        let nextIndices = [index + 1, index + 2].filter { $0 < conversations.count }
        
        // Preload previous 1 conversation for smooth backward swiping
        let previousIndices = [index - 1].filter { $0 >= 0 }
        
        let allPreloadIndices = nextIndices + previousIndices
        
        print("🎵 [FEED] Preloading conversations for indices: \(allPreloadIndices)")
        print("🎵 [FEED] Next indices: \(nextIndices), Previous indices: \(previousIndices)")
        
        // ✅ FIXED: Add error handling and validation for preloading
        for i in allPreloadIndices {
            guard i < conversations.count else {
                print("⚠️ [FEED] Index \(i) out of bounds for conversations count \(conversations.count)")
                continue
            }
            
            let conversation = conversations[i]
            let isNext = nextIndices.contains(i)
            let isPrevious = previousIndices.contains(i)
            
            // Validate conversation has audio before preloading
            let hasHostAudio = conversation.host_audio_url != nil && !conversation.host_audio_url!.isEmpty
            let hasVisitorAudio = conversation.visitor_audio_url != nil && !conversation.visitor_audio_url!.isEmpty
            let hasAudio = hasHostAudio || hasVisitorAudio
            
            guard hasAudio else {
                print("⚠️ [FEED] Skipping preload for conversation \(conversation.id) - no audio available")
                continue
            }
            
            print("🎵 [FEED] Preloading conversation \(conversation.id) (\(isNext ? "NEXT" : isPrevious ? "PREVIOUS" : "OTHER"))")
            
            // ✅ FIXED: Use the updated methods that handle preloading automatically
            if isNext {
                print("📥 [FEED] Preloading next conversation \(conversation.id) with SAPlayer's queue system")
                audioManager.preloadNextConversation(conversation)
            } else if isPrevious {
                print("📥 [FEED] Preloading previous conversation \(conversation.id) with SAPlayer's queue system")
                audioManager.preloadPreviousConversation(conversation)
            }
        }
        
        print("✅ [FEED] Preloading completed for \(allPreloadIndices.count) conversations")
    }
    
    var body: some View {
        if spacesViewModel.isLoadingConversations && conversations.isEmpty {
            TikTokLoadingView(size: 60, color: .white)
        } else {
            GeometryReader { geometry in
                TabView(selection: $currentIndex) {
                    // TikTok-style feed: Only load more content when scrolling down
                    // No top marker needed for previous content loading
                    ForEach(Array(conversations.enumerated()), id: \.element.id) { index, conversation in
                        // Wrapper with reaction button positioned outside TikTokStyleAudioPostCard
                        ZStack {
                            // TikTok-style AudioPostCard with auto-play
                            TikTokStyleAudioPostCard(
                                post: conversation,
                                isActive: currentIndex == index,
                                onAppear: {
                                    // Auto-play when this post becomes active
                                    print("🎵 TikTok-style: Auto-playing post \(conversation.id)")
                                }
                            )
                            
                            // ✅ ADDED: Reaction Button positioned outside the card
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    ConversationReactionButton(
                                        conversation: conversation,
                                        user1Id: Int64(conversation.host_id ?? 0),
                                        user2Id: Int64(conversation.user_id ?? 0)
                                    )
                                    .padding(.trailing, 20)
                                    .padding(.bottom, 20)
                                }
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height - heightOffset)
                        .rotationEffect(.degrees(-90))
                        .tag(index)
                    }
                }
                .frame(width: geometry.size.height - heightOffset, height: geometry.size.width)
                .rotationEffect(.degrees(90))
                .offset(
                    x: (geometry.size.width - (geometry.size.height - heightOffset)) / 2,
                    y: ((geometry.size.height - heightOffset) - geometry.size.width) / 2 + heightOffset
                )
                .tabViewStyle(.page(indexDisplayMode: .never))
                .refreshable {
                    // Check if navigation should be blocked
                    if spacesViewModel.isInSpace && !spacesViewModel.isHost {
                        showNavigationBlockedToast = true
                        return
                    }
                    
                    await spacesViewModel.refreshConversationsFeed()
                }
            }
            .onChange(of: currentIndex) { index in
                // ✅ BLOCKED: Prevent swiping when in space as participant
                if spacesViewModel.isInSpace && !spacesViewModel.isHost {
                    // Revert to previous index
                    withAnimation(.spring()) {
                        currentIndex = lastIndexChange
                    }
                    showNavigationBlockedToast = true
                    return
                }
                
                // ✅ OPTIMIZED: Minimal index change handling
                spacesViewModel.saveConversationPosition(index: index)
                preloadConversations(for: index)
                
                // Detect scroll direction
                let isScrollingDown = index > lastIndexChange
                let isScrollingUp = index < lastIndexChange
                
                // Handle scrolling down - load more conversations
                if isScrollingDown &&
                   index >= conversations.count - 2 &&
                   !spacesViewModel.isLoadingMoreConversations &&
                   spacesViewModel.hasMoreDataConversations {
                    Task {
                        await loadDebouncer.debounce {
                            await spacesViewModel.loadMoreConversations()
                        }
                    }
                }
                
                // Handle scrolling up - load previous conversations
                if isScrollingUp &&
                   index <= 2 &&
                   !spacesViewModel.isLoadingConversations &&
                   spacesViewModel.currentPageConversations > 1 {
                    Task {
                        await loadDebouncer.debounce {
                            await spacesViewModel.loadPreviousConversations()
                        }
                    }
                }
                
                lastIndexChange = index
            }
            .onAppear {
                print("🎵 ConversationsTabView appeared")
                isViewActive = true
                
                // Restore position when view appears
                if isInitialLoad {
                    isInitialLoad = false
                    let (index, _) = spacesViewModel.restoreConversationPosition()
                    print("📊 Restoring conversation position to index: \(index)")
                    // Ensure index is valid (not -1 when no posts)
                    if conversations.isEmpty {
                        currentIndex = 0
                    } else {
                        currentIndex = max(0, min(index, conversations.count - 1))
                    }
                }
            }
            .onDisappear {
                print("🎵 ConversationsTabView disappeared")
                isViewActive = false
                print("🔇 Stopping all audio when conversations tab disappears")
                audioManager.pause()
                handleScrollPosition()
            }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                print("📱 App going to background - cleaning up audio queue and saving position")
                // Clear audio queue when app goes to background
                audioManager.clearPreloadedQueue()
                
                // ✅ FIXED: Stop audio when app goes to background
                print("🔇 Stopping audio when app goes to background")
                audioManager.pause()
                
                // Save conversation position
                spacesViewModel.saveConversationPosition(index: currentIndex)
            }
            .overlay(
                Group {
                    // Loading indicator for more conversations (bottom)
                    if spacesViewModel.isLoadingMoreConversations {
                        VStack {
                            Spacer()
                            TikTokLoadingView(size: 30, color: .white)
                                .padding(.bottom, 40)
                        }
                    }
                    
                    // Loading indicator for previous conversations (top)
                    if spacesViewModel.isLoadingConversations && !spacesViewModel.conversationsFeed.posts.isEmpty {
                        VStack {
                            TikTokLoadingView(size: 30, color: .white)
                                .padding(.top, 40)
                            Spacer()
                        }
                    }
                }
            )
            // App lifecycle handling - position saving is now handled in the combined notification handler above
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                print("📱 App coming to foreground - restoring conversation position")
                let (index, _) = spacesViewModel.restoreConversationPosition()
                currentIndex = min(index, conversations.count - 1)
            }
        }
    }
}


// Add EmptyStateView
struct EmptyStateViewForLetsTalk: View {
    @EnvironmentObject private var spacesViewModel: SpacesViewModel
    @State private var refreshIconRotation: Double = 0
    @State private var showRefreshHint = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 120)
                
                // Main icon with subtle animation
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(showRefreshHint ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: showRefreshHint)
                    
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white.opacity(0.7), .white.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(showRefreshHint ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: showRefreshHint)
                }
                .padding(.bottom, 8)
                
                // Title with gradient
                Text("No online rooms currently")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text("Discover live conversations and join the discussion")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Pull to refresh hint
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .rotationEffect(.degrees(refreshIconRotation))
                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: refreshIconRotation)
                    
                    Text("Pull down to refresh")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .scaleEffect(showRefreshHint ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: showRefreshHint)
                .padding(.top, 16)
                
                Spacer(minLength: 120)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: UIScreen.main.bounds.height - 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Start subtle animations
            withAnimation {
                showRefreshHint = true
                refreshIconRotation = 360
            }
        }
        .onDisappear {
            showRefreshHint = false
            refreshIconRotation = 0
        }
    }
}

// Update LetsTalkTabView
struct LetsTalkTabView: View {
    @EnvironmentObject private var conversationManager: ConversationCacheManager
    @EnvironmentObject private var spacesViewModel: SpacesViewModel
    @State private var currentIndex = 0
    @State private var previousIndex = 0 // ✅ ADDED: Track previous index for navigation blocking
    @State private var isInitialLoad = true
    @State private var lastFilteredCount: Int = 0
    @State private var showConfirmationModal = false
    @State private var isViewActive = false
    let heightOffset: CGFloat
    @EnvironmentObject var tweetData: TweetData
    @Binding var showNavigationBlockedToast: Bool
    private let loadDebouncer = Debouncer(delay: 0.5)
    
    private var filteredSpaces: [Space] {
        guard let currentUserId = tweetData.user?.id else {
            print("⚠️ No current user ID available, showing all spaces")
            return spacesViewModel.spaces
        }
        
        let filtered = spacesViewModel.spaces.filter { space in
            space.hostId != currentUserId
        }
        
        if filtered.count != lastFilteredCount {
            print("🔄 Filtered spaces count changed:")
            print("- Previous count: \(lastFilteredCount)")
            print("- New count: \(filtered.count)")
            print("- Total spaces: \(spacesViewModel.spaces.count)")
            print("- Current user ID: \(currentUserId)")
            
            DispatchQueue.main.async {
                lastFilteredCount = filtered.count
            }
        }
        
        return filtered
    }
    
    private func handleTalkButtonTap(for card: Space) async {
        print("🎯 handleTalkButtonTap triggered with card: \(card.id)")
        
        await MainActor.run { [self] in
            print("🎯 Setting currentViewingSpace")
            spacesViewModel.currentViewingSpace = card
            // ✅ REMOVED: WebSocket monitoring - now using REST API approach
        }
    }
    
    private func handleScrollPosition() {
        // Only save position if it's different from the last saved position
        let currentPosition = spacesViewModel.restorePosition()
        if currentPosition.index != currentIndex {
            spacesViewModel.savePosition(index: currentIndex)
        }
    }
    
    var body: some View {
        if spacesViewModel.isLoadingSpaces && filteredSpaces.isEmpty {
            // Show loading view when actively loading and no spaces available
            VStack {
                Spacer()
                TikTokLoadingView(size: 60, color: .white)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .refreshable {
                // Check if navigation should be blocked
                if spacesViewModel.isInSpace && !spacesViewModel.isHost {
                    showNavigationBlockedToast = true
                    return
                }
                
                await spacesViewModel.refreshFeed()
            }
        } else if filteredSpaces.isEmpty {
            // Show empty state only when not loading and empty
            EmptyStateViewForLetsTalk()
                .refreshable {
                    // Check if navigation should be blocked
                    if spacesViewModel.isInSpace && !spacesViewModel.isHost {
                        showNavigationBlockedToast = true
                        return
                    }
                    
                    await spacesViewModel.refreshFeed()
                }
               
        } else {
            GeometryReader { geometry in
                let cardHeight = geometry.size.height - heightOffset // Remove header offset - already accounted for in main view
                
                TabView(selection: $currentIndex) {
                    ForEach(Array(filteredSpaces.enumerated()), id: \.element.id) { index, space in
                            SpacesListeningNowViewForTalkCard(
                                onTalkButtonTap: {
                                    Task {
                                        await handleTalkButtonTap(for: space)
                                    }
                                },
                                showConfirmationModal: $showConfirmationModal
                            )
                        .frame(width: geometry.size.width, height: cardHeight)
                        .rotationEffect(.degrees(-90))
                        .tag(index)
                    }
                }
                .frame(width: geometry.size.height - heightOffset, height: geometry.size.width)
                .rotationEffect(.degrees(90))
                .offset(
                    x: (geometry.size.width - (geometry.size.height - heightOffset)) / 2,
                    y: ((geometry.size.height - heightOffset) - geometry.size.width) / 2 + heightOffset
                )
                .tabViewStyle(.page(indexDisplayMode: .never))
                .refreshable {
                    // Check if navigation should be blocked
                    if spacesViewModel.isInSpace && !spacesViewModel.isHost {
                        showNavigationBlockedToast = true
                        return
                    }
                    
                    await spacesViewModel.refreshFeed()
                }
                .onChange(of: currentIndex) { newIndex in
                    // ✅ BLOCKED: Prevent swiping when in space as participant
                    if spacesViewModel.isInSpace && !spacesViewModel.isHost {
                        // Revert to previous index
                        withAnimation(.spring()) {
                            currentIndex = currentIndex // Keep current index
                        }
                        showNavigationBlockedToast = true
                        return
                    }
                    
                    // ✅ OPTIMIZED: Minimal index change handling
                    if newIndex < filteredSpaces.count {
                        let newSpace = filteredSpaces[newIndex]
                       
                        spacesViewModel.currentViewingSpace = newSpace
                       
                    } else {
                        print("❌ Index out of bounds: \(newIndex) >= \(filteredSpaces.count)")
                    }
                    
                    spacesViewModel.savePosition(index: newIndex)
                    
                    // Load next page when user reaches near the end
                    if newIndex >= filteredSpaces.count - 2 && !spacesViewModel.isLoadingSpaces && !spacesViewModel.isLoadingMoreSpaces && spacesViewModel.hasMoreDataSpaces {
                        Task {
                            await loadDebouncer.debounce {
                                await spacesViewModel.loadNextPage()
                            }
                        }
                    }
                    
                    // Load previous page when user reaches near the beginning
                    if newIndex <= 2 && !spacesViewModel.isLoadingSpaces && !spacesViewModel.isLoadingMoreSpaces && spacesViewModel.currentPageSpaces > 1 {
                        Task {
                            await loadDebouncer.debounce {
                                await spacesViewModel.loadPreviousSpaces()
                            }
                        }
                    }
                }
                .overlay(
                    Group {
                        // Loading indicator for more spaces (bottom)
                        if spacesViewModel.isLoadingMoreSpaces {
                            VStack {
                                Spacer()
                                TikTokLoadingView(size: 30, color: .white)
                                    .padding(.bottom, 40)
                            }
                        }
                        
                       
                    }
                )
            }
            // ✅ OPTIMIZED: Debounced spaces count change to prevent excessive re-renders
            .onChange(of: spacesViewModel.spaces.count) { newCount in
                print("🔄 Spaces count updated: \(newCount)")
                
                // Adjust current index if needed
                if currentIndex >= filteredSpaces.count {
                    currentIndex = max(0, filteredSpaces.count - 1)
                }
            }
            .onAppear {
                print("🔄 LetsTalkTabView appeared")
                isViewActive = true
               
                // Initialize lastFilteredCount
                lastFilteredCount = filteredSpaces.count
                
                // ✅ REMOVED: Loading logic moved to parent handleAppear() method
                // This prevents race conditions and matches ConversationsTabView behavior
                
                // Restore position when view appears
                if isInitialLoad {
                    isInitialLoad = false
                    let (index, _) = spacesViewModel.restorePosition()
                    print("📊 Restoring position to index: \(index)")
                    currentIndex = min(index, filteredSpaces.count - 1)
                    
                                    // Set currentViewingSpace for the initial item
                if currentIndex < filteredSpaces.count {
                    let initialSpace = filteredSpaces[currentIndex]
                    spacesViewModel.currentViewingSpace = initialSpace
                    print("🎯 Initial currentViewingSpace set to: \(initialSpace.id)")
                }
                
                // ✅ REMOVED: WebSocket monitoring - now using REST API approach
                // Host status will be fetched via REST API when needed
            }
            }
            .onDisappear {
                print("📊 LetsTalkTabView disappeared")
                isViewActive = false
                // Don't clear currentViewingSpace when switching tabs - only when view is destroyed
                // spacesViewModel.currentViewingSpace = nil
                print("📊 Final spaces count: \(spacesViewModel.spaces.count)")
                print("📊 Final filtered spaces count: \(filteredSpaces.count)")
                // Save position when view disappears
                handleScrollPosition()
                
                // ✅ REMOVED: WebSocket monitoring - now using REST API approach
                // No need to stop monitoring since we're not using WebSocket subscriptions
            }
            .alert("Error Loading Spaces", isPresented: .constant(spacesViewModel.loadErrorSpaces != nil)) {
                Button("Retry") {
                    print("🔄 Retry button tapped")
                    Task {
                        await spacesViewModel.refreshFeed()
                    }
                }
                Button("OK", role: .cancel) {
                    print("📊 Dismissing error alert")
                    spacesViewModel.loadErrorSpaces = nil
                }
            } message: {
                Text(spacesViewModel.loadErrorSpaces ?? "Unknown error")
            }
        }
    }
}

// First, let's create a model for our Let's Talk card
/*struct TalkCard: Identifiable, Decodable {
    let id: Int64
    let hostId: Int64
    let hostName: String
    let hostImageUrl: String
    let topics: [String]?
    let description: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case hostName = "host"
        case hostImageUrl = "host_image_url"
        case topics
        case description
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        hostId = try container.decode(Int64.self, forKey: .hostId)
        hostName = try container.decode(String.self, forKey: .hostName)
        hostImageUrl = try container.decode(String.self, forKey: .hostImageUrl)
       
        description = try container.decode(String.self, forKey: .description)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        
        if let topicsArray = try? container.decode([String].self, forKey: .topics) {
            topics = topicsArray.isEmpty ? nil : topicsArray
        } else {
            topics = nil
        }
    }
}

// Card UI Component
struct TalkCardView: View {
    let card: Space
    let onTalkButtonTap: () -> Void
    @State private var isImageLoaded = false
    @State private var isButtonEnabled = true
    @State private var imageLoadingState: String = "initial"
    @State private var showDefaultImage = false
    
    private func logImageState(_ state: String) {
        print("🔄 [TalkCardView] Card \(card.id) - Image state: \(state)")
        imageLoadingState = state
    }
    
    private func cleanImageURL(_ urlString: String?) -> URL? {
        guard let urlString = urlString else { return nil }
        // Use the comprehensive safeURL function
        return urlString.safeURL()
    }
    
    private var defaultProfileImage: some View {
        Group {
            if let _ = UIImage(named: "ic_smalluser") {
                Image("ic_smalluser")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                // Fallback if image is not found
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.7))
                    )
            }
        }
    }
    
    private var statusColor: Color {
        return card.isHostOnline ? .green : .gray
    }
    
    private var statusText: String {
        return card.isHostOnline ? "Available" : "Offline"
    }
    
    private var topicsView: some View {
        Group {
            if let topics = card.topics {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(topics, id: \.self) { topic in
                            TopicPill(topic: topic)
                        }
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Profile Image and Status
            HStack(alignment: .top, spacing: 16) {
                // Profile Image - Simplified for iOS 16
                if let url = cleanImageURL(card.hostImageUrl) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        case .failure, .empty:
                            defaultProfileImage
                        @unknown default:
                            defaultProfileImage
                        }
                    }
                    .frame(width: 80, height: 80)
                } else {
                    defaultProfileImage
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Name
                    Text(card.host ?? "Unknown Host")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Topics section
                    topicsView
                        .padding(.top, 4)
                }
            }
            .padding(.bottom, 8)
            
            // Action Button and Status
            HStack {
                // Status Indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.1))
                .clipShape(Capsule())
                
                Spacer()
                
                // Talk Button - Simplified for iOS 16 compatibility
                Button(action: {
                    guard isButtonEnabled else { return }
                    isButtonEnabled = false
                    print("💬 Talk button tapped - Card ID: \(card.id)")
                    onTalkButtonTap()
                    
                    // Re-enable button after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isButtonEnabled = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                        Text("Talk")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.purple)
                    .clipShape(Capsule())
                }
                .disabled(!isButtonEnabled)
                .opacity(isButtonEnabled ? 1 : 0.7)
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal)
        .onAppear {
            print("🔄 [TalkCardView] View appeared for card: \(card.id)")
        }
    }
}

// Update Equatable implementation to be more precise
extension TalkCardView: Equatable {
    static func == (lhs: TalkCardView, rhs: TalkCardView) -> Bool {

        
        let isEqual = lhs.card.id == rhs.card.id &&
        lhs.card.hostId == rhs.card.hostId &&
        lhs.card.host == rhs.card.host &&
        lhs.card.hostImageUrl == rhs.card.hostImageUrl &&
        lhs.card.topics == rhs.card.topics
        
        if !isEqual {
            print("🔄 [TalkCardView] View will re-render due to changes:")
            print("  - Card ID: \(lhs.card.id) vs \(rhs.card.hostId)")
            print("  - Host ID: \(lhs.card.hostId) vs \(rhs.card.hostId)")
            print("  - Host: \(lhs.card.host ?? "nil") vs \(rhs.card.host ?? "nil")")
            print("  - Image URL: \(lhs.card.hostImageUrl ?? "nil") vs \(rhs.card.hostImageUrl ?? "nil")")
            print("  - Topics: \(lhs.card.topics ?? []) vs \(rhs.card.topics ?? [])")
        }
        
        return isEqual
    }
}*/

// New component for topic pills
struct TopicPill: View {
    let topic: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "tag.fill")
                .font(.system(size: 12))
            Text(topic)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(.white.opacity(0.8))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
}

// Shimmer Effect Modifier
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.3), location: 0.3),
                            .init(color: .clear, location: 0.7)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width)
                    .offset(x: geometry.size.width * phase)
                    .animation(
                        .linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: phase
                    )
                }
            )
            .onAppear {
                phase = 1
            }
    }
}

// Add this new button style at the bottom of the file
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Add this new button style at the bottom of the file
struct SearchButtonStyle: ButtonStyle {
    @State private var isPressed = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Add this before ConversationFeedView
private struct SearchButtonView: View {
    @Binding var showSearchUsers: Bool
    let isDisabled: Bool
    let onBlockedAction: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer()
                // Only search button here
                Button(action: {
                    if isDisabled {
                        onBlockedAction()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showSearchUsers = true
                        }
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isDisabled ? .white.opacity(0.5) : .white)
                        .padding(10)
                        .background(isDisabled ? Color.black.opacity(0.2) : Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .padding(.trailing, 16)
            }
            .padding(.top, geometry.safeAreaInsets.top + 8)
            .frame(height: 60)
        }
        .zIndex(1)
    }
}

// Add this before ConversationFeedView
private struct ConfirmationModalOverlay: View {
    @EnvironmentObject private var spacesViewModel: SpacesViewModel
    @Binding var showConfirmationModal: Bool
    @EnvironmentObject var tweetData: TweetData
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) {
                        showConfirmationModal = false
                    }
                }
            
          RemoveUserConfirmationModal(
                isPresented: $showConfirmationModal,
                userName: tweetData.user?.username ?? "User",
                onConfirm: {
                    print("🚫 Confirmation modal confirmed")
                    Task {
                        if spacesViewModel.isInSpace {
                            print("🚫 Leaving space")
                            await spacesViewModel.spaceButtonTapped()
                        } else if spacesViewModel.isInQueue {
                            print("🚫 Leaving queue")
                          //  await spacesViewModel.leaveQueue()
                        }
                    }
                }
            )
            .transition(.scale.combined(with: .opacity))
            .zIndex(2)
        }
    }
}

// Add this before the main view's closing brace
private extension ConversationFeedView {
    func handleAppear() {
        print("\n=== 🚀 CONVERSATION FEED VIEW APPEARED ===")
        print("📊 Selected Tab: \(selectedTab)")
        
        // Start host status timer if there's already a currentViewingSpace
        if let currentSpace = spacesViewModel.currentViewingSpace {
            print("⏰ Starting host status timer for existing currentViewingSpace")
            startHostStatusTimer(for: currentSpace.hostId)
        }
        
        switch selectedTab {
        case .conversations:
            print("🎵 Conversations tab - checking state")
            if spacesViewModel.conversationsFeed.posts.isEmpty {
                print("📥 Loading initial conversations using new pagination")
                Task {
                    await spacesViewModel.loadConversationsFeed(conversationPage: 1)
                }
            } else {
                print("📊 Conversations already loaded: \(spacesViewModel.conversationsFeed.posts.count) posts")
            }
            
        case .letsTalk:
            print("💬 Let's Talk tab - checking state")
            print("🔍 [handleAppear] isLoadingSpaces: \(spacesViewModel.isLoadingSpaces)")
            print("🔍 [handleAppear] spaces.isEmpty: \(spacesViewModel.spaces.isEmpty)")
            print("🔍 [handleAppear] spaces.count: \(spacesViewModel.spaces.count)")
            
            if spacesViewModel.spaces.count <= 1 {
                print("📥 Loading initial spaces using spaces pagination")
              
                Task {
                    print("🔍 [handleAppear] BEFORE loadSpacesFeed - isLoadingSpaces: \(spacesViewModel.isLoadingSpaces)")
                    await spacesViewModel.loadSpacesFeed(spacePage: 1)
                    print("🔍 [handleAppear] AFTER loadSpacesFeed - isLoadingSpaces: \(spacesViewModel.isLoadingSpaces)")
                }
            } else {
                print("📊 Spaces already loaded: \(spacesViewModel.spaces.count) spaces")
            }
        }
    }
    
    func handleTabChange(_ tab: FeedTab) {
        print("\n=== 🔄 TAB CHANGE HANDLER ===")
        print("📊 Switching from: \(selectedTab) to: \(tab)")
        
        // ✅ FIXED: Stop audio when switching away from conversations tab
        if selectedTab == .conversations && tab == .letsTalk {
            print("🔇 Stopping audio when switching from conversations to let's talk")
            audioManager.pause()
        }
        
        switch tab {
        case .conversations:
         
            // Only reset if no conversations are loaded
            if spacesViewModel.conversationsFeed.posts.isEmpty {
                print("🎵 Conversations tab - resetting to first post (no posts loaded)")
                spacesViewModel.lastViewedConversationIndex = 0
                spacesViewModel.lastViewedConversationPage = 1
                spacesViewModel.currentPageConversations = 0
                spacesViewModel.hasMoreDataConversations = true
                
                // Reset conversation loading states to prevent stuck state
                spacesViewModel.isLoadingConversations = false
                spacesViewModel.isLoadingMoreConversations = false
                
                print("🔍 AFTER CONVERSATIONS TAB RESET:")
                print("  - currentPageConversations: \(spacesViewModel.currentPageConversations)")
                print("  - hasMoreDataConversations: \(spacesViewModel.hasMoreDataConversations)")
                print("  - lastViewedConversationIndex: \(spacesViewModel.lastViewedConversationIndex)")
                print("  - lastViewedConversationPage: \(spacesViewModel.lastViewedConversationPage)")
                
                // Load initial feed
                print("📥 Loading initial feed")
                Task {
                    await spacesViewModel.loadConversationsFeed(conversationPage: 1)
                }
            } else {
                print("🎵 Conversations tab - maintaining current state (posts already loaded)")
                print("🔍 NO STATE CHANGE - POSTS ALREADY LOADED:")
                print("  - currentPageConversations: \(spacesViewModel.currentPageConversations)")
                print("  - hasMoreDataConversations: \(spacesViewModel.hasMoreDataConversations)")
                print("  - conversationsFeed.posts.count: \(spacesViewModel.conversationsFeed.posts.count)")
            }
            
        case .letsTalk:
            
            // Only reset if we only have 1 space (user's own space) or no spaces
            if spacesViewModel.spaces.count <= 1 {
                print("💬 Let's Talk tab - resetting to first post (no spaces loaded)")
                spacesViewModel.lastViewedSpaceIndex = 0
                spacesViewModel.lastViewedSpacePage = 1
                spacesViewModel.currentPageSpaces = 0
                spacesViewModel.hasMoreDataSpaces = true
              
                print("🔍 [handleTabChange] BEFORE reset - isLoadingSpaces: \(spacesViewModel.isLoadingSpaces)")
                spacesViewModel.isLoadingSpaces = false
                spacesViewModel.isLoadingMoreSpaces = false
                print("🔍 [handleTabChange] AFTER reset - isLoadingSpaces: \(spacesViewModel.isLoadingSpaces)")
                // Load initial feed - set loading state SYNCHRONOUSLY before async task
             
                Task {
                    print("🔍 [handleTabChange] BEFORE loadSpacesFeed - isLoadingSpaces: \(spacesViewModel.isLoadingSpaces)")
                    await spacesViewModel.loadSpacesFeed(spacePage: 1)
                    print("🔍 [handleTabChange] AFTER loadSpacesFeed - isLoadingSpaces: \(spacesViewModel.isLoadingSpaces)")
                }
            } else {
              
                print("  - spaces.count: \(spacesViewModel.spaces.count)")
            }
        }
        
        // Reset conversation manager for the new tab
        conversationManager.resetAndReloadContent(for: tab)
    }
    
    // MARK: - Host Status Timer Functions
    
    /// Starts a timer to check host online status every 20 seconds
    private func startHostStatusTimer(for hostId: Int64) {
        print("⏰ Starting host status timer for host ID: \(hostId)")
        
        // Safety check: Don't start if already running for the same host
        if hostStatusTimer != nil && currentHostId == hostId {
            print("⚠️ Timer already running for host ID: \(hostId), skipping duplicate start")
            return
        }
        
        // Clean up existing timer if any (handles both same and different host cases)
        if hostStatusTimer != nil {
            print("🔄 Timer exists for host (\(currentHostId ?? 0)), cleaning up for new host (\(hostId))")
            hostStatusTimer?.invalidate()
            hostStatusTimer = nil
            currentHostId = nil
        }
        
       
        // Update current host ID
        currentHostId = hostId
        
        // Start 20-second repeating timer (first execution is after 20 seconds)
        hostStatusTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task {
                await self.checkHostOnlineStatus(hostId: hostId)
            }
        }
        
        // Perform immediate check since timer waits 20 seconds for first execution
        Task {
            await self.checkHostOnlineStatus(hostId: hostId)
        }
        
        print("✅ Host status timer started with 20-second interval for host ID: \(hostId)")
    }
    
    /// Resets and stops the host status timer
    private func resetHostStatusTimer() {
        print("⏰ Resetting host status timer")
        hostStatusTimer?.invalidate()
        hostStatusTimer = nil
        currentHostId = nil
        print("✅ Host status timer reset")
    }
    

    
    /// Checks the online status of a specific host
    private func checkHostOnlineStatus(hostId: Int64) async {
        print("🔍 Checking online status for host ID: \(hostId)")
        
        do {
            let isOnline = try await TweetData.shared.fetchUserOnlineStatus(userId: hostId)
            print("✅ Host \(hostId) online status: \(isOnline)")
            
            // The fetchUserOnlineStatus method already handles updating SpacesViewModel state
            // so we don't need to do anything else here
        } catch {
            print("❌ Failed to check host online status: \(error)")
        }
    }
}

// Helper extension for placeholder
/*extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}*/

// ✅ REMOVED: Duplicate UnifiedNavigationBlockedToast struct - now defined in TwitterTabView.swift

// Add this before ConversationFeedView
private struct DismissKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private extension EnvironmentValues {
    var dismiss: () -> Void {
        get { self[DismissKey.self] }
        set { self[DismissKey.self] = newValue }
    }
}



// TikTok-style AudioPostCard with auto-play functionality
struct TikTokStyleAudioPostCard: View {
    let post: AudioConversation
    let isActive: Bool
    let onAppear: () -> Void
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @EnvironmentObject var audioManager: WebMAudioPlaybackManager
    
    @State private var isPlayerReady = false
    @State private var isPlaying = false
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @GestureState private var dragLocation: CGFloat = 0
    @State private var showPlayIcon = false
    @State private var showWaveform = false
    @State private var waveformOffset: CGFloat = 0
    // ✅ FIXED: Use computed properties to get real-time audio levels from audio manager
    private var hostAudioLevel: Float {
        return audioManager.hostAudioLevel
    }
    
    private var visitorAudioLevel: Float {
        return audioManager.visitorAudioLevel
    }
    
    // MARK: - Location Helper Properties
    
    /// Check if address contains complete location information (street, city, state, country)
    private func isCompleteAddress(_ address: String) -> Bool {
        let components = address.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // A complete address should have at least 4 components: street, city, state, country
        if components.count >= 4 {
            // Check if first component looks like a street (has numbers or street indicators)
            let firstComponent = components[0].lowercased()
            if firstComponent.contains(where: { $0.isNumber }) || 
               firstComponent.contains("street") || 
               firstComponent.contains("road") || 
               firstComponent.contains("avenue") ||
               firstComponent.contains("boulevard") ||
               firstComponent.contains("drive") ||
               firstComponent.contains("lane") {
                return true
            }
        }
        return false
    }
    
    /// Extract street name from address string
    private func extractStreetFromAddress(_ address: String) -> String? {
        let components = address.components(separatedBy: ",")
        if let firstComponent = components.first, !firstComponent.trimmingCharacters(in: .whitespaces).isEmpty {
            let street = firstComponent.trimmingCharacters(in: .whitespaces)
            // Only return if it looks like a street (contains numbers or common street words)
            if street.contains(where: { $0.isNumber }) || 
               street.lowercased().contains("street") || 
               street.lowercased().contains("road") || 
               street.lowercased().contains("avenue") ||
               street.lowercased().contains("boulevard") {
                return street
            }
        }
        return nil
    }
    
    private var hasLocationData: Bool {
        return post.location_name != nil ||
               post.location_city != nil ||
               post.location_address != nil ||
               post.location_country != nil
    }
    
    private var primaryLocationText: String {
        // Priority: address (if complete) > city > location_name > country
        // Show the most specific location first
        if let address = post.location_address, !address.isEmpty {
            // If address contains complete location info, use it directly
            if isCompleteAddress(address) {
                return address
            }
            // Otherwise extract street name from address if possible
            if let street = extractStreetFromAddress(address) {
                return street
            }
            return address
        } else if let city = post.location_city, !city.isEmpty {
            return city
        } else if let locationName = post.location_name, !locationName.isEmpty {
            // If location_name is a prefecture/region, add context
            if locationName.contains("Prefecture") || locationName.contains("自治州") || locationName.contains("Bayingolin") {
                return "\(locationName), Xinjiang"
            }
            return locationName
        } else if let country = post.location_country, !country.isEmpty {
            return country
        }
        return "Unknown Location"
    }
    
    private var secondaryLocationText: String? {
        // Show additional location details for context
        var components: [String] = []
        
        // Add state/province if available
        if let state = post.location_state, !state.isEmpty {
            components.append(state)
        }
        
        // Add country if available and different from state
        if let country = post.location_country, !country.isEmpty, post.location_state != country {
            components.append(country)
        }
        
        // If we have a full address, show it as secondary info
        if let address = post.location_address, !address.isEmpty {
            // Only show if it's different from what we're already showing as primary
            let primaryText = primaryLocationText
            if address != primaryText && !address.contains(primaryText) {
                components.append(address)
            }
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    @State private var showTimeline = false
    @State private var timelineOpacity: Double = 0
    @State private var isScrubbing: Bool = false
    @State private var isPrepared: Bool = false
    @State private var isUIEnabled: Bool = true
    @State private var playbackError: Error?
    @State private var showError = false
    @State private var lastPlaybackPosition: Double = 0
    @State private var isVisible = false
    @State private var showControls = false
    @State private var syncTimer: Timer?
    @State private var seekWorkItem: DispatchWorkItem?
    
    // ✅ FIXED: Add state tracking to prevent infinite loops
    @State private var lastAudioManagerPlayingState: Bool = false
    @State private var lastAudioManagerPreparedState: Bool = false
    @State private var isStateUpdateInProgress: Bool = false
    
private func getProgressForPost() -> Double {
    return audioManager.getProgressForConversation(post.id)
}


    // ✅ SIMPLIFIED: Seek indicator logic
    private var shouldShowSeekIndicator: Bool {
        return showSeekIndicator && audioManager.isCurrentlyPlaying(post.id)
    }

    @State private var showSeekIndicator = false
@State private var seekProgress: Double = 0

    init(post: AudioConversation, isActive: Bool, onAppear: @escaping () -> Void) {
        self.post = post
        self.isActive = isActive
        self.onAppear = onAppear
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern Header Section
            VStack(spacing: 0) {
                // Header with location and time - Modern Design
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // Instagram-style location design
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
                    }
                    .padding(.bottom, 10)
                    
                    // Speakers Section
                    GeometryReader { geometry in
                        VStack {
                            HStack(spacing: geometry.size.width * 0.1) {
                                Spacer()
                                
                                speakerInfoView(
                                    name: post.host_name ?? "Host",
                                    image: post.host_image,
                                    isActive: audioManager.isPlaying,
                                    geometry: geometry
                                )
                                
                                speakerInfoView(
                                    name: post.user_name ?? "Guest",
                                    image: post.user_image,
                                    isActive: audioManager.isPlaying,
                                    geometry: geometry
                                )
                                
                                Spacer()
                            }
                            .padding(.vertical, geometry.size.height * 0.05)
                        }
                    }
                    .frame(height: 160)
                    
                    // Footer Section - Same as TwitterProfileView AudioPostCard
 /*                  VStack(spacing: 4) {
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
        .padding(.vertical, 12)*/




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
                .background(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.95),
                            Color.black.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
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
                .overlay(playbackOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .zIndex(showPlayIcon ? 10 : 1) // Ensure overlay appears above other elements
            }
            .alert("Playback Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
                Button("Retry") {
                    // ✅ FIXED: Use the shared audio manager's preparation method
                    audioManager.prepareAudioWithCachePriority(post)
                }
            } message: {
                Text(playbackError?.localizedDescription ?? "An unknown error occurred")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
        .contentShape(Rectangle())
        .onTapGesture {
            togglePlayback()
        }
        // Add this modifier to ensure tap gestures work properly
        .simultaneousGesture(TapGesture().onEnded {
            togglePlayback()
        })
        .onAppear {
            isVisible = true
            
            // Set initial active state
            audioManager.setActive(isActive)
            
            // ✅ FIXED: Ensure active posts are properly set up for auto-play
            if isActive {
                print("🎧 Setting up TikTok player for ACTIVE post \(post.id)")
                audioManager.setActiveConversation(post)
            } else {
                print("🎧 Inactive post \(post.id) appeared - no preparation needed")
            }
        }
        .onDisappear {
            isVisible = false
            stopSyncTimer()
            
            // ✅ FIXED: Stop audio when post becomes inactive
            if audioManager.isCurrentlyPlaying(post.id) {
                print("🔇 Stopping audio when post \(post.id) becomes inactive")
                audioManager.pause()
            }
            
            // Don't cleanup here - let the shared audio manager handle it
            // audioManager.cleanup() // REMOVED - causes infinite loop
            print("🎵 TikTok player view disappeared for post \(post.id)")
        }
        .onChange(of: isActive) { active in
            // Set the active state on the player
            audioManager.setActive(active)
            
            print("🎵 TikTok-style: Active state changed to \(active) for post \(post.id)")
            
            // Check if audio session is blocked before auto-playing
            guard !spacesViewModel.isAudioSessionBlocked else {
                print("🔇 Auto-play blocked - space is active")
                return
            }
            
            if active {
                // ✅ FIXED: Immediate auto-play for feed with async fallback
                print("🎵 TikTok-style: Post \(post.id) became active, attempting immediate auto-play")
                
                // Set the conversation as active (this handles preparation)
                audioManager.setActiveConversation(post)
                
                // ✅ FIXED: Try immediate play, then async fallback if needed
                if audioManager.isReadyForAutoPlay() && audioManager.isPreparedForConversation(post.id) {
                    print("✅ [TikTokStyleAudioPostCard] Immediate auto-play for post \(post.id)")
                    audioManager.play() // Use the correct play() method
                } else {
                    print("⏳ [TikTokStyleAudioPostCard] Post \(post.id) not ready yet, trying async fallback")
                    print("  - isReadyForAutoPlay: \(audioManager.isReadyForAutoPlay())")
                    print("  - isPreparedForConversation: \(audioManager.isPreparedForConversation(post.id))")
                    
                    // ✅ FIXED: Async fallback for cases where preparation takes time
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if self.isActive && self.audioManager.isReadyForAutoPlay() && self.audioManager.isPreparedForConversation(self.post.id) {
                            print("✅ [TikTokStyleAudioPostCard] Async auto-play for post \(self.post.id)")
                            self.audioManager.play()
                        } else {
                            print("⚠️ [TikTokStyleAudioPostCard] Async auto-play failed for post \(self.post.id)")
                            print("  - isActive: \(self.isActive)")
                            print("  - isReadyForAutoPlay: \(self.audioManager.isReadyForAutoPlay())")
                            print("  - isPreparedForConversation: \(self.audioManager.isPreparedForConversation(self.post.id))")
                        }
                    }
                }
            } else {
                // ✅ FIXED: Ensure audio stops when post becomes inactive
                if audioManager.isPlaying && audioManager.isCurrentlyPlaying(post.id) {
                    print("🎵 TikTok-style: Auto-pausing post \(post.id)")
                    audioManager.pause()
                }
            }
        }
        .onChange(of: audioManager.isPlaying) { playing in
            // ✅ FIXED: Prevent infinite loops by tracking state changes
            guard !isStateUpdateInProgress && lastAudioManagerPlayingState != playing else {
                print("🎵 TikTok-style: Skipping redundant playing state update for post \(post.id)")
                return
            }
            
            isStateUpdateInProgress = true
            lastAudioManagerPlayingState = playing
            
            // Sync local state with audio manager state
            isPlaying = playing
            
            // Hide play icon when playback stops
            if !playing && showPlayIcon {
                withAnimation(.easeOut(duration: 0.2)) {
                    showPlayIcon = false
                }
            }
            
            print("🎵 TikTok-style: Playback state changed to \(playing ? "playing" : "paused") for post \(post.id)")
            
            // Reset state update flag after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isStateUpdateInProgress = false
            }
        }
        .onChange(of: audioManager.isPrepared) { prepared in
            // ✅ FIXED: Prevent infinite loops by tracking state changes
            guard !isStateUpdateInProgress && lastAudioManagerPreparedState != prepared else {
                print("🎵 TikTok-style: Skipping redundant prepared state update for post \(post.id)")
                return
            }
            
            isStateUpdateInProgress = true
            lastAudioManagerPreparedState = prepared
            
            // Sync local isPrepared state with player state
            if prepared != isPrepared {
                isPrepared = prepared
                print("🎵 TikTok-style: Preparation state changed to \(prepared) for post \(post.id)")
                
                // ✅ FIXED: Immediate auto-play when preparation completes (if still active)
                if prepared && isActive && audioManager.isReadyForAutoPlay() && audioManager.isPreparedForConversation(post.id) {
                    print("🎵 TikTok-style: Auto-playing immediately after preparation completion")
                    audioManager.play() // Use the correct play() method
                } else if prepared && isActive {
                    print("🎵 TikTok-style: Preparation completed but auto-play conditions not met")
                    print("  - isActive: \(isActive)")
                    print("  - isReadyForAutoPlay: \(audioManager.isReadyForAutoPlay())")
                    print("  - isPreparedForConversation: \(audioManager.isPreparedForConversation(post.id))")
                    
                    // ✅ FIXED: Try async fallback for preparation completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if self.isActive && self.audioManager.isReadyForAutoPlay() && self.audioManager.isPreparedForConversation(self.post.id) {
                            print("🎵 TikTok-style: Async auto-play after preparation completion")
                            self.audioManager.play()
                        }
                    }
                } else if prepared && !isActive {
                    print("🎵 TikTok-style: Preparation completed but post \(post.id) is no longer active")
                }
            }
            
            // Reset state update flag after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isStateUpdateInProgress = false
            }
        }
        .id(post.id)
    }
    
    // ✅ REMOVED: setupAudioPlayer() method - no longer needed
    // We now use the shared audio manager for all audio operations
    
    private func startSyncTimer() {
        syncTimer?.invalidate()
    }
    
    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    private func cleanupAudioPlayer() {
        stopSyncTimer()
        seekWorkItem?.cancel()
        seekWorkItem = nil
        lastPlaybackPosition = audioManager.currentTime
        
        // Don't call cleanup here - let the shared audio manager handle it
        // audioManager.cleanup() // REMOVED - causes infinite loop
        
        // Reset local state
        isPrepared = false
        isScrubbing = false
        isUIEnabled = true
        showWaveform = false
    }
    
    private func speakerInfoView(name: String, image: String?, isActive: Bool, geometry: GeometryProxy) -> some View {
        let isHost = name == post.host_name
        let audioLevel = isHost ? hostAudioLevel : visitorAudioLevel
        let hasAudioURL = isHost ? (post.host_audio_url != nil) : (post.visitor_audio_url != nil)
        let speakerId = isHost ? Int64(post.host_id ?? 0) : Int64(post.user_id ?? 0)
        
        let speakingThreshold: Float = 0.08
        let overlapThreshold: Float = 0.12
        let activeSpeakerId = audioManager.activeSpeakerId
        let bothSpeakersActive = audioManager.bothSpeakersActive
        let isActiveSpeaker = activeSpeakerId == speakerId
        let isClearlySpeaking = audioLevel > speakingThreshold
        
        let isSpeaking: Bool = {
            if bothSpeakersActive {
                return audioLevel > overlapThreshold
            } else {
                return isActiveSpeaker && isClearlySpeaking
            }
        }()
        
        return VStack(spacing: 8) {
            ZStack {
                if let imageUrl = image {
                    CachedAsyncImage(url: imageUrl.safeURL()) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: min(geometry.size.width * 0.2, 100),
                                       height: min(geometry.size.width * 0.2, 100))
                                .clipShape(Circle())
                                .shadow(radius: 3)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSpeaking)
                        case .failure:
                            // ✅ FIXED: Use custom default image from assets (faster, no loading)
                            Image("ic_smalluser")
                                .resizable()
                                .scaledToFill()
                                .frame(width: min(geometry.size.width * 0.2, 100),
                                       height: min(geometry.size.width * 0.2, 100))
                                .clipShape(Circle())
                                .shadow(radius: 3)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSpeaking)
                        case .empty:
                            // ✅ FIXED: Use custom default image from assets (faster, no loading)
                            Image("ic_smalluser")
                                .resizable()
                                .scaledToFill()
                                .frame(width: min(geometry.size.width * 0.2, 100),
                                       height: min(geometry.size.width * 0.2, 100))
                                .clipShape(Circle())
                                .shadow(radius: 3)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSpeaking)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // ✅ UPDATED: Use same beautiful default avatar design as other views
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: min(geometry.size.width * 0.2, 100),
                                   height: min(geometry.size.width * 0.2, 100))
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSpeaking)
                    }
                    .clipShape(Circle())
                    .shadow(radius: 3)
                }
                
                if isSpeaking {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: min(geometry.size.width * 0.2, 100) + 10,
                               height: min(geometry.size.width * 0.2, 100) + 10)
                        .opacity(isSpeaking ? 1 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSpeaking)
                }
            }
            
            Text(name)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: geometry.size.width * 0.25)
                .opacity(isSpeaking ? 1 : 0.7)
                .animation(.easeInOut(duration: 0.2), value: isSpeaking)
            
            if hasAudioURL && audioManager.isPlaying && isSpeaking {
                AudioDetectionAnimation(
                    audioLevel: audioLevel,
                    progress: audioManager.progress
                )
                .frame(height: min(geometry.size.height * 0.02, 13))
                .opacity(1)
                .animation(.easeInOut(duration: 0.2), value: isSpeaking)
            }
        }
        .frame(width: geometry.size.width * 0.25)
    }
    
    @ViewBuilder
    private var playbackOverlay: some View {
        if showPlayIcon {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Play/Pause icon
                Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .transition(.opacity.combined(with: .scale))
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // TikTok-style: Debounced seek operation (same as TwitterProfileView)
    private func performSeekOperation() {
        guard audioManager.duration > 0 else {
            print("⚠️ Cannot seek - duration not available")
            return
        }
        
        // ✅ FIXED: Use main queue since we're using shared audio manager
        DispatchQueue.main.async {
            audioManager.seek(to: dragProgress)
        }
    }
    
    private func togglePlayback() {
        let hasHostAudio = post.host_audio_url != nil && !post.host_audio_url!.isEmpty
        let hasVisitorAudio = post.visitor_audio_url != nil && !post.visitor_audio_url!.isEmpty
        let hasAudio = hasHostAudio || hasVisitorAudio
        
        guard hasAudio else {
            print("❌ [TikTokStyleAudioPostCard] No audio available for post \(post.id)")
            return
        }
        
        // Check if audio session is blocked (space is active)
        guard !spacesViewModel.isAudioSessionBlocked else {
            print("🔇 [TikTokStyleAudioPostCard] Audio blocked - space is active")
            return
        }
        
        print("🎵 [TikTokStyleAudioPostCard] Manual toggle playback called for post \(post.id)")
        
        // Show overlay immediately
        withAnimation(.spring(response: 0.3)) {
            showPlayIcon = true
        }
        
        // Schedule overlay to hide after consistent delay
        scheduleOverlayHide()
        
        // ✅ FIXED: Simplified toggle logic
        if !audioManager.isPreparedForConversation(post.id) {
            print("🎧 [TikTokStyleAudioPostCard] Not prepared for \(post.id), preparing...")
            audioManager.setActiveConversation(post)
            
            // Simple delay for manual playback after preparation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.audioManager.isPreparedForConversation(self.post.id) {
                    print("✅ [TikTokStyleAudioPostCard] Preparation completed for \(self.post.id), now playing")
                    self.audioManager.play()
                } else {
                    print("❌ [TikTokStyleAudioPostCard] Preparation failed for \(self.post.id)")
                }
            }
            return
        }
        
        // ✅ FIXED: Simple play/pause logic
        if audioManager.isCurrentlyPlaying(post.id) {
            print("⏸️ [TikTokStyleAudioPostCard] Pausing \(post.id)")
            audioManager.pause()
        } else {
            print("▶️ [TikTokStyleAudioPostCard] Playing \(post.id)")
            audioManager.play()
        }
    }
    
    /**
     Schedules the overlay to hide after a consistent delay.
     This ensures overlay timing is consistent across all interactions.
     */
    private func scheduleOverlayHide() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                showPlayIcon = false
            }
        }
    }
    

}

struct RemoveUserConfirmationModal: View {
    @Binding var isPresented: Bool
    let userName: String
    let onConfirm: () -> Void
    @State private var animateGradient = false
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            // Background overlay with blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .blur(radius: 3)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }
            
            // Modal content
            VStack(spacing: 24) {
                // Header with gradient animation
                ZStack {
                    LinearGradient(
                        colors: [.red.opacity(0.8), .orange.opacity(0.8)],
                        startPoint: animateGradient ? .topLeading : .bottomTrailing,
                        endPoint: animateGradient ? .bottomTrailing : .topLeading
                    )
                    .opacity(0.9)
                    .blur(radius: 0.5)
                    
                    VStack(spacing: 16) {
                        Image(systemName: "person.fill.xmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(animateContent ? 1.1 : 1)
                        
                        Text("Remove \(userName)?")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 32)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // Warning message
                Text("Are you sure you want to remove this user from the space? This action cannot be undone.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Action buttons
                HStack(spacing: 16) {
                    // Cancel button
                    Button(action: {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Cancel")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                        )
                    }
                    
                    // Remove button
                    Button(action: {
                        onConfirm()
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill.xmark")
                            Text("Remove")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.red.opacity(0.9), .orange.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [.red.opacity(0.3), .orange.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
            .scaleEffect(animateContent ? 1 : 0.9)
            .opacity(animateContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateContent = true
            }
        }
    }
}

// ✅ REMOVED: Duplicate ProfileSheetCoordinator - now defined in TwitterProfileView.swift

// ✅ ADDED: Two Users Reaction Sheet
struct TwoUsersReactionSheet: View {
    let user1Id: Int64
    let user2Id: Int64
    let post: AudioConversation
    @Binding var showReactionSheet: Bool
    
    @EnvironmentObject var tweetData: TweetData
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    
    @State private var reactions: [UserReaction] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMoreData = true
    @State private var currentPage = 1
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateAppearance = false
    @State private var isPaginationTriggered = false
    @State private var lastScrollCheck = Date()
    
    // ✅ ADDED: Reaction submission states
    @State private var showUserSelection = false
    @State private var showReactionSelection = false
    @State private var selectedTargetUserId: Int64?
    @State private var selectedReactionType: ReactionType?
    @State private var isSubmittingReaction = false
    @State private var showSubmissionError = false
    @State private var submissionErrorMessage = ""
    
    // ✅ REMOVED: Profile navigation state - using direct fullScreenCover in child views
    
    private let pageSize = 20
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Content
                if reactions.isEmpty && !isLoading {
                    emptyStateView
                } else {
                    reactionsListView
                }
            }
            
            // ✅ FIXED: Floating Action Button positioned absolutely
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    reactionSubmissionButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
            }
            .zIndex(1) // Ensure button stays on top
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
        .onAppear {
            // Start appearance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateAppearance = true
            }
            
            // Load initial data
            loadReactions()
        }
        .onDisappear {
            animateAppearance = false
        }
        .alert("Error", isPresented: $showError) {
            Button("Retry") {
                loadReactions()
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        // ✅ ADDED: Reaction submission sheets and alerts
        .sheet(isPresented: $showUserSelection) {
            UserSelectionSheet(
                user1Id: user1Id,
                user2Id: user2Id,
                post: post,
                showUserSelection: $showUserSelection,
                onUserSelected: { targetUserId in
                    selectedTargetUserId = targetUserId
                    showUserSelection = false
                    showReactionSelection = true
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showReactionSelection) {
            ReactionSelectionSheet(
                selectedReactionType: $selectedReactionType,
                showReactionSelection: $showReactionSelection,
                onReactionSelected: { reactionType in
                    selectedReactionType = reactionType
                    showReactionSelection = false
                    submitReaction()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Submission Error", isPresented: $showSubmissionError) {
            Button("Retry") {
                submitReaction()
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(submissionErrorMessage)
        }
        // ✅ REMOVED: Profile navigation - using direct fullScreenCover in child views
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Navigation bar
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showReactionSheet = false
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                Text("Reactions Between Users")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Placeholder for balance
                Circle()
                    .fill(.clear)
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Post info
            VStack(spacing: 12) {
                // Topic
                if !post.topic.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "number")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(post.topic)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.8)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                }
                
                // Users info
                HStack(spacing: 16) {
                    // User 1 (Host)
                    UserInfoView(
                        name: post.host_name ?? "Host",
                        image: post.host_image,
                        userId: post.host_id,
                        username: post.host_name ?? "host_\(post.host_id)", // Use actual host username
                        isHost: true
                    )
                    
                    // VS indicator
                    VStack(spacing: 4) {
                        Text("VS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 1, height: 20)
                    }
                    
                    // User 2 (Guest)
                    UserInfoView(
                        name: post.user_name ?? "Guest",
                        image: post.user_image,
                        userId: post.user_id,
                        username: post.user_name ?? "user_\(post.user_id)", // Use actual user username
                        isHost: false
                    )
                }
            }
            .padding(.horizontal)
            .scaleEffect(animateAppearance ? 1 : 0.9)
            .opacity(animateAppearance ? 1 : 0)
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - User Info View
    private struct UserInfoView: View {
        let name: String
        let image: String?
        let userId: Int64
        let username: String
        let isHost: Bool
        
        @EnvironmentObject var tweetData: TweetData
        @EnvironmentObject var spacesViewModel: SpacesViewModel
        @State private var showProfile = false
        
        var body: some View {
            Button {
                // ✅ DIRECT: Show profile directly
                showProfile = true
            } label: {
                VStack(spacing: 8) {
                    // Avatar
                    CachedAsyncImage(url: (image ?? "").safeURL()) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(radius: 4)
                        case .failure, .empty:
                            // ✅ FIXED: Use custom default image from assets (faster, no loading)
                            Image("ic_smalluser")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(radius: 4)
                        @unknown default:
                            Image("ic_smalluser")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(radius: 4)
                        }
                    }
                    
                    // Name
                    Text(name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Role badge
                    Text(isHost ? "Host" : "Guest")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    isHost ?
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
            }
            .buttonStyle(PlainButtonStyle())
            // ✅ DIRECT: Profile navigation with fullScreenCover
            .fullScreenCover(isPresented: $showProfile) {
                TwitterProfileView(
                    userId: userId,
                    username: username,
                    initialProfile: nil
                )
                .environmentObject(tweetData)
                .environmentObject(spacesViewModel)
                .interactiveDismissDisabled()
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "heart.slash")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("No Reactions Yet")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("When users react to each other, you'll see their reactions here")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Spacer()
        }
        .padding()
        .scaleEffect(animateAppearance ? 1 : 0.9)
        .opacity(animateAppearance ? 1 : 0)
    }
    
    // MARK: - Reactions List View
    private var reactionsListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Top anchor for scroll control
                    Color.clear
                        .frame(height: 1)
                        .id("top")
                    
                    ForEach(Array(self.reactions.enumerated()), id: \.element.id) { index, reaction in
                        ReactionRowView(
                            reaction: reaction,
                            user1Id: self.user1Id,
                            post: self.post
                        )
                            .onAppear {
                                // Trigger load more when the last item appears
                                if index == self.reactions.count - 1 && self.hasMoreData && !self.isLoadingMore && !self.isPaginationTriggered {
                                    print("🔄 [UI] Last reaction appeared, triggering load more")
                                    self.isPaginationTriggered = true
                                    self.loadMoreReactions()
                                }
                            }
                    }
                    
                    // Loading indicator at bottom
                    if self.isLoadingMore {
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
                .padding(.bottom, 100) // Add space for floating action button
            }
            .background(
                // Instagram-style scroll tracking
                GeometryReader { geometry in
                    Color.clear
                        .onChange(of: geometry.frame(in: .global).minY) { _ in
                            self.handleScrollPagination()
                        }
                }
            )
        }
    }
    
    // MARK: - Reaction Row View
    private struct ReactionRowView: View {
        let reaction: UserReaction
        let user1Id: Int64
        let post: AudioConversation
        
        @EnvironmentObject var tweetData: TweetData
        @EnvironmentObject var spacesViewModel: SpacesViewModel
        @State private var showProfile = false
        
        // Helper function to get natural reaction text with target user
        private func getReactionTextWithTarget(_ reactionType: String, targetUserId: Int64) -> String {
            // Handle case where targetUserId is 0 (fallback for nil)
            let targetUsername = (targetUserId == 0 || targetUserId == user1Id) ? post.host_name : post.user_name
            
            let reactionMap: [String: String] = [
                "like": "likes @\(targetUsername)",
                "love": "loves @\(targetUsername)",
                "hot": "thinks @\(targetUsername) is hot",
                "smart": "thinks @\(targetUsername) is smart",
                "funny": "thinks @\(targetUsername) is funny",
                "kind": "thinks @\(targetUsername) is kind",
                "brave": "thinks @\(targetUsername) is brave",
                "cool": "thinks @\(targetUsername) is cool",
                "sweet": "thinks @\(targetUsername) is sweet",
                "strong": "thinks @\(targetUsername) is strong",
                "friendly": "thinks @\(targetUsername) is friendly",
                "honest": "thinks @\(targetUsername) is honest",
                "generous": "thinks @\(targetUsername) is generous",
                "fit": "thinks @\(targetUsername) is fit",
                "creative": "thinks @\(targetUsername) is creative",
                "stupid": "thinks @\(targetUsername) is stupid",
                "mean": "thinks @\(targetUsername) is mean",
                "fake": "thinks @\(targetUsername) is fake",
                "lazy": "thinks @\(targetUsername) is lazy"
            ]
            
            return reactionMap[reactionType.lowercased()] ?? "reacted to @\(targetUsername)"
        }
        
        var body: some View {
            HStack(spacing: 12) {
                // Reactor avatar - Only this is clickable for navigation
                Button {
                    // ✅ DIRECT: Show profile directly
                    showProfile = true
                } label: {
                    CachedAsyncImage(url: reaction.reactorUser.avatar.safeURL()) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(radius: 4)
                        case .failure, .empty:
                            // ✅ FIXED: Use custom default image from assets (faster, no loading)
                            Image("ic_smalluser")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(radius: 4)
                        @unknown default:
                            Image("ic_smalluser")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(radius: 4)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    // Natural reaction text with target user
                    HStack(spacing: 8) {
                        Text(reaction.reactorUser.nickname)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(getReactionTextWithTarget(reaction.reactionName, targetUserId: reaction.targetUserId ?? 0))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text(reaction.reactionIcon)
                            .font(.system(size: 16))
                    }
                    
                    // Time
                    Text(TwoUsersReactionSheet.formatReactionTime(reaction.createdOn))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
            // ✅ DIRECT: Profile navigation with fullScreenCover
            .fullScreenCover(isPresented: $showProfile) {
                TwitterProfileView(
                    userId: reaction.reactorUser.id,
                    username: reaction.reactorUser.username,
                    initialProfile: nil
                )
                .environmentObject(tweetData)
                .environmentObject(spacesViewModel)
                .interactiveDismissDisabled()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadReactions() {
        guard !isLoading else { return }
        
        isLoading = true
        currentPage = 1
        
        Task {
            do {
                let (newReactions, pager) = try await tweetData.getReactionsToTwoUsersList(
                    user1Id: user1Id,
                    user2Id: user2Id,
                    page: currentPage,
                    pageSize: pageSize
                )
                
                await MainActor.run {
                    self.reactions = newReactions
                    self.hasMoreData = newReactions.count < pager.totalRows
                    self.isLoading = false
                    print("✅ Loaded \(newReactions.count) reactions (total: \(pager.totalRows))")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.showError = true
                    self.errorMessage = error.localizedDescription
                    print("❌ Error loading reactions: \(error)")
                }
            }
        }
    }
    
    private func loadMoreReactions() {
        guard !isLoadingMore && hasMoreData else {
            isPaginationTriggered = false
            return
        }
        
        isLoadingMore = true
        currentPage += 1
        
        Task {
            do {
                let (newReactions, pager) = try await tweetData.getReactionsToTwoUsersList(
                    user1Id: user1Id,
                    user2Id: user2Id,
                    page: currentPage,
                    pageSize: pageSize
                )
                
                await MainActor.run {
                    self.reactions.append(contentsOf: newReactions)
                    self.hasMoreData = self.reactions.count < pager.totalRows
                    self.isLoadingMore = false
                    self.isPaginationTriggered = false
                    print("✅ Loaded \(newReactions.count) more reactions (total: \(self.reactions.count))")
                }
            } catch {
                await MainActor.run {
                    self.isLoadingMore = false
                    self.isPaginationTriggered = false
                    self.showError = true
                    self.errorMessage = error.localizedDescription
                    print("❌ Error loading more reactions: \(error)")
                }
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
        
        // Instagram-style: Trigger load more when near bottom
        if hasMoreData && !isLoadingMore {
            print("🔄 [SCROLL] Triggering load more reactions")
            isPaginationTriggered = true
            loadMoreReactions()
        }
    }
    
    static func formatReactionTime(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
    
    // ✅ ADDED: Reaction Submission UI Components
    
    private var reactionSubmissionButton: some View {
        Button(action: {
            showUserSelection = true
        }) {
            ZStack {
                // Background circle with glass effect
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                
                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSubmittingReaction ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSubmittingReaction)
    }
    
    // ✅ ADDED: Reaction Submission Logic
    
    private func submitReaction() {
        guard let targetUserId = selectedTargetUserId,
              let reactionType = selectedReactionType else {
            print("❌ Missing target user or reaction type")
            return
        }
        
        isSubmittingReaction = true
        
        // ✅ OPTIMISTIC UI UPDATE: Add reaction to local array immediately
        let currentUser = tweetData.user
        
        // ✅ FIXED: Create proper default UserProfile with all required fields
        let defaultUser = UserProfile(
            id: 0,
            nickname: "Unknown User",
            username: "Unknown",
            avatar: "",
            isFollowing: false,
            status: 0,
            isAdmin: false,
            isFriend: false,
            follows: 0,
            followings: 0,
            tweetsCount: 0,
            createdOn: 0,
            categories: nil,
            reactionCounts: nil,
            isOnline: false,
            phone: nil,
            activation: nil,
            balance: nil
        )
        
        let optimisticReaction = UserReaction(
            id: Int64.random(in: 1000000...9999999), // Temporary ID
            reactorUser: (currentUser ?? defaultUser).toReactionUserProfile(),
            targetUserId: targetUserId,
            targetUser: nil,
            reactionTypeId: reactionType.id,
            reactionName: reactionType.name,
            reactionIcon: reactionType.icon,
            createdOn: Int64(Date().timeIntervalSince1970)
        )
        
        // ✅ UPSERT LOGIC: Check if user already has a reaction for this target user
        let currentUserId = currentUser?.id ?? 0
        let existingReactionIndex = reactions.firstIndex { reaction in
            reaction.reactorUser.id == currentUserId &&
            reaction.targetUserId == targetUserId
        }
        
        if let existingIndex = existingReactionIndex {
            // ✅ UPDATE: Replace existing reaction with new one
            reactions[existingIndex] = optimisticReaction
            print("✅ Optimistic UI update: Updated existing reaction for user \(targetUserId)")
        } else {
            // ✅ INSERT: Add new reaction to beginning
            reactions.insert(optimisticReaction, at: 0)
            print("✅ Optimistic UI update: Added new reaction for user \(targetUserId)")
        }
        
        Task {
            do {
                try await tweetData.createUserReaction(
                    targetUserId: targetUserId,
                    reactionTypeId: reactionType.id
                )
                
                await MainActor.run {
                    isSubmittingReaction = false
                    
                    // Reset selection states
                    selectedTargetUserId = nil
                    selectedReactionType = nil
                    
                    print("✅ Reaction submitted successfully")
                    
                    // ✅ DISMISS SHEET: Close reaction selection after success
                    showReactionSelection = false
                }
            } catch {
                await MainActor.run {
                    isSubmittingReaction = false
                    showSubmissionError = true
                    submissionErrorMessage = error.localizedDescription
                    print("❌ Failed to submit reaction: \(error)")
                    
                    // ✅ REVERT OPTIMISTIC UPDATE: Handle both update and insert cases
                    let currentUserId = currentUser?.id ?? 0
                    let existingReactionIndex = reactions.firstIndex { reaction in
                        reaction.reactorUser.id == currentUserId &&
                        reaction.targetUserId == targetUserId
                    }
                    
                    if let existingIndex = existingReactionIndex {
                        // ✅ REVERT UPDATE: Remove the updated reaction
                        reactions.remove(at: existingIndex)
                        print("🔄 Reverted optimistic UI update (removed updated reaction) due to API failure")
                    }
                    // Note: For new reactions, they're already at index 0, so removing at index 0 will work
                }
            }
        }
    }
}

// ✅ ADDED: Conversation Reaction Button Component
struct ConversationReactionButton: View {
    let conversation: AudioConversation
    let user1Id: Int64
    let user2Id: Int64
    
    @EnvironmentObject var tweetData: TweetData
    @State private var showReactionSheet = false
    @State private var animateReactionButton = false
    
    var body: some View {
        Button(action: {
            showReactionSheet = true
        }) {
            ZStack {
                // Background circle with glass effect
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.red.opacity(0.6), .pink.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Heart icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateReactionButton ? 1.1 : 1.0)
                
                // Pulse animation
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.red.opacity(0.3), .pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 54, height: 54)
                    .scaleEffect(animateReactionButton ? 1.3 : 1.0)
                    .opacity(animateReactionButton ? 0 : 0.6)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showReactionSheet) {
            TwoUsersReactionSheet(
                user1Id: user1Id,
                user2Id: user2Id,
                post: conversation,
                showReactionSheet: $showReactionSheet
            )
            .environmentObject(tweetData)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
        }
        .onAppear {
            // Start reaction button animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateReactionButton = true
            }
        }
    }
}

// ✅ ADDED: User Selection Sheet
struct UserSelectionSheet: View {
    let user1Id: Int64
    let user2Id: Int64
    let post: AudioConversation
    @Binding var showUserSelection: Bool
    let onUserSelected: (Int64) -> Void
    
    @EnvironmentObject var tweetData: TweetData
    @State private var animateAppearance = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Choose User to React To")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Select which user you want to give a reaction to")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            // User Options
            VStack(spacing: 16) {
                // Host User
                userOptionCard(
                    userId: user1Id,
                    name: post.host_name ?? "Host",
                    image: post.host_image,
                    role: "Host",
                    gradientColors: [.blue, .purple]
                ) {
                    onUserSelected(user1Id)
                }
                
                // Guest User
                userOptionCard(
                    userId: user2Id,
                    name: post.user_name ?? "Guest",
                    image: post.user_image,
                    role: "Guest",
                    gradientColors: [.orange, .red]
                ) {
                    onUserSelected(user2Id)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Cancel Button
            Button(action: {
                showUserSelection = false
            }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
            }
            .padding(.bottom, 20)
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
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateAppearance = true
            }
        }
    }
    
    private func userOptionCard(
        userId: Int64,
        name: String,
        image: String?,
        role: String,
        gradientColors: [Color],
        action: @escaping () -> Void
    ) -> some View {
        let isCurrentUser = userId == tweetData.user?.id
        
        return Button(action: {
            if !isCurrentUser {
                action()
            }
        }) {
            HStack(spacing: 16) {
                // Avatar
                CachedAsyncImage(url: (image ?? "").safeURL()) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(radius: 6)
                    case .failure, .empty:
                        // ✅ FIXED: Use custom default image from assets (faster, no loading)
                        Image("ic_smalluser")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(radius: 6)
                    @unknown default:
                        Image("ic_smalluser")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(radius: 6)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Name
                    Text(name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(isCurrentUser ? .secondary : .primary)
                    
                    // Role badge
                    Text(role)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: isCurrentUser ? [.gray, .gray.opacity(0.7)] : gradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    
                    // Show "You" indicator for current user
                    if isCurrentUser {
                        Text("You")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                // Arrow icon or disabled indicator
                if isCurrentUser {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isCurrentUser ? Color.gray.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isCurrentUser ? Color.gray.opacity(0.3) : Color.gray.opacity(0.1),
                                lineWidth: 1
                            )
                    )
            )
            .background(.ultraThinMaterial)
            .scaleEffect(animateAppearance ? 1 : 0.9)
            .opacity(animateAppearance ? (isCurrentUser ? 0.6 : 1.0) : 0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isCurrentUser)
    }
}

// ✅ ADDED: Reaction Selection Sheet
struct ReactionSelectionSheet: View {
    @Binding var selectedReactionType: ReactionType?
    @Binding var showReactionSelection: Bool
    let onReactionSelected: (ReactionType) -> Void
    
    @State private var animateAppearance = false
    @State private var selectedCategory: ReactionCategory = .positive
    
    enum ReactionCategory: String, CaseIterable {
        case positive = "Positive"
        case negative = "Negative"
        
        var reactions: [LocalReactionType] {
            switch self {
            case .positive:
                return LocalReactionType.positiveReactions
            case .negative:
                return LocalReactionType.negativeReactions
            }
        }
        
        var gradientColors: [Color] {
            let positiveColors = [Color.green, Color.blue]
            let negativeColors = [Color.red, Color.orange]
            
            switch self {
            case .positive:
                return positiveColors
            case .negative:
                return negativeColors
            }
        }
    }
    
    // Local reaction type to avoid import issues
    struct LocalReactionType: Identifiable, Hashable {
        let id: Int64
        let name: String
        let description: String
        let icon: String
        let isPositive: Bool
        
        static let positiveReactions: [LocalReactionType] = {
            let reactions = [
                LocalReactionType(id: 1, name: "like", description: "Basic approval, neutral positive", icon: "👍", isPositive: true),
                LocalReactionType(id: 2, name: "love", description: "Strong emotional connection, affection", icon: "❤️", isPositive: true),
                LocalReactionType(id: 3, name: "hot", description: "Attractive, good-looking", icon: "🔥", isPositive: true),
                LocalReactionType(id: 4, name: "smart", description: "Intelligent, clever", icon: "🧠", isPositive: true),
                LocalReactionType(id: 5, name: "funny", description: "Humorous, entertaining", icon: "😂", isPositive: true),
                LocalReactionType(id: 6, name: "kind", description: "Compassionate, helpful", icon: "🤗", isPositive: true),
                LocalReactionType(id: 7, name: "brave", description: "Courageous, bold", icon: "💪", isPositive: true),
                LocalReactionType(id: 8, name: "cool", description: "Awesome, impressive", icon: "😎", isPositive: true),
                LocalReactionType(id: 9, name: "sweet", description: "Nice, pleasant", icon: "🍯", isPositive: true),
                LocalReactionType(id: 10, name: "strong", description: "Resilient, powerful", icon: "💪", isPositive: true),
                LocalReactionType(id: 11, name: "friendly", description: "Approachable, sociable", icon: "😊", isPositive: true),
                LocalReactionType(id: 12, name: "honest", description: "Truthful, trustworthy", icon: "🤝", isPositive: true),
                LocalReactionType(id: 13, name: "generous", description: "Giving, selfless", icon: "🎁", isPositive: true),
                LocalReactionType(id: 14, name: "fit", description: "Athletic, in good shape", icon: "🏃", isPositive: true),
                LocalReactionType(id: 15, name: "creative", description: "Artistic, innovative", icon: "🎨", isPositive: true)
            ]
            return reactions
        }()
        
        static let negativeReactions: [LocalReactionType] = {
            let reactions = [
                LocalReactionType(id: 16, name: "stupid", description: "Not smart, poor thinking", icon: "🤦", isPositive: false),
                LocalReactionType(id: 17, name: "mean", description: "Unkind, cruel", icon: "😠", isPositive: false),
                LocalReactionType(id: 18, name: "fake", description: "Dishonest, inauthentic", icon: "🎭", isPositive: false),
                LocalReactionType(id: 19, name: "lazy", description: "Not hardworking", icon: "😴", isPositive: false)
            ]
            return reactions
        }()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Button(action: {
                        showReactionSelection = false
                    }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Spacer()
                    
                    Text("Choose Reaction")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Placeholder for balance
                    Circle()
                        .fill(.clear)
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                
                // Category Tabs
                let categories = ReactionCategory.allCases
                HStack(spacing: 0) {
                    ForEach(categories, id: \.self) { category in
                        let isSelected = selectedCategory == category
                        let textColor = isSelected ? Color.primary : Color.secondary
                        let gradientColors = category.gradientColors
                        
                        Button(action: {
                            withAnimation(.spring()) {
                                selectedCategory = category
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(category.rawValue)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(textColor)
                                
                                let tabIndicator = Rectangle()
                                    .fill(
                                        isSelected ?
                                        AnyShapeStyle(LinearGradient(
                                            colors: gradientColors,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )) : AnyShapeStyle(Color.clear)
                                    )
                                    .frame(height: 3)
                                
                                tabIndicator
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Reactions Grid
            ScrollView {
                let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
                let reactions = selectedCategory.reactions
                
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(reactions) { reaction in
                        reactionCard(reaction)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            let animation = Animation.spring(response: 0.6, dampingFraction: 0.8)
            withAnimation(animation) {
                animateAppearance = true
            }
        }
    }
    
    private func reactionCard(_ reaction: LocalReactionType) -> some View {
        let reactionColor = getReactionColor(reaction)
        let gradientColors = [reactionColor, reactionColor.opacity(0.6)]
        
        return Button(action: {
            // Convert LocalReactionType to ReactionType for the callback
            let reactionType = ReactionType(
                id: reaction.id,
                name: reaction.name,
                description: reaction.description,
                icon: reaction.icon,
                color: "#4ECDC4", // Default color
                isPositive: reaction.isPositive
            )
            onReactionSelected(reactionType)
        }) {
            VStack(spacing: 12) {
                // Reaction Icon
                Text(reaction.icon)
                    .font(.system(size: 32))
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                    .shadow(color: reactionColor.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Reaction Name
                Text(reaction.name.capitalized)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Reaction Description
                Text(reaction.description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(animateAppearance ? 1 : 0.8)
            .opacity(animateAppearance ? 1 : 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Helper function to get reaction color without hex extension
    private func getReactionColor(_ reaction: LocalReactionType) -> Color {
        switch reaction.id {
        case 1: return .teal      // like
        case 2: return .red       // love
        case 3: return .orange    // hot
        case 4: return .purple    // smart
        case 5: return .yellow    // funny
        case 6: return .green     // kind
        case 7: return .orange    // brave
        case 8: return .blue      // cool
        case 9: return .yellow    // sweet
        case 10: return .gray     // strong
        case 11: return .purple   // friendly
        case 12: return .cyan     // honest
        case 13: return .pink     // generous
        case 14: return .green    // fit
        case 15: return .pink     // creative
        case 16: return .red      // stupid
        case 17: return .red      // mean
        case 18: return .gray     // fake
        case 19: return .gray     // lazy
        default: return .blue
        }
    }
}


