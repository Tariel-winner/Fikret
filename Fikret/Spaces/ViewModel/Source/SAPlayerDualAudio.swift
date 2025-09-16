//
//  SAPlayerDualAudio.swift
//  SwiftAudioPlayer
//
//  Created for Fikret Dual Audio Support
//
//  Complete dual audio implementation for SAPlayer
//  This file extends SAPlayer functionality for dual audio support
//  with proper loading of both host and visitor audio streams
//  and real-time audio level monitoring
//

import Foundation
import AVFoundation

// MARK: - Audio Level Monitoring Delegate
public protocol DualAudioLevelDelegate: AnyObject {
    func hostAudioLevelChanged(_ level: Float)
    func visitorAudioLevelChanged(_ level: Float)
    func activeSpeakerChanged(_ speakerId: Int64?)
}

// MARK: - Dual Audio Conversation State
public struct DualAudioConversationState {
    public let conversationId: Int64
    public var isPrepared: Bool = false
    public var isPlaying: Bool = false
    public var hostVolume: Float = 1.0
    public var visitorVolume: Float = 1.0
    public var speed: Float = 1.0
    public var hostAudioURL: URL?
    public var visitorAudioURL: URL?
    
    public init(conversationId: Int64) {
        self.conversationId = conversationId
    }
}

// MARK: - Dual Audio Engine Protocol
internal protocol DualAudioEngineProtocol: AudioEngineProtocol {
    var currentConversationId: Int64? { get }
    var hostPlayerNode: AVAudioPlayerNode? { get }
    var visitorPlayerNode: AVAudioPlayerNode? { get }
    func setHostVolume(_ volume: Float)
    func setVisitorVolume(_ volume: Float)
    func setDualAudioSpeed(_ speed: Float)
    func setAudioLevelDelegate(_ delegate: DualAudioLevelDelegate?)
    func setSpeakerIds(hostId: Int64, visitorId: Int64)
}

// MARK: - Complete Dual Audio Engine with Real Audio Level Monitoring
internal class DualAudioEngine: AudioEngine, DualAudioEngineProtocol {
    
    // MARK: - Dual Audio Properties
    public var currentConversationId: Int64?
    public var hostPlayerNode: AVAudioPlayerNode?
    public var visitorPlayerNode: AVAudioPlayerNode?
    
    // Individual volume control
    private var hostVolume: Float = 1.0
    private var visitorVolume: Float = 1.0
    
    // Individual speed control
    private var hostTimePitch: AVAudioUnitTimePitch?
    private var visitorTimePitch: AVAudioUnitTimePitch?
    
    // Audio files for both streams
    private var hostAudioFile: AVAudioFile?
    private var visitorAudioFile: AVAudioFile?
    
    // Audio properties for both streams
    private var hostAudioLengthSamples: AVAudioFramePosition = 0
    private var visitorAudioLengthSamples: AVAudioFramePosition = 0
    private var hostAudioSampleRate: Float = 0
    private var visitorAudioSampleRate: Float = 0
    private var hostSeekFrame: AVAudioFramePosition = 0
    private var visitorSeekFrame: AVAudioFramePosition = 0
    
    // Current frame tracking for host audio (used for needle calculation)
    private var hostCurrentFrame: AVAudioFramePosition {
        guard let lastRenderTime = hostPlayerNode?.lastRenderTime,
            let playerTime = hostPlayerNode?.playerTime(forNodeTime: lastRenderTime) else {
                return 0
        }
        return playerTime.sampleTime
    }
    
    // Conversation state
    public var conversationState: DualAudioConversationState?
    
    // Audio level monitoring
    private weak var audioLevelDelegate: DualAudioLevelDelegate?
    // ✅ MADE PUBLIC: So UI can access live audio levels directly
    public var hostAudioLevel: Float = 0.0
    public var visitorAudioLevel: Float = 0.0
    public var activeSpeakerId: Int64?
    private var hostId: Int64?
    private var visitorId: Int64?
    
    // Audio level processing
    private let audioLevelQueue = DispatchQueue(label: "com.fikret.audiolevel", qos: .userInitiated)
    private var hostLevelHistory: [Float] = []
    private var visitorLevelHistory: [Float] = []
    private let maxLevelHistorySize = 10
    private let speakingThreshold: Float = 0.01  // Lower threshold for WebM audio files
    private let levelUpdateInterval: TimeInterval = 0.1
    private var lastLevelUpdateTime: TimeInterval = 0
    
    // MARK: - Initialization
    internal init(hostURL: URL, visitorURL: URL, conversationId: Int64, delegate: AudioEngineDelegate?) {
        self.currentConversationId = conversationId
        self.conversationState = DualAudioConversationState(conversationId: conversationId)
        self.conversationState?.hostAudioURL = hostURL
        self.conversationState?.visitorAudioURL = visitorURL
        
        // Initialize with host URL (base class needs one URL)
        super.init(url: hostURL, delegate: delegate, engineAudioFormat: AudioEngine.defaultEngineAudioFormat)
        
        // ✅ FIXED: Set the key in AudioClockDirector immediately (like single engines)
        // This ensures AudioClockDirector accepts updates from this engine
        AudioClockDirector.shared.setKey(key)
        
        // Setup dual audio nodes and load both audio files
        setupDualAudioNodes()
        loadBothAudioFiles(hostURL: hostURL, visitorURL: visitorURL)
        setupAudioLevelMonitoring()
    }
    
    // MARK: - Complete Dual Audio Setup
    private func setupDualAudioNodes() {
        guard let engine = engine else { return }
        
        // Create second player node for visitor audio
        visitorPlayerNode = AVAudioPlayerNode()
        hostPlayerNode = playerNode // Use existing playerNode as host
        
        // Create individual time pitch units for speed control
        hostTimePitch = AVAudioUnitTimePitch()
        visitorTimePitch = AVAudioUnitTimePitch()
        
        // Attach nodes to engine
        if let visitorNode = visitorPlayerNode {
            engine.attach(visitorNode)
        }
        if let hostPitch = hostTimePitch {
            engine.attach(hostPitch)
        }
        if let visitorPitch = visitorTimePitch {
            engine.attach(visitorPitch)
        }
        
        // Connect host audio chain (existing playerNode is already connected)
        // Connect visitor audio chain
        if let visitorNode = visitorPlayerNode,
           let visitorPitch = visitorTimePitch {
            engine.connect(visitorNode, to: visitorPitch, format: AudioEngine.defaultEngineAudioFormat)
            engine.connect(visitorPitch, to: engine.mainMixerNode, format: AudioEngine.defaultEngineAudioFormat)
        }
        
        // Set initial volumes
        setHostVolume(hostVolume)
        setVisitorVolume(visitorVolume)
    }
    
    // MARK: - Audio Level Monitoring Setup
    private func setupAudioLevelMonitoring() {
        guard let engine = engine else { return }
        
        print("🎧 [DUAL_ENGINE] Setting up audio level monitoring...")
        
        // Add audio taps to both player nodes for level monitoring
        if let hostNode = hostPlayerNode {
            print("🎧 [DUAL_ENGINE] Installing tap on host node")
            hostNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
                print("🎧 [DUAL_ENGINE] Host audio tap triggered - buffer size: \(buffer.frameLength)")
                self?.processHostAudioLevel(buffer: buffer)
            }
        } else {
            print("❌ [DUAL_ENGINE] Host node not available for tap installation")
        }
        
        if let visitorNode = visitorPlayerNode {
            print("🎤 [DUAL_ENGINE] Installing tap on visitor node")
            visitorNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
                print("🎤 [DUAL_ENGINE] Visitor audio tap triggered - buffer size: \(buffer.frameLength)")
                self?.processVisitorAudioLevel(buffer: buffer)
            }
        } else {
            print("❌ [DUAL_ENGINE] Visitor node not available for tap installation")
        }
        
        print("✅ [DUAL_ENGINE] Audio level monitoring setup complete")
        
        // Start level monitoring timer
        startAudioLevelMonitoring()
    }
    
    // MARK: - Audio Level Processing
    private func processHostAudioLevel(buffer: AVAudioPCMBuffer) {
        audioLevelQueue.async { [weak self] in
            guard let self = self else { return }
            
            let level = self.calculateAudioLevel(from: buffer)
            self.updateHostAudioLevel(level)
            
            // ✅ ADD DEBUG LOG
            if level > 0.01 { // Only log when there's actual audio
                print("🎧 [DUAL_ENGINE] Host audio level: \(String(format: "%.3f", level))")
            }
        }
    }
    
    private func processVisitorAudioLevel(buffer: AVAudioPCMBuffer) {
        audioLevelQueue.async { [weak self] in
            guard let self = self else { return }
            
            let level = self.calculateAudioLevel(from: buffer)
            self.updateVisitorAudioLevel(level)
            
            // ✅ ADD DEBUG LOG
            if level > 0.01 { // Only log when there's actual audio
                print("🎤 [DUAL_ENGINE] Visitor audio level: \(String(format: "%.3f", level))")
            }
        }
    }
    
    // MARK: - Audio Level Calculation
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else {
            return 0.0
        }
        
        // Calculate RMS (Root Mean Square) for accurate audio level
        var sum: Float = 0.0
        let frameLength = Int(buffer.frameLength)
        
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        
        // Convert to decibels and scale to 0-1 range
        let db = 20 * log10(max(rms, 1e-10))
        let scaledLevel = self.scaleDecibelsToLevel(db)
        
        return scaledLevel
    }
    
    private func scaleDecibelsToLevel(_ db: Float) -> Float {
        // Scale from typical audio range (-60dB to 0dB) to 0-1
        let minDb: Float = -60.0
        let maxDb: Float = 0.0
        
        if db <= minDb {
            return 0.0
        } else if db >= maxDb {
            return 1.0
        } else {
            return (db - minDb) / (maxDb - minDb)
        }
    }
    
    // MARK: - Audio Level Updates
    private func updateHostAudioLevel(_ level: Float) {
        // Apply smoothing using moving average
        hostLevelHistory.append(level)
        if hostLevelHistory.count > maxLevelHistorySize {
            hostLevelHistory.removeFirst()
        }
        
        let smoothedLevel = hostLevelHistory.reduce(0, +) / Float(hostLevelHistory.count)
        hostAudioLevel = smoothedLevel
        
        // ✅ ADD DEBUG LOG
        print("🎧 [DUAL_ENGINE] updateHostAudioLevel called - raw: \(String(format: "%.3f", level)), smoothed: \(String(format: "%.3f", smoothedLevel))")
        
        // Update active speaker detection
        updateActiveSpeakerDetection()
        
        // Notify delegate on main queue
        DispatchQueue.main.async { [weak self] in
            print("🎧 [DUAL_ENGINE] Notifying delegate - hostAudioLevelChanged: \(String(format: "%.3f", smoothedLevel))")
            self?.audioLevelDelegate?.hostAudioLevelChanged(smoothedLevel)
        }
    }
    
    private func updateVisitorAudioLevel(_ level: Float) {
        // Apply smoothing using moving average
        visitorLevelHistory.append(level)
        if visitorLevelHistory.count > maxLevelHistorySize {
            visitorLevelHistory.removeFirst()
        }
        
        let smoothedLevel = visitorLevelHistory.reduce(0, +) / Float(visitorLevelHistory.count)
        visitorAudioLevel = smoothedLevel
        
        // ✅ ADD DEBUG LOG
        print("🎤 [DUAL_ENGINE] updateVisitorAudioLevel called - raw: \(String(format: "%.3f", level)), smoothed: \(String(format: "%.3f", smoothedLevel))")
        
        // Update active speaker detection
        updateActiveSpeakerDetection()
        
        // Notify delegate on main queue
        DispatchQueue.main.async { [weak self] in
            print("🎤 [DUAL_ENGINE] Notifying delegate - visitorAudioLevelChanged: \(String(format: "%.3f", smoothedLevel))")
            self?.audioLevelDelegate?.visitorAudioLevelChanged(smoothedLevel)
        }
    }
    
    // MARK: - Active Speaker Detection
    private func updateActiveSpeakerDetection() {
        let currentTime = Date().timeIntervalSince1970
        
        // Throttle updates to prevent excessive UI updates
        guard currentTime - lastLevelUpdateTime >= levelUpdateInterval else { return }
        lastLevelUpdateTime = currentTime
        
        let hostSpeaking = hostAudioLevel > speakingThreshold
        let visitorSpeaking = visitorAudioLevel > speakingThreshold
        
        var newActiveSpeakerId: Int64?
        
        if hostSpeaking && visitorSpeaking {
            // Both speaking - use the louder one
            newActiveSpeakerId = hostAudioLevel > visitorAudioLevel ? hostId : visitorId
        } else if hostSpeaking {
            newActiveSpeakerId = hostId
        } else if visitorSpeaking {
            newActiveSpeakerId = visitorId
        }
        
        // Only update if changed
        if newActiveSpeakerId != activeSpeakerId {
            activeSpeakerId = newActiveSpeakerId
            
            // ✅ ADD DEBUG LOG
            print("🎯 [DUAL_ENGINE] Active speaker changed to: \(newActiveSpeakerId ?? 0)")
            
            DispatchQueue.main.async { [weak self] in
                print("🎯 [DUAL_ENGINE] Notifying delegate - activeSpeakerChanged: \(newActiveSpeakerId ?? 0)")
                self?.audioLevelDelegate?.activeSpeakerChanged(newActiveSpeakerId)
            }
        }
    }
    
    // MARK: - Audio Level Monitoring Control
    private func startAudioLevelMonitoring() {
        // Audio level monitoring is continuous via audio taps
        // No additional timer needed
    }
    
    private func stopAudioLevelMonitoring() {
        // Remove audio taps
        hostPlayerNode?.removeTap(onBus: 0)
        visitorPlayerNode?.removeTap(onBus: 0)
        
        // Clear level history
        hostLevelHistory.removeAll()
        visitorLevelHistory.removeAll()
        
        // Reset levels
        hostAudioLevel = 0.0
        visitorAudioLevel = 0.0
        activeSpeakerId = nil
    }
    
    // MARK: - Load Both Audio Files
    private func loadBothAudioFiles(hostURL: URL, visitorURL: URL) {
        print("🎧 Loading audio files...")
        print("🔗 Host URL: \(hostURL)")
        print("🔗 Visitor URL: \(visitorURL)")
        
        // Check if URLs are network URLs
        let isHostNetworkURL = hostURL.scheme == "http" || hostURL.scheme == "https"
        let isVisitorNetworkURL = visitorURL.scheme == "http" || visitorURL.scheme == "https"
        
        print("🌐 Host is network URL: \(isHostNetworkURL)")
        print("🌐 Visitor is network URL: \(isVisitorNetworkURL)")
        
        // For network URLs, check cache first, then download if needed
        if isHostNetworkURL || isVisitorNetworkURL {
            print("🌐 Network URLs detected - checking cache first")
            
            // Check if both files are already cached
            let hostCachedURL = AudioDataManager.shared.getPersistedUrl(withRemoteURL: hostURL)
            let visitorCachedURL = AudioDataManager.shared.getPersistedUrl(withRemoteURL: visitorURL)
            
            if let hostCached = hostCachedURL, let visitorCached = visitorCachedURL {
                print("✅ Both audio files found in cache - using cached versions")
                loadBothAudioFiles(hostURL: hostCached, visitorURL: visitorCached)
                return
            } else {
                print("⚠️ Audio files not cached - downloading...")
                // Download both audio files to local storage first
                downloadAudioFiles(hostURL: hostURL, visitorURL: visitorURL)
                return
            }
        }
        
        // Load host audio file (local files only)
        do {
            hostAudioFile = try AVAudioFile(forReading: hostURL)
            if let file = hostAudioFile {
                hostAudioLengthSamples = file.length
                hostAudioSampleRate = Float(file.processingFormat.sampleRate)
                print("✅ Host loaded: \(hostURL.lastPathComponent)")
            }
        } catch {
            print("❌ Host load failed: \(error.localizedDescription)")
            print("❌ Error code: \(error as NSError).code")
        }
        
        // Load visitor audio file (local files only)
        do {
            visitorAudioFile = try AVAudioFile(forReading: visitorURL)
            if let file = visitorAudioFile {
                visitorAudioLengthSamples = file.length
                visitorAudioSampleRate = Float(file.processingFormat.sampleRate)
                print("✅ Visitor loaded: \(visitorURL.lastPathComponent)")
            }
        } catch {
            print("❌ Visitor load failed: \(error.localizedDescription)")
            print("❌ Error code: \(error as NSError).code")
        }
        
        // ✅ FIXED: Set duration based on actual content length, not just metadata
        // For dual audio, we need to determine the actual conversation duration
        // This might be different from the individual file lengths due to content trimming
        
        let hostDuration = hostAudioLengthSamples > 0 ? Double(Float(hostAudioLengthSamples) / hostAudioSampleRate) : 0
        let visitorDuration = visitorAudioLengthSamples > 0 ? Double(Float(visitorAudioLengthSamples) / visitorAudioSampleRate) : 0
        
        // ✅ FIXED: Use the shorter duration as the base, since that's likely the actual content length
        // The longer file might have padding or metadata that extends beyond the actual conversation
        let actualDuration = min(hostDuration, visitorDuration)
        
        if actualDuration > 0 {
            duration = Duration(actualDuration)
            bufferedSeconds = SAAudioAvailabilityRange(
                startingNeedle: 0,
                durationLoadedByNetwork: actualDuration,
                predictedDurationToLoad: actualDuration,
                isPlayable: true
            )
            
            // ✅ FIXED: Notify AudioClockDirector about the duration change
            // This ensures SAPlayer's public duration property is updated
            AudioClockDirector.shared.durationWasChanged(key, duration: duration)
            AudioClockDirector.shared.changeInAudioBuffered(key, buffered: bufferedSeconds)
            print("✅ [DUAL AUDIO] Duration set to \(actualDuration)s (host: \(hostDuration)s, visitor: \(visitorDuration)s) and notified AudioClockDirector")
        }
        
        // Schedule both audio files
        scheduleBothAudioFiles()
        
        // Start monitoring
        startDualAudioMonitoring()
    }
    
    // MARK: - Schedule Both Audio Files
    private func scheduleBothAudioFiles() {
        // Schedule host audio file
        if let hostFile = hostAudioFile {
            hostPlayerNode?.scheduleFile(hostFile, at: nil, completionHandler: nil)
        }
        
        // Schedule visitor audio file
        if let visitorFile = visitorAudioFile {
            visitorPlayerNode?.scheduleFile(visitorFile, at: nil, completionHandler: nil)
        }
    }
    
    // MARK: - Download Audio Files
    private func downloadAudioFiles(hostURL: URL, visitorURL: URL) {
        print("📥 Starting download of audio files using SAPlayer's AudioDataManager...")
        
        let group = DispatchGroup()
        var hostLocalURL: URL?
        var visitorLocalURL: URL?
        
        // Download host audio file using AudioDataManager
        group.enter()
        AudioDataManager.shared.startDownload(withRemoteURL: hostURL) { localURL, error in
            if let error = error {
                print("❌ [SAPlayer] Failed to download host audio: \(error)")
                hostLocalURL = nil
            } else {
                print("✅ [SAPlayer] Host audio downloaded to: \(localURL)")
                hostLocalURL = localURL
            }
            group.leave()
        }
        
        // Download visitor audio file using AudioDataManager
        group.enter()
        AudioDataManager.shared.startDownload(withRemoteURL: visitorURL) { localURL, error in
            if let error = error {
                print("❌ [SAPlayer] Failed to download visitor audio: \(error)")
                visitorLocalURL = nil
            } else {
                print("✅ [SAPlayer] Visitor audio downloaded to: \(localURL)")
                visitorLocalURL = localURL
            }
            group.leave()
        }
        
        // When both downloads complete, load the local files
        group.notify(queue: .main) { [weak self] in
            guard let self = self,
                  let hostLocal = hostLocalURL,
                  let visitorLocal = visitorLocalURL else {
                print("❌ Failed to download audio files")
                return
            }
            
            print("✅ Both audio files downloaded successfully using SAPlayer's AudioDataManager")
            self.loadBothAudioFiles(hostURL: hostLocal, visitorURL: visitorLocal)
        }
    }
    
    // MARK: - Schedule Empty Buffers for Network URLs
    private func scheduleEmptyBuffers() {
        print("⚠️ Scheduling empty buffers for network URLs")
        // For network URLs, we'll schedule empty buffers for now
        // This is a temporary solution until we implement proper streaming
    }
    
    // MARK: - Start Dual Audio Monitoring
    private func startDualAudioMonitoring() {
        doRepeatedly(timeInterval: 0.2) { [weak self] in
            guard let self = self else { return }
            
            self.updateDualAudioPlayingStatus()
            self.updateDualAudioNeedle()
        }
    }
    
    // MARK: - Update Dual Audio Playing Status
    private func updateDualAudioPlayingStatus() {
        guard let engine = engine else { return }
        
        let hostPlaying = hostPlayerNode?.isPlaying ?? false
        let visitorPlaying = visitorPlayerNode?.isPlaying ?? false
        let engineRunning = engine.isRunning
        
        // Both streams should be playing for dual audio to be considered playing
        let isPlaying = engineRunning && hostPlaying && visitorPlaying
        
        var newStatus: SAPlayingStatus
        
        if !bufferedSeconds.isPlayable {
            if bufferedSeconds.reachedEndOfAudio(needle: needle) {
                newStatus = .ended
            } else {
                newStatus = .buffering
            }
        } else {
            newStatus = isPlaying ? .playing : .paused
        }
        
        // Only update if status changed
        if newStatus != playingStatus {
            playingStatus = newStatus
            
            // ✅ FIXED: Notify AudioClockDirector about playing status changes
            // This ensures SAPlayer's public playingStatus property is updated
            AudioClockDirector.shared.audioPlayingStatusWasChanged(key, status: newStatus)
        }
    }
    
    // MARK: - Update Dual Audio Needle
    private func updateDualAudioNeedle() {
        guard engine?.isRunning == true else { return }
        
        // Use host audio position as primary (they should be synchronized)
        let hostPosition = hostCurrentFrame + hostSeekFrame
        let hostPositionClamped = max(0, min(hostPosition, hostAudioLengthSamples))
        
        // ✅ FIXED: Detect when audio actually ends (not just reaches metadata length)
        let currentTime = Double(Float(hostPositionClamped) / hostAudioSampleRate)
        
        // ✅ FIXED: Check if audio has stopped playing before reaching the end
        // This indicates the actual content is shorter than the file metadata
        if currentTime > 0 && !(hostPlayerNode?.isPlaying ?? false) && !(visitorPlayerNode?.isPlaying ?? false) {
            // Audio stopped playing - this is the actual end time
            if currentTime < duration {
                print("🎵 [DURATION_FIX] Audio stopped at \(currentTime)s, updating duration from \(duration)s")
                duration = Duration(currentTime)
                AudioClockDirector.shared.durationWasChanged(key, duration: duration)
            }
            
            // Audio ended
            if state == .resumed {
                state = .suspended
            }
            playingStatus = .ended
            
            // Reset needle to 0 when audio ends
            needle = 0.0
            hostSeekFrame = 0
            visitorSeekFrame = 0
            
            // Reschedule audio files for next play
            rescheduleAudioFilesFromBeginning()
            
            // Notify AudioClockDirector about the reset
            AudioClockDirector.shared.needleTick(key, needle: 0.0)
            
            print("🔄 Audio ended - needle reset to 0 and files rescheduled")
            return
        }
        
        // Check if we've reached the end of the file
        if hostPositionClamped >= hostAudioLengthSamples {
            // Audio ended
            hostPlayerNode?.stop()
            visitorPlayerNode?.stop()
            if state == .resumed {
                state = .suspended
            }
            playingStatus = .ended
            
            // Reset needle to 0 when audio ends
            needle = 0.0
            hostSeekFrame = 0
            visitorSeekFrame = 0
            
            // Reschedule audio files for next play
            rescheduleAudioFilesFromBeginning()
            
            // Notify AudioClockDirector about the reset
            AudioClockDirector.shared.needleTick(key, needle: 0.0)
            
            print("🔄 Audio ended - needle reset to 0 and files rescheduled")
            return
        }
        
        guard hostAudioSampleRate != 0 else {
            Log.error("Missing host audio sample rate in dual audio update")
            return
        }
        
        let newNeedle = Double(Float(hostPositionClamped) / hostAudioSampleRate)
        needle = newNeedle
        
        // ✅ FIXED: Notify AudioClockDirector about needle changes
        // This ensures SAPlayer's public elapsedTime property is updated
        AudioClockDirector.shared.needleTick(key, needle: newNeedle)
    }
    
    // MARK: - Volume Control
    public func setHostVolume(_ volume: Float) {
        hostVolume = max(0.0, min(1.0, volume))
        hostPlayerNode?.volume = hostVolume
        conversationState?.hostVolume = hostVolume
    }
    
    public func setVisitorVolume(_ volume: Float) {
        visitorVolume = max(0.0, min(1.0, volume))
        visitorPlayerNode?.volume = visitorVolume
        conversationState?.visitorVolume = visitorVolume
    }
    
    // MARK: - Speed Control
    public func setDualAudioSpeed(_ speed: Float) {
        let safeSpeed = max(0.1, min(32.0, speed)) // Conservative speed limits
        
        hostTimePitch?.rate = safeSpeed
        visitorTimePitch?.rate = safeSpeed
        
        conversationState?.speed = safeSpeed
    }
    
    // MARK: - Audio Level Delegate
    public func setAudioLevelDelegate(_ delegate: DualAudioLevelDelegate?) {
        audioLevelDelegate = delegate
    }
    
    // MARK: - Speaker ID Setup
    public func setSpeakerIds(hostId: Int64, visitorId: Int64) {
        self.hostId = hostId
        self.visitorId = visitorId
    }
    
    // MARK: - Override Play/Pause for Dual Audio
    override func play() {
        print("🎵 DualAudioEngine.play() called")
        
        // ✅ SIMPLIFIED: Follow base AudioEngine pattern - just ensure engine is running
        if !(engine?.isRunning ?? false) {
            do {
                try engine?.start()
                print("✅ Engine started")
            } catch let error {
                print("❌ Engine start failed: \(error.localizedDescription)")
                return
            }
        }
        
        // ✅ SIMPLIFIED: Just start both player nodes - let AVAudioEngine handle the rest
        hostPlayerNode?.play()
        visitorPlayerNode?.play()
        
        if state == .suspended {
            state = .resumed
        }
        
        conversationState?.isPlaying = true
        print("✅ Dual audio playing")
    }
    
    // ✅ REMOVED: Complex scheduling check - using simple AVAudioEngine pattern instead
    
    // ✅ ADDED: Reschedule audio files from beginning
    private func rescheduleAudioFilesFromBeginning() {
        guard let hostFile = hostAudioFile,
              let visitorFile = visitorAudioFile else {
            print("❌ Cannot reschedule - audio files not available")
            return
        }
        
        print("🔄 Rescheduling audio files from beginning...")
        
        // Reset seek frames to 0
        hostSeekFrame = 0
        visitorSeekFrame = 0
        
        // Stop both players
        hostPlayerNode?.stop()
        visitorPlayerNode?.stop()
        
        // Schedule both audio files from the beginning
        hostPlayerNode?.scheduleFile(hostFile, at: nil, completionHandler: nil)
        visitorPlayerNode?.scheduleFile(visitorFile, at: nil, completionHandler: nil)
        
        // Reset playing status
        playingStatus = .paused
        
        print("✅ Audio files rescheduled from beginning")
    }
    
    override func pause() {
        // Pause both player nodes
        hostPlayerNode?.pause()
        visitorPlayerNode?.pause()
        
        engine?.pause()
        
        if state == .resumed {
            state = .suspended
        }
        
        conversationState?.isPlaying = false
    }
    
    // MARK: - Override Seek for Dual Audio
    override func seek(toNeedle needle: Needle) {
        guard let hostFile = hostAudioFile,
              let visitorFile = visitorAudioFile else {
            Log.error("Missing audio files for dual audio seek")
            return
        }
        
        let playing = hostPlayerNode?.isPlaying ?? false
        let seekToNeedle = needle > Needle(duration) ? Needle(duration) : needle
        
        self.needle = seekToNeedle // to tick while paused
        
        // Calculate seek frames for both streams
        hostSeekFrame = AVAudioFramePosition(Float(seekToNeedle) * hostAudioSampleRate)
        hostSeekFrame = max(hostSeekFrame, 0)
        hostSeekFrame = min(hostSeekFrame, hostAudioLengthSamples)
        
        visitorSeekFrame = AVAudioFramePosition(Float(seekToNeedle) * visitorAudioSampleRate)
        visitorSeekFrame = max(visitorSeekFrame, 0)
        visitorSeekFrame = min(visitorSeekFrame, visitorAudioLengthSamples)
        
        // Stop both players
        hostPlayerNode?.stop()
        visitorPlayerNode?.stop()
        
        // Schedule segments for both streams
        if hostSeekFrame < hostAudioLengthSamples {
            hostPlayerNode?.scheduleSegment(
                hostFile,
                startingFrame: hostSeekFrame,
                frameCount: AVAudioFrameCount(hostAudioLengthSamples - hostSeekFrame),
                at: nil,
                completionHandler: nil
            )
        }
        
        if visitorSeekFrame < visitorAudioLengthSamples {
            visitorPlayerNode?.scheduleSegment(
                visitorFile,
                startingFrame: visitorSeekFrame,
                frameCount: AVAudioFrameCount(visitorAudioLengthSamples - visitorSeekFrame),
                at: nil,
                completionHandler: nil
            )
        }
        
        // Resume playing if was playing
        if playing {
            hostPlayerNode?.play()
            visitorPlayerNode?.play()
        }
    }
    
    // MARK: - Cleanup
    override func invalidate() {
        // Stop audio level monitoring
        stopAudioLevelMonitoring()
        
        // Stop both player nodes
        hostPlayerNode?.stop()
        visitorPlayerNode?.stop()
        
        // Cleanup visitor node
        if let visitorNode = visitorPlayerNode {
            engine?.detach(visitorNode)
        }
        
        // Cleanup time pitch units
        if let hostPitch = hostTimePitch {
            engine?.detach(hostPitch)
        }
        if let visitorPitch = visitorTimePitch {
            engine?.detach(visitorPitch)
        }
        
        // ✅ FIXED: Reset audio length samples to prevent stale values
        // This ensures each post gets its own correct audio length
        hostAudioLengthSamples = 0
        visitorAudioLengthSamples = 0
        
        // Use existing cleanup
        super.invalidate()
        
        // Clear conversation state
        conversationState = nil
        currentConversationId = nil
        
        // Clear audio files
        hostAudioFile = nil
        visitorAudioFile = nil
        
        // Clear delegate
        audioLevelDelegate = nil
    }
}

    // MARK: - SAPlayer Dual Audio Extension
extension SAPlayer {
    
    // MARK: - Dual Audio Properties
    private var dualAudioPlayer: DualAudioEngine? {
        // Use the public property to access the current dual audio engine
        return currentDualAudioEngine
    }
    
    // MARK: - Dual Audio Setup
    /**
     Sets up dual audio for a conversation with host and visitor audio streams.
     
     - Parameter hostURL: URL for host audio stream
     - Parameter visitorURL: URL for visitor audio stream
     - Parameter conversationId: Unique identifier for the conversation
     - Parameter mediaInfo: Optional media information for lock screen
     */
    public func startDualAudio(hostURL: URL, visitorURL: URL, conversationId: Int64, mediaInfo: SALockScreenInfo? = nil) {
        
        // Clear existing player first using public method
        clear()
        
        // Set media info
        self.mediaInfo = mediaInfo
        
        // Create dual audio engine using internal method
        startDualAudioEngine(hostURL: hostURL, visitorURL: visitorURL, conversationId: conversationId)
        
        // Mark as prepared
        currentDualAudioEngine?.conversationState?.isPrepared = true
        
        Log.info("✅ Dual audio started for conversation \(conversationId)")
    }
    
    // MARK: - Dual Audio Volume Control
    /**
     Sets the volume for host audio stream.
     
     - Parameter volume: Volume level (0.0 to 1.0)
     */
    public func setHostVolume(_ volume: Float) {
        dualAudioPlayer?.setHostVolume(volume)
    }


    /**
     Sets the volume for visitor audio stream.
     
     - Parameter volume: Volume level (0.0 to 1.0)
     */
    public func setVisitorVolume(_ volume: Float) {
        dualAudioPlayer?.setVisitorVolume(volume)
    }
    
    // MARK: - Dual Audio Speed Control
    /**
     Sets the playback speed for both host and visitor audio streams.
     
     - Parameter speed: Playback speed (0.1 to 32.0)
     */
    public func setDualAudioSpeed(_ speed: Float) {
        dualAudioPlayer?.setDualAudioSpeed(speed)
    }
    
    // MARK: - Audio Level Monitoring
    /**
     Sets the audio level monitoring delegate for real-time audio level updates.
     
     - Parameter delegate: Delegate to receive audio level updates
     */
    public func setAudioLevelDelegate(_ delegate: DualAudioLevelDelegate?) {
        dualAudioPlayer?.setAudioLevelDelegate(delegate)
    }
    
    /**
     Sets the speaker IDs for active speaker detection.
     
     - Parameter hostId: ID of the host speaker
     - Parameter visitorId: ID of the visitor speaker
     */
    public func setSpeakerIds(hostId: Int64, visitorId: Int64) {
        dualAudioPlayer?.setSpeakerIds(hostId: hostId, visitorId: visitorId)
    }
    
    // MARK: - Conversation State
    /**
     Gets the current conversation ID if using dual audio.
     
     - Returns: Current conversation ID or nil if not using dual audio
     */
    public var currentDualAudioConversationId: Int64? {
        return dualAudioPlayer?.currentConversationId
    }
    
    /**
     Checks if the player is currently set up for dual audio.
     
     - Returns: True if using dual audio, false otherwise
     */
    public var isDualAudioMode: Bool {
        return dualAudioPlayer != nil
    }
    
    /**
     Gets the current playing status from SAPlayer.
     
     - Returns: Current playing status or nil
     */
    public var playingStatus: SAPlayingStatus? {
        return dualAudioPlayer?.playingStatus
    }
    
    /**
     Gets the current playing status from dual audio engine (alias for compatibility).
     
     - Returns: Current playing status or nil
     */
    public var dualAudioPlayingStatus: SAPlayingStatus? {
        return dualAudioPlayer?.playingStatus
    }
}

// MARK: - Migration Helper
extension SAPlayer {
    
        /**
     Migrates from single audio to dual audio for a conversation.
     
     - Parameter conversation: Audio conversation with host and visitor URLs
     - Parameter mediaInfo: Optional media information for lock screen
     */
    internal func migrateToDualAudio(for conversation: AudioConversation, mediaInfo: SALockScreenInfo? = nil) {
        
        // Validate conversation has both audio URLs
        guard let hostURL = URL(string: conversation.host_audio_url ?? ""),
              let visitorURL = URL(string: conversation.visitor_audio_url ?? ""),
              !hostURL.absoluteString.isEmpty,
              !visitorURL.absoluteString.isEmpty else {
            Log.monitor("Invalid audio URLs for conversation \(conversation.id)")
            return
        }
        
        // Start dual audio
        startDualAudio(hostURL: hostURL, visitorURL: visitorURL, conversationId: conversation.id, mediaInfo: mediaInfo)
    }
    
    // MARK: - Dual Audio Queue Management
    
    /**
     Queues a conversation for preloading using dual audio.
     This allows efficient preloading of both host and visitor audio streams.
     This method is non-interruptive and won't affect current playback.
     
     - Parameter conversation: The conversation to queue for preloading
     */
    func queueDualAudioConversation(_ conversation: AudioConversation) {
        // ✅ OPTIMIZED: Use truly non-interruptive preloading approach
        guard let hostURL = URL(string: conversation.host_audio_url ?? ""),
              let visitorURL = URL(string: conversation.visitor_audio_url ?? ""),
              !hostURL.absoluteString.isEmpty,
              !visitorURL.absoluteString.isEmpty else {
            Log.monitor("Invalid audio URLs for conversation \(conversation.id)")
            return
        }
        
        // ✅ ADDED: Check if already preloaded to avoid duplicate downloads
        if isConversationPreloaded(conversation) {
            print("✅ [SAPlayer] Conversation \(conversation.id) already preloaded - skipping")
            return
        }
        
        // ✅ FIXED: Use AudioDataManager for non-interruptive preloading
        // This downloads and caches the audio files without starting playback
        print("📥 [SAPlayer] Starting non-interruptive preloading for conversation \(conversation.id)")
        
        // Download host audio file using AudioDataManager (non-interruptive)
        AudioDataManager.shared.startDownload(withRemoteURL: hostURL) { localURL, error in
            if let error = error {
                print("❌ [SAPlayer] Failed to preload host audio: \(error)")
            } else {
                print("✅ [SAPlayer] Host audio preloaded to: \(localURL)")
            }
        }
        
        // Download visitor audio file using AudioDataManager (non-interruptive)
        AudioDataManager.shared.startDownload(withRemoteURL: visitorURL) { localURL, error in
            if let error = error {
                print("❌ [SAPlayer] Failed to preload visitor audio: \(error)")
            } else {
                print("✅ [SAPlayer] Visitor audio preloaded to: \(localURL)")
            }
        }
        
        Log.info("✅ Queued dual audio conversation \(conversation.id) for non-interruptive preloading")
    }
    

    

    
    /**
     Gets the current dual audio conversation state for debugging and state management.
     
     - Returns: Current conversation state or nil if not in dual audio mode
     */
    public var currentDualAudioState: DualAudioConversationState? {
        return currentDualAudioEngine?.conversationState
    }
    
    /**
     Checks if a conversation's audio files are already cached/preloaded.
     This helps avoid duplicate downloads during preloading.
     
     - Parameter conversation: The conversation to check
     - Returns: True if both audio files are cached, false otherwise
     */
    internal func isConversationPreloaded(_ conversation: AudioConversation) -> Bool {
        guard let hostURL = URL(string: conversation.host_audio_url ?? ""),
              let visitorURL = URL(string: conversation.visitor_audio_url ?? ""),
              !hostURL.absoluteString.isEmpty,
              !visitorURL.absoluteString.isEmpty else {
            return false
        }
        
        // Check if both audio files are already cached
        let hostCachedURL = AudioDataManager.shared.getPersistedUrl(withRemoteURL: hostURL)
        let visitorCachedURL = AudioDataManager.shared.getPersistedUrl(withRemoteURL: visitorURL)
        
        return hostCachedURL != nil && visitorCachedURL != nil
    }
 

}
