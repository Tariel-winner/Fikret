import Foundation
import HMSSDK
import SwiftUI
import CryptoKit
import Ably
import LiveKit

extension SpacesViewModel {
  
    // ✅ COORDINATED: Calculate positions without updating state
    func calculatePositions(_ speakers: [SpaceParticipant], _ geometry: GeometryProxy) -> [Int64: CGSize] {
        let totalWidth = geometry.size.width
        let spacing = totalWidth * 0.1
        let speakerWidth = totalWidth * 0.25
        
        var newPositions: [Int64: CGSize] = [:]
        
        for (index, speaker) in speakers.enumerated() {
            let xPosition = calculateXPosition(
                index: index,
                totalSpeakers: speakers.count,
                totalWidth: totalWidth,
                spacing: spacing,
                speakerWidth: speakerWidth
            )
            newPositions[speaker.id] = CGSize(width: xPosition, height: 0)
        }
        
        return newPositions
    }
    
    // ✅ COORDINATED: Find new speakers
    func findNewSpeakers(_ newSpeakers: [SpaceParticipant]) -> Set<Int64> {
        let currentIds = Set(speakerPositions.keys)
        let newIds = Set(newSpeakers.map { $0.id })
        return newIds.subtracting(currentIds)
    }
    
    // ✅ COORDINATED: Find leaving speakers
    func findLeavingSpeakers(_ newSpeakers: [SpaceParticipant]) -> Set<Int64> {
        let currentIds = Set(speakerPositions.keys)
        let newIds = Set(newSpeakers.map { $0.id })
        return currentIds.subtracting(newIds)
    }
    
    // ✅ COORDINATED: Cleanup leaving speakers after animation
    func cleanupLeavingSpeakers() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            var finalPositions = self.speakerPositions
            for speakerId in self.leavingSpeakerIds {
                finalPositions.removeValue(forKey: speakerId)
            }
            
            withAnimation(.easeOut(duration: 0.3)) {
                self.speakerPositions = finalPositions
                self.leavingSpeakerIds.removeAll()
                self.enteringSpeakerIds.removeAll()
            }
        }
    }
    
    // ✅ SIMPLIFIED: Helper for X position calculation
    private func calculateXPosition(index: Int, totalSpeakers: Int,
                                  totalWidth: CGFloat, spacing: CGFloat,
                                  speakerWidth: CGFloat) -> CGFloat {
        switch totalSpeakers {
        case 1: return 0
        case 2: return index == 0 ? -spacing : spacing
        case 3: return CGFloat(index - 1) * (spacing + speakerWidth * 0.5)
        default: return CGFloat(index - totalSpeakers / 2) * (spacing + speakerWidth * 0.8)
        }
    }
}
