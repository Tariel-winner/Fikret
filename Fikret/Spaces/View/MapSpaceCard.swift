import SwiftUI
import MapKit
import PhotosUI
import CryptoKit

// 1. Renamed Story struct for map
struct MapStory: Identifiable {
    let id: Int64
    let userImageUrl: String
    let username: String
    let storyImageUrl: String
    let timestamp: Date
    let isViewed: Bool
    
    init(id: Int64,
         userImageUrl: String,
         username: String,
         storyImageUrl: String,
         isViewed: Bool = false,
         timestamp: Date) {
        self.id = id
        self.userImageUrl = userImageUrl
        self.username = username
        self.storyImageUrl = storyImageUrl
        self.timestamp = timestamp
        self.isViewed = isViewed
        
       /// print("Creating MapStory with image URL: \(storyImageUrl)")
    }
}

// 2. Renamed StoriesView for map
struct MapStoriesView: View {
    let stories: [MapStory]
    let zoomLevel: Int
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @State private var showStoryViewer = false
    
    private var bubbleSize: CGFloat {
        switch zoomLevel {
        case ...8: return 0.7    // Global view (5x smaller)
        case 9...12: return 0.84  // Continental view (5x smaller)
        case 13...15: return 0.98 // Regional view (5x smaller)
        case 16: return 1.12      // City view (5x smaller)
        default: return 1.26      // Detailed view (5x smaller)
        }
    }
    
    var body: some View {
        HStack(spacing: bubbleSize * 2) {
            ForEach(stories, id: \.id) { story in
                MapStoryBubbleView(
                    story: story,
                    hasStory: !story.storyImageUrl.isEmpty,
                    bubbleSize: bubbleSize,
                    onTap: {
                        if !story.storyImageUrl.isEmpty,
                           let spaceId = story.id as Int64?,
                           let space = spacesViewModel.spaces.first(where: { $0.id == spaceId }) {
                            spacesViewModel.selectedSpace = space
                            showStoryViewer = true
                        }
                    }
                )
            }
        }
        .padding(.horizontal, bubbleSize)
      /*  .fullScreenCover(isPresented: $showStoryViewer) {
            if let selectedSpace = spacesViewModel.selectedSpace,
               let imageURL = selectedSpace.previewImageURL?.absoluteString {
                MapStoryViewer(
                    story: MapStory(
                        id: selectedSpace.id,
                        userImageUrl: selectedSpace.hostImageUrl ?? "",
                        username: selectedSpace.host ?? "",
                        storyImageUrl: imageURL,
                        isViewed: false,
                        timestamp: selectedSpace.updatedAt
                    ),
                    isPresented: $showStoryViewer
                )
            }
        }*/
    }
}

// 3. Renamed StoryBubbleView for map
struct MapStoryBubbleView: View {
    let story: MapStory
    let hasStory: Bool
    let bubbleSize: CGFloat
    let onTap: () -> Void
    @State private var animateGradient = false
    
    var body: some View {
        Button(action: onTap) {
            if let url = URL(string: story.userImageUrl) {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: bubbleSize * 3, height: bubbleSize * 3)
                            .clipShape(Circle())
                    default:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: bubbleSize * 3, height: bubbleSize * 3)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(
                            hasStory ?
                                LinearGradient(
                                    colors: [.purple, .red, .orange],
                                    startPoint: animateGradient ? .topLeading : .bottomTrailing,
                                    endPoint: animateGradient ? .bottomTrailing : .topLeading
                                )
                                : LinearGradient(
                                    colors: [Color.gray.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: hasStory ? bubbleSize * 0.1 : bubbleSize * 0.05
                        )
                )
            }
        }
        .disabled(!hasStory)
        .onAppear {
            if hasStory {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
        }
    }
}

// 4. Renamed StoryViewer for map
struct MapStoryViewer: View {
    let story: MapStory
    @Binding var isPresented: Bool
    @State private var progress: CGFloat = 0
    @State private var isLoading = true
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        ZStack {
            // Fixed black background
            Color.black
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                // Story content (full screen)
                if let url = URL(string: story.storyImageUrl) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        case .failure:
                            VStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                Text("Failed to load image")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Overlay elements with gradient for better visibility
                VStack {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                    .overlay {
                        HStack(spacing: 12) {
                            // Progress circle with user image
                            ZStack {
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 36, height: 36)
                                
                                // User image
                                if let url = URL(string: story.userImageUrl) {
                                    CachedAsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                        default:
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 32, height: 32)
                                        }
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(story.username)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("2h")  // Calculate from story.timestamp
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            // Close button
                            Button {
                                withAnimation(.spring()) {
                                    isPresented = false
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                }
            }
            .offset(y: dragOffset.height)
            .opacity(1.0 - abs(dragOffset.height)*0.0033)
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    dragOffset = gesture.translation
                }
                .onEnded { gesture in
                    if abs(gesture.translation.height) > 100 {
                        withAnimation(.interactiveSpring()) {
                            isPresented = false
                        }
                    } else {
                        withAnimation {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            isPresented = false
        }
        .onAppear {
            dragOffset = .zero
            withAnimation(.linear(duration: 5)) {
                progress = 1
            }
        }
    }
}

// Add MapStoriesContent component
struct MapStoriesContent: View {
    @Binding var currentStory: MapStory
    let geometry: GeometryProxy
    
    var body: some View {
        if let url = URL(string: currentStory.storyImageUrl) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .edgesIgnoringSafeArea(.all)
                case .failure(let error):
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                        Text("Failed to load image: \(error.localizedDescription)")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                case .empty:
                    ProgressView()
                        .tint(.white)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            VStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                Text("Invalid URL")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.7))
        }
    }
}

// Add MapLivePhotoViews component
struct MapLivePhotoViews: View {
    let url: URL
    @State private var livePhoto: PHLivePhoto?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let photo = livePhoto {
                MapLivePhotoRepresentable(livePhoto: photo)
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "photo.fill")
                    .foregroundColor(.gray)
            }
        }
        .task {
            await loadLivePhoto()
        }
    }
    
    private func loadLivePhoto() async {
        isLoading = true
        defer { isLoading = false }
        
        let targetSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        if let photo = await LivePhotoCacheManager.shared.getLivePhoto(for: url, targetSize: targetSize) {
            self.livePhoto = photo
        }
    }
}

// Add MapLivePhotoRepresentable component
struct MapLivePhotoRepresentable: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    
    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.livePhoto = livePhoto
        return view
    }
    
    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
    }
}

// Add MapOptimizedAsyncImage component
struct MapOptimizedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase = .empty
    
    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }
    
    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url = url else {
                    phase = .empty
                    return
                }
                
                // First check cache
                if let cached = await ImageCacheManager.shared.image(for: url) {
                    phase = .success(Image(uiImage: cached))
                    return
                }
                
                // If not in cache, load and cache is handled automatically by image(for:)
                if let image = await ImageCacheManager.shared.image(for: url) {
                    phase = .success(Image(uiImage: image))
                } else {
                    phase = .failure(URLError(.badServerResponse))
                }
            }
    }
}
struct MapSpaceCard: View {
    let space: Space
    let zoomLevel: Int
    @EnvironmentObject var spacesViewModel: SpacesViewModel

    @EnvironmentObject var tweetData: TweetData
    @State private var showBlockedModal = false
    @State private var showHostActiveModal = false
    @State private var isHovered = false
    @State private var animateGradient = false
    @State private var animateRestriction = false
    @State private var showHostInfo = false
    @State private var pulseEffect: CGFloat = 1.0

    // Calculate the scale factor based on zoom level
    private var scaleFactor: CGFloat {
        switch zoomLevel {
        case ...5: return 1.0 / 2.4  // Most zoomed out
        case 6...8: return 1.0 / 2.0
        case 9...11: return 1.0 / 1.8
        case 12...13: return 1.0 / 1.6
        case 14: return 1.0 / 1.4
        case 15: return 1.0 / 1.2
        case 16...: return 1.0       // Most zoomed in, full size
        default: return 1.0 / 2.4
        }
    }

    // *** Updated base size based on user input ***
    private var baseSize: CGFloat { 40 * scaleFactor * markerScale } // Combine scaleFactor and markerScale for overall size
    private var storiesSize: CGFloat { 25 * scaleFactor * markerScale } // Adjust story size similarly

    // Refined zoom level scaling that matches MapKit's behavior (Used for Marker-like scaling)
    private var markerScale: CGFloat {
        switch zoomLevel {
        case ...13: return 1.0      // Normal size for zoom levels up to 13
        case 14: return 1.7         // 70% larger
        case 15: return 2.4         // Another 70% larger
        case 16...: return 3.1      // Another 70% larger
        default: return 1.0
        }
    }

    // Internal elements scale factor (Used for things *inside* the marker, like font or padding relative to baseSize)
    // Note: The previous implementation used baseSize * factor for padding/font directly, which incorporates markerScale now.
    // This elementScale might be redundant if all internal elements scale with baseSize. Let's keep it simple for now.
    // private var elementScale: CGFloat { ... } // Keep if needed for independent scaling

    // Update font sizes to scale with zoom (using the new baseSize)
    private var titleFontSize: CGFloat {
        max(baseSize * 0.15, 8) // Use a fraction of baseSize, ensure minimum size
    }

    private var countFontSize: CGFloat {
        max(baseSize * 0.15, 8) // Use a fraction of baseSize, ensure minimum size
    }

    private var gradientColors: [Color] {
    
            return [.blue, .purple, .blue.opacity(0.8)]
     
    }

    private var isHostOfActiveSpace: Bool {
        guard let currentUserId = tweetData.user?.id else { return false }
        // Ensure comparison works correctly (check UUID string representation)
        return spacesViewModel.spaces.contains { space in
        
            space.hostId == currentUserId
        }
    }
    
    // Check if the *current* user is the host of *this specific* space
    private var isCurrentUserHostOfThisSpace: Bool {
        guard let currentUserId = tweetData.user?.id else { return false }
        return space.hostId == currentUserId
    }

    private var hostInfo: (imageUrl: String, username: String)? {
        guard let hostImageUrl = space.hostImageUrl,
              let hostName = space.host,
              !hostImageUrl.isEmpty else {
            return nil
        }
        return (imageUrl: hostImageUrl, username: hostName)
    }

    private var story: MapStory? {
      /*  guard let imageURL = space.previewImageURL?.absoluteString,
              !imageURL.isEmpty,
              let hostInfo = hostInfo else {
            return nil
        }*/

        return MapStory(
            id: space.id,
            userImageUrl: hostInfo!.imageUrl,
            username: hostInfo!.username,
            storyImageUrl: "",
            isViewed: false, // Fetch actual viewed status if needed
            timestamp: space.updatedAt
        )
    }
    private var elementScale: CGFloat {
          switch zoomLevel {
          case ...3: return 0.4    // World view
          case 4...6: return 0.5   // Continent view
          case 7...9: return 0.6   // Country view
          case 10...12: return 0.7 // Region view
          case 13...15: return 0.8 // City view
          case 16...18: return 0.9 // Street view
          default: return 1.0      // Maximum zoom
          }
      }

    // Card dimensions (derived from new baseSize)
    private var cardWidth: CGFloat { baseSize }
    // Make card slightly taller than wide, adjust ratio as needed
    private var cardHeight: CGFloat { baseSize * 0.6 }
    // Total height should accommodate stories + card + spacing
    // Approximate story height based on bubble size + padding (adjust!)
    private var calculatedStoryHeight: CGFloat {
        // Estimate based on MapStoryBubbleView size (bubbleSize * 3) + padding
        let bubbleDiameter = (zoomLevel <= 8 ? 0.7 : zoomLevel <= 12 ? 0.84 : zoomLevel <= 15 ? 0.98 : zoomLevel == 16 ? 1.12 : 1.26) * 3
        let verticalPadding: CGFloat = 10 // From the .padding(.vertical, 10) on MapStoriesView
        return (story != nil ? (bubbleDiameter + verticalPadding * 2) : 0) * scaleFactor * markerScale // Scale story height too
    }
     private var verticalSpacing: CGFloat { max(5 * scaleFactor * markerScale, 2) } // Spacing between stories and card
    private var totalHeight: CGFloat { calculatedStoryHeight + cardHeight + verticalSpacing }


    // --- Lock Overlay View ---
    // (Integrated from user's provided code, adjusted sizes based on baseSize)
    private var lockOverlay: some View {
        ZStack {
            // Semi-transparent background matching card shape
            Color.black.opacity(showHostInfo ? 0.6 : 0.4) // Darker when info shown
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                .allowsHitTesting(false) // Don't block taps on the card below

            if showHostInfo {
                // Content when hovered/tapped
                VStack(spacing: max(baseSize * 0.1, 8)) { // Scaled spacing
                    HStack(spacing: max(baseSize * 0.08, 5)) {
                        ZStack {
                            Circle()
                                .fill(.red)
                                .frame(width: baseSize * 0.1, height: baseSize * 0.1) // Scaled dot

                            Circle()
                                .stroke(.red.opacity(0.5), lineWidth: 1)
                                .frame(width: baseSize * 0.18, height: baseSize * 0.18) // Scaled pulse ring
                                .scaleEffect(pulseEffect)
                                .opacity(pulseEffect == 1.0 ? 1 : 0)
                        }

                        Text("Currently Hosting")
                            .font(.system(size: max(baseSize * 0.12, 9), weight: .semibold, design: .rounded)) // Scaled font
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, max(baseSize * 0.1, 8))
                    .padding(.vertical, max(baseSize * 0.05, 4))
                    .background(Capsule().fill(.ultraThinMaterial))

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red.opacity(0.2), .orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: baseSize * 0.4, height: baseSize * 0.4) // Scaled icon background

                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: baseSize * 0.2)) // Scaled icon size
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }

                    Text("End your active space to join others")
                        .font(.system(size: max(baseSize * 0.1, 8), weight: .medium, design: .rounded)) // Scaled font
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, max(baseSize * 0.05, 4))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                }
                .padding(max(baseSize * 0.1, 8)) // Scaled padding
                .background(
                    RoundedRectangle(cornerRadius: max(baseSize * 0.15, 10)) // Scaled corner radius
                        .fill(.ultraThinMaterial)
                        .opacity(0.8) // Slightly more opaque background
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))

            } else {
                // Static lock icon when not showing info
                Image(systemName: "lock.fill")
                    .font(.system(size: baseSize * 0.25)) // Scaled icon size
                    .foregroundColor(.white.opacity(0.7))
                    .scaleEffect(animateRestriction ? 1.1 : 1.0) // Keep pulse animation
                     .transition(.opacity) // Simple transition for static icon
            }
        }
        // Make overlay tappable only when showing info (to dismiss?)
        .contentShape(Rectangle())
        .onTapGesture {
             if showHostInfo {
                 withAnimation(.easeOut(duration: 0.2)) {
                     showHostInfo = false
                 }
             }
         }
    }

     // Helper for corner radius consistency
     private var cardCornerRadius: CGFloat { max(baseSize * 0.2, 12) } // Scaled corner radius with minimum

    // Add this function to handle the tap
    private func handleSpaceTap() {
        print("DEBUG: MapSpaceCard Button TAPPED for space: \(space.id)")
        if ((spacesViewModel.selectedSpace?.isBlockedFromSpace) != nil) {
            print("DEBUG: User blocked from space \(space.id)")
            showBlockedModal = true
        } else if isHostOfActiveSpace && !isCurrentUserHostOfThisSpace {
            print("DEBUG: User is hosting another active space, cannot join \(space.id)")
            withAnimation(.spring()) {
                showHostActiveModal = true
            }
        } else {
           
                print("DEBUG: Handling Card Tap (no fanout) for space: \(space.id)")
                withAnimation(.spring()) {
                    spacesViewModel.spaceCardTapped(space: space)
                }
            
        }
    }

    // --- Body ---
    var body: some View {
        VStack(alignment: .center, spacing: verticalSpacing) {
            // 1. Stories section - keep exactly as is
            if let story = story {
                MapStoriesView(stories: [story], zoomLevel: zoomLevel)
                    .environmentObject(spacesViewModel)
                    .frame(height: calculatedStoryHeight)
                    .opacity(zoomLevel >= 12 ? 1.0 : 0.0)
                    .animation(.easeInOut, value: zoomLevel)
            } else {
                Spacer()
                    .frame(height: calculatedStoryHeight)
                    .opacity(0)
            }
            
            // 2. Main card ZStack
            ZStack {
                // Main card content
                VStack(alignment: .center, spacing: 0) {
                    Spacer(minLength: 0)
                    
                    HStack(spacing: max(baseSize * 0.1, 5)) {
                     
                            Spacer().frame(width: baseSize * 0.3)
                        
                        
                       
                            ZStack {
                                Circle()
                                    .fill(.red)
                                    .frame(width: baseSize * 0.15, height: baseSize * 0.15)
                                
                                Circle()
                                    .stroke(.red.opacity(0.5), lineWidth: 1 * scaleFactor)
                                    .frame(width: baseSize * 0.2, height: baseSize * 0.2)
                                    .scaleEffect(animateGradient ? 1.2 : 1.0)
                                    .opacity(animateGradient ? 0.0 : 0.5)
                                    .animation(
                                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                        value: animateGradient
                                    )
                            }
                            .frame(width: baseSize * 0.25, height: baseSize * 0.25)
                            
                            SoundIndicatorView(zoomLevel: zoomLevel)
                                .scaleEffect(max(elementScale * 0.6, 0.4))
                                .frame(width: baseSize * 0.25, height: baseSize * 0.25)
                        
                        
                     /*   Text(space.state.mapPinString)
                            .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, max(baseSize * 0.1, 4))
                            .padding(.vertical, max(baseSize * 0.05, 2))
                        
                        Spacer(minLength: 0)
                        
                        if space.state == .running {
                            Text("\(space.listeners.count)")
                                .font(.system(size: countFontSize, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .padding(max(baseSize * 0.08, 4))
                                .background(Circle().fill(Color.white.opacity(0.15)))
                        } else {
                            Spacer().frame(width: baseSize * 0.2)
                        }*/
                    }
                    .padding(.horizontal, max(baseSize * 0.15, 8))
                    
                    Spacer(minLength: 0)
                }
                .frame(width: cardWidth, height: cardHeight)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: animateGradient ? .topLeading : .bottomTrailing,
                        endPoint: animateGradient ? .bottomTrailing : .topLeading
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                .shadow(color: gradientColors[0].opacity(0.3), radius: max(5 * scaleFactor, 2), x: 0, y: max(3 * scaleFactor, 1))
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: max(1 * scaleFactor, 0.5)
                        )
                )
                .contentShape(Rectangle()) // Ensure the entire area is tappable
                .onTapGesture {
                    handleSpaceTap()
                }
                .scaleEffect(isHovered ? 0.95 : 1.0) // Add press animation
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                
                // Lock overlay
                if isHostOfActiveSpace && !isCurrentUserHostOfThisSpace {
                    lockOverlay
                        .frame(width: cardWidth, height: cardHeight)
                        .allowsHitTesting(true)
                }
            }
        }
        .frame(width: baseSize, height: totalHeight, alignment: .center)
        .onAppear {
            if !animateGradient {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    animateGradient = true
                    if isHostOfActiveSpace && !isCurrentUserHostOfThisSpace {
                        animateRestriction = true
                    }
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
                if isHostOfActiveSpace && !isCurrentUserHostOfThisSpace {
                    showHostInfo = hovering
                }
            }
        }
        .onChange(of: showHostInfo) { newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseEffect = 1.2
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulseEffect = 1.0
                }
            }
        }
        .fullScreenCover(isPresented: $showBlockedModal) {
            BlockedUserModal(isPresented: $showBlockedModal)
        }
        .fullScreenCover(isPresented: $showHostActiveModal) {
            HostActiveSpaceModal(isPresented: $showHostActiveModal)
        }
    }
}

struct MapSpaceCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/*
extension ImageCacheManager {
    func createSignedRequest(for url: URL) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        let dateString = dateFormatter.string(from: Date())
        
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let pathComponents = urlComponents?.path.components(separatedBy: "/")
        let fileName = pathComponents?.last ?? ""
        
        let stringToSign = """
        GET
        
        
        \(dateString)
        /\(Config.digitalOcean.bucket)/\(fileName)
        """
        
        let signature = stringToSign.hmac(key: Config.digitalOcean.secretKey)
        
        request.setValue(dateString, forHTTPHeaderField: "Date")
        request.setValue("AWS \(Config.digitalOcean.accessKey):\(signature)", forHTTPHeaderField: "Authorization")
        
        return request
    }
}
*/

