//
//  ReactionsFeedView.swift
//  Spaces
//
//  Created by AI Assistant on 2025.
//

import SwiftUI
import AVFoundation
import AVKit

struct ReactionsFeedView: View {
    @EnvironmentObject private var audioManager: WebMAudioPlaybackManager
    @EnvironmentObject private var tweetData: TweetData
    @EnvironmentObject private var spacesViewModel: SpacesViewModel
    @Namespace private var namespace
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.black.ignoresSafeArea()
            
            // Content Layer
            VStack(spacing: 0) {
                // Header
                ReactionsHeaderView()
                
                // Feed Content
                ReactionsFeedContentView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            print("📱 ReactionsFeedView appeared")
            // Load initial reactions if needed
            if tweetData.reactionsFeedReactions.isEmpty {
                Task {
                    await tweetData.loadReactionsFeed()
                }
            }
        }
        .onDisappear {
            print("📱 ReactionsFeedView disappeared")
        }
    }
}

// MARK: - Reactions Header View
struct ReactionsHeaderView: View {
    var body: some View {
        HStack {
            Text("Reactions")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Global reactions indicator
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                
                Text("Live Reactions")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 60) // Account for safe area
        .padding(.bottom, 16)
    }
}

// MARK: - Reactions Feed Content View
struct ReactionsFeedContentView: View {
    @EnvironmentObject private var audioManager: WebMAudioPlaybackManager
    @EnvironmentObject private var tweetData: TweetData
    
    @State private var isInitialLoad = true
    @State private var isViewActive = false
    @State private var currentCenteredIndex: Int = 0 // ✅ Keep: Track most centered reaction
    
    private let loadDebouncer = Debouncer(delay: 0.5)
    
    private var reactions: [UserReaction] {
        return tweetData.reactionsFeedReactions
    }
    
    private func handleScrollPosition() {
        // ✅ FIXED: Only save position when view is actually active
        guard isViewActive else { return }
        
        print("💾 [SCROLL] Saving reaction position at index: \(currentCenteredIndex)")
        tweetData.saveReactionPosition(index: currentCenteredIndex)
    }
    
    var body: some View {
        if tweetData.reactionsFeedIsLoading && reactions.isEmpty {
            TikTokLoadingView(size: 60, color: .white)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(reactions.enumerated()), id: \.element.id) { index, reaction in
                            ReactionCardView(reaction: reaction)
                                .id("reaction-\(reaction.id)")
                                .onAppear {
                                    // ✅ FIXED: Only update current centered index, don't save position here
                                    currentCenteredIndex = index
                                    
                                    // Preload reactions when they become visible
                                    preloadReactions(for: index)
                                    
                                    // Load more reactions when approaching end
                                    if index >= reactions.count - 3 &&
                                       !tweetData.isLoadingMoreReactions &&
                                       tweetData.reactionsFeedHasMoreData {
                                        
                                        print("📄 [SCROLL] Triggering load more reactions (approaching end)")
                                        Task {
                                            await loadDebouncer.debounce {
                                                await tweetData.loadMoreReactionsFeed()
                                            }
                                        }
                                    }
                                }
                                .onDisappear {
                                    // ✅ FIXED: Don't save position on every item disappear - this causes infinite loop
                                    // Only update current centered index if needed
                                }
                        }
                        
                        // Loading indicator at bottom
                        if tweetData.isLoadingMoreReactions {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(.white)
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        }
                        
                        // End of feed indicator
                        if !tweetData.reactionsFeedHasMoreData && !reactions.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.green)

                                }
                                .padding(.vertical, 20)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .onAppear {
                    print("🎯 ReactionsFeedContentView appeared")
                    isViewActive = true
                    
                    // Restore position when view appears
                    if isInitialLoad {
                        isInitialLoad = false
                        let (index, _) = tweetData.restoreReactionPosition()
                        print("📊 Restoring reaction position to index: \(index)")
                        
                        // Ensure index is valid and scroll to it
                        if !reactions.isEmpty && index >= 0 && index < reactions.count {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo("reaction-\(reactions[index].id)", anchor: .top)
                                }
                            }
                        }
                    }
                }
                .onDisappear {
                    print("🎯 ReactionsFeedContentView disappeared")
                    isViewActive = false
                    handleScrollPosition()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    print("📱 App going to background - saving reaction position")
                    
                    // ✅ FIXED: Only save position when view is actually active
                    guard isViewActive else { return }
                    
                    print("💾 [SCROLL] App background, saving current centered position at index: \(currentCenteredIndex)")
                    tweetData.saveReactionPosition(index: currentCenteredIndex)
                }
                .refreshable {
                    await MainActor.run {
                        print("🔄 Pull to refresh triggered for reactions")
                        Task {
                            await tweetData.refreshReactionsFeed()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Preloading Logic
    
    /**
     Preloads reactions for smooth scrolling experience.
     This ensures content is ready when user scrolls to it.
     
     - Parameter index: The current reaction index
     */
    private func preloadReactions(for index: Int) {
        guard reactions.indices.contains(index) else { 
            print("⚠️ [REACTIONS] Invalid index \(index) for reactions count \(reactions.count)")
            return 
        }
        
        // Preload next 3 reactions for smooth forward scrolling
        let nextIndices = [index + 1, index + 2, index + 3].filter { $0 < reactions.count }
        
        // Preload previous 2 reactions for smooth backward scrolling
        let previousIndices = [index - 1, index - 2].filter { $0 >= 0 }
        
        let allPreloadIndices = nextIndices + previousIndices
        
        print("🎯 [REACTIONS] Preloading reactions for indices: \(allPreloadIndices)")
        print("🎯 [REACTIONS] Next indices: \(nextIndices), Previous indices: \(previousIndices)")
        
        // ✅ FIXED: Add error handling and validation for preloading
        for i in allPreloadIndices {
            guard i < reactions.count else {
                print("⚠️ [REACTIONS] Index \(i) out of bounds for reactions count \(reactions.count)")
                continue
            }
            
            let reaction = reactions[i]
            let isNext = nextIndices.contains(i)
            let isPrevious = previousIndices.contains(i)
            
            print("🎯 [REACTIONS] Preloading reaction \(reaction.id) (\(isNext ? "NEXT" : isPrevious ? "PREVIOUS" : "OTHER"))")
            print("🎯 [REACTIONS] Reaction type: \(tweetData.getReactionTypeName(reaction.reactionTypeId))")
            print("🎯 [REACTIONS] Reactor: \(reaction.reactorUser.nickname ?? reaction.reactorUser.username)")
        }
        
        print("✅ [REACTIONS] Preloading completed for \(allPreloadIndices.count) reactions")
    }
}

// MARK: - Reaction Card View
struct ReactionCardView: View {
    let reaction: UserReaction
    @EnvironmentObject private var tweetData: TweetData
    @EnvironmentObject private var spacesViewModel: SpacesViewModel
    
    @State private var showReactorProfile = false
    @State private var showTargetProfile = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Reaction content
            VStack(spacing: 24) {
                // User info - Reactor and Target with bigger images
                VStack(spacing: 20) {
                    // Reactor user (who gave the reaction) - Bigger image, cleaner layout
                    HStack(spacing: 16) {
                        Button {
                            showReactorProfile = true
                        } label: {
                            AsyncImage(url: URL(string: reaction.reactorUser.avatar ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 70, height: 70) // ✅ BIGGER: Increased from 50 to 70
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 2))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(reaction.reactorUser.nickname ?? reaction.reactorUser.username)
                                .font(.system(size: 20, weight: .bold, design: .rounded)) // ✅ BIGGER: Increased font size
                                .foregroundColor(.white)
                            
                            Text("@\(reaction.reactorUser.username)")
                                .font(.system(size: 16, weight: .medium)) // ✅ BIGGER: Increased font size
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        // Reaction type indicator - Moved to top right
                        ReactionTypeIndicator(reactionTypeId: reaction.reactionTypeId)
                    }
                    
                    // Show target user if available - Bigger image, cleaner layout
                    if let targetUser = reaction.targetUserProfile {
                        // Reaction arrow and target user
                        HStack(spacing: 16) {
                            // Reaction arrow with better styling
                            HStack(spacing: 8) {
                                Text("→")
                                    .font(.system(size: 24, weight: .bold)) // ✅ BIGGER: Increased arrow size
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Text(tweetData.getReactionTypeIcon(reaction.reactionTypeId))
                                    .font(.system(size: 20)) // ✅ BIGGER: Increased reaction icon size
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            
                            // Target user (who received the reaction) - Bigger image
                            Button {
                                showTargetProfile = true
                            } label: {
                                HStack(spacing: 16) {
                                    AsyncImage(url: URL(string: targetUser.avatar ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 60, height: 60) // ✅ BIGGER: Increased from 40 to 60
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 2))
                                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(targetUser.nickname ?? targetUser.username)
                                            .font(.system(size: 18, weight: .semibold, design: .rounded)) // ✅ BIGGER: Increased font size
                                            .foregroundColor(.white)
                                        
                                        Text("@\(targetUser.username)")
                                            .font(.system(size: 14, weight: .medium)) // ✅ BIGGER: Increased font size
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Reaction content - Centered and cleaner
                VStack(spacing: 20) {
                    // Reaction description - Bigger and more prominent
                    Text(tweetData.getReactionTypeDescription(reaction.reactionTypeId))
                        .font(.system(size: 22, weight: .semibold, design: .rounded)) // ✅ BIGGER: Increased font size
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 20)
                    
                    // Reaction timestamp - Moved below, smaller and subtle
                    Text(formatReactionTime(reaction.createdOn))
                        .font(.system(size: 12, weight: .medium)) // ✅ SMALLER: Decreased font size
                        .foregroundColor(.white.opacity(0.5)) // ✅ MORE SUBTLE: Reduced opacity
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Bottom padding for spacing
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20) // ✅ BIGGER: Increased corner radius
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.9),
                                Color.blue.opacity(0.7),
                                Color.black.opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        // ✅ DIRECT: Profile navigation with fullScreenCover (same as ConversationFeedView.swift)
        .fullScreenCover(isPresented: $showReactorProfile) {
            TwitterProfileView(
                userId: reaction.reactorUser.id,
                username: reaction.reactorUser.username,
                initialProfile: nil
            )
            .environmentObject(tweetData)
            .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $showTargetProfile) {
            if let targetUser = reaction.targetUserProfile {
                TwitterProfileView(
                    userId: targetUser.id,
                    username: targetUser.username,
                    initialProfile: nil
                )
                .environmentObject(tweetData)
                .interactiveDismissDisabled()
            }
        }
    }
    
    private func formatReactionTime(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Reaction Type Indicator
struct ReactionTypeIndicator: View {
    let reactionTypeId: Int64
    @EnvironmentObject private var tweetData: TweetData
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tweetData.getReactionTypeIcon(reactionTypeId))
                .font(.system(size: 16))
            
            Text(tweetData.getReactionTypeName(reactionTypeId))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Debouncer for API calls
class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func debounce(_ action: @escaping () async -> Void) async {
        workItem?.cancel()
        
        let newWorkItem = DispatchWorkItem {
            Task {
                await action()
            }
        }
        
        workItem = newWorkItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }
}

// MARK: - Preview
struct ReactionsFeedView_Previews: PreviewProvider {
    static var previews: some View {
        ReactionsFeedView()
            .environmentObject(WebMAudioPlaybackManager())
            .environmentObject(TweetData())
            .environmentObject(SpacesViewModel())
            .preferredColorScheme(.dark)
    }
} 
