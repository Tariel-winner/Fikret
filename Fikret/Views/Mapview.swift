import SwiftUI
import MapKit
import RiveRuntime
/*
// Add these at the top level, after imports
struct MapDataResponseWrapper: Decodable {
    let type: String
    let payload: MapDataPayload
}

struct MapDataPayload: Decodable {
    let geometry: GeoJSONGeometry
    let point_count: Int
    let id: UUID?
    let name: String?
    let description: String?
    let host: String?
    let host_username: String?
    let host_image_url: String?
    let preview_image_url: String?
    let price: Double?
    let state: String?
    let host_id: UUID?
    let updated_at: Date?
    let hmsRoomId: String?
    
    enum CodingKeys: String, CodingKey {
        case geometry, point_count, id, name, description
        case host, host_username, host_image_url, preview_image_url
        case price, state, host_id, updated_at
        case hmsRoomId = "hmsRoomId"
    }
}

// Add this after imports
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let locationManager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    override private init() {
        authorizationStatus = .notDetermined
        
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
    }
    
    func requestLocationPermission() {
        print("📍 Requesting location permission...")
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("📍 Location authorization status changed: \(manager.authorizationStatus.rawValue)")
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("✅ Location access granted")
                manager.startUpdatingLocation()
            default:
                print("❌ Location access not granted")
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = location
        }
    }
    
    func getCurrentLocation() async -> CLLocationCoordinate2D? {
        return await withCheckedContinuation { continuation in
            if let location = currentLocation {
                continuation.resume(returning: location.coordinate)
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}

// MARK: - Event Models
/*private struct EventPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let importance: Double // 0.0 to 1.0
     let venueName: String
    let category: EventCategory
    let date: String
     var isSubscribed: Bool = false
    var subscriberCount: Int = 0
}*/

// MARK: - Events Manager



// First, add these models
struct SpaceCluster: Identifiable, Decodable {
    let cluster_id: Int
    let space_count: Int
    let centroid: CLLocationCoordinate2D
    let density: Float
    
    var id: Int { cluster_id }
    
    enum CodingKeys: String, CodingKey {
        case cluster_id
        case space_count
        case centroid
        case density
    }
    
    init(cluster_id: Int, space_count: Int, centroid: CLLocationCoordinate2D, density: Float) {
        self.cluster_id = cluster_id
        self.space_count = space_count
        self.centroid = centroid
        self.density = density
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cluster_id = try container.decode(Int.self, forKey: .cluster_id)
        space_count = try container.decode(Int.self, forKey: .space_count)
        density = try container.decode(Float.self, forKey: .density)
        
        // Decode GeoJSON centroid
        let centroidString = try container.decode(String.self, forKey: .centroid)
        if let coordinates = Self.parseGeoJSONPoint(centroidString) {
            centroid = coordinates
        } else {
            throw DecodingError.dataCorruptedError(forKey: .centroid, in: container, debugDescription: "Invalid centroid format")
        }
    }
    
    static func parseGeoJSONPoint(_ geoJSON: String) -> CLLocationCoordinate2D? {
        let components = geoJSON.replacingOccurrences(of: "POINT(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: " ")
        
        guard components.count == 2,
              let longitude = Double(components[0]),
              let latitude = Double(components[1]) else {
            return nil
        }
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init?(from response: MapDataResponseWrapper) {
        // Only process cluster type responses
        guard response.type == "cluster",
              let coordinates = response.payload.geometry.coordinate else {
            return nil
        }
        
        self.cluster_id = Int.random(in: 1...1000000)  // Generate random ID since clusters are temporary
        self.space_count = response.payload.point_count
        self.centroid = coordinates
        self.density = Float(response.payload.point_count) / 10000.0  // Normalize density
        
        print("""
        🔵 Created cluster:
        - ID: \(cluster_id)
        - Count: \(space_count)
        - Location: \(centroid.latitude), \(centroid.longitude)
        - Density: \(density)
        """)
    }
}

// Add these at the top level, after imports
struct ClusterFeature: Identifiable, Decodable {
    let id = UUID() // Add id for Identifiable conformance
    let point_count: Int
    let coordinate: CLLocationCoordinate2D
    
    enum CodingKeys: String, CodingKey {
        case point_count, coordinate
    }
   static func parseGeoJSONPoint(_ geoJSON: String) -> CLLocationCoordinate2D? {
        // Expected format: "POINT(longitude latitude)"
        let components = geoJSON.replacingOccurrences(of: "POINT(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: " ")
        
        guard components.count == 2,
              let longitude = Double(components[0]),
              let latitude = Double(components[1]) else {
            return nil
        }
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        point_count = try container.decode(Int.self, forKey: .point_count)
        
        // Decode coordinate from GeoJSON
        let coordinateString = try container.decode(String.self, forKey: .coordinate)
        if let coords = ClusterFeature.parseGeoJSONPoint(coordinateString) {
            coordinate = coords
        } else {
            throw DecodingError.dataCorruptedError(forKey: .coordinate, in: container, debugDescription: "Invalid coordinate format")
        }
    }
}

// Update SpacesMapManager
class SpacesMapManager: ObservableObject {
    static let shared = SpacesMapManager()
    
    weak var spacesViewModel: SpacesViewModel?
    @Published var clusters: [SpaceCluster] = []
    @Published var isLoading = false
    @Published var currentZoomLevel: Int = 0
    
    private var debounceTask: Task<Void, Never>? = nil
    private var lastLoadTime: Date = .distantPast
    private let minimumInterval: TimeInterval = 0.6
    private let loadingQueue = DispatchQueue(label: "com.app.mapLoading")
    private let loadingSemaphore = DispatchSemaphore(value: 1)
    
    func calculateZoomLevel(for distance: Double) -> Int {
        switch distance {
        case ...1_000: return 16     // Maximum zoom (street level)
        case ...10_000: return 15    // Detailed street level
        case ...50_000: return 14    // Neighborhood level
        case ...100_000: return 13   // City level
        case ...500_000: return 11   // Metropolitan level
        case ...1_000_000: return 9  // Regional level
        case ...2_000_000: return 7  // State level
        case ...5_000_000: return 5  // Country level
        case ...10_000_000: return 3 // Continental level
        default: return 2            // Global view
        }
    }
    
         func loadMapData(at coordinate: CLLocationCoordinate2D, zoom: Int, region: MKCoordinateRegion) {
             // Cancel any pending task
             debounceTask?.cancel()
    
             // Create new debounce task
             debounceTask = Task { [weak self] in
                 guard let self = self else { return }
    
                 do {
                     // Wait for debounce interval
                     try await Task.sleep(nanoseconds: UInt64(minimumInterval * 1_000_000_000))
    
                     // Check if task was cancelled during sleep
                    try Task.checkCancellation()
    
                    // Ensure minimum time between loads
                    let timeSinceLastLoad = Date().timeIntervalSince(self.lastLoadTime)
                     if timeSinceLastLoad < self.minimumInterval {
                         try await Task.sleep(nanoseconds: UInt64((self.minimumInterval - timeSinceLastLoad) * 1_000_000_000))
                     }
    
                     // Check cancellation again after second sleep
                     try Task.checkCancellation()
    
                     // Acquire semaphore with timeout
                   let semaphoreResult = self.loadingSemaphore.wait(timeout: .now() + 1.0)
                     guard semaphoreResult == .success else {
                         print("⚠️ Failed to acquire loading semaphore, skipping update")
                         return
                    }
    
                     defer {
                         self.loadingSemaphore.signal()
                     }
    
                     // Update loading state
                     await MainActor.run {
                         self.isLoading = true
                    }
    
                    // Perform the actual data fetch
                     await self.fetchMapData(region: region, zoom: zoom)
    
                 // Update last load time
                     self.lastLoadTime = Date()
    
                      await MainActor.run {
                        self.isLoading = false
                     }
    
                } catch is CancellationError {
                     print("🚫 Map data load cancelled")
                 } catch {
                    print("❌ Error loading map data: \(error)")
                await MainActor.run {
                        self.isLoading = false
                    }
                 }
             }
        }

    
func parseGeoJSONPoint(_ geoJSON: String) -> CLLocationCoordinate2D? {
        // Expected format: "POINT(longitude latitude)"
        let components = geoJSON.replacingOccurrences(of: "POINT(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: " ")
        
        guard components.count == 2,
              let longitude = Double(components[0]),
              let latitude = Double(components[1]) else {
            return nil
        }
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    private func fetchMapData(region: MKCoordinateRegion, zoom: Int) async {
        guard let spacesViewModel = spacesViewModel else { return }
        
        await MainActor.run {
            isLoading = true
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
                let viewport = """
        ST_SetSRID(ST_MakeEnvelope(
            \(region.minLongitude), \(region.minLatitude),
            \(region.maxLongitude), \(region.maxLatitude)
        ), 4326)
        """
      
        print("""
        🗺️ Fetching map data:
        - Zoom level: \(zoom)
        - Viewport: lat [\(region.minLatitude), \(region.maxLatitude)], lon [\(region.minLongitude), \(region.maxLongitude)]
        """)

      
        do {
           /* let query = try supabase.rpc(
                "get_map_data",
                params: [
                    "zoom_level": String(zoom),
                    "min_lon": String(region.minLongitude),
                    "min_lat": String(region.minLatitude),
                    "max_lon": String(region.maxLongitude),
                    "max_lat": String(region.maxLatitude)
                ] as [String: String]
            )
            print("📤 Sending request to Supabase get_map_data...")
                    let response: [MapDataResponseWrapper] = try await query.execute().value
                    print("""
                    📥 Map Data Response:
                    - Total items: \(response.count)
                    - Types breakdown: \(Dictionary(grouping: response, by: { $0.type }).mapValues { $0.count })
                    """)
            
             try Task.checkCancellation()

            await MainActor.run {
                var processedSpaceIds: [Int64] = []
                var newClusters: [SpaceCluster] = []
                
                // Store previous selection
                let previousSelectedID = spacesViewModel.selectedSpace?.id
                
                for item in response {
                    if item.type == "point" {
                        guard let id = item.payload.id,
                              let geometry = item.payload.geometry.coordinate else {
                            print("❌ Invalid point data received")
                            continue
                        }
                        
                        print("📍 Processing space: \(id)")
                     //   processedSpaceIds.append(id)
                        
                        let newSpace = Space(
                            id: 1,
                            name: item.payload.name ?? "",
                            description: item.payload.description,
                            hostId: 12,
                            channelUrl: "",
                            hmsRoomId: item.payload.hmsRoomId,
                            speakerIdList: [],
                            state: SpaceState(rawValue: item.payload.state ?? "") ?? .planned,
                            startTime: nil,
                            createdAt: Date(),
                            updatedAt: item.payload.updated_at ?? Date(),
                            host: item.payload.host ?? "",
                            hostImageUrl: item.payload.host_image_url,
                            hostUsername: item.payload.host_username ?? "",
                            price: item.payload.price ?? 0.0,
                            previewImageURL: item.payload.preview_image_url.flatMap { URL(string: $0) },
                            location: geometry,
                            latitudeBand: Int((geometry.latitude + 90) / 10)
                        )
                          print("Creating space with hostImageUrl: \(item.payload.host_image_url ?? "nil"), previewImageURL: \(item.payload.preview_image_url ?? "nil")")
                        
                       
                        // Update SpacesViewModel's spaces array
                      /* if let index = spacesViewModel.spaces.firstIndex(where: { $0.id == id }) {
                             
                            print("  🔄 Updating existing space \(id)")
                            print("  Old state: \(spacesViewModel.spaces[index].state)")
                
                        
                        
                            spacesViewModel.spaces[index].update(with: newSpace, preservingFieldsFrom: spacesViewModel.spaces[index])
                        print("  Final state: \(spacesViewModel.spaces[index].state)")
                        } else {
                             print("  ➕ Adding new space \(id)")
                            spacesViewModel.spaces.append(newSpace)
                        }*/
                        
                    } else if item.type == "cluster" {
                        // Create cluster from payload
                        print("🔵 Creating cluster with \(item.payload)")
                        print("🔵 Creating cluster with \(item.payload.geometry.coordinate)")
                        if let cluster = SpaceCluster(from: item) {
                            newClusters.append(cluster)
                            print("🔵 Added cluster with \(cluster.space_count) spaces")
                        }
                    }
                }
                
                // Clean up spaces that are no longer in view
                spacesViewModel.spaces.removeAll { !processedSpaceIds.contains($0.id) }
                
                // Restore selection if it still exists
                if let selectedID = previousSelectedID,
                   let updatedSpace = spacesViewModel.spaces.first(where: { $0.id == selectedID }) {
                    spacesViewModel.selectedSpace?.update(with: updatedSpace, preservingFieldsFrom: spacesViewModel.selectedSpace!, shouldUpdateQueue: false)
                }
                
                // Update clusters
                self.clusters = newClusters
                
                print("""
                📊 Update Summary:
                - Visible Spaces: \(spacesViewModel.spaces.count)
                - Active Clusters: \(newClusters.count)
                """)
            }*/
        } catch {
            await MainActor.run {
                print("""
                ❌ Error fetching map data:
                - Error: \(error)
                - Description: \(error.localizedDescription)
                """)
            }
        }
    }
    

}


// Add helper extensions
extension MKCoordinateRegion {
    var minLatitude: Double {
        center.latitude - span.latitudeDelta / 2
    }
    
    var maxLatitude: Double {
        center.latitude + span.latitudeDelta / 2
    }
    
    var minLongitude: Double {
        center.longitude - span.longitudeDelta / 2
    }
    
    var maxLongitude: Double {
        center.longitude + span.longitudeDelta / 2
    }
}

struct GeoJSONGeometry: Decodable {
    let type: String
    let coordinates: [Double]
    
    var coordinate: CLLocationCoordinate2D? {
        guard coordinates.count == 2 else { return nil }
        return CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
    }
}
// First, add this custom view
struct CustomZoomControl: View {
    @Binding var position: MapCameraPosition
    
    var body: some View {
        VStack(spacing: 8) {
            Button {
                           withAnimation {
                               if let camera = position.camera {
                                   position = .camera(
                                       MapCamera(
                                           centerCoordinate: camera.centerCoordinate,
                                           distance: min(camera.distance * 2, 20_000_000),
                                           heading: camera.heading,
                                           pitch: camera.pitch
                                       )
                                   )
                               }
                           }
                       } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Button {
                            withAnimation {
                                if let camera = position.camera {
                                    position = .camera(
                                        MapCamera(
                                            centerCoordinate: camera.centerCoordinate,
                                            distance: max(camera.distance * 0.5, 1000),
                                            heading: camera.heading,
                                            pitch: camera.pitch
                                        )
                                    )
                                }
                            }
                        }  label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

// Add this class before MapView struct
class SpaceAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let space: Space?
    let cluster: SpaceCluster?
    let title: String?
    
    // For individual spaces
    init(space: Space) {
        self.space = space
        self.cluster = nil
      
        super.init()
    }
    
    // For clusters
    init(cluster: SpaceCluster) {
        self.space = nil
        self.cluster = cluster
        self.coordinate = cluster.centroid
        self.title = "\(cluster.space_count) spaces"
        super.init()
    }
}
/*

struct RemoveUserConfirmationModal: View {
@Binding var isPresented: Bool
let userName: String
let onConfirm: () -> Void

var body: some View {
    VStack(spacing: 20) {
        Text("Remove \(userName)?")
            .font(.headline)
            .padding()

        Text("Are you sure you want to remove this user from the space?")
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .padding()

        HStack(spacing: 20) {
            Button("Cancel") {
                isPresented = false
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.secondary)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())

            Button("Remove") {
                onConfirm()
                isPresented = false
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding()
            .background(Color.red)
            .clipShape(Capsule())
        }
    }
    .padding()
    .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.systemBackground)))
    .shadow(color: .black.opacity(0.2), radius: 10)
    .padding()
}
}
*/

struct MinimizedViewDragIndicator: View {
    let action: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            Button(action: action) {
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 36, height: 4)
                    .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MinimizedQueueView: View {
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @Binding var showConfirmationModal: Bool
    @Binding var showUserTopicModal: Bool
    @Binding var selectedUserTopic: String?
    @State private var dragOffset: CGFloat = 0
    @State private var isPressed = false
    @State private var isAnimating = false
    
    var body: some View {
        Group {
            if spacesViewModel.isQueueSuperMinimized {
                MinimizedViewDragIndicator {
                    withAnimation(.spring()) {
                        spacesViewModel.isQueueSuperMinimized = false
                    }
                }
                .frame(height: 20)
            } else {
                VStack(spacing: 8) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)
                    
                    if let currentUser = currentUser {
                        HStack(spacing: 12) {
                            UserProfileView(currentUser: currentUser, isAnimating: isAnimating)
                            
                            UserInfoView(
                                currentUser: currentUser,
                                participantCount: spacesViewModel.selectedSpace?.queue.participants.count ?? 0,
                                showUserTopicModal: $showUserTopicModal,
                                selectedUserTopic: $selectedUserTopic
                            )
                            
                            Spacer()
                            
                            // Leave button
                            Button {
                                showConfirmationModal = true
                            } label: {
                                Text("Leave")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(
                                            colors: [.red, .orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: .red.opacity(0.3), radius: 5, x: 0, y: 2)
                            }
                            .buttonStyle(ScalesButtonStyle())
                        }
                        .padding(.horizontal)
                    }
                }
                .frame(height: 100)
                .background(
                    CustomRoundedRectangle(radius: 20, corners: [.topLeft, .topRight])
                        .fill(Color(UIColor.systemBackground).opacity(0.98))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -4)
                )
                .offset(y: max(0, dragOffset))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow downward dragging
                            dragOffset = max(0, value.translation.height)
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            withAnimation(.spring()) {
                                if value.translation.height > threshold {
                                    spacesViewModel.isQueueSuperMinimized = true
                                }
                                dragOffset = 0
                            }
                        }
                )
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                    spacesViewModel.isQueueMinimized = false
                    spacesViewModel.showQueueView = true
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onChange(of: spacesViewModel.showQueueView) { newValue in
            if newValue {
                spacesViewModel.isQueueMinimized = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    spacesViewModel.isQueueMinimized = false
                }
            }
        }
    }
    
    // MARK: - User Profile View
    private struct UserProfileView: View {
        let currentUser: QueueUser
        let isAnimating: Bool
        
        var body: some View {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 4)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                
                AsyncImage(url: URL(string: currentUser.image)) { phase in
                    switch phase {
                    case .empty, .failure:
                        Image(systemName: "person.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                            .frame(width: 48, height: 48)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
        }
    }
    
    // MARK: - User Info View
    private struct UserInfoView: View {
        let currentUser: QueueUser
        let participantCount: Int
        @Binding var showUserTopicModal: Bool
        @Binding var selectedUserTopic: String?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                // Name and verification
                HStack {
                    Text(currentUser.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if currentUser.isInvited {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                            .symbolEffect(.pulse)
                    }
                }
                
                // Topic button
                if let topic = currentUser.topic {
                    TopicButton(topic: topic, showUserTopicModal: $showUserTopicModal, selectedUserTopic: $selectedUserTopic)
                }
                
                // Status indicators
                StatusIndicators(position: currentUser.position, participantCount: participantCount)
            }
        }
    }
    
    // MARK: - Topic Button
    private struct TopicButton: View {
        let topic: String
        @Binding var showUserTopicModal: Bool
        @Binding var selectedUserTopic: String?
        
        var body: some View {
            Button {
                selectedUserTopic = topic
                withAnimation(.spring()) {
                    showUserTopicModal = true
                }
            } label: {
                Label("Topic", systemImage: "text.bubble.fill")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Status Indicators
    private struct StatusIndicators: View {
        let position: Int
        let participantCount: Int
        
        var body: some View {
            HStack(spacing: 6) {
                PositionIndicator(position: position)
                QueueCountIndicator(count: participantCount)
            }
        }
    }
    
    // MARK: - Helper Views
    private struct PositionIndicator: View {
        let position: Int
        
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                
                Text("#\(position)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.1))
            )
        }
    }
    
    private struct QueueCountIndicator: View {
        let count: Int
        
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                
                Text("\(count) in queue")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.1))
            )
        }
    }
    
    var currentUser: QueueUser? {
        guard let userId = spacesViewModel.tweetData.user?.id else { return nil }
        return spacesViewModel.selectedSpace?.queue.participants.first { $0.id == userId }
    }
}

struct CustomRoundedRectangle: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct MinimizedSpaceView: View {
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @Binding var showConfirmationModal: Bool
    @State private var isPressed = false
    @State private var isAnimating = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        Group {
            if spacesViewModel.isSpaceSuperMinimized {
                MinimizedViewDragIndicator {
                    withAnimation(.spring()) {
                        spacesViewModel.isSpaceSuperMinimized = false
                    }
                }
                .frame(height: 20)
            } else {
                VStack(spacing: 8) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)
                    
                    // Rest of your content
                   HStack(spacing: 16) {
                        // Your existing speaker section
                       /* if let speakers = spacesViewModel.selectedSpace?.speakers {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(speakers.prefix(2), id: \.id) { speaker in
                                        VStack(spacing: 4) {
                                            ZStack {
                                                // Enhanced speaker border animation
                                                if spacesViewModel.activeSpeakerId == speaker.peerID {
                                                    Circle()
                                                        .stroke(
                                                            LinearGradient(
                                                                colors: [.blue, .purple],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            ),
                                                            lineWidth: 2
                                                        )
                                                        .frame(width: 42, height: 42)
                                                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                                                        .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: isAnimating)
                                                }
                                                
                                                // Enhanced speaker avatar
                                                SpeakerAvatar(
                                                    image: spacesViewModel.peerImages[speaker.peerID!],
                                                    isActive: spacesViewModel.activeSpeakerId == speaker.peerID
                                                )
                                                .frame(width: 40, height: 40)
                                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                                
                                                // Enhanced audio wave indicator
                                                if spacesViewModel.activeSpeakerId == speaker.peerID {
                                                    AudioDetectionAnimation()
                                                        .frame(height: 8)
                                                        .offset(y: 24)
                                                        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                                                }
                                            }
                                            
                                            // Enhanced text elements
                                            VStack(spacing: 2) {
                                                Text(speaker.name ?? "")
                                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                    .lineLimit(1)
                                                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                                
                                                Text(
                                                    speaker.id != spacesViewModel.tweetData.user?.id && spacesViewModel.isHost == false ? "🔉 Host" :
                                                        speaker.id == spacesViewModel.tweetData.user?.id && spacesViewModel.isHost == true ? "🔉 Host" :
                                                        "🔇 Speaker"
                                                )
                                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                            }
                                        }
                                        .frame(width: 80)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                        }
                        */
                        Spacer()
                        
                        // Your existing status section
                        VStack(alignment: .trailing, spacing: 4) {
                            // Enhanced live indicator
                            HStack(spacing: 6) {
                                Text("🔴 LIVE")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.red)
                                
                                Text("\(spacesViewModel.selectedSpace?.listeners.count ?? 0)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.1))
                                    .shadow(color: .red.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                            
                            // Enhanced end/leave button
                            Button {
                                showConfirmationModal = true
                            } label: {
                                Text(spacesViewModel.isHost ? "End" : "Leave")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        LinearGradient(
                                            colors: [.red, .orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: .red.opacity(0.3), radius: 6, x: 0, y: 3)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            }
                        }
                        .padding(.trailing, 12)
                    }
                }
                .frame(height: 100)
                .background(
                    CustomRoundedRectangle(radius: 20, corners: [.topLeft, .topRight])
                        .fill(Color(UIColor.systemBackground).opacity(0.98))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -4)
                )
                .offset(y: max(0, dragOffset))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow downward dragging
                            dragOffset = max(0, value.translation.height)
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            withAnimation(.spring()) {
                                if value.translation.height > threshold {
                                    spacesViewModel.isSpaceSuperMinimized = true
                                }
                                dragOffset = 0
                            }
                        }
                )
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                    spacesViewModel.isSpaceMinimized = false
                    spacesViewModel.showSpaceView = true
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onChange(of: spacesViewModel.showSpaceView) { newValue in
            if newValue {
                spacesViewModel.isSpaceMinimized = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    spacesViewModel.isSpaceMinimized = false
                }
            }
        }
    }
    
}




private struct SpeakerAvatar: View {
    let image: UIImage?
    let isActive: Bool
    @EnvironmentObject var viewModel: SpacesViewModel
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size * 1, height: size * 1)
                        .clipShape(Circle())
                        .shadow(radius: 3)
                        .scaleEffect(isActive ? 1.2 : 1.0)
                } else {
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: size * 1, height: size * 1)
                        .clipShape(Circle())
                        .shadow(radius: 3)
                        .scaleEffect(isActive ? 1.2 : 1.0)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
/*
struct AudioDetectionAnimation: View {
@State private var animate = false

var body: some View {
    HStack(spacing: 2) { // Reduced spacing for a more compact look
        ForEach(0..<10) { index in
            Rectangle()
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.8), .blue.opacity(0.6)], // Darker blue colors
                    startPoint: .bottom,
                    endPoint: .top
                ))
                .frame(width: 3, height: CGFloat.random(in: 8...30)) // Smaller bars
                .scaleEffect(y: animate ? CGFloat.random(in: 0.5...1.5) : 1, anchor: .bottom)
                .animation(
                    Animation.easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                    value: animate
                )
        }
    }
    .onAppear {
        animate = true
    }
}
}*/




// Update EventMapView to handle both spaces and clusters
struct MapView: View {
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @StateObject private var spacesManager: SpacesMapManager = {
        let manager = SpacesMapManager.shared
        return manager
    }()
    @State private var selectedSpace: Space?
    @State private var selectedCluster: SpaceCluster?
    @State private var position: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 30, longitude: 0),
            distance: 20_000_000, // Much larger distance for global view
            heading: 0,
            pitch: 45 // Better angle for globe view
        )
    )
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
    )
    @State private var camera = MapCamera(
        centerCoordinate: CLLocationCoordinate2D(latitude: 30, longitude: 0),
        distance: 20_000_000,
        heading: 0,
        pitch: 45
    )
    

    
    // In MapView, add a debounce timer for camera changes
    @State private var cameraChangeTimer: Timer?
    
    var currentUser: QueueUser? {
                guard let userId = spacesViewModel.tweetData.user?.id else { return nil }
                return spacesViewModel.selectedSpace?.queue.participants.first { $0.id == userId }
            }
    
    var shouldShowSpaceSheet: Bool {
        guard let selectedSpace = spacesViewModel.selectedSpace else { return false }
        return spacesViewModel.showSpaceView && !selectedSpace.isBlockedFromSpace
    }
   /* var notificationOverlay: some View {
        Group {
            if let notification = spacesViewModel.activeNotification {
                SpeakingRequestedNotification(
                    message: notification.message,
                    systemImage: notification.isError ? "xmark.circle.fill" : "checkmark.circle.fill"
                )
                .transition(.move(edge: .top))
                .frame(maxWidth: .infinity)
            }
        }
    }*/
    // Similarly for queue sheet
    var shouldShowQueueSheet: Bool {
        guard let selectedSpace = spacesViewModel.selectedSpace else { return false }
        return spacesViewModel.showQueueView && !selectedSpace.isBlockedFromSpace
    }
    @State private var dragOffset = CGSize.zero
    
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmationModal = false
    @State private var showUserTopicModal = false
    @State private var selectedUserTopic: String?
    
    var body: some View {
        ZStack {
            Map(position: $position, interactionModes: [.all]) {
                // Render spaces
                ForEach(spacesViewModel.spaces) { space in
                    Annotation(space.name, coordinate: space.location!) {
                        SpaceCard(space: space, zoomLevel: spacesManager.currentZoomLevel)
                            .environmentObject(spacesViewModel)
                            .onTapGesture {
                                selectedSpace = space
                            }
                    }
                }
                
                // Render clusters
                ForEach(spacesManager.clusters) { cluster in
                    Annotation("\(cluster.space_count) spaces", coordinate: cluster.centroid) {
                        ClusterMarker(cluster: cluster, zoomLevel: spacesManager.currentZoomLevel)
                            .onTapGesture {
                                selectedCluster = cluster
                                // Zoom in when cluster is tapped
                                withAnimation {
                                    camera = MapCamera(
                                        centerCoordinate: cluster.centroid,
                                        distance: camera.distance * 0.5,
                                        heading: camera.heading,
                                        pitch: camera.pitch
                                    )
                                }
                            }
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapPitchToggle()
                MapScaleView()
                MapUserLocationButton()
            }
            .overlay(alignment: .trailing) {
                if #available(iOS 17.0, *) {
                    EmptyView()
                } else {
                    // Custom zoom control for iOS 16 and earlier
                    VStack(spacing: 8) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if let camera = position.camera {
                                    let newDistance = max(camera.distance * 0.5, 1000)
                                    position = .camera(
                                        MapCamera(
                                            centerCoordinate: camera.centerCoordinate,
                                            distance: newDistance,
                                            heading: camera.heading,
                                            pitch: camera.pitch
                                        )
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if let camera = position.camera {
                                    let newDistance = min(camera.distance * 2, 20_000_000)
                                    position = .camera(
                                        MapCamera(
                                            centerCoordinate: camera.centerCoordinate,
                                            distance: newDistance,
                                            heading: camera.heading,
                                            pitch: camera.pitch
                                        )
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.trailing, 16)
                    .padding(.vertical, 50)
                }
            }
            .onMapCameraChange { context in
                // Update the reset logic to use ViewModel
                let distance = spacesViewModel.spiderfyCenter?.distance(to: context.region.center) ?? 0
                /*if distance > 1000 { // Only reset if moved more than 1km
                    spacesViewModel.resetFanOut()
                }
                */
                // Update the position to match the current camera
                position = .camera(context.camera)
                camera = context.camera  // Update our camera state
                
                // Cancel existing timer
                cameraChangeTimer?.invalidate()
                
                // Set new timer
                cameraChangeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    // Only reset spiderfying if significant movement occurred
                    let distance = spacesViewModel.spiderfyCenter?.distance(to: context.region.center) ?? 0
                 
                }
                
                print("🗺️ Map camera changed:")
                print("- Distance: \(context.camera.distance)")
                print("- Zoom Level: \(spacesManager.calculateZoomLevel(for: context.camera.distance))")
                print("- Center: \(context.region.center)")
                
                let zoomLevel = spacesManager.calculateZoomLevel(for: context.camera.distance)
                spacesManager.currentZoomLevel = zoomLevel
                
                Task {
                    await spacesManager.loadMapData(
                        at: context.region.center,
                        zoom: zoomLevel,
                        region: context.region
                    )
                }
            }
            
            // Controls and overlays
            VStack {
                if !spacesViewModel.spaces.isEmpty {
                    Text("Zoom: \(spacesManager.currentZoomLevel)")
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                
                // Notification overlay
              //  notificationOverlay
                
                Spacer()
                
                // Location permission button
                if LocationManager.shared.authorizationStatus == .notDetermined {
                    Button("Enable Location") {
                        LocationManager.shared.requestLocationPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            
            // Add this - Side Panel Indicator
            HStack {
                Spacer()
                SidePanelIndicator()
                    .padding(.trailing, 4)
            }
            .zIndex(1) // Ensure it's above other content
            
            // Minimized views
            VStack {
                Spacer()
                if !spacesViewModel.showSpaceView && spacesViewModel.selectedSpace != nil && spacesViewModel.isInSpace {
                    MinimizedSpaceView(showConfirmationModal: $showConfirmationModal)
                        .transition(.move(edge: .bottom))
                }
                
                if !spacesViewModel.showQueueView && spacesViewModel.selectedSpace != nil && spacesViewModel.isInQueue && !spacesViewModel.isInSpace {
                    MinimizedQueueView(
                        showConfirmationModal: $showConfirmationModal,
                        showUserTopicModal: $showUserTopicModal,
                        selectedUserTopic: $selectedUserTopic
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            .ignoresSafeArea(.keyboard)
            
            // Confirmation modal
            if showConfirmationModal {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showConfirmationModal = false
                    }
                
                RemoveUserConfirmationModal(
                    isPresented: $showConfirmationModal,
                    userName: currentUser?.name ?? "User",
                    onConfirm: {
                        if spacesViewModel.isInSpace {
                            Task {
                                await spacesViewModel.spaceButtonTapped()
                            }
                        } else if spacesViewModel.isInQueue {
                            Task {
                                await spacesViewModel.queueButtonTapped()
                            }
                        }
                    }
                )
                .zIndex(1)
                .transition(.scale)
            }
            
            // Add the ConversationSidePanel here
            ConversationSidePanel()
                .zIndex(2) // Ensure it's above everything else
        }
        // Sheet modifiers
        .sheet(isPresented: Binding(
            get: { shouldShowQueueSheet },
            set: { if !$0 { spacesViewModel.showQueueView = false } }
        )) {
            if let selectedSpace = spacesViewModel.selectedSpace {
                QueueView()
                    .presentationDetents([.fraction(0.9)])
                    .onDisappear {
                        if !spacesViewModel.isInQueue && !spacesViewModel.isInSpace {
                            spacesViewModel.selectedSpace = nil
                        }
                    }
            }
        }
        .sheet(isPresented: Binding(
            get: { shouldShowSpaceSheet },
            set: { if !$0 { spacesViewModel.showSpaceView = false } }
        )) {
            if let selectedSpace = spacesViewModel.selectedSpace {
                SpacesListeningNowView(showConfirmationModal: $showConfirmationModal)
                    .presentationDetents([.fraction(0.9)])
                    .presentationDragIndicator(.visible)
                    .onDisappear {
                            if !spacesViewModel.isInSpace {
                                spacesViewModel.selectedSpace = nil
                            }
                        
                    }
            }
        }
        .onAppear {
            spacesManager.spacesViewModel = spacesViewModel
            Task {
                if let location = await LocationManager.shared.getCurrentLocation() {
                    position = .camera(
                        MapCamera(
                            centerCoordinate: location,
                            distance: 1000_000,
                            heading: 0,
                            pitch: 60
                        )
                    )
                }
            }
        }
    }
    
    // Add marker views
    struct SpaceMarker: View {
        let space: Space
        
        var body: some View {
            VStack(spacing: 4) {
                // Space preview image
                AsyncImage(url: space.previewImageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                
                // Space name
                Text(space.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
            }
        }
    }
    
    struct ClusterDetailView: View {
        let cluster: SpaceCluster
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            VStack(spacing: 16) {
                Text("Spaces in this area")
                    .font(.headline)
                
                Text("\(cluster.space_count) active spaces")
                    .foregroundColor(.secondary)
                
                // No need for loadLiveSpaces - just dismiss and let the map handle zooming
                Button("Show Spaces") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
    
    
    
    struct ClusterMarker: View {
        let cluster: SpaceCluster
        let zoomLevel: Int
        
        var body: some View {
            ZStack {
                // Global view (zoom <= 3)
                if zoomLevel <= 3 {
                    GlobalHeatmapMarker(count: cluster.space_count, density: cluster.density, coordinate: cluster.centroid)
                }
                // Continental view (zoom 4-5)
                else if zoomLevel <= 5 {
                    ContinentalClusterMarker(count: cluster.space_count, density: cluster.density)
                }
                // Country/Region view (zoom 6-8)
                else if zoomLevel <= 8 {
                    RegionalClusterMarker(count: cluster.space_count)
                }
                // City view (zoom 9-12)
                else if zoomLevel <= 12 {
                    CityClusterMarker(count: cluster.space_count)
                }
                // Neighborhood view (zoom > 12)
                else {
                    DetailedClusterMarker(count: cluster.space_count)
                }
            }
        }
    }
    
    // Add this enum before the GlobalHeatmapMarker struct
    enum MarkerStyle {
        case single
        case verySmall
        case small
        case medium
        case large
        
        var size: CGFloat {
            switch self {
            case .single: return 40
            case .verySmall: return 60
            case .small: return 100
            case .medium: return 140
            case .large: return 180
            }
        }
    }
    
    // Add this struct before the GlobalHeatmapMarker struct
    struct StandardClusterMarker: View {
        let count: Int
        let density: Float
        
        var body: some View {
            ZStack {
                // Outer heat layer
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                .red.opacity(Double(density)),
                                .orange.opacity(Double(density) * 0.7)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 90
                        )
                    )
                
                Text("\(count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
        }
    }
    
    // Different marker styles for each zoom level
    struct GlobalHeatmapMarker: View {
        let count: Int
        let density: Float
        let coordinate: CLLocationCoordinate2D
        
        private var markerStyle: MarkerStyle {
            switch count {
            case 1:
                return .single
            case 2...3:
                return .verySmall
            case 4...9:
                return .small
            case 10...50:
                return .medium
            default:
                return .large
            }
        }
        
        var body: some View {
            switch markerStyle {
            case .single:
                SingleSpaceMarker(coordinate: coordinate)
                    .frame(width: 40, height: 40)
            case .verySmall:
                // Small cluster for 2-3 spaces
                EarlyAdopterMarker(count: count)
                    .frame(width: 60, height: 60)
            case .small:
                // Growing cluster for 4-9 spaces
                SmallClusterMarker(count: count, density: density)
                    .frame(width: 100, height: 100)
            default:
                // Regular cluster visualization
                StandardClusterMarker(count: count, density: density)
                    .frame(width: markerStyle.size, height: markerStyle.size)
            }
        }
    }
    
    struct ContinentalClusterMarker: View {
        let count: Int
        let density: Float
        
        var body: some View {
            Circle()
                .fill(.blue.opacity(Double(density)))
                .frame(width: 120, height: 120)
                .overlay {
                    Text("\(count)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
        }
    }
    
    struct RegionalClusterMarker: View {
        let count: Int
        
        var body: some View {
            Circle()
                .fill(.purple.opacity(0.8))
                .frame(width: 80, height: 80)
                .overlay {
                    Text("\(count)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
        }
    }
    
    struct CityClusterMarker: View {
        let count: Int
        
        var body: some View {
            Circle()
                .fill(.indigo.opacity(0.9))
                .frame(width: 50, height: 50)
                .overlay {
                    Text("\(count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
        }
    }
    
    struct DetailedClusterMarker: View {
        let count: Int
        
        var body: some View {
            Circle()
                .fill(.green.opacity(0.9))
                .frame(width: 30, height: 30)
                .overlay {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
        }
    }
    
    struct SmallClusterMarker: View {
        let count: Int
        let density: Float
        
        var body: some View {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            .orange.opacity(0.8),
                            .yellow.opacity(0.5)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
                .overlay {
                    Text("\(count) spaces")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
        }
    }
    
    struct EarlyAdopterMarker: View {
        let count: Int
        
        var body: some View {
            Circle()
                .fill(.purple.opacity(0.7))
                .frame(width: 60, height: 60)
                .overlay {
                    VStack {
                        Text("\(count)")
                            .font(.system(size: 16, weight: .bold))
                        Text("New!")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                }
        }
    }
    
    struct SingleSpaceMarker: View {
        let coordinate: CLLocationCoordinate2D
        
        var body: some View {
            Circle()
                .fill(.blue.opacity(0.8))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                }
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: 2)
                }
        }
    }
    
    // Helper extension for coordinate calculations
    
    
    // Update SpaceDetailView to remove drag gesture and add better navigation
    struct SpaceDetailView: View {
        let space: Space
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Preview image
                    if let imageUrl = space.previewImageURL {
                        AsyncImage(url: imageUrl) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Space details
                    VStack(alignment: .leading, spacing: 8) {
                        Text(space.name)
                            .font(.title2)
                            .bold()
                        
                        if let description = space.description {
                            Text(description)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Host info
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: space.hostImageUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(space.hostUsername!)
                                .font(.headline)
                            Text("Host: \(space.host)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Price if applicable
                    if space.price > 0 {
                        Text("Price: $\(space.price, specifier: "%.2f")")
                            .font(.headline)
                            .padding(.vertical, 4)
                    }
                    
                    // Location info
                    Text("Location: \(space.location!.latitude), \(space.location!.longitude)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
    
   
struct ConversationSidePanel: View {
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @EnvironmentObject var conversationManager: ConversationCacheManager
    @State private var offset: CGFloat = UIScreen.main.bounds.width
    @State private var dragOffset: CGFloat = 0
    
    private let screenWidth = UIScreen.main.bounds.width
    private let dragThreshold: CGFloat = 50
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Background overlay
                if spacesViewModel.isSidePanelVisible {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeSidePanel()
                        }
                }
                
                HStack(spacing: 0) {
                    // Vertical drag indicator
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 4, height: 60)
                        .padding(.trailing, 8)
                    
                    // Main content
                    VStack(spacing: 0) {
                        // Add drag indicator at the top
                        Capsule()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 36, height: 4)
                            .padding(.vertical, 12)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(conversationManager.feedConversations) { conversation in
                                    ConversationItem(conversation: conversation,zoomLevel: nil)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .frame(width: geometry.size.width * 0.85)
                    .background(Color(UIColor.systemBackground))
                }
                .offset(x: offset + dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow dragging to the right
                            dragOffset = max(0, value.translation.width)
                        }
                        .onEnded { value in
                            if value.translation.width > dragThreshold ||
                               value.predictedEndTranslation.width > dragThreshold {
                                closeSidePanel()
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
        }
        .onChange(of: spacesViewModel.isSidePanelVisible) { newValue in
            withAnimation(.spring()) {
                offset = newValue ? 0 : screenWidth
                dragOffset = 0
                
                // Minimize other views when side panel opens
                if newValue {
                    if spacesViewModel.isInSpace {
                        spacesViewModel.isSpaceSuperMinimized = true
                        spacesViewModel.showSpaceView = false
                    }
                    if spacesViewModel.isInQueue {
                        spacesViewModel.isQueueSuperMinimized = true
                        spacesViewModel.showQueueView = false
                    }
                }
            }
        }
        .onAppear {
            conversationManager.loadFeedConversations()
        }
    }
    
    private func closeSidePanel() {
        withAnimation(.spring()) {
            offset = screenWidth
            dragOffset = 0
            spacesViewModel.isSidePanelVisible = false
        }
    }
}

// Add this struct for individual conversation items
struct ConversationItemView: View {
    let space: Space
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Host info
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: space.hostImageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(space.hostUsername ?? "")
                        .font(.headline)
                    Text("Host")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if space.state == .running {
                    Text("LIVE")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            
            // Space info
            Text(space.name)
                .font(.title3)
                .bold()
            
            if let description = space.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Participants info
            HStack {
                Image(systemName: "person.3.fill")
                Text("\(space.speakers.count) speakers")
                
                Spacer()
                
                Image(systemName: "person.2.fill")
                Text("\(space.listeners.count) listening")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

struct SpaceDragIndicator: View {
    var body: some View {
        VStack(spacing: 8) {
            // Drag indicator pill
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 36, height: 4)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            
            // Space indicator
            HStack(spacing: 6) {
                Image(systemName: "mic.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 14))
                
                Text("Space")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 3)
            )
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5)
        )
        .padding(.horizontal)
    }
}

// Add a reusable drag indicator view
struct DragIndicatorView: View {
    let title: String
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 50 {
                        withAnimation(.spring()) {
                            // Only handle the active sheet
                            if spacesViewModel.isInSpace {
                                spacesViewModel.showSpaceView = false
                                spacesViewModel.isSpaceSuperMinimized = true
                            } else if spacesViewModel.isInQueue {
                                spacesViewModel.showQueueView = false
                                spacesViewModel.isQueueSuperMinimized = true
                            }
                            
                            // If side panel is visible, close it
                            if spacesViewModel.isSidePanelVisible {
                                spacesViewModel.isSidePanelVisible = false
                            }
                        }
                    }
                }
        )
    }
}

struct SidePanelIndicator: View {
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    
    var body: some View {
        VStack {
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 4, height: 60)
                .padding(.vertical, 4)
        }
        .frame(width: 20)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width < 0 {
                        withAnimation(.spring()) {
                            spacesViewModel.isSidePanelVisible = true
                        }
                    }
                }
        )
        .onTapGesture {
            withAnimation(.spring()) {
                spacesViewModel.isSidePanelVisible = true
            }
        }
    }
}

    
}

    extension CLLocationCoordinate2D {
        func distance(to coordinate: CLLocationCoordinate2D) -> Double {
            let location1 = CLLocation(latitude: latitude, longitude: longitude)
            let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return location1.distance(from: location2)
        }
    }

func overlappingSpaces(at coordinate: CLLocationCoordinate2D, in spaces: [Space], thresholdMeters: Double = 100) -> [Space] {
    print("Checking for overlapping spaces at \(coordinate)")
    let overlapping = spaces.filter {
        guard let loc = $0.location else { return false }
        let distance = coordinate.distance(to: loc)
        print("Space \($0.id) distance: \(distance)m")
        return distance < thresholdMeters
    }
    print("Found \(overlapping.count) overlapping spaces")
    return overlapping
}

func fanOutPositions(center: CLLocationCoordinate2D, count: Int, radiusMeters: Double = 30) -> [CLLocationCoordinate2D] {
    guard count > 1 else { return [center] }
    let earthRadius = 6378137.0 // meters
    let dLat = { (meters: Double) in meters / earthRadius * 180.0 / .pi }
    let dLon = { (meters: Double, lat: Double) in meters / (earthRadius * cos(.pi * lat / 180.0)) * 180.0 / .pi }
    return (0..<count).map { i in
        let angle = 2 * .pi * Double(i) / Double(count)
        let lat = center.latitude + dLat(radiusMeters * cos(angle))
        let lon = center.longitude + dLon(radiusMeters * sin(angle), center.latitude)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

private func areCoordinatesEqual(_ coord1: CLLocationCoordinate2D?, _ coord2: CLLocationCoordinate2D?) -> Bool {
    guard let c1 = coord1, let c2 = coord2 else { return false }
    return c1.latitude == c2.latitude && c1.longitude == c2.longitude
}


*/
