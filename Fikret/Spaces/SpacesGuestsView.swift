import SwiftUI

struct SpacesGuestsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: SpacesViewModel
    @State private var showUserTopicModal = false
    @State private var selectedUserTopic: String?
    private var firstParticipant: QueueUser? {
           viewModel.selectedSpace?.queue.participants.first
       }

       var inviteButtonDisabled: Bool {
           viewModel.selectedSpace?.queue.participants.isEmpty ?? true
       }

       var selectedQueue: Queue? {
           viewModel.selectedSpace?.queue
       }
    let columns = [GridItem(.adaptive(minimum: 100))]
    let gridSpacing: CGFloat = 20
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack {
                // Header with title and participant count
                VStack {
                    Text("Guests")
                        .font(.title)
                        .bold()
                        .foregroundColor(.primary)
                        .padding(.bottom, 8)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                        Text("\(viewModel.selectedSpace?.queue.participants.count ?? 0) Participants")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 16)
                
                // Guest list with a grid layout
                ScrollView {
                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(viewModel.selectedSpace?.queue.participants ?? [], id: \.id) { participant in
                            VStack {
                                profileImage(for: participant)
                                participantInfo(for: participant)
                                actionButtons(for: participant)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 8)
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
            }
            .padding()
            .background(
                LinearGradient(gradient: Gradient(colors: [.white, .blue.opacity(0.1)]), startPoint: .top, endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.primary)
                            .padding()
                            .background(Circle().fill(Color(UIColor.systemBackground)))
                            .shadow(radius: 2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Search action
                    } label: {
                        Text("Search")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding()
                            .background(Circle().fill(Color(UIColor.systemBackground)))
                            .shadow(radius: 2)
                    }
                }
            }
        }
    }
    
    private func profileImage(for participant: QueueUser) -> some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: participant.isInvited ? [.green, .blue] : [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 80, height: 80)
            
            AsyncImage(url: URL(string: participant.image)) { phase in
                switch phase {
                case .empty, .failure:
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(Color.gray.opacity(0.2)))
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(Circle())
                @unknown default:
                    EmptyView()
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private func participantInfo(for participant: QueueUser) -> some View {
        VStack(alignment: .center, spacing: 6) {
            Text("@\(participant.name)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            if let topic = participant.topic {
                Button {
                    selectedUserTopic = topic
                    withAnimation(.spring()) {
                        showUserTopicModal = true
                    }
                } label: {
                    Text("Topic")
                        .font(.system(size: 12, weight: .medium))
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
        HStack(spacing: 12) {
            if participant.id == firstParticipant?.id && !participant.isInvited {
                Button(action: {
                    Task {
                      /*  await viewModel.inviteUserFromQueue(userId: participant.id)*/
                    }
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
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct SpacesGuestsView_Previews: PreviewProvider {
    static var previews: some View {
        SpacesGuestsView()
            .environmentObject(SpacesViewModel.preview)
    }
}
