import SwiftUI
//import FirebaseFirestore

//import Stripe
//import StripePaymentSheet

struct QueueView: View {
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: SpacesViewModel
    @State private var showClosedPopup = false
    @State private var showTopicModal = false
    @State private var userTopic = ""
    @State private var showUserTopicModal = false
    @State private var selectedUserTopic: String?
    @State private var isTyping = false
     @State private var isPaymentInProgress: Bool = false
    var selectedQueue: Queue? {
        viewModel.selectedSpace?.queue
    }
     @State private var paymentIntentClientSecret: String? = nil
    
    // Add new state variables
    @State private var paymentStatus: PaymentStatus = .none
    @State private var showPaymentError = false
    @State private var paymentErrorMessage = ""
    @State private var showPaymentSuccess = false
    @State private var paymentProgress: CGFloat = 0
    @State private var showPaymentSheet = false
    
    // Add PaymentSheet states
  //  @State private var paymentSheet: PaymentSheet?
    //@State private var paymentResult: PaymentSheetResult?
    @State private var isPaymentSheetReady = false
    
    // Add at the top with other @State properties
    @State private var headerOffset: CGFloat = -50
    @State private var headerOpacity: Double = 0
    @State private var animateBackground = false
    
    enum PaymentStatus {
        case none
        case processing
        case success
        case failed
        case canceled
    }
    
    let columns = [GridItem(.adaptive(minimum: 80))]
    let gridSpacing: CGFloat = 20
    
    var currentUser: QueueUser? {
        guard let userId = viewModel.tweetData.user?.id else { return nil }
        return viewModel.selectedSpace?.queue.participants.first { $0.id == userId }
    }
    
    var buttonDisabled: Bool {
        viewModel.selectedSpace?.queue.isClosed ?? true || viewModel.isProcessingQueue
    }
    
   /* private var actionButtons: some View {
        Group {
            if let user = currentUser {
                if user.isInvited {
                    HStack(spacing: 16) {
                        // Leave Button
                        Button(action: {
                           /* Task {
                                print("🚀 Button Pressed: Leaving queue")
                                await viewModel.leaveQueue()
                                viewModel.showQueueView = false
                            }*/
                        }) {
                            Text("Leave")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(
                                    LinearGradient(gradient: Gradient(colors: [.red, .orange]), startPoint: .leading, endPoint: .trailing),
                                    in: Capsule()
                                )
                                .shadow(color: .orange.opacity(0.5), radius: 10, x: 0, y: 0)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Join/Payment Button
                        Button(action: {
                            Task {
                                let price = 0.0
                                if price <= 0 {
                                    // If price is 0, directly join the space
                                    print("🆓 Free space - directly joining")
                                    await viewModel.queueButtonTapped()
                                } else {
                                    // If price > 0, start payment process
                                    print("\n💰 PAYMENT FLOW: Starting payment process")
                                   // await handlePayment(user: user)
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                // Icon
                          
                                
                                Spacer(minLength: 8)
                            
                            }
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 0)
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(isPaymentInProgress)
                    }
                    .padding(.horizontal)
                } else {
                    // Non-invited user button with consistent width
                    Button(action: {
                        Task {
                            print("🚀 Button Pressed: Leaving queue")
                            await viewModel.leaveQueue()
                            viewModel.showQueueView = false
                        }
                    }) {
                        Text("Leave Queue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                LinearGradient(gradient: Gradient(colors: [.red, .orange]), startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                            .shadow(color: .orange.opacity(0.5), radius: 10, x: 0, y: 0)
                    }
                    .padding(.horizontal)
                }
            } else {
                // Join Queue button with consistent width
                Button(action: {
                    withAnimation(.spring()) {
                        showTopicModal = true
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 24)
                        
                        Text("Join Queue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(minWidth: 100)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                    .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 0)
                }
                .padding(.horizontal)
                .disabled(buttonDisabled)
            }
        }
        .disabled(buttonDisabled)
        .opacity(buttonDisabled ? 0.4 : 1)
        .scaleEffect(buttonDisabled ? 0.95 : 1.0)
        .animation(.spring(), value: buttonDisabled)
    }*/
    
/*    private func handlePayment(user: QueueUser) async {
        let price = viewModel.selectedSpace?.price ?? 0.0
        
        // If price is 0, skip payment process
        if price <= 0 {
            print("🆓 Free space - skipping payment process")
            await viewModel.queueButtonTapped()
            return
        }
        
        print("🟢 Starting handlePayment function")

        // Check and set the publishable key if it's nil
        guard STPAPIClient.shared.publishableKey != nil else {
            print("❌ Stripe publishable key is not set")
            return
        }

        do {
            isPaymentInProgress = true
            print("🔄 Payment in progress: \(isPaymentInProgress)")
            guard let seller = viewModel.selectedSpace?.hostId else { return  }
            // Fetch the client secret for the PaymentIntent
            print("🔍 Fetching client secret for PaymentIntent...")
            let paymentIntentResponse = try await viewModel.createPaymentIntent(
                amount: viewModel.selectedSpace?.price ?? 10.0,
                sellerId: String(seller).lowercased() ?? ""
            )
            let customAPIClient = STPAPIClient(publishableKey:"pk_test_51OYr6bEL5j6LpNh8shdEVrGTCvUZGTldcqmnuqGnRHDl4hEkIBtgcxwPHTkDp4vBcMsuBDCJKEwgJBoWXAbUqiIe00Pzxyl3gg")

                  // Configure PaymentSheet
                  print("⚙️ Configuring PaymentSheet...")
                  var configuration = PaymentSheet.Configuration()
                  configuration.apiClient = customAPIClient
            
         
            configuration.merchantDisplayName = "Agora"
            configuration.defaultBillingDetails.email = ""
            configuration.allowsDelayedPaymentMethods = true
            configuration.returnURL = "https://cl73494.tw1.ru" // Set your custom return URL
            //configuration.customer = .init(id: paymentIntentResponse.customer, ephemeralKeySecret: paymentIntentResponse.ephemeralKey)
            print("⚙️ PaymentSheet configuration: \(configuration)")

            // Create PaymentSheet instance
            print("🛠️ Creating PaymentSheet instance...")
            let paymentSheet = PaymentSheet(
                paymentIntentClientSecret: paymentIntentResponse.clientSecret,
                configuration: configuration
            )
            print("🛠️ PaymentSheet instance created")

            // Update UI on the main thread
            await MainActor.run {
                self.paymentSheet = paymentSheet
                self.isPaymentSheetReady = true
                print("🔄 PaymentSheet and isPaymentSheetReady updated on MainActor")
           }

            // Present PaymentSheet from the current view controller
            print("🔍 Looking for the topmost view controller to present PaymentSheet...")
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {

                // Find the topmost presented view controller
                var topViewController = rootViewController
                while let presentedViewController = topViewController.presentedViewController {
                    topViewController = presentedViewController
                }
                print("🔍 Topmost view controller found: \(topViewController)")

                // Present the PaymentSheet from the topmost view controller
                print("🔄 Presenting PaymentSheet...")
                paymentSheet.present(from: topViewController) { result in
                    Task { @MainActor in
                        switch result {
                        case .completed:
                            print("✅ Payment completed successfully")
                            do {
                                print("🔄 Calling queueButtonTapped...")
                                await self.viewModel.queueButtonTapped()
                                print("✅ queueButtonTapped completed")
                            } catch {
                                print("❌ Payment confirmation error: \(error)")
                            }

                        case .failed(let error):
                            print("❌ Payment failed with error: \(error)")

                        case .canceled:
                            print("🟡 Payment canceled by the user")
                        }

                        self.isPaymentInProgress = false
                        print("🔄 Payment in progress set to false: \(self.isPaymentInProgress)")
                    }
                }
            } else {
                print("❌ Could not find the topmost view controller to present PaymentSheet")
           }
        } catch {
            print("❌ Payment setup error: \(error)")
            isPaymentInProgress = false
            print("🔄 Payment in progress set to false: \(isPaymentInProgress)")
        }
    }
    */
    private var descriptionView: some View {
        Text(viewModel.selectedSpace?.queue.description ?? "")
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .overlay(
                Image(systemName: "quote.bubble.fill")
                    .foregroundStyle(.quaternary)
                    .font(.system(size: 40))
                    .opacity(0.1)
                    .offset(x: -8, y: -8),
                alignment: .topLeading
            )
            .opacity(viewModel.selectedSpace?.queue.description == nil ? 0 : 1)
    }
    
    private var topicInputModal: some View {
        ZStack {
            // Animated background blur
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showTopicModal = false
                    }
                }
            
            // Main modal content
            VStack(spacing: 24) {
                // Enhanced handle and title section
                VStack(spacing: 16) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)
                    
                    // Animated title container
                    HStack(spacing: 16) {
                        // Animated icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#A8E6CF"), Color(hex: "#3B4371")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .symbolEffect(.bounce.byLayer, options: .repeating)
                        }
                        
                        Text("Share Your Voice")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    Text("What topic would you like to discuss?")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Enhanced topic input field
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "number")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Your Topic")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    // Animated input field
                    ZStack(alignment: .leading) {
                        HStack(spacing: 8) {
                            Text("#")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .font(.system(size: 20, weight: .bold))
                                .padding(.leading, 20)
                            
                            TextField("", text: Binding(
                                get: { userTopic.hasPrefix("#") ? String(userTopic.dropFirst()) : userTopic },
                                set: { newValue in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        userTopic = "#" + newValue
                                    }
                                }
                            ))
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .padding(.vertical, 16)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color(hex: "#4ECDC4").opacity(0.2), radius: 10, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#FF6B6B").opacity(isTyping ? 0.8 : 0.3),
                                        Color(hex: "#4ECDC4").opacity(isTyping ? 0.8 : 0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isTyping ? 2 : 1
                            )
                            .animation(.easeInOut(duration: 0.3), value: isTyping)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isTyping = true
                        }
                    }
                }
                .padding(.horizontal)
                
                // Enhanced join button
                Button {
                    if !userTopic.isEmpty {
                        Task {
                            await viewModel.queueButtonTapped(topic: userTopic)
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showTopicModal = false
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Join Queue")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        userTopic.isEmpty ?
                        LinearGradient(colors: [Color.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(
                            colors: [Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(
                        color: Color(hex: "#4ECDC4").opacity(userTopic.isEmpty ? 0 : 0.3),
                        radius: 15,
                        x: 0,
                        y: 5
                    )
                    .scaleEffect(userTopic.isEmpty ? 0.98 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: userTopic.isEmpty)
                }
                .disabled(userTopic.isEmpty)
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .padding(.bottom, 24)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(
                        color: Color(hex: "#4ECDC4").opacity(0.2),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FF6B6B").opacity(0.2),
                                Color(hex: "#4ECDC4").opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .frame(maxWidth: 340)
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                )
            )
        }
    }

    private var userTopicModal: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showUserTopicModal = false
                    }
                }
            
            VStack(spacing: 24) {
                // Handle and Title
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 40, height: 4)
                    
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        
                        Text("Topic")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                
                // Topic Display
                VStack(spacing: 16) {
                    Text((selectedUserTopic?.hasPrefix("#") ?? false) ? selectedUserTopic ?? "" : "#\(selectedUserTopic ?? "")")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 8)
                                
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                                
                                // Background pattern
                                GeometryReader { geometry in
                                    Path { path in
                                        let size = geometry.size
                                        let spacing: CGFloat = 20
                                        for x in stride(from: 0, through: size.width, by: spacing) {
                                            path.move(to: CGPoint(x: x, y: 0))
                                            path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                                        }
                                    }
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.05), .purple.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                                }
                            }
                        )
                }
                
                // Close Button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showUserTopicModal = false
                    }
                } label: {
                    Text("Close")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.secondary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.2), .clear],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                }
                .buttonStyle(ScalesButtonStyle())
            }
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(UIColor.systemBackground))
                    
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .frame(maxWidth: 340)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private var participantGridView: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: gridSpacing) {
            ForEach(viewModel.selectedSpace?.queue.participants.sorted { $0.position < $1.position } ?? []) { participant in
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: participant.isInvited ?
                                        [.green, .blue] : [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 58, height: 58)
                        
                        if let imageUrl = URL(string: participant.image) {
                            AsyncImage(url: imageUrl) { phase in
                                switch phase {
                                case .empty, .failure:
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .padding(4)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .padding(4)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        
                        Text("#\(participant.position)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                            .offset(y: 28)
                    }
                    
                    HStack(spacing: 4) {
                        Text(participant.name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if participant.isInvited {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 14))
                                .symbolEffect(.pulse)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    if let topic = participant.topic {
                        Button {
                            selectedUserTopic = topic
                            withAnimation(.spring()) {
                                showUserTopicModal = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                  Image(systemName: "text.bubble.fill")
                .font(.system(size: 12))
            Text("Topic") // Display the topic name
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1) // Ensure the text doesn't overflow
                .truncationMode(.tail)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .purple.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(ScalesButtonStyle())
                    }
                }
                .padding(12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: participant.isInvited ?
                                        [.green.opacity(0.3), .blue.opacity(0.3)] :
                                        [.blue.opacity(0.2), .purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                )
                .scaleEffect(participant.isInvited ? 1.05 : 1.0)
                .zIndex(participant.isInvited ? 1 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: participant.isInvited)
            }
        }
    }
    
    private var backgroundView: some View {
          LinearGradient(
              gradient: Gradient(colors: [
                  Color(hex: "#F5F5F7"),
                  Color(hex: "#E8E8E8").opacity(0.9),
                  Color(hex: "#F0F0F3")
              ]),
              startPoint: .top,
              endPoint: .bottom
          )
          .ignoresSafeArea()
          .overlay(animatedBackgroundCircles)
      }
    private var animatedBackgroundCircles: some View {
           ZStack {
               ForEach(0..<3) { index in
                   Circle()
                       .fill(
                           LinearGradient(
                               colors: [
                                   Color(hex: "#6C63FF").opacity(0.1),
                                   Color(hex: "#FF6584").opacity(0.08)
                               ],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing
                           )
                       )
                       .frame(width: UIScreen.main.bounds.width * 0.7)
                       .offset(
                           x: CGFloat.random(in: -50...50),
                           y: CGFloat.random(in: -50...50)
                       )
                       .blur(radius: 60)
                       .rotationEffect(.degrees(animateBackground ? 360 : 0))
                       .animation(
                           .linear(duration: Double.random(in: 20...30))
                           .repeatForever(autoreverses: false),
                           value: animateBackground
                       )
               }
           }
       }
    
    private var navigationBarButton: some View {
          Button(action: { dismiss() }) {
              ZStack {
                  Circle()
                      .fill(Color(.systemBackground))
                      .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                      .frame(width: 36, height: 36)
                  
                  Image(systemName: "xmark")
                      .font(.system(size: 14, weight: .semibold))
                      .foregroundStyle(
                          LinearGradient(
                              colors: [.blue, .purple],
                              startPoint: .leading,
                              endPoint: .trailing
                          )
                      )
              }
          }
      }
    // MARK: - Lifecycle Methods
      private func handleOnAppear() {
          withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
              headerOffset = 0
              headerOpacity = 1
              animateBackground = true
          }
          
          if let space = viewModel.selectedSpace {
           /*   Task {
                  await viewModel.listenToQueueUpdates(for: space)
              }*/
          }
          
          if currentUser == nil {
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                  withAnimation(.spring()) {
                      showTopicModal = true
                  }
              }
          }
      }
    private func handleOnDisappear() {
         viewModel.showQueueView = false
        /* Task {
             await viewModel.removeQueueListeners()
         }*/
     }
    
    var body: some View {
        VStack(spacing: 16) {
            // Queue Status Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Queue Position")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if let position = currentUser?.position {
                        Text("#\(position)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                // Topic Badge
                if let topic = currentUser?.topic {
                    HStack(spacing: 6) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 12))
                        Text(topic)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
            .padding()
            
            // Queue List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.selectedSpace?.queue.participants.sorted { $0.position < $1.position } ?? []) { participant in
                        QueueParticipantRow(participant: participant)
                    }
                }
                .padding()
            }
            
            // Leave Queue Button
            if currentUser != nil {
                Button(action: {
                    /*Task {
                        await viewModel.leaveQueue()
                    }*/
                }) {
                    Text("Leave Queue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
    }
}

// New component for queue participant rows
struct QueueParticipantRow: View {
    let participant: QueueUser
    
    var body: some View {
        HStack(spacing: 12) {
            // Position number
            Text("#\(participant.position)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 30)
            
            // Profile image
            AsyncImage(url: URL(string: participant.image)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
            }
            
            // Name and topic
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.name)
                    .font(.system(size: 16, weight: .medium))
                
                if let topic = participant.topic {
                    Text(topic)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Invited indicator
            if participant.isInvited {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
         /*.onAppear(perform: handleOnAppear)
                .onDisappear(perform: handleOnDisappear)*/
    }
}


