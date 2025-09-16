//
//  SpacesViewModel+Preview.swift
//  Spaces
//
//  Created by Stefan Blos on 16.02.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import Foundation

extension SpacesViewModel {
    
    static var preview: SpacesViewModel {
        // Use the shared instance of TweetData for the preview
        let tweetData = TweetData.shared
        
      
        
        return SpacesViewModel()
    }
    
}
