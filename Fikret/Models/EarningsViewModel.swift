import SwiftUI
/*import Supabase

class EarningsViewModel: ObservableObject {
    @Published var totalEarnings: Double = 0
    @Published var pendingWithdrawals: Double = 0
    @Published var availableBalance: Double = 0
    @Published var walletAddress: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var withdrawalStatus: WithdrawalStatus = .none
    @Published var feeAmount: Double = 0
    @Published var netAmount: Double = 0
    
    // Simplified models matching DB schema
    struct StreamPayment: Codable {
        let id: UUID
        let streamer_id: UUID
        let viewer_id: UUID?
        let stream_id: UUID?
        let amount: Decimal
        let is_paid_out: Bool
        let created_at: Date
        let apple_transaction_id: String?
    }
    
    struct UserWallet: Codable {
        let id: UUID
        let user_id: UUID
        let wallet_address: String
        let is_verified: Bool
        let min_withdrawal: Decimal?
        let withdrawal_fee: Decimal?
        let created_at: Date
    }
    
    struct WithdrawalRequest: Codable {
        let id: UUID
        let user_id: UUID
        let wallet_address: String
        let amount: Decimal
        let fee_amount: Decimal
        let net_amount: Decimal
        let status: String
        let transaction_hash: String?
        let created_at: Date
        let processed_at: Date?
        let error_message: String?
    }
    
    enum WithdrawalStatus: String, Codable {
        case none = "none"
        case pending = "pending"
        case processing = "processing"
        case completed = "completed"
        case failed = "failed"
        
        func canTransitionTo(_ newStatus: WithdrawalStatus) -> Bool {
            switch (self, newStatus) {
            case (.none, .pending),
                 (.pending, .processing),
                 (.processing, .completed),
                 (.processing, .failed),
                 (.failed, .pending): // Allow retry
                return true
            default:
                return false
            }
        }
    }
    
    var canWithdraw: Bool {
        totalEarnings >= 100 && walletAddress != nil
    }
    
    // Validation for TRON wallet address
    func isValidTronAddress(_ address: String) -> Bool {
        // TRON addresses start with "T" and are 34 characters long
        return address.starts(with: "T") && address.count == 34
    }
    
    func loadEarnings() async {
       
        isLoading = true
        errorMessage = nil
        
       guard let userId = supabase.auth.currentUser?.id else {
                self.errorMessage = "User not found"
                self.isLoading = false
                return
            }
        do {
            // 1. Fetch wallet
            if let wallet = try? await fetchUserWallet() {
                        guard wallet.is_verified else {
                            throw WithdrawalError.noWalletConnected
                        }
                        self.walletAddress = wallet.wallet_address
                    } else {
                        throw WithdrawalError.noWalletConnected
                    }
            
            // 2. Fetch unpaid stream payments
            let paymentsResponse = try await supabase.from("stream_payments")
                .select("id, amount, is_paid_out")
                .eq("streamer_id", value: userId)
                .eq("is_paid_out", value: false)
                .execute()
            
            // 3. Fetch pending withdrawals
            let withdrawalsResponse = try await supabase.from("withdrawal_requests")
                .select("amount")
                .eq("user_id", value: userId)
                .eq("status", value: "pending")
                .execute()
            
            // Fix: Handle Supabase response data correctly

             if let payments = try? JSONDecoder().decode([StreamPayment].self, from: paymentsResponse.data ?? Data()) {
                        let totalPayments = payments.reduce(Decimal.zero) { $0 + $1.amount }
                        self.totalEarnings = Double(truncating: totalPayments as NSNumber)
                    }
                    
                    // 5. Process withdrawals
                    if let withdrawals = try? JSONDecoder().decode([WithdrawalRequest].self, from: withdrawalsResponse.data ?? Data()) {
                        let pendingAmount = withdrawals.first?.amount ?? Decimal.zero
                        self.pendingWithdrawals = Double(truncating: pendingAmount as NSNumber)
                        if let firstWithdrawal = withdrawals.first {
                            self.withdrawalStatus = WithdrawalStatus(rawValue: firstWithdrawal.status) ?? .none
                        }
                    }
           
                  self.availableBalance = self.totalEarnings - self.pendingWithdrawals
                        
                            self.feeAmount = Double(truncating: (Decimal(self.totalEarnings) * (1 / 100)) as NSNumber)
                            self.netAmount = self.availableBalance - self.feeAmount
                        
                        self.isLoading = false
                
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.totalEarnings = 0
                self.pendingWithdrawals = 0
                self.availableBalance = 0
                self.feeAmount = 0
                self.netAmount = 0
                self.isLoading = false
         
            }
        }
       }
     
    
    // First, create a struct for wallet data
    struct WalletData: Encodable {
        let wallet_address: String
        let user_id: UUID
        let network: String
        let currency: String
        let status: String
        let is_verified: Bool
        let created_at: String
        let last_used: String?
        let withdrawal_limit: Decimal
        let min_withdrawal: Decimal
        let withdrawal_fee: Decimal
        let payout_schedule: String?
    }
    
    func saveWalletAddress(_ address: String) async throws {
        guard isValidTronAddress(address) else {
            throw ValidationError.invalidWalletAddress
        }
        
        guard let userId = supabase.auth.currentUser?.id else {
            throw WithdrawalError.noUserFound
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let walletData = WalletData(
                wallet_address: address,
                user_id: userId,
                network: "TRON",
                currency: "USDT",
                status: "active",
                is_verified: true,
                created_at: ISO8601DateFormatter().string(from: Date()),
                last_used: nil,
                withdrawal_limit: 5000,
                min_withdrawal: 100,
                withdrawal_fee: 1,
                payout_schedule: "instant"
            )
            
            try await supabase.from("user_wallets")
                .upsert(walletData)
                .execute()
            
            await MainActor.run {
                self.walletAddress = address
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save wallet: \(error.localizedDescription)"
                self.isLoading = false
            }
            throw error
        }
    }
    
    func requestWithdrawal() async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw WithdrawalError.noUserFound
        }
        // Fix: Remove redundant optional binding for wallet_address
        guard let walletAddress = self.walletAddress else {
            throw WithdrawalError.noWalletConnected
        }
        
        // Verify we have funds
        guard totalEarnings >= 100  else {
            throw WithdrawalError.insufficientFunds
        }
        // 3. Start database transaction
        try await supabase.rpc("begin_transaction").execute()
        
        do {
            let pendingWithdrawal = try await supabase.from("withdrawal_requests")
                .select("id")
                .eq("user_id", value: userId)
                .eq("status", value: "pending")
                .single()
                .execute()
            
            if pendingWithdrawal.data != nil {
                throw WithdrawalError.existingPendingWithdrawal
            }
            // 4. Create withdrawal request
            let withdrawalRequest = WithdrawalRequest(
                id: UUID(),
                user_id: userId,
                wallet_address: walletAddress,
                amount: Decimal(totalEarnings),
                fee_amount: Decimal(feeAmount),
                net_amount: Decimal(netAmount),
                status: "pending",
                transaction_hash: nil,
                created_at: Date(),
                processed_at: nil,
                error_message: nil
            )
            
            // 5. Insert withdrawal request
            try await supabase.from("withdrawal_requests")
                .insert(withdrawalRequest)
                .execute()
            
            // 6. Mark related payments as paid out
            try await supabase.from("stream_payments")
                .update(["is_paid_out": true])
                .eq("streamer_id", value: userId)
                .eq("is_paid_out", value: false)
                .execute()
            
            // 7. Commit transaction
            try await supabase.rpc("commit_transaction").execute()
            
            await MainActor.run {
                self.withdrawalStatus = .pending
                // Refresh earnings after successful withdrawal
                self.pendingWithdrawals = self.totalEarnings
                self.availableBalance = 0
            }
        } catch {
            // 8. Rollback on error
            try? await supabase.rpc("rollback_transaction").execute()
            throw error
        }
    }
    
    
    
    
    
    
    private func fetchUserWallet() async throws -> UserWallet? {
        guard let userId = supabase.auth.currentUser?.id else {
            throw WithdrawalError.noUserFound
        }
        
        let response = try await supabase.from("user_wallets")
            .select("*")
            .eq("user_id", value: userId)
            .single()
            .execute()
        
        return try? JSONDecoder().decode(UserWallet.self, from: response.data)
    }
    
    
    
    
    
    
    // Custom errors for better error handling
    enum ValidationError: LocalizedError {
        case invalidWalletAddress
        
        var errorDescription: String? {
            switch self {
            case .invalidWalletAddress:
                return "Invalid TRON wallet address. Please check and try again."
            }
        }
    }
    
    enum WithdrawalError: LocalizedError {
        case existingPendingWithdrawal
        case noWalletConnected
        case noUserFound
        case insufficientFunds
        case belowMinimum(minimum: Double)
        case invalidStatusTransition
        case requestNotFound
        
        var errorDescription: String? {
            switch self {
            case .existingPendingWithdrawal:
                return "You have a pending withdrawal. Please wait for it to be processed."
            case .noWalletConnected:
                return "Please connect a verified wallet before withdrawing"
            case .noUserFound:
                return "User not found. Please try again"
            case .insufficientFunds:
                return "Insufficient funds for withdrawal"
            case .belowMinimum(let minimum):
                return "Minimum withdrawal amount is $\(minimum)"
            case .invalidStatusTransition:
                return "Invalid status transition"
            case .requestNotFound:
                return "Withdrawal request not found"
            }
        }
    }
}
*/
