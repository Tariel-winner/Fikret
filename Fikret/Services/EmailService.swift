import Foundation
/*import SwiftSMTP

struct SMTPConfig {
    static let host = "email-smtp.us-east-1.amazonaws.com"
    static let port = 465  // TLS Wrapper Port
    static let username = "YOUR_SMTP_USERNAME"  // Your SMTP credentials
    static let password = "YOUR_SMTP_PASSWORD"  // Your SMTP credentials
    static let fromEmail = "your-verified-email@domain.com"  // Your verified SES email
}

enum EmailError: Error {
    case configurationError
    case sendError(String)
}

class EmailService {
    static let shared = EmailService()
    private let smtp: SMTP
    
    private init() {
        smtp = SMTP(
            hostname: SMTPConfig.host,
            port: SMTPConfig.port,
            username: SMTPConfig.username,
            password: SMTPConfig.password,
            timeout: 10,
            security: .ssl  // Using SSL for port 465
        )
    }
    
    func sendOTPEmail(to recipient: String, otp: String) async throws {
        let email = Mail(
            from: Mail.User(email: SMTPConfig.fromEmail),
            to: [Mail.User(email: recipient)],
            subject: "Your Twitter Clone Verification Code",
            text: """
                Your verification code is: \(otp)
                
                This code will expire in 5 minutes.
                
                If you didn't request this code, please ignore this email.
                
                Best regards,
                Twitter Clone Team
                """,
            html: """
                <html>
                <body style="font-family: Arial, sans-serif; padding: 20px;">
                    <h2 style="color: #1DA1F2;">Twitter Clone Verification</h2>
                    <p>Your verification code is:</p>
                    <h1 style="font-size: 32px; letter-spacing: 5px; color: #1DA1F2; padding: 20px; background-color: #f8f9fa; border-radius: 10px; text-align: center;">
                        \(otp)
                    </h1>
                    <p>This code will expire in <strong>5 minutes</strong>.</p>
                    <p style="color: #657786; font-size: 12px; margin-top: 20px;">
                        If you didn't request this code, please ignore this email.
                    </p>
                    <hr style="border: none; border-top: 1px solid #eaeaea; margin: 20px 0;">
                    <p style="color: #657786; font-size: 12px;">
                        Best regards,<br>
                        Twitter Clone Team
                    </p>
                </body>
                </html>
                """
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            smtp.send(email) { error in
                if let error = error {
                    continuation.resume(throwing: EmailError.sendError(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// Helper extension for generating OTP
extension EmailService {
    static func generateOTP(length: Int = 6) -> String {
        var otp = ""
        for _ in 0..<length {
            otp += String(Int.random(in: 0...9))
        }
        return otp
    }
} 
*/
