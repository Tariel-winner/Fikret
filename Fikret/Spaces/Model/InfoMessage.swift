//
//  InfoMessage.swift
//  Spaces
//
//  Created by Stefan Blos on 01.03.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import Foundation



struct InfoMessageV1: Identifiable {
    var id = UUID()
    var text: String
    var type: InfoMessageTypeV1 = .information
}

enum InfoMessageTypeV1: Equatable {
    case error
    case success
    case information
    case warning
}
