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

// MARK: - Clean SAPlayer-Only Audio Playback Manager with Real Audio Level Monitoring
class WebMAudioPlaybackManager: NSObject, ObservableObject, DualAudioLevelDelegate {
    // MARK: - Global State Management
    private static var currentlyPlayingManager: WebMAudioPlaybackManager?
    
    // MARK: - Essential Published Properties for UI State
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var progress: Double = 0.0
    @Published var isPlaying: Bool = false
    @Published var isSeeking: Bool = false
    
    // ✅ ADDED: Post-specific progress tracking
    @Published var currentPlayingConversationId: Int64?
    @Published var currentProgress: Double = 0.0
    
    // MARK: - Audio Level Monitoring
    @Published var hostAudioLevel: Float = 0.0
    @Published var visitorAudioLevel: Float = 0.0
    
    // MARK: - Speaker State
    @Published var activeSpeakerId: Int64?
   
    // MARK: - Callback Closures
    var onHostLevelUpdate: ((Float) -> Void)?
    var onVisitorLevelUpdate: ((Float) -> Void)?
    var onPositionUpdate: ((Double) -> Void)?
    var onPreparationComplete: (() -> Void)?
    
    // MARK: - SAPlayer Integration
    private var saPlayer: SAPlayer?
    
    // MARK: - Conversation Data
    private var currentConversation: AudioConversation?
    private var hostId: Int64?
    private var visitorId: Int64?
    
    // MARK: - UI Synchronization Timer
    private var uiSyncTimer: Timer?
    
    // MARK: - Computed Properties for Derived State
    
    /// Both speakers are active (computed from activeSpeakerId)
    var bothSpeakersActive: Bool {
        return activeSpeakerId != nil
    }
    
    /// Manager is active (computed from SAPlayer's state)
    var isActive: Bool {
        guard let player = saPlayer else { return false }
        return player.isDualAudioMode && (isPlaying || isSeeking)
    }
    
    /// UI controls are enabled (computed from SAPlayer's state)
    var isUIEnabled: Bool {
        guard let player = saPlayer else { return false }
        return player.isDualAudioMode && player.currentDualAudioEngine?.conversationState?.isPrepared == true
    }
    
    /// User is scrubbing (alias for isSeeking for backward compatibility)
    var isScrubbing: Bool {
        get { return isSeeking }
        set { isSeeking = newValue }
    }
    
    /// Host volume (delegated to SAPlayer dual audio)
    var hostVolume: Float {
        get { return saPlayer?.currentDualAudioEngine?.conversationState?.hostVolume ?? 1.0 }
        set { saPlayer?.setHostVolume(newValue) }
    }
    
    /// Visitor volume (delegated to SAPlayer dual audio)
    var visitorVolume: Float {
        get { return saPlayer?.currentDualAudioEngine?.conversationState?.visitorVolume ?? 1.0 }
        set { saPlayer?.setVisitorVolume(newValue) }
    }
    
    // MARK: - SAPlayer UI State Management
    
    private func setupTimeObserver() {
        // ✅ FIXED: Use SAPlayer's built-in time tracking instead of custom timer
        // SAPlayer already provides real-time updates via its delegate system
        // The time observer is now handled by SAPlayer's internal mechanisms
    }
    
    private func updateUIFromSAPlayer() {
        // ✅ SIMPLIFIED: Just use SAPlayer's state directly - no complex sync needed
        guard let player = saPlayer else { return }
        
        // Direct state from SAPlayer - no manual calculations
        self.currentTime = player.elapsedTime ?? 0.0
        let newDuration = player.duration ?? 0.0
        
        self.duration = newDuration
        self.isPlaying = (player.playingStatus == .playing)
        
        // ✅ FIXED: Reset progress when conversation changes to ensure proper UI updates
        let newConversationId = player.currentDualAudioConversationId
        if self.currentPlayingConversationId != newConversationId {
            // Reset progress when switching conversations
            self.progress = 0.0
            self.currentProgress = 0.0
            
            // ✅ CRITICAL: Force refresh duration for new conversation
            if let newDuration = player.duration {
                self.duration = newDuration
            }
        }
        
        // Update conversation tracking
        self.currentPlayingConversationId = newConversationId
        
        // ✅ FIXED: Calculate progress based on current conversation's duration
        self.progress = self.duration > 0 ? self.currentTime / self.duration : 0.0
        self.currentProgress = self.progress
        
        // Handle completion
        if self.progress >= 1.0 && self.isPlaying {
            handlePlaybackCompletion()
        }
        
        // Call position update callback
        self.onPositionUpdate?(self.currentTime)
    }
    
    private func setupAudioLevelMonitoring() {
        // ✅ FIXED: Audio level monitoring is handled by SAPlayer's DualAudioEngine
        // via the DualAudioLevelDelegate methods below
        // No custom implementation needed - SAPlayer provides real-time audio levels
    }
    
    // MARK: - UI Synchronization Timer
    
    private func startUISynchronizationTimer() {
        // Stop existing timer
        uiSyncTimer?.invalidate()
        
        // Start new timer for UI synchronization
        uiSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateUIFromSAPlayer()
        }
    }
    
    private func stopUISynchronizationTimer() {
        uiSyncTimer?.invalidate()
        uiSyncTimer = nil
    }
    
    // MARK: - DualAudioLevelDelegate Implementation
    
    func hostAudioLevelChanged(_ level: Float) {
         print("🎧 [WebM] hostAudioLevelChanged called with: \(String(format: "%.3f", level))")
        // ✅ FIXED: Direct wrapper around SAPlayer's dual audio level updates
        DispatchQueue.main.async {
             print("🎧 [WebM] Updating hostAudioLevel from \(self.hostAudioLevel) to \(level)")
            self.hostAudioLevel = level
            self.onHostLevelUpdate?(level)
             print("🎧 [WebM] hostAudioLevel updated to: \(self.hostAudioLevel)")
         self.updateActiveSpeakerDetection()
        }
    }
    
    func visitorAudioLevelChanged(_ level: Float) {
        print("🎤 [WebM] visitorAudioLevelChanged called with: \(String(format: "%.3f", level))")
        // ✅ FIXED: Direct wrapper around SAPlayer's dual audio level updates
        DispatchQueue.main.async {
            print("🎤 [WebM] Updating visitorAudioLevel from \(self.visitorAudioLevel) to \(level)")
            self.visitorAudioLevel = level
            self.onVisitorLevelUpdate?(level)
            print("🎤 [WebM] visitorAudioLevel updated to: \(self.visitorAudioLevel)")
        self.updateActiveSpeakerDetection()
        }
    }
    // MARK: - Active Speaker Detection Logic

    private func updateActiveSpeakerDetection() {
         guard let hostId = hostId,
          let visitorId = visitorId else {
        print("❌ [ACTIVE_SPEAKER] No speaker IDs available")
        return
        }
    
    // Define thresholds for WebM audio (typically lower than live audio)
     let speakingThreshold: Float = 0.001  // Lower threshold for WebM
    let bothSpeakersThreshold: Float = 0.002  // Lower threshold for both speakers
    
    let hostSpeaking = hostAudioLevel > speakingThreshold
    let visitorSpeaking = visitorAudioLevel > speakingThreshold
    
    var newActiveSpeakerId: Int64?
    
    if hostSpeaking && visitorSpeaking {
        // Both speaking - use the louder one
        newActiveSpeakerId = hostAudioLevel > visitorAudioLevel ? hostId : visitorId
        print("🎯 [ACTIVE_SPEAKER] Both speakers active - host: \(hostAudioLevel), visitor: \(visitorAudioLevel), active: \(newActiveSpeakerId == hostId ? "host" : "visitor")")
    } else if hostSpeaking {
        newActiveSpeakerId = hostId
        print("🎯 [ACTIVE_SPEAKER] Host speaking - level: \(hostAudioLevel)")
    } else if visitorSpeaking {
        newActiveSpeakerId = visitorId
        print("🎯 [ACTIVE_SPEAKER] Visitor speaking - level: \(visitorAudioLevel)")
    } else {
        newActiveSpeakerId = nil
        print("🎯 [ACTIVE_SPEAKER] No one speaking")
    }
    
    // Only update if changed
    if newActiveSpeakerId != activeSpeakerId {
        print("🎯 [ACTIVE_SPEAKER] Active speaker changed from \(activeSpeakerId ?? 0) to \(newActiveSpeakerId ?? 0)")
        activeSpeakerId = newActiveSpeakerId
    }
        }

    
    func activeSpeakerChanged(_ speakerId: Int64?) {
        // ✅ FIXED: Direct wrapper around SAPlayer's active speaker detection
        DispatchQueue.main.async {
            self.activeSpeakerId = speakerId
        }
    }
    
    // MARK: - SAPlayer Volume Control
    
    func setHostVolume(_ volume: Float) {
        saPlayer?.setHostVolume(volume)
    }
    
    func setVisitorVolume(_ volume: Float) {
        saPlayer?.setVisitorVolume(volume)
    }
    
    // MARK: - SAPlayer Speed Control
    
    func setPlaybackSpeed(_ speed: Float) {
        saPlayer?.setDualAudioSpeed(speed)
    }
    
    // MARK: - SAPlayer Seeking
    
    func seek(to progress: Double) {
        guard let player = saPlayer,
              let duration = player.duration,
              duration > 0 else {
            return
        }
        
        // Simple seek - just calculate target time and seek
        let targetTime = progress * duration
        player.seekTo(seconds: targetTime)
    }
    
  
    /**
     Performs a complete reset by clearing SAPlayer state.
     SAPlayer handles all internal cleanup automatically.
     */
    func fullReset() {
        // Stop UI synchronization timer
        stopUISynchronizationTimer()
        
        // Clear SAPlayer state (handles all internal cleanup)
        saPlayer?.clear()
        
        // Reset UI state
        resetUIState()
        
        // Clear conversation data
        clearConversationData()
    }
    
    /**
     Resets all UI-related state properties to their initial values.
     This ensures a clean slate for the next audio preparation.
     */
    private func resetUIState() {
        DispatchQueue.main.async {
            // Playback state
            self.currentTime = 0
            self.duration = 0
            self.progress = 0
            self.isPlaying = false
            self.isSeeking = false
            
            // ✅ ADDED: Reset post-specific progress tracking
            self.currentPlayingConversationId = nil
            self.currentProgress = 0.0
            
            // Audio level monitoring
            self.hostAudioLevel = 0
            self.visitorAudioLevel = 0
            self.activeSpeakerId = nil
        }
    }
    
    /**
     Clears all conversation-specific data to prevent state contamination.
     This ensures each new conversation starts with a clean state.
     */
    private func clearConversationData() {
        currentConversation = nil
        hostId = nil
        visitorId = nil
    }
    
    /**
     Performs final cleanup when the audio manager is being deallocated.
     This ensures all resources are properly released.
     */
    func cleanup() {
        // Stop UI synchronization timer
        stopUISynchronizationTimer()
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        // Clear SAPlayer state
        saPlayer?.clear()
    }
    
    override init() {
        super.init()
        
        saPlayer = SAPlayer.shared
        setupAudioSessionHandling()
        setupTimeObserver()
        setupAudioLevelMonitoring()
    }
    
    // MARK: - Audio Session Management
    
    private func setupAudioSessionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pauseForAudioSession),
            name: .pauseAllBackgroundAudio,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resumeAfterAudioSession),
            name: .resumeBackgroundAudio,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(forceStopForAudioSession),
            name: .forceStopAllAudio,
            object: nil
        )
    }
    
    /// Pause audio when entering a space
    @objc private func pauseForAudioSession() {
        print("🔇 [WebMAudioPlaybackManager] Pausing for audio session")
        
        if isPlaying {
            pause()
        }
    }
    
    /// Resume audio when leaving a space
    @objc private func resumeAfterAudioSession() {
        print("🔊 [WebMAudioPlaybackManager] Resuming after audio session")
        
        // Note: We don't auto-resume anymore - let user control playback
    }
    
    /// Force stop audio (emergency stop)
    @objc private func forceStopForAudioSession() {
        print("🛑 [WebMAudioPlaybackManager] Force stopping for audio session")
        
        emergencyStop()
    }
    
    // ✅ REMOVED: Audio session blocking check - SAPlayer handles this internally
    
    // ✅ REMOVED: Audio session management - SAPlayer handles this internally
    
    // MARK: - SAPlayer Preparation
    
    /**
     Prepares the audio manager for playing a specific conversation.
     This method ensures proper cleanup and preparation following SAPlayer best practices.
     Now includes cache-aware logic to prioritize local storage over API calls.
     
     - Parameter conversation: The audio conversation to prepare for playback
     */
    func prepareToPlay(conversation: AudioConversation) {
        print("🎧 Preparing \(conversation.id)")
        
        // Check if we're already prepared for this conversation
        if isPreparedForConversation(conversation.id) {
            print("✅ Already prepared for \(conversation.id)")
            return
        }
        
        // Full reset to ensure clean state (now synchronous)
        fullReset()
        
        // Use cache-aware preparation
        prepareAudioWithCachePriority(conversation)
    }
    
    // MARK: - SAPlayer Playback Control
    
    func play() {
        // ✅ FIXED: Let SAPlayer handle audio session - don't interfere
        // SAPlayer already manages audio session internally
        
        // Simple - just call SAPlayer's play method
        saPlayer?.play()
        
        // Set as currently playing manager
        WebMAudioPlaybackManager.currentlyPlayingManager = self
    }
    
    func pause() {
        // Simple - just call SAPlayer's pause method
        saPlayer?.pause()
        
        // Clear global playing manager if this is the current one
        if WebMAudioPlaybackManager.currentlyPlayingManager === self {
            WebMAudioPlaybackManager.currentlyPlayingManager = nil
        }
    }
    
    /**
     Stops playback and performs cleanup.
     */
    func stop() {
        pause()
        cleanup()
    }
    
    /**
     Emergency stop - immediately stops all audio and forces cleanup.
     Use this for critical situations where normal stop might not be sufficient.
     */
    func emergencyStop() {
        print("🚨 Emergency stop initiated")
        
        // Stop UI synchronization timer
        stopUISynchronizationTimer()
        
        // Force stop SAPlayer immediately
        saPlayer?.pause()
        saPlayer?.clear()
        
        // Reset UI state immediately
        resetUIState()
        
        // Clear conversation data
        clearConversationData()
        
        print("✅ Emergency stop completed")
    }
    
    // MARK: - Global Audio Management
    
    static func stopAllPlayers() {
        if let currentManager = currentlyPlayingManager {
            currentManager.pause()
            currentlyPlayingManager = nil
        }
    }
    
    static func isAnyPlayerPlaying() -> Bool {
        return currentlyPlayingManager?.isPlaying ?? false
    }
    
    static func getCurrentlyPlayingConversationId() -> Int64? {
        return currentlyPlayingManager?.currentConversation?.id
    }
    
    func isCurrentlyPlayingManager() -> Bool {
        return WebMAudioPlaybackManager.currentlyPlayingManager === self
    }
    
    func isPreparedForConversation(_ conversationId: Int64) -> Bool {
        // ✅ SIMPLIFIED: Use SAPlayer's dual audio state directly
        guard let player = saPlayer else { return false }
        
        return player.currentDualAudioConversationId == conversationId &&
               player.currentDualAudioEngine?.conversationState?.isPrepared == true
    }
    
    /**
     Clean method to check if a specific conversation is currently playing.
     This is the recommended way to check playing state in UI.
     */
    func isCurrentlyPlaying(_ conversationId: Int64) -> Bool {
        // ✅ SIMPLIFIED: Use SAPlayer's state directly
        guard let player = saPlayer else { return false }
        
        return player.currentDualAudioConversationId == conversationId &&
               player.playingStatus == .playing
    }
    
    /**
     ✅ ADDED: Get progress for a specific conversation.
     Returns 0.0 if the conversation is not currently playing.
     */
    func getProgressForConversation(_ conversationId: Int64) -> Double {
        // ✅ FIXED: Get duration directly from SAPlayer for the specific conversation
        // This ensures each conversation uses its own duration, not the global one
        guard let player = saPlayer,
              player.currentDualAudioConversationId == conversationId else {
            return 0.0
        }
        
        let currentTime = player.elapsedTime ?? 0.0
        // ✅ FIXED: Use player.duration directly instead of self.duration
        // This ensures each conversation uses its own duration
        let conversationDuration = player.duration ?? 0.0
        
       
        if conversationDuration > 0 {
            let progress = min(max(currentTime / conversationDuration, 0.0), 1.0)
           
            return progress
        }
        
        return 0.0
    }
    
    /**
     ✅ ADDED: Get duration for a specific conversation.
     Returns 0.0 if the conversation is not prepared.
     */
    func getDurationForConversation(_ conversationId: Int64) -> Double {
        // ✅ FIXED: Get duration directly from SAPlayer for the specific conversation
        // This ensures we get the correct duration for each conversation
        guard let player = saPlayer,
              player.currentDualAudioConversationId == conversationId else {
            return 0.0
        }
        
        let conversationDuration = player.duration ?? 0.0
        print("🎵 [DURATION_CHECK] Conversation \(conversationId) - SAPlayer duration: \(conversationDuration)")
        return conversationDuration
    }
    

    
    /**
     Forces a UI update by triggering objectWillChange.
     Use this when you need to ensure the UI updates immediately.
     */
    func forceUIUpdate() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    /**
     Forces synchronization of UI state from SAPlayer.
     Use this when you need to ensure the UI reflects the current SAPlayer state.
     */
    func forceSyncFromSAPlayer() {
        print("🔄 Force syncing UI state from SAPlayer")
        updateUIFromSAPlayer()
        forceUIUpdate()
    }
    
    /**
     ✅ SIMPLIFIED: Handle playback completion and reset state.
     Call this when audio reaches the end to ensure proper state reset.
     */
    func handlePlaybackCompletion() {
        print("🎵 Handling playback completion")
        
        // ✅ FIXED: The SAPlayerDualAudio engine now automatically resets to 0 when audio ends
        // No need to manually seek - the engine handles this in updateDualAudioNeedle()
        
        // ✅ FIXED: Let SAPlayer handle audio session - don't interfere
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentProgress = 0.0
            self.progress = 0.0
            self.currentTime = 0.0
            
            // Clear global playing manager
            if WebMAudioPlaybackManager.currentlyPlayingManager === self {
                WebMAudioPlaybackManager.currentlyPlayingManager = nil
            }
        }
        
        print("✅ Playback completion handled - audio will reset to beginning automatically")
    }
    
    /**
     ✅ SIMPLIFIED: Reset seek position to beginning for a specific conversation.
     Use this when you need to ensure audio starts from the beginning.
     */
    func resetSeekPosition(for conversationId: Int64) {
        guard saPlayer?.currentDualAudioConversationId == conversationId else {
            return
        }
        
        // ✅ FIXED: Use SAPlayer's seek method - the dual audio engine handles this properly
        saPlayer?.seekTo(seconds: 0.0)
        
        DispatchQueue.main.async {
            self.currentTime = 0.0
            self.currentProgress = 0.0
            self.progress = 0.0
        }
        
        print("✅ Seek position reset to beginning for conversation \(conversationId)")
    }
    
    /**
     ✅ SIMPLIFIED: Ensures the audio level delegate is properly set up.
     Call this if you suspect the delegate isn't working.
     */
    func ensureDelegateSetup() {
        saPlayer?.setAudioLevelDelegate(self)
        
        if let conversation = currentConversation {
            saPlayer?.setSpeakerIds(hostId: conversation.host_id ?? 0, visitorId: conversation.user_id ?? 0)
        }
    }
    
    /**
     Ensures the audio is properly prepared before seeking.
     Call this before seeking to ensure the audio is ready.
     */
    func ensurePreparationComplete() {
        // Simple check - just verify SAPlayer is available
        guard saPlayer != nil else {
            print("❌ Cannot ensure preparation - SAPlayer not available")
            return
        }
    }
    
   
    func switchToConversation(_ conversation: AudioConversation) {
        print("🔄 Switching to conversation \(conversation.id)")
        
        // Stop any currently playing manager
        if let currentManager = WebMAudioPlaybackManager.currentlyPlayingManager {
            currentManager.pause()
            WebMAudioPlaybackManager.currentlyPlayingManager = nil
        }
        
        // Pause current playback
        if isPlaying {
            pause()
        }
        
        // Reset UI state immediately
        resetUIState()
        
        // Use prepareAudioWithCachePriority for proper dual audio setup
        prepareAudioWithCachePriority(conversation)
    }
    
    /// Get the current conversation being played
    var currentPlayingConversation: AudioConversation? {
        return currentConversation
    }
    
    /// Get the currently playing conversation ID (public interface)
    var playingConversationId: Int64? {
        return saPlayer?.currentDualAudioConversationId
    }
    
    /// Check if the current conversation is prepared (for UI state tracking)
    var isPrepared: Bool {
        guard let player = saPlayer else { return false }
        return player.currentDualAudioEngine?.conversationState?.isPrepared == true
    }
    
    deinit {
        stopUISynchronizationTimer()
        NotificationCenter.default.removeObserver(self)
        saPlayer?.clear()
    }
    
    // MARK: - Conversation Management
    
    /**
     Sets the active conversation and prepares it for playback.
     This ensures proper audio state management when switching between conversations.
     */
    func setActiveConversation(_ conversation: AudioConversation) {
        print("🎵 Setting active conversation: \(conversation.id)")
        
        // Update the current conversation
        currentConversation = conversation
        hostId = Int64(conversation.host_id ?? 0)
        visitorId = Int64(conversation.user_id ?? 0)
        
        // Prepare the audio for this conversation
        if !isPreparedForConversation(conversation.id) {
            print("🎧 Preparing audio for conversation: \(conversation.id)")
            prepareAudioWithCachePriority(conversation)
        } else {
            print("🎧 Conversation \(conversation.id) already prepared")
        }
    }
    
    // MARK: - Feed-Specific Preloading Methods
    
    /**
     Preloads the next conversation for smooth TikTok-style feed navigation.
     This method prepares audio without interrupting current playback.
     
     - Parameter conversation: The conversation to preload
     */
    func preloadNextConversation(_ conversation: AudioConversation) {
        print("📥 [FEED] Preloading next conversation \(conversation.id) for smooth navigation")
        
        // ✅ ADDED: Check if already preloaded to avoid duplicate work
        if isConversationPreloaded(conversation) {
            print("✅ [FEED] Next conversation \(conversation.id) already preloaded - skipping")
            return
        }
        
        // ✅ FIXED: Use SAPlayer's queue system for non-interruptive preloading
        guard let player = saPlayer else {
            print("❌ SAPlayer not available for preloading")
            return
        }
        
        // Use SAPlayer's queue system which doesn't interrupt current playback
        player.queueDualAudioConversation(conversation)
        
        print("✅ [FEED] Next conversation \(conversation.id) queued for preloading")
    }
    
    /**
     Preloads the previous conversation for smooth TikTok-style feed navigation.
     This method prepares audio without interrupting current playback.
     
     - Parameter conversation: The conversation to preload
     */
    func preloadPreviousConversation(_ conversation: AudioConversation) {
        print("📥 [FEED] Preloading previous conversation \(conversation.id) for smooth navigation")
        
        // ✅ ADDED: Check if already preloaded to avoid duplicate work
        if isConversationPreloaded(conversation) {
            print("✅ [FEED] Previous conversation \(conversation.id) already preloaded - skipping")
            return
        }
        
        // ✅ FIXED: Use SAPlayer's queue system for non-interruptive preloading
        guard let player = saPlayer else {
            print("❌ SAPlayer not available for preloading")
            return
        }
        // Use SAPlayer's queue system which doesn't interrupt current playback
        player.queueDualAudioConversation(conversation)
        
        print("✅ [FEED] Previous conversation \(conversation.id) queued for preloading")
    }
    
    /**
     Clears all preloaded conversations to free up resources.
     This is called when the feed is no longer active.
     */
    func clearPreloadedQueue() {
        print("🧹 [FEED] Clearing preloaded conversation queue")
        
        guard let player = saPlayer else {
            print("❌ SAPlayer not available for clearing queue")
            return
        }
        
        // Use SAPlayer's queue clearing method
        let clearedConversations = player.clearAllQueuedDualAudio()
        
        print("✅ [FEED] Preloaded conversation queue cleared - \(clearedConversations.count) conversations removed")
    }
    
    /**
     Checks if a conversation is already preloaded/cached.
     This helps avoid duplicate preloading operations.
     
     - Parameter conversation: The conversation to check
     - Returns: True if the conversation is preloaded, false otherwise
     */
    func isConversationPreloaded(_ conversation: AudioConversation) -> Bool {
        guard let player = saPlayer else {
            return false
        }
        
        return player.isConversationPreloaded(conversation)
    }
    
    // MARK: - Cache-Aware Audio Preparation
    
    /**
     Prepares audio for playback using SAPlayer's built-in caching system.
     SAPlayer will automatically handle caching and use cached versions when available.
     NOTE: This method will replace current audio - use preload methods for feed navigation.
     
     - Parameter conversation: The conversation to prepare
     */
    func prepareAudioWithCachePriority(_ conversation: AudioConversation) {
        print("🔄 Preparing audio for conversation \(conversation.id)")
        
        // Simple conversation switching - just clear and restart
        if let currentId = saPlayer?.currentDualAudioConversationId, currentId != conversation.id {
            print("🔄 Switching from conversation \(currentId) to \(conversation.id)")
            saPlayer?.clear()
        }
        
        // Set conversation data
        currentConversation = conversation
        hostId = conversation.host_id
        visitorId = conversation.user_id
        
        guard let hostURLString = conversation.host_audio_url,
              let visitorURLString = conversation.visitor_audio_url,
              !hostURLString.isEmpty,
              !visitorURLString.isEmpty,
              let hostURL = URL(string: hostURLString),
              let visitorURL = URL(string: visitorURLString),
              let player = saPlayer else {
            print("❌ Invalid setup for conversation \(conversation.id)")
            return
        }
        
        // Simple setup - just start dual audio
     
      

          player.setSpeakerIds(hostId: conversation.host_id ?? 0, visitorId: conversation.user_id ?? 0)
                player.startDualAudio(hostURL: hostURL, visitorURL: visitorURL, conversationId: conversation.id)
        

       DispatchQueue.main.async {
    player.setAudioLevelDelegate(self)
    print("✅ Audio level delegate set for conversation \(conversation.id)")
        }
        // Start UI timer
        startUISynchronizationTimer()
        
        print("✅ Dual audio ready for conversation \(conversation.id)")
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
    
    // Add VLC-based WebM AudioPlaybackManager instance
    private let audioPlaybackManager = WebMAudioPlaybackManager()
    
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
    // ✅ OPTIMIZED: Cached sets for O(1) conversation ID lookups
    private var conversationIdsCache: [Int64: Set<Int64>] = [:] // userId: Set<conversationId>
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
                // ✅ OPTIMIZED: Clean up cached set when removing conversations
                conversationIdsCache.removeValue(forKey: userId)
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
        
        // ✅ OPTIMIZED: Update cached set for O(1) lookups
        let conversationIds = Set(conversations.map { $0.id })
        conversationIdsCache[userId] = conversationIds
        
        checkAndCleanCacheSize()
        saveToDisk()
        print("✅ Successfully cached conversations")
    }
    
    @MainActor func addConversation(_ conversation: AudioConversation, for userId: Int64) {
        print("\n=== ➕ ADDING SINGLE CONVERSATION ===")
        print("📍 User ID: \(userId)")
        print("🆔 Conversation ID: \(conversation.id)")
        
        // ✅ OPTIMIZED: Use cached set for O(1) lookup instead of O(n) linear search
        let existingIds = conversationIdsCache[userId] ?? Set()
        if !existingIds.contains(conversation.id) {
            var existing = conversationsCache[userId] ?? []
            existing.append(conversation)
            conversationsCache[userId] = existing
            
            // ✅ OPTIMIZED: Update cached set for O(1) lookups
            var updatedIds = existingIds
            updatedIds.insert(conversation.id)
            conversationIdsCache[userId] = updatedIds
            
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
            
            // ✅ OPTIMIZED: Initialize cached sets for O(1) lookups
            conversationIdsCache.removeAll()
            for (userId, conversations) in conversationsCache {
                conversationIdsCache[userId] = Set(conversations.map { $0.id })
            }
            
            print("✅ Successfully loaded cache from disk")
            print("📊 Loaded \(conversationsCache.count) user caches")
            print("📊 Initialized \(conversationIdsCache.count) conversation ID sets for O(1) lookups")
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
               /* let loadedConversations = try await audioPlaybackManager.fetchAndCacheConversations(for: userId)
                
                await MainActor.run {
                    self.conversationsCache[userId] = loadedConversations
                    self.currentConversations = loadedConversations!
                    self.isLoadingConversations = false
                    print("✅ Successfully loaded \(loadedConversations!.count) conversations")
                }*/
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


// MARK: - LiveKit Room Delegate
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

    // MARK: - Mute/Unmute Functionality
    
    /**
     Mutes a specific participant in the current space.
     
     - Parameter participantId: The ID of the participant to mute
     - Returns: True if successful, false otherwise
     */
    @MainActor func muteParticipant(_ participantId: Int64) -> Bool {
        print("🔇 Muting participant: \(participantId)")
        
        guard let space = selectedSpace ?? currentViewingSpace,
              let spaceIndex = spaces.firstIndex(where: { $0.id == space.id }) else {
            print("❌ No active space found")
            return false
        }
        
        // Find the participant's audio track using stored tracks
        guard let participant = space.speakers.first(where: { $0.id == participantId }),
              let peerID = participant.peerID else {
            print("❌ Participant not found")
            return false
        }
        
        // Find the audio track from our stored tracks
        let audioTrack: HMSAudioTrack?
        if let localPeer = hmsSDK.localPeer, localPeer.peerID == peerID {
            // This is the local user
            audioTrack = ownTrack
        } else {
            // This is a remote user - find their track in otherTracks
            audioTrack = otherTracks.first { track in
                // Find the peer that owns this track
                if let peer = hmsSDK.room?.peers.first(where: { $0.audioTrack?.trackId == track.trackId }) {
                    return peer.peerID == peerID
                }
                return false
            }
        }
        
        guard let trackToMute = audioTrack else {
            print("❌ Audio track not found for participant \(participantId)")
            return false
        }
        
        // ✅ FIXED: Use correct HMS SDK methods for self vs remote control
        if let localPeer = hmsSDK.localPeer, localPeer.peerID == peerID {
            print("🔇 [MUTE] Self mute - using localAudioTrack().setMute(true)")
            
            // For self-mute, use the correct HMS SDK method
            hmsSDK.localPeer?.localAudioTrack()?.setMute(true)
            print("🔇 [MUTE] setMute(true) called for self")
            
            // Check the current mute state after setting
            if let localAudioTrack = hmsSDK.localPeer?.localAudioTrack() {
                let isMuted = localAudioTrack.isMute()
                print("🔇 [MUTE] Self track mute state after setMute: \(isMuted)")
            }
        } else {
            // For remote mute, use changeTrackState (works immediately)
            print("🔇 [MUTE] Remote mute - using changeTrackState")
            hmsSDK.changeTrackState(for: trackToMute, mute: true)
        }
        
        print("✅ Audio track mute request sent")
        
        // Update local state
        var updatedSpace = spaces[spaceIndex]
        if let speakerIndex = updatedSpace.speakers.firstIndex(where: { $0.id == participantId }) {
            updatedSpace.speakers[speakerIndex].isMuted = true
            spaces[spaceIndex] = updatedSpace
            
            // Update active space references
            if selectedSpace?.id == space.id {
                selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: selectedSpace!)
            }
            if currentViewingSpace?.id == space.id {
                currentViewingSpace?.update(with: updatedSpace, preservingFieldsFrom: currentViewingSpace!)
            }
            
            // ✅ ADDED: Update direct reactive property for current user
            if let currentUserId = tweetData.user?.id, currentUserId == participantId {
                isCurrentUserMuted = true
                print("✅ [REACTIVE] Updated isCurrentUserMuted to: true")
            }
            
            print("✅ Participant \(participantId) muted successfully")
            return true
        }
        
        print("❌ Failed to update local state")
        return false
    }
    
    /**
     Unmutes a specific participant in the current space.
     
     - Parameter participantId: The ID of the participant to unmute
     - Returns: True if successful, false otherwise
     */
    @MainActor func unmuteParticipant(_ participantId: Int64) -> Bool {
        print("🔊 Unmuting participant: \(participantId)")
        
        guard let space = selectedSpace ?? currentViewingSpace,
              let spaceIndex = spaces.firstIndex(where: { $0.id == space.id }) else {
            print("❌ No active space found")
            return false
        }
        
        // Find the participant's audio track using stored tracks
        guard let participant = space.speakers.first(where: { $0.id == participantId }),
              let peerID = participant.peerID else {
            print("❌ Participant not found")
            return false
        }
        
        // Find the audio track from our stored tracks
        let audioTrack: HMSAudioTrack?
        if let localPeer = hmsSDK.localPeer, localPeer.peerID == peerID {
            // This is the local user
            audioTrack = ownTrack
        } else {
            // This is a remote user - find their track in otherTracks
            audioTrack = otherTracks.first { track in
                // Find the peer that owns this track
                if let peer = hmsSDK.room?.peers.first(where: { $0.audioTrack?.trackId == track.trackId }) {
                    return peer.peerID == peerID
                }
                return false
            }
        }
        
        guard let trackToUnmute = audioTrack else {
            print("❌ Audio track not found for participant \(participantId)")
            return false
        }
        
        // ✅ FIXED: Use correct HMS SDK methods for self vs remote control
        if let localPeer = hmsSDK.localPeer, localPeer.peerID == peerID {
            print("🔊 [UNMUTE] Self unmute - using localAudioTrack().setMute(false)")
            
            // For self-unmute, use the correct HMS SDK method
            hmsSDK.localPeer?.localAudioTrack()?.setMute(false)
            print("🔊 [UNMUTE] setMute(false) called for self")
            
            // Check the current mute state after setting
            if let localAudioTrack = hmsSDK.localPeer?.localAudioTrack() {
                let isMuted = localAudioTrack.isMute()
                print("🔊 [UNMUTE] Self track mute state after setMute: \(isMuted)")
            }
        } else {
            // For remote unmute, use changeTrackState (sends request)
            print("🔊 [UNMUTE] Remote unmute - using changeTrackState")
            let result = hmsSDK.changeTrackState(for: trackToUnmute, mute: false)
            print("🔊 [UNMUTE] changeTrackState result: \(result)")
            print("🔊 [UNMUTE] Remote unmute request sent - waiting for acceptance")
        }
        
        print("✅ Audio track unmute request sent")
        
        // Update local state
        var updatedSpace = spaces[spaceIndex]
        if let speakerIndex = updatedSpace.speakers.firstIndex(where: { $0.id == participantId }) {
            updatedSpace.speakers[speakerIndex].isMuted = false
            spaces[spaceIndex] = updatedSpace
            
            // Update active space references
            if selectedSpace?.id == space.id {
                selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: selectedSpace!)
            }
            if currentViewingSpace?.id == space.id {
                currentViewingSpace?.update(with: updatedSpace, preservingFieldsFrom: currentViewingSpace!)
            }
            
            // ✅ ADDED: Update direct reactive property for current user
            if let currentUserId = tweetData.user?.id, currentUserId == participantId {
                isCurrentUserMuted = false
                print("✅ [REACTIVE] Updated isCurrentUserMuted to: false")
            }
            
            print("✅ Participant \(participantId) unmuted successfully")
            return true
        }
        
        print("❌ Failed to update local state")
        return false
    }
    
    /**
     Toggles mute state for a specific participant.
     
     - Parameter participantId: The ID of the participant to toggle mute
     - Returns: True if successful, false otherwise
     */
    @MainActor func toggleMuteParticipant(_ participantId: Int64) -> Bool {
        print("🔄 [TOGGLE] Toggling mute for participant: \(participantId)")
        
        guard let space = selectedSpace ?? currentViewingSpace,
              let participant = space.speakers.first(where: { $0.id == participantId }) else {
            print("❌ [TOGGLE] Participant not found for ID: \(participantId)")
            return false
        }
        
        let isCurrentlyMuted = participant.isMuted ?? false
        print("🔄 [TOGGLE] Current mute state from participant: \(isCurrentlyMuted)")
        print("🔄 [TOGGLE] Participant details: ID=\(participant.id), Name=\(participant.name ?? "unknown"), PeerID=\(participant.peerID ?? "nil")")
        
        // Also check the actual HMS track state
        if let peerID = participant.peerID,
           let peer = hmsSDK.room?.peers.first(where: { $0.peerID == peerID }),
           let audioTrack = peer.audioTrack as? HMSAudioTrack {
            let hmsTrackMuted = audioTrack.isMute()
            print("🔄 [TOGGLE] HMS track mute state: \(hmsTrackMuted)")
            
            // Use HMS track state if it differs from local state
            if isCurrentlyMuted != hmsTrackMuted {
                print("🔄 [TOGGLE] State mismatch! Local: \(isCurrentlyMuted), HMS: \(hmsTrackMuted)")
                return hmsTrackMuted ? unmuteParticipant(participantId) : muteParticipant(participantId)
            }
        }
        
        let result = isCurrentlyMuted ? unmuteParticipant(participantId) : muteParticipant(participantId)
        print("🔄 [TOGGLE] Toggle result: \(result)")
        return result
    }
    
    /**
     Mutes all participants except the host.
     
     - Returns: True if successful, false otherwise
     */
   
    
    //
    
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
        
       
     
        initialPeerCount = (hmsSDK.room?.peers.count ?? 0)
        print("👥 Initial peers in room: \(initialPeerCount)")
        
        // Log added peers
        print("🔄 onPeerListUpdate - Added Peers: \(added.map { $0.peerID })")
        let newPeers = added.filter { peer in
        selectedSpace.speakers.contains(where: { $0.peerID == peer.peerID })
       
    }
        // Handle added peers
        for peer in added {
            print("\n=== 🎵 PROCESSING PEER AUDIO ===")
            print("Peer: \(peer.name)")
            print("Is Local: \(peer.isLocal)")
            print("Current ownTrack: \(ownTrack?.trackId ?? "nil")")
            print("Current otherTracks count: \(otherTracks.count)")
            print("Other Tracks IDs: \(otherTracks.map { $0.trackId })")
            
            // Handle profile image
            if let imageURLString = peer.parsedMetadata()?["profilePicture"],
               let imageURL = URL(string: imageURLString) {
                ImageCacheManagerForAuth.shared.downloadImage(from: imageURL, peerID: peer.peerID) { [weak self] image in
                    DispatchQueue.main.async {
                        self?.peerImages[peer.peerID] = image
                    }
                }
            }
            
            // Enhanced audio track handling
            if let audioTrack = peer.audioTrack as? HMSAudioTrack {
                print("🎵 Processing audio track for peer: \(peer.name)")
                print("Track ID: \(audioTrack.trackId)")
                addTrackIfNotExists(audioTrack, for: peer)
                print("After processing:")
                print("- ownTrack: \(ownTrack?.trackId ?? "nil")")
                print("- otherTracks count: \(otherTracks.count)")
                print("- otherTracks IDs: \(otherTracks.map { $0.trackId })")
                } else {
                print("⚠️ No audio track found for peer: \(peer.name)")
                // Try to get audio track from room
                if let roomAudioTrack = hmsSDK.room?.peers.first(where: { $0.peerID == peer.peerID })?.audioTrack as? HMSAudioTrack {
                    print("🎵 Found audio track in room for peer: \(peer.name)")
                    print("Track ID: \(roomAudioTrack.trackId)")
                    addTrackIfNotExists(roomAudioTrack, for: peer)
                    print("After processing room track:")
                    print("- ownTrack: \(ownTrack?.trackId ?? "nil")")
                    print("- otherTracks count: \(otherTracks.count)")
                    print("- otherTracks IDs: \(otherTracks.map { $0.trackId })")
                }
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
            print("➖ Processing removed peer: \(peer.name)")
            
            // Clean up profile image
            if let imageURLString = peer.parsedMetadata()?["profilePicture"],
               let imageURL = URL(string: imageURLString) {
                ImageCacheManagerForAuth.shared.removeImage(for: peer.peerID)
            }
            
            // Enhanced audio track cleanup
            if let audioTrack = peer.audioTrack as? HMSAudioTrack {
                print("🎵 Removing audio track for peer: \(peer.name)")
                if peer.isLocal {
                    print("🎵 Removing own track")
                    ownTrack = nil
                } else {
                    print("🎵 Removing from other tracks")
                    otherTracks.remove(audioTrack)
                }
            }
        }
        
        // Process metadata updates in batch
        if !added.isEmpty {
            print("\n🔄 Processing metadata for added peers")
            processPeerMetadata(added)
        }
        
        if !removed.isEmpty {
            print("🔄 Processing metadata for removed peers")
            removePeerMetadata(removed)
        }
        
        // Debug current tracks state
        print("\n=== 🎵 FINAL TRACKS STATE ===")
        print("Own Track: \(ownTrack != nil ? "Present" : "Missing")")
        print("Own Track ID: \(ownTrack?.trackId ?? "nil")")
        print("Other Tracks Count: \(otherTracks.count)")
        print("Other Tracks IDs: \(otherTracks.map { $0.trackId })")
        
        // Check recording state
        let totalPeers = hmsSDK.room?.peers.count ?? 0
        print("📊 Final peer count: \(totalPeers)")
        
        if totalPeers <= 1 && isRecording && isHost {
            print("🛑 Stopping recording - insufficient peers")
            stopCustomRecording()
        }
    }
    
    @MainActor public func on(join room: HMSRoom) {
        print("\n=== 🚪 ROOM JOIN EVENT ===")
        print("📍 Room ID: \(room.roomID ?? "unknown")")
        
        // 🔍 DEBUG: Log all available HMS room properties
        print("\n🔍 HMS Room Object Properties:")
        print("- Room ID: \(room.roomID ?? "nil")")
        print("- Room Name: \(room.name ?? "nil")")

        print("- HMS Room Object: \(room)")
        
         if let currentPeers = hmsSDK.room?.peers {
            print("\n👥 Current Peers in Room:")
            currentPeers.forEach { peer in
                print("- Name: \(peer.name)")
                print("  ID: \(peer.peerID)")
                print("  Is Local: \(peer.isLocal)")
                print("  Role: \(peer.role?.name ?? "unknown")")
                print("  Metadata: \(peer.metadata ?? "none")")
            }
        onPeerListUpdate(added: currentPeers, removed: [])
    }
        
     if isHost {
            print("\n👑 Host Information:")
            print("- Local Peer ID: \(hmsSDK.localPeer?.peerID ?? "unknown")")
            print("- Local Peer Name: \(hmsSDK.localPeer?.name ?? "unknown")")
            print("- Local Peer Role: \(hmsSDK.localPeer?.role?.name ?? "unknown")")
            print("- Local Peer Metadata: \(hmsSDK.localPeer?.metadata ?? "none")")
    }
    }
    

    
    @MainActor public func on(removedFromRoom notification: HMSRemovedFromRoomNotification) {
        print("\n=== 🚪 REMOVED FROM ROOM ===")
        print("📍 Reason: \(notification.reason)")
        print("👤 Removed by: \(notification.requestedBy?.name ?? "unknown")")
        print("🎭 Is Host: \(isHost)")
        
        // Update recording state when removed from room
        if isRecording && isHost {
            stopCustomRecording()
            isRecording = false
            print("🛑 Stream recording stopped - removed from room")
        } else if isRecording && !isHost {
            isRecording = false
            print("🛑 Stream recording stopped after removal")
        }
        
        // ✅ ADDED: Reset participant timer state when removed from room
        if !isHost && isRecordingActive {
            // ✅ FIXED: Check timer remaining to show appropriate message
            let wasTimerNearCompletion = recordingTimeRemaining <= 3 // Within 3 seconds of completion
            
            isRecordingActive = false
            recordingTimeRemaining = 0
            recordingStartTime = nil
            
            if wasTimerNearCompletion {
                print("⏹️ [VISITOR] Participant timer stopped near completion - showing topic completion toast")
                showToast("Topic completed! 🎉 7 min max per topic", isError: false)
            } else {
                print("⏹️ [VISITOR] Participant timer stopped early - room ended before completion")
                // ✅ ADDED: Show different message for early exit
                showToast("Conversation completed! Wanna speak on another topic?", isError: false)
            }
        }
        
        // Cleanup the tracks
        ownTrack = nil
        otherTracks = []
        
        // ✅ RESET: Clear active speaker state for new session
        activeSpeakerId = nil
 
        
        // Update the state to reflect that the user is no longer in the space
        isInSpace = false
        showSpaceView = false
        
        // Get current user ID for cleanup
        let currentUserId = tweetData.user?.id ?? 0
        print("\n👤 Current user ID: \(currentUserId)")
        
      
       
        
       if !isHost, let currentViewingSpace = currentViewingSpace {
            print("🔄 Cleaning up Ably channels after room ended...")
            
            let currentUser = tweetData.user
            guard let currentUser = currentUser else {
                print("❌ No current user found")
                return
            }
          let space = currentViewingSpace
                  
           
            // Get host's channel
            let hostChannelName = "user:\(currentViewingSpace.hostId)"
            let hostChannel = AblyService.shared.chatClient?.channels.get(hostChannelName)
            
            // Leave presence first
            print("👋 Leaving presence...")
            hostChannel?.presence.leave(["id": currentUser.id, "role": "participant"])
            print("✅ Left presence")
            
            // Publish space leave message to host's channel
            let spaceData: [String: Any] = [
                "id": currentUser.id,
                "spaceId": currentViewingSpace.id,
                "action": "leave",
                "role": currentViewingSpace.hostId == currentUser.id ? "host" : "participant",
                "channelType": "host"
            ]
            print("📤 Publishing space leave message...")
            print("📤 Message data: \(spaceData)")
             hostChannel?.publish("user_update", data: spaceData)
            print("✅ Space leave message published")
            
            // Clean up host channel subscriptions
            print("📡 Cleaning up host channel subscriptions: \(hostChannelName)")
            hostChannel?.unsubscribe() // First unsubscribe from messages
            hostChannel?.presence.unsubscribe() // Then unsubscribe from presence
            hostChannel?.detach { error in
                if let error = error {
                    print("❌ Failed to detach from host channel: \(error)")
                } else {
                    print("✅ Successfully detached from host channel")
                    
                    // After detaching from host's channel, reconnect to our own channel
                    Task {
                        do {
                            print("🔄 Reconnecting to own user channel...")
                            let ownChannel = try await AblyService.shared.connectToUserChannel(userId: currentUser.id)
                            print("✅ Reconnected to own user channel")
                            
                            // Ensure we're subscribed to our own channel
                            AblyService.shared.subscribeToUserChannel()
                            print("✅ Subscribed to own user channel messages")
                            
                            // Ensure host presence is set up
                            AblyService.shared.ensureHostPresence(userId: currentUser.id)
                            print("✅ Host presence ensured")
                        } catch {
                            print("❌ Failed to reconnect to own user channel: \(error)")
                        }
                    }
                }
            }

            if let userId = tweetData.user?.id {
                if let spaceIndex = self.spaces.firstIndex(where: { $0.id == space.id }) {
                    var updatedSpace = self.spaces[spaceIndex]
                    
                    // Remove user from speakers
                    updatedSpace.speakers.removeAll { $0.id == userId }
                    print("✅ User removed from speakers")
                    
                    // Update local state
                    self.spaces[spaceIndex].update(with: updatedSpace, preservingFieldsFrom: self.spaces[spaceIndex])
                
                 
                 self.currentViewingSpace?.update(with: updatedSpace, preservingFieldsFrom: self.currentViewingSpace!)
                }
            }
            
            self.isInSpace = false
            self.isSpaceMinimized = false
            self.showSpaceView = false
            self.initialPeerCount = 0
            self.isRecording = false
            self.activeSpeakerId = nil // Reset active speaker when leaving space
            
            // Reset the wasEndedByHost flag since user left manually
            self.wasEndedByHost = false
            
        }
        
        selectedSpace = nil
        
      
      
   
        showToast("Conversation completed successfully! 🎉", isError: false)
          
    }
    
    @MainActor public func on(peer: HMSPeer, update: HMSPeerUpdate) {
        // Do something here
        print("[HMSUpdate] on peer: \(peer.name), update: \(update.description)")
       
    }


    @MainActor private func handleRoomEnded() {
        print("\n=== 🏁 HANDLING ROOM ENDED ===")
        
        // Stop recording if active
        if isRecording {
            stopCustomRecording()
            isRecording = false
            print("🛑 Recording stopped - Room ended")
        }
        
        // ✅ ADDED: Reset participant timer state when room ends
        if !isHost && isRecordingActive {
            // ✅ FIXED: Check timer remaining to show appropriate message
            let wasTimerNearCompletion = recordingTimeRemaining <= 3 // Within 3 seconds of completion
            
            isRecordingActive = false
            recordingTimeRemaining = 0
            recordingStartTime = nil
            
            if wasTimerNearCompletion {
                print("⏹️ [VISITOR] Participant timer stopped near completion - showing topic completion toast")
                showToast("Topic completed! 🎉 7 min max per topic", isError: false)
            } else {
                print("⏹️ [VISITOR] Participant timer stopped early - room ended before completion")
                // ✅ ADDED: Show different message for early exit
                showToast("Conversation completed! Wanna speak on another topic?", isError: false)
            }
        }
        hmsSDK.leave()
        selectedSpace = nil
        ownTrack = nil
        otherTracks = []
        
        // ✅ RESET: Clear active speaker state for new session
        activeSpeakerId = nil
    
        
        // ✅ FIXED: Show appropriate message based on completion reason
       
            showToast("Conversation completed successfully! 🎉", isError: false)
         

        // ✅ CRITICAL: Clean up Ably channels when room ends (same as leaveSpace) - ONLY for non-hosts
        if !isHost, let currentViewingSpace = currentViewingSpace {
            print("🔄 Cleaning up Ably channels after room ended...")
            
            let currentUser = tweetData.user
            guard let currentUser = currentUser else {
                print("❌ No current user found")
                return
            }
             let space = currentViewingSpace
            
            // Get host's channel
            let hostChannelName = "user:\(currentViewingSpace.hostId)"
            let hostChannel = AblyService.shared.chatClient?.channels.get(hostChannelName)
            
            // Leave presence first
            print("👋 Leaving presence...")
            hostChannel?.presence.leave(["id": currentUser.id, "role": "participant"])
            print("✅ Left presence")
            
            // Publish space leave message to host's channel
            let spaceData: [String: Any] = [
                "id": currentUser.id,
                "spaceId": currentViewingSpace.id,
                "action": "leave",
                "role": currentViewingSpace.hostId == currentUser.id ? "host" : "participant",
                "channelType": "host"
            ]
            print("📤 Publishing space leave message...")
            print("📤 Message data: \(spaceData)")
             hostChannel?.publish("user_update", data: spaceData)
            print("✅ Space leave message published")
            
            // Clean up host channel subscriptions
            print("📡 Cleaning up host channel subscriptions: \(hostChannelName)")
            hostChannel?.unsubscribe() // First unsubscribe from messages
            hostChannel?.presence.unsubscribe() // Then unsubscribe from presence
            hostChannel?.detach { error in
                if let error = error {
                    print("❌ Failed to detach from host channel: \(error)")
                } else {
                    print("✅ Successfully detached from host channel")
                    
                    // After detaching from host's channel, reconnect to our own channel
                    Task {
                        do {
                            print("🔄 Reconnecting to own user channel...")
                            let ownChannel = try await AblyService.shared.connectToUserChannel(userId: currentUser.id)
                            print("✅ Reconnected to own user channel")
                            
                            // Ensure we're subscribed to our own channel
                            AblyService.shared.subscribeToUserChannel()
                            print("✅ Subscribed to own user channel messages")
                            
                            // Ensure host presence is set up
                            AblyService.shared.ensureHostPresence(userId: currentUser.id)
                            print("✅ Host presence ensured")
                        } catch {
                            print("❌ Failed to reconnect to own user channel: \(error)")
                        }
                    }
                }
            }

            if let userId = tweetData.user?.id {
                if let spaceIndex = self.spaces.firstIndex(where: { $0.id == space.id }) {
                    var updatedSpace = self.spaces[spaceIndex]
                    
                    // Remove user from speakers
                    updatedSpace.speakers.removeAll { $0.id == userId }
                    print("✅ User removed from speakers")
                    
                    // Update local state
                    self.spaces[spaceIndex].update(with: updatedSpace, preservingFieldsFrom: self.spaces[spaceIndex])
               
                 self.currentViewingSpace?.update(with: updatedSpace, preservingFieldsFrom: self.currentViewingSpace!)
               
               
                }
            }
            
            self.isInSpace = false
            self.isSpaceMinimized = false
            self.showSpaceView = false
            self.initialPeerCount = 0
            self.isRecording = false
            self.activeSpeakerId = nil // Reset active speaker when leaving space
            
            // Reset the wasEndedByHost flag since user left manually
            self.wasEndedByHost = false
            
        }

        if isHost, let  selectedSpace = selectedSpace {
 guard let spaceIndex = getSpaceIndex(for: selectedSpace.id) else {
            print("❌ Host's space not found")
            setInfoMessage(text: "Could not find your space", type: .error)
            return
        }
          guard let currentUser = tweetData.user else {
            print("❌ No user found")
            return
        }

        print("✅ Found selected space")
        
        // Remove non-moderator speakers from the space
        var updatedSpace = spaces[spaceIndex]
        updatedSpace.speakers.removeAll { speaker in
            let isModerator = speaker.id == currentUser.id
            if !isModerator {
                print("🗑️ Removing non-moderator speaker: \(speaker.name ?? "unknown")")
            }
            return !isModerator
        }
        
        // Update the space
        spaces[spaceIndex].update(with: updatedSpace, preservingFieldsFrom: spaces[spaceIndex])
        // ✅ CACHE: No manual update needed - didSet will trigger automatically
        
        // ✅ CRITICAL: Update queue cache when speakers change
        self.queueParticipantIds[selectedSpace.id] = Set(updatedSpace.queue.participants.map { $0.id })
        
       
        
        
        self.initialPeerCount = 0
        self.isRecording = false
        self.currentSpaceSessionStartTime = nil
        self.activeSpeakerId = nil // Reset active speaker when ending space
        self.wasEndedByHost = false
        self.currentSpaceSessionStartTime = nil
        
        }

        // 🔄 Sync currentViewingSpace & spaces array to reflect that the room is over
        
    }

       @MainActor public func on(track: HMSTrack, update: HMSTrackUpdate, for peer: HMSPeer) {
        print("[HMSUpdate] on track: \(track.trackId), update: \(update.description), peer: \(peer.name)")
    
        switch update {
        case .trackAdded:
        print("➕ Track added for peer: \(peer.name)")
            if let audioTrack = track as? HMSAudioTrack {
            print("🎵 Audio track added: \(audioTrack.trackId)")
            addTrackIfNotExists(audioTrack, for: peer)
        }
        
        case .trackRemoved:
        print("➖ Track removed for peer: \(peer.name)")
            if let audioTrack = track as? HMSAudioTrack {
            print("🎵 Audio track removed: \(audioTrack.trackId)")
                if peer.isLocal {
                    ownTrack = nil
                } else {
                    otherTracks.remove(audioTrack)
                }
            }
        
    case .trackMuted:
        print("🔇 Track muted for peer: \(peer.name)")
        // ✅ ADDED: Update local mute state when track is muted
        updateParticipantMuteState(for: peer, isMuted: true)
        
    case .trackUnmuted:
        print("🔊 Track unmuted for peer: \(peer.name)")
        // ✅ ADDED: Update local mute state when track is unmuted
        updateParticipantMuteState(for: peer, isMuted: false)
        
        default:
            break
        }
    
    // Update UI if needed
    objectWillChange.send()
    }
    
    /**
     Updates the mute state of a participant when track mute state changes.
     
     - Parameter peer: The HMS peer whose track state changed
     - Parameter isMuted: Whether the track is now muted
     */
    @MainActor private func updateParticipantMuteState(for peer: HMSPeer, isMuted: Bool) {
        guard let space = selectedSpace ?? currentViewingSpace,
              let spaceIndex = spaces.firstIndex(where: { $0.id == space.id }) else {
            return
        }
        
        // Find participant by peerID
        guard let participantIndex = space.speakers.firstIndex(where: { $0.peerID == peer.peerID }) else {
            print("⚠️ Participant not found for peer: \(peer.peerID)")
            return
        }
        
        // Update mute state
        var updatedSpace = spaces[spaceIndex]
        updatedSpace.speakers[participantIndex].isMuted = isMuted
        spaces[spaceIndex] = updatedSpace
        
        // Update active space references
        if selectedSpace?.id == space.id {
            selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: selectedSpace!)
        }
        if currentViewingSpace?.id == space.id {
            currentViewingSpace?.update(with: updatedSpace, preservingFieldsFrom: currentViewingSpace!)
        }
        
        // ✅ ADDED: Update direct reactive property for current user
        if let currentUserId = tweetData.user?.id,
           let participant = space.speakers.first(where: { $0.id == currentUserId }),
           participant.peerID == peer.peerID {
            isCurrentUserMuted = isMuted
            print("✅ [REACTIVE] Updated isCurrentUserMuted to: \(isMuted)")
        }
        
        print("✅ Updated mute state for participant \(peer.name): \(isMuted ? "muted" : "unmuted")")
    }
    
    @MainActor private func processPeerMetadata(_ peers: [HMSPeer]) {
        print("\n=== 🔄 BATCH PROCESSING PEER METADATA ===")
        print("📊 Processing \(peers.count) peers")

        guard let roomID = hmsSDK.room?.roomID else {
            print("❌ Room ID is missing")
            return
        }
        
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

        // Store the host if they exist in current speakers
        let host = updatedSpace.speakers.first { $0.id == updatedSpace.hostId }
        print("\n👑 Host check:")
        print("- Host ID: \(updatedSpace.hostId ?? 0)")
        print("- Host found in speakers: \(host != nil)")

        // Create a temporary array to store updated speakers
        var updatedSpeakers = updatedSpace.speakers

        // Process all peers in the room, not just the newly added ones
        let allPeers = hmsSDK.room?.peers ?? []
        print("\n👥 Processing all peers in room: \(allPeers.count)")
        
        for peer in allPeers {
            print("\n👤 Processing peer: \(peer.name)")
            print("- ID: \(peer.peerID)")
            print("- Is Local: \(peer.isLocal)")
            print("- Role: \(peer.role?.name ?? "unknown")")
            print("- Raw Metadata: \(peer.metadata ?? "none")")
            
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
            print("- User ID: \(parsedMetadata["id"] ?? "nil")")
            print("- Name: \(parsedMetadata["name"] ?? "nil")")
            print("- Username: \(parsedMetadata["username"] ?? "nil")")
            print("- Image URL: \(parsedMetadata["image_url"] ?? "nil")")
            print("- Topic: \(parsedMetadata["topic"] ?? "nil")")
            print("- Role: \(parsedMetadata["role"] ?? "nil")")
            print("- Peer ID from metadata: \(parsedMetadata["peerID"] ?? "nil")")
            print("- Peer ID from HMS peer: \(peer.peerID)")
            
            // ✅ ADDED: Check for mute state changes and sync
            if let existingParticipant = updatedSpeakers.first(where: { $0.peerID == peer.peerID }) {
                let currentMuteState = existingParticipant.isMuted ?? false
                let newMuteState = peer.audioTrack?.isMute() ?? false
                
                if currentMuteState != newMuteState {
                    print("🔇 Mute state changed for \(peer.name): \(currentMuteState) → \(newMuteState)")
                    updateParticipantMuteState(for: peer, isMuted: newMuteState)
                }
            }
            
            // Update topic if present
            if let topic = parsedMetadata["topic"] {
                print("\n🎯 Found topic in metadata: \(topic)")
                currentTopic = topic
                // ✅ ADDED: Also update the space's topics field so it gets preserved in update
                updatedSpace.topics = [topic]
                print("🎯 Updated space topics to: \(updatedSpace.topics ?? [])")
            }

            // ✅ FIXED: Extract location data from metadata (now properly handled as JSON string)
            var locationData: LocationData? = nil
            if let locationDataString = parsedMetadata["locationData"] {
                // Try to decode location data from JSON string
                if let locationJsonData = locationDataString.data(using: .utf8),
                   let locationDict = try? JSONSerialization.jsonObject(with: locationJsonData) as? [String: Any] {
                    // Create LocationData from dictionary - handle mixed types properly
                    locationData = LocationData(
                        name: locationDict["name"] as? String ?? "",
                        lat: (locationDict["lat"] as? NSNumber)?.doubleValue ??
                             (locationDict["lat"] as? Double) ?? 0.0,
                        lng: (locationDict["lng"] as? NSNumber)?.doubleValue ??
                             (locationDict["lng"] as? Double) ?? 0.0,
                        address: locationDict["address"] as? String ?? "",
                        city: locationDict["city"] as? String ?? "",
                        state: locationDict["state"] as? String ?? "",
                        country: locationDict["country"] as? String ?? ""
                    )
                    print("📍 [processPeerMetadata] Extracted location data: \(locationData?.city ?? "unknown")")
                } else {
                    print("❌ [processPeerMetadata] Failed to parse location data JSON")
                }
            }
            
            // Create participant
            let participant = SpaceParticipant(
                id: Int64(parsedMetadata["id"] ?? "0") ?? 0,
                name: parsedMetadata["name"] ?? "Guest",
                username: parsedMetadata["username"] ?? "",
                imageURL: parsedMetadata["image_url"] ?? "",
                peerID: peer.peerID,
                topic: parsedMetadata["topic"],
                isMuted: peer.audioTrack?.isMute() ?? false,  // ✅ ADDED: Initialize with current mute state
                locationData: locationData  // ✅ ADDED: Include location data
            )
            
            print("\n🎭 Created participant:")
            print("- ID: \(participant.id)")
            print("- Name: \(participant.name)")
            print("- Peer ID: \(participant.peerID ?? "nil")")

            let roleName = peer.role?.name.lowercased() ?? "listener"
            print("🎭 Role: \(roleName)")

            // Handle host first
            if participant.id == updatedSpace.hostId {
                print("👑 Processing host participant")
                if let index = updatedSpeakers.firstIndex(where: { $0.id == participant.id }) {
                    print("🔄 Updating existing host speaker with new peerID")
                    updatedSpeakers[index] = participant
                } else {
                    print("➕ Adding host to speakers")
                    updatedSpeakers.append(participant)
                }
            }

            // Handle other speakers
            if roleName == "speaker" || roleName == "moderator" {
               
                if let index = updatedSpeakers.firstIndex(where: { $0.id == participant.id }) {
                    print("🔄 Updating existing speaker with new peerID")
                    updatedSpeakers[index] = participant
                }
                else if let participantPeerID = participant.peerID, !updatedSpeakers.contains(where: { $0.peerID == participantPeerID }) {
                    // ✅ ADDED: Only append if peerID is not nil and not already present
                    print("➕ Adding new speaker with peerID: \(participantPeerID)")
                    updatedSpeakers.append(participant)
                } else if participant.peerID == nil {
                    // ✅ ADDED: If peerID is nil, find and replace existing speaker with same ID
                    if let existingIndex = updatedSpeakers.firstIndex(where: { $0.id == participant.id }) {
                        print("🔄 Replacing existing speaker (ID: \(participant.id)) with nil peerID")
                        updatedSpeakers[existingIndex] = participant
                    } else {
                        print("➕ Adding new speaker with nil peerID (ID: \(participant.id))")
                        updatedSpeakers.append(participant)
                    }
                }
            } else {
                print("➖ Removing from speakers (not a speaker/moderator)")
                updatedSpeakers.removeAll { $0.peerID == participant.peerID }
            }
        }

        // Update the space with the new speakers array
        updatedSpace.speakers = updatedSpeakers
        
        print("\n📊 Speakers after update:")
        print("- Total speakers: \(updatedSpeakers.count)")
        updatedSpeakers.forEach { speaker in
            print("- ID: \(speaker.id), Name: \(speaker.name), PeerID: \(speaker.peerID ?? "nil"), Is Host: \(speaker.id == updatedSpace.hostId)")
        }
        
        // Update the active space if needed
        if let activeSpace = activeSpace {
            if selectedSpace?.id == updatedSpace.id {
                selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: selectedSpace!)
                print("✅ Updated selectedSpace speakers: \(selectedSpace?.speakers.count ?? 0)")
                
                // Ensure spaces array is updated with the latest selectedSpace data
                if let selectedSpaceIndex = spaces.firstIndex(where: { $0.id == selectedSpace?.id }) {
                    spaces[selectedSpaceIndex] = selectedSpace!
                    print("✅ Synced selectedSpace back to spaces array")
                }
            }
            if currentViewingSpace?.id == updatedSpace.id {
                currentViewingSpace?.update(with: updatedSpace, preservingFieldsFrom: currentViewingSpace!)
                print("✅ Updated currentViewingSpace speakers: \(currentViewingSpace?.speakers.count ?? 0)")
                
                // Ensure spaces array is updated with the latest currentViewingSpace data
                if let viewingSpaceIndex = spaces.firstIndex(where: { $0.id == currentViewingSpace?.id }) {
                    spaces[viewingSpaceIndex] = currentViewingSpace!
                    print("✅ Synced currentViewingSpace back to spaces array")
                }
            }
        }
        
        let totalPeers = hmsSDK.room?.peers.count ?? 0
        print("\n📊 Final State:")
        print("- Total peers: \(totalPeers)")
        print("- Speakers: \(updatedSpace.speakers.count)")
        print("- Speaker IDs: \(updatedSpace.speakers.map { $0.id })")
        print("- Speaker PeerIDs: \(updatedSpace.speakers.compactMap { $0.peerID })")
        
        if totalPeers > 1 && !isRecording && isHost && !currentTopic.isEmpty {
            print("🎙️ Starting recording")
            startCustomRecording()
            self.isInSpace = true
            self.showQueueView = false
            self.isSpaceMinimized = false
        }
        
        // ✅ ADDED: Start timer for participants when host starts recording
        if totalPeers > 1 && !isRecordingActive && !isHost && isInSpace  {
            print("🎙️ [VISITOR] Host started recording - starting participant timer")
            startTimerForVisitor()
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
        print("- Host ID: \(space.hostId ?? 0)")
       
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
            print("- Peer ID: \(peer.peerID)")
            
            // Remove from speakers array
            if updatedSpace.speakers.contains(where: { $0.peerID == peer.peerID }) {
                print("- Removing from speakers: \(peer.name)")
                updatedSpace.speakers.removeAll { $0.peerID == peer.peerID }
            } else {
                print("✅ Preserving host speaker")
            }
        }
        
        // Update the active space (either selectedSpace or currentViewingSpace)
        if let activeSpace = activeSpace {
            if selectedSpace?.id == updatedSpace.id {
                selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: selectedSpace!)
                print("✅ Updated selectedSpace speakers: \(selectedSpace?.speakers.count ?? 0)")
                
                // Ensure spaces array is updated with the latest selectedSpace data
                if let selectedSpaceIndex = spaces.firstIndex(where: { $0.id == selectedSpace?.id }) {
                    spaces[selectedSpaceIndex] = selectedSpace!
                    print("✅ Synced selectedSpace back to spaces array")
                }
            }
            if currentViewingSpace?.id == updatedSpace.id {
                currentViewingSpace?.update(with: updatedSpace, preservingFieldsFrom: currentViewingSpace!)
                print("✅ Updated currentViewingSpace speakers: \(currentViewingSpace?.speakers.count ?? 0)")
                
                // Ensure spaces array is updated with the latest currentViewingSpace data
                if let viewingSpaceIndex = spaces.firstIndex(where: { $0.id == currentViewingSpace?.id }) {
                    spaces[viewingSpaceIndex] = currentViewingSpace!
                    print("✅ Synced currentViewingSpace back to spaces array")
                }
            }
        }
        
        // Log final state
        print("\n📊 After batch removePeerMetadata:")
        print("- Speakers: \(updatedSpace.speakers.map { $0.id })")
        print("- Host ID: \(updatedSpace.hostId ?? 0)")
        
        let totalPeers = (hmsSDK.room?.peers.count ?? 0)
        print("👥 Total peers remaining in room: \(totalPeers)")
        
        // Check recording state once after all removals
        if totalPeers <= 1 && isRecording && isHost {
            print("🎙️ Stop recording - \(totalPeers) speakers in the space")
            stopCustomRecording()
        }
        
        // ✅ ADDED: Stop participant timers when room ends or participants leave
        if !isHost && isRecordingActive {
            // ✅ FIXED: Check timer remaining to show appropriate message
            let wasTimerNearCompletion = recordingTimeRemaining <= 3 // Within 3 seconds of completion
            
            print("⏹️ [VISITOR] Room ended or participants left - stopping participant timer")
            stopTimerForVisitor()
            
            if wasTimerNearCompletion {
                print("⏹️ [VISITOR] Participant timer stopped near completion - showing topic completion toast")
                showToast("Topic completed! 🎉 7 min max per topic", isError: false)
            } else {
                // ✅ ADDED: Show different message for early exit
                showToast("Conversation completed! Wanna speak on another topic?", isError: false)
            }
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
        print("\n=== 🔊 ACTIVE SPEAKERS UPDATE ===")
        print("Total active speakers: \(speakers.count)")
        
        DispatchQueue.main.async {
            // Log current speaker IDs
            print("🔄 Current speaker IDs: \(self.speakerIds)")
            
            // Process each active speaker
            for speaker in speakers {
                print("\n👤 Processing active speaker:")
                print("- Name: \(speaker.peer.name)")
                print("- Peer ID: \(speaker.peer.peerID)")
                print("- Audio Level: \(speaker.level)")
                print("- Raw Metadata: \(speaker.peer.metadata ?? "none")")
                
                // Parse metadata
                if let metadata = speaker.peer.parsedMetadata() {
                    print("📝 Parsed Metadata:")
                    print("- User ID: \(metadata["id"] ?? "nil")")
                    print("- Name: \(metadata["name"] ?? "nil")")
                    print("- Username: \(metadata["username"] ?? "nil")")
                }
            }
            
            if let firstSpeakingPeer = speakers.first {
                let audioLevel = firstSpeakingPeer.level
                // Set the current active speaker ID (metadata is user ID)
                self.activeSpeakerId = firstSpeakingPeer.peer.peerID
                print("🔊 Dominant Speaker: \(firstSpeakingPeer.peer.name), Level: \(audioLevel)")
                
                // Update speakerIds set based on current active speakers
                withAnimation {
                    self.speakerIds = Set(speakers.compactMap { speaker in
                        if let metadata = speaker.peer.metadata,
                           let data = metadata.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                           let userId = Int64(json["id"] ?? "0") {
                            print("✅ Added speaker ID: \(userId) to active speakers")
                            return userId
                        }
                        print("⚠️ Could not parse speaker ID from metadata")
                        return nil
                    })
                }
                
                print("\n📊 Final Active Speakers State:")
                print("- Active Speaker ID: \(self.activeSpeakerId ?? "none")")
                print("- Active Speaker IDs: \(self.speakerIds)")
            } else {
                // No active speakers, reset activeSpeakerId
                self.activeSpeakerId = nil
                print("ℹ️ No active speakers")
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
            
            // ✅ ADDED: Reset participant timer state after reconnection if insufficient peers
            if currentPeers.count < 2 && isRecordingActive && !isHost {
                // ✅ FIXED: Check timer remaining to show appropriate message
                let wasTimerNearCompletion = recordingTimeRemaining <= 3 // Within 3 seconds of completion
                
                print("⏹️ [VISITOR] Stopping participant timer after reconnection - insufficient peers")
                isRecordingActive = false
                recordingTimeRemaining = 0
                recordingStartTime = nil
                
                if wasTimerNearCompletion {
                    print("⏹️ [VISITOR] Participant timer stopped near completion after reconnection - showing topic completion toast")
                    showToast("Topic completed! 🎉 7 min max per topic", isError: false)
                } else {
                    // ✅ ADDED: Show different message for early exit
                    showToast("Conversation completed! Wanna speak on another topic?", isError: false)
                }
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

    public func on(room: HMSRoom, update: HMSRoomUpdate) {
        print("[HMSUpdate] on room: \(room.roomID ?? "unknown"), update: \(update.description)")

        switch update {
        case .serverRecordingStateUpdated:
            print("🎥 Server recording state updated")
            // Handle server recording state update
        case .rtmpStreamingStateUpdated:
            print("📺 RTMP streaming state updated")
            // Handle RTMP streaming state update
        case .browserRecordingStateUpdated:
            print("🌐 Browser recording state updated")
            // Handle browser recording state update
        case .hlsRecordingStateUpdated:
            print("🎬 HLS recording state updated")
            // Handle HLS recording state update
        case .hlsStreamingStateUpdated:
            print("📡 HLS streaming state updated")
            // Handle HLS streaming state update
    
        @unknown default:
            print("⚠️ Unknown room update type: \(update)")
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
            // ✅ RESET: Clear active speaker state before handling room end
            activeSpeakerId = nil
            
            // ✅ ADDED: Stop participant timers when streaming stops
            if !isHost && isRecordingActive {
                // ✅ FIXED: Check timer remaining to show appropriate message
                let wasTimerNearCompletion = recordingTimeRemaining <= 3 // Within 3 seconds of completion
                
                print("⏹️ [VISITOR] Streaming stopped - stopping participant timer")
                stopTimerForVisitor()
                
                if wasTimerNearCompletion {
                    print("⏹️ [VISITOR] Participant timer stopped near completion - showing topic completion toast")
                    showToast("Topic completed! 🎉 7 min max per topic", isError: false)
                } else {
                    // ✅ ADDED: Show different message for early exit
                    showToast("Conversation completed! Wanna speak on another topic?", isError: false)
                }
            }
     
            handleRoomEnded()
        case .failed:
            print("❌ Streaming failed")
            // ✅ RESET: Clear active speaker state before handling room end
            activeSpeakerId = nil
            
            // ✅ ADDED: Stop participant timers when streaming fails
            if !isHost && isRecordingActive {
                // ✅ FIXED: Check timer remaining to show appropriate message
                let wasTimerNearCompletion = recordingTimeRemaining <= 3 // Within 3 seconds of completion
                
                print("⏹️ [VISITOR] Streaming failed - stopping participant timer")
                stopTimerForVisitor()
                
                if wasTimerNearCompletion {
                    print("⏹️ [VISITOR] Participant timer stopped near completion - showing topic completion toast")
                    showToast("Topic completed! 🎉 7 min max per topic", isError: false)
                } else {
                    // ✅ ADDED: Show different message for early exit
                    showToast("Conversation completed! Wanna speak on another topic?", isError: false)
                }
            }
        
            handleRoomEnded()
        @unknown default:
            print("⚠️ Unknown streaming state")
        }
    }

    @MainActor private func startCustomRecording() {
           guard isHost else {
               print("❌ Only host can start recording")
               return
           }
           
           guard !isRecording else {
               print("⚠️ Recording already in progress, skipping duplicate call")
               return
           }
           
           guard let roomId = hmsSDK.room?.roomID,
                 let space = selectedSpace else {
               print("❌ Recording failed to start - Missing roomId or space")
               return
           }
           
           // Set recording state immediately to prevent duplicate calls
           isRecording = true
           print("🎙️ Recording state set to true - preventing duplicate calls")
           
           // Reset and start timer
           recordingTimeRemaining = 420 // 420 seconds (7 minutes)
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
                       // ✅ FIXED: Set flag to indicate timer completion
                       self.isTimerCompleted = true
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
                 //  let managementToken = try generateManagmentToken()
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
                   
                   print("\n🎙️ INDIVIDUAL TRACK RECORDING ENABLED")
                   print("🎯 Using session ID from Active Rooms API for individual track recording")
                   print("ℹ️ Individual tracks will be recorded automatically when participants join/leave")
                
                 
                   // 🔍 GET SESSION ID VIA ACTIVE ROOMS API WITH RETRY LOGIC
                   print("🌐 Fetching session ID via Active Rooms API with retry logic...")
                   let sessionId = try await fetchValidSessionId(roomId: roomId)
                   print("✅ Retrieved valid session ID from Active Rooms API: \(sessionId)")
                   
                   // Register sessions for both host and participants
                   var sessionMappings: [SessionMapping] = []
                   
                   // Add host session
                   if let hostPeer = hmsSDK.localPeer {
                       sessionMappings.append(SessionMapping(
                           roomId: roomId,
                           sessionId: sessionId,  // ✅ Using session ID from Active Rooms API
                           peerId: hostPeer.peerID,
                           userId: String(space.hostId ?? 0)
                       ))
                       print("👑 HOST: User \(space.hostId ?? 0) → Peer \(hostPeer.peerID)")
                   }
                   
                   // Add participant sessions
                   for participant in participantsToRecord {
                       if let peer = hmsSDK.room?.peers.first(where: { peer in
                           if let metadata = peer.parsedMetadata(),
                              let peerUserId = Int64(metadata["id"] ?? "0") {
                               return peerUserId == participant.id
                           }
                           return false
                       }) {
                           sessionMappings.append(SessionMapping(
                               roomId: roomId,
                               sessionId: sessionId,  // ✅ Using session ID from Active Rooms API
                               peerId: peer.peerID,
                               userId: String(participant.id)
                           ))
                           print("👤 PARTICIPANT: User \(participant.id) → Peer \(peer.peerID)")
                       } else {
                           print("❌ No peer found for User \(participant.id)")
                       }
                   }
                   
                   // Register all sessions
                   if !sessionMappings.isEmpty {
                    print ("🔑 Registering sessions \(sessionMappings)")
                       try await registerSessions(sessionMappings)
                
                   }
                   
                   for participant in participantsToRecord {
                       print("\n🎯 Processing participant: \(participant.name)")
                       
                       // ✅ ADDED: Find location data from the participant
                       let participantLocationData = participant.locationData
                       if let locationData = participantLocationData {
                           print("📍 [startCustomRecording] Found location data for participant \(participant.name ?? "unknown"):")
                           print("  - Name: \(locationData.name)")
                           print("  - City: \(locationData.city)")
                           print("  - State: \(locationData.state)")
                           print("  - Country: \(locationData.country)")
                           print("  - Address: \(locationData.address)")
                           print("  - Latitude: \(locationData.lat)")
                           print("  - Longitude: \(locationData.lng)")
                       } else {
                           print("📍 [startCustomRecording] No location data found for participant \(participant.name ?? "unknown")")
                       }

                        let audioTweet = try await createAudioTweet(
                    roomId: roomId,  // ✅ Using original room ID
                    sessionId: sessionId,  // ✅ Using session ID from Active Rooms API
                    visitorUsername: participant.name ?? "",
                    audioContent: "",  // ✅ Using session ID as audio content
                    duration: "420", // 420 seconds (7 minutes)
                    size: "0", // Size will be updated when recording is complete
                    tag: currentTopic,
                    visibility: PostConfig.Visibility.public,
                    locationData: participantLocationData // ✅ ADDED: Pass participant's location data
                )
                     
                       self.isRecording = true
                   }
                   
                   print("🎯 Session ID from Active Rooms API: \(sessionId)")
                   
                   
               } catch {
                   print("\n❌ ERROR STARTING RECORDING")
                   print("Error: \(error)")
                   self.isRecording = false  // Ensure recording state is updated on error
               
               }
           }
       }
    
    // MARK: - Visitor Timer Methods (Same Logic as Host but for Participants)
    
    /**
     Starts the timer for visitors/participants when the host starts recording.
     This method has the exact same timer logic as startCustomRecording but is only for participants.
     */
    @MainActor private func startTimerForVisitor() {
        // ✅ GUARD: Only participants can call this method
        guard !isHost else {
            print("❌ Host cannot call startTimerForVisitor - use startCustomRecording instead")
            return
        }
        
        print("🎙️ [VISITOR] Starting timer for participant")
        
        // ✅ SAME LOGIC: Exact same timer setup as startCustomRecording
        // Reset and start timer
        recordingTimeRemaining = 420 // 420 seconds (7 minutes)
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
                    
                    // Start fading out audio when 30 seconds remaining (same as host)
                    /* if self.recordingTimeRemaining <= 30 {
                        let fadePercentage = self.recordingTimeRemaining / 30.0
                        self.adjustAudioLevels(fadePercentage: fadePercentage)
                    }*/
                } else {
                    // Time's up - stop timer (but don't stop recording since participant can't control that)
                    timer.invalidate()
                    print("⏰ [VISITOR] Timer completed - recording continues under host control")
                    self.isRecordingActive = false
                    self.recordingTimeRemaining = 0
                }
            }
        }
        
        print("✅ [VISITOR] Timer started successfully for participant")
    }
    
    /**
     Stops the timer for visitors/participants when the host stops recording.
     This method has the exact same timer cleanup logic as stopCustomRecording but is only for participants.
     */
    @MainActor private func stopTimerForVisitor() {
        // ✅ GUARD: Only participants can call this method
        guard !isHost else {
            print("❌ Host cannot call stopTimerForVisitor - use stopCustomRecording instead")
            return
        }
        
        print("⏹️ [VISITOR] Stopping timer for participant")
        
        // ✅ SAME LOGIC: Exact same timer cleanup as stopCustomRecording
        // Cleanup timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecordingActive = false
        recordingStartTime = nil
        
        print("✅ [VISITOR] Timer stopped successfully for participant")
    }
    
    // Handle recording state updates
    
    // MARK: - Active Rooms API with Session Validation
    private func fetchSessionIdFromActiveRooms(roomId: String, expectedStartTime: Date? = nil) async throws -> String {
        print("\n=== 🌐 FETCHING SESSION ID FROM ACTIVE ROOMS API ===")
        print("📍 Room ID: \(roomId)")
        
        let managementToken = try generateManagmentToken()
        print("🔑 Generated management token for API call")
        
        let url = URL(string: "https://api.100ms.live/v2/active-rooms/\(roomId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(managementToken)", forHTTPHeaderField: "Authorization")
        
        print("🌐 Making request to: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw NSError(domain: "ActiveRooms", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        print("📡 Response status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorJson = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let message = (errorJson["message"] as? String) ?? "Failed to fetch active room"
            print("❌ HTTP Error: \(httpResponse.statusCode) - \(message)")
            throw NSError(domain: "ActiveRooms", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let session = json["session"] as? [String: Any],
              let sessionId = session["id"] as? String else {
            print("❌ Session ID not found in response")
            throw NSError(domain: "ActiveRooms", code: 404, userInfo: [NSLocalizedDescriptionKey: "Session ID not found in response"])
        }
        
        print("✅ Found session ID: \(sessionId)")
        
        try validateSessionTiming(session: session, expectedStartTime: expectedStartTime)
        
        return sessionId
    }
    
    private func validateSessionTiming(session: [String: Any], expectedStartTime: Date?) throws {
        guard let createdAtString = session["created_at"] as? String,
              let sessionDate = ISO8601DateFormatter().date(from: createdAtString) else {
            print("⚠️ Could not parse session creation date, skipping validation")
            return
        }
        
        let maxAge: TimeInterval = expectedStartTime != nil ? 60 : 300 // 1 min if expected time provided, else 5 min
        
        // Check if session is too old
        let sessionAge = Date().timeIntervalSince(sessionDate)
        guard sessionAge <= maxAge else {
            throw NSError(domain: "SessionMismatch", code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Session too old - created \(sessionAge) seconds ago"])
        }
        
        // If expected start time provided, check if session is newer than expected
        if let expectedStartTime = expectedStartTime, sessionDate < expectedStartTime {
            throw NSError(domain: "SessionMismatch", code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Session created before expected start time"])
        }
        
        print("✅ Session validation passed - session is recent enough")
    }
    
    private func fetchValidSessionId(roomId: String, maxRetries: Int = 3, retryDelay: TimeInterval = 1.0) async throws -> String {
        let expectedStartTime = currentSpaceSessionStartTime
        
        for attempt in 1...maxRetries {
            do {
                let sessionId = try await fetchSessionIdFromActiveRooms(roomId: roomId, expectedStartTime: expectedStartTime)
                return sessionId
            } catch let error as NSError where error.domain == "SessionMismatch" && error.code == 409 && attempt < maxRetries {
                let jitterDelay = retryDelay * Double.random(in: 0.8...1.2)
                try await Task.sleep(nanoseconds: UInt64(jitterDelay * 1_000_000_000))
            } catch {
                throw error
            }
        }
        
        throw NSError(domain: "SessionMismatch", code: 500,
                     userInfo: [NSLocalizedDescriptionKey: "Failed after \(maxRetries) attempts"])
    }
    
    
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

          guard let spaceId = selectedSpace?.id else {
              print("❌ Missing spaceId")
              isRecording = false
              return
          }
          
          Task {
              print("\n=== ⏹️ STOPPING INDIVIDUAL TRACK RECORDING ===")
              print("📍 Room ID: \(roomId)")
              print("📍 Space ID: \(spaceId)")
              print("🎯 Composite recording API commented out - individual track recording should auto-stop")
            
              do {
               /*   let managementToken = try generateManagmentToken()
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
                  */
                  
                 await self.endSpace(with: spaceId)
                  self.isRecording = false
                  print("✅ Recording stopped successfully")
                  
                  // ✅ ADDED: Stop participant timers when host stops recording
                  // Note: In a real implementation, you'd broadcast this to all participants
                  // For now, we'll handle it in the peer update methods
                  
                  // ✅ REMOVED: Toast logic moved to endSpace() method to handle both cases properly
                  
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

    // Add this helper method at the top of the class
    private func addTrackIfNotExists(_ track: HMSAudioTrack, for peer: HMSPeer) {
        print("\n=== 🎵 Adding Track ===")
        print("Peer: \(peer.name)")
        print("Track ID: \(track.trackId)")
        
        if peer.isLocal {
            if ownTrack?.trackId != track.trackId {
                print("🎵 Setting own track")
                ownTrack = track
            } else {
                print("ℹ️ Own track already set")
            }
        } else {
            // Check if track already exists in otherTracks
            if !otherTracks.contains(where: { $0.trackId == track.trackId }) {
                print("🎵 Adding new track to otherTracks")
                otherTracks.insert(track)
            } else {
                print("ℹ️ Track already exists in otherTracks")
            }
        }
        
    
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


// MARK: - Audio Session Notification Extensions
extension Notification.Name {
    static let pauseAllBackgroundAudio = Notification.Name("pauseAllBackgroundAudio")
    static let resumeBackgroundAudio = Notification.Name("resumeBackgroundAudio")
    static let forceStopAllAudio = Notification.Name("forceStopAllAudio")
}

// MARK: - SAPlayer Dual Audio Integration (Clean Implementation)
extension WebMAudioPlaybackManager {
    
    // MARK: - SAPlayer State Queries
    /**
     Checks if SAPlayer is currently in dual audio mode.
     
     - Returns: True if using SAPlayer dual audio, false otherwise
     */
    var isSAPlayerDualAudioMode: Bool {
        return saPlayer?.isDualAudioMode == true
    }
    
    /**
     Gets the current conversation ID from SAPlayer.
     
     - Returns: Current conversation ID or nil
     */
    var saPlayerCurrentConversationId: Int64? {
        return saPlayer?.currentDualAudioConversationId
    }
    
    /**
     Gets the current playing status from SAPlayer.
     
     - Returns: Current playing status or nil
     */
    var playingStatus: SAPlayingStatus? {
        return saPlayer?.playingStatus
    }
    
    /**
     Gets the current dual audio conversation state for debugging and state management.
     
     - Returns: Current conversation state or nil if not in dual audio mode
     */
    var currentDualAudioState: DualAudioConversationState? {
        return saPlayer?.currentDualAudioEngine?.conversationState
    }
    
    // MARK: - TikTok-Style Auto-Play Support (Using SAPlayer Methods Directly)
    
    /**
     Checks if the player is ready for auto-play (TikTok-style).
     Uses SAPlayer's dual audio state directly.
     
     - Returns: True if ready for auto-play, false otherwise
     */
    func isReadyForAutoPlay() -> Bool {
        // ✅ FIXED: Simple wrapper around SAPlayer's state checking
        guard let player = saPlayer else { return false }
        
        // Use SAPlayer's dual audio state directly
        return player.isDualAudioMode &&
               player.currentDualAudioEngine?.conversationState?.isPrepared == true &&
               player.playingStatus != .playing &&
               player.playingStatus != .buffering
    }
    
    /**
     Checks if the player is ready to play (legacy compatibility).
     Uses SAPlayer's dual audio state directly.
     
     - Returns: True if ready to play, false otherwise
     */
    func isReadyToPlay() -> Bool {
        // ✅ FIXED: Simple wrapper around SAPlayer's state checking
        guard let player = saPlayer else { return false }
        
        // Use SAPlayer's dual audio state directly
        return player.isDualAudioMode &&
               player.currentDualAudioEngine?.conversationState?.isPrepared == true &&
               player.playingStatus != .buffering
    }
    
    /**
     Attempts to auto-play if conditions are met (TikTok-style).
     Uses SAPlayer's play() method directly.
     */
    func autoPlayIfReady() {
        // ✅ FIXED: Simple wrapper around SAPlayer's auto-play logic
        guard isReadyForAutoPlay() else {
            print("🎵 Auto-play not ready - conditions not met")
            return
        }
        
        print("🎵 Auto-playing audio using SAPlayer")
        saPlayer?.play()
    }
    
    /**
     Sets the active state for this player (used by TikTok-style views).
     
     - Parameter active: Whether this player should be considered active
     */
    func setActive(_ active: Bool) {
        // This method is used by TikTok-style views to mark which player is active
        // The actual auto-play logic is handled in the view's onChange(of: isActive)
        print("🎵 Player active state set to: \(active)")
    }
    

}
