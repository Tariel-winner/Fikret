import Foundation
import CoreLocation

struct SportEvent: Identifiable {
    let id: String
    let name: String
    let eventDate: Date
    let sport: String
    let venue: Venue
    
    struct Venue {
        let name: String
        let latitude: Double
        let longitude: Double
    }
} 