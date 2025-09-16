import SwiftUI
/*
struct TopicDetailView: View {
    let topic: String
    let userName: String
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var animateGradient = false
    @State private var showContent = false
    
    // Sample data for the view
    let relatedTopics = ["Machine Learning", "Data Science", "Neural Networks", "Deep Learning", "Computer Vision"]
    let posts = [
        Post(title: "Introduction to AI", likes: 1234, comments: 89, date: "2 days ago"),
        Post(title: "Future of Technology", likes: 2341, comments: 156, date: "4 days ago"),
        Post(title: "Machine Learning Basics", likes: 876, comments: 45, date: "1 week ago")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section with animated gradient
                    headerSection
                    
                    // Stats Section
                    statsSection
                        .offset(y: -30)
                    
                    // Content Tabs
                    tabSection
                    
                    // Content based on selected tab
                    tabContent
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8)) {
                    showContent = true
                }
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
        }
    }
    
    private var headerSection: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [.blue, .purple, .blue],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .opacity(0.8)
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Topic Icon
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)
                        .shadow(color: .white.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: topicIcon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .symbolEffect(.bounce)
                }
                .offset(y: showContent ? 0 : -50)
                .opacity(showContent ? 1 : 0)
                
                // Topic Title and Author
                VStack(spacing: 8) {
                    Text(topic)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(.white)
                    
                    Text("Created by \(userName)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                .offset(y: showContent ? 0 : 30)
                .opacity(showContent ? 1 : 0)
            }
            .padding(.vertical, 40)
        }
        .frame(height: 280)
    }
    
    private var statsSection: some View {
        HStack(spacing: 20) {
            ForEach(stats, id: \.title) { stat in
                StatCard(stat: stat)
                    .offset(y: showContent ? 0 : 50)
                    .opacity(showContent ? 1 : 0)
            }
        }
        .padding(.horizontal)
    }
    
    private var tabSection: some View {
        HStack {
            ForEach(0..<3) { index in
                Button(action: { withAnimation { selectedTab = index } }) {
                    VStack(spacing: 8) {
                        Text(tabTitles[index])
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == index ? .primary : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == index ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
    
    private var tabContent: some View {
        VStack(spacing: 16) {
            switch selectedTab {
            case 0:
                aboutSection
            case 1:
                relatedTopicsSection
            case 2:
                postsSection
            default:
                EmptyView()
            }
        }
        .padding()
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            userInfoCard(
                title: "Description",
                subtitle: "An in-depth exploration of \(topic)",
                detail: "Covering fundamental concepts and advanced applications.",
                icon: "text.justify"
            )
            
            userInfoCard(
                title: "Description",
                subtitle: "An in-depth exploration of \(topic)",
                detail: "Covering fundamental concepts and advanced applications.",
                icon: "text.justify"
            )
        }
    }
    
    private var relatedTopicsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(relatedTopics, id: \.self) { topic in
                TopicCard(topic: topic)
            }
        }
    }
    
    private var postsSection: some View {
        VStack(spacing: 16) {
            ForEach(posts) { post in
                PostCard(post: post)
            }
        }
    }
    
    // Helper computed properties
    private var topicIcon: String {
        switch topic.lowercased() {
        case let t where t.contains("ai"): return "cpu.fill"
        case let t where t.contains("design"): return "paintbrush.fill"
        case let t where t.contains("photo"): return "camera.fill"
        default: return "star.fill"
        }
    }
    
    private var stats: [StatItem] {
        [
            StatItem(title: "Posts", value: "156", icon: "doc.text.fill"),
            StatItem(title: "Followers", value: "2.3K", icon: "person.2.fill"),
            StatItem(title: "Rating", value: "4.8", icon: "star.fill")
        ]
    }
    
    private var tabTitles = ["About", "Related", "Posts"]
}

// Supporting Views and Models
struct StatItem {
    let title: String
    let value: String
    let icon: String
}

struct Post: Identifiable {
    let id = UUID()
    let title: String
    let likes: Int
    let comments: Int
    let date: String
}

struct StatCard: View {
    let stat: StatItem
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: stat.icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
            
            Text(stat.value)
                .font(.system(size: 20, weight: .bold))
            
            Text(stat.title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

struct userInfoCard: View {
    let title: String
    let subtitle: String
    let detail: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

struct TopicCard: View {
    let topic: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(topic)
                .font(.system(size: 16, weight: .medium))
                .lineLimit(2)
                .truncationMode(.tail)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct PostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(post.title)
                .font(.system(size: 18, weight: .semibold))
            
            HStack {
                Label("\(post.likes)", systemImage: "heart.fill")
                    .foregroundColor(.red)
                
                Label("\(post.comments)", systemImage: "message.fill")
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text(post.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 14))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}
*/
