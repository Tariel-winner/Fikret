
import UIKit
import AppsFlyerLib
import UserNotifications
import CoreLocation

class AppDelegate: NSObject, UIApplicationDelegate {
    
   
    // MARK: - Application Lifecycle
    func application(_ application: UIApplication,
                        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        let devKey = getAppFlyerDevKey()
    let appStoreID = getAppStoreID()
    
    // Configure AppFlyer
    AppsFlyerLib.shared().appsFlyerDevKey = devKey
    AppsFlyerLib.shared().appleAppID = appStoreID
    AppsFlyerLib.shared().delegate = self
    AppsFlyerLib.shared().isDebug = true
        // Configure AppFlyer for TestFlight compatibility
        AppsFlyerLib.shared().useReceiptValidationSandbox = true // Enable for TestFlight
        
        // Start AppFlyer
        AppsFlyerLib.shared().start()
        
        print("✅ AppFlyer initialized successfully")
        
        // Register for push notifications
        registerForPushNotifications(application)
        
        // ❌ REMOVED: Don't initialize LocationService here to prevent premature permission checks
        // LocationService will be initialized when needed in FikretApp or SignupView
        
        // ❌ REMOVED: Don't send location from AppDelegate to prevent permission issues
        // Location will be handled in FikretApp.task when appropriate
        
        return true
    }
    
    private func getAppStoreID() -> String {
    // Get from Info.plist
    if let appStoreID = Bundle.main.object(forInfoDictionaryKey: "AppStoreID") as? String,
       !appStoreID.isEmpty {
        return appStoreID
    }
    
    // Fallback
    return "6752263168"
}
// ADD THIS METHOD:
private func getAppFlyerDevKey() -> String {
    // Get from Info.plist
    if let devKey = Bundle.main.object(forInfoDictionaryKey: "AppsFlyerDevKey") as? String,
       !devKey.isEmpty {
        return devKey
    }
    
    // Fallback
    return "YOUR_APPSFLYER_DEV_KEY"
}


    // MARK: - AppFlyer Deep Link Handling
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // AppFlyer handles all deep linking automatically
        return true
    }
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // AppFlyer handles all deep linking automatically
        return true
    }
    
    // MARK: - Push Notifications
    private func registerForPushNotifications(_ application: UIApplication) {
        print("📱 Registering for push notifications...")
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("📱 Notification permission: \(granted)")
            
            DispatchQueue.main.async {
                if granted {
                    application.registerForRemoteNotifications()
                    print("📱 Registered for remote notifications")
                }
            }
        }
    }
    
    // MARK: - APN Device Token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Convert device token to string
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        print("📱 APN Device token received: \(token)")
        
        // Store device token for use during registration
        UserDefaults.standard.set(token, forKey: "deviceToken")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APN registration failed: \(error)")
    }
    
 
    
}

// MARK: - AppsFlyerLibDelegate
extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
        print("✅ AppFlyer conversion data received: \(conversionInfo)")
        
        // Handle invite code from AppFlyer OneLink
        if let inviteCode = conversionInfo["invite_code"] as? String {
            print("🎫 Found invite code from AppFlyer: \(inviteCode)")
            UserDefaults.standard.set(inviteCode, forKey: "inviteCode")
            
            // Post notification to update FikretApp's invite code state
            NotificationCenter.default.post(
                name: Notification.Name("InviteCodeReceived"),
                object: nil,
                userInfo: ["code": inviteCode]
            )
        }
        
        // Handle TestFlight detection
        if let isTestFlight = conversionInfo["is_testflight"] as? Bool, isTestFlight {
            print("🧪 TestFlight build detected via AppFlyer")
            UserDefaults.standard.set(true, forKey: "isTestFlightBuild")
        }
    }
    
    func onConversionDataFail(_ error: Error) {
        print("❌ AppFlyer conversion data failed: \(error.localizedDescription)")
    }
    
    func onAppOpenAttribution(_ attributionData: [AnyHashable : Any]) {
        print("✅ AppFlyer attribution data: \(attributionData)")
        
        // Handle invite code from attribution data
        if let inviteCode = attributionData["invite_code"] as? String {
            print("🎫 Found invite code from AppFlyer attribution: \(inviteCode)")
            UserDefaults.standard.set(inviteCode, forKey: "inviteCode")
            
            // Post notification to update FikretApp's invite code state
            NotificationCenter.default.post(
                name: Notification.Name("InviteCodeReceived"),
                object: nil,
                userInfo: ["code": inviteCode]
            )
        }
        
        // Handle TestFlight detection
        if let isTestFlight = attributionData["is_testflight"] as? Bool, isTestFlight {
            print("🧪 TestFlight build detected via AppFlyer attribution")
            UserDefaults.standard.set(true, forKey: "isTestFlightBuild")
        }
    }
    
    func onAppOpenAttributionFailure(_ error: Error) {
        print("❌ AppFlyer attribution failed: \(error.localizedDescription)")
    }
}


