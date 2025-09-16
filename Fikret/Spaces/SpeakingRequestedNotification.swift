//
//  SpeakingRequestedNotification.swift
//  Spaces
//
//  Created by amos.gyamfi@getstream.io on 16.2.2023.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import SwiftUI

public struct SpeakingRequestedNotification: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var requestSent = false
    let message: String
    let systemImage: String
    
    public init(message: String, systemImage: String = "checkmark.circle.fill") {
        self.message = message
        self.systemImage = systemImage
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack { // Changed to center alignment
                LinearGradient(gradient: Gradient(colors: [
                    colorScheme == .light ? .streamLightStart : .streamDarkStart,
                    colorScheme == .light ? .streamLightEnd : .streamDarkEnd
                ]), startPoint: .top, endPoint: .bottom)
                .frame(width: min(geometry.size.width - 40, 400), height: 48)
                .cornerRadius(12)
                
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .symbolRenderingMode(.hierarchical)
                    Text(message)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
            .offset(y: requestSent ? geometry.safeAreaInsets.top + 20 : -200)
        }
        .frame(height: 48)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                requestSent = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    requestSent = false
                }
            }
        }
    }
}

struct SpeakingRequestedNotification_Previews: PreviewProvider {
    static var previews: some View {
        SpeakingRequestedNotification(message: "Ended  by Host")
    }
}
