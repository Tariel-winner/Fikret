import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - Production-Ready Slot Machine Reel Component with Maximum Dopamine
// Based on proven GitHub implementations: hrsshopnil/Slot-Machine & SVafadar69/Slot_Machine

// MARK: - Casino-Style Audio Manager (Embedded)
class SlotMachineAudioManager: ObservableObject {
    static let shared = SlotMachineAudioManager()
    
    private var isAudioEnabled = true
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ [AUDIO] Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Casino Sound Effects
    
    /// Play slot machine spin start sound (like pulling the lever)
    func playSpinStart() {
        guard isAudioEnabled else { return }
        AudioServicesPlaySystemSound(1104) // Camera shutter sound (mechanical)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playTone(frequency: 800, duration: 0.2, volume: 0.3)
        }
    }
    
    /// Play spinning reel sound (continuous while spinning)
    func playSpinning() {
        guard isAudioEnabled else { return }
        
        for i in 0..<8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                AudioServicesPlaySystemSound(1103) // Soft click
            }
        }
    }
    
    /// Play reel stop sound with staggered timing
    func playReelStop(reelIndex: Int) {
        guard isAudioEnabled else { return }
        
        let delay = Double(reelIndex) * 0.3
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            AudioServicesPlaySystemSound(1105) // Soft thud
            let frequency = 600 + (reelIndex * 100)
            self.playTone(frequency: Double(frequency), duration: 0.3, volume: 0.4)
        }
    }
    
    /// Play topic selection sound
    func playTopicSelect() {
        guard isAudioEnabled else { return }
        AudioServicesPlaySystemSound(1519) // Actuate sound
        playTone(frequency: 1000, duration: 0.2, volume: 0.5)
    }
    
    /// Play jackpot celebration sound
    func playJackpot() {
        guard isAudioEnabled else { return }
        let frequencies = [523.25, 659.25, 783.99, 1046.50] // C5, E5, G5, C6
        
        for (index, frequency) in frequencies.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                self.playTone(frequency: frequency, duration: 0.3, volume: 0.6)
            }
        }
        AudioServicesPlaySystemSound(1016) // Success sound
    }
    
    /// Play anticipation sound
    func playAnticipation() {
        guard isAudioEnabled else { return }
        playTone(frequency: 400, duration: 0.2, volume: 0.3)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.playTone(frequency: 300, duration: 0.2, volume: 0.3)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.playTone(frequency: 500, duration: 0.3, volume: 0.4)
        }
    }
    
    private func playTone(frequency: Double, duration: Double, volume: Float) {
        // Using system sounds for reliability - tone generation can be enhanced later
        AudioServicesPlaySystemSound(1103)
    }
}

// MARK: - Enhanced Haptic Feedback Manager (Embedded)
class SlotMachineHapticsManager: ObservableObject {
    static let shared = SlotMachineHapticsManager()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Casino Haptic Patterns
    
    /// Lever pull haptic (when starting spin)
    func playLeverPull() {
        heavyImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mediumImpact.impactOccurred()
        }
    }
    
    /// Spinning haptic pattern (subtle ongoing vibration)
    func playSpinning() {
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                self.lightImpact.impactOccurred()
            }
        }
    }
    
    /// Reel stop haptic with increasing intensity
    func playReelStop(reelIndex: Int, isLast: Bool = false) {
        let delay = Double(reelIndex) * 0.3
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if isLast {
                self.heavyImpact.impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.mediumImpact.impactOccurred()
                }
            } else {
                let intensity: UIImpactFeedbackGenerator.FeedbackStyle = reelIndex < 2 ? .medium : .heavy
                let generator = UIImpactFeedbackGenerator(style: intensity)
                generator.impactOccurred()
            }
        }
    }
    
    /// Topic selection haptic
    func playTopicSelect() {
        selectionFeedback.selectionChanged()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.lightImpact.impactOccurred()
        }
    }
    
    /// Jackpot celebration haptic pattern
    func playJackpot() {
        notificationFeedback.notificationOccurred(.success)
        
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                self.heavyImpact.impactOccurred()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.heavyImpact.impactOccurred()
        }
    }
    
    /// Anticipation haptic (building tension)
    func playAnticipation() {
        let delays = [0.0, 0.3, 0.5, 0.6]
        let intensities: [UIImpactFeedbackGenerator.FeedbackStyle] = [.light, .light, .medium, .heavy]
        
        for (index, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let generator = UIImpactFeedbackGenerator(style: intensities[index])
                generator.impactOccurred()
            }
        }
    }
}

struct SlotMachineReel: View {
    let topic: TrendingTopic
    let isSpinning: Bool
    let isSelected: Bool
    let spinDelay: Double
    let onTap: () -> Void
    
    @State private var spinOffset: CGFloat = 0
    @State private var glowIntensity: Double = 0.0
    @State private var pulseScale: Double = 1.0
    @State private var sparkleOpacity: Double = 0.0
    @State private var isTopicExpanded: Bool = false
    
    // Audio and Haptic Managers
    private let audioManager = SlotMachineAudioManager.shared
    private let hapticsManager = SlotMachineHapticsManager.shared
    
    // Dummy spinning texts for realistic slot machine effect
    private let spinTexts = [
        "🎰 Spinning...", "🎲 Rolling...", "⚡ Loading...", "🔥 Hot Topic", 
        "💫 Trending", "🌟 Popular", "🚀 Viral", "✨ Fresh"
    ]
    
    var body: some View {
        Button(action: {
            // Handle different tap behaviors
            if !isSpinning && topic.title.count > 50 && !isSelected {
                // For long topics, first tap expands, second tap selects
               
                // Normal selection behavior
                // 🎵 DOPAMINE: Play selection sound and haptic
                audioManager.playTopicSelect()
                hapticsManager.playTopicSelect()
                onTap()
            }
        }) {
            HStack(spacing: 12) {
                // Enhanced selection indicator with parent view theme
                ZStack {
                    Circle()
                        .fill(
                            isSelected ? 
                                LinearGradient(
                                    colors: [.green, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 24, height: 24)
                        .shadow(color: isSelected ? .green.opacity(glowIntensity) : .clear, radius: 6)
                        .scaleEffect(pulseScale)
                    
                    Image(systemName: isSelected ? "checkmark" : "circle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                
                // Enhanced text content with parent view theme
                VStack(alignment: .leading, spacing: 4) {
                    if isSpinning {
                        // Spinning animation with theme colors
                        Text(spinTexts.randomElement() ?? "🎰 Spinning...")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .opacity(0.8)
                            .transition(.opacity)
                    } else {
                        // Modern auto-expanding topic text (Instagram/Twitter style)
                        VStack(alignment: .leading, spacing: 4) {
                            // Main topic text with smart truncation
                            Text(topic.title)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(isSelected ? nil : 3) // Auto-expand when selected
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true) // Allow natural text flow
                                .transition(.opacity)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
                            
                            // Modern "more" indicator (only for very long topics when not selected)
                            if !isSelected && topic.title.count > 80 {
                                HStack(spacing: 4) {
                                    Text("...")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    
                                    Text("more")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.purple.opacity(0.7), .blue.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .opacity(0.8)
                                }
                                .transition(.opacity)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected ? 
                            LinearGradient(
                                colors: [Color.green.opacity(0.15), Color.blue.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.black.opacity(0.4), Color.black.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
            )
            .overlay {
                // Enhanced border with gradient
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? 
                            LinearGradient(
                                colors: [.green.opacity(0.6), .blue.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .shadow(
                color: isSelected ? .green.opacity(0.3) : .black.opacity(0.2),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.3), value: isSpinning)
        .onChange(of: isSpinning) { spinning in
            if spinning {
                startSpinning()
            } else {
                stopSpinning()
            }
        }
        .onChange(of: isSelected) { selected in
            if selected {
                startSelectionAnimation()
            } else {
                stopSelectionAnimation()
            }
        }
    }
    
    private func startSpinning() {
        // 🎵 DOPAMINE: Play spinning sound
        audioManager.playSpinning()
        
        // Reset to start position
        spinOffset = 0
        
        // Start continuous spinning animation
        withAnimation(.linear(duration: 0.1).repeatForever(autoreverses: false)) {
            spinOffset = -400 // Move through all 8 items (8 * 50 = 400)
        }
        
        // Add subtle haptic feedback during spin
        hapticsManager.playSpinning()
    }
    
    private func stopSpinning() {
        // Calculate reel index from spin delay (0.0s = 0, 0.3s = 1, 0.6s = 2, 0.9s = 3)
        let reelIndex = Int(spinDelay / 0.3)
        let isLastReel = reelIndex == 3
        
        // 🎵 DOPAMINE: Play reel stop sound with staggered timing
        audioManager.playReelStop(reelIndex: reelIndex)
        
        // Stop spinning with staggered delay for realistic casino effect
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDelay) {
            withAnimation(.easeOut(duration: 0.8)) {
                spinOffset = 0 // Return to show the actual topic
            }
            
            // 📳 DOPAMINE: Enhanced haptic feedback with progressive intensity
            self.hapticsManager.playReelStop(reelIndex: reelIndex, isLast: isLastReel)
            
            // Add anticipation animation as reel slows down
            withAnimation(.easeInOut(duration: 0.5)) {
                self.pulseScale = 1.1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.pulseScale = 1.0
                }
            }
        }
    }
    
    private func getDisplayText(for index: Int) -> String {
        if isSpinning {
            // Show spinning text during animation
            return spinTexts[index % spinTexts.count]
        } else {
            // When stopped, ONLY show the actual topic in the visible window (index 0)
            // All other positions show empty or filler text
            if index == 0 {
                return topic.title
            } else {
                // Show filler text for reel effect, but make it less prominent
                return spinTexts[index % spinTexts.count]
            }
        }
    }
    
    private func getTextColor(for index: Int) -> Color {
        if isSpinning {
            // All text same color during spinning
            return .white.opacity(0.9)
        } else {
            // Highlight only the visible topic (index 0), dim the rest
            if index == 0 {
                return .white // Main topic - bright
            } else {
                return .white.opacity(0.3) // Filler text - very dim
            }
        }
    }
    
    // MARK: - Selection Animation Effects
    
    private func startSelectionAnimation() {
        // ✨ DOPAMINE: Sparkle and glow effects when selected
        withAnimation(.easeInOut(duration: 0.3)) {
            glowIntensity = 0.8
            sparkleOpacity = 1.0
        }
        
        // Pulsing effect
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
        }
        
        // Rotating sparkles
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            // This will be handled by the sparkle rotation in the view
        }
    }
    
    private func stopSelectionAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            glowIntensity = 0.0
            sparkleOpacity = 0.0
            pulseScale = 1.0
        }
    }
}
