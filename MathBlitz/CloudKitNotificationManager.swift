//
//  CloudKitNotificationManager.swift
//  MathBlitz
//
//  Created by Codex on 11/20/25.
//

import CloudKit
import Foundation
import UserNotifications
import UIKit

@MainActor
final class CloudKitNotificationManager {
    static let shared = CloudKitNotificationManager()

    private let container = CKContainer.default()
    private let recordType = "LeaderboardStanding"
    private let subscriptionPrefix = "leaderboard."
    private let subscriptionInstalledKeyPrefix = "CloudKitNotification.subscription."
    private var installsInFlight: Set<String> = []

    private init() {}

    private var publicDatabase: CKDatabase {
        container.publicCloudDatabase
    }

    func updateSubscription(for profile: PlayerProfile?) {
        Task { @MainActor in
            guard let profile else {
                await removeAllSubscriptions()
                return
            }
            await installSubscriptionIfNeeded(for: profile)
        }
    }

    func handleRemoteNotification(application: UIApplication,
                                  userInfo: [AnyHashable: Any]) -> UIBackgroundFetchResult? {
        guard
            let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKQueryNotification,
            let subscriptionID = notification.subscriptionID,
            subscriptionID.hasPrefix(subscriptionPrefix),
            let fields = notification.recordFields
        else { return nil }

        let rank = fields["rank"] as? Int ?? 0
        let previousRank = fields["previousRank"] as? Int ?? rank
        let mode = fields["mode"] as? String ?? "global"
        let boardId = fields["boardId"] as? String ?? "global"

        postLocalNotificationIfNeeded(application: application,
                                      rank: rank,
                                      previousRank: previousRank,
                                      mode: mode,
                                      boardId: boardId)
        NotificationCenter.default.post(
            name: .leaderboardStandingChanged,
            object: LeaderboardStandingChange(rank: rank,
                                              previousRank: previousRank,
                                              mode: mode,
                                              boardId: boardId)
        )

        FlowLogger.trace("CloudKit leaderboard push → rank \(rank) (was \(previousRank)) mode \(mode)")
        return .newData
    }

    func resetSubscriptionFlags() {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(subscriptionInstalledKeyPrefix) }
            .forEach { defaults.set(false, forKey: $0) }
    }

    // MARK: - Private

    @MainActor
    private func installSubscriptionIfNeeded(for profile: PlayerProfile) async {
        let subscriptionID = subscriptionPrefix + profile.id
        let flagKey = subscriptionInstalledKeyPrefix + profile.id
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: flagKey) else { return }
        guard !installsInFlight.contains(profile.id) else { return }
        installsInFlight.insert(profile.id)
        defer { installsInFlight.remove(profile.id) }

        let predicate = NSPredicate(format: "playerId == %@", profile.id)
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordUpdate]
        )

        let info = CKSubscription.NotificationInfo()
        info.alertBody = "Your rank changed"
        info.shouldSendContentAvailable = true
        info.desiredKeys = ["rank", "previousRank", "mode", "boardId"]
        subscription.notificationInfo = info

        do {
            try await publicDatabase.save(subscription)
            defaults.set(true, forKey: flagKey)
            FlowLogger.trace("CloudKit leaderboard subscription installed for \(profile.id)")
        } catch {
            FlowLogger.trace("CloudKit leaderboard subscription failed → \(error.localizedDescription)")
        }
    }

    @MainActor
    private func removeAllSubscriptions() async {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(subscriptionInstalledKeyPrefix) }
        for key in keys {
            let subscriptionID = key.replacingOccurrences(of: subscriptionInstalledKeyPrefix, with: subscriptionPrefix)
            await withCheckedContinuation { continuation in
                publicDatabase.delete(withSubscriptionID: subscriptionID) { _, _ in
                    continuation.resume(returning: ())
                }
            }
            defaults.set(false, forKey: key)
        }
    }

    private func postLocalNotificationIfNeeded(application: UIApplication,
                                               rank: Int,
                                               previousRank: Int,
                                               mode: String,
                                               boardId: String) {
        guard application.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your rank changed"
        content.body = "Now #\(rank) in \(mode) (was #\(previousRank))"
        content.sound = .default
        content.userInfo = ["boardId": boardId, "mode": mode]
        let request = UNNotificationRequest(
            identifier: "leaderboard-\(boardId)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

struct LeaderboardStandingChange {
    let rank: Int
    let previousRank: Int
    let mode: String
    let boardId: String
}

extension Notification.Name {
    static let leaderboardStandingChanged = Notification.Name("LeaderboardStandingChanged")
}
