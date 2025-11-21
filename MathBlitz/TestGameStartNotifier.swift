//
//  TestGameStartNotifier.swift
//  MathBlitz
//
//  Created by Codex on 11/19/25.
//

import CloudKit
import Foundation
import UserNotifications
import UIKit

struct TestGameStartEvent {
    let playerName: String
    let mode: GameMode
    let timestamp: Date
}

extension Notification.Name {
    static let testGameStartBroadcastReceived = Notification.Name("TestGameStartBroadcastReceived")
}

@MainActor
final class TestGameStartNotifier {
    static let shared = TestGameStartNotifier()
    
    private let container = CKContainer.default()
    private let recordType = "TestGameStart"
    private let subscriptionID = "test-game-starts.subscription"
    private let subscriptionFlagKey = "TestGameStartNotifier.subscriptionInstalled"
    private var alertsEnabled = false
    
    private init() {}
    
    private var publicDatabase: CKDatabase {
        container.publicCloudDatabase
    }
    
    func updateSubscriptionState(enabled: Bool) {
        alertsEnabled = enabled && DebugDefaults.isTestGameStartNotifierEnabled
        Task { @MainActor in
            if alertsEnabled {
                await installSubscriptionIfNeeded()
            } else {
                await removeSubscriptionIfNeeded()
            }
        }
    }
    
    func broadcastGameStart(mode: GameMode) {
        guard DebugDefaults.isTestGameStartNotifierEnabled else { return }
        Task { @MainActor in
            let record = CKRecord(recordType: recordType)
            let profile = PlayerProfileStore.shared.profile
            record["playerName"] = profile?.displayName ?? "Unknown Challenger"
            record["playerId"] = profile?.id ?? UUID().uuidString
            record["mode"] = mode.rawValue
            record["timestamp"] = Date()
            
            do {
                try await publicDatabase.save(record)
                FlowLogger.trace("Test mode broadcast saved for \(mode.rawValue)")
            } catch {
                FlowLogger.trace("Test mode broadcast failed → \(error.localizedDescription)")
            }
        }
    }
    
    func handleRemoteNotification(application: UIApplication,
                                  userInfo: [AnyHashable: Any]) -> UIBackgroundFetchResult? {
        guard alertsEnabled else { return nil }
        guard
            let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification,
            notification.subscriptionID == subscriptionID,
            let fields = notification.recordFields
        else { return nil }
        
        let playerName = fields["playerName"] as? String ?? "A player"
        let modeRaw = fields["mode"] as? String ?? GameMode.kids.rawValue
        let mode = GameMode(rawValue: modeRaw) ?? .kids
        let timestamp = fields["timestamp"] as? Date ?? Date()
        
        let event = TestGameStartEvent(playerName: playerName, mode: mode, timestamp: timestamp)
        NotificationCenter.default.post(name: .testGameStartBroadcastReceived, object: event)
        
        if application.applicationState != .active {
            scheduleLocalNotification(for: event)
        }
        
        FlowLogger.trace("Received test mode broadcast → \(playerName) started \(mode.rawValue)")
        return .newData
    }
    
    func resetSubscriptionFlag() {
        UserDefaults.standard.set(false, forKey: subscriptionFlagKey)
    }
    
    private func scheduleLocalNotification(for event: TestGameStartEvent) {
        let content = UNMutableNotificationContent()
        content.title = "Test mode: \(event.playerName) jumped in"
        content.body = "New game in \(event.mode.displayName). Can you beat them?"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "test-game-start-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    @MainActor
    private func installSubscriptionIfNeeded() async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: subscriptionFlagKey) else { return }
        
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )
        
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        info.desiredKeys = ["playerName", "mode", "timestamp"]
        subscription.notificationInfo = info
        
        do {
            try await publicDatabase.save(subscription)
            defaults.set(true, forKey: subscriptionFlagKey)
            FlowLogger.trace("Test mode subscription installed")
        } catch {
            FlowLogger.trace("Test mode subscription failed → \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func removeSubscriptionIfNeeded() async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: subscriptionFlagKey) else { return }
        await withCheckedContinuation { continuation in
            publicDatabase.delete(withSubscriptionID: subscriptionID) { _, error in
                if let error {
                    FlowLogger.trace("Test mode subscription delete failed → \(error.localizedDescription)")
                }
                continuation.resume(returning: ())
            }
        }
        defaults.set(false, forKey: subscriptionFlagKey)
    }
}
