//
//  TwitterNotificationView.swift
//  TwitterClone
//
//  Created by Rohit Sridharan on 29/03/23.
//


import SwiftUI

struct TwitterNotificationView: View {
    @Binding var isProfilePictureClicked: Bool
    @EnvironmentObject var tweets: TweetData
    @State private var selectedFilter = NotificationFilter.all
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with filters
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        Button(action: {
                            withAnimation { isProfilePictureClicked = true }
                        }) {
                            AsyncImage(url: URL(string: tweets.user!.avatar)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 32, height: 32)
                            }
                        }
                        
                        Spacer()
                        
                        Text("Notifications")
                            .font(.title3.bold())
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(NotificationFilter.allCases, id: \.self) { filter in
                                FilterPill(filter: filter, isSelected: selectedFilter == filter) {
                                    withAnimation { selectedFilter = filter }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
                .background(.ultraThinMaterial)
                .overlay(
                    Divider()
                        .opacity(0.3)
                    , alignment: .bottom
                )
                
                // Notifications List
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        Section(header: DateHeader(title: "Today")) {
                            ForEach(0..<3) { _ in
                                NotificationCell(type: .like)
                                NotificationCell(type: .reply)
                                NotificationCell(type: .retweet)
                            }
                        }
                        
                        Section(header: DateHeader(title: "Yesterday")) {
                            ForEach(0..<3) { _ in
                                NotificationCell(type: .follow)
                                NotificationCell(type: .mention)
                            }
                        }
                    }
                }
                .refreshable {
                    // Refresh notifications
                }
            }
        }
    }
}

// Notification Types and Filters
enum NotificationType {
    case like, reply, retweet, follow, mention
    
    var icon: String {
        switch self {
        case .like: return "heart.fill"
        case .reply: return "bubble.right.fill"
        case .retweet: return "arrow.2.squarepath"
        case .follow: return "person.fill"
        case .mention: return "at"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .like: return .red
        case .reply: return .blue
        case .retweet: return .green
        case .follow: return .blue
        case .mention: return .purple
        }
    }
}

enum NotificationFilter: String, CaseIterable {
    case all = "All"
    case mentions = "Mentions"
    case verified = "Verified"
}

// Filter Pill
struct FilterPill: View {
    let filter: NotificationFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(filter.rawValue)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? .blue : Color.gray.opacity(0.2))
                )
        }
    }
}

// Date Header
struct DateHeader: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                Spacer()
            }
            .background(.ultraThinMaterial)
            
            Divider()
                .opacity(0.3)
        }
    }
}

// Notification Cell
struct NotificationCell: View {
    let type: NotificationType
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Circle()
                .fill(type.iconColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: type.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // Profile Pictures
                HStack(spacing: -12) {
                    ForEach(0..<2) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 2)
                            )
                    }
                }
                .padding(.trailing, 8)
                
                // Content
                Group {
                    Text("John Doe").fontWeight(.semibold) +
                    Text(" and ") +
                    Text("5 others").fontWeight(.semibold) +
                    Text(" liked your Tweet")
                }
                .font(.subheadline)
                
                // Tweet Preview
                if type == .like || type == .reply || type == .retweet {
                    Text("This is the tweet that was interacted with... #SwiftUI #iOS")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                }
                
                // Timestamp
                Text("2h")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
            
            Spacer()
            
            // More Button
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
            }
        }
        .padding()
        .contentShape(Rectangle())
        .background(
            Color(.systemBackground)
                .opacity(isHovered ? 0.5 : 0)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        Divider()
            .opacity(0.3)
    }
}

// Preview
struct TwitterNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        TwitterNotificationView(isProfilePictureClicked: .constant(false))
            .environmentObject(TweetData())
    }
}
