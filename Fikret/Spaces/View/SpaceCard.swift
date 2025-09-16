//
//  SpaceCard.swift
//  Spaces
//
//  Created by Stefan Blos on 16.02.23.
//  Copyright © 2023 Stream.io Inc. All rights reserved.
//

import SwiftUI
import PhotosUI
import CryptoKit
import CommonCrypto
//import TwitterCloneUI
// Instead of AsyncImage, use CachedAsyncImage
/*CachedAsyncImage(url: space.previewImageURL) { phase in
    switch phase {
    case .empty:
        ProgressView()
    case .success(let image):
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
    case .failure:
        Image(systemName: "photo.fill")
            .foregroundColor(.gray)
    @unknown default:
        EmptyView()
    }
}*/



// Add this class to handle image caching


// Create a custom AsyncImage replacement
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase = .empty
    @State private var currentURL: URL?
    
    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }
    
    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url = url else {
                    phase = .empty
                    return
                }
                
                // Reset phase when URL changes
                if currentURL != url {
                    print("🔄 [CachedAsyncImage] URL changed from \(currentURL?.absoluteString ?? "nil") to \(url.absoluteString)")
                    phase = .empty
                    currentURL = url
                }
                
                do {
                    print("🔄 [CachedAsyncImage] Loading image for URL: \(url.absoluteString)")
                    
                    // First check cache
                    if let cached = await ImageCacheManager.shared.image(for: url) {
                        print("✅ [CachedAsyncImage] Found cached image for: \(url.absoluteString)")
                        phase = .success(Image(uiImage: cached))
                        return
                    }
                    
                    print("📥 [CachedAsyncImage] No cache found, loading from network: \(url.absoluteString)")
                    
                    // If not in cache, load and cache
                    if let image = try await ImageCacheManager.shared.imageWithRetry(for: url) {
                        print("✅ [CachedAsyncImage] Successfully loaded image for: \(url.absoluteString)")
                        phase = .success(Image(uiImage: image))
                    } else {
                        print("❌ [CachedAsyncImage] Failed to load image for: \(url.absoluteString)")
                        phase = .failure(URLError(.badServerResponse))
                    }
                } catch {
                    if (error as NSError).code != NSURLErrorCancelled {
                        phase = .failure(error)
                    }
                }
            }
    }
}

actor ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        // Set up persistent cache directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure cache limits
        cache.countLimit = 200 // Maximum number of images
        cache.totalCostLimit = 1024 * 1024 * 500 // 500 MB
    }
    
    func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString
        
        // Check memory cache first
        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }
        
        // Check disk cache
        let diskCacheURL = cacheDirectory.appendingPathComponent(key.hash.description)
        if let data = try? Data(contentsOf: diskCacheURL),
           let image = UIImage(data: data) {
            // Move to memory cache
            cache.setObject(image, forKey: key)
            return image
        }
      
        // Download and cache if not found
        return nil //await downloadAndCacheImage(from: url, key: key)
    }
    
    // ✅ ADDED: Clear cache for specific URL (useful for avatar updates)
    func clearCache(for url: URL) {
        let key = url.absoluteString as NSString
        
        // Remove from memory cache
        cache.removeObject(forKey: key)
        
        // Remove from disk cache
        let diskCacheURL = cacheDirectory.appendingPathComponent(key.hash.description)
        try? fileManager.removeItem(at: diskCacheURL)
        
        print("🗑️ Cleared cache for URL: \(url.absoluteString)")
    }
    
  /*  private func downloadAndCacheImage(from url: URL, key: NSString) async -> UIImage? {
        do {
            print("🌐 Starting API request for: \(url.lastPathComponent)")
            // Create a signed request using the same pattern as in SpacesViewModel
            var request = URLRequest(url: url)
            
            // Add AWS S3 authentication headers
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = TimeZone(identifier: "GMT")
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
            let dateString = dateFormatter.string(from: Date())
            
            // Extract the key (filename) from the URL
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let pathComponents = urlComponents?.path.components(separatedBy: "/")
            let fileName = pathComponents?.last ?? ""
            
            let stringToSign = """
            GET
            
            
            \(dateString)
            /\(Config.digitalOcean.bucket)/\(fileName)
            """
            
            let signature = stringToSign.hmac(key: Config.digitalOcean.secretKey)
            
            // Add the same headers used in successful uploads
            request.setValue(dateString, forHTTPHeaderField: "Date")
            request.setValue("AWS \(Config.digitalOcean.accessKey):\(signature)", forHTTPHeaderField: "Authorization")
            
            print("🔐 Making authenticated request to: \(url.absoluteString)")
            print("📝 With headers: \(request.allHTTPHeaderFields ?? [:])")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 API Response [\(httpResponse.statusCode)] for: \(url.lastPathComponent)")
            }
            
            guard let image = UIImage(data: data) else {
                print("❌ Failed to create image from API data: \(url.lastPathComponent)")
                return nil
            }
            
            print("💾 Caching new image: \(url.lastPathComponent)")
            // Save to memory cache
            cache.setObject(image, forKey: key)
            
            // Save to disk cache
            let diskCacheURL = cacheDirectory.appendingPathComponent(key.hash.description)
            try? data.write(to: diskCacheURL)
            
            return image
        } catch {
            print("❌ API request failed for: \(url.lastPathComponent), error: \(error)")
            return nil
        }
    }*/
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func imageWithRetry(for url: URL, retries: Int = 1) async throws -> UIImage? {
        // Fix malformed Backblaze B2 URLs
        let fixedURL = fixBackblazeB2URL(url)
        
        do {
            // Try public access first for Backblaze B2
            var request = URLRequest(url: fixedURL)
            
            if fixedURL.host?.contains("backblazeb2.com") == true {
                print("🔐 [ImageCache] Attempting public access for Backblaze B2")
            } else {
                request = try await self.createSignedRequest(for: fixedURL)
            }
            
            // Create a dedicated URLSession for this request
            let config = URLSessionConfiguration.default
            config.waitsForConnectivity = true
        
            let session = URLSession(configuration: config)
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [ImageCache] HTTP Response [\(httpResponse.statusCode)] for: \(url.lastPathComponent)")
             
                switch httpResponse.statusCode {
                case 200:
                    if let image = UIImage(data: data) {
                        print("✅ [ImageCache] Successfully created image from data: \(url.lastPathComponent)")
                        // Cache the successful result
                        self.cache.setObject(image, forKey: url.absoluteString as NSString)
                        return image
                    } else {
                        print("❌ [ImageCache] Failed to create image from data: \(url.lastPathComponent)")
                    }
                case 403:
                    print("❌ [ImageCache] 403 Forbidden - Authentication failed for: \(url.lastPathComponent)")
                    if let errorText = String(data: data, encoding: .utf8) {
                        print("Error response: \(errorText)")
                    }
                default:
                    print("❌ [ImageCache] HTTP \(httpResponse.statusCode) for: \(url.lastPathComponent)")
                    if let errorText = String(data: data, encoding: .utf8) {
                        print("Error response: \(errorText)")
                    }
                }
            }
            
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                throw error
            }
            throw error
        }
        
        throw URLError(.badServerResponse)
    }
    
    // Fix malformed Backblaze B2 URLs from backend
    private func fixBackblazeB2URL(_ url: URL) -> URL {
        let urlString = url.absoluteString
        
        // Fix double https://
        var fixedString = urlString.replacingOccurrences(of: "https://https://", with: "https://")
        
        // Fix duplicate bucket name in path
        if fixedString.contains("PaoPaoAvatars.s3.us-east-005.backblazeb2.com/PaoPaoAvatars/") {
            fixedString = fixedString.replacingOccurrences(of: "PaoPaoAvatars.s3.us-east-005.backblazeb2.com/PaoPaoAvatars/", with: "PaoPaoAvatars.s3.us-east-005.backblazeb2.com/")
        }
        
        if let fixedURL = URL(string: fixedString) {
            if fixedURL.absoluteString != url.absoluteString {
                print("🔧 [ImageCache] Fixed malformed URL:")
                print("   Original: \(url.absoluteString)")
                print("   Fixed:    \(fixedURL.absoluteString)")
            }
            return fixedURL
        }
        
        return url
    }
    
    // ✅ UPDATED: Create signed request with service detection
    private func createSignedRequest(for url: URL) async throws -> URLRequest {
        var request = URLRequest(url: url)
        
        // Detect which service the URL belongs to
        let host = url.host ?? ""
        
        if host.contains("backblazeb2.com") {
            // For public Backblaze B2 buckets, try unauthenticated first
                    print("🔐 [ImageCache] Backblaze B2 bucket detected, trying public access first")
        
        // Debug: Generate curl command to test public access
        let curlCommand = """
        curl -X GET "\(url.absoluteString)" \\
        -H "User-Agent: Mozilla/5.0" \\
        -v
        """
        print("🧪 [TEST] Curl command to test public access:")
        print(curlCommand)
        
        return request
        } else if host.contains("digitaloceanspaces.com") {
            // DigitalOcean Spaces authentication
            return try await createDigitalOceanRequest(for: url)
        } else {
            // For other URLs, try without authentication
            print("🔐 [ImageCache] Making unauthenticated request to: \(url.absoluteString)")
            return request
        }
    }
    
    // Backblaze B2 authentication
    private func createBackblazeB2Request(for url: URL) async throws -> URLRequest {
        var request = URLRequest(url: url)
        
        // Backblaze B2 credentials
        let accessKey = "005e0240b31845c0000000001"
        let secretKey = "K005qQc2ELLwxsvTA/b2IekNvma7e0I"
        let region = "us-east-005" // Note: corrected region format
        
        // Get current date for AWS4 signature
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dateFormatter.string(from: now)
        
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = dateFormatter.string(from: now)
        
        // AWS4 signature calculation
        let algorithm = "AWS4-HMAC-SHA256"
        let service = "s3"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        
        // Extract path components correctly
        let path = url.path // This gives the full path including bucket name
        let canonicalUri = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        
        let canonicalQueryString = ""
        
        // Host header should include the full domain
        let host = url.host ?? ""
        let canonicalHeaders = "host:\(host)\nx-amz-date:\(amzDate)\n"
        let signedHeaders = "host;x-amz-date"
        
        // For GET requests, payload is SHA256 of empty string
        let payloadHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        
        let canonicalRequest = """
        GET
        \(canonicalUri)
        \(canonicalQueryString)
        \(canonicalHeaders)
        \(signedHeaders)
        \(payloadHash)
        """
        
        print("📝 Canonical Request:\n\(canonicalRequest)")
        
        // String to sign
        let stringToSign = """
        \(algorithm)
        \(amzDate)
        \(credentialScope)
        \(canonicalRequest.sha256())
        """
        
        print("📝 String to Sign:\n\(stringToSign)")
        
        // Calculate signature
        let signature = calculateAWS4Signature(
            secretKey: secretKey,
            dateStamp: dateStamp,
            region: region,
            service: service,
            stringToSign: stringToSign
        )
        
        // Add headers
        let authorizationHeader = "\(algorithm) Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        
        print("🔐 [ImageCache] Backblaze B2 Authorization: \(authorizationHeader)")
        print("🔐 [ImageCache] x-amz-date: \(amzDate)")
        
        return request
    }
    
    // DigitalOcean Spaces authentication
    private func createDigitalOceanRequest(for url: URL) async throws -> URLRequest {
        var request = URLRequest(url: url)
        
        // DigitalOcean Spaces credentials (you'll need to provide these)
        let accessKey = Config.digitalOcean.accessKey
        let secretKey = Config.digitalOcean.secretKey
        let region = "nyc3"
        
        // Get current date for AWS4 signature
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dateFormatter.string(from: now)
        
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = dateFormatter.string(from: now)
        
        // Extract the key (filename) from the URL
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let pathComponents = urlComponents?.path.components(separatedBy: "/")
        let fileName = pathComponents?.last ?? ""
        
        // AWS4 signature calculation
        let algorithm = "AWS4-HMAC-SHA256"
        let service = "s3"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        
        // Canonical request
        let canonicalUri = "/\(fileName)"
        let canonicalQueryString = ""
        let canonicalHeaders = "host:\(url.host ?? "")\nx-amz-date:\(amzDate)\n"
        let signedHeaders = "host;x-amz-date"
        let payloadHash = "UNSIGNED-PAYLOAD"
        
        let canonicalRequest = """
        GET
        \(canonicalUri)
        \(canonicalQueryString)
        \(canonicalHeaders)
        \(signedHeaders)
        \(payloadHash)
        """
        
        // String to sign
        let stringToSign = """
        \(algorithm)
        \(amzDate)
        \(credentialScope)
        \(canonicalRequest.sha256())
        """
        
        // Calculate signature
        let signature = calculateAWS4Signature(
            secretKey: secretKey,
            dateStamp: dateStamp,
            region: region,
            service: service,
            stringToSign: stringToSign
        )
        
        // Add headers
        request.setValue("\(algorithm) Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)", forHTTPHeaderField: "Authorization")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        
        print("🔐 [ImageCache] Making DigitalOcean Spaces AWS4 authenticated request to: \(url.absoluteString)")
        
        return request
    }
    
    // Helper function to calculate AWS4 signature
    private func calculateAWS4Signature(secretKey: String, dateStamp: String, region: String, service: String, stringToSign: String) -> String {
        let kSecret = "AWS4\(secretKey)"
        let kDate = dateStamp.hmac(algorithm: .SHA256, key: kSecret)
        let kRegion = region.hmac(algorithm: .SHA256, key: kDate)
        let kService = service.hmac(algorithm: .SHA256, key: kRegion)
        let kSigning = "aws4_request".hmac(algorithm: .SHA256, key: kService)
        return stringToSign.hmac(algorithm: .SHA256, key: kSigning)
    }
    
}



// Add a StoriesView component
struct StoriesView: View {
    let stories: [Story]
    let zoomLevel: Int?
    @EnvironmentObject var viewModel: SpacesViewModel
    @State private var showStoryViewer = false
    
    private var componentScale: CGFloat {
        zoomLevel != nil ? 1.0 / 3.0 : 1.0
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16 * componentScale) {
                ForEach(stories, id: \.id) { story in
                    StoryBubbleView(
                        story: story,
                        hasStory: !story.storyImageUrl.isEmpty,
                        onTap: {
                            if !story.storyImageUrl.isEmpty,
                               let spaceId = story.id as Int64?,
                               let space = viewModel.spaces.first(where: { $0.id == spaceId }) {
                                viewModel.selectedSpace = space
                                showStoryViewer = true
                            }
                        }, zoomLevel: zoomLevel
                    )
                }
            }
            .padding(.horizontal, 20 * componentScale)
        }
        .frame(height: 110 * componentScale)
       /* .fullScreenCover(isPresented: $showStoryViewer) {
            if let selectedSpace = viewModel.selectedSpace,
               let imageURL = selectedSpace.previewImageURL?.absoluteString {
                StoryViewer(
                    story: Story(
                        id: selectedSpace.id,
                        userImageUrl: selectedSpace.hostImageUrl ?? "",
                        username: selectedSpace.host ?? "",
                        storyImageUrl: imageURL,
                        isViewed: false,
                        timestamp: selectedSpace.updatedAt
                    ),
                    isPresented: $showStoryViewer
                )
            }
        }*/
    }
}

// Story bubble component with animated gradient border
struct StoryBubbleView: View {
    let story: Story
    let hasStory: Bool
    let onTap: () -> Void
    let zoomLevel: Int?
    @State private var animateGradient = false
    
    private var componentScale: CGFloat {
        zoomLevel != nil ? 1.0 / 3.0 : 1.0
    }
    
    var body: some View {
        VStack(spacing: 8 * componentScale) {
            Button(action: onTap) {
                if let url = URL(string: story.userImageUrl) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 70 * componentScale, height: 70 * componentScale)
                                .clipShape(Circle())
                        default:
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 70 * componentScale, height: 70 * componentScale)
                        }
                    }
                    .padding(3 * componentScale)
                    .background(
                        Circle()
                            .stroke(
                                hasStory ?
                                    LinearGradient(
                                        colors: story.isViewed
                                            ? [Color.gray.opacity(0.5)]
                                            : [.purple, .red, .orange],
                                        startPoint: animateGradient ? .topLeading : .bottomTrailing,
                                        endPoint: animateGradient ? .bottomTrailing : .topLeading
                                    )
                                    : LinearGradient(
                                        colors: [Color.gray.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                lineWidth: hasStory ? 2 * componentScale : 1 * componentScale
                            )
                    )
                }
            }
            .disabled(!hasStory)
            
            Text(story.username)
                .font(.system(size: 12 * componentScale, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: 80 * componentScale)
        }
        .onAppear {
            if hasStory {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
        }
    }
}

// Full-screen story viewer
struct StoryViewer: View {
    let story: Story
    @Binding var isPresented: Bool
    @State private var progress: CGFloat = 0
    @State private var isLoading = true
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        ZStack {
            // Fixed black background
            Color.black
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                // Story content (full screen)
                if let url = URL(string: story.storyImageUrl) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        case .failure:
                            VStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                Text("Failed to load image")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Overlay elements with gradient for better visibility
                VStack {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                    .overlay {
                        HStack(spacing: 12) {
                            // Progress circle with user image
                            ZStack {
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 36, height: 36)
                                
                                // User image
                                if let url = URL(string: story.userImageUrl) {
                                    CachedAsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                        default:
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 32, height: 32)
                                        }
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(story.username)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("2h")  // Calculate from story.timestamp
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            // Close button
                            Button {
                                withAnimation(.spring()) {
                                    isPresented = false
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                }
            }
            .offset(y: dragOffset.height)
            .opacity(1.0 - abs(dragOffset.height)*0.0033) // Add opacity animation during drag
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    dragOffset = gesture.translation
                }
                .onEnded { gesture in
                    if abs(gesture.translation.height) > 100 {
                        withAnimation(.interactiveSpring()) { // Use interactive spring for smoother dismissal
                            isPresented = false
                        }
                    } else {
                        withAnimation {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            isPresented = false
        }
        .onAppear {
            dragOffset = .zero // Reset drag offset on appear
            withAnimation(.linear(duration: 5)) {
                progress = 1
            }
        }
    }
}

struct SpaceCard: View {
    
    @Environment(\.colorScheme) var colorScheme
    @State private var showBlockedModal = false
    @State private var showHostActiveModal = false
    @State private var isHovered = false
    @State private var animateGradient = false
    @State private var showParticipants = false
    @State private var animateRestriction = false
    @State private var showHostInfo = false
    @State private var pulseEffect: CGFloat = 1.0
    var space: Space
    var zoomLevel: Int?
    @EnvironmentObject var viewModel: SpacesViewModel
    @EnvironmentObject var  tweetData: TweetData
    @State private var showConversations = false
    
    private var scaleFactor: CGFloat {
        guard let zoomLevel = zoomLevel else { return 1.0 }
        
        switch zoomLevel {
        case ...5: return 1.0 / 2.4
        case 6...8: return 1.0 / 2.0
        case 9...11: return 1.0 / 1.8
        case 12...13: return 1.0 / 1.6
        case 14: return 1.0 / 1.4
        case 15: return 1.0 / 1.2
        case 16...: return 1.0
        default: return 1.0 / 2.4
        }
    }

    private var markerScale: CGFloat {
        guard let zoomLevel = zoomLevel else { return 1.0 }
        
        switch zoomLevel {
        case ...13: return 1.0
        case 14: return 1.7
        case 15: return 2.4
        case 16...: return 3.1
        default: return 1.0
        }
    }

    private var elementScale: CGFloat {
        guard let zoomLevel = zoomLevel else { return 1.0 }
        
        switch zoomLevel {
        case ...3: return 0.4
        case 4...6: return 0.5
        case 7...9: return 0.6
        case 10...12: return 0.7
        case 13...15: return 0.8
        case 16...18: return 0.9
        default: return 1.0
        }
    }

    private var baseSize: CGFloat { 280 * componentScale }
    private var storiesSize: CGFloat { 110 * componentScale }
    
    private var titleFontSize: CGFloat {
        14 * componentScale
    }

    private var countFontSize: CGFloat {
        16 * componentScale
    }
    
    private var gradientColors: [Color] {
      
            return [.blue, .purple, .blue.opacity(0.8)]
       
    }
    
    private var isHostOfActiveSpace: Bool {
        guard let currentUserId = tweetData.user?.id else { return false }
        return viewModel.spaces.contains { space in
       
            space.hostId == currentUserId
        }
    }
     var componentScale: CGFloat {
        zoomLevel != nil ? 1.0 / 3.0 : 1.0
    }
    
     var lockOverlay: some View {
     
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .clipShape(RoundedRectangle(cornerRadius: 24 * scaleFactor))
            
            if showHostInfo {
                // Content
                VStack(spacing: 16 * componentScale) {
                    // Live Host Indicator
                    HStack(spacing: 12 * componentScale) {
                        // Animated live dot
                        ZStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 8 * componentScale, height: 8 * componentScale)
                            
                            Circle()
                                .stroke(.red.opacity(0.5), lineWidth: 1 * componentScale)
                                .frame(width: 16 * componentScale, height: 16 * componentScale)
                                .scaleEffect(pulseEffect)
                        }
                        
                        Text("Currently Hosting")
                            .font(.system(size: 14 * componentScale, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16 * componentScale)
                    .padding(.vertical, 8 * componentScale)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Lock icon with gradient
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red.opacity(0.2), .orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50 * componentScale, height: 50 * componentScale)
                        
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 24 * componentScale))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    // Message
                    Text("End your active space to join others")
                        .font(.system(size: 12 * componentScale, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16 * componentScale)
                }
                .padding(16 * componentScale)
                .background(
                    RoundedRectangle(cornerRadius: 20 * scaleFactor)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
            } else {
                // Static lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 24 * componentScale))
                    .foregroundColor(.white)
                    .opacity(0.8)
                    .scaleEffect(animateRestriction ? 1.1 : 1.0)
            }
        }
        .transition(.opacity)
    }
    
    // Add this to cache the story
    private var story: Story? {
        // Always create a story object, even if there's no preview image
        Story(
            id: space.id,
            userImageUrl: space.hostImageUrl ?? "",
            username: space.host ?? "",
            storyImageUrl:  "",
            isViewed: false,
            timestamp: space.updatedAt
        )
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Stories section at the top
                // REMOVED: if let story = story {
                //     StoriesView(stories: [story], zoomLevel: zoomLevel)
                //         .environmentObject(viewModel)
                //         .frame(height: storiesSize)
                //         .padding(.vertical, 5 * componentScale) // Reduced padding
                // }
                
                // Main content area
                Button {
                 /*   if let selectedSpace = viewModel.selectedSpace, selectedSpace.isBlockedFromSpace == true {
                        showBlockedModal = true
                    } else if isHostOfActiveSpace && space.hostId.uuidString != supabase.auth.currentUser?.id.uuidString {
                        withAnimation(.spring()) {
                            showHostActiveModal = true
                        }
                    } else {
                        withAnimation(.spring()) {
                            viewModel.spaceCardTapped(space: space)
                        }
                    }*/
                } label: {
                    HStack(spacing: 8 * componentScale) { // Reduced spacing
                        // Group live indicators and title
                        HStack(spacing: 4 * componentScale) { // Tighter spacing
                         
                                // Live dot
                                ZStack {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8 * componentScale, height: 8 * componentScale)
                                    
                                    Circle()
                                        .stroke(.red.opacity(0.5), lineWidth: 1 * componentScale)
                                        .frame(width: 12 * componentScale, height: 12 * componentScale)
                                }
                                
                              /*  SoundIndicatorView(zoomLevel: zoomLevel)
                                    .scaleEffect(0.25 * componentScale)
                                    .frame(width: 30 * componentScale, height: 30 * componentScale)*/
                            
                            
                           
                        }
                        
                        Spacer()
                        
                        // Group action buttons together
                        HStack(spacing: 6 * componentScale) {
                            Button {
                                withAnimation(.spring()) {
                                    showConversations.toggle()
                                }
                            } label: {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 14 * componentScale))
                                    .foregroundColor(.white)
                                    .padding(6 * componentScale)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                            
                      
                        }
                    }
                    .padding(.horizontal, 12 * componentScale)
                    .padding(.vertical, 12 * componentScale)
                }
            }
            .frame(width: baseSize * 0.8) // Reduced width
            .background(
                ZStack {
                    // Gradient background
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: animateGradient ? .topLeading : .bottomTrailing,
                        endPoint: animateGradient ? .bottomTrailing : .topLeading
                    )
                    
                    // Pattern overlay
                    GeometryReader { geometry in
                        Path { path in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            let spacing: CGFloat = 15 * componentScale // Reduced pattern spacing
                            
                            for x in stride(from: 0, through: width, by: spacing) {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x + height, y: height))
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.1), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5 * componentScale
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16 * componentScale))
            
            // Conversations view overlay
            if showConversations {
                SpaceConversationView(
                    space: space,
                    isPresented: $showConversations,
                    zoomLevel: zoomLevel
                )
                .transition(.move(edge: .trailing))
            }
        }
        .buttonStyle(SpaceCardButtonStyle())
        .overlay(
            Group {
                if isHostOfActiveSpace && space.hostId != tweetData.user?.id {
                    lockOverlay
                }
            }
        )
        // Event handlers
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
                if isHostOfActiveSpace && space.hostId != tweetData.user?.id {
                    animateRestriction.toggle()
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.3)) {
                isHovered = hovering
                if isHostOfActiveSpace && space.hostId != tweetData.user?.id {
                    showHostInfo = hovering
                }
            }
        }
        // Modals
        .fullScreenCover(isPresented: $showBlockedModal) {
            BlockedUserModal(isPresented: $showBlockedModal)
        }
        .fullScreenCover(isPresented: $showHostActiveModal) {
            HostActiveSpaceModal(isPresented: $showHostActiveModal)
        }
    }
}

struct SpaceCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
struct Story: Identifiable {
    let id: Int64
    let userImageUrl: String
    let username: String
    let storyImageUrl: String
    let timestamp: Date
    let isViewed: Bool
    
    init(id:Int64,
         userImageUrl: String,
         username: String,
     storyImageUrl: String,
         isViewed: Bool = false,
         timestamp: Date) {
        self.id = id
        self.userImageUrl = userImageUrl
        self.username = username
        self.storyImageUrl = storyImageUrl
        self.timestamp = timestamp
        self.isViewed = isViewed
        
       
    }
}


struct BlockedUserModal: View {
    @Binding var isPresented: Bool
    @State private var animateGradient = false
    @State private var showContent = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color(hex: "#FF6B6B"),
                    Color(hex: "#4ECDC4"),
                    Color(hex: "#45B7D1")
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .opacity(0.3)
            
            // Glassmorphism card
            VStack {
                Spacer()
                
                VStack(spacing: 25) {
                    // Animated icon
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .scaleEffect(animateGradient ? 1.2 : 1.0)
                        
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 90, height: 90)
                            .scaleEffect(animateGradient ? 1.1 : 0.9)
                        
                        Image(systemName: "hand.raised.slash.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(.red)
                            .rotationEffect(.degrees(showContent ? 360 : 0))
                    }
                    
                    VStack(spacing: 15) {
                        Text("Access Restricted")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("You are temporarily blocked from accessing this space. Please try again in the next session.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                            .padding(.horizontal)
                        
                        // Additional info with icon
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            Text("Block Duration: Current Session")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        )
                    }
                    
                    // Dismiss button
                    Button(action: {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }) {
                        Text("I Understand")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF8E8E")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color(hex: "#FF6B6B").opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 10)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.8))
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Material.ultraThinMaterial)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .offset(y: showContent ? 0 : UIScreen.main.bounds.height)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
}

struct HostActiveSpaceModal: View {
    @Binding var isPresented: Bool
    @State private var animateGradient = false
    @State private var showContent = false
    @State private var pulseEffect: CGFloat = 1.0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color(hex: "#FF6B6B").opacity(0.8),
                    Color(hex: "#4ECDC4").opacity(0.6),
                    Color(hex: "#45B7D1").opacity(0.4)
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .opacity(0.2)
            
            // Content
            VStack {
                Spacer()
                
                VStack(spacing: 25) {
                    // Animated icon
                    ZStack {
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.red.opacity(0.7), .orange.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 120 - CGFloat(i * 20), height: 120 - CGFloat(i * 20))
                                .scaleEffect(pulseEffect)
                                .opacity(1 - Double(i) * 0.2)
                        }
                        
                        Image(systemName: "mic.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .rotationEffect(.degrees(showContent ? 360 : 0))
                    }
                    
                    VStack(spacing: 15) {
                        Text("Active Host Session")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("You're currently hosting a space.\nEnd your session to join other spaces.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                            .padding(.horizontal)
                        
                        // Status indicator
                        HStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(pulseEffect)
                            Text("Live Now")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05))
                        )
                    }
                    
                    // Return button
                    Button {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    } label: {
                        Text("Return to My Space")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
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
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 10)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.8))
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Material.ultraThinMaterial)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .offset(y: showContent ? 0 : UIScreen.main.bounds.height)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
                pulseEffect = 1.2
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
}
// Add Live Photo support to OptimizedAsyncImage
struct OptimizedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase = .empty
    
    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }
    
    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url = url else {
                    phase = .empty
                    return
                }
                
                // First check cache
                if let cached = await ImageCacheManager.shared.image(for: url) {
                    phase = .success(Image(uiImage: cached))
                    return
                }
                
                // If not in cache, load and cache is handled automatically by image(for:)
                if let image = await ImageCacheManager.shared.image(for: url) {
                    phase = .success(Image(uiImage: image))
                } else {
                    phase = .failure(URLError(.badServerResponse))
                }
            }
    }
}

// For Live Photos, let's create a separate component
struct LivePhotoViews: View {
    let url: URL
    @State private var livePhoto: PHLivePhoto?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let photo = livePhoto {
                LivePhotoRepresentable(livePhoto: photo)
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "photo.fill")
                    .foregroundColor(.gray)
            }
        }
        .task {
            await loadLivePhoto()
        }
    }
    
    private func loadLivePhoto() async {
        isLoading = true
        defer { isLoading = false }
        
        let targetSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        if let photo = await LivePhotoCacheManager.shared.getLivePhoto(for: url, targetSize: targetSize) {
            self.livePhoto = photo
        }
    }
}

// LivePhotoRepresentable to bridge UIKit and SwiftUI
struct LivePhotoRepresentable: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    
    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.livePhoto = livePhoto
        return view
    }
    
    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
    }
}

// Update StoriesContent to use the same presigned URL format
struct StoriesContent: View {
    @Binding var currentStory: Story
    let geometry: GeometryProxy
    
    private func getPresignedUrl(_ originalUrl: String) -> URL? {
        guard let url = URL(string: originalUrl) else { return nil }
        
        // Extract the filename from the URL
        let fileName = url.lastPathComponent
        
        // Current timestamp for the request
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        let dateString = dateFormatter.string(from: Date())
        
        /*
        let stringToSign = """
        GET
        
        
        \(dateString)
        /\(Config.digitalOcean.bucket)/\(fileName)
        """
        
        let signature = stringToSign.hmac(key: Config.digitalOcean.secretKey)
        
        // Construct the URL with authentication parameters
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "AWSAccessKeyId", value: Config.digitalOcean.accessKey),
            URLQueryItem(name: "Signature", value: signature),
            URLQueryItem(name: "Date", value: dateString)
        ]*/
        
    //    print("🔗 Accessing image with URL: \(components.url?.absoluteString ?? "")")
        return nil // components.url
    }
    
    var body: some View {
        if let presignedUrl = getPresignedUrl(currentStory.storyImageUrl) {
            CachedAsyncImage(url: presignedUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .id(presignedUrl) // Add id to prevent unnecessary redraws
                case .failure(let error):
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                        Text("Failed to load image: \(error.localizedDescription)")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                case .empty:
                    ProgressView()
                        .tint(.white)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            VStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                Text("Invalid URL")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.7))
        }
    }
}

// Update Story model to include Live Photo support


actor LivePhotoCacheManager {
    static let shared = LivePhotoCacheManager()
    
    private let cache = NSCache<NSString, PHLivePhoto>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("LivePhotoCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        cache.countLimit = 50 // Fewer items since Live Photos are larger
        cache.totalCostLimit = 1024 * 1024 * 1000 // 1 GB
    }
    
    func getLivePhoto(for url: URL, targetSize: CGSize) async -> PHLivePhoto? {
        let key = url.absoluteString as NSString
        
        // Check memory cache first
        if let cachedPhoto = cache.object(forKey: key) {
            return cachedPhoto
        }
        
        // Load and cache if not found
        return await loadAndCacheLivePhoto(from: url, key: key, targetSize: targetSize)
    }
    
    private func loadAndCacheLivePhoto(from url: URL, key: NSString, targetSize: CGSize) async -> PHLivePhoto? {
        do {
            let livePhoto = try await withCheckedThrowingContinuation { continuation in
                PHLivePhoto.request(
                    withResourceFileURLs: [url],
                    placeholderImage: nil,
                    targetSize: targetSize,
                    contentMode: .aspectFit
                ) { livePhoto, info in
                    if let livePhoto = livePhoto {
                        continuation.resume(returning: livePhoto)
                    } else {
                        continuation.resume(throwing: NSError(domain: "", code: -1))
                    }
                }
            }
            
            // Save to memory cache
            cache.setObject(livePhoto, forKey: key)
            return livePhoto
            
        } catch {
            print("Failed to load Live Photo: \(error)")
            return nil
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

extension String {
    func hmac(key: String) -> String {
        guard let keyData = key.data(using: .utf8),
              let messageData = self.data(using: .utf8) else { return "" }
        
        let sha1 = HMAC<Insecure.SHA1>.authenticationCode(
            for: messageData,
            using: SymmetricKey(data: keyData)
        )
        return Data(sha1).base64EncodedString()
    }
    
    func sha256() -> String {
        let data = Data(self.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    func hmac(algorithm: CryptoAlgorithm, key: String) -> String {
        var digest = [UInt8](repeating: 0, count: algorithm.digestLength)
        CCHmac(algorithm.HMACAlgorithm, key, key.count, self, self.count, &digest)
        return Data(digest).map { String(format: "%02x", $0) }.joined()
    }
}

enum CryptoAlgorithm {
    case SHA256
    
    var HMACAlgorithm: CCHmacAlgorithm {
        switch self {
        case .SHA256: return CCHmacAlgorithm(kCCHmacAlgSHA256)
        }
    }
    
    var digestLength: Int {
        switch self {
        case .SHA256: return Int(CC_SHA256_DIGEST_LENGTH)
        }
    }
}

struct AudioWaveform: View {
    @State private var animate = false
    let isPlaying: Bool
    let bars: Int = 20 // More bars for a fuller effect
    let zoomLevel: Int?
    
    private var componentScale: CGFloat {
        zoomLevel != nil ? 1.0 / 3.0 : 1.0
    }
    
    var body: some View {
        HStack(spacing: 2 * componentScale) {
            ForEach(0..<bars, id: \.self) { index in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .blue.opacity(0.8),
                                .purple.opacity(0.6)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 2 * componentScale, height: isPlaying ? CGFloat.random(in: 8...30) * componentScale : 10 * componentScale)
                    .scaleEffect(y: isPlaying && animate ? CGFloat.random(in: 0.5...1.5) : 1, anchor: .bottom)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.05),
                        value: animate
                    )
            }
        }
        .onChange(of: isPlaying) { newValue in
            if newValue {
                animate = true
            } else {
                animate = false
            }
        }
    }
}

struct SpaceConversationView: View {
    let space: Space
    @Binding var isPresented: Bool
    @EnvironmentObject var conversationManager: ConversationCacheManager
    @State private var dragOffset: CGFloat = 0
    let zoomLevel: Int?
    
    private var componentScale: CGFloat {
        zoomLevel != nil ? 1.0 / 3.0 : 1.0
    }
    
    var body: some View {
        GeometryReader { geometry in
            // Single semi-transparent background layer that covers the SpaceCard
            ZStack {
                // Background with blur effect
                Rectangle()
                    .fill(Material.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.2))
                
                // Content
                VStack(spacing: 0) {
                    // Header
                    // Header
                    HStack(alignment: .center) {
                        // Title with gradient and shadow
                        Text("Conversations")
                            .font(.system(size: 24 * componentScale, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                        
                        Spacer()
                        
                        // Close button with improved styling
                        Button {
                            withAnimation(.spring()) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24 * componentScale, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white.opacity(0.8), .white.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 20 * componentScale)
                    .padding(.vertical, 16 * componentScale)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Conversations content
                    if conversationManager.isLoadingConversations {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    } else if conversationManager.currentConversations.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40 * componentScale))
                                .foregroundColor(.white.opacity(0.7))
                            Text("No conversations yet")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                
                                let count = conversationManager.currentConversations.count
                                 
                                
                                ForEach(conversationManager.currentConversations, id: \.id) { conversation in
                
                                    ConversationItem(conversation: conversation, zoomLevel: zoomLevel)

                                }
                            }
                            .padding()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width > 0 {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        let threshold = geometry.size.width * 0.3
                        if value.translation.width > threshold {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .onAppear {
            // Start from off-screen and animate in
            dragOffset = UIScreen.main.bounds.width
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                dragOffset = 0
            }
            // Load conversations
            conversationManager.loadConversations(for: Int64(space.hostId))
        }
        .onDisappear {
            // Reset position for next appearance
            dragOffset = UIScreen.main.bounds.width
        }
    }
}
struct ConversationItem: View {
    let conversation: AudioConversation
    @EnvironmentObject var conversationManager: ConversationCacheManager
    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var progress: Double = 0
    @State private var isPlaying = false
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
   @GestureState private var dragLocation: CGFloat = 0
@State private var showControls = false // Replace showSeekBar with this

    @State private var isHovered = false
    let zoomLevel: Int?
    
    // Animation states
    @State private var pulseEffect: CGFloat = 1.0
    @State private var showPlayIcon = false
    
    private var componentScale: CGFloat {
        zoomLevel != nil ? 1.0 / 3.0 : 1.0
    }
    
    private func togglePlayback() {
      
        withAnimation(.spring(response: 0.3)) {
            if isPlaying {
                
                audioPlayer.pause()
                isPlaying = false
            } else {
                if progress >= 0.99 {
                   
                    handleSeek(progress: 0)
                    audioPlayer.play()
                } else {
                   
                    audioPlayer.play()
                }
                isPlaying = true
            }
            
            showPlayIcon = true
           
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    self.showPlayIcon = false
                    
                }
            }
        }
    }
    
    private func handleSeek(progress: Double) {
        self.progress = progress
        audioPlayer.seek(to: progress)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content container
            HStack(spacing: 16 * componentScale) {
                // User Profile Stack
                HStack(spacing: 8 * componentScale) {
                    ZStack {
                        // Host Image with gradient border
                        CachedAsyncImage(url: URL(string: conversation.host_image ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44 * componentScale, height: 44 * componentScale)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.purple, .blue],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2 * componentScale
                                            )
                                    )
                            case .failure, .empty:
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 44 * componentScale, height: 44 * componentScale)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                        
                        // User Image overlapping
                        CachedAsyncImage(url: URL(string: conversation.user_image ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44 * componentScale, height: 44 * componentScale)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black.opacity(0.1), lineWidth: 2 * componentScale)
                                    )
                                    .offset(x: 20 * componentScale)
                            case .failure, .empty:
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 44 * componentScale, height: 44 * componentScale)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    )
                                    .offset(x: 20 * componentScale)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    .frame(width: 64 * componentScale) // Account for overlap
                    
                    // User Info
                    VStack(alignment: .leading, spacing: 2 * componentScale) {
                        HStack(spacing: 4 * componentScale) {
                            Text(conversation.user_name ?? "Guest")
                                .font(.system(size: 15 * componentScale, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.system(size: 12 * componentScale))
                        }
                        
                        if !conversation.topic.isEmpty {
                                                Text(conversation.topic)
                                                    .font(.system(size: 13 * componentScale, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.7))
                                                    .lineLimit(1)
                                            }
                        
                       /* Text(conversation.created_at.timeAgoDisplay())
                            .font(.system(size: 12 * componentScale, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))*/
                    }
                }
                
                Spacer()
                
                // Duration display
                Text(formatTime(audioPlayer.duration))
                    .font(.system(size: 12 * componentScale, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8 * componentScale)
                    .padding(.vertical, 4 * componentScale)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16 * componentScale)
            .padding(.vertical, 12 * componentScale)
            
            // Interactive Audio Area
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                    
                    // Audio visualization bars (update the existing one)
                    HStack(spacing: 2 * componentScale) {
                        ForEach(0..<30) { index in
                            RoundedRectangle(cornerRadius: 1 * componentScale)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(isPlaying ? 0.7 : 0.3),
                                            .white.opacity(isPlaying ? 0.4 : 0.1)
                                        ],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: 2 * componentScale, height: isPlaying ? CGFloat.random(in: 15...45) * componentScale : 20 * componentScale)
                                .animation(
                                    .easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.05),
                                    value: isPlaying
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    
                    // Update the gesture handling
                    .gesture(
                        DragGesture(minimumDistance: 2 * componentScale)
                            .updating($dragLocation) { value, state, _ in
                                state = value.location.x
                            }
                            .onChanged { value in
                                let newProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                                withAnimation(.interactiveSpring()) {
                                    isDragging = true
                                    dragProgress = newProgress
                                    showControls = true
                                }
                            }
                            .onEnded { value in
                                let newProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                                withAnimation(.easeOut) {
                                    isDragging = false
                                    handleSeek(progress: newProgress)
                                    
                                    // Hide controls after delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        if !isDragging {
                                            showControls = false
                                        }
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                togglePlayback()
                                showControls = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if !isDragging {
                                        showControls = false
                                    }
                                }
                            }
                    )

                    // Update the progress indicator
                    if showControls || isDragging {
                        // Progress bar
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 2 * componentScale)
                            .overlay(
                                Rectangle()
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: geometry.size.width * CGFloat(isDragging ? dragProgress : progress))
                                    .frame(height: 2 * componentScale),
                                alignment: .leading
                            )
                            .overlay(
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 12 * componentScale, height: 12 * componentScale)
                                    .offset(x: geometry.size.width * CGFloat(isDragging ? dragProgress : progress) - 6 * componentScale),
                                alignment: .leading
                            )
                            .position(x: geometry.size.width / 2, y: geometry.size.height - 16 * componentScale)
                    }

                    // Update play/pause indicator
                    if showPlayIcon {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 50 * componentScale, weight: .light))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            .frame(height: 60 * componentScale)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16 * componentScale))
        .overlay(
            RoundedRectangle(cornerRadius: 16 * componentScale)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1 * componentScale
                )
        )
        .onAppear {
             setupAudioPlayer()
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
    
    private func setupAudioPlayer()  {
     
      /*  guard let audioUrl = conversation.audio_url else {
            print("❌ No audio URL found in conversation")
            return
        }*/
     
      
         /*   let sourceUrl =  AudioPlaybackManager.getAudioSource(for: conversation)
            print("✅ Got source URL: \(sourceUrl)")*/
            
           
            
                // Pass the known duration from the conversation
            /*   audioPlayer.prepareToPlay(url: sourceUrl, initialDuration: conversation.audioDurationInSeconds)
                */
                audioPlayer.onProgressUpdate = { currentProgress in
                  
                    withAnimation {
                        self.progress = currentProgress
                    }
                }
                
                audioPlayer.onPlaybackFinished = {
                  
                    withAnimation {
                        self.isPlaying = false
                        self.progress = 0
                    }
                }
                
                audioPlayer.onError = { error in
                   
                    self.isPlaying = false
                }
                
               
            }
       
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Helper extension for time ago display
extension Date {
    func timeAgoDisplaySpaceCard() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// AudioWaveformView component
struct AudioWaveformView: View {
    let samples: [CGFloat]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<samples.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 3, height: geometry.size.height * samples[index])
                }
            }
        }
    }
}

// Simple audio player manager
class AudioPlayerManager: ObservableObject {
    private var player: AVPlayer?
    var onProgressUpdate: ((Double) -> Void)?
    var onPlaybackFinished: (() -> Void)?
    var onError: ((Error) -> Void)?
    private var timeObserver: Any?
    @Published var duration: Double = 0.0
    @Published var currentTime: Double = 0.0
    private var isPreparingToPlay = false
    private var wasPlaying = false
    
    private var fadeTimer: Timer?
    private let fadeOutDuration: TimeInterval = 4.0 // 6 seconds fade
    
    // Add volume control property
    private var playerVolume: Float = 1.0 {
        didSet {
            player?.volume = playerVolume
        }
    }
    
    func prepareToPlay(url: URL, initialDuration: Double? = nil) {
       
        // Remove existing player and observer
        removeTimeObserver()
        player = nil
        
        // If we have an initial duration, set it
        if let initialDuration = initialDuration {
            self.duration = initialDuration
            print("✅ Using provided duration: \(initialDuration) seconds")
        }
        
        // Create new player
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Add observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailedToPlay),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Get duration if not provided
        if initialDuration == nil {
            Task {
                do {
                    let duration = try await playerItem.asset.load(.duration).seconds
                    await MainActor.run {
                        self.duration = duration
                        print("✅ Loaded duration: \(duration) seconds")
                    }
                } catch {
                    print("❌ Failed to get duration: \(error)")
                    onError?(error)
                }
            }
        }
        
        setupTimeObserver()
       
        
        playerVolume = 1.0 // Reset volume to full
        player?.volume = playerVolume
    }
    
    func play() {
        print("▶️ Playing audio")
        guard let player = player else {
            print("❌ Player not initialized")
            return
        }
        player.play()
    }
    
    func pause() {
        print("⏸️ Pausing audio")
        player?.pause()
    }
    
    func stop() {
        print("⏹️ Stopping audio")
        player?.pause()
        player?.seek(to: .zero)
        playerVolume = 1.0 // Reset volume
        removeTimeObserver()
    }
    
    func seek(to progress: Double) {
        print("⏩ Seeking to progress: \(progress)")
        guard let player = player else { return }
        
        // Store current playing state
        wasPlaying = (player.timeControlStatus == .playing)
        if wasPlaying {
            player.pause()
        }
        
        let targetTime = progress * duration
        let cmTime = CMTime(seconds: targetTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        // Use seekToTime with completion handler
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self = self, finished else { return }
            
            // Update current time
            self.currentTime = targetTime
            
            // Resume playback if it was playing
            if self.wasPlaying {
                self.player?.play()
            }
            
            // Update progress
            if self.duration > 0 {
                self.onProgressUpdate?(self.currentTime / self.duration)
            }
        }
    }
    
    @objc private func playerItemDidReachEnd() {
        print("✅ Playback finished")
        DispatchQueue.main.async {
            self.onPlaybackFinished?()
        }
    }
    
    @objc private func playerItemFailedToPlay(_ notification: Foundation.Notification) {
        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
            print("❌ Player item failed: \(error)")
            DispatchQueue.main.async {
                self.onError?(error)
            }
        }
    }
    
    private func setupTimeObserver() {
        print("⏱️ Setting up time observer")
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            
            // Check if we're approaching the end
            let timeRemaining = self.duration - self.currentTime
            
            // Start fade when 6 seconds remaining
            if timeRemaining <= self.fadeOutDuration {
                self.startFadeOut(timeRemaining: timeRemaining)
            }
            
            if self.duration > 0 {
                self.onProgressUpdate?(self.currentTime / self.duration)
            }
        }
    }
    
    private func startFadeOut(timeRemaining: Double) {
        // Calculate fade percentage (1.0 -> 0.0)
        let fadePercentage = Float(timeRemaining / fadeOutDuration)
        
        // Apply volume fade
        playerVolume = max(0.0, min(1.0, fadePercentage))
        print("🔊 Fading volume: \(playerVolume)")
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        removeTimeObserver()
    }
}

// Shimmering effect modifier
struct ShimmeringView: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.5),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: phase
                    )
                }
            )
            .onAppear {
                phase = 1
            }
            .clipped()
    }
}

// Extension to make the modifier easier to use
extension View {
    func shimmering() -> some View {
        modifier(ShimmeringView())
    }
}

// Add this property to parse duration properly
extension AudioConversation {
    var audioDurationInSeconds: Double {
        // Handle both string and numeric duration values
        if let durationString = duration as? String {
            return Double(durationString) ?? 0.0
        } else if let durationNumber = duration as? Double {
            return durationNumber
        } else if let durationInt = duration as? Int {
            return Double(durationInt)
        } else if let durationInt64 = duration as? Int64 {
            return Double(durationInt64)
        }
        return 0.0
    }
}



