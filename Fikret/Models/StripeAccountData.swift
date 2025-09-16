import SwiftUI
/*import Stripe
import StripeFinancialConnections
import Supabase
import os
import SafariServices
import Foundation
import Combine
// Logger for structured logging
private let logger = Logger(subsystem: "com.twitterclone", category: "StripeAccount")

// MARK: - Core Data Models

enum PaymentStatus {
    case success
    case failed
    case pending
}

// Structure for the request body
struct PaymentIntentRequest: Codable {
    let amount: Double
    let userId: String
    let sellerId: String
    let sellerAmount: Double
}



struct PaymentStatusRequest: Codable {
    let clientSecret: String
}

// Structure for the response from the edge function
struct PaymentStatusResponse: Codable {
    let status: String? // success, failed, or pending
    let error: String?
}

struct AccountLink: Codable {
    let url: String
    let created: Int
    let expiresAt: Int
}

// Add these new structures
struct StripeBalance: Codable {
    var available: String
    var pending: String
    var nextPayout: Date?
    var payoutSchedule: String
}

enum StripeAccountState: Equatable, Codable {
    case notStarted
    case pendingVerification([String])
    case pendingDocuments([String])
    case pendingBankAccount
    case verified
    case error(String)
    case pendingApproval
    
    static func == (lhs: StripeAccountState, rhs: StripeAccountState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted):
            return true
        case (.pendingVerification(let lhsReqs), .pendingVerification(let rhsReqs)):
            return lhsReqs == rhsReqs
        case (.pendingDocuments(let lhsDocs), .pendingDocuments(let rhsDocs)):
            return lhsDocs == rhsDocs
        case (.pendingBankAccount, .pendingBankAccount):
            return true
        case (.verified, .verified):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.pendingApproval, .pendingApproval):
            return true
        default:
            return false
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case requirements
        case documents
        case balance
        case error
    }
    
    private enum StateType: String, Codable {
        case notStarted
        case pendingVerification
        case pendingDocuments
        case pendingBankAccount
        case verified
        case error
        case pendingApproval
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(StateType.self, forKey: .type)
        
        switch type {
        case .notStarted:
            self = .notStarted
        case .pendingVerification:
            let requirements = try container.decode([String].self, forKey: .requirements)
            self = .pendingVerification(requirements)
        case .pendingDocuments:
            let documents = try container.decode([String].self, forKey: .documents)
            self = .pendingDocuments(documents)
        case .pendingBankAccount:
            self = .pendingBankAccount
        case .verified:
            let balance = try container.decode(StripeBalance.self, forKey: .balance)
            self = .verified
        case .error:
            let error = try container.decode(String.self, forKey: .error)
            self = .error(error)
        case .pendingApproval:
            self = .pendingApproval
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .notStarted:
            try container.encode(StateType.notStarted, forKey: .type)
        case .pendingVerification(let requirements):
            try container.encode(StateType.pendingVerification, forKey: .type)
            try container.encode(requirements, forKey: .requirements)
        case .pendingDocuments(let documents):
            try container.encode(StateType.pendingDocuments, forKey: .type)
            try container.encode(documents, forKey: .documents)
        case .pendingBankAccount:
            try container.encode(StateType.pendingBankAccount, forKey: .type)
        case .verified:
            try container.encode(StateType.verified, forKey: .type)
        case .error(let error):
            try container.encode(StateType.error, forKey: .type)
            try container.encode(error, forKey: .error)
        case .pendingApproval:
            try container.encode(StateType.pendingApproval, forKey: .type)
        }
    }
}

// Add this structure for bank account details
struct BankAccountInfo: Codable {
    let last4: String
    let bankName: String
    let accountType: String
    var isDefault: Bool
    let currency: String
    let status: String
}

// Add these Codable structs at the top
struct ProfileResponseStripe: Codable {
    let stripeConnectId: String?
    
    enum CodingKeys: String, CodingKey {
        case stripeConnectId = "stripe_connect_id"
    }
}

struct SellerStripeResponse: Codable {
    let stripeConnectId: String?
    
    enum CodingKeys: String, CodingKey {
        case stripeConnectId = "stripe_connect_id"
    }
}

struct StripeOnboardingState: Codable {
    // Essential state data
    var accountId: String?
    var isOnboarding: Bool
    var isVerified: Bool
    var currentStep: OnboardingStep
    var lastUpdated: Date
    var balance: StripeBalance?
}

enum OnboardingStep: Codable, Equatable {
    case notStarted
    case creatingAccount
    case pendingVerification([String])
    case pendingDocuments([String])
    case pendingApproval
    case pendingBankAccount
    case verified
    
    static func == (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted):
            return true
        case (.creatingAccount, .creatingAccount):
            return true
        case (.pendingVerification(let lhsReqs), .pendingVerification(let rhsReqs)):
            return lhsReqs == rhsReqs
        case (.pendingDocuments(let lhsDocs), .pendingDocuments(let rhsDocs)):
            return lhsDocs == rhsDocs
        case (.pendingBankAccount, .pendingBankAccount):
            return true
        case (.verified, .verified):
            return true
        case (.pendingApproval, .pendingApproval):
            return true
        default:
            return false
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case requirements
        case documents
    }
    
    private enum StepType: String, Codable {
        case notStarted
        case creatingAccount
        case pendingVerification
        case pendingDocuments
        case pendingBankAccount
        case verified
        case pendingApproval
    }
    
    init(from decoder: Decoder) throws {
          let container = try decoder.container(keyedBy: CodingKeys.self)
          let type = try container.decode(StepType.self, forKey: .type)
          
          switch type {
          case .notStarted:
              self = .notStarted
          case .creatingAccount:
              self = .creatingAccount
          case .pendingVerification:
              let requirements = try container.decode([String].self, forKey: .requirements)
              self = .pendingVerification(requirements)
          case .pendingDocuments:
              let documents = try container.decode([String].self, forKey: .documents)
              self = .pendingDocuments(documents)
          case .pendingBankAccount:
              self = .pendingBankAccount
          case .verified:
              self = .verified
          case .pendingApproval:
              self = .pendingApproval
          }
      } // Close the init(from:) here

      // Move the encode(to:) function outside the init(from:)
      func encode(to encoder: Encoder) throws {
          var container = encoder.container(keyedBy: CodingKeys.self)
          
          switch self {
          case .notStarted:
              try container.encode(StepType.notStarted, forKey: .type)
          case .creatingAccount:
              try container.encode(StepType.creatingAccount, forKey: .type)
          case .pendingVerification(let requirements):
              try container.encode(StepType.pendingVerification, forKey: .type)
              try container.encode(requirements, forKey: .requirements)
          case .pendingDocuments(let documents):
              try container.encode(StepType.pendingDocuments, forKey: .type)
              try container.encode(documents, forKey: .documents)
          case .pendingBankAccount:
              try container.encode(StepType.pendingBankAccount, forKey: .type)
          case .verified:
              try container.encode(StepType.verified, forKey: .type)
          case .pendingApproval:
              try container.encode(StepType.pendingApproval, forKey: .type)
          }
      }
    }
    
    // MARK: - StripeAccountData
    
    // Move LoadingState enum outside the class to make it internal
    enum LoadingState {
        case initializing
        case refreshing
        case onboarding
        case ready
        case error(String)
    }
    
    @MainActor
    final class StripeAccountData: ObservableObject {
        // Define the shared instance
        static let shared = StripeAccountData()
        private var refreshCancellable: AnyCancellable?
        private var refreshSubject = PassthroughSubject<Void, Never>()
        @Published  var lastSuccessfulRefresh: Date?
        // Core state
        @Published  var state: StripeOnboardingState
        
        // Loading state
        @Published var isLoading: Bool = false
        @Published private(set) var loadingState: LoadingState = .initializing
        private var isStatusCheckActive = false
        
        // Dependencies
        private weak var tweetData: TweetData?
        
        // UI state
        private var safariVC: SFSafariViewController?
        private var statusCheckTimer: Timer?
        
        // Add missing properties
        @Published private(set) var error: Error?
        
        init(tweetData: TweetData = .shared) {
            self.tweetData = tweetData
            loadingState = .initializing
            self.state = StripeOnboardingState( // Initial default state
                accountId: nil,
                isOnboarding: true,
                isVerified: false,
                currentStep: .notStarted,
                lastUpdated: Date()
            )
            // Observe changes in TweetData's user property
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(userDidUpdate),
                name: .userDidUpdate,
                object: nil
            )
            refreshCancellable = refreshSubject
                .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
                .sink { [weak self] in
                    Task {
                        await self?.refreshStripeAccountData()
                    }
                }
        }
        @objc private func userDidUpdate() {
            // Check if user data is available
            if let userId = tweetData?.user?.id {
                
                Task {
                    await refreshStripeAccountData()
                }
            } else {
                print("❌ User data not available yet.")
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        // Initialize with dependencies
        
        
        
        // MARK: - Core Methods
        func getAccountManagementLink(accountId: String) async throws -> URL {
            let url = URL(string: "https://api.stripe.com/v1/accounts/\(accountId)/login_links")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer YOUR_STRIPE_SECRET_KEY_HERE",
                             forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let responseJson = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            guard let managementUrl = responseJson?["url"] as? String,
                  let url = URL(string: managementUrl) else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get account management URL"])
            }
            
            return url
        }
        
        
        
        func resumeOnboarding() async {
            do {
                guard let userId = tweetData?.user?.id else { return }
                
                let response = try await supabase.from("profile")
                    .select("stripe_connect_id")
                    .eq("user_id", value: String(userId))
                    .execute()
                
                let profiles = try JSONDecoder().decode([ProfileResponseStripe].self, from: response.data ?? Data())
                
                guard let profile = profiles.first,
                      let stripeConnectId = profile.stripeConnectId,
                      !stripeConnectId.isEmpty else {
                    print("❌ No Stripe Connect ID found")
                    // If no Stripe account exists, start fresh onboarding
                    await handleBankConnection()
                    return
                }
                
                print("✅ Found Stripe Connect ID: \(stripeConnectId)")
                
                // Get new onboarding URL for existing account
                let url = try await getVerificationLink(accountId: stripeConnectId)
                
                print("🔗 Got verification URL: \(url)")
                
                // Present the onboarding URL
                await MainActor.run {
                    presentStripeOnboarding(url: url)
                    // Start checking status
                    
                }
            } catch {
                print("❌ Error in resumeOnboarding: \(error)")
            }
        }
        
        func refreshStripeAccountData() async {
            
            
            guard let userId = tweetData?.user?.id else {
                print("❌ No user ID found, cannot refresh Stripe account data.")
                return
            }
            await MainActor.run { isLoading = true }
            
            
            do {
                print("🔄 Refreshing Stripe account data for user ID: \(userId)")
                
                // Fetch profile to get Stripe Connect ID
                let response = try await supabase.from("profile")
                    .select("stripe_connect_id")
                    .eq("user_id", value: String(userId))
                    .execute()
                
                let profiles = try JSONDecoder().decode([ProfileResponseStripe].self, from: response.data ?? Data())
                
                guard let profile = profiles.first,
                      let stripeConnectId = profile.stripeConnectId,
                      !stripeConnectId.isEmpty else {
                    print("❌ No Stripe account exists yet for user ID: \(userId)")
                    state = StripeOnboardingState(
                        accountId: nil,
                        isOnboarding: true,
                        isVerified: false,
                        currentStep: .notStarted,
                        lastUpdated: Date(), balance: nil // Reset balance initially
                        
                    )
                    await MainActor.run { isLoading = false }
                    print("🔄 State set to initial: \(state)")
                    return
                }
                
                // Update ONLY accountId first
                await MainActor.run {
                         state.accountId = stripeConnectId
                         persistState()
                     }
                persistState()
                // Check current status
                let newState = await checkOnboardingStatus()
                
                await MainActor.run {
                    state = newState
                    persistState()
                    isLoading = false
                }
            } catch {
                print("❌ Error refreshing Stripe account data: \(error)")
                
                print("🔄 State updated to error: \(state)")
                persistState()
                await MainActor.run { isLoading = false }
            }
        }
        
        func startOnboarding() async {
            await MainActor.run { isLoading = true }
            
            do {
                guard let userId = tweetData?.user?.id,
                      let email = supabase.auth.currentUser?.email else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
                }
                
                
                
                // Create Stripe account
                let accountId = try await createStripeAccount(userId: String(userId), email: email)
                
                // Get verification link
                let url = try await getVerificationLink(accountId: accountId)
                
                // Update state and present onboarding
                await MainActor.run {
                    
                    
                    presentStripeOnboarding(url: url)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
        
        func checkOnboardingStatus() async -> StripeOnboardingState {
            guard let accountId = state.accountId else {
                print("❌ No account ID, setting state to notStarted")
                state = StripeOnboardingState(
                    accountId: nil,
                    isOnboarding: false,
                    isVerified: false,
                    currentStep: .notStarted,
                    lastUpdated: Date(),
                    balance: nil // Reset balance initially
                )
                await MainActor.run { isLoading = false }
                print("🔄 State set to notStarted: \(state)")
                return state
            }
            
            do {
                print("🔄 Checking onboarding status for account ID: \(accountId)")
                try await Task.sleep(nanoseconds: 2_000_000_000)
                let url = URL(string: "https://api.stripe.com/v1/accounts/\(accountId)")!
                var request = URLRequest(url: url)
                request.addValue("Bearer YOUR_STRIPE_SECRET_KEY_HERE",
                                 forHTTPHeaderField: "Authorization")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                print("🔵 Raw API Response:")
                
                      print(String(data: data, encoding: .utf8) ?? "Unable to decode response")
                      
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    print("❌ Account does not exist, setting state to notStarted")
                    state = StripeOnboardingState(
                        accountId: nil,
                        isOnboarding: false,
                        isVerified: false,
                        currentStep: .notStarted,
                        lastUpdated: Date(),
                        balance: nil // Reset balance initially
                    )
                    await MainActor.run { isLoading = false }
                    print("🔄 State set to notStarted: \(state)")
                    return state
                }
                
                let accountInfo = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                // Check verification status
                let chargesEnabled = accountInfo?["charges_enabled"] as? Bool ?? false
                let payoutsEnabled = accountInfo?["payouts_enabled"] as? Bool ?? false
                let detailsSubmitted = accountInfo?["details_submitted"] as? Bool ?? false
                
                // Determine current step - start with notStarted instead of pendingVerification
                var currentStep: OnboardingStep = .notStarted
                
                if chargesEnabled && payoutsEnabled {
                    currentStep = .verified
                } else if let requirements = accountInfo?["requirements"] as? [String: Any] {
                    let currentlyDue = requirements["currently_due"] as? [String] ?? []
                    let pendingVerification = requirements["pending_verification"] as? [String] ?? []
                    
                    if !currentlyDue.isEmpty {
                        currentStep = .pendingVerification(currentlyDue)
                    } else if !pendingVerification.isEmpty {
                        currentStep = .pendingDocuments(pendingVerification)
                    } else if detailsSubmitted && !chargesEnabled && !payoutsEnabled {
                        // All documents submitted, waiting for approval
                        currentStep = .pendingApproval
                    } else if !detailsSubmitted {
                        // If no details submitted, keep as notStarted
                        currentStep = .notStarted
                    }
                }
                
                print("🔄 Current onboarding step determined: \(currentStep)")
                
                // Update state
                state = StripeOnboardingState(
                       accountId: accountId,
                       isOnboarding: currentStep != .verified,
                       isVerified: currentStep == .verified,
                       currentStep: currentStep,
                       lastUpdated: Date(),
                       balance: nil // Reset balance initially
                   )
                persistState() // Add this
                print("""
                      \n📊 Stripe Status Analysis:
                      - Charges Enabled: \(chargesEnabled)
                      - Payouts Enabled: \(payoutsEnabled)
                      - Details Submitted: \(detailsSubmitted)
                      """)
                
                
                
                if currentStep == .verified {
                          let balance = try await getBalance()
                          state.balance = balance
                      }
                print("🔄 State updated after checking onboarding status: \(state)")
                await MainActor.run { isLoading = false }
                return state
            } catch {
                print("❌ Error checking onboarding status: \(error)")
                
                await MainActor.run { isLoading = false }
                print("🔄 State updated to error: \(state)")
                
            }
            return state
        }
        
        
        
        func createStripeAccount(userId: String, email: String) async throws -> String {
            print("\n💳 CREATE STRIPE ACCOUNT: Starting")
            print("├── User ID: \(userId)")
            print("├── Email: \(email)")
            let url = URL(string: "https://api.stripe.com/v1/accounts")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer YOUR_STRIPE_SECRET_KEY_HERE",
                             forHTTPHeaderField: "Authorization")
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let body = [
                "country": "US",
                "business_type": "individual",
                "email": email,
                "type": "express",
                "capabilities[card_payments][requested]": "true",
                "capabilities[transfers][requested]": "true"
            ].map { key, value in "\(key)=\(value)" }.joined(separator: "&")
            
            
            request.httpBody = body.data(using: .utf8)
            
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("├── Response status code: \(httpResponse.statusCode)")
                print("├── Response headers:")
                httpResponse.allHeaderFields.forEach { key, value in
                    print("│   ├── \(key): \(value)")
                }
            }
            
            print("├── Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode response")")
            
            
            let responseJson = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            print("├── Parsed JSON response: \(String(describing: responseJson))")
            
            guard let accountId = responseJson?["id"] as? String else {
                print("└── ❌ ERROR: No account ID in response")
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create Stripe account"])
            }
            
            print("├── ✅ Account created with ID: \(accountId)")
            
            // Save account ID to profile
            try await supabase.from("profile")
                .update(["stripe_connect_id": accountId])
                .eq("user_id", value: userId)
                .execute()
            
            return accountId
        }
        
        func getVerificationLink(accountId: String) async throws -> URL {
            let url = URL(string: "https://api.stripe.com/v1/account_links")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer YOUR_STRIPE_SECRET_KEY_HERE",
                             forHTTPHeaderField: "Authorization")
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let webRedirectUrl = "https://cl73494.tw1.ru"
            
            // Add collect parameter based on onboarding state
            var bodyParams = [
                "account": accountId,
                "type": "account_onboarding",
                "refresh_url": webRedirectUrl,
                "return_url": webRedirectUrl,
                "collect": "eventually_due"
            ]
            
            
            let body = bodyParams.map { key, value in "\(key)=\(value)" }.joined(separator: "&")
            request.httpBody = body.data(using: .utf8)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let responseJson = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            guard let accountLinkUrl = responseJson?["url"] as? String,
                  let url = URL(string: accountLinkUrl) else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get verification URL"])
            }
            
            return url
        }
        
        // MARK: - Bank Account Management
        
        // MARK: - Balance Management
        
        func getBalance() async throws -> StripeBalance {
            guard let accountId = state.accountId else {
                print("❌ No account ID found, cannot fetch balance.")
                return StripeBalance(available: "$0.00", pending: "$0.00", nextPayout: nil, payoutSchedule: "manual")
            }
            
            print("🔄 Fetching balance for account ID: \(accountId)")
            
            // Get balance
            let balanceUrl = URL(string: "https://api.stripe.com/v1/balance")!
            var balanceRequest = URLRequest(url: balanceUrl)
            balanceRequest.addValue("Bearer YOUR_STRIPE_SECRET_KEY_HERE",
                                    forHTTPHeaderField: "Authorization")
            balanceRequest.addValue("Stripe-Account: \(accountId)", forHTTPHeaderField: "Stripe-Account")
            
            let (balanceData, _) = try await URLSession.shared.data(for: balanceRequest)
            let balanceInfo = try JSONSerialization.jsonObject(with: balanceData, options: []) as? [String: Any]
            
            // Get payout schedule
            let accountUrl = URL(string: "https://api.stripe.com/v1/accounts/\(accountId)")!
            var accountRequest = URLRequest(url: accountUrl)
            accountRequest.addValue("Bearer YOUR_STRIPE_SECRET_KEY_HERE",
                                    forHTTPHeaderField: "Authorization")
            
            let (accountData, _) = try await URLSession.shared.data(for: accountRequest)
            let accountInfo = try JSONSerialization.jsonObject(with: accountData, options: []) as? [String: Any]
            
            // Calculate available and pending amounts
            var available = "$0.00"
            var pending = "$0.00"
            var nextPayoutDate: Date? = nil
            var schedule = "manual"
            
            if let availableBalances = balanceInfo?["available"] as? [[String: Any]],
               let amount = availableBalances.first?["amount"] as? Int {
                available = "$\(Double(amount) / 100)"
            }
            
            if let pendingBalances = balanceInfo?["pending"] as? [[String: Any]],
               let amount = pendingBalances.first?["amount"] as? Int {
                pending = "$\(Double(amount) / 100)"
            }
            
            if let settings = accountInfo?["settings"] as? [String: Any],
               let payouts = settings["payouts"] as? [String: Any],
               let scheduleInfo = payouts["schedule"] as? [String: Any] {
                schedule = scheduleInfo["interval"] as? String ?? "manual"
                
                if let nextPayoutSeconds = scheduleInfo["next_payout_at"] as? Double {
                    nextPayoutDate = Date(timeIntervalSince1970: nextPayoutSeconds)
                }
            }
            
            print("✅ Balance fetched: Available - \(available), Pending - \(pending), Schedule - \(schedule)")
            
            return StripeBalance(
                available: available,
                pending: pending,
                nextPayout: nextPayoutDate,
                payoutSchedule: schedule
            )
        }
        
        func updatePayoutSchedule(interval: String) async throws {
            guard let accountId = state.accountId else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No Stripe account found"])
            }
            
            let url = URL(string: "https://api.stripe.com/v1/accounts/\(accountId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer YOUR_STRIPE_SECRET_KEY_HERE",
                             forHTTPHeaderField: "Authorization")
            
            let body = "settings[payouts][schedule][interval]=\(interval)"
            request.httpBody = body.data(using: .utf8)
            
            let (_, resp) = try await URLSession.shared.data(for: request)
            guard let httpResponse = resp as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to update payout schedule"])
            }
        }
        
        func triggerRefresh() {
            refreshSubject.send(())
        }
        // MARK: - State Persistence
        private func validateStateTransition(from currentState: OnboardingStep, to newState: OnboardingStep) -> Bool {
            let isValid = switch (currentState, newState) {
            case (.notStarted, .creatingAccount),
                (.notStarted, .pendingVerification),
                (.creatingAccount, .pendingVerification),
                (.pendingVerification, .pendingDocuments),
                (.pendingVerification, .verified),
                (.pendingDocuments, .pendingVerification),
                (.pendingDocuments, .verified),
                (.pendingBankAccount, .verified),
                // Allow same-state transitions for data refresh
                (.pendingVerification, .pendingVerification),
                (.pendingDocuments, .pendingDocuments),
                (.pendingApproval, .pendingApproval):
                true
            default:
                currentState == newState // Allow same-state updates
            }
            
            if !isValid {
                print("⚠️ Invalid state transition: \(currentState) -> \(newState)")
            }
            return isValid
        }
        
    
        
       
        
        // MARK: - UI Methods
        
        
        func presentStripeOnboarding(url: URL) {
            print("🔵 Presenting Safari view for URL: \(url)")
            
            let safariVC = SFSafariViewController(url: url)
            safariVC.delegate = Coordinator(parent: self)
            safariVC.preferredBarTintColor = .systemBackground
            safariVC.preferredControlTintColor = .blue
            
            // Store the current state before presenting Safari
            let currentState = state
            
            // Get the current window scene
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                print("🔵 Found root view controller")
                
                
                // First dismiss any presented controller
                if let presented = rootVC.presentedViewController {
                    print("🔵 Dismissing existing presented controller")
                    presented.dismiss(animated: true) {
                        print("🔵 Presenting new Safari controller")
                        rootVC.present(safariVC, animated: true) {
                            print("✅ Safari view presented successfully")
                            self.safariVC = safariVC
                            // Store the state we were in when starting∂ç onboarding
                            
                        }
                    }
                } else {
                    print("🔵 No existing controller, presenting Safari directly")
                    rootVC.present(safariVC, animated: true) {
                        print("✅ Safari view presented successfully")
                        self.safariVC = safariVC
                        
                    }
                }
            } else {
                print("❌ Could not find root view controller")
            }
        }
        
        // MARK: - Coordinator
        
        class Coordinator: NSObject, SFSafariViewControllerDelegate {
            let parent: StripeAccountData
            
            init(parent: StripeAccountData) {
                self.parent = parent
            }
            
            func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
                Task { @MainActor in
                    parent.safariVC = nil
                    parent.isLoading = true
                    
                    if parent.state.isOnboarding {
                        parent.loadingState = .refreshing
                        await parent.checkOnboardingStatus()
                        
                        
                        NotificationCenter.default.post(name: Notification.Name("StripeOnboardingCompleted"), object: nil)
                    }
                    parent.loadingState = .ready
                }
            }
        }
        
        func handleBankConnection() async {
            do {
                guard let userId = tweetData?.user?.id,
                      let email = supabase.auth.currentUser?.email else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
                }
                
                print("\n🔄 STRIPE: Starting bank connection process")
                print("👤 STRIPE: User ID: \(userId)")
                print("📧 STRIPE: Email: \(email)")
                
                // Create Stripe account
                let accountId = try await createStripeAccount(userId: String(userId), email: email)
                guard !accountId.isEmpty else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create Stripe account"])
                }
                
                print("✅ STRIPE: Account created with ID: \(accountId)")
                
                // Get verification link
                let url = try await getVerificationLink(accountId: accountId)
                
                print("🔗 STRIPE: Got verification URL: \(url)")
                
                // Update state
                state = StripeOnboardingState(
                    accountId: accountId,
                    isOnboarding: true,
                    isVerified: false,
                    currentStep: .pendingVerification([]),
                    lastUpdated: Date()
                )
                
                
                
            } catch {
                print("❌ STRIPE: Error in handleBankConnection: \(error)")
                
            }
        }
        
        
        func retryFromError() async {
            
            loadingState = .refreshing
            await refreshStripeAccountData()
            
            if !state.isVerified {
                await resumeOnboarding()
            }
            
            loadingState = .ready
        }
        func persistState() {
            do {
                // 1. Validate state before persisting
          
                
                // 2. Use proper error handling
                let stateData = try JSONEncoder().encode(state)
                
                // 3. Atomic write operation
                UserDefaults.standard.set(stateData, forKey: "stripeOnboardingState")
                
                print("✅ State persisted successfully")
            } catch {
                print("❌ State persistence failed: \(error)")
                // Consider reverting to last known good state
            }
        }

        private func isValidState(_ state: StripeOnboardingState) -> Bool {
            // Example validation logic
            switch state.currentStep {
            case .verified:
                return state.accountId != nil && state.isVerified
            case .pendingVerification:
                return state.accountId != nil && !state.isVerified
            case .notStarted:
                return state.accountId == nil
            default:
                return state.accountId != nil
            }
        }
        
        
        
        
        
        func clearUserDefaults() {
            UserDefaults.standard.removeObject(forKey: "stripeOnboardingState")
            UserDefaults.standard.synchronize()
        }
        // MARK: - Status Checking
        
        // MARK: - Preview Support
        
        static var preview: StripeAccountData {
            let data = StripeAccountData()
            data.state = StripeOnboardingState(
                accountId: nil,
                isOnboarding: false,
                isVerified: false,
                currentStep: .notStarted,
                lastUpdated: Date()
            )
            return data
        }
        
        // Add methods to update state
        func updateState(_ newState: StripeOnboardingState) {
            assert(Thread.isMainThread, "State updates must happen on main thread")
            print("🔄 Attempting to update state from \(state.currentStep) to \(newState.currentStep)")
            print("🔄 Attempting to update state from \(state.currentStep) to \(newState.currentStep)")
            state = newState
            print("✅ State successfully updated to \(state.currentStep)")
            if state.currentStep == .verified {
                print("🎉 State is now verified. Full state: \(state)")
            }
        }
        
        
        func setLoading(_ isLoading: Bool) {
            self.isLoading = isLoading
        }
    }

*/
