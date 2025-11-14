//
//  AnswerValidator.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation

enum AnswerValidator {
    static func firstCorrectPlayerId(from answers: [MultiplayerRound.AnswerSubmission]) -> String? {
        answers
            .filter { $0.isCorrect }
            .sorted(by: { $0.submittedAt < $1.submittedAt })
            .first?
            .playerId
    }
    
    static func annotatePlayers(
        players: [MultiplayerPlayerState],
        round: MultiplayerRound
    ) -> [MultiplayerPlayerState] {
        let highlightId = round.firstCorrectPlayerId ??
            firstCorrectPlayerId(from: round.answers)
        
        return players.map { player in
            let answersForPlayer = round.answers.filter { $0.playerId == player.id }
            let latest = answersForPlayer.sorted(by: { $0.submittedAt > $1.submittedAt }).first
            let isFirst = player.id == highlightId
            return player
                .updating(answer: latest?.value,
                          isCorrect: latest?.isCorrect ?? false,
                          isFirst: isFirst,
                          submittedAt: latest?.submittedAt)
        }
    }
}
