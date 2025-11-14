//
//  MultiplayerRecordStore.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation

@MainActor
final class MultiplayerRecordStore: ObservableObject {
    static let shared = MultiplayerRecordStore()
    
    @Published private(set) var records: [MultiplayerRecord] = []
    
    private let storageKey = "MathBlitz.multiplayer.records"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private init() {
        load()
    }
    
    func recordResult(opponent profile: PlayerProfile, outcome: MatchOutcome) {
        if let index = records.firstIndex(where: { $0.opponentId == profile.id }) {
            records[index].opponentName = profile.displayName
            records[index].applyOutcome(outcome)
        } else {
            var record = MultiplayerRecord(
                opponentId: profile.id,
                opponentName: profile.displayName,
                wins: 0,
                losses: 0,
                ties: 0,
                lastPlayed: Date()
            )
            record.applyOutcome(outcome)
            records.append(record)
        }
        save()
    }
    
    func recordResult(opponentId: String, opponentName: String, outcome: MatchOutcome) {
        let profile = PlayerProfile.fresh(
            id: opponentId,
            displayName: opponentName,
            emojitar: .default,
            mode: .kids
        )
        recordResult(opponent: profile, outcome: outcome)
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? decoder.decode([MultiplayerRecord].self, from: data) {
            records = decoded
        }
    }
    
    private func save() {
        guard let data = try? encoder.encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
