import SwiftUI

struct SpacesGuestList: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: SpacesViewModel
    @State private var showUserTopicModal = false
    @State private var selectedUserTopic: String?
    
    let columns = [GridItem(.adaptive(minimum: 80))]
    let gridSpacing: CGFloat = 20
    
    private var firstParticipant: QueueUser? {
        viewModel.selectedSpace?.queue.participants.first
    }

    var inviteButtonDisabled: Bool {
        viewModel.selectedSpace?.queue.participants.isEmpty ?? true
    }

    var selectedQueue: Queue? {
        viewModel.selectedSpace?.queue
    }
    
    private func profileImage(for participant: QueueUser) -> some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: participant.isInvited ?
                            [.green, .blue] : [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 52, height: 52)
            
            AsyncImage(url: URL(string: participant.image)) { phase in
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
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                @unknown default:
                    EmptyView()
                }
            }
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
    
    private func participantInfo(for participant: QueueUser) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("@\(participant.name)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                if participant.isInvited {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 14))
                        .symbolEffect(.pulse)
                }
            }
            
            if let topic = participant.topic {
                Button {
                    selectedUserTopic = topic
                    withAnimation(.spring()) {
                        showUserTopicModal = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 12))
                        Text("Topic")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .purple.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(ScalaButtonStyle())
            }
        }
    }
    
    private func actionButtons(for participant: QueueUser) -> some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 150 // Adjust threshold as needed
            HStack(spacing: 12) {
                if participant.id == firstParticipant?.id && !participant.isInvited {
                    Button(action: {
                       /* Task {
                            await viewModel.inviteUserFromQueue(userId: participant.id)
                        }*/
                    }) {
                        Text("Invite")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [.green, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(ScalaButtonStyle())
                }
                
                Button(action: {
                    Task {
                        if let spaceId = viewModel.selectedSpace?.id {
                          /*  await viewModel.removeUserFromQueue(
                                userId: participant.id,
                                spaceId: spaceId,
                                isInvited: participant.isInvited
                            )*/
                        }
                    }
                }) {
                    Text("Remove")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .red.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .buttonStyle(ScalaButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading) // Ensure buttons do not overflow
        }
        .frame(height: 44) // Ensure consistent button height
    }
    
    private var userTopicModal: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showUserTopicModal = false
                    }
                }
            
            VStack(spacing: 24) {
                // Handle and Title
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 40, height: 4)
                    
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
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        
                        Text("Topic")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                
                // Topic Display
                VStack(spacing: 16) {
                    Text((selectedUserTopic?.hasPrefix("#") ?? false) ? selectedUserTopic ?? "" : "#\(selectedUserTopic ?? "")")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 8)
                                
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                                
                                // Background pattern
                                GeometryReader { geometry in
                                    Path { path in
                                        let size = geometry.size
                                        let spacing: CGFloat = 20
                                        for x in stride(from: 0, through: size.width, by: spacing) {
                                            path.move(to: CGPoint(x: x, y: 0))
                                            path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                                        }
                                    }
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.05), .purple.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                                }
                            }
                        )
                }
                
                // Close Button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showUserTopicModal = false
                    }
                } label: {
                    Text("Close")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.secondary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
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
                }
                .buttonStyle(ScalaButtonStyle())
            }
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(UIColor.systemBackground))
                    
                    RoundedRectangle(cornerRadius: 24)
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
            .frame(maxWidth: 340)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    var body: some View {
        ZStack {
            if viewModel.selectedSpace?.queue.participants.isEmpty ?? true {
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("No participants yet")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Invite people to join the space")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(32)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 10)
                        
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
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.selectedSpace?.queue.participants ?? [], id: \.id) { participant in
                            HStack(spacing: 16) {
                                profileImage(for: participant)
                                participantInfo(for: participant)
                                Spacer()
                                
                                // Action buttons
                                actionButtons(for: participant)
                            }
                            .padding(16)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.05), radius: 8)
                                    
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            LinearGradient(
                                                colors: participant.isInvited ?
                                                    [.green.opacity(0.3), .blue.opacity(0.3)] :
                                                    [.blue.opacity(0.2), .purple.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                            )
                            .scaleEffect(participant.isInvited ? 1.02 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: participant.isInvited)
                        }
                    }
                    .padding()
                }
                .scrollContentBackground(.hidden)
                .background(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color.blue.opacity(0.05),
                            Color.purple.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            
            if showUserTopicModal {
                userTopicModal
            }
        }
        .onAppear {
            if let space = viewModel.selectedSpace {
             /*   Task {
                    await viewModel.listenToQueueUpdates(for: space)
                }*/
            }
        }
        .onDisappear {
          /*  Task {
                await viewModel.removeQueueListeners()
            }*/
        }
    }
}

struct ScalaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
