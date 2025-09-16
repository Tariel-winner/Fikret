//
//  SpaceState.swift
//  Spaces
//
//  Created by Stefan Blos on 16.02.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import Foundation

enum SpaceState: String, Codable, Hashable {
    case planned = "planned"
    case running = "running"
    case finished = "finished"
    
    var cardString: String {
        switch self {
        case .planned:
            return "Planned"
        case .running:
            return "Live"
        case .finished:
            return "Ended"
        }
    }
    
    // Custom decoder for handling different string cases
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        
        switch rawValue {
        case "planned", "Planned":
            self = .planned
        case "running", "Running", "live", "Live":
            self = .running
        case "finished", "Finished", "ended", "Ended":
            self = .finished
        default:
            self = .planned // Default to planned if unknown state
        }
    }
    
    // Helper method for string conversion
    static func from(_ string: String) -> SpaceState {
        switch string.lowercased() {
        case "planned", "Planned":
            return .planned
        case "running", "Running", "live", "Live":
            return .running
        case "finished", "Finished", "ended", "Ended":
            return .finished
        default:
            return .planned
        }
    }
}
