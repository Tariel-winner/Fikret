import SwiftUI




/*
struct MiniCardView: View {
    @EnvironmentObject var viewModel: SpacesViewModel
    @State private var isAnimating = false
    @State private var audioLevel: CGFloat = 0.0
    @State private var showUserTopicModal = false
    @State private var selectedUserTopic: String?
    @Binding var showConfirmationModal: Bool
    // Audio wave animation timer
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var dragOffset = CGSize.zero
    
    // Derive currentUser from SpacesViewModel
    var currentUser: QueueUser? {
        guard let userId = viewModel.tweetData.user?.id else { return nil }
        return viewModel.selectedSpace?.queue.participants.first { $0.id == userId }
    }
    
    var body: some View {
        VStack {
            Spacer() // Ensures the MiniCardView is pushed to the bottom
            Group {
                if let space = viewModel.selectedSpace,
                   (viewModel.isInSpace || currentUser != nil) {
                    VStack {
                        dragIndicator
                if viewModel.isInSpace {
                            spaceMiniCard
                        } else if currentUser != nil {
                            queueMiniCard
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(cardBackground)
                 //   .cornerRadius(24, corners: [.topLeft, .topRight]) // Rounded top corners
                    .overlay {
                        if showUserTopicModal {
                            userTopicModal
                            }
                        }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if viewModel.isInSpace {
                                    viewModel.showSpaceView = true
                            } else if currentUser != nil {
                                    viewModel.showQueueView = true
                                }
                            }
                        }
     /*   .sheet(isPresented: $showConfirmationModal) {
            RemoveUserConfirmationModal(
                isPresented: $showConfirmationModal,
                            userName: viewModel.isHost ? "End the fikret" : "Leave the fikret",
                onConfirm: {
                    Task {
                        await viewModel.spaceButtonTapped()
                    }
                }
            )
        }*/
    }
            }
        }
        .ignoresSafeArea(edges: .bottom) // Ensure the view respects the safe area
    }
    
  /*  struct RemoveUserConfirmationModal: View {
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
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.systemBackground)))
        .shadow(color: .black.opacity(0.2), radius: 10)
        .padding()
    }
}
    */
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(LinearGradient(
                gradient: Gradient(colors: [.gray.opacity(0.9), .gray.opacity(0.5)]),
                startPoint: .top,
                endPoint: .bottom
            ))
            .frame(width: 40, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { gesture in
                if gesture.translation.height < -50 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if viewModel.isInSpace {
                            viewModel.showSpaceView = true
                        } else if currentUser != nil {
                            viewModel.showQueueView = true
                        }
                    }
                }
            }
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.7), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

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
                                           .scaleEffect(isActive ? 1.2 : 1.0)
                                   } else {
                                       Image(systemName: "person.fill")
                                           .resizable()
                                           .scaledToFill()
                                           .frame(width: size * 1, height: size * 1)
                                           .clipShape(Circle())
                                           .shadow(radius: 3)
                                           .scaleEffect(isActive ? 1.2 : 1.0)
                                   }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }
    private var spaceMiniCard: some View {
        HStack(spacing: 16) {
            ZStack {
               
                
                if let speakers = viewModel.selectedSpace?.speakers {
                    ForEach(speakers, id: \.id) { speaker in
                        if speaker.peerID == viewModel.activeSpeakerId {
                            // Use SpeakerAvatar instead of AsyncImage
                            SpeakerAvatar(
                                image: viewModel.peerImages[speaker.peerID!],
                                isActive: true
                            )
                            .frame(width: 48, height: 48)
                         /*   SoundIndicatorView(zoomLevel: nil)
                    .frame(height: 18)*/
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
                Text(viewModel.isHost ? "End" : "Leave")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: viewModel.isHost ? [.red, .orange] : [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: (viewModel.isHost ? Color.red : Color.purple).opacity(0.4),
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
            
            var queueMiniCard: some View {
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
                                    
                                    Text("\(viewModel.selectedSpace?.queue.participants.count ?? 0) in queue")
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
            
            var userTopicModal: some View {
                HStack(spacing: 0) {
                    // Dismiss area
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showUserTopicModal = false
                            }
                        }
                    
                    // Topic display
                    VStack(spacing: 16) {
                        // Handle and Title
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "text.bubble.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                            
                            Text((selectedUserTopic?.hasPrefix("#") ?? false) ? selectedUserTopic ?? "" : "#\(selectedUserTopic ?? "")")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.top, 16)
                        
                        // Close Button
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showUserTopicModal = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .buttonStyle(ScalesButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(width: UIScreen.main.bounds.width * 0.7)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(UIColor.systemBackground))
                            
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    )
                    .offset(x: showUserTopicModal ? 0 : UIScreen.main.bounds.width)
                }
                .transition(.move(edge: .trailing))
            }
        
        
    struct ScalesButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
        }
    }
       /* struct MiniCardView_Previews: PreviewProvider {
            static var previews: some View {
                Group {
                    MiniCardView(showConfirmationModal: .constant(false))
                        .environmentObject(SpacesViewModel.preview)
                        .previewDisplayName("Default Preview")
                        .previewLayout(.sizeThatFits)
                        .padding()
                    
                    MiniCardView(showConfirmationModal: .constant(false))
                        .environmentObject(SpacesViewModel.preview)
                        .previewDisplayName("Dark Mode")
                        .previewLayout(.sizeThatFits)
                        .padding()
                        .background(Color.black)
                        .environment(\.colorScheme, .dark)
                }
            }
        }*/
    }
 
*/
