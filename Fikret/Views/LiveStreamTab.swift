import SwiftUI
import RiveRuntime
//import Supabase
import MapKit

struct LiveStreamTab: View {
    @Binding var showingBroadcast: Bool
    @State private var showMapView = false
   // @State private var streams: [StreamData] = []
    //@State private var isLoadingStreams = true
    @AppStorage("hasSeenBroadcastGuide") private var hasSeenBroadcastGuide = false
    @State private var showGuide = false
    @State private var dragOffset: CGSize = .zero
    @State private var selectedTab: Tab = .spaces
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @State private var animateGradient = false
    @State private var scrollOffset: CGFloat = 0
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showConfirmationModal = false
    @State private var isExpanded = false // Track if the sheet is expanded
    @State private var isAnimating = false
    @Environment(\.dismiss) private var dismiss
    private var safeAreaInsets: UIEdgeInsets {
        let window = UIApplication.shared.windows.first
        return window?.safeAreaInsets ?? .zero
    }
    @State private var audioLevel: CGFloat = 0.0
    @State private var showUserTopicModal = false
    @State private var selectedUserTopic: String?
    // Audio wave animation timer
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    @State private var sheetPosition: CGFloat = UIScreen.main.bounds.height * 0.9 // Start minimized
    
    
    // Derive currentUser from SpacesViewModel
    var currentUser: QueueUser? {
        guard let userId = spacesViewModel.tweetData.user?.id else { return nil }
        return spacesViewModel.selectedSpace?.queue.participants.first { $0.id == userId }
    }
    
    // Animated properties
    @State private var logoScale: CGFloat = 1.0
    @State private var logoRotation: Double = 0
    @State private var pulseEffect: CGFloat = 1.0
    
    
    private struct SpeakerAvatar: View {
        let image: UIImage?
        let isActive: Bool
        @EnvironmentObject var viewModel: SpacesViewModel
        var body: some View {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                ZStack {
                    
                    
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size * 1, height: size * 1)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    } else {
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFill()
                            .frame(width: size * 1, height: size * 1)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }
    // ✅ REMOVED: Custom notification overlay - using standard iOS notifications instead
    
    enum Tab {
        case spaces
    }
    
    // Complex animated logo
    private var animatedLogo: some View {
        ZStack {
            // Outer rotating ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.blue, .purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(logoRotation))
            
            // Middle pulsing circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .scaleEffect(pulseEffect)
            
            // App icon
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(logoScale)
                .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
        }
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    struct MinimizedQueueView: View {
        @EnvironmentObject var spacesViewModel: SpacesViewModel
        @Binding var showConfirmationModal: Bool
        @Binding var showUserTopicModal: Bool
        @Binding var selectedUserTopic: String?
        @State private var isPressed = false
        @State private var isAnimating = false
      
        // Similarly for queue sheet
        var currentUser: QueueUser? {
            guard let userId = spacesViewModel.tweetData.user?.id else { return nil }
            return spacesViewModel.selectedSpace?.queue.participants.first { $0.id == userId }
        }
        
        
        // MARK: - User Profile View
        private struct UserProfileView: View {
            let currentUser: QueueUser
            let isAnimating: Bool
            
            var body: some View {
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            .linear(duration: 4)
                            .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                    
                    AsyncImage(url: URL(string: currentUser.image)) { phase in
                        switch phase {
                        case .empty, .failure:
                            Image(systemName: "person.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                                .frame(width: 48, height: 48)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
            }
        }
        
        // MARK: - User Info View
        private struct UserInfoView: View {
            let currentUser: QueueUser
            let participantCount: Int
            @Binding var showUserTopicModal: Bool
            @Binding var selectedUserTopic: String?
            
            var body: some View {
                VStack(alignment: .leading, spacing: 4) {
                    // Name and verification
                    HStack {
                        Text(currentUser.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if currentUser.isInvited {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                                .symbolEffect(.pulse)
                        }
                    }
                    
                    // Topic button
                    if let topic = currentUser.topic {
                        TopicButton(topic: topic, showUserTopicModal: $showUserTopicModal, selectedUserTopic: $selectedUserTopic)
                    }
                    
                    // Status indicators
                    StatusIndicators(position: currentUser.position, participantCount: participantCount)
                }
            }
        }
        
        // MARK: - Topic Button
        private struct TopicButton: View {
            let topic: String
            @Binding var showUserTopicModal: Bool
            @Binding var selectedUserTopic: String?
            
            var body: some View {
                Button {
                    selectedUserTopic = topic
                    withAnimation(.spring()) {
                        showUserTopicModal = true
                    }
                } label: {
                    Label("Topic", systemImage: "text.bubble.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                }
                .padding(.vertical, 2)
            }
        }
        
        // MARK: - Status Indicators
        private struct StatusIndicators: View {
            let position: Int
            let participantCount: Int
            
            var body: some View {
                HStack(spacing: 6) {
                    PositionIndicator(position: position)
                    QueueCountIndicator(count: participantCount)
                }
            }
        }
        
        var body: some View {
            VStack(spacing: 8) {
                // Drag indicator
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 36, height: 4)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    .padding(.top, 8)
                
                if let currentUser = currentUser {
                    HStack(spacing: 12) {
                        UserProfileView(currentUser: currentUser, isAnimating: isAnimating)
                        
                        UserInfoView(
                            currentUser: currentUser,
                            participantCount: spacesViewModel.selectedSpace?.queue.participants.count ?? 0,
                            showUserTopicModal: $showUserTopicModal,
                            selectedUserTopic: $selectedUserTopic
                        )
                        
                        Spacer()
                        
                        // Leave button
                        Button {
                            showConfirmationModal = true
                        } label: {
                            Text("Leave")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        colors: [.red, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: .red.opacity(0.3), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(ScalesButtonStyle())
                    }
                }
            }
            .frame(height: 100)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(UIColor.systemBackground).opacity(0.98),
                                    Color(UIColor.systemBackground).opacity(0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -4)
                    
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .blue.opacity(0.3),
                                    .purple.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPressed = false
                        spacesViewModel.isQueueMinimized = false
                        spacesViewModel.showQueueView = true
                    }
                }
            }
            .onAppear {
                isAnimating = true
            }
            .onChange(of: spacesViewModel.showQueueView) { newValue in
                if newValue {
                    spacesViewModel.isQueueMinimized = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        spacesViewModel.isQueueMinimized = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Views
    private struct PositionIndicator: View {
        let position: Int
        
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                
                Text("#\(position)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.1))
            )
        }
    }

    private struct QueueCountIndicator: View {
        let count: Int
        
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                
                Text("\(count) in queue")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.1))
            )
        }
    }
    
    struct MinimizedSpaceView: View {
        @EnvironmentObject var spacesViewModel: SpacesViewModel
        @Binding var showConfirmationModal: Bool
        @State private var isPressed = false
        @State private var isAnimating = false
        
        var body: some View {
            VStack(spacing: 8) {
                // Enhanced drag indicator
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 36, height: 4)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    .padding(.top, 8)
                
                HStack(spacing: 16) {
                    // Speakers section with enhanced depth
                    if let speakers = spacesViewModel.selectedSpace?.speakers {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(speakers.prefix(2), id: \.id) { speaker in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            // Enhanced speaker border animation
                                            if spacesViewModel.activeSpeakerId == speaker.peerID {
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [.blue, .purple],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 2
                                                    )
                                                    .frame(width: 42, height: 42)
                                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                                                    .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: isAnimating)
                                            }
                                            
                                            // Enhanced speaker avatar
                                            SpeakerAvatar(
                                                image: spacesViewModel.peerImages[speaker.peerID!],
                                                isActive: spacesViewModel.activeSpeakerId == speaker.peerID
                                            )
                                            .frame(width: 40, height: 40)
                                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                            
                                            // Enhanced audio wave indicator
                                            if spacesViewModel.activeSpeakerId == speaker.peerID {
                                                AudioDetectionAnimation()
                                                    .frame(height: 8)
                                                    .offset(y: 24)
                                                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                                            }
                                        }
                                        
                                        // Enhanced text elements
                                        VStack(spacing: 2) {
                                            Text(speaker.name ?? "")
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .lineLimit(1)
                                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                            
                                            Text(
                                                speaker.id != spacesViewModel.tweetData.user?.id && spacesViewModel.isHost == false ? "🔉 Host" :
                                                    speaker.id == spacesViewModel.tweetData.user?.id && spacesViewModel.isHost == true ? "🔉 Host" :
                                                    "🔇 Speaker"
                                            )
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                        }
                                    }
                                    .frame(width: 80)
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }
                    
                    Spacer()
                    
                    // Enhanced status section
                    VStack(alignment: .trailing, spacing: 4) {
                        // Enhanced live indicator
                        HStack(spacing: 6) {
                            Text("🔴 LIVE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                            
                          
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                                .shadow(color: .red.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                        
                        // Enhanced end/leave button
                        Button {
                            showConfirmationModal = true
                        } label: {
                            Text(spacesViewModel.isHost ? "End" : "Leave")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    LinearGradient(
                                        colors: [.red, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: .red.opacity(0.3), radius: 6, x: 0, y: 3)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(.trailing, 12)
                }
            }
            .frame(height: 100)
            .background(
                ZStack {
                    // Enhanced background with depth
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(UIColor.systemBackground).opacity(0.98),
                                    Color(UIColor.systemBackground).opacity(0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -4)
                    
                    // Enhanced border
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .blue.opacity(0.3),
                                    .purple.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPressed = false
                        spacesViewModel.isSpaceMinimized = false
                        spacesViewModel.showSpaceView = true
                    }
                }
            }
            .onAppear {
                isAnimating = true
            }
            .onChange(of: spacesViewModel.showSpaceView) { newValue in
                if newValue {
                    spacesViewModel.isSpaceMinimized = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        spacesViewModel.isSpaceMinimized = false
                    }
                }
            }
        }
        
    }

    private var shouldShowSpaceSheet: Bool {
        guard let selectedSpace = spacesViewModel.selectedSpace else { return false }
        return spacesViewModel.showSpaceView && !selectedSpace.isBlockedFromSpace
    }

    // Similarly for queue sheet
    private var shouldShowQueueSheet: Bool {
        guard let selectedSpace = spacesViewModel.selectedSpace else { return false }
        return spacesViewModel.showQueueView && !selectedSpace.isBlockedFromSpace
    }



    // Enhanced search bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("Search spaces...", text: $searchText)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            
            // Map Button
            Button(action: { showMapView.toggle() }) {
                Image(systemName: "map.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
            }
            
            Button(action: { isSearching.toggle() }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
            }
        }
        .padding(.horizontal)
    }

    var body: some View {
        NavigationView {
            
            ZStack {
                // Animated background gradient
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.blue.opacity(0.05),
                        Color.purple.opacity(0.05),
                        Color(.systemBackground)
                    ],
                    startPoint: animateGradient ? .topLeading : .bottomTrailing,
                    endPoint: animateGradient ? .bottomTrailing : .topLeading
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateGradient)
                
                VStack(spacing: 0) {
                    // Header with logo and search
                    VStack(spacing: 16) {
                        HStack {
                            animatedLogo
                            
                            Text("Agora")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Spacer()
                            
                            Button(action: { showingBroadcast = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal)
                        
                        searchBar
                    }
                    .padding(.top, 20)
                    .background(
                        Rectangle()
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    
                    // Spaces ScrollView
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(spacesViewModel.spaces) { space in
                                SpaceCard(space: space)
                                    .padding(.horizontal)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            if spacesViewModel.hasMoreDataSpaces {
                                ProgressView()
                                    .onAppear {
                                        
                                    }
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                       
                    }
                }
                
                // ✅ REMOVED: Custom notification overlay - using standard iOS notifications instead
                
            
                if showConfirmationModal {
                    Color.black.opacity(0.4) // Dim background
                        .ignoresSafeArea()
                        .onTapGesture {
                            showConfirmationModal = false
                        }
                    
                    RemoveUserConfirmationModal(
                        isPresented: $showConfirmationModal,
                        userName: currentUser?.name ?? "User",
                        onConfirm: {
                            if spacesViewModel.isInSpace {
                                Task {
                                    await spacesViewModel.spaceButtonTapped()
                                }
                            } else if spacesViewModel.isInQueue {
                                Task {
                                    await spacesViewModel.queueButtonTapped()
                                }
                            }
                        }
                    )
                    .zIndex(1) // Ensure modal is on top
                    .transition(.scale) // Optional: Add a transition effect
                }
                if !spacesViewModel.showSpaceView && spacesViewModel.selectedSpace != nil  &&  spacesViewModel.isInSpace {
                    VStack {
                        Spacer()
                        MinimizedSpaceView(showConfirmationModal: $showConfirmationModal)
                            .transition(.move(edge: .bottom))
                    }
                    .ignoresSafeArea(.keyboard)
                    
                    
                }
                if !spacesViewModel.showQueueView && spacesViewModel.selectedSpace != nil &&  spacesViewModel.isInQueue &&  !spacesViewModel.isInSpace {
                    VStack {
                        Spacer()
                        MinimizedQueueView(
                            showConfirmationModal: $showConfirmationModal,
                            showUserTopicModal: $showUserTopicModal,
                            selectedUserTopic: $selectedUserTopic
                        )
                        .transition(.move(edge: .bottom))
                    }
                    .ignoresSafeArea(.keyboard)
                }
            }
                 
            
          /*  .sheet(isPresented: $showGuide) {
                NavigationView {
                    StreamInfoModal(isPresented: $showGuide)
                        .interactiveDismissDisabled(true)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Got It") {
                                    hasSeenBroadcastGuide = true
                                    showGuide = false
                                }
                            }
                        }
                }
            }*/
            .sheet(isPresented: Binding(
                get: { shouldShowQueueSheet },
                set: { if !$0 { spacesViewModel.showQueueView = false } }
            )) {
                if let selectedSpace = spacesViewModel.selectedSpace {
                    QueueView()
                        .presentationDetents([.fraction(0.9)])
                        .onDisappear {
                            if !spacesViewModel.isInQueue && !spacesViewModel.isInSpace {
                                spacesViewModel.selectedSpace = nil
                            }
                        }
                }
            }
            
            .sheet(isPresented: Binding(
                get: { shouldShowSpaceSheet },
                set: { if !$0 { spacesViewModel.showSpaceView = false } }
            )) {
                if let selectedSpace = spacesViewModel.selectedSpace {
                    SpacesListeningNowView(showConfirmationModal: $showConfirmationModal)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .onDisappear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if !spacesViewModel.isInSpace {
                                    spacesViewModel.selectedSpace = nil
                                }
                            }
                        }
                }
            }
                  /*  .sheet(isPresented: $spacesViewModel.showSpaceView) {
                                   if let selectedSpace = spacesViewModel.selectedSpace,
                                      selectedSpace.isBlockedFromSpace != true {
                                                           SpacesListeningNowView(showConfirmationModal: $showConfirmationModal)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                                           .onDisappear {
                                               
                                               DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                   if !spacesViewModel.isInSpace {
                                                       spacesViewModel.selectedSpace = nil
                                                   }
                                               }
                                           }
                                   }
                               }
            
        
            .sheet(isPresented: $spacesViewModel.showQueueView) {
                if let selectedSpace = spacesViewModel.selectedSpace, selectedSpace.isBlockedFromSpace != true {
                    QueueView()
                        .presentationDetents([.fraction(0.9)])
                        .onDisappear {
                            if !spacesViewModel.isInQueue && !spacesViewModel.isInSpace {
                                spacesViewModel.selectedSpace = nil
                            }
                        }
                }
            }
            .fullScreenCover(isPresented: $showingBroadcast) {
                BroadcastView(isPresented: $showingBroadcast)
            }*/
            .onAppear {
                // Start animations
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    logoRotation = 360
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseEffect = 1.2
                    animateGradient.toggle()
                }
                
                // Load data
                Task {
                 //   await fetchStreams()
                 
                    spacesViewModel.startPolling()
                }
            }
            .onDisappear {
                spacesViewModel.stopPolling()
            }
        }
        /*.sheet(isPresented: $showMapView) {
            NavigationView {
                MapView()
                    .navigationBarHidden(true)
                    .edgesIgnoringSafeArea(.all)
            }
        }*/
    }
    
    /*func fetchStreams() async {
        do {
            let response: PostgrestResponse<[StreamData]> = try await supabase.database
                .from("streams")
                .select()
                .eq("isLive", value: true)
                .order("startedAt", ascending: false)
                .execute()
            
            await MainActor.run {
                self.streams = response.value
                self.isLoadingStreams = false
            }
        } catch {
            print("❌ Error fetching streams: \(error)")
            await MainActor.run {
                self.isLoadingStreams = false
            }
        }
    }*/
    

    private struct RemoveUserConfirmationModal: View {
    @Binding var isPresented: Bool
    let userName: String
    let onConfirm: () -> Void
        @EnvironmentObject var spacesViewModel: SpacesViewModel
    var body: some View {
        VStack(spacing: 20) {
            if spacesViewModel.isHost && spacesViewModel.isInSpace {
            Text("Are you sure you want to end the fikret?")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding()
} else if  !spacesViewModel.isHost && spacesViewModel.isInSpace{
    Text("Are you sure you want to leave the fikret?")
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .padding()
} else  if spacesViewModel.isInQueue && !spacesViewModel.isHost{
    Text("Are you sure you want to leave the Queue?")
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .padding()
}

            HStack(spacing: 20) {
                Button("Cancel") {
                    isPresented = false
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())

                Button("Ok") {
                    onConfirm()
                    isPresented = false
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
                .clipShape(Capsule())
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.systemBackground)))
        .shadow(color: .black.opacity(0.2), radius: 10)
        .padding()
    }
}

    
    private var queueMiniCardContent: some View {
        VStack(spacing: 8) {
            // Drag indicator
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .cornerRadius(2.5)
                .padding(.top, 8)

            HStack(spacing: 12) {
                if let currentUser = currentUser {
                    // User Image with animated border
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 52, height: 52)
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .animation(
                                .linear(duration: 4)
                                .repeatForever(autoreverses: false),
                                value: isAnimating
                            )
                        
                        AsyncImage(url: URL(string: currentUser.image)) { phase in
                            switch phase {
                            case .empty, .failure:
                                Image(systemName: "person.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                    .frame(width: 48, height: 48)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    
                    // User Info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(currentUser.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if currentUser.isInvited {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 14))
                                    .symbolEffect(.pulse)
                            }
                        }
                        
                        if let topic = currentUser.topic {
                            Button {
                                selectedUserTopic = topic
                                withAnimation(.spring()) {
                                    showUserTopicModal = true
                                }
                            } label: {
                                Label("Topic", systemImage: "text.bubble.fill")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .clipShape(Capsule())
                            }
                            .padding(.vertical, 2)
                        }
                        
                        HStack(spacing: 6) {
                            // Position indicator
                            HStack(spacing: 4) {
                                Image(systemName: "number.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 12))
                                
                                Text("#\(currentUser.position)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.1))
                            )
                            
                            // Queue status
                            HStack(spacing: 4) {
                                Image(systemName: "person.3.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 12))
                                
                                Text("\(spacesViewModel.selectedSpace?.queue.participants.count ?? 0) in queue")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.1))
                            )
                        }
                    }
                    
                    Spacer()
                    
                    // Leave Queue Button
                    Button {
                        showConfirmationModal = true
                    } label: {
                        Text("Leave")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .red.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(ScalesButtonStyle())
                }
            }
            .onAppear {
                isAnimating = true
            }
        }
    }
    
    struct AudioDetectionAnimation: View {
        @State private var animate = false

        var body: some View {
            HStack(spacing: 2) { // Reduced spacing for a more compact look
                ForEach(0..<10) { index in
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.8), .blue.opacity(0.6)], // Darker blue colors
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 3, height: CGFloat.random(in: 8...30)) // Smaller bars
                        .scaleEffect(y: animate ? CGFloat.random(in: 0.5...1.5) : 1, anchor: .bottom)
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: animate
                        )
                }
            }
            .onAppear {
                animate = true
            }
        }
    }
    
    
    private var spaceMiniCardContent: some View {
        VStack(spacing: 8) {
            // Drag indicator
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .cornerRadius(2.5)
                .padding(.top, 8)

            HStack(spacing: 16) {
                ZStack {
                    if let speakers = spacesViewModel.selectedSpace?.speakers {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(speakers, id: \.id) { speaker in
                                    VStack {
                                        SpeakerAvatar(
                                            image: spacesViewModel.peerImages[speaker.peerID!],
                                            isActive: spacesViewModel.activeSpeakerId == speaker.peerID
                                        )
                                        .frame(width: 60 * 0.7, height: 60 * 0.7) // Adjust size as needed
                                        
                                        Text(speaker.name ?? "")
                                            .font(.system(size: 14 * 0.7, weight: .bold, design: .rounded)) // Adjust font size
                                            .minimumScaleFactor(0.5)
                                            .lineLimit(1)
                                        
                                        Text(
                                            speaker.id != spacesViewModel.tweetData.user?.id && spacesViewModel.isHost == false ? "🔉 Host" :
                                            speaker.id == spacesViewModel.tweetData.user?.id && spacesViewModel.isHost == true ? "🔉 Host" :
                                            "🔇 Speaker"
                                        )
                                        .font(.system(size: 12 * 0.7, weight: .medium, design: .rounded)) // Adjust font size
                                            .foregroundColor(.secondary)
                                            .minimumScaleFactor(0.5)
                                            .lineLimit(1)
                                        
                                        if spacesViewModel.activeSpeakerId == speaker.peerID {
                                            AudioDetectionAnimation()
                                                .frame(height: 8 * 0.7) // Adjust height as needed
                                        }
                                    }
                                    .frame(maxWidth: .infinity) // Ensure each speaker takes equal space
                                }
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("🔴 LIVE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.2))
                            .clipShape(Capsule())
                            .shadow(color: .red.opacity(0.4), radius: 2, x: 0, y: 1)
                    }
                    
                 
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        
                   
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                Button {
                    showConfirmationModal = true
                } label: {
                    Text(spacesViewModel.isHost ? "End" : "Leave")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: spacesViewModel.isHost ? [.red, .orange] : [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: (spacesViewModel.isHost ? Color.red : Color.purple).opacity(0.4),
                                radius: 5, x: 0, y: 2)
                }
                .buttonStyle(ScalesButtonStyle())
                
            }
            .padding(.horizontal)
            .onAppear {
                isAnimating = true
            }
            .onReceive(timer) { _ in
                withAnimation(.easeInOut(duration: 0.1)) {
                    audioLevel = CGFloat.random(in: 0.8...1.2)
                }
            }
        }
        .offset(y: dragOffset.height < 0 ? dragOffset.height / 2 : 0) // Move up effect
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    if value.translation.height < -50 {
                        spacesViewModel.showSpaceView = true
                    }
                    dragOffset = .zero
                }
        )
    }
}
struct ScalesButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}


