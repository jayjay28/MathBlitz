//
//  GameModels.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation

enum MultiplayerPhase: Equatable {
    case lobby
    case countdown(remaining: TimeInterval)
    case round
    case scoreboard
}

struct MultiplayerPlayerState: Identifiable, Equatable {
    var profile: PlayerProfile
    var isReady: Bool
    var score: Int
    var latestAnswer: Int?
    var isCorrect: Bool
    var isFirstCorrect: Bool
    var submittedAt: Date?
    
    var id: String { profile.id }
    
    func updating(answer: Int?, isCorrect: Bool, isFirst: Bool, submittedAt: Date?) -> MultiplayerPlayerState {
        var copy = self
        copy.latestAnswer = answer
        copy.isCorrect = isCorrect
        copy.isFirstCorrect = isFirst
        copy.submittedAt = submittedAt
        return copy
    }
    
    func updating(score: Int) -> MultiplayerPlayerState {
        var copy = self
        copy.score = score
        return copy
    }
}

enum MultiplayerRoundState: String, Codable {
    case open
    case locked
}

struct MultiplayerRound: Identifiable, Equatable {
    var id: String
    var problem: Problem
    var state: MultiplayerRoundState
    var startedAt: Date
    var lockedAt: Date?
    var answers: [AnswerSubmission]
    var firstCorrectPlayerId: String?
    var questionIndex: Int
    
    struct AnswerSubmission: Identifiable, Equatable {
        var id: String
        var playerId: String
        var value: Int
        var isCorrect: Bool
        var submittedAt: Date
    }
}

extension MultiplayerRound {
    static func == (lhs: MultiplayerRound, rhs: MultiplayerRound) -> Bool {
        lhs.id == rhs.id &&
        lhs.problem == rhs.problem &&
        lhs.state == rhs.state &&
        lhs.startedAt == rhs.startedAt &&
        lhs.lockedAt == rhs.lockedAt &&
        lhs.answers == rhs.answers &&
        lhs.firstCorrectPlayerId == rhs.firstCorrectPlayerId
    }
}

struct MultiplayerGame: Identifiable, Equatable {
    var id: String
    var players: [MultiplayerPlayerState]
    var currentRound: MultiplayerRound?
    var phase: MultiplayerPhase
    var winnerId: String?
    var roundStartedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    static let placeholder = MultiplayerGame(
        id: "demo",
        players: [],
        currentRound: nil,
        phase: .lobby,
        winnerId: nil,
        roundStartedAt: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
}
