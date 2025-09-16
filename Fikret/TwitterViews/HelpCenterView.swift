import SwiftUI
struct HelpCenterView: View {
    @State private var searchQuery = ""
    
    private let commonQuestions = [
        "How to change my profile picture?",
        "How to protect my tweets?",
        "How to manage notifications?",
        "How to change account settings?",
        "How to contact support?"
    ]
    
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search help articles", text: $searchQuery)
                }
                .frame(height: 44)
            }
            
            Section(header: Text("Popular Topics")) {
                NavigationLink {
                    AccountHelpView()
                } label: {
                    HelpTopicRow(
                        icon: "person.circle.fill",
                        title: "Account & Profile",
                        description: "Manage your account settings and profile",
                        color: .blue
                    )
                }
                
                NavigationLink {
                    PrivacyHelpView()
                } label: {
                    HelpTopicRow(
                        icon: "lock.fill",
                        title: "Privacy & Safety",
                        description: "Control your privacy and security settings",
                        color: .green
                    )
                }
                
                NavigationLink {
                    NotificationHelpView()
                } label: {
                    HelpTopicRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        description: "Customize your notification preferences",
                        color: .red
                    )
                }
            }
            
            Section(header: Text("Frequently Asked Questions")) {
                ForEach(commonQuestions, id: \.self) { question in
                    NavigationLink {
                        FAQDetailView(question: question)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(question)
                                .font(.body)
                            Text("Learn more about this topic")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Section(header: Text("Contact Support")) {
                Button {
                    // Open email composer
                } label: {
                    HelpTopicRow(
                        icon: "envelope.fill",
                        title: "Email Support",
                        description: "Get help from our support team",
                        color: .blue
                    )
                }
                
                Link(destination: URL(string: "https://twitter.com/support")!) {
                    HelpTopicRow(
                        icon: "globe",
                        title: "Support Center",
                        description: "Visit our online support center",
                        color: .purple
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct HelpTopicRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
} 
