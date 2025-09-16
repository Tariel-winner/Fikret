import SwiftUI
import Foundation
//import Supabase
enum Theme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}



struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tweets: TweetData
    @EnvironmentObject var viewModel: SpacesViewModel
 //   @StateObject private var userService = UserService()
    @State private var showSignOutAlert = false
    @AppStorage("selectedTheme") private var selectedTheme = Theme.system
    @Environment(\.colorScheme) var systemColorScheme
    @State private var notifications = true  // Default to true
    @GestureState private var dragOffset = CGSize.zero
    @State private var isLoading = false
    @State private var errorMessage = ""
   // @EnvironmentObject var stripeAccountData: StripeAccountData
    
    @State private var showEditProfile = false
    @State private var showBankAccount = false
    @State private var showEarnings = false
    
    /*@StateObject private var viewControllerPresenter = ViewControllerPresenter(
          presentViewController: { vc in
              DispatchQueue.main.async {
                  if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                      rootVC.present(vc, animated: true, completion: nil)
                  }
              }
          },
          pushViewController: { vc in
              DispatchQueue.main.async {
                  if let navigationController = UIApplication.shared.windows.first?.rootViewController as? UINavigationController {
                      navigationController.pushViewController(vc, animated: true)
                  }
              }
          },
          setRootViewController: { vc in
              DispatchQueue.main.async {
                  if let window = UIApplication.shared.windows.first {
                      window.rootViewController = vc
                      window.makeKeyAndVisible()
                  }
              }
          }
      )*/
    private var effectiveColorScheme: ColorScheme {
        selectedTheme.colorScheme ?? systemColorScheme
    }
    
 /*   private func loadNotificationSettings() async {
        guard let userId = tweets.user?.id else { return }
        
        do {
            let response =  try await supabase.from("profiles")
                .select("notifications_enabled")
                .eq("id", value:String( userId))
                .single()
                .execute()
            
            if let data = response.data as? [String: Any],
               let enabled = data["notifications_enabled"] as? Bool {
                await MainActor.run {
                    self.notifications = enabled
                }
            } else {
                // If no setting is found, default to true
                await MainActor.run {
                    self.notifications = true
                }
                // Save the default value
            try await supabase.from("profiles")
                    .update(["notifications_enabled": true])
                    .eq("id", value:String(userId))
                    .execute()
            }
        } catch {
            print("Failed to load notification settings: \(error)")
            // Default to true even on error
            await MainActor.run {
                self.notifications = true
            }
        }
    }
    */
  /*  private func handleSignOut() {
        isLoading = true
        
        Task {
            do {
                try await userService.signOut()
                await MainActor.run {
                    withAnimation(.easeOut) {
                        tweets.isAuthenticated = false
                        tweets.user = nil  // Just set to nil instead of creating empty user
                    }
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }*/
    
    var signOutSection: some View {
        Section {
            Button {
                showSignOutAlert = true
            } label: {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Text("Sign Out")
                            .foregroundColor(.red)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .disabled(isLoading)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .listRowBackground(Color.clear)
    }
    
    var body: some View {
        NavigationStack {
            List {
                accountSection
                preferencesSection
               // supportSection
                signOutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    dismissButton
                }
            }
        }
        .gesture(dismissGesture)
        .offset(y: dragOffset.height)
        .animation(.interactiveSpring(), value: dragOffset)
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
              //  handleSignOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .preferredColorScheme(selectedTheme.colorScheme)
        .onAppear {
            print("SettingsView appeared with tweets: \(tweets)")
            Task {
               // await setupAppInfoAndMerchant()
            }
        }
       /* .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(tweets)
        }
        .sheet(isPresented: $showBankAccount) {
            AddBankAccountView()
                .environmentObject(viewModel)
                .environmentObject(tweets)
                .environmentObject(stripeAccountData)
        }
        .sheet(isPresented: $showEarnings) {
            EarningsView()
        }*/
    }



    
    // MARK: - Sections
    private var accountSection: some View {
        Section {
            Button(action: { showEditProfile = true }) {
                SettingsRow(
                    icon: "person.circle.fill",
                    iconColor: .blue,
                    title: "Edit Profile",
                    showChevron: false
                )
            }
            
         /*   NavigationLink {

                    AppLoadingView().environmentObject(tweets)
                    .environmentObject(viewControllerPresenter)
              
            } label: {
                SettingsRow(
                    icon: "building.columns.fill",
                    iconColor: .purple,
                    title: "Merchant Account",
                    description: "Manage your merchant account",
                    showChevron: false
                )
            }*/
            
            Button(action: { showEarnings = true }) {
                SettingsRow(
                    icon: "dollarsign.circle.fill",
                    iconColor: .green,
                    title: "Earnings",
                    showChevron: false
                )
            }
            
            Button(action: { showBankAccount = true }) {
                SettingsRow(
                    icon: "building.columns.fill",
                    iconColor: .purple,
                    title: "Bank Account",
                    description: "Connect or manage your bank account",
                    showChevron: false
                )
            }
        } header: {
            Text("Account")
                .textCase(.uppercase)
                .font(.footnote)
                .foregroundColor(.gray)
    }
    }
    
    private var preferencesSection: some View {
        Section {
            themeRow
            notificationsRow
        } header: {
            Text("Preferences")
                .textCase(.uppercase)
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }
    
    private var supportSection: some View {
        Section {
           /* NavigationLink {
                HelpCenterView()
            } label: {
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    iconColor: .orange,
                    title: "Help Center",
                    description: "Get help and support",
                    showChevron: false
                )
            }*/
            
            Link(destination: URL(string: "https://twitter.com/about")!) {
                SettingsRow(
                    icon: "info.circle.fill",
                    iconColor: .blue,
                    title: "About",
                    description: "Learn more about our app",
                    showChevron: true, isExternal: true
                )
            }
        } header: {
            Text("Support")
                .textCase(.uppercase)
                .font(.footnote)
                .foregroundColor(.gray)
        }
        }
    
    private var themeRow: some View {
        HStack {
            SettingsRow(
                icon: "moon.stars.fill",
                iconColor: .purple,
                title: "Appearance",
                showChevron: false
            )
            
            Spacer()
            
            Menu {
                ForEach(Theme.allCases, id: \.self) { theme in
                    Button {
                        selectedTheme = theme
                        applyTheme(theme)
                    } label: {
                        if selectedTheme == theme {
                            Label(theme.rawValue, systemImage: "checkmark")
                        } else {
                            Text(theme.rawValue)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedTheme.rawValue)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
    }
    
    private var notificationsRow: some View {
        HStack {
            SettingsRow(
                icon: "bell.fill",
                iconColor: .red,
                title: "Notifications",
                showChevron: false
            )
            
            Spacer()
            
            Toggle("", isOn: $notifications)
                .tint(.blue)
        }
    }
    
    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.body.bold())
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
        }
    }
    
    private var dismissGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                if value.translation.height > 0 {
                    state = value.translation
                }
            }
            .onEnded { value in
                if value.translation.height > 100 {
                    dismiss()
                }
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
    
   /* private func setupAppInfoAndMerchant() async {
        guard let userId = tweets.user?.id, let name = tweets.user?.name else { return }

        // Fetch the stripeConnectId asynchronously
        if let stripeConnectId = await getStripeConnectIdForCurrentUser() {
            // Construct AppInfo with the publishable key
            let appInfo = AppInfo(publishableKey: "pk_test_51OYr6bEL5j6LpNh8RBtgcxwPHTkDp4vBcMsuBDCJKEwgJBoWXAbUqiIe00Pzxyl3gg", merchant:nil)

            // Construct MerchantInfo
            let merchant = MerchantInfo(displayName: name, merchantId: stripeConnectId)
            await MainActor.run {
                self.selectedMerchant = merchant
                self.appInfo = appInfo
            }
        } else {
            await MainActor.run {
                // Handle the case where the user is not onboarded
                self.selectedMerchant = nil
                self.appInfo = nil
            }
        }
    }*/
    
    private func getStripeConnectIdForCurrentUser() async -> String? {
        do {
           /* let resp = try await supabase.from("profile")
                .select("stripe_connect_id")
                .eq("user_id", value: String(tweets.user.id))
                .execute()
            
            let profiles = try JSONDecoder().decode([ProfileResponseStripe].self, from: resp.data ?? Data())
            
            guard let profile = profiles.first,
                  let stripeConnectId = profile.stripeConnectId,
                  !stripeConnectId.isEmpty else {
                print("Seller has no Stripe account")
                return nil
            }*/
            //return stripeConnectId
            return nil
        } catch {
            print("Error fetching stripeConnectId: \(error)")
            return nil
        }
    }
}

// Helper view for consistent row styling
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var description: String? = nil
    var showChevron: Bool = true
    var isExternal: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if showChevron {
                Spacer()
                Image(systemName: isExternal ? "arrow.up.right" : "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .contentShape(Rectangle())
    }
}

struct AccountHelpView: View {
    private let accountTopics = [
        HelpTopic(
            title: "Profile Settings",
            description: "Learn how to customize your profile",
            content: """
            To update your profile:
            1. Go to Settings > Edit Profile
            2. Tap the field you want to change
            3. Make your changes
            4. Tap Save
            
            You can update your:
            • Profile picture
            • Display name
            • Bio
            • Location
            • Website
            """
        ),
        HelpTopic(
            title: "Account Security",
            description: "Keep your account safe",
            content: """
            Protect your account by:
            • Using a strong password
            • Enabling two-factor authentication
            • Regularly reviewing connected devices
            • Monitoring account activity
            
            If you notice suspicious activity, contact support immediately.
            """
        ),
        HelpTopic(
            title: "Account Recovery",
            description: "Recover access to your account",
            content: """
            If you can't access your account:
            1. Use the "Forgot Password" option
            2. Follow the recovery steps sent to your email
            3. Update your security settings once recovered
            
            Contact support if you need additional help.
            """
        )
    ]
    
    var body: some View {
        List(accountTopics) { topic in
            NavigationLink {
                HelpDetailView(topic: topic)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.title)
                        .font(.body)
                    Text(topic.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Account & Profile")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct PrivacyHelpView: View {
    private let privacyTopics = [
        HelpTopic(
            title: "Privacy Settings",
            description: "Control your account privacy",
            content: """
            Manage your privacy:
            • Private/Public account
            • Who can see your posts
            • Who can message you
            • Who can mention you
            
            Your privacy settings can be changed at any time.
            """
        ),
        HelpTopic(
            title: "Blocking & Muting",
            description: "Manage unwanted interactions",
            content: """
            To block or mute someone:
            1. Go to their profile
            2. Tap the menu button
            3. Select Block or Mute
            
            Blocked users cannot:
            • See your posts
            • Message you
            • Follow you
            """
        ),
        HelpTopic(
            title: "Data & Privacy",
            description: "Understand your data rights",
            content: """
            Your data rights include:
            • Accessing your data
            • Downloading your data
            • Deleting your data
            • Controlling data sharing
            
            We protect your privacy and never sell your data.
            """
        )
    ]
    
    var body: some View {
        List(privacyTopics) { topic in
            NavigationLink {
                HelpDetailView(topic: topic)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.title)
                        .font(.body)
                    Text(topic.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Privacy & Safety")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct NotificationHelpView: View {
    private let notificationTopics = [
        HelpTopic(
            title: "Notification Settings",
            description: "Customize your notifications",
            content: """
            Control notifications for:
            • New followers
            • Likes and comments
            • Messages
            • Live streams
            • System updates
            
            You can customize each type individually.
            """
        ),
        HelpTopic(
            title: "Push Notifications",
            description: "Manage push notifications",
            content: """
            To enable push notifications:
            1. Go to Settings > Notifications
            2. Toggle notifications on/off
            3. Choose notification types
            4. Set quiet hours if desired
            
            You can change these settings anytime.
            """
        ),
        HelpTopic(
            title: "Email Notifications",
            description: "Control email updates",
            content: """
            Manage email notifications:
            • Security alerts
            • Account updates
            • Marketing emails
            • Newsletter
            
            Unsubscribe options are available in each email.
            """
        )
    ]
    
    var body: some View {
        List(notificationTopics) { topic in
            NavigationLink {
                HelpDetailView(topic: topic)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.title)
                        .font(.body)
                    Text(topic.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct HelpTopic: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let content: String
}

struct HelpDetailView: View {
    let topic: HelpTopic
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(topic.content)
                    .font(.body)
                    .padding()
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Still need help?")
                        .font(.headline)
                    
                    Button {
                        // Open email composer
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Contact Support")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct FAQDetailView: View {
    let question: String
    
    // Sample answers - in production, these would come from a backend
    private func getAnswer(for question: String) -> (String, [String]) {
        switch question {
        case "How to change my profile picture?":
            return (
                "You can change your profile picture in just a few steps:",
                [
                    "1. Go to Settings > Edit Profile",
                    "2. Tap on your current profile picture",
                    "3. Choose 'Take Photo' or 'Choose from Library'",
                    "4. Adjust the image as needed",
                    "5. Tap 'Save' to confirm changes"
                ]
            )
        case "How to protect my tweets?":
            return (
                "Making your account private ensures only approved followers can see your tweets:",
                [
                    "1. Go to Settings > Privacy",
                    "2. Enable 'Private Account'",
                    "3. Existing followers will remain",
                    "4. New followers will need approval",
                    "5. Your tweets won't appear in public searches"
                ]
            )
        default:
            return (
                "Here's what you need to know:",
                [
                    "• Check our detailed documentation",
                    "• Contact support for specific issues",
                    "• Visit our help center for more information",
                    "• Follow our guidelines for best practices",
                    "• Stay updated with our latest features"
                ]
            )
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Question Header
                Text(question)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Main Content
                let (intro, steps) = getAnswer(for: question)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(intro)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(steps, id: \.self) { step in
                            Text(step)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.vertical)
                
                // Help Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Still need help?")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Support Options
                    VStack(spacing: 12) {
                        Button {
                            // Contact Support action
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("Contact Support")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44) // Apple's minimum touch target
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        Button {
                            // Open Help Center action
                        } label: {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                Text("Visit Help Center")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Related Articles
                VStack(alignment: .leading, spacing: 12) {
                    Text("Related Articles")
                        .font(.headline)
                        .padding(.top)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(1...3, id: \.self) { _ in
                                RelatedArticleCard()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Helper view for related articles
private struct RelatedArticleCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related Topic")
                .font(.headline)
            Text("Learn more about this related feature or setting")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 200)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


