import SwiftUI
//import Supabase
import Ably
import CoreLocation
import Security
import Foundation

// Add this to TweetData.swift

// MARK: - Location Data Model
struct LocationData: Codable {
    let name: String
    let lat: Double
    let lng: Double
    let address: String
    let city: String
    let state: String
    let country: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case lat
        case lng
        case address
        case city
        case state
        case country
    }
    
    // Create from CLLocation and CLPlacemark
    init(location: CLLocation, placemark: CLPlacemark? = nil) {
        self.lat = location.coordinate.latitude
        self.lng = location.coordinate.longitude
        
        if let placemark = placemark {
            // ✅ IMPROVED: Better name extraction
            self.name = placemark.name ?? placemark.locality ?? placemark.administrativeArea ?? placemark.country ?? ""
            
            // ✅ IMPROVED: Better address construction with proper street-level data
            var addressComponents: [String] = []
            
            // Add street number and name (most specific)
            if let subThoroughfare = placemark.subThoroughfare, !subThoroughfare.isEmpty {
                addressComponents.append(subThoroughfare)
            }
            if let thoroughfare = placemark.thoroughfare, !thoroughfare.isEmpty {
                addressComponents.append(thoroughfare)
            }
            
            // Add neighborhood or sublocality
            if let subLocality = placemark.subLocality, !subLocality.isEmpty {
                addressComponents.append(subLocality)
            }
            
            // Add city
            if let locality = placemark.locality, !locality.isEmpty {
                addressComponents.append(locality)
            }
            
            // Add state/province
            if let administrativeArea = placemark.administrativeArea, !administrativeArea.isEmpty {
                addressComponents.append(administrativeArea)
            }
            
            // Add country
            if let country = placemark.country, !country.isEmpty {
                addressComponents.append(country)
            }
            
            self.address = addressComponents.joined(separator: ", ")
            
            // ✅ IMPROVED: Better field mapping
            self.city = placemark.locality ?? ""
            self.state = placemark.administrativeArea ?? ""
            self.country = placemark.country ?? ""
            
            print("📍 [LocationService] Parsed location data:")
            print("  - Name: \(self.name)")
            print("  - Address: \(self.address)")
            print("  - City: \(self.city)")
            print("  - State: \(self.state)")
            print("  - Country: \(self.country)")
            print("  - Thoroughfare: \(placemark.thoroughfare ?? "nil")")
            print("  - SubThoroughfare: \(placemark.subThoroughfare ?? "nil")")
            print("  - SubLocality: \(placemark.subLocality ?? "nil")")
        } else {
            self.name = ""
            self.address = ""
            self.city = ""
            self.state = ""
            self.country = ""
        }
    }
    
    // ✅ ADDED: Custom initializer for creating from individual parameters
    init(name: String, lat: Double, lng: Double, address: String, city: String, state: String, country: String) {
        self.name = name
        self.lat = lat
        self.lng = lng
        self.address = address
        self.city = city
        self.state = state
        self.country = country
    }
    
    // Create basic location data for backend
    func toBackendFormat() -> [String: Any] {
        return [
            "name": name,
            "lat": lat,
            "lng": lng,
            "address": address,
            "city": city,
            "state": state,
            "country": country
        ]
    }
}


// MARK: - Location Update API
func updateUserLocation(_ locationData: LocationData) async throws -> Bool {
    guard let token = try KeychainManager.shared.getToken() else {
        throw AuthError.notAuthenticated
    }
    
    print("🌍 [API] Updating user location: \(locationData.city), \(locationData.country)")
    
    let url = URL(string: "\(AuthConfig.baseURL)/v1/user/location")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Create request body
    let requestBody = [
        "locationData": locationData.toBackendFormat()
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
        throw AuthError.networkError("Failed to encode location data: \(error.localizedDescription)")
    }
    
    print("🌍 Making request to: \(url.absoluteString)")
    if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
        print("📝 Request JSON: \(jsonString)")
    }
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw AuthError.networkError("Invalid response")
    }
    
    guard httpResponse.statusCode == 200 else {
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw AuthError.networkError("Update location failed: \(httpResponse.statusCode) - \(errorMessage)")
    }
    
    print("📥 Received location update response")
    if let jsonString = String(data: data, encoding: .utf8) {
        print("📝 Response JSON: \(jsonString)")
    }
    
    // Decode response
    let locationResponse = try JSONDecoder().decode(LocationUpdateResponse.self, from: data)
    
    guard locationResponse.code == 0 else {
        throw AuthError.networkError(locationResponse.msg)
    }
    
    guard let responseData = locationResponse.data else {
        throw AuthError.networkError("No data in location update response")
    }
    
    print("✅ Successfully updated location: \(responseData.message)")
    
    return responseData.success
}

// MARK: - Response Models
struct LocationUpdateResponse: Codable {
    let code: Int
    let msg: String
    let data: LocationUpdateData?
}

struct LocationUpdateData: Codable {
    let success: Bool
    let message: String
}

// MARK: - Location Service
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var locationPermissionGranted = false
    @Published var locationPermissionRequested = false
    @Published var locationData: LocationData?
    
    private override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        checkPermissionStatus()
    }
    
    func checkPermissionStatus() {
        let status = locationManager.authorizationStatus
        locationPermissionGranted = (status == .authorizedWhenInUse || status == .authorizedAlways)
        print("📍 LocationService: Permission status: \(status.rawValue), granted: \(locationPermissionGranted)")
    }
    
    func checkLocationPermissionStatus() {
        checkPermissionStatus()
    }
    
    func requestPermission() {
        guard !locationPermissionGranted else { return }
        locationPermissionRequested = true
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getCurrentLocation() {
        guard locationPermissionGranted else { 
            print("📍 [LocationService] Cannot get location - permission not granted")
            return 
        }
        
        // Double-check permission status before requesting location
        let currentStatus = locationManager.authorizationStatus
        guard currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways else {
            print("📍 [LocationService] Cannot get location - permission status is \(currentStatus.rawValue)")
            return
        }
        
        print("📍 [LocationService] Requesting current location...")
        locationManager.requestLocation()
    }
    
    // MARK: - Simple Location Send
    
    /// Send location to backend - only if permission is already granted
    func sendLocationToBackend() {
        print("📍 [LocationService] Attempting to send location to backend")
        
        // Check permission first
        checkPermissionStatus()
        
        if !locationPermissionGranted {
            print("📍 [LocationService] No permission, skipping location send")
            return
        }
        
        // Get current location
        print("📍 [LocationService] Getting current location...")
        getCurrentLocation()
    }
    
    /// Send location data to backend with retry
    private func sendLocationData(_ locationData: LocationData) {
        Task {
            await updateLocationWithRetry(locationData, retryCount: 0)
        }
    }
    
    /// Update location with simple retry logic
    private func updateLocationWithRetry(_ locationData: LocationData, retryCount: Int) async {
        let maxRetries = 3
        
        do {
            print("🌍 [LocationService] Sending location to backend (attempt \(retryCount + 1))")
            let success = try await updateUserLocation(locationData)
            
            if success {
                print("✅ [LocationService] Location sent successfully")
                return
            } else {
                throw AuthError.networkError("Backend returned success=false")
            }
            
        } catch {
            print("❌ [LocationService] Location update failed: \(error.localizedDescription)")
            
            if retryCount < maxRetries {
                let delay = 2.0 * Double(retryCount + 1) // 2s, 4s, 6s
                print("🔄 [LocationService] Retrying in \(delay) seconds...")
                
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await updateLocationWithRetry(locationData, retryCount: retryCount + 1)
            } else {
                print("❌ [LocationService] Max retries reached, giving up")
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        print("📍 LocationService: Location received: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        currentLocation = location
        
        // Geocode the location
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Geocoding failed: \(error.localizedDescription)")
                    self.locationData = LocationData(location: location)
                    // Send even without geocoding
                    self.sendLocationData(self.locationData!)
                    return
                }
                
                let placemark = placemarks?.first
                self.locationData = LocationData(location: location, placemark: placemark)
                print("✅ LocationService: Geocoding successful")
                
                // Send location to backend
                self.sendLocationData(self.locationData!)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationService: Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.locationPermissionRequested = false
            self.checkPermissionStatus()
            
            if self.locationPermissionGranted {
                print("📍 [LocationService] Permission granted, getting location...")
                self.getCurrentLocation()
            } else {
                print("📍 [LocationService] Permission denied")
            }
        }
    }
}