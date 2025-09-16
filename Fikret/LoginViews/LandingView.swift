//
//  LandingView.swift
//  TwitterClone
//
//  Created by Rohit Sridharan on 20/04/23.
//

import SwiftUI

struct LandingView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var tweetData: TweetData
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Premium dark background with subtle gradient
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.1, green: 0.05, blue: 0.15),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Animated floating particles for premium feel
                ForEach(0..<15, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.4),
                                    Color.blue.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: CGFloat.random(in: 3...8))
                        .offset(
                            x: CGFloat.random(in: -200...400),
                            y: CGFloat.random(in: -100...800)
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 4...10))
                            .repeatForever(autoreverses: true),
                            value: UUID()
                        )
                }
                
                VStack(spacing: 50) {
                    Spacer()
                    
                    // Premium App Icon with advanced effects
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.purple.opacity(0.6),
                                        Color.blue.opacity(0.4),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 160, height: 160)
                            .blur(radius: 25)
                            .scaleEffect(1.3)
                            .opacity(0.4)
                            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: UUID())
                        
                        // Middle glow ring
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 140, height: 140)
                            .blur(radius: 15)
                            .scaleEffect(1.1)
                            .opacity(0.6)
                            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: UUID())
                        
                        // Icon background with glassmorphism
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        // Main microphone icon with gradient overlay
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: UUID())
                    
                    // App branding with premium typography
                    VStack(spacing: 12) {
                        Text("Fikret")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .white.opacity(0.4), radius: 15, x: 0, y: 8)
                        

                    }
                    
                    Spacer()
                    
                    // Premium Get Started button
                    NavigationLink {
                        SignupView()
                            .environmentObject(tweetData)
                            .environmentObject(spacesViewModel)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 22, weight: .semibold))
                            
                            Text("Join")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .shadow(color: .white.opacity(0.4), radius: 20, x: 0, y: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: UUID())
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct LandingView_Previews: PreviewProvider {
    static var previews: some View {
        LandingView()
            .environmentObject(TweetData.shared)
            .environmentObject(SpacesViewModel())
    }
}
