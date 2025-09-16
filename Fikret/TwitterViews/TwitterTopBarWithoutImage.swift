//
//  TwitterTopBarWithoutProfile.swift
//  TwitterClone
//
//  Created by Rohit Sridharan on 20/04/23.
//

import SwiftUI

struct TwitterTopBarWithoutImage: View {
    var body: some View {
        ZStack{            
            HStack{
                Image("twitter-logo")
                    .resizable()
                    .frame(width: 35, height: 35)
            }.zIndex(2)
        }
    }
}

struct TwitterTopBarWithoutProfile_Previews: PreviewProvider {
    static var previews: some View {
        TwitterTopBarWithoutImage()
    }
}
