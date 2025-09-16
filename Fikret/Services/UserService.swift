import Foundation
import SwiftUI
/*import Supabase

@MainActor
class UserService: ObservableObject {
    @Published var authState: AuthState = .signedOut
    
    enum AuthState {
        case signedOut
        case signedIn
    }
    
    init() {
        setupAuthSubscription()
    }
    
    private func setupAuthSubscription() {
        Task {
            for await (event, _) in supabase.auth.authStateChanges {
                switch event {
                case .signedIn:
                    self.authState = .signedIn
                case .signedOut:
                    self.authState = .signedOut
                default:
                    break
                }
            }
        }
    }
 

    func signUp(email: String, password: String, username: String, name: String) async throws {
    // 1. Validate inputs
    guard !username.isEmpty, !name.isEmpty else {
        throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Username and name are required"])
    }
    
    print("\n1️⃣ Starting signup process...")
    
    // 2. First create the auth user
    let authResponse = try await supabase.auth.signUp(
        email: email,
        password: password
    )
    
   let userId = authResponse.user.id  // User is non-optional
    print("✅ Auth user created with ID: \(userId)")
    
    
    print("✅ Auth user created with ID: \(userId)")
    
    // 3. Create the profile record
    print("\n2️⃣ Creating profile...")
    
    struct ProfileCreate: Encodable {
        let user_id: UUID
        let username: String
        let name: String
        let bio: String
        let location: String
        let website: String
        let profilepicture: String
    }
    
    let profile = ProfileCreate(
        user_id: userId,
        username: username,
        name: name,
        bio: "",
        location: "",
        website: "",
        profilepicture: ""
    )
    
    try await supabase
        .from("profile")
        .insert(profile)
        .execute()
    
    print("""
    ✅ User signup complete:
    - Email: \(email)
    - Username: \(username)
    - Name: \(name)
    - User ID: \(userId)
    """)
}
    
    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
    }
    
    func searchUsers(query: String) async throws -> [UserProfile] {
        let users: [UserProfile] = try await supabase
            .from("profiles")
            .select()
            .or("name.ilike.%\(query)%,username.ilike.%\(query)%")
            .limit(10)
            .execute()
            .value
        
        return users
    }
    
 
    
    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
    
    func updatePassword(newPassword: String) async throws {
        try await supabase.auth.update(user: UserAttributes(password: newPassword))
    }
 
}



*/
