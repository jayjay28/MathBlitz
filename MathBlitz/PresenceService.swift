//
//  PresenceService.swift
//  MathBlitz
//
//  Created by Codex on 11/18/25.
//

import Foundation
import FirebaseFirestore

@MainActor
final class PresenceService: ObservableObject {
    static let shared = PresenceService()
    
    @Published private(set) var onlineCount: Int = 0
    
    private let db = Firestore.firestore()
    private let heartbeatInterval: TimeInterval = 25
    private let staleThreshold: TimeInterval = 120
    
    private var listener: ListenerRegistration?
    private var heartbeatTask: Task<Void, Never>?
    private var currentPlayerId: String?
    private var currentProfile: PlayerProfile?
    
    private init() {}
    
    func startTracking(profile: PlayerProfile) {
        guard currentProfile?.id != profile.id else {
            updateProfileMetadata(profile)
            return
        }
        currentProfile = profile
        startHeartbeat()
        attachListenerIfNeeded()
    }
    
    func stopTracking() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        listener?.remove()
        listener = nil
        currentProfile = nil
        if let playerId = currentPlayerId {
            let ref = db.collection("presence").document(playerId)
            Task {
                do {
                    try await ref.delete()
                } catch {
                    FlowLogger.trace("Presence cleanup failed → \(error.localizedDescription)")
                }
            }
        }
        currentPlayerId = nil
        onlineCount = 0
    }
    
    private func startHeartbeat() {
        guard let profile = currentProfile else { return }
        currentPlayerId = profile.id
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            let ref = self.db.collection("presence").document(profile.id)
            while !Task.isCancelled {
                do {
                    try await ref.setData([
                        "playerId": profile.id,
                        "displayName": profile.displayName,
                        "updatedAt": FieldValue.serverTimestamp(),
                        "emoji": profile.emojitar.emoji,
                        "colorHex": profile.emojitar.colorHex
                    ], merge: true)
                } catch {
                    FlowLogger.trace("Presence heartbeat failed → \(error.localizedDescription)")
                }
                try? await Task.sleep(nanoseconds: UInt64(self.heartbeatInterval * 1_000_000_000))
            }
        }
    }
    
    private func updateProfileMetadata(_ profile: PlayerProfile) {
        guard let playerId = currentPlayerId else { return }
        currentProfile = profile
        let ref = db.collection("presence").document(playerId)
        Task {
            do {
                try await ref.setData([
                    "displayName": profile.displayName,
                    "emoji": profile.emojitar.emoji,
                    "colorHex": profile.emojitar.colorHex
                ], merge: true)
            } catch {
                FlowLogger.trace("Presence metadata update failed → \(error.localizedDescription)")
            }
        }
    }
    
    private func attachListenerIfNeeded() {
        guard listener == nil else { return }
        listener = db.collection("presence")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    FlowLogger.trace("Presence snapshot failed → \(error.localizedDescription)")
                    return
                }
                guard let docs = snapshot?.documents else {
                    self.onlineCount = 0
                    return
                }
                let cutoff = Date().addingTimeInterval(-self.staleThreshold)
                let activeCount = docs.filter { doc in
                    guard let timestamp = doc.data()["updatedAt"] as? Timestamp else { return false }
                    return timestamp.dateValue() >= cutoff
                }.count
                self.onlineCount = activeCount
            }
    }
}
