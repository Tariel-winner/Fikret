import SwiftUI

// Define SpaceError enum
enum SpaceError: Error, Identifiable {
    case roomFull
    case alreadyInSpace
    case hostNotPresent
    case unknown
    
    var id: String { localizedDescription }
    
    var localizedDescription: String {
        switch self {
        case .roomFull:
            return "The space is full"
        case .alreadyInSpace:
            return "You are already in a space"
        case .hostNotPresent:
            return "The host is not present"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

struct TalkButtonWithTopicInput: View {
    @EnvironmentObject private var spacesViewModel: SpacesViewModel
    @EnvironmentObject private var tweetData: TweetData
    @EnvironmentObject private var trendingService: TrendingTopicsService
    
    @State private var isExpanded = false
    @State private var topic = ""
    @State private var activeError: SpaceError?
    // ✅ SPINNER WHEEL STATE
    @State private var currentSpinTopics: [TrendingTopic] = []
    @State private var selectedTopic: TrendingTopic? = nil
    @State private var spinCount = 0
    @State private var isSpinning = false
    
    @State private var isSubmitting = false
    
    // 🎰 DOPAMINE: Audio and Haptic Managers (from SlotMachineReel.swift)
    private let audioManager = SlotMachineAudioManager.shared
    private let hapticsManager = SlotMachineHapticsManager.shared
    
    // ✅ FIXED: Only disable button when host is offline
    private var isButtonDisabled: Bool {
        guard let currentSpace = spacesViewModel.currentViewingSpace else { return false }
        return !currentSpace.isHostOnline
    }
    
    private var buttonDisabledReason: String? {
        guard let currentSpace = spacesViewModel.currentViewingSpace else { return nil }
        
        if !currentSpace.isHostOnline {
            return "Host is offline now"
        }
        
        return nil
    }
    
    var body: some View {
        ZStack {
            // Main content
            VStack {
                Spacer()
                
                if !spacesViewModel.isInSpace {
                    // Show either the collapsed button OR the expanded content, not both
                    if !isExpanded {
                        // Collapsed state button
                        Button(action: toggleExpansion) {
                            HStack(spacing: 8) {
                                Image(systemName: "mic.circle.fill")
                                    .font(.system(size: 20))
                                Text("Connect")
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 20))
                            }
                            .foregroundColor(isButtonDisabled ? .white.opacity(0.4) : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: isButtonDisabled ?
                                        [Color.gray.opacity(0.3), Color.gray.opacity(0.2)] :
                                        [Color.purple.opacity(0.9), Color.blue.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: isButtonDisabled ? .black.opacity(0.1) : .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Capsule())
                        .zIndex(2)
                        .disabled(isButtonDisabled)
                    } else {
                        /* COMMENTED OUT: Expanded content UI - not needed for direct join
                        // Background + Expanded content with proper boundaries
                        ZStack {
                            // Dark overlay background
                            Color.black.opacity(0.6)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    resetToCollapsedState()
                                }
                            
                            // Content with proper sizing
                            VStack {
                                Spacer()
                                
                                spinnerExpandedContent
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 100) // Ensure it stays within safe boundaries
                                
                                Spacer()
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 1.05))
                        ))
                        */
                        // ✅ SIMPLIFIED: No expanded content needed for direct join
                        EmptyView()
                    }
                } else if spacesViewModel.isHost && spacesViewModel.isInSpace {
                    // Host is in space - disabled state
                    disabledTalkButton
                        .zIndex(2)
                }
                
                Spacer()
            }
        }
        .alert(item: $activeError) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
        // ✅ ADDED: Reset state when leaving space
        .onChange(of: spacesViewModel.isInSpace) { isInSpace in
            if !isInSpace {
                print("🔄 [TalkButton] Space ended, resetting state")
                resetToCollapsedState()
            }
        }
    }
    

    
    // ✅ MODERN: Clean Spinner Content
    private var spinnerExpandedContent: some View {
        VStack(spacing: 20) {
            // Header with close button
            HStack {
                Text("Choose a Topic")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    resetToCollapsedState()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Spinning indicator (simple and clean)
            if isSpinning {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .colorScheme(.dark)
                    Text("Finding topics...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 8)
            }
            
            // Topics List (clean rows)
            if !currentSpinTopics.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(currentSpinTopics.enumerated()), id: \.offset) { index, spinTopic in
                        SlotMachineReel(
                            topic: spinTopic,
                            isSpinning: isSpinning,
                            isSelected: selectedTopic?.id == spinTopic.id,
                            spinDelay: Double(index) * 0.3,
                            onTap: {
                                selectTopic(spinTopic)
                            }
                        )
                    }
                }
            }
            
            // Action Buttons (modern design)
            VStack(spacing: 12) {
                // Primary Action
                Button(action: {
                    useSelectedTopic()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Use This Topic")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedTopic != nil ?
                            LinearGradient(
                                colors: [.purple.opacity(0.9), .blue.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedTopic == nil)
                
                // Secondary Actions
                HStack(spacing: 12) {
                    if spinCount < 2 {
                        Button(action: {
                            getNewTopics()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14))
                                Text("New Topics")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isSpinning)
                    } else {
                        Button(action: {
                            talkFreely()
                        }) {
                            HStack {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 14))
                                Text("Talk Freely")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.95),
                            Color.blue.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .purple.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .onAppear {
            // Start first spin when expanded
            spinForTopics()
        }
    }
    
    
    
    private var disabledTalkButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 20))
            Text("Connect")
                .font(.system(size: 16, weight: .semibold))
            Image(systemName: "chevron.up")
                .font(.system(size: 12))
        }
        .foregroundColor(.white.opacity(0.4))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func toggleExpansion() {
        // ✅ FIXED: Only disable when host is offline
        if isButtonDisabled {
            print("🎯 [TalkButtonWithTopicInput] Button disabled, ignoring tap")
            return
        }
       
        
        guard let currentSpace = spacesViewModel.currentViewingSpace else {
            print("🎯 [TalkButtonWithTopicInput] No current viewing space")
            return
        }
        
        if !(currentSpace.isFollowing ?? false) {
            print("🎯 [TalkButtonWithTopicInput] User not following, showing follow notification")
            spacesViewModel.showToast("You need to follow this user to join the room", isError: true)
            return
        }
        
        print("🎯 [TalkButtonWithTopicInput] Direct joinSpace called - bypassing topic input")
        
        // ✅ SIMPLIFIED: Directly call joinSpace instead of showing topic input UI
        joinSpace()
        
        /* COMMENTED OUT: Topic input UI logic
        withAnimation(.easeInOut(duration: 0.3)) {
            isExpanded = true
        }
        */
    }
    
    private func dismissExpanded() {
        print("🎯 [TalkButtonWithTopicInput] Dismissing expanded view")
        withAnimation(.easeOut(duration: 0.2)) {
            isExpanded = false
            // ✅ FIXED: Don't reset isSubmitting if we're in the middle of joining
            if !isSubmitting {
                isSubmitting = false
            }
            // Reset spinner state
            topic = ""
            currentSpinTopics = []
            selectedTopic = nil
            spinCount = 0
            isSpinning = false
        }
    }
    
  // ... existing code ...

private func joinSpace() {
    guard !isSubmitting else {
        print("⚠️ [TalkButton] Already submitting, ignoring tap")
        return
    }
    
    // ✅ FIXED: Only disable when host is offline
    if isButtonDisabled {
        print("🎯 [TalkButton] Button disabled, ignoring join attempt")
        return
    }
    
    guard let currentSpace = spacesViewModel.currentViewingSpace else {
        print("🎯 [TalkButton] No current viewing space")
        return
    }
    
    if !(currentSpace.isFollowing ?? false) {
        return
    }
    
    print("🚀 [TalkButton] Starting joinSpace process...")
    
    // ✅ FIXED: Immediately hide topic input UI when joining starts
    print("🎯 [TalkButton] Hiding topic input UI and setting submitting state")
    withAnimation(.easeOut(duration: 0.2)) {
        isExpanded = false
        isSubmitting = true
    }
    print("🎯 [TalkButton] UI state updated - isExpanded: \(isExpanded), isSubmitting: \(isSubmitting)")
    
    Task {
        print("📝 [TalkButton] Direct joinSpace call - no topic input")
        
        guard let currentSpace = spacesViewModel.currentViewingSpace else {
            print("❌ [TalkButton] No current viewing space")
            activeError = .unknown
            resetToInputState()
            return
        }
        
        print("✅ [TalkButton] Found current space: \(currentSpace.id)")
        
        do {
            // Use topic if provided, otherwise use empty string
          ///  let finalTopic = topic.isEmpty ? "" : topic
            let finalTopic = "Free Talk"

            print("📝 [TalkButton] Setting topic in SpacesViewModel: '\(finalTopic)'")
            spacesViewModel.setTopic(finalTopic)
            print("📝 [TalkButton] Calling joinSpace with space ID: \(currentSpace.id)")
            try await spacesViewModel.joinSpace(id: currentSpace.id)
            
            print("✅ [TalkButton] joinSpace completed successfully")
            // ✅ ADDED: Reset all states on successful completion
            withAnimation(.easeOut(duration: 0.2)) {
                topic = ""
                isSubmitting = false
            currentSpinTopics = []
            selectedTopic = nil
            spinCount = 0
            isSpinning = false
            }
            
        } catch { // ✅ SIMPLIFIED: Catch any error, not just SpaceError
            print("❌ [TalkButton] Error occurred: \(error)")
            
            // ✅ CONVERT: Convert general error to SpaceError for UI display
            if let nsError = error as NSError? {
                switch nsError.code {
                case -1:
                    activeError = .unknown
                case -2:
                    activeError = .unknown
                case -3:
                    activeError = .unknown
                default:
                    activeError = .unknown
                }
            } else {
                activeError = .unknown
            }
            
            resetToInputState()
        }
        
        print("🏁 [TalkButton] joinSpace process completed")
    }
}

// ... existing code ...
    
    // Helper function to reset to input state on error
    private func resetToInputState() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isSubmitting = false
            isExpanded = false
            topic = ""
            // Reset spinner state
            currentSpinTopics = []
            selectedTopic = nil
            spinCount = 0
            isSpinning = false
            activeError = nil
        }
    }
    
    // ✅ ADDED: Reset to collapsed state when space ends
    private func resetToCollapsedState() {
        withAnimation(.easeOut(duration: 0.2)) {
            isExpanded = false
            isSubmitting = false
            topic = ""
            // Reset spinner state
            currentSpinTopics = []
            selectedTopic = nil
            spinCount = 0
            isSpinning = false
            activeError = nil
        }
        print("✅ [TalkButton] Reset to collapsed state")
    }
    
    // MARK: - Spinner Wheel Methods
    
    private func spinForTopics() {
        guard !isSpinning else { return }
        
        print("🎲 [SPINNER] Starting spin #\(spinCount + 1)")
        
        // 🎵 DOPAMINE: Play anticipation effects before spin
        audioManager.playAnticipation()
        hapticsManager.playAnticipation()
        
        // Delay the actual spin for dramatic effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            // 🎵 DOPAMINE: Play lever pull sound and haptic
            self.audioManager.playSpinStart()
            self.hapticsManager.playLeverPull()
            
            withAnimation(.easeInOut(duration: 0.5)) {
                self.isSpinning = true
                self.selectedTopic = nil // Clear selection during spin
            }
        }
        
        Task {
            do {
                // ✅ PERSONALIZED: Set user categories for personalized trending topics
                let userCategories = getUserCategoriesForTrending()
                if !userCategories.isEmpty {
                    print("🎯 [SPINNER] Using user categories: \(userCategories)")
                    trendingService.setUserCategories(userCategories)
                } else {
                    print("🎯 [SPINNER] No user categories, using defaults")
                    trendingService.resetSpinnerWheel() // Reset to use defaults
                }
                
                // Use TrendingTopicsService to get 4 topics
                let topics = await trendingService.getNextTrendingTopics(count: 4)
                
                await MainActor.run {
                    // Store the new topics but don't display them yet
                    let newTopics = topics
                    
                    // Wait for the longest reel delay (3rd reel = 0.9s) + animation time (0.8s) = 1.7s total
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            self.currentSpinTopics = newTopics
                            self.isSpinning = false
                            self.spinCount += 1
                        }
                        print("🎲 [SPINNER] Spin #\(self.spinCount) completed with \(newTopics.count) topics")
                    }
                }
            } catch {
                print("❌ [SPINNER] Error getting topics: \(error)")
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.isSpinning = false
                    }
                }
            }
        }
    }
    
    private func selectTopic(_ spinTopic: TrendingTopic) {
        print("🎯 [SPINNER] Selected topic: \(spinTopic.title)")
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTopic = spinTopic
            topic = spinTopic.title // Set the topic for joinSpace
        }
    }
    
    private func useSelectedTopic() {
        guard let selectedTopic = selectedTopic else {
            print("❌ [SPINNER] No topic selected")
            return
        }
        
        print("✅ [SPINNER] Using selected topic: \(selectedTopic.title)")
        
        // 🎵 DOPAMINE: Play jackpot celebration sounds and haptics
        audioManager.playJackpot()
        hapticsManager.playJackpot()
        
        topic = selectedTopic.title
        joinSpace() // ✅ REUSE EXISTING METHOD
    }
    
    private func getNewTopics() {
        print("🔄 [SPINNER] Getting new topics (spin count: \(spinCount))")
        spinForTopics()
    }
    
    private func talkFreely() {
        print("🗣️ [SPINNER] User chose to talk freely")
        topic = "Free Talk" // Empty topic for free talk
        joinSpace() // ✅ REUSE EXISTING METHOD
    }
    
    // ✅ CATEGORY MAPPING: Convert category IDs to Reddit subreddit names
    private func getUserCategoriesForTrending() -> [String] {
        var categoryIds: [Int64] = []
        
        // First priority: Get space host's categories (user is joining host's space)
        if let hostCategories = spacesViewModel.currentViewingSpace?.categories, !hostCategories.isEmpty {
            categoryIds = hostCategories
            print("🎯 [CATEGORY] Using space host's categories: \(hostCategories)")
        }
        // Second priority: Get current user's categories as fallback
        else if let userCategoryIds = tweetData.user?.categories, !userCategoryIds.isEmpty {
            categoryIds = userCategoryIds
            print("🎯 [CATEGORY] Using current user's categories as fallback: \(userCategoryIds)")
        }
        // No categories available - will use defaults
        else {
            print("🎯 [CATEGORY] No host or user categories found, using service defaults")
            return []
        }
        
        print("🎯 [CATEGORY] Selected category IDs: \(categoryIds)")
        
        // Map category IDs to Reddit subreddit names
        let subredditNames = categoryIds.compactMap { categoryId -> String? in
            let categoryName = tweetData.getCategoryNameById(categoryId).lowercased()
            
            // Map category names to Reddit subreddit names
            switch categoryName {
            case "gaming":
                return "gaming"
            case "technology":
                return "technology"
            case "music":
                return "music"
            case "movies":
                return "movies"
            case "tv shows":
                return "television"
            case "comedy":
                return "funny"
            case "news":
                return "news"
            case "politics":
                return "politics"
            case "sports":
                return "sports"
            case "science":
                return "science"
            case "business":
                return "business"
            case "health & wellness":
                return "health"
            case "fitness":
                return "fitness"
            case "food":
                return "food"
            case "travel":
                return "travel"
            case "pets":
                return "aww"
            case "automotive":
                return "cars"
            case "environment":
                return "environment"
            case "ai":
                return "artificial"
            case "fashion":
                return "fashion"
            case "beauty":
                return "beauty"
            default:
                // For unmapped categories, try to use the name directly if it's a valid subreddit
                let cleanName = categoryName.replacingOccurrences(of: " ", with: "")
                return cleanName.count > 2 ? cleanName : nil
            }
        }
        
        print("🎯 [CATEGORY] Mapped to subreddits: \(subredditNames)")
        return subredditNames
    }
    
}

// Helper extension for placeholder
extension View {
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
}

// ✅ REMOVED: Custom focus extension - use native iOS instead
// This was causing lag and slowness

// Host Not Present Modal
struct HostNotPresentModal: View {
    @Binding var isPresented: Bool
    @State private var animateGradient = false
    @State private var showContent = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color.red.opacity(0.8),
                    Color.blue.opacity(0.6),
                    Color.purple.opacity(0.4)
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .opacity(0.2)
            
            // Content
            VStack {
                Spacer()
                
                VStack(spacing: 25) {
                    // Animated icon
                    ZStack {
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.7), .yellow.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 120 - CGFloat(i * 20), height: 120 - CGFloat(i * 20))
                                .scaleEffect(showContent ? 1.1 : 1.0)
                                .opacity(1 - Double(i) * 0.2)
                        }
                        
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(spacing: 15) {
                        Text("Host Not Available")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("The host is currently not available. Please try again later.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                            .padding(.horizontal)
                    }
                    
                    // Dismiss button
                    Button {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    } label: {
                        Text("Try Again Later")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 10)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.8))
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Material.ultraThinMaterial)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .offset(y: showContent ? 0 : UIScreen.main.bounds.height)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
}

// Room Full Modal
struct RoomFullModal: View {
    @Binding var isPresented: Bool
    @State private var animateGradient = false
    @State private var showContent = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color.red.opacity(0.8),
                    Color.blue.opacity(0.6),
                    Color.purple.opacity(0.4)
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .opacity(0.2)
            
            // Content
            VStack {
                Spacer()
                
                VStack(spacing: 25) {
                    // Animated icon
                    ZStack {
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.red.opacity(0.7), .orange.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 120 - CGFloat(i * 20), height: 120 - CGFloat(i * 20))
                                .scaleEffect(showContent ? 1.1 : 1.0)
                                .opacity(1 - Double(i) * 0.2)
                        }
                        
                        Image(systemName: "person.3.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(spacing: 15) {
                        Text("Space is Full")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("This space has reached its maximum capacity of 2 participants. Please try again later.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                            .padding(.horizontal)
                    }
                    
                    // Dismiss button
                    Button {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    } label: {
                        Text("Try Again Later")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 10)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.8))
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Material.ultraThinMaterial)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .offset(y: showContent ? 0 : UIScreen.main.bounds.height)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
}
