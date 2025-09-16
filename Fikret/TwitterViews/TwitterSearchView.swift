import SwiftUI
/*
struct TwitterSearchView: View {
    @StateObject private var userService = UserService()
    @State var isEditing = false
    @State var searchField = ""
    @FocusState private var isFocused: Bool
    @Binding var isProfilePictureClicked: Bool
    @EnvironmentObject var tweets: TweetData
    @State private var users: [UserProfile] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack(alignment: .top) {
            TwitterSearchBar(searchField: $searchField, isEditing: $isEditing, isClicked: $isProfilePictureClicked)
                .autocorrectionDisabled()
                .zIndex(2)
                .environmentObject(tweets)
                .onChange(of: searchField) { query in
                    searchUsers(query: query)
                }
            
            if !isEditing {
                ScrollView {
                    Spacer(minLength: 90)
                    HStack {
                        Text("Suggested Accounts")
                            .font(.title3)
                            .bold()
                            .padding()
                        Spacer()
                    }
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        UserListView(users: users)
                    }
                }
            } else {
                ScrollView {
                    Spacer(minLength: 90)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        UserListView(users: users)
                    }
                }
            }
        }
        .onAppear {
            loadSuggestedUsers()
        }
        .onTapGesture {
            if isProfilePictureClicked {
                withAnimation(.linear(duration: 0.2)) {
                    isProfilePictureClicked = false
                }
            }
        }
    }
    
    private func searchUsers(query: String) {
        guard !query.isEmpty else {
            loadSuggestedUsers()
            return
        }
        
        Task {
            isLoading = true
            do {
                users = try await userService.searchUsers(query: query)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func loadSuggestedUsers() {
        Task {
            isLoading = true
            do {
                users = try await userService.getSuggestedUsers()
                errorMessage = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
*/
