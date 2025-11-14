//
//  ScoreboardView.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

struct ScoreboardView: View {
    var players: [MultiplayerPlayerState]
    var winnerId: String?
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            header
            
            if sortedPlayers.isEmpty {
                Text("No scores yet.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(Array(sortedPlayers.enumerated()), id: \.1.id) { index, player in
                            MultiplayerScoreCardView(
                                emoji: player.profile.emojitar.emoji,
                                color: player.profile.emojitar.color,
                                displayName: player.profile.displayName,
                                score: player.score,
                                rank: index + 1,
                                isWinner: player.id == winnerId
                            )
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(colors: [.blue, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
    }
    
    private var sortedPlayers: [MultiplayerPlayerState] {
        players.sorted { $0.score > $1.score }
    }
    
    private var header: some View {
        HStack {
            Text("Scoreboard")
                .font(.bobaland(size: 48))
                .foregroundColor(.white)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}
