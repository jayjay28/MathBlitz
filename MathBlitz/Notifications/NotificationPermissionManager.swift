import Foundation
import UserNotifications

final class NotificationPermissionManager {
    static let shared = NotificationPermissionManager()
    private init() {}
    
    func requestIfNotDetermined() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self.requestPermission()
        }
    }
    
    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            completion?(granted)
        }
    }
}
