//
//  SoundIndicatorView.swift
//  SwiftUICallingKit
//
//  Display this animated view when users disable their video
//

import SwiftUI

public struct SoundIndicatorView: View {
    @State private var isSounding = false
     let zoomLevel: Int?
     
     init(zoomLevel: Int?) {
         self.zoomLevel = zoomLevel
     }
     
     private var componentScale: CGFloat {
         zoomLevel != nil ? 1.0 / 3.0 : 1.0
     }
    
    public var body: some View {
        HStack {
            ForEach(0 ..< 7) { rect in
                RoundedRectangle(cornerRadius: 2 * componentScale)
                    .frame(width: 3 * componentScale, height: .random(in: isSounding ? 16...32 : 8...24) * componentScale)
                    .foregroundColor(.white)
                    .animation(.easeInOut(duration: 0.25).delay(Double(rect) * 0.01).repeatForever(autoreverses: true), value: isSounding)
            }
            .onAppear {
                startSoundAnimation()
            }
        }
    }
    
    func startSoundAnimation() {
        isSounding.toggle()
    }
}

/*struct SoundIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        SoundIndicatorView()
            .preferredColorScheme(.dark)
    }
}*/
