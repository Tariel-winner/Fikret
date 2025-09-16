import SwiftUI
import AVFoundation
/*
public struct SpacesBackgroundWidget: View {
    @EnvironmentObject var viewModel: SpacesViewModel
    @Environment(\.scenePhase) var scenePhase
    @State private var audioRenderer: AudioRenderer?  // Hypothetical class for handling audio
    
    // Setup background audio session
    private func setupAudioSession() {
        do {
            // Set the audio session to allow playback in the background
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            print("Audio session activated for background.")
        } catch {
            print("Error setting up audio session: \(error.localizedDescription)")
        }
    }

    // Synchronize audio tracks based on viewModel's audio data
    private func setupAudioPlayer() {
        // Play own audio track if it exists
        if let audioTrack = viewModel.ownTrack {
            do {
                audioRenderer = AudioRenderer(track: audioTrack)  // Assuming this is a custom class
                try audioRenderer?.prepareToPlay()
                audioRenderer?.play()
                print("Audio is playing for own track.")
            } catch {
                print("Error setting up audio player for own track: \(error.localizedDescription)")
            }
        }
        
        // Play other participants' audio tracks
        for track in viewModel.otherTracks {
            do {
                audioRenderer = AudioRenderer(track: track)  // Assuming this is a custom class
                try audioRenderer?.prepareToPlay()
                audioRenderer?.play()
                print("Audio is playing for peer track.")
            } catch {
                print("Error setting up audio player for peer track: \(error.localizedDescription)")
            }
        }
    }

    // Avatar for participants (simplified)
    private func avatarView(for participant: Participant) -> some View {
        ImageFromUrl(url: participant.imageURL, size: 54)
            .clipShape(Circle())
            .scaledToFit()
            .frame(width: 54, height: 54)
            .shadow(radius: 3)
    }
    
    // This function will display speakers in the background widget
    private func speakersSection() -> some View {
        if let speakers = viewModel.selectedSpace?.speakers {
            return AnyView(
                ForEach(speakers, id: \.id) { speaker in
                    VStack {
                        avatarView(for: speaker)
                        Text(speaker.name ?? "")
                            .font(.caption)
                            .bold()
                        Text(participantRole(isHost: viewModel.isHost))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                            Text("Current Speaker: \(viewModel.activeSpeaker?.name ?? "None")")
    .font(.caption)
    .foregroundColor(viewModel.selectedSpace?.activeSpeaker?.peerID == viewModel.activeSpeaker?.peerID ? .green : .secondary)

                    }
                }
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    // This function will display listeners in the background widget
    private func listenersSection() -> some View {
        if let listeners = viewModel.selectedSpace?.listeners {
            return AnyView(
                ForEach(listeners, id: \.id) { listener in
                    VStack {
                        avatarView(for: listener)
                        Text(listener.name ?? "")
                            .font(.caption)
                            .bold()
                        Text("Listener")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    // UI for when app goes into the background
    public var body: some View {
        VStack(alignment: .leading) {
            // Show speakers and listeners as in the main view
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 24) {
                speakersSection()
                listenersSection()
            }

            Spacer()
        }
        .onAppear {
            // Setup audio session for background audio
            setupAudioSession()

            // Sync with onPeerListUpdate to ensure correct data usage
            if viewModel.isInSpace {
                if let room = viewModel.hmsSDK.room {
                    viewModel.onPeerListUpdate(added: room.peers, removed: [])
                }
            }
            
            // Setup the audio player (start playing the own and other participants' audio tracks)
            setupAudioPlayer()
        }
        .onDisappear {
            // Cleanup when widget is removed or goes inactive
            audioRenderer?.stop()
            print("Stopped audio playback.")
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                // Ensure that we pause or stop unnecessary updates when backgrounded
                print("App is in the background, audio continues.")
            } else if newPhase == .active {
                // Reactivate UI updates and audio when the app returns to the foreground
                print("App is active again.")
                setupAudioPlayer()
            }
        }
        .overlay {
            if viewModel.showInviteNextModal && viewModel.isHost {
                InviteNextUserModal(
                    isPresented: $viewModel.showInviteNextModal,
                    lastUser: viewModel.lastUserWhoLeft,
                    queueParticipants: viewModel.selectedSpace?.queue.participants ?? [],
                    onInviteNext: { userId in
                        Task {
                            await viewModel.inviteUserFromQueue(userId: userId)
                        }
                    }
                )
            }
        }
        .padding()
    }
}

struct AudioRenderer {
    // Hypothetical audio renderer that plays the audio
    let track: HMSAudioTrack

    func prepareToPlay() throws {
        // Prepare track to play
        print("Preparing to play audio.")
    }

    func play() {
        // Logic to play audio
        print("Playing audio.")
    }

    func stop() {
        // Logic to stop audio
        print("Stopping audio.")
    }
}
*/
