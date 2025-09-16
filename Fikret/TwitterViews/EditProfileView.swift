/*
import SwiftUI
import PhotosUI
import Supabase

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tweets: TweetData
    
    @State private var name: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var website: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
      
            Form {
                // Profile Picture Section
                Section(header: Text("Profile Picture")) {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            VStack {
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                } else if let user = tweets.user,
                                          !user.profilepicture.isEmpty {
                                    AsyncImage(url: URL(string: user.profilepicture)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 90, height: 90)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        ProgressView()
                                            .frame(width: 90, height: 90)
                                    }
                                } else {
                                    // Default profile image
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundColor(.gray)
                                        .frame(width: 90, height: 90)
                                }
                                
                                Text("Tap to change")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("Profile Information")) {
                    TextField("Name", text: $name)
                    TextField("Bio", text: $bio)
                    TextField("Location", text: $location)
                    TextField("Website", text: $website)
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            profileImage = image
                        }
                    }
                }
            }
        }
        .onAppear {
            // Load current user data
            if let user = tweets.user {
                name = user.name
                bio = user.bio ?? ""
                location = user.location ?? ""
                website = user.website ?? ""
            }
        }
    }
    
    private func saveProfile() async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
        }

        do {
            try await tweets.updateProfile(
                name: name,
                bio: bio,
                location: location,
                website: website,
                profileImage: profileImage
            )
            
            // Update local storage
            UserDefaults.standard.set(name, forKey: "userName")
            UserDefaults.standard.set(bio, forKey: "userBio")
            UserDefaults.standard.set(location, forKey: "userLocation")
            UserDefaults.standard.set(website, forKey: "userWebsite")
            
          
            await MainActor.run {
                isLoading = false
                dismiss()
            }
            
        } catch {
            print("❌ Error updating profile: \(error)")
            await MainActor.run {
                errorMessage = "Failed to update profile: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView()
            .environmentObject(TweetData())
    }
}
*/


