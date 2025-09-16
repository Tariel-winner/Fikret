//
//  SpacesViewModel+Channel.swift
//  Spaces
//
//  Created by Stefan Blos on 16.02.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import Foundation
import HMSSDK
/* import SendbirdChatSDK  // Add this import
 import SwiftUI
 
 
 extension SpacesViewModel: BaseChannelDelegate {
 public func channel(_ sender: BaseChannel, didUpdate channel: BaseChannel) {
 guard let groupChannel = channel as? GroupChannel,
 groupChannel.customType == "livestream_spaces" else { return }
 
 print("🔍 Sendbird: Channel didUpdate called for channel: \(groupChannel.channelURL)")
 
 // Optimistically update local state first
 Task { @MainActor in
 // 1. Create space object from SendBird data immediately
 guard let optimisticSpace = Space.from(groupChannel) else { return }
 print("🔍 Sendbird: Created optimistic space from channel data: \(optimisticSpace)")
 
 
 
 // 2. Update local state immediately
 if let index = self.spaces.firstIndex(where: {  $0.id == optimisticSpace.id }){
 self.spaces.remove(at: index)
 
 spaces.insert(optimisticSpace, at: index)
 print("🔍 Sendbird: Updated local spaces with optimistic space")
 }
 if selectedSpace?.id == optimisticSpace.id {
    selectedSpace?.update(with: optimisticSpace, preservingFieldsFrom: selectedSpace!)
    print("🔍 Sendbird: Updated selected space with optimistic space")
 }
 
 // 3. Handle immediate UI updates for state changes
 if optimisticSpace.state == .finished && isInSpace && !isHost {
 //  self.isInSpace = false
 self.selectedSpace = nil
 print("🔍 Sendbird: Space finished, updated isInSpace and selectedSpace")
 }
 
 // 4. Persist to Supabase in background
 /* Task.detached {
  do {
  try await supabase.from("spaces")
  .update([
  "name": groupChannel.name,
  "state": optimisticSpace.state.rawValue,
  "updated_at": Date().iso8601String
  ])
  .eq("channel_url", value: groupChannel.channelURL)
  .execute()
  print("✅ Supabase: Successfully updated space in Supabase")
  } catch {
  // Log error but don't block UI
  print("❌ Supabase: Background sync failed:", error)
  }
  }*/
 }
 }
 
 public func channel(_ sender: BaseChannel, didReceive event: String) {
 guard let groupChannel = sender as? GroupChannel else { return }
 
 print("🔍 Sendbird: Channel didReceive event: \(event) for channel: \(groupChannel.channelURL)")
 
 switch event {
 case "ENTER", "EXIT":
 // Update UI immediately
 let task = Task  { @MainActor in
 
 //   updatedSpace.participantCount = groupChannel.memberCount
 
 if let index = self.spaces.firstIndex(where: { $0.channelUrl == groupChannel.channelURL }) {
 var updatedSpace = self.spaces[index]
 
 
 // Remove the old space and insert the updated one
 if  updatedSpace != nil {
 self.spaces.remove(at: index)
 self.spaces.insert(updatedSpace, at: index)
 }
 
 
 if self.selectedSpace?.id == self.spaces[index].id {
    selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: selectedSpace!)
    print("🔍 Sendbird: Updated selected space for ENTER/EXIT event")
 }
 
 // Persist in background
 
 }
 }
 
 case "DELETE":
 let task = Task  { @MainActor in
 // Immediate UI update
 spaces = spaces.filter { $0.channelUrl != groupChannel.channelURL }
 if self.selectedSpace?.channelUrl == groupChannel.channelURL {
    if let space = selectedSpace {
        var updatedSpace = space
        updatedSpace.hmsRoomId = nil
        selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: selectedSpace!)
    }
 }
 
 // Background update
 /*  Task.detached {
  try? await supabase.from("spaces")
  .update([
  "state": SpaceState.finished.rawValue
  ])
  .eq("channel_url", value: groupChannel.channelURL)
  .execute()
  print("✅ Supabase: Successfully updated space state to finished in Supabase")
  }*/
 }
 
 default:
 print("🔍 Sendbird: Received unhandled event: \(event)")
 break
 }
 }
 }
 
 // Helper extension for Date
 /*private extension Date {
  var iso8601String: String {
  let formatter = ISO8601DateFormatter()
  return formatter.string(from: self)
  }
  }*/
 */
