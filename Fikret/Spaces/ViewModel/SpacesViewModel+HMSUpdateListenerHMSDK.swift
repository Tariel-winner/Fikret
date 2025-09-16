//
//  SpacesViewModel+HMSUpdateListener.swift
//  Spaces
//
//  Created by Stefan Blos on 14.02.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//
import Foundation
import HMSSDK
//import SendbirdChatSDK  // Add this import
import SwiftUI
//import Firebase
//import Supabase
/*
class ImageCacheManagerForAuth {
  static let shared = ImageCacheManagerForAuth()
  private init() {}

  func downloadImage(from url: URL, peerID: String, completion: @escaping (UIImage?) -> Void) {
      let fileManager = FileManager.default
      let documentsURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
      let fileURL = documentsURL.appendingPathComponent("\(peerID).png")

      // Check if the image is already cached
      if let image = UIImage(contentsOfFile: fileURL.path) {
          completion(image)
          return
      }

      // Download the image
      URLSession.shared.dataTask(with: url) { data, response, error in
          guard let data = data, error == nil, let image = UIImage(data: data) else {
              completion(nil)
              return
          }

          // Save the image to cache
          do {
              try data.write(to: fileURL)
              completion(image)
          } catch {
              print("Error saving image: \(error)")
              completion(nil)
          }
      }.resume()
  }

  func removeImage(for peerID: String) {
      let fileManager = FileManager.default
      let documentsURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
      let fileURL = documentsURL.appendingPathComponent("\(peerID).png")

      do {
          if fileManager.fileExists(atPath: fileURL.path) {
              try fileManager.removeItem(at: fileURL)
              print("Image removed from cache: \(fileURL.lastPathComponent)")
          }
      } catch {
          print("Error removing image: \(error)")
      }
  }
}





class AudioPlaybackManager {
    static let shared = AudioPlaybackManager()
    private let conversationManager = ConversationCacheManager.shared

    func getAudioSource(for conversation: AudioConversation) -> URL {
        guard let audioUrl = conversation.audio_url,
              let url = URL(string: audioUrl) else {
            print("❌ Invalid audio URL in conversation")
            fatalError("Invalid audio URL")
        }
        return url
    }

    func fetchAndCacheConversations(for userId: Int64) async throws -> [AudioConversation]? {
        print("\n=== 🎯 FETCHING CONVERSATIONS ===")
        print("📍 User ID: \(userId)")
        
        // Check cache first
        let cachedConversations = conversationManager.getConversations(for: userId)
        print("🔍 Checking cache...")
        if !cachedConversations.isEmpty {
            print("✅ Found \(cachedConversations.count) conversations in cache")
            return cachedConversations
        }
        print("⚠️ No cached conversations found, fetching from API...")
        
      /*  let response =  try await supabase.database
            .from("audio_conversations")
            .select()
            .eq("host_id", value: String(userId))
            .eq("space_status", value: "completed")
            .execute()
        
        print("📝 Got raw response from Supabase")
        
        let decoder = JSONDecoder()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(dateString)"
            )
        }
        
        let convers = try decoder.decode([AudioConversation].self, from: response.data ?? Data())
        print("📥 Successfully decoded \(convers) conversations")
        
        // Cache the conversations
        print("💾 Caching conversations...")
        await conversationManager.cacheConversations(convers, for: userId)
        print("✅ Successfully cached conversations")
        
        return convers*/
        return nil
    }
    
    @MainActor func updateConversationCache(with conversation: AudioConversation) {
        print("\n=== 🔄 UPDATING CONVERSATION CACHE ===")
        print("📍 Conversation ID: \(conversation.id)")
        print("👤 User ID: \(conversation.user_id)")
        
        conversationManager.addConversation(conversation, for: (conversation.user_id))
        print("✅ Successfully updated cache with new conversation")
    }
}

class ConversationCacheManager: ObservableObject {
    static let shared: ConversationCacheManager = {
        let instance = ConversationCacheManager(tweetData: TweetData.shared)
        return instance
    }()
    @Published var talkCards: [Space] = []
    @Published var isLoadingTalkCards = false
    @Published  var isLoadingMore = false
    @Published var isLoadingConversations = false

        @Published var error: Error?
    func loadInitialTalkCards() {
        print("🔄 Loading initial talk cards...")
        Task {
            await MainActor.run {
                isLoadingTalkCards = true
                talkCards = []
            }
            
            do {
                let cards: [Space] = [] /*try await supabase.from("spaces")
                    .select()
                    .order("created_at", ascending: false)
                    .limit(10)
                    .execute()
                    .value*/
                
                print("✅ Loaded \(cards.count) initial talk cards")
                await MainActor.run {
                    self.talkCards = cards
                    isLoadingTalkCards = false
                }
            } catch {
                print("❌ Error loading initial talk cards: \(error)")
                await MainActor.run {
                    self.error = error
                    isLoadingTalkCards = false
                }
            }
        }
    }

    func loadMoreTalkCards() {
        guard !isLoadingMore else {
            print("⚠️ Already loading more talk cards")
            return
        }
        
        print("🔄 Loading more talk cards...")
        Task {
            await MainActor.run {
                isLoadingMore = true
            }
            
            do {
                let currentCount = talkCards.count
                print("📡 Fetching more spaces from index \(currentCount)")
                
                let newCards: [Space] = [] /*try await supabase.from("spaces")
                    .select()
                    .order("created_at", ascending: false)
                    .range(from: currentCount, to: currentCount + 9)
                    .execute()
                    .value*/
                
                print("✅ Loaded \(newCards.count) additional talk cards")
                await MainActor.run {
                    self.talkCards.append(contentsOf: newCards)
                    isLoadingMore = false
                }
            } catch {
                print("❌ Error loading more talk cards: \(error)")
                await MainActor.run {
                    self.error = error
                    isLoadingMore = false
                }
            }
        }
    }
    func loadInitialContent() {
          print("🔄 Loading initial conversations...")
          Task {
              await MainActor.run {
                  isLoadingConversations = true
              }
              
              do {
                  let conversations: [AudioConversation] = [] /* try await supabase.from("audio_conversations")
                      .select()
                      .eq("space_status", value: "completed")
                      .order("created_at", ascending: false)
                      .range(from: 0, to: 9)
                      .execute()
                      .value*/
                  
                  print("✅ Loaded \(conversations.count) initial conversations")
                  await MainActor.run {
                      self.feedConversations = conversations
                      isLoadingConversations = false
                  }
              } catch {
                  print("❌ Error loading initial conversations: \(error)")
                  await MainActor.run {
                      self.error = error
                      isLoadingConversations = false
                  }
              }
          }
      }
      
      func loadMoreContent() {
          guard !isLoadingMore,
                !self.feedConversations.isEmpty else { return }
          
          Task {
              await MainActor.run {
                  isLoadingMore = true
              }
              
              do {
                  let currentCount = self.feedConversations.count
                  let newConversations: [AudioConversation] = [] /*try await supabase.from("audio_conversations")
                      .select()
                      .eq("space_status", value: "completed")
                      .order("created_at", ascending: false)
                      .range(from: currentCount, to: currentCount + 9)
                      .execute()
                      .value
                  */
                  await MainActor.run {
                      self.feedConversations.append(contentsOf: newConversations)
                      isLoadingMore = false
                  }
              } catch {
                  await MainActor.run {
                      self.error = error
                      isLoadingMore = false
                      print("Error loading more content: \(error)")
                  }
              }
          }
      }

    func resetAndReloadContent(for tab: ConversationFeedView.FeedTab) {
        Task {
            await MainActor.run {
                if tab == .conversations {
                    feedConversations = []
                    isLoadingConversations = true
                    loadInitialContent()
                } else {
                    talkCards = []
                    isLoadingTalkCards = true
                   // loadInitialTalkCards()
                }
            }
        }
    }
    private let defaults = UserDefaults.standard
    private let conversationCacheKey = "cached_conversations"
    private let maxCacheSize: Int64 = 1024 * 1024 * 1024
    @Published private(set) var currentConversations: [AudioConversation] = []

    @Published var feedConversations: [AudioConversation] = []
   
    
    private var conversationsCache: [Int64: [AudioConversation]] = [:]
    private weak var tweetData: TweetData?
    
    private init(tweetData: TweetData) {
        self.tweetData = tweetData
        print("\n=== 🚀 INITIALIZING CONVERSATION CACHE MANAGER ===")
        loadFromDisk()
    }
    
 /*   @MainActor private func getAuthUserId() -> String? {
        var Id: String
        Id = String(tweetData?.user?.id)
        return Id
    }*/
    
    // Add this new method for fetching feed
    func loadFeedConversations() {
        print("\n=== 📂 LOADING FEED CONVERSATIONS ===")
        isLoadingConversations = true
        
        Task {
            do {
               /* let response = try await supabase.database
                    .from("audio_conversations")
                    .select()
                    .eq("space_status", value: "completed")
                    .order("created_at", ascending: false)
                    .limit(5) // Adjust limit as needed
                    .execute()
                
                let decoder = JSONDecoder()
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                decoder.dateDecodingStrategy = .custom { decoder -> Date in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    if let date = isoFormatter.date(from: dateString) {
                        return date
                    }
                    
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Invalid date format: \(dateString)"
                    )
                }
                
                let conversations = try decoder.decode([AudioConversation].self, from: response.data ?? Data())
                print("📥 Successfully decoded \(conversations.count) feed conversations")
                
                await MainActor.run {
                    self.feedConversations = conversations
                    self.isLoadingConversations = false
                    print("✅ Successfully loaded feed conversations")
                }*/
            } catch {
                await MainActor.run {
                    self.error = error
                    self.feedConversations = []
                    self.isLoadingConversations = false
                    print("❌ Error loading feed conversations: \(error.localizedDescription)")
                }
            }
        }
    }
    @MainActor private func checkAndCleanCacheSize() {
        let authUserId = tweetData?.user?.id ?? 0
        var totalSize: Int64 = 0
        var userCacheSizes: [(userId: Int64, size: Int64)] = []
        
        for (userId, conversations) in conversationsCache {
            if userId == authUserId { continue }
            let data = try? JSONEncoder().encode(conversations)
            let size = Int64(data?.count ?? 0)
            totalSize += size
            userCacheSizes.append((userId, size))
        }
        
        if totalSize > maxCacheSize {
            userCacheSizes.sort { $0.size > $1.size }
            
            for (userId, _) in userCacheSizes {
                conversationsCache.removeValue(forKey: userId)
                if getTotalCacheSize() <= maxCacheSize { break }
            }
            saveToDisk()
        }
    }
    
    private func getTotalCacheSize() -> Int64 {
        let data = try? JSONEncoder().encode(conversationsCache)
        return Int64(data?.count ?? 0)
    }
    
    func getConversations(for userId: Int64) -> [AudioConversation] {
        print("\n=== 🔍 RETRIEVING CONVERSATIONS ===")
        print("📍 User ID: \(userId)")
        
        let conversations = conversationsCache[userId] ?? []
        print("📊 Found \(conversations.count) conversations in cache")
        return conversations
    }
    
    @MainActor func cacheConversations(_ conversations: [AudioConversation], for userId: Int64) {
        print("\n=== 💾 CACHING CONVERSATIONS ===")
        print("📍 User ID: \(userId)")
        print("📊 Caching \(conversations.count) conversations")
        
        conversationsCache[userId] = conversations
        checkAndCleanCacheSize()
        saveToDisk()
        print("✅ Successfully cached conversations")
    }
    
    @MainActor func addConversation(_ conversation: AudioConversation, for userId: Int64) {
        print("\n=== ➕ ADDING SINGLE CONVERSATION ===")
        print("📍 User ID: \(userId)")
        print("🆔 Conversation ID: \(conversation.id)")
        
        var existing = conversationsCache[userId] ?? []
        if !existing.contains(where: { $0.id == conversation.id }) {
            existing.append(conversation)
            conversationsCache[userId] = existing
            checkAndCleanCacheSize()
            saveToDisk()
            print("✅ Successfully added conversation to cache")
        } else {
            print("⚠️ Conversation already exists in cache")
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(conversationsCache)
            defaults.set(data, forKey: conversationCacheKey)
            print("✅ Successfully saved cache to disk")
        } catch {
            print("❌ Failed to save cache to disk: \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard let data = defaults.data(forKey: conversationCacheKey) else {
            print("⚠️ No cached data found on disk")
            return
        }
        
        do {
            conversationsCache = try JSONDecoder().decode([Int64: [AudioConversation]].self, from: data)
            print("✅ Successfully loaded cache from disk")
            print("📊 Loaded \(conversationsCache.count) user caches")
        } catch {
            print("❌ Failed to load cache from disk: \(error)")
        }
    }
    
    func loadConversations(for userId: Int64) {
        print("\n=== 📂 LOADING CONVERSATIONS ===")
        print("📍 User ID: \(userId)")
        
        isLoadingConversations = true
        
        Task {
            do {
                let loadedConversations = try await AudioPlaybackManager.shared.fetchAndCacheConversations(for: userId)
                
                await MainActor.run {
                    self.conversationsCache[userId] = loadedConversations
                    self.currentConversations = loadedConversations!
                    self.isLoadingConversations = false
                    print("✅ Successfully loaded \(loadedConversations!.count) conversations")
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.currentConversations = []
                    self.isLoadingConversations = false
                    print("❌ Error loading conversations: \(error.localizedDescription)")
                }
            }
        }
    }
}

extension SpacesViewModel {
 
   /* private func adjustAudioLevels(fadePercentage: Double) {
        print("\n=== 🔊 Adjusting Audio Levels ===")
        print("Fade Percentage: \(fadePercentage)")
        
        // Convert fadePercentage (0.0-1.0) to HMS volume scale (0.0-10.0)
        let hmsVolume = fadePercentage * 10.0
        
        // Adjust own track if it exists
        if let localTrack = ownTrack {
            hmsSDK.setVolume(localTrack, volume: hmsVolume)
            print("✅ Adjusted local track volume to \(hmsVolume)")
        }
        
        // Adjust all remote tracks
        for remoteTrack in otherTracks {
            hmsSDK.setVolume(remoteTrack, volume: hmsVolume)
            print("✅ Adjusted remote track volume to \(hmsVolume)")
        }
    }*/
    
    public func on(error: Error) {
      print("[HMSUpdate] on error: \(error.localizedDescription)")
          guard let space = selectedSpace else {
              setInfoMessage(text: "Couldn't find space currently. Please try again later.", type: .error)
              return
          }
          
      if let hmsError = error as? HMSError {
          print("Error Code: \(hmsError.code), Description: \(hmsError.localizedDescription)")
          print("Error Domain: \(hmsError), Is Terminal: \(hmsError.isTerminal)")
      }
      
      // Only set isInSpace to false for terminal errors
      if let error = error as? HMSError, error.isTerminal {
         if error.canRetry  {
            print("Retrying connection")
            Task {
                await startCall(with: space.id)
            }
        } else {
           // showErrorAndExitMeeting(errorMessage: error.localizedDescription)
        }
            hmsSDK.leave()
          self.selectedSpace = nil
  
         
      } else {
          // Log non-terminal errors for further investigation
          print("⚠️ Non-terminal error occurred: \(error.localizedDescription)")
      }
  }

    
    @MainActor public func onPeerListUpdate(added: [HMSPeer], removed: [HMSPeer]) {
        guard let selectedSpace = self.selectedSpace else {
            print("❌ No selected space available.")
            return
        }
        print("[HMSUpdate] Peers added: \(added.count), removed: \(removed.count)")
        
        // Update initial peer count
        initialPeerCount = (hmsSDK.room?.peers.count ?? 0)
        print("👥 Initial peers in room: \(initialPeerCount)")
        
        // Handle added peers
        for peer in added {
            print("➕ Processing added peer: \(peer.name)")
            
            // Handle profile image
            if let imageURLString = peer.parsedMetadata()?["profilePicture"],
               let imageURL = URL(string: imageURLString) {
                ImageCacheManagerForAuth.shared.downloadImage(from: imageURL, peerID: peer.peerID) { [weak self] image in
                    DispatchQueue.main.async {
                        self?.peerImages[peer.peerID] = image
                    }
                }
            }
            
            // Handle audio tracks
            if let audioTrack = peer.audioTrack as? HMSAudioTrack {
                print("🎵 Found audio track for peer: \(peer.name)")
                if peer.isLocal {
                    print("🎵 Setting own track")
                    ownTrack = audioTrack
                } else {
                    print("🎵 Adding remote track for peer: \(peer.name)")
                    otherTracks.insert(audioTrack)
                }
            } else {
                print("⚠️ No audio track found for peer: \(peer.name)")
            }
            
            // Handle role assignment for new peers
            if isHost && !peer.isLocal {
                print("🎭 Processing role for new peer: \(peer.name)")
                if let speakerRole = hmsSDK.roles.first(where: { $0.name == "speaker" }) {
                    print("🎯 Assigning speaker role to: \(peer.name)")
                    hmsSDK.changeRole(for: peer, to: speakerRole, force: true)
                }
            }
        }
        
        // Handle removed peers
        for peer in removed {
            print("\n➖ Processing removed peer: \(peer.name)")
            
            // Clean up profile image
            if let imageURLString = peer.parsedMetadata()?["profilePicture"],
               let imageURL = URL(string: imageURLString) {
                ImageCacheManagerForAuth.shared.removeImage(for: peer.peerID)
            }
            
            // Clean up audio tracks
            if let audioTrack = peer.audioTrack {
                print("🎵 Removing audio track for peer: \(peer.name)")
                if peer.isLocal {
                    ownTrack = nil
                } else {
                    otherTracks.remove(audioTrack)
                }
            }
        }
        
        // Process metadata updates in batch
        if !added.isEmpty {
            print("🔄 Processing metadata for added peers")
            processPeerMetadata(added)
        }
        
        if !removed.isEmpty {
            print("🔄 Processing metadata for removed peers")
            removePeerMetadata(removed)
        }
        
        // Check recording state
        let totalPeers = hmsSDK.room?.peers.count ?? 0
        print("📊 Final peer count: \(totalPeers)")
        
        if totalPeers <= 1 && isRecording && isHost {
            print("🛑 Stopping recording - insufficient peers")
            stopCustomRecording()
        }
    }
    
    @MainActor public func on(join room: HMSRoom) {
        print("[HMSUpdate] on join room: \(room.roomID ?? "unknown")")
         if let currentPeers = hmsSDK.room?.peers {
        onPeerListUpdate(added: currentPeers, removed: [])
        
      
    }
     if isHost {
        print("🟢 Host is rejoining, verifying role...")
    }
    }
    

    
    @MainActor public func on(removedFromRoom notification: HMSRemovedFromRoomNotification) {
        print("[HMSUpdate] onRemovedFromRoom: \(notification.description), reason: \(notification.reason)")
        
        // Update recording state when removed from room
        if isRecording && isHost {
            stopCustomRecording()
            isRecording = false
            print("🛑 Stream recording stopped - removed from room")
        } else if isRecording && !isHost {
            isRecording = false
            print("🛑 Stream recording stopped after removal  removed from room")
        }
        
        // Clean up entire canvas when removed
        if let space = currentViewingSpace {
            Task {
                do {
                  currentViewingSpace = nil
                    print("🔄 Current Viewing Space set to nil")
               
                } catch {
                    print("❌ Failed to cleanup canvas: \(error)")
                }
            }
        }
        
        // Cleanup the tracks
        ownTrack = nil
        otherTracks = []
        
        // Update the state to reflect that the user is no longer in the space
        isInSpace = false
        showSpaceView = false
        
        // Get current user ID for cleanup
        let currentUserId = tweetData.user?.id ?? 0
        
        // Update both selectedSpace and currentViewingSpace
        if let selectedSpace = selectedSpace {
            var updatedSpace = selectedSpace
            // Remove all non-current users from selectedSpace
            updatedSpace.speakers.removeAll { speaker in
                let shouldRemove = speaker.id != currentUserId
                if shouldRemove {
                    print("🗑️ Removing non-current user from selectedSpace: \(speaker.name ?? "unknown")")
                }
                return shouldRemove
            }
            self.selectedSpace = updatedSpace
            print("✅ Updated selectedSpace speakers: \(updatedSpace.speakers.count)")
        }
        
        if let currentViewingSpace = currentViewingSpace {
            var updatedSpace = currentViewingSpace
            // Remove only current user from currentViewingSpace
            if let speakerIndex = updatedSpace.speakers.firstIndex(where: { $0.id == currentUserId }) {
                print("🗑️ Removing current user from currentViewingSpace")
                updatedSpace.speakers.remove(at: speakerIndex)
            }
            self.currentViewingSpace = updatedSpace
            print("✅ Updated currentViewingSpace speakers: \(updatedSpace.speakers.count)")
        }
        
        selectedSpace = nil
        
        // Update the state to remove the peer from the space
        updateStateAfterPeerRemoval(peerId: notification.requestedBy!.peerID)
        setInfoMessage(text: "You were removed from the space.\n\(notification.reason)", type: .information)
        activeNotification = NotificationMessage(
               message: "You were removed from the space by @\(notification.requestedBy?.name ?? "Host")",
               isError: true
           )
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.activeNotification = nil
            }
    }
    
    @MainActor public func on(peer: HMSPeer, update: HMSPeerUpdate) {
        print("[HMSUpdate] on peer: \(peer.name), update: \(update.description)")
        switch update {
        case .peerJoined:
            // When we are host and it's not the local peer
            if isHost && !peer.isLocal {
                // Change the role of the peer to "listener"
                if let listenerRole = hmsSDK.roles.first(where: { role in
                    role.name == "listener"
                }) {
                    hmsSDK.changeRole(for: peer, to: listenerRole, force: true)
                }
            }
        case .roleUpdated:
            print("🎭 Role updated for peer: \(peer.name)")
            objectWillChange.send()
            
        default:
            break
        }
    }


  @MainActor public func on(streamingState: HMSStreamingState) {
        print("\n=== 🏠 STREAMING STATE UPDATE RECEIVED ===")
        print("Streaming State: \(streamingState)")
        
        switch streamingState {
        case .none:
            print("⏹️ No streaming")
            
        case .starting:
            print("🔄 Streaming starting")
            
        case .started:
            print("▶️ Streaming started")
            
        case .stopped:
            print("⏹️ Streaming stopped")
            handleRoomEnded()
            
        case .failed:
            print("❌ Streaming failed")
            handleRoomEnded()
            
        @unknown default:
            print("⚠️ Unknown streaming state")
        }
    }

    @MainActor private func handleRoomEnded() {
        if isRecording {
            stopCustomRecording()
            isRecording = false
            print("🛑 Recording stopped - Room ended")
        }

        let activeSpace = selectedSpace ?? currentViewingSpace
        let currentUserId = tweetData.user?.id ?? 0
            
        if let space = activeSpace,
           let spaceIndex = spaces.firstIndex(where: { $0.id == space.id }) {
            print("\n=== 🏁 HANDLING ROOM END ===")
            print("🔍 Found active space: \(space.id)")
            print("👤 Current user ID: \(currentUserId)")
            print("📱 Space type: \(selectedSpace?.id == space.id ? "selectedSpace" : "currentViewingSpace")")
            
            var updatedSpace = spaces[spaceIndex]
            
            // Log initial state
            print("\n📊 Initial state:")
            print("- Total speakers: \(updatedSpace.speakers.count)")
            print("- Speaker IDs: \(updatedSpace.speakers.map { $0.id })")
            
            // Determine if this is selectedSpace or currentViewingSpace
            let isSelectedSpace = selectedSpace?.id == space.id
            
            if isSelectedSpace {
                // For selectedSpace: remove all non-current users
                print("🎯 Processing selectedSpace - removing non-current users")
                updatedSpace.speakers.removeAll { speaker in
                    let shouldRemove = speaker.id != currentUserId
                    if shouldRemove {
                        print("🗑️ Removing non-current user: \(speaker.name ?? "unknown") (ID: \(speaker.id))")
                    }
                    return shouldRemove
                }
            } else {
                // For currentViewingSpace: remove only current user
                print("👀 Processing currentViewingSpace - removing current user")
                if let speakerIndex = updatedSpace.speakers.firstIndex(where: { $0.id == currentUserId }) {
                    let speaker = updatedSpace.speakers[speakerIndex]
                    print("🗑️ Removing current user from speakers: \(speaker.name ?? "unknown") (ID: \(speaker.id))")
                    updatedSpace.speakers.remove(at: speakerIndex)
                } else {
                    print("⚠️ Current user not found in speakers list")
                }
            }
            
            // Update space state
            spaces[spaceIndex] = updatedSpace
            
            // Update active space references
            if selectedSpace?.id == updatedSpace.id {
                selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: selectedSpace!)
                print("✅ Selected Space Updated")
                print("- Speakers: \(selectedSpace?.speakers.count ?? 0)")
                print("- Speaker IDs: \(selectedSpace?.speakers.map { $0.id } ?? [])")
            }
            
            if currentViewingSpace?.id == updatedSpace.id {
                currentViewingSpace?.update(with: updatedSpace, preservingFieldsFrom: currentViewingSpace!)
                print("✅ Current Viewing Space Updated")
                print("- Speakers: \(currentViewingSpace?.speakers.count ?? 0)")
                print("- Speaker IDs: \(currentViewingSpace?.speakers.map { $0.id } ?? [])")
            }
            
            print("📊 Final state after room end:")
            print("- Speakers: \(updatedSpace.speakers.count)")
            print("- Speaker IDs: \(updatedSpace.speakers.map { $0.id })")
            print("- Speaker details:")
            updatedSpace.speakers.forEach { speaker in
                print("  - ID: \(speaker.id), Name: \(speaker.name ?? "unknown"), PeerID: \(speaker.peerID ?? "unknown")")
            }
        }
        
        hmsSDK.leave()
        selectedSpace = nil
        ownTrack = nil
        otherTracks = []
        setInfoMessage(text: "Host left - conversation completed", type: .information)
        
        // Force UI update
        objectWillChange.send()
        print("\n=== ✅ ROOM END HANDLING COMPLETED ===")
    }

    public func on(track: HMSTrack, update: HMSTrackUpdate, for peer: HMSPeer) {
        print("[HMSUpdate] on track: \(track.trackId), update: \(update.description), peer: \(peer.name)")
        switch update {
        case .trackAdded:
            // If the track that was added is an audio track, add it to our tracks.
            if let audioTrack = track as? HMSAudioTrack {
                if peer.isLocal {
                    ownTrack = audioTrack
                } else {
                    otherTracks.insert(audioTrack)
                }
            }
        case .trackRemoved:
            // If the track that was removed is an audio track, remove it from our tracks.
            if let audioTrack = track as? HMSAudioTrack {
                if peer.isLocal {
                    ownTrack = nil
                } else {
                    otherTracks.remove(audioTrack)
                }
            }
        default:
            break
        }
    }

    
    @MainActor private func processPeerMetadata(_ peers: [HMSPeer]) {
        print("\n=== 🔄 BATCH PROCESSING PEER METADATA ===")
        
        guard let roomID = hmsSDK.room?.roomID,
              let allPeers = hmsSDK.room?.peers else {
            print("❌ Room ID or peers missing")
            return
        }
        
        print("📊 Processing all peers in room: \(allPeers.count)")
        
        // Find the active space (either selectedSpace or currentViewingSpace)
        let activeSpace = selectedSpace ?? currentViewingSpace
        
        guard let spaceIndex = spaces.firstIndex(where: {
            ($0.hmsRoomId == roomID) || (String($0.id) == String(activeSpace?.id ?? 0))
        }) else {
            print("❌ Space index not found")
            return
        }

        var updatedSpace = spaces[spaceIndex]
        updatedSpace.hmsRoomId = roomID

        // Process ALL peers in the room, not just the ones that changed
        for peer in allPeers {
            print("\n👤 Processing peer: \(peer.name)")
            
            // Parse metadata with explicit error handling
            let parsedMetadata: [String: String]
            do {
                guard let metadata = peer.metadata,
                      let data = metadata.data(using: .utf8) else {
                    print("⚠️ No metadata or invalid encoding for peer: \(peer.name)")
                    continue
                }
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
                    print("⚠️ Invalid metadata format for peer: \(peer.name)")
                    continue
                }
                parsedMetadata = json
                
            } catch {
                print("❌ Failed to parse metadata: \(error)")
                continue
            }
            
            // Log metadata contents
            print("📝 Parsed Metadata:")
            print("- User ID: \(parsedMetadata["userId"] ?? "nil")")
            print("- Name: \(parsedMetadata["name"] ?? "nil")")
            print("- Topic: \(parsedMetadata["topic"] ?? "nil")")
            
            // Update topic if present
            if let topic = parsedMetadata["topic"] {
                print("\n🎯 Found topic in metadata: \(topic)")
                currentTopic = topic
            }

            // Create participant
            let participant = SpaceParticipant(
                id: Int64(parsedMetadata["id"] ?? "0") ?? 0,
                name: parsedMetadata["name"] ?? "Guest",
                username: "",
                imageURL: URL(string: parsedMetadata["image_url"] ?? ""),
                peerID: peer.peerID,
                topic: parsedMetadata["topic"]
            )
            
            print("\n👤 Created participant:")
            print("- ID: \(participant.id)")
            print("- Name: \(participant.name)")
            print("- PeerID: \(participant.peerID ?? "nil")")
            print("- Topic: \(participant.topic ?? "nil")")

            let roleName = peer.role?.name.lowercased() ?? "listener"
            print("🎭 Role: \(roleName)")

            // Add to speakers if role is speaker or moderator
            if roleName == "speaker" || roleName == "moderator" {
                // Check if speaker already exists
                if let existingIndex = updatedSpace.speakers.firstIndex(where: { $0.id == participant.id }) {
                    // Replace existing speaker with new data
                    print("🔄 Replacing existing speaker: \(peer.name)")
                    updatedSpace.speakers[existingIndex] = participant
                } else {
                    // Add new speaker
                    print("➕ Adding new speaker: \(peer.name)")
                    updatedSpace.speakers.append(participant)
                }
            }
        }

        // Update state
        spaces[spaceIndex] = updatedSpace
        
        // Update the active space if needed
        if let activeSpace = activeSpace {
            if selectedSpace?.id == updatedSpace.id {
                selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: selectedSpace!)
                print("Selected Space Updated: \(String(describing: selectedSpace?.id))")
                print("📊 Updated speakers count: \(selectedSpace?.speakers.count ?? 0)")
                print("👥 Speaker IDs: \(selectedSpace?.speakers.map { $0.id } ?? [])")
            }
            
            if currentViewingSpace?.id == updatedSpace.id {
                currentViewingSpace?.update(with: updatedSpace, preservingFieldsFrom: currentViewingSpace!)
                print("Current Viewing Space Updated: \(String(describing: currentViewingSpace?.id))")
                print("📊 Updated speakers count: \(currentViewingSpace?.speakers.count ?? 0)")
                print("👥 Speaker IDs: \(currentViewingSpace?.speakers.map { $0.id } ?? [])")
            }
        }
        
        let totalPeers = hmsSDK.room?.peers.count ?? 0
        print("\n📊 Final State:")
        print("- Total peers: \(totalPeers)")
        print("- Speakers: \(updatedSpace.speakers.count)")
        print("- Speaker IDs: \(updatedSpace.speakers.map { $0.id })")
        
        if totalPeers > 1 && !isRecording && isHost && !currentTopic.isEmpty {
            print("🎙️ Starting recording")
            startCustomRecording()
        }

        objectWillChange.send()
        print("\n=== ✅ BATCH PROCESSING COMPLETED ===")
    }

    @MainActor private func removePeerMetadata(_ peers: [HMSPeer]) {
        print("\n=== 🗑️ STARTING BATCH PEER REMOVAL ===")
        print("Removing \(peers.count) peers")
        
        // Find the active space (either selectedSpace or currentViewingSpace)
        let activeSpace = selectedSpace ?? currentViewingSpace
        
        guard let space = activeSpace,
              let spaceIndex = spaces.firstIndex(where: { $0.id == space.id }) else {
            print("❌ No active space found or invalid space index")
            return
        }

        // Log initial state
        print("🔄 Before batch removePeerMetadata:")
        print("- Speakers: \(space.speakers.map { $0.id })")
       
        var updatedSpace = space
        
        // Clean up canvas collection once for all peers
        Task {
            do {
              /*  try await Firestore.firestore()
                    .collection("spaceCanvas")
                    .document(String(space.id))
                    .delete()*/
                print("✅ Cleaned up canvas for space: \(String(space.id))")
            } catch {
                print("❌ Failed to cleanup canvas: \(error)")
            }
        }
        
        // Process all peers in batch
        for peer in peers {
            print("\n🔄 Processing removal for peer: \(peer.name)")
            
            // Remove from speakers array
            if updatedSpace.speakers.contains(where: { $0.peerID == peer.peerID }) {
                print("- Removing from speakers: \(peer.name)")
                updatedSpace.speakers.removeAll { $0.peerID == peer.peerID }
            }
            
           
            
            print("🖼️ Cleaned up canvas items for departing user: \(peer.peerID)")
        }
        
        // Update state using mutation
        spaces[spaceIndex] = updatedSpace
        
        // Update the active space (either selectedSpace or currentViewingSpace)
        if let activeSpace = activeSpace {
            if selectedSpace?.id == updatedSpace.id {
                selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: selectedSpace!)
                print("Selected Space Updated: \(String(describing: selectedSpace?.id))")
            }
            if currentViewingSpace?.id == updatedSpace.id {
                currentViewingSpace?.update(with: updatedSpace, preservingFieldsFrom: currentViewingSpace!)
                print("Current Viewing Space Updated: \(String(describing: currentViewingSpace?.id))")
            }
        }
        
        // Log final state
        print("\n🔄 After batch removePeerMetadata:")
        print("- Speakers: \(updatedSpace.speakers.map { $0.id })")
    
        
        let totalPeers = (hmsSDK.room?.peers.count ?? 0)
        print("👥 Total peers remaining in room: \(totalPeers)")
        
        // Check recording state once after all removals
        if totalPeers <= 1 && isRecording && isHost {
            print("🎙️ Stop recording - \(totalPeers) speakers in the space")
            stopCustomRecording()
        }
        
        // Notify SwiftUI once for all changes
        objectWillChange.send()
        
        print("✅ Completed batch removal of \(peers.count) peers")
    }

    public func on(message: HMSMessage) {
        print("[HMSUpdate] on message: \(message.message)")
        // Add any additional logging if needed
    }
    
    public func on(updated speakers: [HMSSpeaker]) {
        print("\n=== 🔊 SPEAKER UPDATE RECEIVED ===")
        print("Total speakers: \(speakers.count)")
        
        // Log each speaker's details
        for (index, speaker) in speakers.enumerated() {
            print("\nSpeaker \(index + 1):")
            print("- Name: \(speaker.peer.name)")
            print("- PeerID: \(speaker.peer.peerID)")
            print("- Audio Level: \(speaker.level)")
            print("- Is Local: \(speaker.peer.isLocal)")
        }
        
        DispatchQueue.main.async {
            if let firstSpeakingPeer = speakers.first {
                let audioLevel = firstSpeakingPeer.level
                // Set the current active speaker ID (metadata is user ID)
                self.activeSpeakerId = firstSpeakingPeer.peer.peerID
                print("\n=== 🔊 Active Speaker Update ===")
                print("Old Active Speaker ID: \(oldActiveSpeakerId ?? "nil")")
                print("New Active Speaker ID: \(self.activeSpeakerId ?? "nil")")
                print("Speaker Name: \(firstSpeakingPeer.peer.name)")
                print("Audio Level: \(audioLevel)")
                
                // Update speakerIds set based on current active speakers
                withAnimation {
                    self.speakerIds = Set(speakers.compactMap { speaker in
                        if let metadata = speaker.peer.metadata,
                           let userId = Int64(metadata) {
                            return userId
                        }
                        return nil
                    })
                }
            } else {
                // No active speakers, reset activeSpeakerId
                self.activeSpeakerId = nil
            }
        }
    }
    
    public func onReconnecting() {
      //  reconnecting = true
        print("[HMSUpdate] on reconnecting")
        // Log the current state of listeners and other relevant data
      
    }
    
    @MainActor public func onReconnected() {
        print("[HMSUpdate] on reconnected")
      //  reconnecting = false
        print("\n=== HMS RECONNECTED ===")

        // Check recording state after reconnection
        if let currentPeers = hmsSDK.room?.peers,
           let selectedSpace = self.selectedSpace {
            if currentPeers.count < 2 && isRecording && isHost {
                print("🛑 Stopping recording after reconnection - Insufficient peers")
                stopCustomRecording()
                isRecording = false
            }
    
        }

        // Re-fetch and update peer list after reconnecting
        if let currentPeers = hmsSDK.room?.peers {
            onPeerListUpdate(added: currentPeers, removed: [])
        }

        // Log the updated state of listeners and other relevant data
     

        // Ensure the user retains the host role if they were the host
        if isHost {
            if let hostRole = hmsSDK.roles.first(where: { $0.name == "host" }) {
                hmsSDK.changeRole(for: hmsSDK.localPeer!, to: hostRole, force: true)
            }
        }
    }


    // Storage config matching 100ms dashboard
    private struct StorageConfig {
        static let bucket = "conversations"  // Your bucket name
        static let region = "auto"          // Your region
        static let prefix = "spaces"        // Recommended prefix for better organization
    }

    // Add storage config struct
    private struct R2Config {
        static let accessKey = "90f510507ebb799c81183619756d6cde"
        static let bucket = "conversations"
        static let region = "auto"
        static let prefix = "spaces"
        static let accountId = "fc9bb64b8e9130de6c3dd1a617f62a9b"
    }

    @MainActor public func on(room: HMSRoom, update: HMSRoomUpdate) {
      
      
    }
    @MainActor private func startCustomRecording() {
           guard isHost else {
               print("❌ Only host can start recording")
               return
           }
           
           guard let roomId = hmsSDK.room?.roomID,
                 let space = selectedSpace else {
               print("❌ Recording failed to start - Missing roomId or space")
               return
           }
           
           // Reset and start timer
           recordingTimeRemaining = 420 // 7 minutes
           recordingStartTime = Date()
           isRecordingActive = true
           
           // Start timer
           recordingTimer?.invalidate()
           recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
               guard let self = self else {
                   timer.invalidate()
                   return
               }
               
               Task { @MainActor in
                   if self.recordingTimeRemaining > 0 {
                       self.recordingTimeRemaining -= 1
                       
                       // Start fading out audio when 30 seconds remaining
                      /* if self.recordingTimeRemaining <= 30 {
                           let fadePercentage = self.recordingTimeRemaining / 30.0
                           self.adjustAudioLevels(fadePercentage: fadePercentage)
                       }*/
                   } else {
                       // Time's up - stop recording
                       timer.invalidate()
                       await self.stopCustomRecording()
                   }
               }
           }
           
           print("\n=== 🎙️ STARTING RECORDING FLOW ===")
           print("📍 Room ID: \(roomId)")
           print("📍 Space ID: \(String(space.id))")
           
           // Debug current speakers state
           print("🔍 Current Speakers State:")
           print("Total Speakers: \(space.speakers.count)")
           print("Speaker IDs: \(space.speakers.map { $0.id })")
           print("Host ID: \(String(space.hostId))")
           
           // Ensure we have at least 2 speakers before proceeding
          
           
           
           Task {
               do {
                   let managementToken = try generateManagmentToken()
                   print("🔑 Using management token for recording API")
                   
                   print("\n👥 PROCESSING PARTICIPANTS")
                   // Get all speakers except the host
                   let participantsToRecord = selectedSpace?.speakers.filter { $0.id != selectedSpace?.hostId ?? 0 } ?? []
                   print("📊 Total participants to record: \(participantsToRecord.count)")
                   print("🔍 Participants details:")
                   participantsToRecord.forEach { participant in
                       print("- Name: \(participant.name), ID: \(participant.id)")
                   }
                   
                   // Only proceed if we have participants to record
                   guard !participantsToRecord.isEmpty else {
                       print("⚠️ No participants to record after filtering")
                       return
                   }
                   
                   print("\n🎙️ CONFIGURING RECORDING")
                   var request = URLRequest(url: URL(string: "https://api.100ms.live/v2/recordings/room/\(roomId)/start")!)
                   request.httpMethod = "POST"
                   request.setValue("Bearer \(managementToken)", forHTTPHeaderField: "Authorization")
                   request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                   
                   let requestBody: [String: Any] = [
                       "audio_only": true
                   ]
                   
                   let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
                   request.httpBody = jsonData
                   
                   print("📤 Request Headers:")
                   request.allHTTPHeaderFields?.forEach { key, value in
                       print("  \(key): \(value)")
                   }
                   print("📤 Request Body: \(String(data: jsonData, encoding: .utf8) ?? "")")
                   
                   print("🔄 Starting recording via API...")
                   let (data, response) = try await URLSession.shared.data(for: request)
                   
                   guard let httpResponse = response as? HTTPURLResponse else {
                       print("❌ Invalid response type")
                       throw NSError(domain: "Recording", code: 500)
                   }
                   
                   print("📥 Response Status Code: \(httpResponse.statusCode)")
                   print("📥 Response Headers:")
                   httpResponse.allHeaderFields.forEach { key, value in
                       print("  \(key): \(value)")
                   }
                   
                   // Try to parse and print response body regardless of status code
                   if let responseString = String(data: data, encoding: .utf8) {
                       print("📥 Response Body: \(responseString)")
                   }
                   
                   guard httpResponse.statusCode == 200 else {
                       // Try to parse error response
                       if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                           print("❌ API Error Details: \(errorJson)")
                       }
                       throw NSError(domain: "Recording", code: httpResponse.statusCode)
                   }
                   guard let httpResponse = response as? HTTPURLResponse,
                                httpResponse.statusCode == 200,
                                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                let recordingId = json["id"] as? String,
                                let status = json["status"] as? String else {
                              throw NSError(domain: "Recording", code: (response as? HTTPURLResponse)?.statusCode ?? 500)
                          }
                 
                   
                   for participant in participantsToRecord {
                       print("\n🎯 Processing participant: \(participant.name)")
                       
                     /*  let conversation = [
                           "host_id": String(space.hostId),
                                                 "user_id": String(participant.id),
                                                 "user_name": participant.name,
                                                 "user_image": participant.imageURL?.absoluteString,
                                                 "host_name": space.host ?? "Unknown Host",
                                                 "host_image": space.hostImageUrl,
                                                 "room_id": roomId,           // Save room_id for matching
                                                 "recording_id": recordingId,  // Save recording_id for matching
                                                 "space_status": "processing",
                           "tag": currentTopic
                       ] as [String: String?]*/
                       

                        let audioTweet = try await createAudioTweet(
                    roomId: roomId,
                    sessionId: "", // ✅ ADDED: sessionId parameter
                    visitorUsername: participant.name ?? "",
                    audioContent: recordingId,
                    duration: "420", // 7 minutes in seconds
                    size: "0", // Size will be updated when recording is complete
                    tag: currentTopic,
                    visibility: PostConfig.Visibility.public,
                    locationData: participant.locationData // ✅ ADDED: Pass participant's location data
                )
                       print("📝 Saving conversation record to database...\(audioTweet)")
                    
                       print("✅ Saved conversation record for: \(participant.name)")
                       self.isRecording = true
                   }
                   
                   
               } catch {
                   print("\n❌ ERROR STARTING RECORDING")
                   print("Error: \(error)")
                   self.isRecording = false  // Ensure recording state is updated on error
               
               }
           }
       }
    // Handle recording state updates
    
    
    
    
    private func verifyRecordingExists(at url: URL) async -> Bool {
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("❌ Failed to verify recording: \(error)")
            return false
        }
    }

    // Get playback URL for a recording
    func getPlaybackURL(permanentPath: String) -> URL {
        // For public R2 bucket
        return URL(string: "https://\(StorageConfig.bucket).r2.cloudflarestorage.com/\(permanentPath)")!
    }

    // Update stopCustomRecording to use HTTP API
    @MainActor private func stopCustomRecording() {
          // Cleanup timer
          recordingTimer?.invalidate()
          recordingTimer = nil
          isRecordingActive = false
          recordingStartTime = nil
          
          guard isHost else {
              print("❌ Only host can stop recording")
              return
          }
          
          guard let roomId = hmsSDK.room?.roomID else {
              print("❌ Missing roomId")
              isRecording = false
              return
          }
          
          Task {
              do {
                  let managementToken = try generateManagmentToken()
                  print("\n=== ⏹️ STOPPING RECORDING ===")
                  print("📍 Room ID: \(roomId)")
                  print("🔑 Management Token (first 10 chars): \(String(managementToken.prefix(10)))...")
                  
                  let url = URL(string: "https://api.100ms.live/v2/recordings/room/\(roomId)/stop")!
                  print("🌐 Request URL: \(url.absoluteString)")
                  
                  var request = URLRequest(url: url)
                  request.httpMethod = "POST"
                  request.setValue("Bearer \(managementToken)", forHTTPHeaderField: "Authorization")
                  request.setValue("application/json", forHTTPHeaderField: "Content-Type") // Add missing Content-Type header
                  
                  // Add empty JSON body as per API spec
                  let emptyBody: [String: Any] = [:]
                  request.httpBody = try JSONSerialization.data(withJSONObject: emptyBody)
                  
                  // Log request details
                  print("\n📤 Request Details:")
                  print("Method: \(request.httpMethod ?? "nil")")
                  print("Headers: \(request.allHTTPHeaderFields ?? [:])")
                  if let bodyData = request.httpBody,
                     let bodyString = String(data: bodyData, encoding: .utf8) {
                      print("Body: \(bodyString)")
                  }
                  
                  let (data, response) = try await URLSession.shared.data(for: request)
                  
                  // Log raw response
                  print("\n📥 Raw Response:")
                  if let responseString = String(data: data, encoding: .utf8) {
                      print(responseString)
                  }
                  
                  guard let httpResponse = response as? HTTPURLResponse else {
                      print("❌ Invalid response type")
                      throw NSError(domain: "Recording",
                                  code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
                  }
                  
                  // Log response details
                  print("\n📥 Response Details:")
                  print("Status Code: \(httpResponse.statusCode)")
                  print("Headers: \(httpResponse.allHeaderFields)")
                  
                  // Parse error response if status code is not 200
                  if httpResponse.statusCode != 200 {
                      if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                          print("❌ Error Response: \(json)")
                          
                          // Try to get detailed error message
                          let message = (json["message"] as? String) ?? "Unknown error"
                          throw NSError(domain: "Recording",
                                      code: httpResponse.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: message])
                      } else {
                          throw NSError(domain: "Recording",
                                      code: httpResponse.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "Failed to stop recording"])
                      }
                  }
                  
                  // Try to parse success response
                  if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                      print("✅ Success Response: \(json)")
                  }
                  
                  self.isRecording = false
                  print("✅ Recording stopped successfully")
                   // Start polling for the recording
                
                
               
                  
              } catch {
                  print("\n❌ Error Details:")
                  print("Error: \(error)")
             
                  
                  self.isRecording = false
                  
              }
          }
      }
    // Add a method to check if we should be recording
    private func shouldStartRecording() -> Bool {
        guard let room = hmsSDK.room else { return false }
        
        // Count peers excluding the local peer
        let otherPeersCount = room.peers.filter { !$0.isLocal }.count
        return otherPeersCount > 0 // At least one other person besides the host
    }
}

extension HMSPeer {
    func parsedMetadata() -> [String: String]? {
        guard let metadata = self.metadata,
              let data = metadata.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }
        return json
    }
}





*/