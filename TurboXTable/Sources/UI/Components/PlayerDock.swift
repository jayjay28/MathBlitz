//
//  PlayerDock.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

struct PlayerDock: View {
    var players: [MultiplayerPlayerState]
    
    var body: some View {
        HStack(spacing: 20) {
            ForEach(Array(players.enumerated()), id: \.1.id) { index, player in
                let status = statusInfo(for: player)
                MultiplayerScoreCardView(
                    emoji: player.profile.emojitar.emoji,
                    displayName: player.profile.displayName,
                    score: player.score,
                    rank: index + 1,
                    isWinner: player.isFirstCorrect,
                    style: .compact
                )
                .accessibilityLabel("\(player.profile.displayName) \(status.label) score \(player.score)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

private func statusInfo(for player: MultiplayerPlayerState) -> (label: String, color: Color) {
    if player.isFirstCorrect {
        return ("First!", .yellow)
    } else if player.isCorrect {
        return ("Correct", .green)
    } else if player.latestAnswer != nil {
        return ("Locked", .orange)
    } else {
        return ("Thinking", .white.opacity(0.8))
    }
}
