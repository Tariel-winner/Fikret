import Foundation
import SwiftUI
/*import Supabase

class UserListService {
    func fetchUsers() async throws -> [UserProfile] {
        let currentUserId = supabase.auth.currentUser?.id
        
        return try await supabase
            .from("profile")
            .select()
            .neq("user_id", value: currentUserId)
            .order("name")
            .execute()
            .value
    }
} 
*/
