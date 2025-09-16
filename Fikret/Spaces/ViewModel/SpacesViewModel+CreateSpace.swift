//
//  SpacesViewModel+CreateSpace.swift
//  Spaces
//
//  Created by Stefan Blos on 01.03.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
import Foundation
import HMSSDK
//import SendbirdChatSDK  // Add this import
import SwiftUI
import CommonCrypto
//import AWSS3
import CoreLocation
//import Supabase

extension SpacesViewModel {
    // Make these methods internal instead of public since they use internal types
    internal func clearImageCache() {
        Task {
            await ImageCacheManager.shared.clearCache()
        }
    }
    
    internal func handleError(_ error: Error) {
        setInfoMessage(text: error.localizedDescription, type: .error)
        print("Error: \(error.localizedDescription)")
        print("🔄 Setting isInSpace to false due to error")
    }
    
    @MainActor internal func autoCreateSpace() async {
        guard let currentUser = tweetData.user else {
            print("❌ No current user found for auto space creation")
            return
        }
        
        // Check if host's space already exists in UserDefaults
        let userDefaults = UserDefaults.standard
        let hostSpaceKey = "hostSpace_\(currentUser.id)"
        
        if let savedSpaceData = userDefaults.data(forKey: hostSpaceKey),
           let savedSpace = try? JSONDecoder().decode(Space.self, from: savedSpaceData) {
            print("✅ Found existing host space in UserDefaults")
            
            // Update the space with current user data while preserving other fields
            var updatedSpace = savedSpace
            updatedSpace.host = currentUser.username
            updatedSpace.hostImageUrl = currentUser.avatar
            updatedSpace.hostUsername = currentUser.username
            
            // Update the space in our array
            if let index = spaces.firstIndex(where: { $0.id == savedSpace.id }) {
                spaces[index] = updatedSpace
            } else {
                spaces.append(updatedSpace)
            }
            
            // Save the updated space back to UserDefaults
            if let encodedSpace = try? JSONEncoder().encode(updatedSpace) {
                userDefaults.set(encodedSpace, forKey: hostSpaceKey)
            }
            
            print("✅ Updated existing host space with current user data")
            return
        }
        
        // If no saved space exists, create a new one
        print("🔄 Creating new host space")
        let spaceId = currentUser.id
        let title = "Auto Space \(Date().formatted(date: .abbreviated, time: .shortened))"
        let description = "Automatically created space"
        let date = Date()
        let price = 0.0
        let location = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let latitudeBand = 0
        
        do {
            try await proceedWithChannelCreation(
                id: String(currentUser.id),
                title: title,
                description: description,
                date: date,
                currentUser: currentUser,
                price: price,
                localImageURL: nil,
                location: location,
                latitudeBand: latitudeBand
            )
            
            // After creating the space, save it to UserDefaults
            if let createdSpace = spaces.first(where: { $0.hostId == currentUser.id }),
               let encodedSpace = try? JSONEncoder().encode(createdSpace) {
                userDefaults.set(encodedSpace, forKey: hostSpaceKey)
                print("✅ Saved new host space to UserDefaults")
            }
            
            print("✅ Auto space created successfully")
        } catch {
            print("❌ Failed to create auto space: \(error)")
            handleError(error)
        }
    }
    
    @MainActor internal func createChannelForSpace(title: String, description: String, date: Date, price: Double, previewImageURL: URL? = nil, location: CLLocationCoordinate2D, latitudeBand: Int) {
        guard let currentUser = tweetData.user else {
            print("❌ No current user found")
            setInfoMessage(text: "User not logged in", type: .error)
            return
        }
        
        let spaceId = UUID().uuidString
        var s3URL: URL? = nil
        
        Task {
            do {
                try await proceedWithChannelCreation(
                    id: String(currentUser.id),
                    title: title,
                    description: description,
                    date: date,
                    currentUser: currentUser,
                    price: price,
                    localImageURL: s3URL,
                    location: location,
                    latitudeBand: latitudeBand
                )
            } catch {
                handleError(error)
            }
        }
    }
    
    internal func proceedWithChannelCreation(
        id: String,
        title: String,
        description: String,
        date: Date,
        currentUser: UserProfile,
        price: Double,
        localImageURL: URL?,
        location: CLLocationCoordinate2D,
        latitudeBand: Int
    ) async throws {
        // Detailed location logging
        print("\n📍 Location Debug Information:")
        print("Raw location data:")
        print("  - Type: \(type(of: location))")
        print("  - Latitude: \(location.latitude)")
        print("  - Longitude: \(location.longitude)")
        print("  - Latitude Band: \(latitudeBand)")
        
        // Validate location
        guard location.latitude.isFinite && location.longitude.isFinite else {
            print("❌ Invalid location coordinates:")
            print("  - Latitude isFinite: \(location.latitude.isFinite)")
            print("  - Longitude isFinite: \(location.longitude.isFinite)")
            return
        }
        
        // Format location as PostGIS POINT with SRID
        let locationString = "SRID=4326;POINT(\(location.longitude) \(location.latitude))"
        print("\n🗺 Formatted PostGIS location:")
        print("  - Format: \(locationString)")
        
        let hmsRoomId = UUID().uuidString
        .lowercased()
            .replacingOccurrences(of: "-", with: "")
        
            let spaceId = currentUser.id
            let dateFormatter = ISO8601DateFormatter()
            
            let uuidString = currentUser.id
            
            let optimisticSpace = Space(
                id: spaceId,
                hostId: currentUser.id,
                hmsRoomId: hmsRoomId,
                speakerIdList: [],
                startTime: date,
                createdAt: Date(),
                updatedAt: Date(),
                speakers: [],
                queue: Queue(
                    id: spaceId,
                    name: nil,
                    description: nil,
                    isClosed: false,
                    participants: []
                ),
                host: currentUser.username,
                hostImageUrl: currentUser.avatar,
                hostUsername: nil,
                isBlockedFromSpace: false,
                topics: nil
            )

            Task { @MainActor in
                spaces.append(optimisticSpace)
                selectedSpace = optimisticSpace
            }

            // 5. Update optimistic space with channel URL
            Task { @MainActor in
                // Create new Space instance with updated channel URL
                let updatedSpace = Space(
                    id: optimisticSpace.id,
                    hostId: optimisticSpace.hostId,
                    hmsRoomId: optimisticSpace.hmsRoomId,
                    speakerIdList: optimisticSpace.speakerIdList,
                    startTime: optimisticSpace.startTime,
                    createdAt: optimisticSpace.createdAt,
                    updatedAt: optimisticSpace.updatedAt,
                    speakers: optimisticSpace.speakers,
                    queue: optimisticSpace.queue,
                    host: currentUser.username,
                    hostImageUrl: currentUser.avatar,
                    hostUsername: nil,
                    isBlockedFromSpace: false,
                    topics: nil
                )
                
                // Update local state
                if let index = self.spaces.firstIndex(of: optimisticSpace) {
                    self.spaces.remove(at: index)
                    self.spaces.insert(updatedSpace, at: index)
                }

                self.isInSpace = true

                if self.selectedSpace?.id == optimisticSpace.id {
                    self.selectedSpace = updatedSpace
                }
            }
           
            // 6. Persist to Supabase in background
            Task.detached {
                do {
                    let hostUUIDString = String(currentUser.id)
                    
                    let newSpace = SpaceInsert(
                        id: String(spaceId),
                        host_id: hostUUIDString,
                        hms_room_id: optimisticSpace.hmsRoomId,
                        queue: optimisticSpace.queue,
                        start_time: dateFormatter.string(from: date),
                        speaker_id_list: [hostUUIDString],
                        created_at: dateFormatter.string(from: Date()),
                        updated_at: dateFormatter.string(from: Date()),
                        host: currentUser.username,
                        host_image_url: currentUser.avatar,
                        host_username: currentUser.username,
                        topics: nil
                    )
                    
                  //  try await self.createQueue(for: optimisticSpace)
                  /*  await self.listenToQueueUpdates(for: optimisticSpace)*/

                    // Add logging before Supabase insert
                    print("\n📤 Preparing Supabase insert:")
                    print("  - Location string: \(locationString)")
                    print("  - Latitude band: \(latitudeBand)")
                    
                    // After Supabase insert, add result logging
                    print("\n✅ Supabase insert successful:")
                } catch {
                    print("\n❌ Supabase insert failed:")
                    print("  - Error: \(error)")
                    print("  - Location data that failed: \(locationString)")
                }
            }
        
    }

    actor ImageCacheManager {
        static let shared = ImageCacheManager()
        
        private let cache = NSCache<NSString, UIImage>()
        private let fileManager = FileManager.default
        private let cacheDirectory: URL
        
        init() {
            // Set up persistent cache directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            
            // Configure cache limits
            cache.countLimit = 200 // Maximum number of images
            cache.totalCostLimit = 1024 * 1024 * 500 // 500 MB
        }
        
        func image(for url: URL) async -> UIImage? {
            let key = url.absoluteString as NSString
            
            // Check memory cache first
            if let cachedImage = cache.object(forKey: key) {
                return cachedImage
            }
            
            // Check disk cache
            let diskCacheURL = cacheDirectory.appendingPathComponent(key.hash.description)
            if let data = try? Data(contentsOf: diskCacheURL),
               let image = UIImage(data: data) {
                // Move to memory cache
                cache.setObject(image, forKey: key)
                return image
            }
            
            // Download and cache if not found
            return await downloadAndCacheImage(from: url, key: key)
        }
        
        private func downloadAndCacheImage(from url: URL, key: NSString) async -> UIImage? {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                
                // Save to memory cache
                cache.setObject(image, forKey: key)
                
                // Save to disk cache
                let diskCacheURL = cacheDirectory.appendingPathComponent(key.hash.description)
                try? data.write(to: diskCacheURL)
                
                return image
            } catch {
                print("Failed to download image: \(error)")
                return nil
            }
        }
        
        func clearCache() {
            cache.removeAllObjects()
            try? fileManager.removeItem(at: cacheDirectory)
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    // Call this when app goes to background - REMOVED: Now handled in main SpacesViewModel
    // func handleAppBackground() {
    //     // Optionally clear memory cache but keep disk cache
    //     NSCache<NSString, UIImage>().removeAllObjects()
    // }

    struct PresignedURLResponse: Codable {
        let url: String
    }

    private func saveImageLocally(_ url: URL) -> URL? {
        print("📥 Starting local image save for URL: \(url)")
        let fileName = "\(UUID().uuidString).jpg"
        print("📄 Generated filename: \(fileName)")
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDirectory = documentsPath.appendingPathComponent("SpaceImages")
        let localURL = imagesDirectory.appendingPathComponent(fileName)
        
        print("📁 Target directory: \(imagesDirectory)")
        print("📍 Target local URL: \(localURL)")
        
        do {
            // Create directory if needed
            try FileManager.default.createDirectory(
                at: imagesDirectory,
                withIntermediateDirectories: true
            )
            print("📁 Directory created/verified")
            
            // Copy image to local storage
            try FileManager.default.copyItem(at: url, to: localURL)
            print("✅ Image copied successfully")
            return localURL
        } catch {
            print("❌ Failed to save image locally: \(error)")
            return nil
        }
    }

    // Add a method to update host space when user data changes
    @MainActor internal func updateHostSpaceWithUserData(user: UserProfile) {
        let userDefaults = UserDefaults.standard
        let hostSpaceKey = "hostSpace_\(user.id)"
        
        if let savedSpaceData = userDefaults.data(forKey: hostSpaceKey),
           let savedSpace = try? JSONDecoder().decode(Space.self, from: savedSpaceData) {
            
            // Update the space with current user data
            var updatedSpace = savedSpace
            updatedSpace.host = user.username
            updatedSpace.hostImageUrl = user.avatar
            updatedSpace.hostUsername = user.username
            
            // Update in spaces array
            if let index = spaces.firstIndex(where: { $0.id == savedSpace.id }) {
                spaces[index] = updatedSpace
            } else {
                spaces.append(updatedSpace)
            }
            
            // Save updated space back to UserDefaults
            if let encodedSpace = try? JSONEncoder().encode(updatedSpace) {
                userDefaults.set(encodedSpace, forKey: hostSpaceKey)
            }
            
            print("✅ Updated host space with new user data")
        }
    }

    
    

}

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

// Update SpaceInsert struct to match Space struct
internal struct SpaceInsert: Codable {
    let id: String
    let host_id: String
    let hms_room_id: String?
    let speaker_id_list: [String]
    let start_time: String
    let created_at: String
    let updated_at: String
    let queue: Queue
    let host: String
    let host_image_url: String
    let host_username: String
    let topics: [String]?
    
    init(id: String, host_id: String, hms_room_id: String?, queue: Queue,
         start_time: String, speaker_id_list: [String], created_at: String,
         updated_at: String, host: String, host_image_url: String,
         host_username: String, topics: [String]?) {
        self.id = id
        self.host_id = host_id
        self.hms_room_id = hms_room_id
        self.queue = queue
        self.start_time = start_time
        self.speaker_id_list = speaker_id_list
        self.created_at = created_at
        self.updated_at = updated_at
        self.host = host
        self.host_image_url = host_image_url
        self.host_username = host_username
        self.topics = topics
    }
}














