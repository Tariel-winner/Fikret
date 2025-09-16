//
//  InfoMessageView.swift
//  Spaces
//
//  Created by Stefan Blos on 01.03.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import SwiftUI




struct InfoMessageView: View {
    
   private struct InfoMessage: Identifiable {
        var id = UUID()
        var text: String
        var type: InfoMessageType = .information
    }

    enum InfoMessageType: Equatable {
        case error
        case success
        case information
        case warning
    }

    private var infoMessage: InfoMessage
    
    var iconName: String {
        switch infoMessage.type {
        case .information:
            return "info.circle"
        case .error:
            return "xmark.circle"
        case .success:
            return "xmark.circle"
        case .warning:
            return "xmark.circle"
        }
    }
    
    var iconColor: Color {
        switch infoMessage.type {
        case .information:
            return .secondary
        case .error:
            return .red.opacity(0.5)
        case .success:
            return .secondary
        case .warning:
            return .secondary
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundColor(iconColor)
            
            Text(infoMessage.text)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background()
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(radius: 4)
    }
}

