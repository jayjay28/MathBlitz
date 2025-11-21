import OneSignalFramework
import OneSignalNotifications
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        // Remove this method to stop OneSignal from prompting for permission
        OneSignal.Notifications.requestPermission({ accepted in
            print("User accepted notifications: \(accepted)")
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }, fallbackToSettings: true)

        // OneSignal initialization
        OneSignal.initialize("8db0ad86-6dbb-47c8-925c-7d6f49719ae1", withLaunchOptions: launchOptions)
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        OSNotificationsManager.didRegister(forRemoteNotifications: application, deviceToken: deviceToken)
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
#if DEBUG
        print("APNs device token: \(token)")
#endif
        Task { @MainActor in
            let userId = PlayerProfileStore.shared.profile?.id
            await APNSTokenStore.shared.register(token: deviceToken, userId: userId)
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
        if let result = CloudKitNotificationManager.shared.handleRemoteNotification(application: application,
                                                                                    userInfo: userInfo) {
            return result
        }
        if let result = TestGameStartNotifier.shared.handleRemoteNotification(application: application,
                                                                              userInfo: userInfo) {
            return result
        }
        return .newData
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        OSNotificationsManager.handleDidFailRegister(forRemoteNotification: error as NSError)
        print(error)
    }
}
