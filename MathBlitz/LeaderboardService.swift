//
//  LeaderboardService.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class LeaderboardService {
    static let shared = LeaderboardService()
    
    private let db = Firestore.firestore()
    private let playerNameKey = "PlayerDisplayName"
    
    private init() {}
    
    func submitScore(_ score: Int, mode: GameMode) async throws {
        guard score > 0 else { return }
        
        let user = try await ensureUser()
        let docRef = collection(for: mode).document(user.uid)
        let existingSnapshot = try? await docRef.getDocument()
        if
            let data = existingSnapshot?.data(),
            let currentBest = data["score"] as? Int,
            currentBest >= score
        {
            return
        }
        
        let displayName = await resolvedDisplayName()
        let now = Date()
        
        let payload: [String: Any] = [
            "playerId": user.uid,
            "displayName": displayName,
            "score": score,
            "mode": mode.rawValue,
            "updatedAt": Timestamp(date: now)
        ]
        
        try await docRef.setData(payload, merge: true)
    }
    
    func fetchTopEntries(mode: GameMode, limit: Int = 10) async throws -> [LeaderboardEntry] {
        let snapshot = try await collection(for: mode)
            .order(by: "score", descending: true)
            .order(by: "updatedAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard
                let displayName = data["displayName"] as? String,
                let score = data["score"] as? Int,
                let timestamp = data["updatedAt"] as? Timestamp
            else {
                return nil
            }
            return LeaderboardEntry(
                id: data["playerId"] as? String ?? doc.documentID,
                displayName: displayName,
                score: score,
                mode: mode,
                updatedAt: timestamp.dateValue()
            )
        }
    }
    
    private func collection(for mode: GameMode) -> CollectionReference {
        db.collection("leaderboards")
            .document(mode.firestoreDocument)
            .collection("entries")
    }
    
    @MainActor
    private func resolvedDisplayName() -> String {
        if let profile = PlayerProfileStore.shared.profile,
           !profile.displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            return profile.displayName
        }
        if let stored = UserDefaults.standard.string(forKey: playerNameKey) {
            return stored
        }
        let generated = randomDisplayName()
        UserDefaults.standard.set(generated, forKey: playerNameKey)
        return generated
    }
    
    private func randomDisplayName() -> String {
        let adjectives = ["Clever", "Wise", "Smart", "Genius", "Bright", "Sharp"]
        let nouns = ["Thinker", "Mind", "Scholar", "Brain", "Guru", "Ace"]
        let adjective = adjectives.randomElement() ?? "Smart"
        let noun = nouns.randomElement() ?? "Thinker"
        let number = Int.random(in: 11...99)
        return "\(adjective) \(noun) \(number)"
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
                    continuation.resume(throwing: NSError(domain: "LeaderboardService",
                                                          code: -1,
                                                          userInfo: [NSLocalizedDescriptionKey: "Missing user"]))
                }
            }
        }
    }
}
