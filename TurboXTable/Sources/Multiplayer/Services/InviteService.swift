//
//  InviteService.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class InviteService: ObservableObject {
    static let shared = InviteService()
    
    @Published private(set) var pendingInvites: [MultiplayerInvite] = []
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    private init() {}
    
    func startListening(for playerId: String) {
        listener?.remove()
        listener = db.collection("invites")
            .whereField("toPlayerId", isEqualTo: playerId)
            .whereField("status", isEqualTo: InviteStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    FlowLogger.trace("Invite listener error → \(error.localizedDescription)")
                    return
                }
                guard let docs = snapshot?.documents else { return }
                self.pendingInvites = docs.compactMap { doc in
                    self.makeInvite(from: doc.data(), id: doc.documentID)
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        pendingInvites = []
    }
    
    func sendInvite(to targetId: String,
                    friendName: String,
                    gameId: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "InviteService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user"])
        }
        guard let profile = PlayerProfileStore.shared.profile else {
            throw NSError(domain: "InviteService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No local profile"])
        }
        let payload: [String: Any] = [
            "fromPlayerId": currentUser.uid,
            "fromName": profile.displayName,
            "toPlayerId": targetId,
            "toName": friendName,
            "gameId": gameId,
            "createdAt": FieldValue.serverTimestamp(),
            "status": InviteStatus.pending.rawValue
        ]
        try await db.collection("invites").addDocument(data: payload)
    }
    
    func updateInvite(_ inviteId: String, status: InviteStatus) async {
        do {
            try await db.collection("invites")
                .document(inviteId)
                .updateData([
                    "status": status.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
        } catch {
            FlowLogger.trace("Invite update failed → \(error.localizedDescription)")
        }
    }
    
    private func makeInvite(from data: [String: Any], id: String) -> MultiplayerInvite? {
        guard
            let fromPlayerId = data["fromPlayerId"] as? String,
            let fromName = data["fromName"] as? String,
            let toPlayerId = data["toPlayerId"] as? String,
            let toName = data["toName"] as? String,
            let gameId = data["gameId"] as? String,
            let statusRaw = data["status"] as? String,
            let status = InviteStatus(rawValue: statusRaw)
        else {
            return nil
        }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return MultiplayerInvite(
            id: id,
            fromPlayerId: fromPlayerId,
            fromName: fromName,
            toPlayerId: toPlayerId,
            toName: toName,
            gameId: gameId,
            createdAt: createdAt,
            status: status
        )
    }
}
