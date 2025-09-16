import SwiftUI

struct InviteQueueView: View {
    
    @Environment(\.dismiss) var dismiss
    
    
    let columns = [GridItem(.adaptive(minimum: 80))]
    let gridSpacing: CGFloat = 20
    @EnvironmentObject var viewModel: SpacesViewModel
    
   
    
   var inviteButtonDisabled: Bool {
        // Directly check if there are no participants in the queue
        viewModel.selectedSpace?.queue.participants.isEmpty ?? true
    }
    
    private var inviteButton: some View {
        Button(action: {
            Task {
               if let firstParticipant = viewModel.selectedSpace?.queue.participants.sorted(by: { $0.position < $1.position }).first {
                    print("🔄 [InviteQueueView] Inviting user with ID: \(firstParticipant.id)")
                 /*   await viewModel.inviteUserFromQueue(userId: firstParticipant.id)*/
                }
                dismiss()
            }
        }) {
            Text("Invite First in Queue")
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(LinearGradient(gradient: Gradient(colors: [.green, .blue]), startPoint: .leading, endPoint: .trailing)))
                .shadow(radius: 5)
        }
        .padding()
        .disabled(inviteButtonDisabled)
        .opacity(inviteButtonDisabled ? 0.4 : 1)
    }
    
    private var participantGridView: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: gridSpacing) {
            ForEach(viewModel.selectedSpace?.queue.participants ?? []) { participant in
                VStack {
                    if let imageUrl = URL(string: participant.image) {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(width: 50, height: 50)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                    .padding(4)
                                    .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                            case .failure:
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                    .padding(4)
                                    .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .padding(4)
                            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                    }
                    Text(participant.name)
                        .font(.caption)
                    
                    Text("Position: \(participant.position)")
                        .font(.caption2)
                    
                    if participant.isInvited {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            participantGridView
            Spacer()
            Divider().padding(.bottom)
            inviteButton
        }
        .padding()
        .navigationTitle("Invite from Queue")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            print("🔄 [InviteQueueView] View appeared. Current queue participants: \(viewModel.selectedSpace?.queue.participants.map { $0.id } ?? [])")
            guard let space = viewModel.selectedSpace else { return }
          /*  Task {
                await viewModel.listenToQueueUpdates(for: space)
            }*/
        }
        .onDisappear {
            /*Task {
                await viewModel.removeQueueListeners()
            }*/
        }
    }
}


