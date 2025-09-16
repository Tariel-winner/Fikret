import SwiftUI
/*
struct OTPVerificationView: View {
    @EnvironmentObject var tweetData: TweetData
    @State private var otp: String = ""
    @State private var message: String = ""
    @State private var isLoading: Bool = false
    @State private var timeRemaining: Int = 30
    @State private var canResend: Bool = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                TwitterTopBarWithoutImage()
                
                VStack(spacing: 30) {
                    Spacer()
                    Text("Verify Your Email")
                        .font(.system(size: 30, weight: .heavy))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 30)
                    
                    Text("We've sent a verification code to your email")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 30)
                    
                    VStack(spacing: 20) {
                        if !message.isEmpty {
                            Text(message)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(Color(.systemRed))
                                .padding(.horizontal, 35)
                        }
                        
                        TextField("Enter verification code", text: $otp)
                            .font(.headline)
                            .bold()
                            .foregroundColor(Color.primary)
                            .frame(width: UIScreen.main.bounds.width-90, height: 70)
                            .padding(.horizontal)
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray, lineWidth: 0.5)
                            }
                            .keyboardType(.numberPad)
                            .disabled(isLoading)
                    }
                    
                    if !canResend {
                        Text("Resend code in \(timeRemaining)s")
                            .foregroundColor(.gray)
                    }
                    
                    Button {
                        if canResend {
                            Task {
                                await handleResendOTP()
                            }
                        }
                    } label: {
                        Text("Resend Code")
                            .foregroundColor(canResend ? .blue : .gray)
                    }
                    .disabled(!canResend || isLoading)
                    
                    Spacer()
                    
                    Button {
                        Task {
                            await handleVerifyOTP()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: UIScreen.main.bounds.width-90, height: 60)
                                .background(Color(.systemBlue))
                                .cornerRadius(50)
                        } else {
                            Text("Verify")
                                .font(.title3)
                                .fontWeight(.heavy)
                                .foregroundColor(.white)
                                .frame(width: UIScreen.main.bounds.width-90, height: 60)
                                .background(Color(.systemBlue))
                                .cornerRadius(50)
                        }
                    }
                    .disabled(otp.isEmpty || isLoading)
                }
            }
            .navigationTitle("")
            .onReceive(timer) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    canResend = true
                }
            }
        }
    }
    
    private func handleVerifyOTP() async {
        isLoading = true
        do {
            try await tweetData.verifyOTP(otp: otp)
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
    }
    
    private func handleResendOTP() async {
        isLoading = true
        do {
            try await tweetData.resendOTP()
            timeRemaining = 30
            canResend = false
            message = "Verification code resent"
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
    }
}

struct OTPVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        OTPVerificationView()
            .environmentObject(TweetData())
    }
} 
*/
