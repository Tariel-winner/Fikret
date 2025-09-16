//
//  TTwinLogo.swift
//  TTwin

import SwiftUI

public struct TTwinLogo: View {

    public init() {}

    public var body: some View {
        Image("twitter-logo")
            .resizable()
            .scaledToFit()
            .frame(width: 32, height: 32)
    }
}

// struct TTwinLogo_Previews: PreviewProvider {
//    static var previews: some View {
//        TTwinLogo()
//            .preferredColorScheme(.dark)
//    }
// }
