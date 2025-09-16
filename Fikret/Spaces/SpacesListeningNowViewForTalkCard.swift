//
//  SpacesListeningNowView.swift
//  Spaces
//
//  Created by amos.gyamfi@getstream.io on 11.2.2023.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import SwiftUI
import PhotosUI
import Ably
//import FirebaseFirestore
//import TwitterCloneUI

private func getButtonTextForRunningState(isInSpace: Bool, isHost: Bool) -> String {
    if isInSpace {
        return isHost ? "" : "Leave room"
    }
    return "Join fikret"
}

private func getButtonTextForPlannedState(isHost: Bool) -> String {
    return isHost ? "Start fikret" : "Waiting for space to start"
}
private func participantRole(isHost: Bool) -> String {
    isHost ? "🔉 Host" : "🔇Speaker"
}
private func reconnectingOverlayView() -> some View {
    ZStack {
        Color(white: 0, opacity: 0.75)
        ProgressView().tint(.white)
        Text("Reconnecting")
    }
}

// Categories/Interests View Component
struct CategoriesInterestsView: View {
    let space: Space
    
    // ✅ SIMPLE: Direct computed property - no async loading needed
    private var spaceCategories: [Category] {
        let spaceCategoryIds = space.categories ?? []
        return Category.staticCategories.filter { category in
            spaceCategoryIds.contains(category.id)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Space Interests")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Categories ScrollView
            if !spaceCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(spaceCategories.prefix(8)) { category in
                            CategoryPillView(category: category)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                // Empty state
                HStack {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("No interests selected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 16)
    }
}

// Category Pill View Component
struct CategoryPillView: View {
    let category: Category
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 6) {
            Text(category.icon)
                .font(.system(size: 14))
            
            Text(category.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: category.color).opacity(0.8),
                    Color(hex: category.color).opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
        .shadow(color: Color(hex: category.color).opacity(0.3), radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
}


public struct SpacesListeningNowViewForTalkCard: View {
    init(onTalkButtonTap: @escaping () -> Void, showConfirmationModal: Binding<Bool>) {
        self.onTalkButtonTap = onTalkButtonTap
        self._showConfirmationModal = showConfirmationModal
    }
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: SpacesViewModel
    @State private var requestSent = false
    @State private var isShowingGuests = false
    @State private var showInviteQueueView = false
    @State private var isExpanded = false
    let bottomBarHeights = stride(from: 0.5, through: 1.0, by: 0.1).map { PresentationDetent.fraction($0) }
    
    private let onTalkButtonTap: () -> Void
    
    @State private var showGuide = false
    @State private var dragOffset: CGSize = .zero
    
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @State private var animateGradient = false
    @State private var scrollOffset: CGFloat = 0
    @State private var searchText = ""
    @State private var isSearching = false
    @Binding var showConfirmationModal: Bool
    @State private var isAnimating = false
    // ✅ REMOVED: Custom overlay state - using standard iOS notifications instead
    
    @State private var audioLevel: CGFloat = 0.0
    
    // ✅ ADDED: Real-time participant monitoring
    @State private var presenceTimer: Timer?

    @State private var showUserTopicModal = false
    @State private var selectedUserTopic: String?
    // Audio wave animation timer
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    let gridColumns = [GridItem(.adaptive(minimum: 80))]
    var vSpacing: CGFloat = 24.0
    
    /*  private func validateDismissPermissions(itemId: String) -> Bool {
     guard let space = viewModel.selectedSpace else { return false }
     // Allow hosts to dismiss any image
     if viewModel.isHost { return true }
     
     // Allow users to dismiss their own uploads
     if let item = canvasItems.first(where: { $0.id == itemId }),
     item.uploaderId == String(viewModel.tweetData.user?.id) {
     return true
     }
     return false
     }*/
    
    /*  private func updateCanvasItem(spaceId: String, itemId: String, data: [String: Any]) async throws {
     do {
     try await Firestore.firestore()
     .collection("spaceCanvas")
     .document(spaceId)
     .collection("canvasItems")
     .document(itemId)
     .updateData(data)
     } catch {
     print("❌ Failed to update canvas item: \(error)")
     throw error
     }
     }*/
    var buttonText: String {
        return getButtonTextForRunningState(isInSpace: viewModel.isInSpace, isHost: viewModel.isHost)
    }
    
    
    
    var buttonDisabled: Bool {
        /*  if let space = viewModel.selectedSpace {
         if space.state == .finished { return true }
         
         }*/
        return false
    }
    
    private var removeButton: some View {
        Button {
            // Find the first speaker who is not the host
            if let currentUserId = viewModel.tweetData.user?.id,
               let firstNonCurrentUserSpeaker = viewModel.currentViewingSpace?.speakers
                .filter({ $0.id != currentUserId})
                .first {
                // Set the selected speaker's ID for removal confirmation
                viewModel.selectedUserForRemoval = firstNonCurrentUserSpeaker
                viewModel.showRemoveUserModal = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.fill.xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .symbolEffect(.bounce)
                Text("Remove User")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF8C42")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
            .shadow(radius: 5)
        }
        .padding(.trailing, 8)
        .disabled(viewModel.currentViewingSpace?.speakers.count ?? 0 < 2)
        .opacity(viewModel.currentViewingSpace?.speakers.count ?? 0 >= 1 ? 1 : 0.4)
        .scaleEffect(viewModel.currentViewingSpace?.speakers.count ?? 0 >= 1 ? 1.0 : 0.9)
        .animation(.spring(), value: viewModel.currentViewingSpace?.speakers.count ?? 0 >= 1)
        .onAppear {
            print("🔄 Remove Button - Speakers Count: \(viewModel.currentViewingSpace?.speakers.count ?? 0)")
        }
    }
    
    private var closeSpaceButton: some View {
        Button {
            viewModel.showSpaceView = false
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    let heartPlus = UIImage(named: "heart_plus")
    
    @State private var isShowingReactionsMenu = false
    @State private var wantToSpeak = false
    @State private var isShowingNewComment = false
   
    
    private var inviteButtonNext: some View {
        Button(action: {
            Task {
                if let firstUser = viewModel.currentViewingSpace?.queue.participants.sorted(by: { $0.position < $1.position }).first {
                    print("🔄 [InviteQueueView] Inviting user with ID: \(firstUser.id)")
         /*           await viewModel.inviteUserFromQueue(userId: firstUser.id)*/
                }
            }
        }) {
            Text("Invite Next")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(LinearGradient(gradient: Gradient(colors: [.purple, .blue]), startPoint: .leading, endPoint: .trailing)))
                .shadow(radius: 5)
        }
        .padding(.trailing, 8)
        .disabled(viewModel.currentViewingSpace?.queue.participants.isEmpty ?? true)
        .opacity(viewModel.currentViewingSpace?.queue.participants.isEmpty ?? true ? 0.4 : 1)
        .scaleEffect(viewModel.currentViewingSpace?.queue.participants.isEmpty ?? true ? 0.9 : 1.0)
        .animation(.spring(), value: viewModel.currentViewingSpace?.queue.participants.isEmpty ?? true)
    }
    
    @State private var showImagePicker = false
    
    private var uploadImageButton: some View {
        Button {
            showImagePicker = true
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .padding(12)
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 5)
        }
        .fullScreenCover(isPresented: $showImagePicker) {
            /*     ImagePickerView(
             isPresented: $showImagePicker,
             onImageSelected: { imageURL in
             Task {
             await viewModel.uploadAndSaveImageForCanvas(
             imageURL: imageURL,
             spaceId: String(viewModel.selectedSpace!.id) ?? ""
             )
             try? FileManager.default.removeItem(at: imageURL)
             }
             }
             )*/
        }
    }
    /*
     // Simplified ImagePickerView
     struct ImagePickerView: UIViewControllerRepresentable {
     @Binding var isPresented: Bool
     let onImageSelected: (URL) -> Void
     
     func makeUIViewController(context: Context) -> CreatePostVCWithMediaPicker {
     let vc = CreatePostVCWithMediaPicker()
     vc.delegate = context.coordinator as! any CreatePostVCWithMediaPickerDelegate
     return vc
     }
     
     func updateUIViewController(_ uiViewController: CreatePostVCWithMediaPicker, context: Context) {}
     
     func makeCoordinator() -> Coordinator {
     Coordinator(self)
     }
     
     class Coordinator: NSObject, CreatePostVCDelegate {
     let parent: ImagePickerView
     
     init(_ parent: ImagePickerView) {
     self.parent = parent
     }
     
     func didCapturePhoto(_ image: UIImage) {
     if let imageURL = compressImage(image) {
     parent.onImageSelected(imageURL)
     parent.isPresented = false
     }
     }
     
     func didCancelPhotoCapture() {
     parent.isPresented = false
     }
     
     func didCaptureLivePhoto(_ livePhoto: PHLivePhoto, stillImage: UIImage) {
     if let imageURL = compressImage(stillImage) {
     parent.onImageSelected(imageURL)
     parent.isPresented = false
     }
     }
     
     private func compressImage(_ image: UIImage) -> URL? {
     let targetSize = CGSize(width: 1024, height: 1024)
     let resizedImage = image.resized(to: targetSize)
     
     guard let data = resizedImage?.jpegData(compressionQuality: 0.7) else {
     return nil
     }
     
     let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory())
     .appendingPathComponent(UUID().uuidString)
     .appendingPathExtension("jpg")
     
     do {
     try data.write(to: tempUrl)
     return tempUrl
     } catch {
     print("Compression save failed: \(error)")
     return nil
     }
     }
     }*/
    
    // CanvasViewModel.swift
    
    
    
    // Handle image upload flow
    
    // Dismiss functionality
    func dismissCanvasItem(_ itemId: String, spaceId: String) async {
        do {
            /*if validateDismissPermissions(itemId: itemId) {
             try await updateCanvasItem(
             spaceId: spaceId,
             itemId: itemId,
             data: ["status": "dismissed"]
             )
             }*/
        } catch {
            print("❌ Failed to dismiss canvas item: \(error)")
        }
    }
    private func liveIndicatorView() -> some View {
        // Location ticker only - no LIVE indicator
        Group {
            if !viewModel.isInSpace && !viewModel.isHost {
                locationTickerView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)).animation(.spring(response: 0.6, dampingFraction: 0.8)),
                        removal: .opacity.combined(with: .move(edge: .trailing)).animation(.spring(response: 0.4, dampingFraction: 0.9))
                    ))
            }
        }
    }
    
    // ✅ FIXED: Location ticker view with full width and better text handling
    private func locationTickerView() -> some View {
        HStack(spacing: 8) {
            // ✅ REMOVED: Location icon since we have separate Instagram location section
            
            // Simple location text - full width with proper truncation
            if let hostLocation = viewModel.currentViewingSpace?.hostLocation, !hostLocation.isEmpty {
                Text(formatLocationForDisplay(hostLocation))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Use full available width
            } else {
                Text("Location unavailable")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading) // ✅ FIXED: Use full available width
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // ✅ UPDATED: Helper function to format location string for display with smart truncation
    private func formatLocationForDisplay(_ locationString: String) -> String {
        // Handle empty location
        guard !locationString.isEmpty else {
            return "📍 Location unavailable"
        }
        
        // Helper function to truncate long strings intelligently
        func smartTruncate(_ text: String, maxLength: Int = 25) -> String {
            if text.count <= maxLength {
                return text
            }
            
            // Try to truncate at word boundaries
            let truncated = String(text.prefix(maxLength))
            if let lastSpaceIndex = truncated.lastIndex(of: " ") {
                return String(truncated[..<lastSpaceIndex]) + "..."
            } else {
                return truncated + "..."
            }
        }
        
        // Handle format: "Country|City" or "Country" only
        if locationString.contains("|") {
            // Format: "Country|City"
            let components = locationString.split(separator: "|", maxSplits: 1)
            if components.count == 2 {
                let country = String(components[0]).trimmingCharacters(in: .whitespaces)
                let city = String(components[1]).trimmingCharacters(in: .whitespaces)
                
                // Show both country and city with smart truncation
                if !city.isEmpty {
                    let countryTruncated = smartTruncate(country, maxLength: 15)
                    let cityTruncated = smartTruncate(city, maxLength: 15)
                    return "📍 \(countryTruncated), \(cityTruncated)"
                } else {
                    return "📍 \(smartTruncate(country, maxLength: 25))"
                }
            }
        }
        
        // Fallback: Country only format (no pipe separator) with smart truncation
        let cleanedLocation = locationString.trimmingCharacters(in: .whitespaces)
        return "📍 \(smartTruncate(cleanedLocation, maxLength: 25))"
    }
    
    private func peopleCountView() -> some View {
        HStack {
            Image(systemName: "person.3.fill")
                .font(.system(size: 20))
                .foregroundColor(.gray)
            
            
        }
    }
    
    private var endOrLeaveButton: some View {
        Button(action: {
            Task {
                await viewModel.spaceButtonTapped()
            }
        }) {
            Text(getButtonTextForRunningState(isInSpace: viewModel.isInSpace, isHost: viewModel.isHost))
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(LinearGradient(gradient: Gradient(colors: [.red, .pink]), startPoint: .leading, endPoint: .trailing))
                .cornerRadius(8)
                .shadow(radius: 5)
        }
    }
    
    private struct SpeakerAvatarForTalkCard: View {
        let image: String? // ✅ FIXED: Use URL? directly without safeURL()
        let isActive: Bool
        let isHost: Bool // ✅ ADDED: Identify if this is the host
        let isMuted: Bool // ✅ ADDED: Mute state parameter
        let speakerId: Int64 // ✅ ADDED: Speaker ID for navigation
        let speakerUsername: String // ✅ ADDED: Speaker username for navigation
        let speaker: SpaceParticipant // ✅ ADDED: Speaker object for peerID access
        @EnvironmentObject var viewModel: SpacesViewModel
        @EnvironmentObject var tweetData: TweetData // ✅ ADDED: Access to tweetData
        @State private var showProfile = false // ✅ ADDED: State for profile navigation
         @State private var hasSyncedOnlineStatus = false // ✅ ADDED: Track if we've synced online status

        var body: some View {
            Button(action: {
                // ✅ SIMPLE: Show profile when tapped (same as conversations tab)
                if !(viewModel.isInSpace && !viewModel.isHost) {
                    showProfile = true
                }
            }) {
                GeometryReader { geometry in
                    let size = min(geometry.size.width, geometry.size.height)
                                        ZStack {
                        if let imageURL = image {
                            CachedAsyncImage(url: imageURL.safeURL()) { phase in
                            switch phase {
                            case .empty:
                                Color.clear
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: size * 1, height: size * 1)
                                    .clipShape(Circle())
                                    .shadow(radius: 3)
                            case .failure(_):
                                // Error placeholder
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
                            .frame(width: size * 1, height: size * 1)
                            .shadow(radius: 3)
                            @unknown default:
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
                            .frame(width: size * 1, height: size * 1)
                            .shadow(radius: 3)
                            }
                        }
                    } else {
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
                            .frame(width: size * 1, height: size * 1)
                            .shadow(radius: 3)
                        }
                        
                        // ✅ ADDED: Mute indicator overlay - only show when in space
                        if isMuted && viewModel.isInSpace {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(Color.red.opacity(0.9))
                                            .frame(width: size * 0.3, height: size * 0.3)
                                        
                                        Image(systemName: "mic.slash.fill")
                                            .font(.system(size: size * 0.15, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .frame(width: size, height: size)
                        }
                    }
                    .overlay(
                        // ✅ ADDED: Online status indicator for host AND non-host users with peerID == nil
                        Group {
                            if isHost && !viewModel.isInSpace {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        // Online status dot for host
                                        Circle()
                                            .fill(
                                                (viewModel.currentViewingSpace?.isHostOnline ?? false) ?
                                                LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                                LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            )
                                            .frame(width: 16, height: 16)
                                            .overlay(Circle().stroke(.white, lineWidth: 2))
                                            .shadow(color: .black.opacity(0.3), radius: 2)
                                    }
                                    .padding(.trailing, 4)
                                }
                                .padding(.bottom, 4)
                            } else if !isHost && speaker.peerID == nil {
                                // ✅ NON-HOST: Use speaker's isOnline status from presence data
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        // Online status dot - use speaker's actual online status
                                        Circle()
                                            .fill(
                                                (speaker.isOnline ?? true) ?
                                                LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                                LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            )
                                            .frame(width: 16, height: 16)
                                            .overlay(Circle().stroke(.white, lineWidth: 2))
                                            .shadow(color: .black.opacity(0.3), radius: 2)
                                    }
                                    .padding(.trailing, 4)
                                }
                                .padding(.bottom, 4)
                               
                            }
                        }
                    )
                }
                .aspectRatio(1, contentMode: .fit)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isInSpace && !viewModel.isHost) // ✅ DISABLE: When in space as participant
            // Removed opacity change - speakers should remain visible when in space
            // ✅ SIMPLE: Use fullScreenCover for navigation (same as conversations tab)
            .fullScreenCover(isPresented: $showProfile) {
                TwitterProfileView(
                    userId: speakerId,
                    username: speakerUsername,
                    initialProfile: nil
                )
                .environmentObject(viewModel.tweetData)
                .environmentObject(viewModel)
                .interactiveDismissDisabled()
            }
            
            
        }
    }
    
    struct AudioDetectionAnimationForTalkCard: View {
        @State private var animate = false
        
        var body: some View {
            HStack(spacing: 2) {
                ForEach(0..<10) { index in
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.8), .blue.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 3, height: CGFloat.random(in: 8...30))
                        .scaleEffect(y: animate ? CGFloat.random(in: 0.3...0.8) : 1, anchor: .bottom)
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
    
    // ✅ REALISTIC: Each speaker has completely independent, random animation patterns
    struct FakeConversationAnimation: View {
        let speakerId: Int64
        @EnvironmentObject var viewModel: SpacesViewModel
        @State private var animate = false
        @State private var isActive = false
        @State private var hasStartedConversation = false
        
        // ✅ UNIQUE: Each speaker gets different random values
        private let speakerSeed: Int
        private let baseDelay: Double
        private let baseDuration: Double
        private let baseSkip: Double
        
        init(speakerId: Int64) {
            self.speakerId = speakerId
            // ✅ UNIQUE: Use speaker ID to generate different random patterns
            self.speakerSeed = Int(speakerId % 1000) // Ensure different seeds for different speakers
            self.baseDelay = Double.random(in: 0.5...3.0)
            self.baseDuration = Double.random(in: 1.5...4.5)
            self.baseSkip = Double.random(in: 0.8...3.2)
        }
        
        var body: some View {
            HStack(spacing: 2) {
                ForEach(0..<10) { index in
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.6), .blue.opacity(0.4)],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 3, height: animate && isActive ? getRandomHeight(for: index) : 4)
                        .scaleEffect(y: animate && isActive ? getRandomScale(for: index) : 1, anchor: .bottom)
                        .animation(
                            Animation.easeInOut(duration: getRandomDuration(for: index))
                                .repeatForever(autoreverses: true)
                                .delay(getRandomDelay(for: index)),
                            value: animate
                        )
                }
            }
            .onAppear {
                animate = true
                // ✅ UNIQUE: Each speaker starts at different time
                waitForTransitionCompletion()
            }
        }
        
        // ✅ UNIQUE: Each speaker waits different amount of time
        private func waitForTransitionCompletion() {
            let transitionDelay = 0.8 + baseDelay // Different delay per speaker
            print("🎭 [FAKE-ANIM] Speaker \(speakerId) will start in \(String(format: "%.1f", transitionDelay))s")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDelay) {
                if (viewModel.currentViewingSpace?.speakers.count ?? 0) > 1 {
                    self.hasStartedConversation = true
                    self.startUniqueConversationCycle()
                }
            }
        }
        
        // ✅ UNIQUE: Each speaker has completely different conversation pattern
        private func startUniqueConversationCycle() {
            guard hasStartedConversation else { return }
            
            // ✅ VARIED: Different timing for each speaker
            let randomDelay = Double.random(in: 0...baseDelay * 2)
            let animateDuration = Double.random(in: baseDuration * 0.7...baseDuration * 1.3)
            let skipDuration = Double.random(in: baseSkip * 0.6...baseSkip * 1.4)
            
            print("🎭 [FAKE-ANIM] Speaker \(speakerId) - Delay: \(String(format: "%.1f", randomDelay))s, Duration: \(String(format: "%.1f", animateDuration))s, Skip: \(String(format: "%.1f", skipDuration))s")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) {
                guard self.hasStartedConversation else { return }
                self.isActive = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + animateDuration) {
                    guard self.hasStartedConversation else { return }
                    self.isActive = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + skipDuration) {
                        guard self.hasStartedConversation else { return }
                        self.startUniqueConversationCycle()
                    }
                }
            }
        }
        
        // ✅ UNIQUE: Each bar has different random values based on speaker
        private func getRandomHeight(for index: Int) -> CGFloat {
            let baseHeight = Double(index) * 0.3 + Double(speakerSeed % 10)
            return CGFloat(baseHeight + Double.random(in: 8...22))
        }
        
        private func getRandomScale(for index: Int) -> CGFloat {
            let baseScale = Double(speakerSeed % 5) * 0.1 + 0.3
            return CGFloat(baseScale + Double.random(in: 0.2...0.6))
        }
        
        private func getRandomDuration(for index: Int) -> Double {
            let baseDuration = Double(speakerSeed % 3) * 0.2 + 0.4
            return baseDuration + Double.random(in: 0.3...0.7)
        }
        
        private func getRandomDelay(for index: Int) -> Double {
            let baseDelay = Double(speakerSeed % 4) * 0.1
            return baseDelay + Double.random(in: 0.1...0.3)
        }
    }
    
    // ✅ SMOOTH TRANSITIONS: Skeleton loading for user appearance
    struct SkeletonUserView: View {
        var body: some View {
            VStack(spacing: 8) {
                // Skeleton avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(colors: [.purple.opacity(0.5), .blue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2
                            )
                    )
                
                // Skeleton name
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 16)
                
                // Skeleton role
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 12)
            }
        }
    }
    
    private static func speakerRoleText(for speaker: SpaceParticipant, viewModel: SpacesViewModel) -> String {
        if speaker.id == viewModel.tweetData.user!.id && viewModel.isHost {
            return "Host"
        } else if speaker.id != viewModel.tweetData.user!.id && !viewModel.isHost {
            return "Host"
        } else {
            return "Speaker"
        }
    }
    
    // ✅ MOVED: Helper function outside main struct for nested structs to access
    private static func speakerInfoView(for speaker: SpaceParticipant, geometry: GeometryProxy, viewModel: SpacesViewModel) -> some View {
        VStack(spacing: 8) {
            // ✅ CLEAN: Simple avatar with sand effects
            SpeakerAvatarForTalkCard(
                image: speaker.imageURL,
                isActive: viewModel.activeSpeakerId == speaker.peerID,
                isHost: speaker.id == viewModel.currentViewingSpace?.hostId,
                isMuted: speaker.isMuted ?? false,
                speakerId: speaker.id,
                speakerUsername: speaker.username ?? speaker.name ?? "user_\(speaker.id)",
                speaker: speaker
            )
            .frame(width: min(geometry.size.width * 0.2, 100), height: min(geometry.size.width * 0.2, 100))
            
            
                            // ✅ CLEAN: Text display
            VStack(spacing: 2) {
                Text(speaker.name ?? "")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(maxWidth: geometry.size.width * 0.25)
                
                if let username = speaker.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(maxWidth: geometry.size.width * 0.25)
                }
            }
            
            
            Text(SpacesListeningNowViewForTalkCard.speakerRoleText(for: speaker, viewModel: viewModel))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            // ✅ DIRECT: Show real active speaker OR fake conversation animation
            if viewModel.activeSpeakerId == speaker.peerID && viewModel.activeSpeakerId != nil {
                AudioDetectionAnimationForTalkCard()
                    .frame(height: 13)
                    .transition(.opacity)
            } else if (viewModel.currentViewingSpace?.speakers.count ?? 0) > 1  && speaker.peerID == nil  {
                FakeConversationAnimation(speakerId: speaker.id)
                    .frame(height: 13)
                    .transition(.opacity)
            }
        }
        .frame(width: geometry.size.width * 0.25)

    }
    
    // ✅ SIMPLIFIED: Smooth speaker animation system using only essential reactive variables
    struct SpeakerContainerView: View {
        let speaker: SpaceParticipant
        let geometry: GeometryProxy
        @EnvironmentObject var viewModel: SpacesViewModel
        
        // Animation state
        @State private var isAppearing = false
        @State private var targetPosition: CGSize = .zero
        
        var body: some View {
            SpacesListeningNowViewForTalkCard.speakerInfoView(for: speaker, geometry: geometry, viewModel: viewModel)
                .scaleEffect(isAppearing ? 1.0 : 0.8)
                .opacity(isAppearing ? 1.0 : 0.0)
                .offset(targetPosition)
                .onAppear {
                         
                    // Animate from off-screen to center
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        isAppearing = true
                        targetPosition = .zero
                    }
                }
                .onChange(of: viewModel.speakerPositions[speaker.id]) { newPosition in
                    // Animate to new position when changed
                    if let newPosition = newPosition {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            targetPosition = newPosition
                        }
                    }
                }
                // ✅ SIMPLIFIED: Use only essential reactive variables for smooth transitions
                .onChange(of: viewModel.enteringSpeakerIds.contains(speaker.id)) { isEntering in
                    if isEntering {
                        // Speaker is entering - start entrance animation
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            isAppearing = true
                        }
                    }
                }
                .onChange(of: viewModel.leavingSpeakerIds.contains(speaker.id)) { isLeaving in
                    if isLeaving {
                        // Speaker is leaving - start exit animation
                        withAnimation(.easeOut(duration: 0.3)) {
                            isAppearing = false
                        }
                    }
                }
        }
    }
    
    struct AnimatedSpeakerView: View {
        let speaker: SpaceParticipant
        let geometry: GeometryProxy
        let isEntering: Bool
        @EnvironmentObject var viewModel: SpacesViewModel
        
        @State private var animationState: AnimationState = .initial
        
        enum AnimationState {
            case initial, appearing, visible, disappearing, gone
        }
        
        var body: some View {
            SpacesListeningNowViewForTalkCard.speakerInfoView(for: speaker, geometry: geometry, viewModel: viewModel)
                .scaleEffect(animationState == .initial ? 0.5 :
                            animationState == .appearing ? 0.8 : 1.0)
                .opacity(animationState == .gone ? 0.0 : 1.0)
                .offset(x: calculateEntryOffset())
                .onAppear {
                     
                    if isEntering {
                        animateEntry()
                    }
                }
                .onChange(of: isEntering) { newValue in
                    if !newValue {
                        animateExit()
                    }
                }
        }
        
        private func animateEntry() {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animationState = .appearing
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    animationState = .visible
                }
            }
        }
        
        private func animateExit() {
            withAnimation(.easeOut(duration: 0.3)) {
                animationState = .disappearing
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeIn(duration: 0.2)) {
                    animationState = .gone
                }
            }
        }
        
        private func calculateEntryOffset() -> CGFloat {
            switch animationState {
            case .initial: return 100
            case .appearing: return 20
            case .visible: return 0
            case .disappearing: return -20
            case .gone: return -100
            }
        }
    }
    
    func speakersSection(geometry: GeometryProxy) -> some View {
        VStack {
            if let speakers = viewModel.currentViewingSpace?.speakers {
                HStack(spacing: geometry.size.width * 0.1) {
                    Spacer()
                    
                    ForEach(speakers, id: \.id) { speaker in
                        SpeakerContainerView(speaker: speaker, geometry: geometry)
                            .id("speaker-\(speaker.id)")
                            .animation(.spring(response: 0.3), value: viewModel.activeSpeakerId)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, geometry.size.height * 0.02)
                // ✅ SINGLE COORDINATED ANIMATION
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: speakers)
                // ✅ CALCULATE POSITIONS BEFORE RENDERING
                .onAppear {
                    let initialPositions = viewModel.calculatePositions(speakers, geometry)
                    viewModel.speakerPositions = initialPositions
                }
                // ✅ BATCHED SPEAKER CHANGES
                .onChange(of: speakers) { newSpeakers in
                    // Calculate everything first
                    let newPositions = viewModel.calculatePositions(newSpeakers, geometry)
                    let newEnteringIds = viewModel.findNewSpeakers(newSpeakers)
                    let newLeavingIds = viewModel.findLeavingSpeakers(newSpeakers)
                    
                    // Then animate everything together
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        viewModel.speakerPositions = newPositions
                        viewModel.enteringSpeakerIds = newEnteringIds
                        viewModel.leavingSpeakerIds = newLeavingIds
                    }
                    
                    // Cleanup after animation
                    viewModel.cleanupLeavingSpeakers()
                }
            }
        }
    }
    
    /* struct RemoveUserConfirmationModal: View {
     @Binding var isPresented: Bool
     let userName: String
     let onConfirm: () -> Void
     
     var body: some View {
     VStack(spacing: 20) {
     Text("Remove \(userName)?")
     .font(.headline)
     .padding()
     
     Text("Are you sure you want to remove this user from the space?")
     .font(.subheadline)
     .multilineTextAlignment(.center)
     .padding()
     
     HStack(spacing: 20) {
     Button("Cancel") {
     isPresented = false
     }
     .font(.system(size: 16, weight: .semibold))
     .foregroundColor(.secondary)
     .padding()
     .background(Color.secondary.opacity(0.1))
     .clipShape(Capsule())
     
     Button("Remove") {
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
     }
     }*/
    struct RadioWaveAnimationForTalkCard: View {
        @State private var animate = false
        
        var body: some View {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height: CGFloat = 10 // Height of the wave
                
                ZStack {
                    ForEach(0..<3) { index in
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: width * 0.8, height: height)
                            .offset(y: CGFloat(index) * 10)
                            .scaleEffect(animate ? 1.2 : 1)
                            .opacity(animate ? 0 : 1)
                            .animation(
                                Animation.easeOut(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.3),
                                value: animate
                            )
                    }
                }
                .onAppear {
                    animate = true
                }
            }
        }
    }
    
    
    
    @State private var canvasItems: [CanvasItem] = []
    @State private var isShowingCanvas: Bool = false
    @State private var imageTransitionId = UUID()
    @State private var showDismissConfirmation = false
    @State private var selectedCanvasItem: CanvasItem?
    
    
    // Update the canvasSection view
    var canvasSection: some View {
        VStack(spacing: 0) {
            if !canvasItems.isEmpty {
                CanvasViewForTalkCard(
                    items: canvasItems,
                    isVisible: $isShowingCanvas,
                    onDismiss: { item in
                        selectedCanvasItem = item
                        showDismissConfirmation = true
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .alert("Remove Image?", isPresented: $showDismissConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Remove", role: .destructive) {
                        if let item = selectedCanvasItem {
                            Task {
                                /* await viewModel.dismissCanvasItem(item.id, spaceId: String(viewModel.selectedSpace!.id))*/
                            }
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: canvasItems)
    }
    
    @State private var cardOffset: CGSize = .zero
    
    // ✅ SMOOTH TRANSITIONS: Staggered animation states for user appearance
    @State private var showUserSection = false
    @State private var showUserAvatar = false
    @State private var showUserName = false
    @State private var showUserRole = false
    
    // ✅ ADDED: Animation state for joining overlay
    @State private var isJoiningAnimating = false
    
    // ✅ UPDATED: Use space topics directly instead of currentTopic
    private var currentTopic: String {
        viewModel.currentViewingSpace?.topics?.first ?? ""
    }
    
    // ✅ ADDED: Joining space overlay view (transferred from TalkButtonWithTopicInput)
    private var joiningSpaceOverlay: some View {
        VStack(spacing: 24) {
            // Animated joining indicator
            VStack(spacing: 16) {
                // Pulsing microphone icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(isJoiningAnimating ? 1.2 : 1.0)
                        .opacity(isJoiningAnimating ? 0.6 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isJoiningAnimating)
                    
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .scaleEffect(isJoiningAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isJoiningAnimating)
                }
                
                // Topic display with fade-in animation
                VStack(spacing: 8) {
                    Text("Connecting to...")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    // ✅ ADDED: Show host location if available
                    if let hostLocation = viewModel.currentViewingSpace?.hostLocation, !hostLocation.isEmpty {
                        VStack(spacing: 4) {
                            Text("Location:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(formatLocationForDisplay(hostLocation))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .truncationMode(.tail)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.15))
                                )
                        }
                    }
                    
                    // ✅ CONDITIONAL: Use currentTopic when in space as participant, otherwise use space topics
                    let topic = (viewModel.isInSpace && !viewModel.isHost ? viewModel.currentTopic : viewModel.currentViewingSpace?.topics?.first) ?? ""
                    
                    if !topic.isEmpty {
                        VStack(spacing: 4) {
                            Text("Topic:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(topic)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.15))
                                )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Loading dots animation
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isJoiningAnimating ? 1.2 : 0.8)
                        .opacity(isJoiningAnimating ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: isJoiningAnimating
                        )
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: [Color.purple.opacity(0.95), Color.blue.opacity(0.95)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            // Start animations immediately
            isJoiningAnimating = true
        }
        .onDisappear {
            // Stop animations when overlay disappears
            isJoiningAnimating = false
        }
        

    }
    
    // ✅ ADDED: Check if current user is muted - now reactive to @Published properties
    private var isCurrentUserMuted: Bool {
        guard let currentUserId = viewModel.tweetData.user?.id,
              let currentSpeaker = viewModel.currentViewingSpace?.speakers.first(where: { $0.id == currentUserId }) else {
            return false
        }
        return currentSpeaker.isMuted ?? false
    }
    

    
    // ✅ ADDED: Real-time participant monitoring functions
    private func startRealTimeMonitoring() {
        guard let currentSpace = viewModel.currentViewingSpace else {
            return
        }
        
        // ✅ JOINING CHECK: Don't start monitoring if join operation is in progress
        if viewModel.isJoining {
            print("⚠️ [MONITORING] Join operation in progress, skipping monitoring start")
            return
        }
        
        // ✅ RACE CONDITION FIX: Capture space ID at start to prevent race conditions
        let targetSpaceId = currentSpace.id
        
        print("🔒 [RACE-FIX] Starting monitoring for space ID: \(targetSpaceId)")
        
        // Stop existing timer
        presenceTimer?.invalidate()
        
        // ✅ RACE-FIX: Timer will use targetSpaceId for validation
        
        // ✅ IMMEDIATE: Trigger first check right away
        performPeriodicPresenceCheck()
        
        // Start periodic timer - check every 15 seconds
        presenceTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            // ✅ RACE CONDITION FIX: Validate space hasn't changed before periodic check
            if self.viewModel.currentViewingSpace?.id == targetSpaceId {
                self.performPeriodicPresenceCheck()
            } else {
                print("⚠️ [RACE-FIX] Space ID changed from \(targetSpaceId) to \(self.viewModel.currentViewingSpace?.id ?? -1), stopping timer")
                self.stopRealTimeMonitoring()
            }
        }
        
        print("✅ [MONITORING] Timer started with immediate trigger for space ID: \(targetSpaceId)")
    }
    
    // ✅ FIXED: Method that attaches, gets presence, then detaches
    private func performPeriodicPresenceCheck() {
        guard let currentSpace = viewModel.currentViewingSpace else {
            return
        }
        
        // ✅ RACE CONDITION FIX: Capture space ID at start to prevent race conditions
        let targetSpaceId = currentSpace.id
        let targetHostId = currentSpace.hostId
        
        // Get host's channel
        let hostChannelName = "user:\(targetHostId)"
        let tempChannel = AblyService.shared.chatClient?.channels.get(hostChannelName)
        
        guard let channel = tempChannel else {
            return
        }
        
        print("🔒 [RACE-FIX] Starting presence check for space ID: \(targetSpaceId)")
        
        // ✅ ATTACH → REQUEST → DETACH pattern
        channel.attach { error in
            if let error = error {
                print("❌ [ABLY] Failed to attach for periodic check: \(error)")
            } else {
                print("✅ [ABLY] Attached for periodic check")
                
                // Get presence data
                channel.presence.get { members, error in
                    if let error = error {
                        print("❌ [ABLY] Failed to get presence: \(error)")
                    } else {
                        // ✅ RACE CONDITION FIX: Validate space hasn't changed before processing
                        Task { @MainActor in
                            // Check if currentViewingSpace is still the same space we started with
                            if self.viewModel.currentViewingSpace?.id == targetSpaceId {
                                print("✅ [RACE-FIX] Space ID still matches, processing presence data")
                                self.viewModel.processPresenceMembers(members, targetSpaceId: targetSpaceId)
                            } else {
                                print("⚠️ [RACE-FIX] Space ID changed from \(targetSpaceId) to \(self.viewModel.currentViewingSpace?.id ?? -1), skipping processing")
                            }
                        }
                    }
                    
                    // ✅ DETACH after getting data (regardless of success/failure)
                    // ✅ DETACH PROTECTION: Check if join operation is in progress before detaching
                    if self.viewModel.isJoining {
                        print("🔒 [DETACH-PROTECTION] Join operation in progress, skipping detach for space \(targetSpaceId)")
                    } else {
                        channel.detach { detachError in
                            if let detachError = detachError {
                                print("❌ [ABLY] Error detaching after periodic check: \(detachError)")
                            } else {
                                print("✅ [ABLY] Detached after periodic check")
                            }
                        }
                    }
                }
            }
        }
    }
    

    

    
    private func stopRealTimeMonitoring() {
        print("🛑 [MONITORING] Stopping real-time monitoring")
        
        // ✅ FIXED: Only stop timer - no channels to detach since we attach/detach per request
        presenceTimer?.invalidate()
        presenceTimer = nil
        
        // ✅ RACE-FIX: Timer cleared, no tracking needed
        
        print("✅ [MONITORING] Timer stopped - no persistent channels to clean up")
    }
    
    // ✅ SIMPLIFIED: Monitoring state handler (conditions checked at call site)
    private func handleMonitoringStateChange() {
        let isHostOnline = viewModel.currentViewingSpace?.isHostOnline ?? false
        
        print("🎯 [MONITORING] Evaluating monitoring state:")
        print("  - isHostOnline: \(isHostOnline)")
        
        // ✅ SIMPLE: If host is online, start monitoring; otherwise stop
        if isHostOnline {
            print("🔄 [MONITORING] Host is online, starting monitoring")
            startRealTimeMonitoring()
        } else {
            print("⚠️ [MONITORING] Host is offline, stopping monitoring")
            stopRealTimeMonitoring()
        }
    }
    
    private struct SpaceOverlays: View {
        @EnvironmentObject var viewModel: SpacesViewModel
        
        var body: some View {
            Group {
                if viewModel.showInviteNextModal && viewModel.isHost {
                    InviteNextUserModalForTalkCard(
                        isPresented: $viewModel.showInviteNextModal,
                        lastUser: viewModel.lastUserWhoLeft,
                        queueParticipants: viewModel.currentViewingSpace?.queue.participants ?? [],
                        onInviteNext: { userId in
                            Task {
                                viewModel.showInviteNextModal = false
                                viewModel.lastUserWhoLeft = nil
                            /*    await viewModel.inviteUserFromQueue(userId: userId)*/
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: viewModel.showInviteNextModal)
                }
                if viewModel.showRemoveUserModal && viewModel.isHost {
                    RemoveUserConfirmationModal(
                        isPresented: $viewModel.showRemoveUserModal,
                        userName: viewModel.selectedUserForRemoval?.name ?? "User",
                        onConfirm: {
                            if let peerId = viewModel.selectedUserForRemoval?.peerID {
                                Task { await viewModel.removeUser(userId: peerId) }
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: viewModel.showRemoveUserModal)
                }
            }
        }
    }
    
    private struct SpaceContent: View {
        @EnvironmentObject var viewModel: SpacesViewModel
        let geometry: GeometryProxy
        
        private func speakersSection(geometry: GeometryProxy) -> some View {
            VStack {
                if let speakers = viewModel.currentViewingSpace?.speakers {
                    HStack(spacing: geometry.size.width * 0.1) {
                        Spacer()
                        
                        ForEach(speakers, id: \.id) { speaker in
                            SpeakerContainerView(speaker: speaker, geometry: geometry)
                                .id("speaker-\(speaker.id)")
                                .animation(.spring(response: 0.3), value: viewModel.activeSpeakerId)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, geometry.size.height * 0.02)
                    // ✅ SINGLE COORDINATED ANIMATION
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: speakers)
                    // ✅ CALCULATE POSITIONS BEFORE RENDERING
                    .onAppear {
                        viewModel.calculatePositions(
                            speakers,
                            geometry
                        )
                    }
                    // ✅ BATCHED SPEAKER CHANGES
                    .onChange(of: speakers) { newSpeakers in
                        // Calculate everything first
                        let newPositions = viewModel.calculatePositions(newSpeakers, geometry)
                        let newEnteringIds = viewModel.findNewSpeakers(newSpeakers)
                        let newLeavingIds = viewModel.findLeavingSpeakers(newSpeakers)
                        
                        // Then animate everything together
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            viewModel.speakerPositions = newPositions
                            viewModel.enteringSpeakerIds = newEnteringIds
                            viewModel.leavingSpeakerIds = newLeavingIds
                        }
                        
                        // Cleanup after animation
                        viewModel.cleanupLeavingSpeakers()
                    }
                }
            }
        }
        
        private func speakerInfoView(for speaker: SpaceParticipant, geometry: GeometryProxy) -> some View {
            VStack(spacing: 8) {
                SpeakerAvatarForTalkCard(
                    image: speaker.imageURL,
                    isActive: viewModel.activeSpeakerId == speaker.peerID,
                    isHost: speaker.id == viewModel.currentViewingSpace?.hostId,
                    isMuted: speaker.isMuted ?? false,
                    speakerId: speaker.id,
                    speakerUsername: speaker.username ?? speaker.name ?? "user_\(speaker.id)",
                    speaker: speaker
                )
                .frame(width: min(geometry.size.width * 0.2, 100), height: min(geometry.size.width * 0.2, 100))

                
                // ✅ CLEAN: Text display
                VStack(spacing: 2) {
                    Text(speaker.name ?? "")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(maxWidth: geometry.size.width * 0.25)
                    
                    if let username = speaker.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .frame(maxWidth: geometry.size.width * 0.25)
                    }
                }

                
                Text(speakerRoleText(for: speaker))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                // ✅ DIRECT: Show real active speaker OR fake conversation animation
                if viewModel.activeSpeakerId == speaker.peerID && viewModel.activeSpeakerId != nil {
                    AudioDetectionAnimationForTalkCard()
                        .frame(height: 13)
                        .transition(.opacity)
                } else if (viewModel.currentViewingSpace?.speakers.count ?? 0) > 1  && speaker.peerID == nil  {
                    FakeConversationAnimation(speakerId: speaker.id)
                        .frame(height: 13)
                        .transition(.opacity)
                }
            }
            .frame(width: geometry.size.width * 0.25)
        }
        
        private func speakerRoleText(for speaker: SpaceParticipant) -> String {
            if speaker.id == viewModel.tweetData.user!.id && viewModel.isHost {
                return "Host"
            } else if speaker.id != viewModel.tweetData.user!.id && !viewModel.isHost {
                return "Host"
            } else {
                return "Speaker"
            }
        }
        
        var body: some View {
            VStack(spacing: 0) {
                if let speakers = viewModel.currentViewingSpace?.speakers {
                    speakersSection(geometry: geometry)
                        .drawingGroup()
                        .id("speakers-\(speakers.count)-\(speakers.map { String($0.id) }.joined(separator: "-"))")
                }
                
                // ✅ FIXED: Push speakers UP from bottom
            }
        }
    }
    
    
    // Pulse animation modifier
    struct PulseAnimation: ViewModifier {
        @State private var isAnimating = false
        
        func body(content: Content) -> some View {
            content
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .scaleEffect(isAnimating ? 2 : 1)
                        .opacity(isAnimating ? 0 : 1)
                )
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1)
                        .repeatForever(autoreverses: false)
                    ) {
                        isAnimating = true
                    }
                }
        }
    }
    
    struct RecordingTimerView: View {
        @EnvironmentObject var viewModel: SpacesViewModel
        // ✅ REMOVED: let topic: String - now using viewModel.currentTopic directly
        @State private var isTopicExpanded = false
        // ✅ REMOVED: Sand particle bindings - no longer needed
        
        private var timeString: String {
            let minutes = Int(viewModel.recordingTimeRemaining) / 60
            let seconds = Int(viewModel.recordingTimeRemaining) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        private var progressValue: Double {
            1 - (viewModel.recordingTimeRemaining / 420.0) // 7 minutes total
        }
        
        private var topicIndicator: some View {
            /* COMMENTED OUT: Topic discussion section - not needed for now
            HStack(spacing: 6) {
                // Subtle icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "message.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Text with gradient
                Text("Discussion on")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // ✅ CONDITIONAL: Use currentTopic when in space as participant, otherwise use space topics
                let topic = (viewModel.isInSpace && !viewModel.isHost ? viewModel.currentTopic : viewModel.currentViewingSpace?.topics?.first) ?? ""
                
                if !topic.isEmpty {
                    // Topic with hashtag - using proper text truncation
                    Text("#\(topic)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(isTopicExpanded ? 2 : 1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut, value: isTopicExpanded)
                        .onTapGesture {
                            // Allow tap to expand/collapse for any length topic
                            withAnimation {
                                isTopicExpanded.toggle()
                            }
                        }
                }
                
                // ✅ CONDITIONAL: Show expand/collapse button for any topic that can be expanded
                if topic.count > 20 { // Reduced threshold for better UX
                    Button(action: {
                        withAnimation {
                            isTopicExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isTopicExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
            )
            */
            
            // ✅ SIMPLIFIED: Empty view since topic discussion is commented out
            EmptyView()
        }
        
        private var timerSection: some View {
            HStack(spacing: 12) {
                // Live indicator with pulse animation
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .modifier(PulseAnimation())
                
                Spacer()
                
                // Timer progress
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 100, height: 4)
                    
                    // Progress bar
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    viewModel.recordingTimeRemaining <= 30 ? .red : .green,
                                    viewModel.recordingTimeRemaining <= 30 ? .orange : .blue
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 100 * progressValue, height: 4)
                }
                
                // Time remaining
                Text(timeString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.recordingTimeRemaining <= 30 ? .red : .white)
                    .monospacedDigit()
                    .frame(width: 50)
            }
        }
        
        var body: some View {
            VStack(spacing: 8) {
                if viewModel.isRecordingActive {
                    timerSection
                }
                
                // ✅ SIMPLIFIED: Topic section
                topicIndicator
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                VStack(alignment: .leading, spacing: 0) {

                    // Timer/Indicator section - positioned higher since no top toolbar
                    VStack(spacing: 0) {
                        if (viewModel.currentViewingSpace?.speakers.count ?? 0) > 1 || (!viewModel.isHost && viewModel.isInSpace) {
                            RecordingTimerView()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            liveIndicatorView()
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.top, 20) // ✅ REDUCED: Move timer higher since no top toolbar
                    .padding(.bottom, 10)
                    .padding(.horizontal, 16) // ✅ ADDED: Horizontal padding for proper spacing
                    
                    GeometryReader { geometry in
                        SpaceContent(geometry: geometry)
                            .transition(.opacity)
                            .id("space-content-\(viewModel.currentViewingSpace?.id ?? 0)-\(viewModel.currentViewingSpace?.speakers.count ?? 0)")
                    }
                }
                .id("main-content-\(viewModel.currentViewingSpace?.id ?? 0)-\(viewModel.currentViewingSpace?.speakers.count ?? 0)")
                // ✅ REMOVED: .padding() that was pushing everything down
                .background(Color.black.opacity(0.95))
                
                // ✅ SMOOTH MORPHING: Categories/Interests with smooth morphing transition
                // VStack {
                //     Spacer()
                //
                //     // Categories/Interests Section at bottom of card - moved outside background
                //     if let currentSpace = viewModel.currentViewingSpace {
                //         CategoriesInterestsView(space: currentSpace)
                //             .scaleEffect(viewModel.isInSpace ? 0.85 : 1.0)
                //             .blur(radius: viewModel.isInSpace ? 2.5 : 0)
                //             .opacity(viewModel.isInSpace ? 0.3 : 1.0)
                //             .offset(y: viewModel.isInSpace ? 20 : 0)
                //             .animation(.spring(response: 0.7, dampingFraction: 0.8), value: viewModel.isInSpace)
                //     }
                // }
                // .padding(.horizontal) // ✅ ADDED: Maintain horizontal padding for proper positioning
                // .onAppear {
                //     print("🔄 [DEBUG] Main content appeared - isInSpace: \(viewModel.isInSpace)")
                // }
                
                // ✅ TOAST NOTIFICATION OVERLAY - Natural iOS style
                VStack {
                    if viewModel.showToastNotification {
                        ToastNotificationView(
                            message: viewModel.toastMessage,
                            isError: viewModel.toastIsError
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1000)
                    }
                    Spacer()
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showToastNotification)
                
                                    // ✅ SMOOTH MORPHING: Talk Button with smooth morphing transition
                VStack {
                    Spacer()
                    
                    // ✅ FIXED: Coordinated joining and room UI transitions
                    ZStack {
                        // Talk button (always present, but animated based on state)
                        TalkButtonWithTopicInput()
                            .scaleEffect((viewModel.isInSpace && !viewModel.isHost) ? 0.8 : 1.0)
                            .blur(radius: (viewModel.isInSpace && !viewModel.isHost) ? 3.0 : 0)
                            .offset(y: (viewModel.isInSpace && !viewModel.isHost) ? 30 : 0)
                            .allowsHitTesting(!(viewModel.isInSpace && !viewModel.isHost))
                            .zIndex(1)
                            .animation(.spring(response: 0.7, dampingFraction: 0.8), value: viewModel.isInSpace)
                        
                        // Joining overlay (appears on top when joining)
                        if viewModel.isJoining {
                            joiningSpaceOverlay
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95)).animation(.spring(response: 0.6, dampingFraction: 0.8)),
                                    removal: .opacity.combined(with: .scale(scale: 1.05)).animation(.spring(response: 0.4, dampingFraction: 0.9))
                                ))
                                .zIndex(2)
                        }
                    }
                    
                    Spacer()
                }
                
                // ✅ REMOVED: Bottom leave button - keeping only top-right leave button
                
                // ✅ REMOVED: Custom overlay - using standard iOS notifications instead
            }
            // ✅ FIXED: Single coordinated animation for smooth transitions
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.isInSpace || viewModel.isJoining)
           
            .onChange(of: viewModel.isInSpace) { isInSpace in
                print("🔄 [DEBUG] isInSpace changed to: \(isInSpace)")
                
                // ✅ ADDED: Stop monitoring when user joins the space
                if isInSpace {
                    print("🛑 [MONITORING] User joined space, stopping monitoring")
                    stopRealTimeMonitoring()
                    
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                        showUserSection = true
                    }
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                        showUserAvatar = true
                    }
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                        showUserName = true
                    }
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                        showUserRole = true
                    }
                    

                } else {
                    // ✅ ADDED: Start monitoring when user leaves the space (if host is online and not joining)
                    print("🔄 [MONITORING] User left space, checking if should start monitoring")
                    if !viewModel.isJoining && (viewModel.currentViewingSpace?.isHostOnline == true) {
                        print("🔄 [MONITORING] Host is online and not joining, starting monitoring after leaving space")
                        startRealTimeMonitoring()
                    }
                    
                    // Reset animation states when leaving space
                    showUserSection = false
                    showUserAvatar = false
                    showUserName = false
                    showUserRole = false
                }
                
                // Reset the flag after handling
                viewModel.wasEndedByHost = false
            }
            .overlay(
                // ✅ FIXED: Move "End fikret" button inside main view content
                VStack {
                    Spacer()
                    
                    if viewModel.isInSpace && !viewModel.isHost {
                        HStack(spacing: 16) {
                            // ✅ ADDED: Microphone toggle button
                            Button {
                                if let currentUserId = viewModel.tweetData.user?.id {
                                    viewModel.toggleMuteParticipant(currentUserId)
                                }
                            } label: {
                                Image(systemName: isCurrentUserMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .symbolEffect(.bounce)
                                    .padding(12)
                                    .background(
                                        Circle().fill(
                                            LinearGradient(
                                                colors: isCurrentUserMuted ?
                                                    [Color(hex: "#FF6B6B"), Color(hex: "#FF8C42")] :
                                                    [Color(hex: "#4CAF50"), Color(hex: "#45A049")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    )
                                    .shadow(radius: 5)
                            }
                            
                            // End/Leave button
                            Button {
                                Task {
                                    print("🔴 Leave button tapped")
                                    print("📊 Current state - isInSpace: \(viewModel.isInSpace), isHost: \(viewModel.isHost)")
                                    await viewModel.spaceButtonTapped()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: viewModel.isHost ? "stop.circle.fill" : "arrow.right.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .symbolEffect(.bounce)
                                    Text(getButtonTextForRunningState(isInSpace: viewModel.isInSpace, isHost: viewModel.isHost))
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF8C42")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                )
                                .shadow(radius: 5)
                            }
                        }
                        .padding(.bottom, 100) // Above tab bar
                    }
                }
            )
        }
      /*  .sheet(isPresented: $showInviteQueueView) {
            SpacesGuestsView()
                .environmentObject(viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }*/
        .onAppear {
            // ✅ ADDED: Start location ticker animation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                animateGradient = true
            }
            
            // ✅ UNIFIED: Use the same logic for initial monitoring state
            print("🔄 [MONITORING] Initial monitoring state evaluation on appear")
            // ✅ CONDITION: Only start monitoring if not joining and not in space
            if !viewModel.isJoining && !viewModel.isInSpace {
                handleMonitoringStateChange()
            }
            

            
            if viewModel.isInSpace {
                if let room = viewModel.hmsSDK.room {
                    print("🔄 Triggering initial peer list update")
                    
                    
                    
                    
                  viewModel.onPeerListUpdate(added: room.peers, removed: [])
                    
                   
                    
                    
                    
                }
                
              
            }
        }
        .onDisappear {
            print("\n=== 📱 SpacesListeningNowViewForTalkCard disappeared ===")
            
            // ✅ ADDED: Stop real-time monitoring when view disappears
            stopRealTimeMonitoring()
        }
        .onChange(of: viewModel.currentViewingSpace?.isHostOnline) { isHostOnline in
            print("🔄 [MONITORING] Host online status changed: \(isHostOnline ?? false)")
            // ✅ CONDITION: Only handle monitoring if not joining and not in space
            if !viewModel.isJoining && !viewModel.isInSpace {
                handleMonitoringStateChange()
            } else {
                print("✅ [MONITORING] Skipping host online change - inSpace: \(viewModel.isInSpace)")
            }
        }
        .onChange(of: viewModel.isJoining) { isJoining in
            print("🔄 [JOINING] Join state changed: \(isJoining)")
            // ✅ CONDITION: Always stop monitoring when joining starts
            if isJoining {
                print("🛑 [JOINING] Join operation started, stopping monitoring")
                stopRealTimeMonitoring()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .inactive || newPhase == .background {
                dismiss()
            }
        }
        .overlay {
            SpaceOverlays()
        }
        .fullScreenCover(isPresented: $viewModel.showHostNotPresentModal) {
            HostNotPresentModal(isPresented: $viewModel.showHostNotPresentModal)
                .onTapGesture {
                    viewModel.showHostNotPresentModal = false
                }
        }
        .fullScreenCover(isPresented: $viewModel.showRoomFullModal) {
            RoomFullModal(isPresented: $viewModel.showRoomFullModal)
                .onTapGesture {
                    viewModel.showRoomFullModal = false
                }
        }
    }
    
    
    /*struct SpacesListeningNowView_Previews: PreviewProvider {
     static var previews: some View {
     SpacesListeningNowView(showConfirmationModal: $showConfirmationModal)
     }
     }*/
    
    struct RoundedShapeForTalkCard: Shape {
        var corners: UIRectCorner
        
        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: 25, height: 25)
            )
            return Path(path.cgPath)
        }
    }
    
    struct InviteNextUserModalForTalkCard: View {
        @Binding var isPresented: Bool
        let lastUser: QueueUser?
        let queueParticipants: [QueueUser]
        let onInviteNext: (Int64) -> Void
        @Environment(\.colorScheme) var colorScheme
        @EnvironmentObject var viewModel: SpacesViewModel
        @State private var showModal = false
        @State private var animateGradient = false
        @State private var animateContent = false
        
        private var hasParticipants: Bool {
            !queueParticipants.isEmpty
        }
        
        var body: some View {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .blur(radius: 2)
                
                if let lastUser = lastUser {
                    VStack(spacing: 0) {
                        ModalHeaderForTalkCard(
                            user: lastUser,
                            animateGradient: animateGradient,
                            animateContent: animateContent
                        )
                        
                        VStack(spacing: 24) {
                            InfoModalCardForTalkCard(
                                icon: hasParticipants ? "person.2.fill" : "person.3.sequence.fill",
                                title: hasParticipants ? "Queue Status" : "Queue Empty",
                                message: hasParticipants ? "\(queueParticipants.count) people waiting" : "No one is waiting in queue",
                                color: hasParticipants ? .green : .orange
                            )
                            
                            if hasParticipants {
                                HStack(spacing: 16) {
                                    ActionModalButtonForTalkCard(
                                        title: "Cancel",
                                        icon: "xmark.circle.fill",
                                        color: .gray
                                    ) {
                                        withAnimation {
                                            isPresented = false
                                            viewModel.showInviteNextModal = false
                                        }
                                    }
                                    
                                    ActionModalButtonForTalkCard(
                                        title: "Invite Next",
                                        icon: "person.fill.badge.plus",
                                        color: .blue
                                    ) {
                                        if let firstUser = queueParticipants
                                            .sorted(by: { $0.position < $1.position })
                                            .first {
                                            onInviteNext(firstUser.id)
                                        }
                                        isPresented = false
                                        viewModel.showInviteNextModal = false
                                    }
                                }
                            } else {
                                ActionModalButtonForTalkCard(
                                    title: "Close",
                                    icon: "xmark.circle.fill",
                                    color: .gray,
                                    isFullWidth: true
                                ) {
                                    withAnimation {
                                        isPresented = false
                                        viewModel.showInviteNextModal = false
                                    }
                                }
                            }
                        }
                        .padding(24)
                    }
                    .frame(maxWidth: min(UIScreen.main.bounds.width - 40, 400))
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .offset(y: showModal ? 0 : UIScreen.main.bounds.height)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showModal = true
                }
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animateContent.toggle()
                }
            }
        }
    }
    
    // Supporting Components
    private struct ModalHeaderForTalkCard: View {
        let user: QueueUser
        let animateGradient: Bool
        let animateContent: Bool
        
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [.purple.opacity(0.8), .blue.opacity(0.8), .purple.opacity(0.8)],
                    startPoint: animateGradient ? .topLeading : .bottomTrailing,
                    endPoint: animateGradient ? .bottomTrailing : .topLeading
                )
                .opacity(0.9)
                .blur(radius: 0.5)
                
                VStack(spacing: 20) {
                    AnimatedAvatarForTalkCard(imageURL: user.image, animateContent: animateContent)
                    
                    VStack(spacing: 8) {
                        Text(user.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("has left the space")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.vertical, 40)
            }
            .frame(height: 260)
        }
    }
    
    private struct AnimatedAvatarForTalkCard: View {
        let imageURL: String
        let animateContent: Bool
        
        var body: some View {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(animateContent ? 1.1 : 1)
                
                ImageFromUrl(url: imageURL.safeURL(), size: 90)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 10)
            }
        }
    }
    
    private struct InfoModalCardForTalkCard: View {
        let icon: String
        let title: String
        let message: String
        let color: Color
        
        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    private struct ActionModalButtonForTalkCard: View {
        let title: String
        let icon: String
        let color: Color
        var isFullWidth: Bool = false
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(color.opacity(0.1))
                .foregroundColor(color)
                .clipShape(Capsule())
            }
        }
    }
    
    struct CanvasViewForTalkCard: View {
        let items: [CanvasItem]
        @Binding var isVisible: Bool
        let onDismiss: (CanvasItem) -> Void
        init(items: [CanvasItem], isVisible: Binding<Bool>, onDismiss: @escaping (CanvasItem) -> Void) {
            self.items = items
            self._isVisible = isVisible
            self.onDismiss = onDismiss
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Shared Canvas")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(items.count) items")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in
                            CanvasItemViewForTalkCard(item: item) {
                                onDismiss(item)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground).opacity(0.95))
                    .shadow(color: .black.opacity(0.1), radius: 10)
            )
            .padding()
        }
    }
    
    struct CanvasItemViewForTalkCard: View {
        let item: CanvasItem
        let onDismiss: () -> Void
        @State private var isLoading = true
        
        var body: some View {
            ZStack {
                if let url = item.cdnUrl.safeURL() {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 160, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(dismissButton)
                                .onAppear { isLoading = false }
                            
                        case .failure:
                            failureView
                        case .empty:
                            Color.clear
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .frame(width: 160, height: 160)
        }
        
        private var dismissButton: some View {
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
                Spacer()
            }
        }
        
        private var loadingView: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                ProgressView()
            }
        }
        
        private var failureView: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.gray)
            }
        }
    }
    
}

// MARK: - Toast Notification View
struct ToastNotificationView: View {
    let message: String
    let isError: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isError ? .red : .green)
            
            // Message
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isError ?
                        Color.black.opacity(0.9) :
                        Color.green.opacity(0.9)
                )
                .shadow(color: isError ? .black.opacity(0.3) : .green.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

