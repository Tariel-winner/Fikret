import SwiftUI
//import Supabase
/*

@MainActor
class UserListViewModel: ObservableObject {
    @Published private(set) var users: [UserProfile] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let userListService: UserListService
    
    init(userListService: UserListService = UserListService()) {
        self.userListService = userListService
        Task {
            await fetchUsers()
        }
    }
    
    func fetchUsers() async {
        isLoading = true
        error = nil
        
        do {
            users = try await userListService.fetchUsers()
            print("✅ Fetched \(users.count) users")
        } catch {
            print("❌ Error fetching users:", error)
            self.error = error
        }
        
        isLoading = false
    }
} 
*/
