//
//  ForgotPasswordView.swift
//  TwitterClone
//
//  Created by Rohit Sridharan on 24/04/23.
//

import SwiftUI
/*
struct ForgotPasswordView: View {
    @StateObject private var userService = UserService()
    @Environment(\.dismiss) private var dismiss
    
    @State var email: String = ""
    @State var password: String = ""
    @State var confirmPassword: String = ""
    @State private var errorMessage = ""
    @State private var isSuccess = false
    @FocusState private var emailIsFocused: Bool
    @FocusState private var passwordIsFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
              //  TwitterTopBarWithoutImage()
                
                Rectangle()
                    .fill(.background)
                    .onTapGesture {
                        emailIsFocused = false
                        passwordIsFocused = false
                    }
                    .gesture(DragGesture().onChanged { value in
                        if value.translation.height > 0 {
                            emailIsFocused = false
                            passwordIsFocused = false
                        }
                    })
                
                VStack(spacing: 50) {
                    Spacer()
                    
                    Text("Forgot password")
                        .font(.system(size: 30, weight: .heavy))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 30)
                    
                    VStack(spacing: 20) {
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(Color(.systemRed))
                                .padding(.horizontal, 35)
                        }
                        
                        TextField("Enter email", text: $email)
                            .font(.headline)
                            .bold()
                            .foregroundColor(Color.primary)
                            .frame(width: UIScreen.main.bounds.width-90, height: 70)
                            .padding(.horizontal)
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray, lineWidth: 0.5)
                            }
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($emailIsFocused)
                        
                        SecureField("New Password", text: $password)
                            .font(.headline)
                            .bold()
                            .frame(width: UIScreen.main.bounds.width-90, height: 70)
                            .padding(.horizontal)
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray, lineWidth: 0.5)
                            }
                            .focused($passwordIsFocused)
                        
                        SecureField("Confirm password", text: $confirmPassword)
                            .font(.headline)
                            .bold()
                            .frame(width: UIScreen.main.bounds.width-90, height: 70)
                            .padding(.horizontal)
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray, lineWidth: 0.5)
                            }
                    }
                    
                    Spacer()
                    
                    Button {
                        Task {
                            await handlePasswordReset()
                        }
                    } label: {
                        Text("Reset password")
                            .font(.title3)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                            .frame(width: UIScreen.main.bounds.width-90, height: 60)
                            .background(Color(.systemBlue))
                            .cornerRadius(50)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("")
            .alert("Password Reset", isPresented: $isSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Password reset email has been sent. Please check your inbox.")
            }
        }
    }
    
    private func handlePasswordReset() async {
        do {
            // Validate inputs
            guard !email.isEmpty else {
                errorMessage = "Please enter your email"
                return
            }
            
            guard !password.isEmpty else {
                errorMessage = "Please enter a new password"
                return
            }
            
            guard password == confirmPassword else {
                errorMessage = "Passwords don't match"
                return
            }
            
            // Send password reset request
           /* try await supabase.auth.resetPasswordForEmail(email)*/
            isSuccess = true
            errorMessage = ""
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordView()
    }
}*/
