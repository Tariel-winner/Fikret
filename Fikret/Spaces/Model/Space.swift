//
//  Space.swift
//  Spaces
//
//  Created by Stefan Blos on 16.02.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
///

import Foundation
//import SendbirdChatSDK
import CoreLocation

struct Profile: Codable {
 let name: String?
 let profilepicture: String?
 let username: String?
 }
 extension Queue {
 func addingUser(_ user: QueueUser) -> Queue {
 var new = self
 new.participants.append(user)
 return new
 }
 
 func removingUser(id: Int64) -> Queue {
 var new = self
 new.participants.removeAll { $0.id == id }
 return new
 }
 
 
 }

 
 // Define the Queue struct
 struct Queue: Identifiable, Codable, Equatable, Hashable {
 var id: Int64     // Unique identifier for the queue
 var name: String?   // Name of the queue (optional)
 var description: String? // Description of the queue (optional)
 var isClosed: Bool  // Whether the queue is closed or not
 var participants: [QueueUser] // List of users in the queue
 var lastPosition: Int?
 // Computed property to return the number of participants
 var participantCount: Int {
 participants.count
 }
 
 // Preview helper for testing in SwiftUI Previews
 
 }
 
 // Ensure QueueUser conforms to Equatable and Hashable
 struct QueueUser: Identifiable, Codable, Equatable, Hashable {
 var id: Int64
 var position: Int
 var name: String
 var image: String
 var isInvited: Bool
 var topic: String?
 var hasLeft: Bool
 }
 
 // 1. First, add ImageUploadStatus enum at the top level
 enum ImageUploadStatus: Codable, Hashable {
 case none
 case pending
 case completed(URL)
 case failed(String)
 
 private enum CodingKeys: String, CodingKey {
 case type, url, error
 }
 
 enum CodingError: String, Codable {
 case none, pending, completed, failed
 }
 
 init(from decoder: Decoder) throws {
 // First try to decode as a simple string
 if let stringValue = try? decoder.singleValueContainer().decode(String.self) {
 switch stringValue {
 case "none": self = .none
 case "pending": self = .pending
 case "failed": self = .failed("Unknown error")
 default:
 if let url = URL(string: stringValue) {
 self = .completed(url)
 } else {
 self = .none
 }
 }
 return
 }
 
 // If not a string, try the dictionary format
 let container = try decoder.container(keyedBy: CodingKeys.self)
 let type = try container.decode(CodingError.self, forKey: .type)
 
 switch type {
 case .none:
 self = .none
 case .pending:
 self = .pending
 case .completed:
 let url = try container.decode(URL.self, forKey: .url)
 self = .completed(url)
 case .failed:
 let errorMessage = try container.decode(String.self, forKey: .error)
 self = .failed(errorMessage)
 }
 }
 
 func encode(to encoder: Encoder) throws {
 // Always encode in dictionary format for consistency
 var container = encoder.container(keyedBy: CodingKeys.self)
 
 switch self {
 case .none:
 try container.encode(CodingError.none, forKey: .type)
 case .pending:
 try container.encode(CodingError.pending, forKey: .type)
 case .completed(let url):
 try container.encode(CodingError.completed, forKey: .type)
 try container.encode(url, forKey: .url)
 case .failed(let errorMessage):
 try container.encode(CodingError.failed, forKey: .type)
 try container.encode(errorMessage, forKey: .error)
 }
 }
 }
 
 // Add this helper function at the top level
 func parseLocationString(_ locationString: String) -> CLLocationCoordinate2D? {
 // Case 1: Handle SRID=4326;POINT format
 if locationString.hasPrefix("SRID=4326;POINT") {
 let pointPart = locationString.replacingOccurrences(of: "SRID=4326;POINT(", with: "")
 .replacingOccurrences(of: ")", with: "")
 let coordinates = pointPart.split(separator: " ")
 if coordinates.count == 2,
 let longitude = Double(coordinates[0]),
 let latitude = Double(coordinates[1]) {
 return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
 }
 }
 
 // Case 2: Handle WKB hex format (0101000020E610...)
 if locationString.hasPrefix("0101000020E610") {
 // For now, return a default location until we implement proper WKB parsing
 return CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
 }
 
 // Case 3: Handle simple POINT format
 if locationString.hasPrefix("POINT") {
 let coordinates = locationString.replacingOccurrences(of: "POINT(", with: "")
 .replacingOccurrences(of: ")", with: "")
 .split(separator: " ")
 if coordinates.count == 2,
 let longitude = Double(coordinates[0]),
 let latitude = Double(coordinates[1]) {
 return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
 }
 }
 
 return nil
 }
 
  struct SpaceParticipant: Identifiable, Codable, Hashable {
  var id: Int64
  var name: String?
  var username: String?
  var imageURL: String?
  var peerID: String?
  var topic: String?
  var isInvited: Bool?
  var isOnline: Bool?
  var isMuted: Bool? // ✅ ADDED: Mute state tracking
  var locationData: LocationData? // ✅ ADDED: Optional location data
  
  enum CodingKeys: String, CodingKey {
  case id
  case name
  case username
  case imageURL = "image_url"
  case peerID
  case topic
  case isInvited
  case isOnline
  case isMuted
  case locationData = "location_data"
  }
  
  init(id: Int64, name: String?, username: String?, imageURL: String?, peerID: String?, topic: String?, isInvited: Bool? = false, isOnline: Bool? = nil, isMuted: Bool? = false, locationData: LocationData? = nil) {
  self.id = id
  self.name = name
  self.username = username
  self.imageURL = imageURL
  self.peerID = peerID
  self.topic = topic
  self.isInvited = isInvited
  self.isOnline = isOnline
  self.isMuted = isMuted
  self.locationData = locationData
  }
  
  static func == (lhs: SpaceParticipant, rhs: SpaceParticipant) -> Bool {
  lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
  hasher.combine(id)
  }
  }
  
  struct Space: Codable, Identifiable, Hashable {
  var id: Int64
  var hostId: Int64
  var hmsRoomId: String?
  var speakerIdList: [Int64] = []  // Empty by default
  var startTime: Date?
  var createdAt: Date
  var updatedAt: Date
  var queue: Queue = Queue(id: 0, name: nil, description: nil, isClosed: false, participants: [])  // Empty by default
  var isBlockedFromSpace: Bool = false
  var speakers: [SpaceParticipant] = []  // Empty by default
  var host: String?
  var hostImageUrl: String?
  var hostUsername: String?
  var topics: [String]? = nil  // Optional
  var categories: [Int64]? = nil  // Optional
   var isHostOnline: Bool = false
 var isFollowing: Bool? = nil  // NEW: Optional following status
 var hostLocation: String? = nil  // NEW: Optional host location
 
 var startDate: Date {
  startTime ?? createdAt
  }
  
  enum CodingKeys: String, CodingKey {
  case id
  case hostId = "host_id"
  case hmsRoomId = "hms_room_id"
  case speakerIdList = "speaker_ids"
  case startTime = "start_time"
  case createdAt = "created_at"
  case updatedAt = "updated_at"
  case queue
  case isBlockedFromSpace = "is_blocked_from_space"
  case host = "host"
  case hostImageUrl = "host_image_url"
  case hostUsername = "host_username"
  case topics
  case categories
  case isHostOnline = "is_host_online"
  case isFollowing = "is_following"  // NEW: Add coding key
  case hostLocation = "host_location"  // NEW: Add coding key for location
  }
  
  init(from decoder: Decoder) throws {
  let container = try decoder.container(keyedBy: CodingKeys.self)
  
  id = try container.decode(Int64.self, forKey: .id)
  hostId = try container.decode(Int64.self, forKey: .hostId)
  hmsRoomId = try container.decodeIfPresent(String.self, forKey: .hmsRoomId)
  speakerIdList = try container.decodeIfPresent([Int64].self, forKey: .speakerIdList) ?? []
  queue = try container.decodeIfPresent(Queue.self, forKey: .queue) ?? Queue(id: 0, name: nil, description: nil, isClosed: false, participants: [])
  
  // Handle Unix timestamp decoding for dates
  if let startTimeTimestamp = try container.decodeIfPresent(Int64.self, forKey: .startTime) {
    startTime = Date(timeIntervalSince1970: TimeInterval(startTimeTimestamp))
  } else {
    startTime = nil
  }
  
  let createdAtTimestamp = try container.decode(Int64.self, forKey: .createdAt)
  createdAt = Date(timeIntervalSince1970: TimeInterval(createdAtTimestamp))
  
  let updatedAtTimestamp = try container.decode(Int64.self, forKey: .updatedAt)
  updatedAt = Date(timeIntervalSince1970: TimeInterval(updatedAtTimestamp))
  
  // Handle is_blocked_from_space as integer (0 = false, 1 = true)
  if let blockedInt = try container.decodeIfPresent(Int.self, forKey: .isBlockedFromSpace) {
    isBlockedFromSpace = blockedInt != 0
  } else {
    isBlockedFromSpace = false
  }
  
  host = try container.decodeIfPresent(String.self, forKey: .host)
  hostImageUrl = try container.decodeIfPresent(String.self, forKey: .hostImageUrl)
  hostUsername = try container.decodeIfPresent(String.self, forKey: .hostUsername)
  topics = try container.decodeIfPresent([String].self, forKey: .topics)
  categories = try container.decodeIfPresent([Int64].self, forKey: .categories)
  isHostOnline = try container.decodeIfPresent(Bool.self, forKey: .isHostOnline) ?? false
  isFollowing = try container.decodeIfPresent(Bool.self, forKey: .isFollowing)  // NEW: Decode optional following status
  hostLocation = try container.decodeIfPresent(String.self, forKey: .hostLocation)  // NEW: Decode optional host location
  
  // Initialize local state properties
  speakers = []
  
  // Add host to speakers array
  let hostParticipant = SpaceParticipant(
    id: hostId,
    name: host,
    username: hostUsername,
    imageURL: hostImageUrl,
    peerID: nil,
    topic: nil,
    isInvited: true
  )
  speakers.insert(hostParticipant, at: 0)
  }
  
  func encode(to encoder: Encoder) throws {
  var container = encoder.container(keyedBy: CodingKeys.self)
  try container.encode(id, forKey: .id)
  try container.encode(hostId, forKey: .hostId)
  try container.encode(hmsRoomId, forKey: .hmsRoomId)
  try container.encode(speakerIdList.map { $0}, forKey: .speakerIdList)
  try container.encodeIfPresent(startTime?.timeIntervalSince1970, forKey: .startTime)
  try container.encode(createdAt.timeIntervalSince1970, forKey: .createdAt)
  try container.encode(updatedAt.timeIntervalSince1970, forKey: .updatedAt)
  try container.encodeIfPresent(queue, forKey: .queue)
  try container.encode(isBlockedFromSpace ? 1 : 0, forKey: .isBlockedFromSpace)
  try container.encodeIfPresent(host, forKey: .host)
  try container.encodeIfPresent(hostImageUrl, forKey: .hostImageUrl)
  try container.encodeIfPresent(hostUsername, forKey: .hostUsername)
  try container.encodeIfPresent(topics, forKey: .topics)
  try container.encodeIfPresent(categories, forKey: .categories)
  try container.encode(isHostOnline, forKey: .isHostOnline)
  try container.encodeIfPresent(isFollowing, forKey: .isFollowing)  // NEW: Encode optional following status
  try container.encodeIfPresent(hostLocation, forKey: .hostLocation)  // NEW: Encode optional host location
  }
  
  init(id: Int64, hostId: Int64, hmsRoomId: String?, speakerIdList: [Int64],
  startTime: Date?, createdAt: Date, updatedAt: Date,
  speakers: [SpaceParticipant] = [],
  queue: Queue = Queue(id: 0, name: nil, description: nil, isClosed: false, participants: []),
  host: String? = nil, hostImageUrl: String? = nil, hostUsername: String? = nil,
  isBlockedFromSpace: Bool = false, topics: [String]? = nil, categories: [Int64]? = nil,
  isHostOnline: Bool = false, isFollowing: Bool? = nil, hostLocation: String? = nil) {  // NEW: Add parameters
  self.id = id
  self.hostId = hostId
  self.hmsRoomId = hmsRoomId
  self.speakerIdList = speakerIdList
  self.startTime = startTime
  self.createdAt = createdAt
  self.updatedAt = updatedAt
  self.speakers = speakers
  self.host = host
  self.queue = queue
  self.hostImageUrl = hostImageUrl
  self.hostUsername = hostUsername
  self.isBlockedFromSpace = isBlockedFromSpace
  self.topics = topics
  self.categories = categories
  self.isHostOnline = isHostOnline
  self.isFollowing = isFollowing  // NEW: Set the property
  self.hostLocation = hostLocation  // NEW: Set the property
  }
  
  // Add mutating functions to update properties
  mutating func updateQueue(_ newQueue: Queue) {
  self.queue = newQueue
  }
  
  mutating func updateHmsRoomId(_ newRoomId: String?) {
  self.hmsRoomId = newRoomId
  }
  
  mutating func updateHostOnlineStatus(_ isOnline: Bool) {
  self.isHostOnline = isOnline
  }
  
  mutating func updateQueueParticipants(_ participants: [QueueUser]) {
  self.queue.participants = participants
  }
  
  mutating func updateQueueClosedState(_ isClosed: Bool) {
  self.queue.isClosed = isClosed
  }
  
  mutating func updateQueueLastPosition(_ position: Int?) {
  self.queue.lastPosition = position
  }
  
  mutating func updateFollowStatus(_ isFollowing: Bool) {
  self.isFollowing = isFollowing
  }
  
  mutating func updateWithSpace(_ newSpace: Space) {
  self.hmsRoomId = newSpace.hmsRoomId
  self.speakerIdList = newSpace.speakerIdList
  self.startTime = newSpace.startTime
  self.updatedAt = newSpace.updatedAt
  self.queue = newSpace.queue
  self.speakers = newSpace.speakers
  self.host = newSpace.host
  self.hostImageUrl = newSpace.hostImageUrl
  self.hostUsername = newSpace.hostUsername
  self.isBlockedFromSpace = newSpace.isBlockedFromSpace
  self.topics = newSpace.topics
  self.categories = newSpace.categories
  self.isHostOnline = newSpace.isHostOnline
  self.isFollowing = newSpace.isFollowing  // NEW: Update following status
  self.hostLocation = newSpace.hostLocation  // NEW: Update host location
  }
  }
  
  extension Space {
  mutating func update(with newSpace: Space, preservingFieldsFrom oldSpace: Space, shouldUpdateQueue: Bool = false) {
  self.hmsRoomId = newSpace.hmsRoomId
  self.speakerIdList = newSpace.speakerIdList
  self.startTime = newSpace.startTime
  self.updatedAt = newSpace.updatedAt
  
  if shouldUpdateQueue {
  self.queue = newSpace.queue
  } else {
  self.queue = oldSpace.queue
  }
  
    // Use new speakers list instead of old one
    self.speakers = newSpace.speakers
  self.host = oldSpace.host
  self.hostImageUrl = oldSpace.hostImageUrl
  self.hostUsername = oldSpace.hostUsername
  self.isBlockedFromSpace = oldSpace.isBlockedFromSpace
  self.topics = newSpace.topics
  self.categories = newSpace.categories
  self.isHostOnline = newSpace.isHostOnline
  self.isFollowing = newSpace.isFollowing  // NEW: Update following status from new space
  self.hostLocation = newSpace.hostLocation  // NEW: Update host location from new space
  }
  }
  
  extension Space {
  func hash(into hasher: inout Hasher) {
  hasher.combine(id)
  hasher.combine(hostId)
  hasher.combine(hmsRoomId)
  hasher.combine(speakerIdList)
  hasher.combine(startTime)
  hasher.combine(createdAt)
  hasher.combine(updatedAt)
  hasher.combine(queue)
  hasher.combine(isBlockedFromSpace)
  hasher.combine(host)
  hasher.combine(hostImageUrl)
  hasher.combine(hostUsername)
  hasher.combine(topics)
  hasher.combine(categories)
  hasher.combine(isHostOnline)
  hasher.combine(isFollowing)  // NEW: Include following status in hash
  hasher.combine(hostLocation)  // NEW: Include host location in hash
  }
  
  static func == (lhs: Space, rhs: Space) -> Bool {
  lhs.id == rhs.id &&
  lhs.hostId == rhs.hostId &&
  lhs.hmsRoomId == rhs.hmsRoomId &&
  lhs.speakerIdList == rhs.speakerIdList &&
  lhs.startTime == rhs.startTime &&
  lhs.createdAt == rhs.createdAt &&
  lhs.updatedAt == rhs.updatedAt &&
  lhs.queue == rhs.queue &&
  lhs.isBlockedFromSpace == rhs.isBlockedFromSpace &&
  lhs.host == rhs.host &&
  lhs.hostImageUrl == rhs.hostImageUrl &&
  lhs.hostUsername == rhs.hostUsername &&
  lhs.topics == rhs.topics &&
  lhs.categories == rhs.categories &&
  lhs.isHostOnline == rhs.isHostOnline &&
  lhs.isFollowing == rhs.isFollowing &&  // NEW: Compare following status
  lhs.hostLocation == rhs.hostLocation  // NEW: Compare host location
  }
  }
  
  private enum LocationCodingKeys: String, CodingKey {
  case type
  case coordinates
  }

