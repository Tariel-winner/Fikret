//
//  SignupView.swift
//  TwitterClone
//
//  Created by Rohit Sridharan on 21/04/23.
//
//  VALIDATION REQUIREMENTS (matching backend):
//  - Password: 6-16 characters
//  - Username: 3-12 alphanumeric characters (letters + numbers only), must be unique
//  - Name: Required, minimum 2 characters
//  - Email: Required for frontend, not used by backend
//  - Categories: Required, 1-6 categories
//

import SwiftUI
import Contacts
import UserNotifications
import CoreLocation

// MARK: - Location Manager Delegate
class SignupLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isRequestingPermission = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        guard authorizationStatus == .notDetermined else { return }
        
        isRequestingPermission = true
        
        // ✅ MODIFIED: Use requestAlwaysAuthorization() to show only 2 options:
        // "Allow" (persistent) and "Don't Allow" - no "Allow Once" option
        locationManager.requestAlwaysAuthorization()
        
        print("📍 [SignupLocationManager] Requesting always authorization - shows only 2 options")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isRequestingPermission = false
            print("📍 Location authorization status changed to: \(status.rawValue)")
        }
    }
    
    var isLocationPermissionGranted: Bool {
        // ✅ UPDATED: Now checks for both when-in-use and always authorization
        // Since we're requesting always authorization, this will be .authorizedAlways
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
}

// MARK: - Environment Key for Invite Code
private struct InviteCodeKey: EnvironmentKey {
    static let defaultValue: String = ""
}

extension EnvironmentValues {
    var inviteCode: String {
        get { self[InviteCodeKey.self] }
        set { self[InviteCodeKey.self] = newValue }
    }
}

struct SignupView: View {
    @EnvironmentObject var tweetData: TweetData
    @EnvironmentObject var spacesViewModel: SpacesViewModel
    @Environment(\.inviteCode) private var inviteCode: String

    @State private var currentStep = 0
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var message = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var isValidEmail = false
    @State private var isValidPassword = false
    @State private var isValidUsername = false
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    // Manual invite code input fallback (when AppFlyer fails)
    @State private var manualInviteCode: String = ""
    @State private var showManualInput = false
    
    // Category selection states
    @State private var selectedCategories: Set<Int64> = []
    @State private var availableCategories: [Category] = []
    @State private var isLoadingCategories = false
    @State private var categorySelectionError = ""
    
    // Contacts permission states
    @State private var contactsPermissionGranted = false
    @State private var contactsPermissionRequested = false
    @State private var collectedContacts: [ContactItem] = []
    
    // Location permission using proper delegate
    @StateObject private var locationManager = SignupLocationManager()
  
    @FocusState private var emailIsFocused: Bool
    @FocusState private var passwordIsFocused: Bool
    @FocusState private var usernameIsFocused: Bool
    @FocusState private var nameIsFocused: Bool
    @FocusState private var inviteCodeIsFocused: Bool
    
    private enum Design {
        static let cornerRadius: CGFloat = 20
        static let buttonHeight: CGFloat = 50
        static let imageSize: CGFloat = 120
        static let spacing: CGFloat = 20
    }
    
    var isInviteCodeValid: Bool {
        // Check both environment invite code (from AppFlyer) and manual input (for testing)
        let currentInviteCode = inviteCode.isEmpty ? manualInviteCode : inviteCode
        return InviteManager.isValidInviteCode(currentInviteCode)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.2, green: 0.1, blue: 0.3),
                        Color(red: 0.1, green: 0.2, blue: 0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Animated floating particles
                ForEach(0..<20, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.3),
                                    Color.blue.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: CGFloat.random(in: 4...12))
                        .offset(
                            x: CGFloat.random(in: -200...400),
                            y: CGFloat.random(in: -100...800)
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 3...8))
                            .repeatForever(autoreverses: true),
                            value: UUID()
                        )
                }
                
                ScrollView {
                    VStack(spacing: Design.spacing) {
                        // Invite code validation (hidden, automatic from deep link)
                        if !isInviteCodeValid {
                            VStack(alignment: .center, spacing: 24) {
                                Image(systemName: "envelope.badge")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Invitation Required")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 20) {
                                    Text("You need an invitation to join Fikret. Ask a friend to send you an invite link, or enter the invite code manually if the link doesn't work.")
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    // Manual invite code input fallback
                                    VStack(spacing: 16) {
                                        if !showManualInput {
                                            Button(action: {
                                                withAnimation(.spring()) {
                                                    showManualInput = true
                                                }
                                            }) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "key.fill")
                                                    Text("Enter Invite Code Manually")
                                                }
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(Color.purple.opacity(0.8))
                                                )
                                            }
                                        } else {
                                            VStack(spacing: 12) {
                                                ModernTextField(
                                                    text: $manualInviteCode,
                                                    placeholder: "Enter invite code (e.g., FIK-12345)",
                                                    icon: "key.fill"
                                                )
                                                .focused($inviteCodeIsFocused)
                                                
                                                if !manualInviteCode.isEmpty {
                                                    Text(isInviteCodeValid ? "✅ Valid invite code" : "❌ Invalid invite code")
                                                        .font(.caption)
                                                        .foregroundColor(isInviteCodeValid ? .green : .red)
                                                }
                                                
                                                // Help text for manual input
                                                VStack(spacing: 8) {
                                                    Text("If the invite link didn't work, ask your friend for the invite code and enter it here.")
                                                        .font(.caption)
                                                        .foregroundColor(.white.opacity(0.6))
                                                        .multilineTextAlignment(.center)
                                                }
                                                .padding(.top, 8)
                                            }
                                        }
                                    }
                                    
                                    // Helpful instructions
                                    VStack(spacing: 12) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "person.2.fill")
                                                .foregroundColor(.blue)
                                            Text("Ask a friend who's already on Fikret")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        
                                        HStack(spacing: 12) {
                                            Image(systemName: "link")
                                                .foregroundColor(.green)
                                            Text("They'll send you an invite link")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        
                                        HStack(spacing: 12) {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .foregroundColor(.purple)
                                            Text("Tap the link to open this app")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                                
                                // Contact support button
                                Button(action: {
                                    // You can add support contact action here
                                    if let url = URL(string: "mailto:support@fikret.app") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "envelope.fill")
                                        Text("Contact Support")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.blue.opacity(0.8))
                                    )
                                }
                                .padding(.top, 16)
                            }
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Progress indicator
                        HStack(spacing: 8) {
                            ForEach(0..<7) { index in
                                Circle()
                                    .fill(
                                        index <= currentStep ?
                                        LinearGradient(
                                            colors: [Color.purple, Color.blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ) :
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 10, height: 10)
                                    .scaleEffect(index <= currentStep ? 1.2 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                            }
                        }
                        .padding(.top, 50)
                        
                        
                        // Main content (only show if valid invite code)
                        if isInviteCodeValid {
                            VStack(spacing: Design.spacing) {
                                switch currentStep {
                                case 0:
                                    nameAndUsernameSection
                                case 1:
                                    emailAndPasswordSection
                                case 2:
                                    profilePhotoSection
                                case 3:
                                    contactsPermissionSection
                                case 4:
                                    locationPermissionSection
                                case 5:
                                    categorySelectionSection
                                case 6:
                                    termsAndSignupSection
                                default:
                                    EmptyView()
                                }
                            }
                            .padding(.horizontal, 30)
                            .padding(.top, 20)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .onAppear {
                loadCategories()
                checkContactsPermissionStatus()
                // Location permission is now handled by the SignupLocationManager
            }
            .ignoresSafeArea(.keyboard, edges: .bottom) // Prevent keyboard layout issues
        }
    }
    
    // MARK: - Step Sections
 private var nameAndUsernameSection: some View {
    VStack(spacing: Design.spacing) {
        // Create Account header
        VStack(spacing: 8) {
            Text("Create Account")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Join Fikret and start sharing your world")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        VStack(spacing: 16) {
            // Username field (this will be used for both username and nickname)
            VStack(alignment: .leading, spacing: 8) {
                ModernTextField(
                    text: $username,
                    placeholder: "Username (will be your display name)",
                    icon: "at"
                )
                .onChange(of: username) { newValue in
                    // Backend validation: 3-12 characters, alphanumeric only
                    let isValidLength = newValue.count >= 3 && newValue.count <= 12
                    let isValidChars = newValue.range(of: "^[a-zA-Z0-9]+$", options: .regularExpression) != nil
                    isValidUsername = isValidLength && isValidChars && !newValue.isEmpty
                }
                .focused($usernameIsFocused)
                
                if !username.isEmpty {
                    if isValidUsername {
                        Text("Username is available")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        if username.count < 3 || username.count > 12 {
                            Text("Username must be 3-12 characters")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("Username can only contain letters and numbers")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        
        Spacer()
        
        // Next button
        ModernButton(
            title: "Next",
            isEnabled: isValidUsername,  // ✅ Only check username
            action: {
                withAnimation(.spring()) {
                    currentStep += 1
                }
            }
        )
        .disabled(!isValidUsername || !isInviteCodeValid)  // ✅ Remove name check
    }
}

    private var emailAndPasswordSection: some View {
        VStack(spacing: Design.spacing) {
            Text("Create your account")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                // Email field
                VStack(alignment: .leading, spacing: 8) {
                    ModernTextField(
                        text: $email,
                        placeholder: "Email",
                        icon: "envelope.fill"
                    )
                    .onChange(of: email) { newValue in
                        isValidEmail = newValue.contains("@") && newValue.contains(".")
                    }
                    .focused($emailIsFocused)
                    
                    if !email.isEmpty {
                        Text(isValidEmail ? "Valid email address" : "Please enter a valid email")
                            .font(.caption)
                            .foregroundColor(isValidEmail ? .green : .red)
                    }
                }
                
                // Password field
                VStack(alignment: .leading, spacing: 8) {
                    ModernSecureField(
                        text: $password,
                        placeholder: "Password",
                        icon: "lock.fill"
                    )
                    .onChange(of: password) { newValue in
                        isValidPassword = newValue.count >= 8 && newValue.count <= 16
                    }
                    .focused($passwordIsFocused)
                    
                    if !password.isEmpty {
                        Text(isValidPassword ? "Password meets requirements" : "Password must be 6-16 characters")
                            .font(.caption)
                            .foregroundColor(isValidPassword ? .green : .red)
                    }
                }
            }
            
            Spacer()
            
            // Navigation buttons
            HStack(spacing: 12) {
                ModernButton(
                    title: "Back",
                    isEnabled: true,
                    action: {
                        withAnimation(.spring()) {
                            currentStep -= 1
                        }
                    }
                )
                
                ModernButton(
                    title: "Next",
                    isEnabled: isValidEmail && isValidPassword,
                    action: {
                        withAnimation(.spring()) {
                            currentStep += 1
                        }
                    }
                )
            }
        }
    }
    
    private var profilePhotoSection: some View {
        VStack(spacing: Design.spacing) {
            Text("Add a profile photo")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                showImagePicker = true
            } label: {
                ZStack {
                    // Modern glassmorphism background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .frame(width: Design.imageSize, height: Design.imageSize)
                    
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: Design.imageSize - 8, height: Design.imageSize - 8)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("Tap to add a photo")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Navigation buttons
            HStack(spacing: 12) {
                ModernButton(
                    title: "Back",
                    isEnabled: true,
                    action: {
                        withAnimation(.spring()) {
                            currentStep -= 1
                        }
                    }
                )
                
                ModernButton(
                    title: "Next",
                    isEnabled: true,
                    action: {
                        withAnimation(.spring()) {
                            currentStep += 1
                        }
                    }
                )
            }
        }
    }
    
    private var contactsPermissionSection: some View {
        VStack(spacing: Design.spacing) {
            Text("Find friends on Fikret")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Allow access to your contacts to find friends who are already on Fikret")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 24) {
                // Contacts permission icon
                Image(systemName: contactsPermissionGranted ? "checkmark.circle.fill" : "person.2.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(contactsPermissionGranted ? .green : .white.opacity(0.8))
                    .scaleEffect(contactsPermissionGranted ? 1.1 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: contactsPermissionGranted)
                
                if contactsPermissionGranted {
                    VStack(spacing: 12) {
                        Text("Contacts Access Granted")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.green)
                        
                        if !collectedContacts.isEmpty {
                            Text("\(collectedContacts.count) contacts collected")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.green.opacity(0.8))
                        }
                        
                        Text("We'll help you find friends who are already on Fikret")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("Connect with Friends")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Tap 'Allow' to access your contacts and find friends who are already using Fikret")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            requestContactsPermission()
                        }) {
                            HStack(spacing: 12) {
                                if contactsPermissionRequested {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 18, weight: .medium))
                                }
                                Text(contactsPermissionRequested ? "Requesting..." : "Allow Access")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(contactsPermissionRequested)
                        
                        // Skip option for users who don't want to grant permission
                        Button(action: {
                            // Allow users to skip contacts permission
                            contactsPermissionGranted = false
                        }) {
                            Text("Skip for now")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .underline()
                        }
                        .disabled(contactsPermissionRequested)
                    }
                }
            }
            .padding(.vertical, 40)
            
            Spacer()
            
            // Navigation buttons
            HStack(spacing: 12) {
                ModernButton(
                    title: "Back",
                    isEnabled: true,
                    action: {
                        withAnimation(.spring()) {
                            currentStep -= 1
                        }
                    }
                )
                
                ModernButton(
                    title: "Next",
                    isEnabled: true, // Allow proceeding regardless of contacts permission
                    action: {
                        withAnimation(.spring()) {
                            currentStep += 1
                        }
                    }
                )
            }
        }
    }
    
    private var locationPermissionSection: some View {
        VStack(spacing: Design.spacing) {
            Text("Share your location")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Location access is required to create your account and connect with people around the world")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 24) {
                // Location permission icon with proper state management
                Image(systemName: locationManager.isLocationPermissionGranted ? "checkmark.circle.fill" : "location.fill")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(locationManager.isLocationPermissionGranted ? .green : .white.opacity(0.8))
                    .scaleEffect(locationManager.isLocationPermissionGranted ? 1.1 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: locationManager.isLocationPermissionGranted)
                
                if locationManager.isLocationPermissionGranted {
                    VStack(spacing: 12) {
                        Text("Location Access Granted")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("Great! You can now complete your account setup")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("Connect Globally")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Tap 'Allow' to enable location access and continue with your account setup")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            print("📍 [SIGNUP] Requesting location permission...")
                            locationManager.requestLocationPermission()
                        }) {
                            HStack(spacing: 12) {
                                if locationManager.isRequestingPermission {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 18, weight: .medium))
                                }
                                Text(locationManager.isRequestingPermission ? "Requesting..." : "Allow Access")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(locationManager.isRequestingPermission)
                        
                        // Show different messages based on authorization status
                        switch locationManager.authorizationStatus {
                        case .denied, .restricted:
                            VStack(spacing: 12) {
                                Text("Location access was denied")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                
                                Text("Location access is required to continue. Please go to Settings > Privacy & Security > Location Services > Fikret and enable location access.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button(action: {
                                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(settingsUrl)
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "gear")
                                        Text("Open Settings")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.red.opacity(0.8))
                                    )
                                }
                            }
                            .padding(.top, 16)
                            
                        case .notDetermined:
                            Text("Tap 'Allow Access' to request location permission")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .padding(.vertical, 40)
            
            Spacer()
            
            // Navigation buttons
            HStack(spacing: 12) {
                ModernButton(
                    title: "Back",
                    isEnabled: true,
                    action: {
                        withAnimation(.spring()) {
                            currentStep -= 1
                        }
                    }
                )
                
                ModernButton(
                    title: "Next",
                    isEnabled: locationManager.isLocationPermissionGranted, // ✅ REQUIRED: Location permission is mandatory
                    action: {
                        withAnimation(.spring()) {
                            currentStep += 1
                        }
                    }
                )
            }
        }
    }
    
    private var categorySelectionSection: some View {
        VStack(spacing: Design.spacing) {
            Text("Choose your interests")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Select up to 6 categories that interest you")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if isLoadingCategories {
                VStack(spacing: 24) {
                    TikTokLoadingView(size: 60, color: .white)
                    Text("Loading categories...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.vertical, 60)
            } else if !categorySelectionError.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(categorySelectionError)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    ModernButton(
                        title: "Retry",
                        isEnabled: true,
                        action: {
                            loadCategories()
                        }
                    )
                }
                .padding(.vertical, 40)
            } else {
                // Modern category grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                    ForEach(availableCategories) { category in
                        ModernCategoryCard(
                            category: category,
                            isSelected: selectedCategories.contains(category.id),
                            isDisabled: !selectedCategories.contains(category.id) && selectedCategories.count >= 6,
                            onTap: {
                                if selectedCategories.contains(category.id) {
                                    selectedCategories.remove(category.id)
                                } else if selectedCategories.count < 6 {
                                    selectedCategories.insert(category.id)
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 20)
            }
            
            Spacer()
            
            // Selected count indicator
            if !selectedCategories.isEmpty {
                Text("\(selectedCategories.count)/6 categories selected")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(selectedCategories.count >= 6 ? .orange : .white.opacity(0.8))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedCategories.count >= 6 ? Color.orange.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            
            // Navigation buttons
            HStack(spacing: 12) {
                ModernButton(
                    title: "Back",
                    isEnabled: true,
                    action: {
                        withAnimation(.spring()) {
                            currentStep -= 1
                        }
                    }
                )
                
                ModernButton(
                    title: "Next",
                    isEnabled: !selectedCategories.isEmpty,
                    action: {
                        withAnimation(.spring()) {
                            currentStep += 1
                        }
                    }
                )
            }
        }
    }
    
    private var termsAndSignupSection: some View {
        VStack(spacing: Design.spacing) {
            Text("Almost there!")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 20)
            
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Navigation buttons
            HStack(spacing: 12) {
                ModernButton(
                    title: "Back",
                    isEnabled: true,
                    action: {
                        withAnimation(.spring()) {
                            currentStep -= 1
                        }
                    }
                )
                
                ModernButton(
                    title: isLoading ? "Signing up..." : "Sign up",
                    isEnabled: !isLoading && locationManager.isLocationPermissionGranted,
                    action: {
                        Task {
                            await handleSignUp()
                        }
                    }
                )
            }
        }
    }
    
    private func handleSignUp() async {
        print("\n📱 Starting signup process from SignupView...")
        print("🔍 Input validation:")
        print("- Username: \(username)")
        print("- Email: \(email)")
        print("- Password length: \(password.count)")
        print("- Has avatar: \(selectedImage != nil)")
        print("- Selected categories: \(selectedCategories.count)")
        
        // Frontend validation - match backend requirements exactly
        if password.count < 6 || password.count > 16 {
            message = "Password must be between 6-16 characters"
            print("❌ Frontend validation failed: \(message)")
            return
        }
        
        if username.isEmpty {
            message = "Username cannot be empty"
            print("❌ Frontend validation failed: \(message)")
            return
        }
        
        if username.count < 3 || username.count > 12 {
            message = "Username must be between 3-12 characters"
            print("❌ Frontend validation failed: \(message)")
            return
        }
        
        // Check username contains only alphanumeric characters
        if username.range(of: "^[a-zA-Z0-9]+$", options: .regularExpression) == nil {
            message = "Username can only contain letters and numbers"
            print("❌ Frontend validation failed: \(message)")
            return
        }
        
        if email.isEmpty {
            message = "Email cannot be empty"
            print("❌ Frontend validation failed: \(message)")
            return
        }
        
        // ✅ ADDED: Location permission is mandatory for signup
        if !locationManager.isLocationPermissionGranted {
            message = "Location permission is required to create an account. Please enable location access to continue."
            print("❌ Frontend validation failed: \(message)")
            return
        }
        
        // Require valid invite code for all builds
        if !isInviteCodeValid {
            message = "A valid invitation is required to sign up."
            print("❌ Frontend validation failed: \(message)")
            isLoading = false
            return
        }
        
        if selectedCategories.isEmpty {
            message = "You must select at least one category."
            print("❌ Frontend validation failed: \(message)")
            return
        }
        
        if selectedCategories.count > 6 {
            message = "You can select a maximum of 6 categories."
            print("❌ Frontend validation failed: \(message)")
            return
        }
        
        isLoading = true
        message = "" // Clear any previous error messages
        
        do {
            var avatarData: Data?
            if let image = selectedImage {
                print("\n📸 Processing avatar image...")
                if let data = image.jpegData(compressionQuality: 0.8) {
                    avatarData = data
                    print("✅ Avatar processed successfully")
                    print("- Image size: \(data.count) bytes")
                } else {
                    print("⚠️ Failed to process avatar image")
                }
            } else {
                print("\nℹ️ No avatar image selected")
            }
            
            // Convert selected categories to array
            let categoryIds = Array(selectedCategories)
            print("\n🏷️ Selected categories: \(categoryIds)")
            
            print("\n🌐 Calling signUp with categories, contacts, and device info...")
            
            // Get contacts and device info for signup
            let contacts = collectedContacts.isEmpty ? nil : collectedContacts
            let device = try? await getDeviceInfo()
            
            print("📱 Signup details:")
            print("- Contacts: \(contacts?.count ?? 0)")
            print("- Device: \(device?.platform ?? "none")")
            
            // Single signup call that handles registration, login, and profile creation
            let userProfile = try await tweetData.signUp(
                email: email,
                password: password,
                username: username,
                name: username,
                avatarData: avatarData,
                categories: categoryIds,
                contacts: contacts,
                device: device
            )
            
            print("\n✅ Signup completed successfully")
            print("📋 User Profile Details:")
            print("- User ID: \(userProfile.id)")
            print("- Username: \(userProfile.username)")
            if let categories = userProfile.categories {
                print("- Categories: \(categories)")
            }
          
            // Create a room for the new user
            print("\n🌐 Creating room for new user...")
            do {
                // Generate a unique room ID using the user's ID
                let hmsRoomId = "room_\(userProfile.id)"
                let topics = ["Welcome"] // Default topic for new users
                
                print("📝 Room Creation Parameters:")
                print("- HMS Room ID: \(hmsRoomId)")
                print("- Topics: \(topics)")
                print("- Categories: \(categoryIds)")
                
                print("🔄 Calling spacesViewModel.createRoom...")
                let space = try await spacesViewModel.createRoom(hmsRoomId: hmsRoomId, topics: topics, categories: categoryIds)
                
                print("✅ Room created successfully:")
                print("- Room ID: \(space.hmsRoomId ?? "nil")")
                print("- Space ID: \(space.id)")
                print("- Topics: \(space.topics)")
                
                // ✅ PERSISTENT STORAGE: Space is automatically saved to UserDefaults in createRoom method
                print("✅ User's own space automatically saved to persistent storage")
                
                // Set authentication state
                await MainActor.run {
                    tweetData.isAuthenticated = true
                    print("✅ Authentication state set to true")
                    
                    // ✅ ADDED: Post notification when signup authentication is complete
                    if let user = tweetData.user {
                        print("🔔 [SIGNUP] Posting authentication complete notification")
                        NotificationCenter.default.post(
                            name: Notification.Name("UserAuthenticationComplete"),
                            object: nil,
                            userInfo: [
                                "userId": user.id,
                                "username": user.username
                            ]
                        )
                    }
                }
                
                // ✅ ADDED: Send location to backend after successful signup
                if locationManager.isLocationPermissionGranted {
                    print("📍 [SIGNUP] Sending location to backend after successful signup...")
                    LocationService.shared.sendLocationToBackend()
                } else {
                    print("📍 [SIGNUP] Location permission not granted, skipping location send")
                }
                
                // Location will be handled by LocationService after authentication
            } catch {
                print("❌ Room creation failed with error:")
                print("- Error type: \(type(of: error))")
                print("- Error description: \(error.localizedDescription)")
                print("- Error details: \(error)")
                
                // Set authentication state even if room creation fails
                // since the user is still successfully signed up
                await MainActor.run {
                    tweetData.isAuthenticated = true
                    print("✅ Authentication state set to true (despite room creation failure)")
                }
                
                // ✅ ADDED: Send location to backend even if room creation failed
                if locationManager.isLocationPermissionGranted {
                    print("📍 [SIGNUP] Sending location to backend after signup (room creation failed)...")
                    LocationService.shared.sendLocationToBackend()
                } else {
                    print("📍 [SIGNUP] Location permission not granted, skipping location send")
                }
            }
            
        } catch let error as AuthError {
            print("\n❌ Signup failed with AuthError:")
            switch error {
            case .invalidInput:
                message = "Please check your input fields"
                print("- Invalid input")
            case .networkError(let message):
                self.message = "Network error: \(message)"
                print("- Network error: \(message)")
            case .signupFailed(let message):
                // Handle specific backend validation errors
                if message.contains("用户名已存在") || message.contains("username already exists") {
                    self.message = "Username is already taken. Please choose a different username."
                } else if message.contains("密码长度6~16") || message.contains("password length") {
                    self.message = "Password must be between 6-16 characters"
                } else if message.contains("用户名长度3~12") || message.contains("username length") {
                    self.message = "Username must be between 3-12 characters"
                } else if message.contains("用户名只能包含字母、数字") || message.contains("username characters") {
                    self.message = "Username can only contain letters and numbers"
                } else {
                    self.message = "Signup failed: \(message)"
                }
                print("- Signup failed: \(message)")
            case .loginFailed(let message):
                self.message = "Login failed: \(message)"
                print("- Login failed: \(message)")
            case .avatarUploadFailed(let message):
                self.message = "Avatar upload failed: \(message)"
                print("- Avatar upload failed: \(message)")
            default:
                self.message = "An unexpected error occurred"
                print("- Unexpected error: \(error)")
            }
        } catch {
            print("\n❌ Signup failed with unexpected error:")
            print("- Error type: \(type(of: error))")
            print("- Error description: \(error.localizedDescription)")
            print("- Error details: \(error)")
            message = "An unexpected error occurred: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func loadCategories() {
        isLoadingCategories = true
        categorySelectionError = ""
        
        // Use static categories only for signup - no API calls needed
        availableCategories = tweetData.getStaticCategories()
        
        // Simulate a brief loading for smooth UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoadingCategories = false
        }
        
        print("✅ Loaded \(availableCategories.count) static categories for signup")
    }
    
    private func checkContactsPermissionStatus() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        contactsPermissionGranted = (status == .authorized)
        print("🔐 Contacts permission status: \(status.rawValue), granted: \(contactsPermissionGranted)")
        
        // If permission is already granted, collect contacts
        if contactsPermissionGranted {
            Task {
                await collectContacts()
            }
        }
    }
    
    private func requestContactsPermission() {
        contactsPermissionRequested = true
        print("🔐 Requesting contacts permission...")
        
        // Check current authorization status first
        let currentStatus = CNContactStore.authorizationStatus(for: .contacts)
        print("🔐 Current contacts authorization status: \(currentStatus.rawValue)")
        
        switch currentStatus {
        case .authorized:
            // Already authorized - collect contacts immediately
            DispatchQueue.main.async {
                self.contactsPermissionRequested = false
                self.contactsPermissionGranted = true
                print("✅ Contacts permission already granted")
                // Collect contacts in background
                Task {
                    await self.collectContacts()
                }
            }
            
        case .denied, .restricted:
            // Permission denied or restricted
            DispatchQueue.main.async {
                self.contactsPermissionRequested = false
                self.contactsPermissionGranted = false
                print("❌ Contacts permission denied or restricted")
            }
            
        case .notDetermined:
            // Request permission
            let contactStore = CNContactStore()
            contactStore.requestAccess(for: .contacts) { granted, error in
                DispatchQueue.main.async {
                    self.contactsPermissionRequested = false
                    self.contactsPermissionGranted = granted
                    
                    if granted {
                        print("✅ Contacts permission granted")
                        // Collect contacts in background
                        Task {
                            await self.collectContacts()
                        }
                    } else {
                        print("❌ Contacts permission denied: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
            
        @unknown default:
            // Handle future cases
            DispatchQueue.main.async {
                self.contactsPermissionRequested = false
                self.contactsPermissionGranted = false
                print("❌ Unknown contacts authorization status")
            }
        }
    }
    
    // MARK: - Contact Collection
    private func collectContacts() async {
        guard contactsPermissionGranted else {
            print("⚠️ Cannot collect contacts - permission not granted")
            return
        }
        
        do {
            print("📱 Collecting contacts...")
            let store = CNContactStore()
            
            // Fetch contacts (permission already granted at this point)
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey]
            let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
            
            var contacts: [ContactItem] = []
            
            try store.enumerateContacts(with: request) { contact, stop in
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                
                // Get first phone number
                if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                    // Get first email
                    let email = contact.emailAddresses.first?.value as String?
                    
                    let contactItem = ContactItem(
                        name: name,
                        phone: phoneNumber,
                        email: email
                    )
                    contacts.append(contactItem)
                }
            }
            
            print("✅ Successfully collected \(contacts.count) contacts")
            
            // Store contacts for later use in signup
            await MainActor.run {
                self.collectedContacts = contacts
            }
        } catch {
            print("❌ Failed to collect contacts: \(error)")
            // Don't fail signup if contacts collection fails
        }
    }
    
   
    
    // MARK: - Device Token (Simple & Reliable)
    func getDeviceToken() async throws -> String {
        // Check if we already have a real device token (not temporary)
        if let deviceToken = UserDefaults.standard.string(forKey: "deviceToken"),
           !deviceToken.isEmpty && !deviceToken.hasPrefix("temp_") {
            print("✅ Found existing real device token: \(deviceToken)")
            return deviceToken
        }
        
        print("📱 No device token found, requesting APN registration...")
        
        // Request notification permission
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else {
            throw AuthError.notificationPermissionDenied("Notification permission denied")
        }
        
        print("📱 Notification permission granted, registering for remote notifications...")
        
        // Register for remote notifications (this triggers AppDelegate methods)
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        // ✅ SIMPLE: Wait up to 5 seconds for APN token
        for i in 1...50 { // Check 50 times over 5 seconds
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            if let deviceToken = UserDefaults.standard.string(forKey: "deviceToken"),
               !deviceToken.isEmpty && !deviceToken.hasPrefix("temp_") {
                print("✅ Received real APN device token: \(deviceToken)")
                return deviceToken
            }
            
            if i % 10 == 0 { // Log every second
                print("📱 Waiting for APN token... (\(i/10)s)")
            }
        }
        
        // If no real token received, return temporary token as fallback
        let tempToken = "temp_\(UUID().uuidString)"
        print("⚠️ No real APN token received, using temporary token: \(tempToken)")
        return tempToken
    }
    
    
    private func getDeviceInfo() async throws -> DeviceInfo {
        let deviceToken = try await getDeviceToken()
        
        return DeviceInfo(
            deviceToken: deviceToken,
            platform: "ios",
            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            deviceName: UIDevice.current.name
        )
    }
    
    
    
    // MARK: - AppFlyer Invite Code Handling
    // AppFlyer automatically extracts invite codes and stores them in UserDefaults
    // FikretApp listens for notifications and updates the environment variable
    // SignupView automatically receives the invite code via @Environment(\.inviteCode)
}



// MARK: - Modern Category Card
struct ModernCategoryCard: View {
    let category: Category
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Category icon with animated background
                ZStack {
                    Circle()
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            isDisabled ?
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Text(category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isDisabled ? .gray : .white)
                }
                
                // Category name
                Text(category.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(isDisabled ? .gray : .white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isDisabled ? 0.05 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ?
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                isDisabled ?
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .opacity(isDisabled ? 0.6 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Modern UI Components

struct ModernTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .submitLabel(.next)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct ModernButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isEnabled ?
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(
                    color: isEnabled ? Color.purple.opacity(0.3) : Color.clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .scaleEffect(isEnabled ? 1.0 : 0.98)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEnabled)
        }
        .disabled(!isEnabled)
    }
}

struct ModernSecureField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    @State private var showPassword: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20)
            
            if showPassword {
                TextField(placeholder, text: $text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
            } else {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
            }
            
            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true // Allow editing to optimize image size
        picker.videoQuality = .typeLow // Optimize for photos only
        picker.modalPresentationStyle = .fullScreen // Prevent layout issues
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Use edited image if available, otherwise original
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView()
            .environmentObject(TweetData())
            .environmentObject(SpacesViewModel())
    }
}

