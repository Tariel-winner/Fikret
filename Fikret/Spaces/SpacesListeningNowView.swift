//
//  SpacesListeningNowView.swift
//  Spaces
//
//  Created by amos.gyamfi@getstream.io on 11.2.2023.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import SwiftUI
import PhotosUI
//import FirebaseFirestore
//import TwitterCloneUI

private func getButtonTextForRunningState(isInSpace: Bool, isHost: Bool) -> String {
    if isInSpace {
        return isHost ? "End fikret" : "Leave fikret quietly"
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
struct CanvasItem: Identifiable, Equatable {
    let id: String
    let cdnUrl: String
    let status: String
    let timestamp: Date
    let uploaderId: String?
    
    static func == (lhs: CanvasItem, rhs: CanvasItem) -> Bool {
        lhs.id == rhs.id
    }
}

public struct SpacesListeningNowView: View {
    public init(showConfirmationModal: Binding<Bool>, isHostView: Bool = false) {
        self._showConfirmationModal = showConfirmationModal
        self.isHostView = isHostView
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
    let isHostView: Bool
    
    
    @State private var showGuide = false
    @State private var dragOffset: CGSize = .zero
    
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @State private var animateGradient = false
    @State private var scrollOffset: CGFloat = 0
    @State private var searchText = ""
    @State private var isSearching = false
    @Binding var showConfirmationModal: Bool
    @State private var isAnimating = false
    
    @State private var audioLevel: CGFloat = 0.0
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
        let isHost = viewModel.isHost
        if let space = activeSpace {
            return getButtonTextForRunningState(isInSpace: viewModel.isInSpace, isHost: viewModel.isHost)
        }
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
               let firstNonCurrentUserSpeaker = activeSpace?.speakers
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
        .disabled(activeSpace?.speakers.count ?? 0 < 2)
        .opacity(activeSpace?.speakers.count ?? 0 >= 1 ? 1 : 0.4)
        .scaleEffect(activeSpace?.speakers.count ?? 0 >= 1 ? 1.0 : 0.9)
        .animation(.spring(), value: activeSpace?.speakers.count ?? 0 >= 1)
        .onAppear {
            print("🔄 Remove Button - Speakers Count: \(activeSpace?.speakers.count ?? 0)")
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
                if let firstUser = activeSpace?.queue.participants.sorted(by: { $0.position < $1.position }).first {
                    print("🔄 [InviteQueueView] Inviting user with ID: \(firstUser.id)")
                
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
        .disabled(activeSpace?.queue.participants.isEmpty ?? true)
        .opacity(activeSpace?.queue.participants.isEmpty ?? true ? 0.4 : 1)
        .scaleEffect(activeSpace?.queue.participants.isEmpty ?? true ? 0.9 : 1.0)
        .animation(.spring(), value: activeSpace?.queue.participants.isEmpty ?? true)
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
        Text("LIVE")
            .italic()
            .bold()
            .foregroundColor(.white)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(LinearGradient(gradient: Gradient(colors: [.red, .orange]), startPoint: .leading, endPoint: .trailing))
            .cornerRadius(8)
            .shadow(color: .red.opacity(0.5), radius: 10, x: 0, y: 0)
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
    
    private struct SpeakerAvatar: View {
        let image: String? // ✅ FIXED: Use URL? directly without safeURL()
        let isActive: Bool
        let isMuted: Bool // ✅ ADDED: Mute state parameter
        @EnvironmentObject var viewModel: SpacesViewModel
        
        var body: some View {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                ZStack {
                    // Avatar image or default - use URL directly
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
                                defaultAvatarView(size: size)
                            @unknown default:
                                defaultAvatarView(size: size)
                            }
                        }
                    } else {
                        // ✅ UPDATED: Use same beautiful default avatar as TalkCard
                        defaultAvatarView(size: size)
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
            }
            .aspectRatio(1, contentMode: .fit)
        }
        
        // ✅ ADDED: Helper function for default avatar to avoid code duplication
        func defaultAvatarView(size: CGFloat) -> some View {
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
    struct AudioDetectionAnimation: View {
        @State private var animate = false
        @EnvironmentObject var viewModel: SpacesViewModel
        let peerID: String?
        
        var body: some View {
            let isActive = peerID != nil && viewModel.activeSpeakerId == peerID
            
            return HStack(spacing: 2) {
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
            .onChange(of: viewModel.activeSpeakerId) { newActiveSpeakerId in
                if isActive {
                    animate = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        animate = true
                    }
                }
            }
        }
    }
    
    private func speakerRoleText(for speaker: SpaceParticipant) -> String {
        if speaker.id == viewModel.tweetData.user!.id && activeSpace?.hostId == speaker.id {
            return "Host"
        } else if speaker.id != viewModel.tweetData.user!.id && activeSpace?.hostId == speaker.id {
            return "Host"
        } else {
            return "Speaker"
        }
    }
    
            private func speakerInfoView(for speaker: SpaceParticipant, geometry: GeometryProxy) -> some View {
            VStack(spacing: 8) {
                SpeakerAvatar(
                    image: speaker.imageURL,
                    isActive: speaker.peerID != nil && viewModel.activeSpeakerId == speaker.peerID,
                    isMuted: speaker.isMuted ?? false // ✅ ADDED: Pass mute state
                )
                .frame(width: min(geometry.size.width * 0.2, 100), height: min(geometry.size.width * 0.2, 100))
            
            // ✅ IMPROVED: Show display name first, then username with @
            VStack(spacing: 2) {
                // Display name (nickname) - on top
                Text(speaker.name ?? "")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(maxWidth: geometry.size.width * 0.25)
                
                // Username with @ symbol - underneath
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
            
                            if speaker.peerID != nil && viewModel.activeSpeakerId == speaker.peerID {
                    AudioDetectionAnimation(peerID: speaker.peerID)
                        .frame(height: 13)
                        .opacity(1)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.activeSpeakerId)
                }
        }
        .frame(width: geometry.size.width * 0.25)
        .id("speaker-\(speaker.id)-\(speaker.peerID ?? "")-\(viewModel.activeSpeakerId ?? "")")
    }
    
    private func speakersSection(geometry: GeometryProxy) -> some View {
        let speakers = activeSpace?.speakers ?? []
 
        print("Speakers Count: \(speakers.count)")
        print("Speakers: \(speakers.map { "ID: \($0.id), Name: \($0.name ?? "unknown"), PeerID: \($0.peerID ?? "nil")" })")
        print("===================================\n")
        
        return AnyView(
            VStack {
                HStack(spacing: geometry.size.width * 0.1) {
                    Spacer()
                    
                    ForEach(speakers.prefix(2), id: \.id) { speaker in
                        speakerInfoView(for: speaker, geometry: geometry)
                            .id("\(speaker.id)-\(speaker.peerID ?? "")") // Force update on speaker changes
                    }
                    
                    Spacer()
                }
                .padding(.vertical, geometry.size.height * 0.05)
            }
        )
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
    struct RadioWaveAnimation: View {
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
                CanvasView(
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
    
    private struct SpaceOverlays: View {
        @EnvironmentObject var viewModel: SpacesViewModel
        
        var body: some View {
            Group {
                if viewModel.showInviteNextModal && viewModel.isHost {
                    InviteNextUserModal(
                        isPresented: $viewModel.showInviteNextModal,
                        lastUser: viewModel.lastUserWhoLeft,
                        queueParticipants: viewModel.selectedSpace?.queue.participants ?? [],
                        onInviteNext: { userId in
                            Task {
                                viewModel.showInviteNextModal = false
                                viewModel.lastUserWhoLeft = nil
                                
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
        let activeSpace: Space?
        
        @State private var canvasItems: [CanvasItem] = []
        @State private var isShowingCanvas: Bool = false
        @State private var showDismissConfirmation = false
        @State private var selectedCanvasItem: CanvasItem?
        
        private func speakersSection(geometry: GeometryProxy) -> some View {
            let speakers = activeSpace?.speakers ?? []
            return AnyView(
                VStack {
                    HStack(spacing: geometry.size.width * 0.1) {
                        Spacer()
                        
                        ForEach(speakers.prefix(2), id: \.id) { speaker in
                            speakerInfoView(for: speaker, geometry: geometry)
                                .id("speaker-\(speaker.id)-\(speaker.peerID ?? "")")
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, geometry.size.height * 0.05)
                }
            )
        }
        
        private func speakerInfoView(for speaker: SpaceParticipant, geometry: GeometryProxy) -> some View {
            VStack(spacing: 8) {
                SpeakerAvatar(
                    image: speaker.imageURL,
                    isActive: speaker.peerID != nil && viewModel.activeSpeakerId == speaker.peerID,
                    isMuted: speaker.isMuted ?? false // ✅ ADDED: Pass mute state
                )
                .frame(width: min(geometry.size.width * 0.2, 100), height: min(geometry.size.width * 0.2, 100))
                
                // ✅ IMPROVED: Show display name first, then username with @
                VStack(spacing: 2) {
                    // Display name (nickname) - on top
                    Text(speaker.name ?? "")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(maxWidth: geometry.size.width * 0.25)
                    
                    // Username with @ symbol - underneath
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
                
                if let pid = speaker.peerID, viewModel.activeSpeakerId == pid {
                    AudioDetectionAnimation(peerID: pid)
                        .frame(height: min(geometry.size.height * 0.02, 13))
                }
            }
            .frame(width: geometry.size.width * 0.25)
        }
        
        private func speakerRoleText(for speaker: SpaceParticipant) -> String {
            if speaker.id == viewModel.tweetData.user!.id && activeSpace?.hostId == speaker.id {
                return "Host"
            } else if speaker.id != viewModel.tweetData.user!.id && activeSpace?.hostId == speaker.id {
                return "Host"
            } else {
                return "Speaker"
            }
        }
        
        private var canvasSection: some View {
            VStack(spacing: 0) {
                if !canvasItems.isEmpty {
                    CanvasView(
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
        
        var body: some View {
            VStack(spacing: 0) {
                if let speakers = activeSpace?.speakers {
                    speakersSection(geometry: geometry)
                        .drawingGroup()
                        .id("speakers-\(speakers.count)-\(speakers.map { String($0.id) }.joined(separator: "-"))")
                }
                
                Spacer()
                
                canvasSection
                    .frame(maxHeight: geometry.size.height * 0.3)
            }
        }
    }
    
    private var hostSpace: Space? {
    // ✅ FIXED: Safe optional unwrapping
    guard let userId = viewModel.tweetData.user?.id else {
        print("⚠️ No current user ID found")
        return nil
    }
    
    // ✅ FIXED: Safe array access with nil coalescing
    let space = viewModel.spaces.first { $0.hostId == userId }
    
    if let space = space {
        print("✅ Found host space: \(space.id)")
    } else {
        print("⚠️ No host space found for user: \(userId)")
    }
    
    return space
}

private var activeSpace: Space? {
    // ✅ FIXED: Safe optional handling
    if let selectedSpace = viewModel.selectedSpace, viewModel.isInSpace {
        print("✅ Using selected space: \(selectedSpace.id)")
        return selectedSpace
    }
    
    if let hostSpace = hostSpace {
        print("✅ Using host space: \(hostSpace.id)")
        return hostSpace
    }
    
    print("⚠️ No active space available")
    return nil
}
    
  
    
    private var isCurrentUserHost: Bool {
        guard let currentUserId = viewModel.tweetData.user?.id else { return false }
        return activeSpace?.hostId == currentUserId
    }
    
    // ✅ ADDED: Use reactive property from ViewModel instead of computed property
    private var isCurrentUserMuted: Bool {
        return viewModel.isCurrentUserMuted
    }
    
    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // ✅ ADDED: Custom drag handle area for easier dragging
                VStack(spacing: 0) {
                    // Drag indicator handle
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    
                    // Extended drag area - much larger touch target
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // This makes the entire area draggable
                        }
                }
                .frame(maxWidth: .infinity)
                .background(Color.clear)
                
                HStack {
                    if (activeSpace?.speakers.count ?? 0) > 1 || viewModel.isInSpace {
                        RecordingTimerView()
                    } else {
                        liveIndicatorView()
                    }
                    Spacer() // Ensure proper spacing from toolbar
                }
                .padding(.top, 10) // ✅ REDUCED: Less top padding since we have drag area
                .padding(.bottom, 10)
                
                GeometryReader { geometry in
                    SpaceContent(geometry: geometry, activeSpace: activeSpace)
                        .id("space-\(activeSpace?.id ?? 0)-\(activeSpace?.speakers.count ?? 0)")
                }
            }
            .padding()
            .background(Color.black.opacity(0.95))
            .overlay(
                // ✅ FIXED: Move "End fikret" button inside main view content
                VStack {
                    Spacer()
                    
                    if viewModel.isInSpace {
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
                                Task { await viewModel.spaceButtonTapped() }
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
        .sheet(isPresented: $showInviteQueueView) {
            SpacesGuestsView()
                .environmentObject(viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: viewModel.selectedSpace) { newSpace in
            print("\n=== 🔄 Selected Space Changed ===")
            print("New selectedSpace: \(String(describing: newSpace?.id))")
            print("Current isInSpace: \(viewModel.isInSpace)")
            print("Host Space ID: \(String(describing: hostSpace?.id))")
        }
        .onChange(of: viewModel.selectedSpace?.speakers) { newSpeakers in
            print("\n=== 🔄 Speakers Updated ===")
            print("New speaker count: \(newSpeakers?.count ?? 0)")
            print("Speaker IDs: \(newSpeakers?.map { $0.id } ?? [])")
        }
        .onChange(of: viewModel.selectedSpace?.id) { newId in
            print("\n=== 🔄 Space ID Changed ===")
            print("New Space ID: \(String(describing: newId))")
        }
        .id("space-\(activeSpace?.id ?? 0)-\(activeSpace?.speakers.count ?? 0)") // Force view update when space or speakers change
        .onAppear {
            print("\n=== 📱 SpacesListeningNowView appeared ===")
            print("Initial State:")
            print("- isInSpace: \(viewModel.isInSpace)")
            print("- Selected Space ID: \(String(describing: viewModel.selectedSpace?.id))")
            print("- Host Space ID: \(String(describing: hostSpace?.id))")
        }
        .onDisappear {
            print("\n=== 📱 SpacesListeningNowView disappeared ===")
            print("🏠 Space state: \(viewModel.isInSpace)")
            print("👁️ Show space view: \(viewModel.showSpaceView)")
            print("🔍 Selected space: \(String(describing: viewModel.selectedSpace?.id))")
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .inactive || newPhase == .background {
                dismiss()
            }
        }
        .overlay {
            SpaceOverlays()
        }
    }
    
    
    /*struct SpacesListeningNowView_Previews: PreviewProvider {
     static var previews: some View {
     SpacesListeningNowView(showConfirmationModal: $showConfirmationModal)
     }
     }*/
    
    struct RoundedShape: Shape {
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
    
    struct InviteNextUserModal: View {
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
                        ModalHeader(
                            user: lastUser,
                            animateGradient: animateGradient,
                            animateContent: animateContent
                        )
                        
                        VStack(spacing: 24) {
                            InfoModalCard(
                                icon: hasParticipants ? "person.2.fill" : "person.3.sequence.fill",
                                title: hasParticipants ? "Queue Status" : "Queue Empty",
                                message: hasParticipants ? "\(queueParticipants.count) people waiting" : "No one is waiting in queue",
                                color: hasParticipants ? .green : .orange
                            )
                            
                            if hasParticipants {
                                HStack(spacing: 16) {
                                    ActionModalButton(
                                        title: "Cancel",
                                        icon: "xmark.circle.fill",
                                        color: .gray
                                    ) {
                                        withAnimation {
                                            isPresented = false
                                            viewModel.showInviteNextModal = false
                                        }
                                    }
                                    
                                    ActionModalButton(
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
                                ActionModalButton(
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
    private struct ModalHeader: View {
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
                    AnimatedAvatar(imageURL: user.image, animateContent: animateContent)
                    
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
    
    private struct AnimatedAvatar: View {
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
                
                ImageFromUrl(url: URL(string: imageURL), size: 90)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 10)
            }
        }
    }
    
    private struct InfoModalCard: View {
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
    
    private struct ActionModalButton: View {
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
    
    struct CanvasView: View {
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
                            CanvasItemView(item: item) {
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
    
    struct CanvasItemView: View {
        let item: CanvasItem
        let onDismiss: () -> Void
        @State private var isLoading = true
        
        var body: some View {
            ZStack {
                if let url = URL(string: item.cdnUrl) {
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
    /*
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
     }*/
    
    struct RecordingTimerView: View {
        @EnvironmentObject var viewModel: SpacesViewModel
        @State private var isTopicExpanded = false
        
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
                
                // ✅ UPDATED: Use viewModel.currentTopic directly for reactive updates
                let topic = viewModel.currentTopic
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
                
                // ✅ UPDATED: Show expand/collapse button for any topic that can be expanded
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
                if viewModel.isHost && viewModel.isRecordingActive {
                    timerSection
                }
                
                // Topic section
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
    
    private struct TopicDisplayView: View {
        let topic: String
        @State private var isExpanded = false
        
        private var truncatedTopic: String {
            if topic.count > 50 && !isExpanded {
                return topic.prefix(50) + "..."
            }
            return topic
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 18))
                    
                    Text("Topic")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Text(truncatedTopic)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(isExpanded ? nil : 2)
                    .animation(.spring(), value: isExpanded)
                    .onTapGesture {
                        if topic.count > 50 {
                            withAnimation {
                                isExpanded.toggle()
                            }
                        }
                    }
                
                if topic.count > 35 && !isExpanded {
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        Text("Read more")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(16)
            .padding(.trailing, 80) // Add trailing padding to prevent overlap with toolbar buttons
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.3))
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
            .padding(.horizontal)
        }
    }
    
    struct UserListViewForListeningView: View {
        @EnvironmentObject var viewModel: SpacesViewModel
        @State private var searchText = ""
        @State private var isLoading = false
        
        var filteredUsers: [QueueUser] {
            let participants = viewModel.selectedSpace?.queue.participants ?? []
            if searchText.isEmpty {
                return participants
            }
            return participants.filter { participant in
                participant.name.lowercased().contains(searchText.lowercased())
            }
        }
        
        var body: some View {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText, isSearching: .constant(false))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                if filteredUsers.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredUsers, id: \.id) { participant in
                                UserListCellForGrid(user: participant)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Users")
            .navigationBarTitleDisplayMode(.inline)
            .foregroundColor(.white)
            .background(Color.clear)
        }
    }
    
    
}
