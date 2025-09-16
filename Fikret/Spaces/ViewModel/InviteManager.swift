import Foundation
import Contacts
import SwiftUI
import Combine

class InviteManager: ObservableObject {
    // Simple invite code generation: FIK-XXXXX
    static func generateInviteCode() -> String {
        let charset = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let randomPart = (0..<5).map { _ in charset.randomElement()! }
        let randomString = String(randomPart)
        return "FIK-\(randomString)"
    }
    
    // Simple validation: just check format
    static func isValidInviteCode(_ code: String) -> Bool {
        let parts = code.uppercased().split(separator: "-")
        return parts.count == 2 && parts[0] == "FIK" && parts[1].count == 5
    }
    
    @Published var contacts: [CNContact] = []
    @Published var permissionStatus: CNAuthorizationStatus = .notDetermined
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var selectedContact: CNContact?
    @Published var showShareSheet: Bool = false
    @Published var shareMessage: String = ""
    
    private let contactStore = CNContactStore()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize with current permission status
        permissionStatus = CNContactStore.authorizationStatus(for: .contacts)
        print("🔐 InviteManager initialized with permission status: \(permissionStatus.rawValue)")
        
        // If permission is already granted, fetch contacts
        if permissionStatus == .authorized {
            print("✅ Permission already granted, fetching contacts on init...")
            fetchContacts()
        }
    }
    
    func requestAccess() {
        isLoading = true
        print("🔐 Requesting contact access...")
        contactStore.requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.permissionStatus = CNContactStore.authorizationStatus(for: .contacts)
                print("🔐 Contact access result: granted=\(granted), status=\(self?.permissionStatus.rawValue ?? 0)")
                if granted {
                    self?.fetchContacts()
                } else {
                    self?.error = "Access to contacts was denied."
                    print("❌ Contact access denied")
                }
            }
        }
    }
    
    func fetchContacts() {
        isLoading = true
        print("📱 Fetching contacts...")
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var fetched: [CNContact] = []
        do {
            try contactStore.enumerateContacts(with: request) { contact, _ in
                if !contact.phoneNumbers.isEmpty || !contact.emailAddresses.isEmpty {
                    fetched.append(contact)
                }
            }
            DispatchQueue.main.async {
                self.contacts = fetched.sorted { $0.givenName < $1.givenName }
                self.isLoading = false
                print("✅ Fetched \(fetched.count) contacts")
            }
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to fetch contacts."
                self.isLoading = false
                print("❌ Failed to fetch contacts: \(error)")
            }
        }
    }
    
func invite(contact: CNContact) {
    let code = InviteManager.generateInviteCode()
    
    // ✅ REPLACE with your actual OneLink ID from AppFlyer dashboard
    let oneLinkURL = "https://fikret.onelink.me/87kg/cu3q37hg?invite_code=\(code)"
    let message = """
    Hey! 🎉
    
    Join me on Fikret!
    
    📱 Click this link: \(oneLinkURL)
    
    🔑 If the link doesn't work, use this invite code:
    \(code)
    
    You can enter this code manually in the app if needed.
    """
    
    self.shareMessage = message
    self.showShareSheet = true
}

    
    func resetShareSheet() {
        print("🔄 Resetting share sheet")
        self.showShareSheet = false
        self.selectedContact = nil
        self.shareMessage = ""
    }
}
