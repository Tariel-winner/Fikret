//
//  SpaceView.swift
//  Spaces
//
//  Created by Stefan Blos on 16.02.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import SwiftUI
/*
// MARK: - Helper Functions
private func getButtonTextForRunningState(isInSpace: Bool, isHost: Bool) -> String {
    if isInSpace {
        return isHost ? "End space" : "Leave space quietly"
    }
    return "Join space"
}

private func getButtonTextForPlannedState(isHost: Bool) -> String {
    return isHost ? "Start space" : "Waiting for space to start"
}

private func participantRole(isHost: Bool) -> String {
    isHost ? "Host" : "Speaker"
}

private func reconnectingOverlayView() -> some View {
    ZStack {
        Color(white: 0, opacity: 0.75)
        ProgressView().tint(.white)
        Text("Reconnecting")
    }
}

private func liveIndicatorView() -> some View {
    Text("LIVE")
        .italic()
        .bold()
        .foregroundColor(.white)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(LinearGradient.spaceish, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
}

private func listenerCountView(_ count: Int) -> some View {
    Text("\(count) total listeners")
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.gray, lineWidth: 2)
        }
}

// MARK: - View Components
private func participantOverlay(speakerIds: Set<Int64>, id: String) -> some View {
    Group {
        if speakerIds.contains(id) {
            Circle().stroke(LinearGradient.spaceish, lineWidth: 4)
        }
    }
}

// MARK: - Grid Components
private func speakersSection(speakers: [SpaceParticipant], hostId: String, speakerIds: Set<Int64>, viewModel: SpacesViewModel, isHost: Bool) -> some View {
    ForEach(speakers, id: \.id) { speaker in
        VStack {
            ImageFromUrl(url: speaker.imageURL, size: 50)
                .padding(4)
                .overlay {
                    if speakerIds.contains(speaker.id) {
                        Circle().stroke(LinearGradient.spaceish, lineWidth: 4)
                    }
                }
                .contextMenu {
                    if isHost {
                        Button("Remove from Space", role: .destructive) {
                            Task { @MainActor in
                                await viewModel.removeUser(speaker)
                            }
                        }
                    }
                }
            
            Text(speaker.name ?? "Unknown")
                .font(.caption)
                .bold()
            
            Text(participantRole(isHost: String(hostId) == String(speaker.id)))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

private func listenersSection(listeners: [SpaceParticipant], speakerIds: Set<Int64>, viewModel: SpacesViewModel, isHost: Bool) -> some View {
    ForEach(listeners, id: \.id) { listener in
        VStack {
            ImageFromUrl(url: listener.imageURL, size: 50)
                .padding(4)
                .overlay {
                    if speakerIds.contains(listener.id) {
                        Circle().stroke(LinearGradient.spaceish, lineWidth: 4)
                    }
                }
                 .contextMenu {
                     if isHost {
                        Button("Remove from Space", role: .destructive) {
                            Task { await viewModel.removeUser(listener) }
                        }
                    }
                }
            
            Text(listener.name ?? "Unknown")
                .font(.caption)
                .bold()
            
            Text("Listener")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct ParticipantGridView: View {
    let columns: [GridItem]
    let gridSpacing: CGFloat
    let speakers: [SpaceParticipant]
    let listeners: [SpaceParticipant]
    let hostId: String
    let speakerIds: Set<String>
    @EnvironmentObject var viewModel: SpacesViewModel

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: gridSpacing) {
            speakersSection(speakers: speakers, hostId: hostId, speakerIds: speakerIds, viewModel: viewModel,isHost: viewModel.isHost)
            listenersSection(listeners: listeners, speakerIds: speakerIds,viewModel: viewModel,isHost: viewModel.isHost)
        }
    }
}

struct SpaceView: View {
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
     @EnvironmentObject var viewModel: SpacesViewModel
   
  
    
    let columns = [GridItem(.adaptive(minimum: 80))]
    let gridSpacing: CGFloat = 20
    
    @State private var showInviteQueueView = false
    
    // MARK: - Computed Properties
    var buttonText: String {
        let isHost = viewModel.isHost
        if let space = viewModel.selectedSpace {
            switch space.state {
            case .running: return getButtonTextForRunningState(isInSpace: viewModel.isInSpace, isHost: viewModel.isHost)
            case .planned: return getButtonTextForPlannedState(isHost: viewModel.isHost)
            case .finished: return "This space finished already"
            }
        }
        return "This space finished already"
    }
    
    var buttonDisabled: Bool {
        if let space = viewModel.selectedSpace {
            if space.state == .finished { return true }
            if space.state == .planned && !viewModel.isHost { return true }
        }
        return false
    }
    
    // MARK: - Helper Views
    private var audioControlButton: some View {
        Button {
            viewModel.toggleAudioMute()
        } label: {
            Image(systemName: viewModel.isAudioMuted ? "speaker.slash.circle" : "speaker.circle")
                .resizable()
                .frame(width: 38, height: 38)
                .foregroundStyle(LinearGradient.spaceish)
        }
    }
    
    private var closeSpaceButton: some View {
        Button {
           /* Task {
                await viewModel.spaceCloseTapped()
                 viewModel.showSpaceView = false
                dismiss()
            }*/
            viewModel.showSpaceView = false
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundStyle(LinearGradient.spaceish)
        }
    }
    
    // MARK: - Control Views
    private var actionButton: some View {
        Button {
            Task { await viewModel.spaceButtonTapped() }
        } label: {
            Text(buttonText)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    LinearGradient.spaceish,
                    in: Capsule()
                )
        }
        .padding(.horizontal)
        .disabled(buttonDisabled)
        .opacity(buttonDisabled ? 0.4 : 1)
    }
    
    // MARK: - Content Components
    private var descriptionView: some View {
        Text(viewModel.selectedSpace?.description ?? "")
            .font(.headline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var audioControlsView: some View {
        Group {
            if viewModel.selectedSpace?.state == .running {
                HStack {
                    Spacer()

                     if viewModel.isHost {
                    Button(action: {
                        withAnimation(.easeInOut) {
                            showInviteQueueView.toggle()
                        }
                    }) {
                        Image(systemName: "person.3.fill")
                            .resizable()
                            .frame(width: 38, height: 38) // Ensures the button is easily tappable
                            .padding()
                            .background(Circle().fill(LinearGradient.spaceish))
                            .shadow(radius: 5)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }

                    if viewModel.isSpeaker {
                        audioControlButton
                    }

                }
                .padding(.horizontal)
            }
        }
    }
    
    private var bottomInfoView: some View {
        VStack {
            listenerCountView(viewModel.selectedSpace?.listeners.count ?? 0)
            
            if !viewModel.isInSpace {
                Text("Your mic will be off to start")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            actionButton
        }
    }
    
    private var navigationToolbar: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                closeSpaceButton
            }
            if viewModel.selectedSpace?.state == .running {
                ToolbarItem(placement: .navigationBarTrailing) {
                    liveIndicatorView()
                }
            }
        }
    }
    
   /* private var mainContent: some View {
        VStack {
            descriptionView
            
            ParticipantGridView(
                columns: columns,
                gridSpacing: gridSpacing,
                speakers: viewModel.selectedSpace?.speakers ?? [],
                listeners: viewModel.selectedSpace?.listeners ?? [],
                hostId: viewModel.selectedSpace?.hostId,
                speakerIds: viewModel.speakerIds
            )
            
          
            
            Spacer()
            Divider().padding(.bottom)
            
            audioControlsView
            bottomInfoView
        }
       .onAppear {
        // Debugging: Log the current state of selectedSpace
        if let selectedSpace = viewModel.selectedSpace {
            print("🔄 SpaceView - Selected Space ID: in spaceView \(selectedSpace.id)")
            print("🔄 SpaceView - Speakers: in spaceView \(selectedSpace.speakers)")
            print("🔄 SpaceView - Listeners: in spaceView \(selectedSpace.listeners)")
        } else {
            print("❌ SpaceView - No selected space")
        }
    }
    }*/
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                /*mainContent
                    .overlay(viewModel.reconnecting ? reconnectingOverlayView() : nil)*/
            }
            .padding()
            .navigationTitle(viewModel.selectedSpace?.name ?? "Space")
            .toolbar { navigationToolbar }
           /* .sheet(isPresented: $showInviteQueueView) {
                InviteQueueView()
                    .environmentObject(viewModel)
                    .presentationDetents([.medium, .large]) // Use medium and large detents for modal
                    .presentationDragIndicator(.visible)
            }*/
            .onAppear {
               
               
                if viewModel.isInSpace {
                    if let room = viewModel.hmsSDK.room {
                        viewModel.onPeerListUpdate(added: room.peers, removed: [])
                    }
                }
            }
            .onDisappear {
               
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .inactive || newPhase == .background {
                    dismiss()
                }
            }
        }
    }
}


struct SpaceView_Previews: PreviewProvider {
    static var previews: some View {
        // Explicitly use Space.preview
        SpaceView()
            .environmentObject(SpacesViewModel.preview)
    }
}*/


