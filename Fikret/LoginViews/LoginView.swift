import SwiftUI

struct LoginView: View {
    @EnvironmentObject var tweetData: TweetData  // Change to @EnvironmentObject
    
    @State var email: String = ""
    @State var password: String = ""
    @State  var errorMessage = ""
    @FocusState  var emailIsFocused: Bool
    @FocusState  var passwordIsFocused: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Header
            /*    HStack {
                    TwitterTopBarWithoutImage()
                        .frame(width: 30, height: 30)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)*/
                
                // Main Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Sign in to Twitter")
                            .font(.system(size: 28, weight: .bold))
                        
                        // Error Message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                        
                        // Input Fields
                        VStack(spacing: 16) {
                            TextField("", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .placeholder(when: email.isEmpty) {
                                    Text("Email")
                                        .foregroundColor(.gray)
                                }
                                .focused($emailIsFocused)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            
                            SecureField("", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .placeholder(when: password.isEmpty) {
                                    Text("Password")
                                        .foregroundColor(.gray)
                                }
                                .focused($passwordIsFocused)
                        }
                        
                        // Login Button
                        Button {
                            Task {
                                do {
                                  /*  try await tweetData.signIn(email: email, password: password)*/
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        } label: {
                            Text("Log in")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.blue)
                                .cornerRadius(22)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                }
                .onTapGesture {
                    emailIsFocused = false
                    passwordIsFocused = false
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// Helper extension for placeholder text
/*extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}*/

struct LoginView_Previews: PreviewProvider {
    static var previews: some View { 
        LoginView()
            .environmentObject(TweetData())  // Provide TweetData in preview
    }
}


