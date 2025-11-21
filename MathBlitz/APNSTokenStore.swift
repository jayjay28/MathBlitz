//
//  APNSTokenStore.swift
//  MathBlitz
//
//  Created by Codex on 11/20/25.
//

import FirebaseFirestore
import UIKit

@MainActor
final class APNSTokenStore {
    static let shared = APNSTokenStore()

    private let db = Firestore.firestore()
    private let userDefaultsKey = "APNSTokenStore.lastToken"

    private init() {}

    func register(token: Data, userId: String?) async {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        let existing = UserDefaults.standard.string(forKey: userDefaultsKey)
        guard existing != tokenString else { return }

        UserDefaults.standard.set(tokenString, forKey: userDefaultsKey)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        var payload: [String: Any] = [
            "token": tokenString,
            "bundleId": Bundle.main.bundleIdentifier ?? "unknown",
            "platform": "ios",
            "lastSeen": FieldValue.serverTimestamp()
        ]
        if let userId {
            payload["userId"] = userId
        }
        do {
            try await db.collection("devices")
                .document(deviceId)
                .setData(payload, merge: true)
            FlowLogger.trace("APNS token stored for device \(deviceId)")
        } catch {
            FlowLogger.trace("APNS token store failed → \(error.localizedDescription)")
        }
    }
}
