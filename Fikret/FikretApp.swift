//
//  TwitterCloneApp.swift
//  TwitterClone
//
//  Created by Tariel on 04.05.2025.
//

import SwiftUI
import StoreKit
//import Firebase
import SafariServices
import CoreLocation
//import FirebaseCore
//import Stripe
//import FirebaseAppCheck

@main
struct FikretApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var deepLink: String?
    @State private var showBankAccountView = false
    @State private var isStripeOnboarding = false
    @StateObject private var tweetData = TweetData.shared
    @AppStorage("selectedTheme") private var selectedTheme = Theme.system
    @StateObject private var spacesViewModel = SpacesViewModel()
    @StateObject private var locationService = LocationService.shared
    @StateObject private var conversationManager = ConversationCacheManager.shared
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var inviteManager = InviteManager()
    @StateObject private var audioManager = WebMAudioPlaybackManager()
    @StateObject private var trendingTopicsService = TrendingTopicsService.shared
    @State private var inviteCode: String = ""
    @State private var showSpacesSheet = false
    var body: some Scene {
        // Main app window
        WindowGroup {
            Group {
                if tweetData.hasValidAuth {
                    TwitterTabView()
                        .environmentObject(tweetData)
                        .environmentObject(spacesViewModel)
                        .environmentObject(conversationManager)
                        .environmentObject(notificationManager)
                        .environmentObject(inviteManager)
                        .environmentObject(audioManager)
                        .environmentObject(trendingTopicsService)
                        .environmentObject(locationService)
                        .preferredColorScheme(selectedTheme.colorScheme)
       
                        .onAppear {
                            applyTheme(selectedTheme)
                            // Start notification polling when app launches
                            notificationManager.startPolling()
                        }
                        .transition(.opacity.combined(with: .scale))
                } else {
                    LandingView()
                        .environmentObject(tweetData)
                        .environmentObject(spacesViewModel)
                        .environmentObject(conversationManager)
                        .environmentObject(notificationManager)
                        .environmentObject(inviteManager)
                        .environmentObject(audioManager)
                        .environmentObject(trendingTopicsService)
                        .environmentObject(locationService)
                        .environment(\.inviteCode, inviteCode)
                        .preferredColorScheme(selectedTheme.colorScheme)
                        .onAppear {
                            applyTheme(selectedTheme)
                        }
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.easeInOut(duration: 0.5), value: tweetData.hasValidAuth)
        
        .sheet(isPresented: $showSpacesSheet) {
            // ✅ NATIVE SHEET: Use iOS native sheet for proper drag-to-dismiss
            SpacesListeningNowView(showConfirmationModal: .constant(false))
                .environmentObject(spacesViewModel)
                .environmentObject(tweetData)
                .environmentObject(conversationManager)
                .environmentObject(notificationManager)
                .environmentObject(inviteManager)
                .environmentObject(audioManager)
                .environmentObject(trendingTopicsService)
        }
        .overlay {
            // ✅ GLOBAL FLOATING INDICATOR: Appears above ALL views including fullscreen covers
            if spacesViewModel.isInSpace && spacesViewModel.isHost && !showSpacesSheet {
                floatingIndicator
                    .zIndex(99999) // Higher than any presentation layer
            }
        }
          .onChange(of: spacesViewModel.isInSpace) { isInSpace in
          
            if isInSpace && spacesViewModel.isHost {
                    // ✅ NATIVE SHEET: Show sheet immediately when entering space as host
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showSpacesSheet = true
                    }
                } else {
                // Hide sheet when leaving space - no delay
                showSpacesSheet = false
            }
        }
        // ✅ NATIVE SHEET: Add observer for showSpaceView changes to properly manage sheet state
        .onChange(of: spacesViewModel.showSpaceView) { showSpaceView in
            if !showSpaceView {
                // Hide sheet when showSpaceView becomes false
                showSpacesSheet = false
            }
        }
        .task {
                await tweetData.checkPersistentAuthentication()
                
                // ✅ FIXED: Only send location for authenticated users who have explicitly granted permission
                if tweetData.hasValidAuth {
                    // Check permission status first (this won't request permission, just check current status)
                    locationService.checkPermissionStatus()
                    
                    if locationService.locationPermissionGranted {
                        print("📍 [FikretApp] User is authenticated and has location permission, sending location to backend...")
                        locationService.sendLocationToBackend()
                    } else {
                        print("📍 [FikretApp] User is authenticated but no location permission, skipping location request")
                    }
                } else {
                    print("📍 [FikretApp] User not authenticated, skipping location request")
                }
                
                // Listen for invite code updates from AppFlyer
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("InviteCodeReceived"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let code = notification.userInfo?["code"] as? String {
                        print("🔔 Received invite code update from AppFlyer: \(code)")
                        inviteCode = code
                    }
                }
                
                // Check for stored invite code from AppFlyer on app launch
                if let storedInviteCode = UserDefaults.standard.string(forKey: "inviteCode") {
                    print("🎫 Found stored invite code from AppFlyer: \(storedInviteCode)")
                    inviteCode = storedInviteCode
                }
                
                if let user = tweetData.user {
                    print("👤 Initializing Ably with persistent user ID: \(user.id)")
                    AblyService.shared.initialize(userId: user.id)
                   
                } else {
                    print("⚠️ No persistent user found, initializing Ably without userId")
                    AblyService.shared.initialize()
                }
            }
            // AppFlyer handles all deep linking automatically
        }
        .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    // Update notification polling state
                    notificationManager.updateAppState(isActive: true)
                    Task {
                        await tweetData.checkPersistentAuthentication()
                    }
                case .inactive:
                    break
                case .background:
                    notificationManager.updateAppState(isActive: false)
                    AblyService.shared.unsubscribeFromUserChannel()
                    
                    // ✅ ADDED: Handle HMSDK sessions when app goes to background
                    handleAppBackground()
                @unknown default:
                    break
                }
            }
    }

 // ✅ FIXED: Separate component for floating indicator to reduce complexity
    // ✅ FIXED: Separate component for floating indicator to reduce complexity
private var floatingIndicator: some View {
    VStack {
        Spacer()
        
        // ✅ NATIVE SHEET: Make entire floating indicator tappable
        Button(action: {
            showSpacesSheet = true
        }) {
            HStack {
                HStack(spacing: 12) {
                    // Live indicator
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: spacesViewModel.isInSpace)
                    
                    // Call info
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Space")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Tap to return")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // ✅ FIXED: Arrow icon is now just visual, not a separate button
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.9), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Above tab bar
        }
        .buttonStyle(PlainButtonStyle()) // ✅ ADDED: Prevents default button styling
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: spacesViewModel.isInSpace)
        .zIndex(999)
    }
}





    
    private func applyTheme(_ theme: Theme) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            switch theme {
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
    
    // ✅ ADDED: Handle HMSDK sessions when app goes to background
    private func handleAppBackground() {
        print("📱 [FikretApp] App going to background - handling HMSDK sessions")
        
        // Check if user is currently in a space
        if spacesViewModel.isInSpace {
            if spacesViewModel.isHost {
                print("👑 [FikretApp] Host going to background - ending space automatically")
                // Host: End the space completely
                if let spaceId = spacesViewModel.selectedSpace?.id {
                    Task {
                        await spacesViewModel.endSpace(with: spaceId)
                    }
                }
            } else {
                print("👤 [FikretApp] Participant going to background - leaving space automatically")
                // Participant: Leave the space
                if let spaceId = spacesViewModel.currentViewingSpace?.id ?? spacesViewModel.selectedSpace?.id {
                    Task {
                        await spacesViewModel.leaveSpace(id: spaceId)
                    }
                }
            }
        } else {
            print("ℹ️ [FikretApp] User not in space - no HMSDK action needed")
        }
    }

    // MARK: - AppFlyer Deep Link Handling
    // AppFlyer handles all deep linking automatically through its delegate methods in AppDelegate

    private func handleStripeRedirect(url: URL) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            func findAndDismissSafariVC(from viewController: UIViewController) {
                if let safariVC = viewController as? SFSafariViewController {
                    safariVC.dismiss(animated: true) {
                        // Show AddBankAccountView after Safari dismissal
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showBankAccountView = true
                            
                            // Wait for view to appear before posting notification
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                NotificationCenter.default.post(
                                    name: Notification.Name("StripeOnboardingCompleted"),
                                    object: nil,
                                    userInfo: ["url": url]
                                )
                            }
                        }
                    }
                } else if let presented = viewController.presentedViewController {
                    findAndDismissSafariVC(from: presented)
                }
            }
            
            findAndDismissSafariVC(from: rootVC)
        } else {
            Task {
                await MainActor.run {
                    showBankAccountView = true
                }
            }
            
            // Wait for view to appear before posting notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(
                    name: Notification.Name("StripeOnboardingCompleted"),
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        }
    }
}


