import SwiftUI
import Contacts
import UIKit

struct InviteContactsView: View {
    @EnvironmentObject var inviteManager: InviteManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    
    var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return inviteManager.contacts
        } else {
            return inviteManager.contacts.filter { contact in
                let name = "\(contact.givenName) \(contact.familyName)"
                return name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.black, Color.purple.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Invite Friends")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Circle().fill(Color.white.opacity(0.2)))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 8)
                    
                    // Search bar
                    ModernSearchBar(text: $searchText)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    
                    // Content
                    if inviteManager.permissionStatus == .notDetermined {
                        // Permission request view
                        VStack(spacing: 24) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.white.opacity(0.8))
                            
                            VStack(spacing: 8) {
                                Text("Connect with Friends")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text("Allow access to your contacts to invite them to Fikret")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            Button(action: {
                                inviteManager.requestAccess()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Allow Access")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.9), Color.blue.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            
                            Button("Not Now") {
                                dismiss()
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    } else if inviteManager.permissionStatus == .denied {
                        // Permission denied view
                        VStack(spacing: 24) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.white.opacity(0.8))
                            
                            VStack(spacing: 8) {
                                Text("Access Denied")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text("Please enable contact access in Settings to invite friends")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            Button(action: {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "gear")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Open Settings")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.9), Color.blue.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            
                            Button("Cancel") {
                                dismiss()
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    } else if inviteManager.isLoading {
                        // Loading view
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 3)
                                    .frame(width: 60, height: 60)
                                
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.purple, Color.blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                                    .frame(width: 60, height: 60)
                                    .rotationEffect(.degrees(360))
                                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: true)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Loading Contacts")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Please wait while we fetch your contacts")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Button("Cancel") {
                                dismiss()
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    } else {
                        // Contacts list
                        if inviteManager.contacts.isEmpty {
                            // No contacts view
                            VStack(spacing: 24) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                VStack(spacing: 8) {
                                    Text("No Contacts Found")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("We couldn't find any contacts with phone numbers or email addresses")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                }
                                
                                Button("Done") {
                                    dismiss()
                                }
                                .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(32)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // Contacts list
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredContacts, id: \.identifier) { contact in
                                        ModernContactRow(
                                            contact: contact,
                                            onInvite: {
                                                inviteManager.invite(contact: contact)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { EmptyView() } }
            .alert("Error", isPresented: Binding<Bool>(
                get: { inviteManager.error != nil },
                set: { newValue in if !newValue { inviteManager.error = nil } }
            )) {
                Button("OK") { inviteManager.error = nil }
            } message: {
                Text(inviteManager.error ?? "Unknown error")
            }
            .sheet(isPresented: $inviteManager.showShareSheet, onDismiss: {
                inviteManager.resetShareSheet()
                // Dismiss the entire invite view after sharing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }) {
                if let message = inviteManager.shareMessage as String? {
                    ActivityView(activityItems: [message])
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .interactiveDismissDisabled(false)
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            }
            .onAppear {
                // Initialize permission status when view appears
                inviteManager.permissionStatus = CNContactStore.authorizationStatus(for: .contacts)
                print("📱 InviteContactsView appeared with permission status: \(inviteManager.permissionStatus.rawValue)")
                
                // If permission is already granted, fetch contacts immediately
                if inviteManager.permissionStatus == .authorized && inviteManager.contacts.isEmpty {
                    print("✅ Permission already granted, fetching contacts...")
                    inviteManager.fetchContacts()
                }
            }
            .onChange(of: inviteManager.permissionStatus) { newStatus in
                if newStatus == .authorized {
                    print("✅ Permission granted, fetching contacts...")
                    // Fetch contacts when permission is granted
                    if inviteManager.contacts.isEmpty {
                        inviteManager.fetchContacts()
                    }
                } 
            }
        }
    }
    
}

// Helper for UIActivityViewController
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        
        // Ensure the share sheet can be dismissed
        activityVC.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            // This will trigger the onDismiss of the sheet
        }
        
        // For iPad, set the popover presentation
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = CGRect(x: 0, y: 0, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Modern Search Bar
struct ModernSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            TextField("Search contacts", text: $text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// Modern Contact Row
struct ModernContactRow: View {
    let contact: CNContact
    let onInvite: () -> Void
    @State private var isInviting = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Contact avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Text(getInitials())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Contact info
            VStack(alignment: .leading, spacing: 4) {
                Text("\(contact.givenName) \(contact.familyName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                if let phone = contact.phoneNumbers.first?.value.stringValue {
                    Text(phone)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                } else if let email = contact.emailAddresses.first?.value as String? {
                    Text(email)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Invite button
            Button(action: {
                isInviting = true
                onInvite()
                
                // Reset after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isInviting = false
                }
            }) {
                HStack(spacing: 6) {
                    if isInviting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(isInviting ? "Inviting..." : "Invite")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.9), Color.blue.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .purple.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .disabled(isInviting)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func getInitials() -> String {
        let firstName = contact.givenName.prefix(1).uppercased()
        let lastName = contact.familyName.prefix(1).uppercased()
        return "\(firstName)\(lastName)"
    }
}


