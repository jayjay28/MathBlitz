//
//  PlayerProfileStore.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class PlayerProfileStore: ObservableObject {
    static let shared = PlayerProfileStore()
    
    @Published private(set) var profile: PlayerProfile?
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastError: Error?
    
    private let db = Firestore.firestore()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageKey = "MathBlitz.identity.profile"
    
    private init() {
        restoreLocalProfile()
    }
    
    func hydrate() {
        restoreLocalProfile()
        Task {
            await syncFromCloudIfPossible()
        }
    }
    
    func upsertProfile(
        displayName: String,
        emojitar: Emojitar,
        preferredMode: GameMode
    ) async throws -> PlayerProfile {
        let user = try await ensureUser()
        let now = Date()
        
        var nextProfile: PlayerProfile
        if var existing = profile {
            existing.displayName = displayName
            existing.emojitar = emojitar
            existing.preferredMode = preferredMode
            existing.updatedAt = now
            nextProfile = existing
        } else {
            nextProfile = PlayerProfile.fresh(
                id: user.uid,
                displayName: displayName,
                emojitar: emojitar,
                mode: preferredMode,
                createdAt: now
            )
        }
        
        try persistLocal(nextProfile)
        profile = nextProfile
        AnalyticsClient.track(event: .emojitarSelected(emoji: emojitar.emoji, colorHex: emojitar.colorHex))
        
        do {
            try await pushToCloud(nextProfile)
        } catch {
            lastError = error
            FlowLogger.trace("PlayerProfileStore cloud save failed → \(error.localizedDescription)")
            throw error
        }
        
        return nextProfile
    }
    
    func updateMode(_ mode: GameMode) async {
        guard var profile else { return }
        profile.preferredMode = mode
        profile.updatedAt = Date()
        do {
            try persistLocal(profile)
            self.profile = profile
            try await pushToCloud(profile)
        } catch {
            lastError = error
            FlowLogger.trace("PlayerProfileStore mode update failed → \(error.localizedDescription)")
        }
    }
    
    func clear() {
        profile = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    
    func syncFromCloudIfPossible() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            if let remote = try await fetchRemoteProfile(playerId: userId) {
                try persistLocal(remote)
                profile = remote
            }
        } catch {
            lastError = error
            FlowLogger.trace("PlayerProfileStore cloud fetch failed → \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private helpers
    
    private func restoreLocalProfile() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try decoder.decode(PlayerProfile.self, from: data)
            profile = decoded
        } catch {
            FlowLogger.trace("PlayerProfileStore local decode failed → \(error.localizedDescription)")
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
    
    private func persistLocal(_ profile: PlayerProfile) throws {
        let data = try encoder.encode(profile)
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    private func pushToCloud(_ profile: PlayerProfile) async throws {
        let payload: [String: Any] = [
            "playerId": profile.id,
            "displayName": profile.displayName,
            "emoji": profile.emojitar.emoji,
            "colorHex": profile.emojitar.colorHex,
            "preferredMode": profile.preferredMode.rawValue,
            "createdAt": Timestamp(date: profile.createdAt),
            "updatedAt": Timestamp(date: profile.updatedAt),
            "alertClyonGameStart": profile.alertClyonGameStart
        ]
        
        try await db.collection("profiles")
            .document(profile.id)
            .setData(payload, merge: true)
    }
    
    private func fetchRemoteProfile(playerId: String) async throws -> PlayerProfile? {
        let snapshot = try await db.collection("profiles")
            .document(playerId)
            .getDocument()
        
        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }
        
        guard
            let displayName = data["displayName"] as? String,
            let emoji = data["emoji"] as? String,
            let colorHex = data["colorHex"] as? String,
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        else {
            return nil
        }
        
        let profile = PlayerProfile(
            id: playerId,
            displayName: displayName,
            emojitar: Emojitar(emoji: emoji, colorHex: colorHex),
            createdAt: createdAt,
            updatedAt: updatedAt,
            preferredModeRaw: data["preferredMode"] as? String,
            alertClyonGameStart: data["alertClyonGameStart"] as? Bool ?? false
        )
        
        return profile
    }
    
    private func ensureUser() async throws -> User {
        if let user = Auth.auth().currentUser {
            return user
        }
        return try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signInAnonymously { authResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let user = authResult?.user {
                    continuation.resume(returning: user)
                } else {
                    continuation.resume(throwing: NSError(domain: "PlayerProfileStore",
                                                          code: -1,
                                                          userInfo: [NSLocalizedDescriptionKey: "Missing user"]))
                }
            }
        }
    }
}
