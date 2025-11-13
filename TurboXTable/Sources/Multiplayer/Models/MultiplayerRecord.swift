//
//  MultiplayerRecord.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation

enum MatchOutcome: String, Codable {
    case win
    case loss
    case tie
}

struct MultiplayerRecord: Codable, Identifiable {
    var opponentId: String
    var opponentName: String
    var wins: Int
    var losses: Int
    var ties: Int
    var lastPlayed: Date
    
    var id: String { opponentId }
    
    mutating func applyOutcome(_ outcome: MatchOutcome) {
        lastPlayed = Date()
        switch outcome {
        case .win: wins += 1
        case .loss: losses += 1
        case .tie: ties += 1
        }
    }
}
