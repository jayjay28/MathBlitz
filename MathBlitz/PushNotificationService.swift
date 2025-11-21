import OneSignalFramework
import UserNotifications

// This is no longer a centralized service but a collection of delegates.
// OneSignal handles the core push registration and token management.

//extension AppDelegate: UNUserNotificationCenterDelegate {
//    // Handle foreground notifications
//    func userNotificationCenter(_ center: UNUserNotificationCenter,
//                                willPresent notification: UNNotification,
//                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
//        completionHandler([.banner, .sound])
//    }
//}
