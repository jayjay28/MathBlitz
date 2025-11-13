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
        VStack(spacing: 24) {
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
            
            // Olympic Podium Section
            HStack(alignment: .bottom, spacing: 16) {
                // Player at index 1 (2nd place) - smaller, to the left
                if sortedPlayers.count > 1 {
                    podiumPlayerView(player: sortedPlayers[1], rank: 2)
                        .scaleEffect(0.8)
                        .offset(y: 20)
                }

                // Player at index 0 (Winner) - largest, central
                if sortedPlayers.count > 0 {
                    podiumPlayerView(player: sortedPlayers[0], rank: 1)
                        .scaleEffect(1.2)
                }

                // Player at index 2 (3rd place) - smaller, to the right
                if sortedPlayers.count > 2 {
                    podiumPlayerView(player: sortedPlayers[2], rank: 3)
                        .scaleEffect(0.8)
                        .offset(y: 20)
                }
            }
            .frame(maxWidth: .infinity) // Center the podium

            // Remaining players (4th place onwards) - in a list below
            if sortedPlayers.count > 3 {
                VStack(spacing: 8) {
                    ForEach(Array(sortedPlayers.dropFirst(3).enumerated()), id: \.1.id) { index, player in
                        regularPlayerRow(player: player, rank: index + 4)
                    }
                }
            }
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
    
    private func podiumPlayerView(player: MultiplayerPlayerState, rank: Int) -> some View {
        let isWinner = rank == 1
        return VStack(spacing: 8) {
            EmojitarBadge(
                emoji: player.profile.emojitar.emoji,
                color: player.profile.emojitar.color,
                size: isWinner ? .lg : .md,
                ring: isWinner,
                glow: isWinner,
                highlight: isWinner
            )
            Text(player.profile.displayName)
                .font(.system(size: isWinner ? 22 : 18, weight: .bold, design: .rounded))
                .foregroundColor(isWinner ? .yellow : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(player.score) pts")
                .font(.system(size: isWinner ? 18 : 14, weight: .semibold, design: .rounded))
                .foregroundColor(isWinner ? .yellow.opacity(0.9) : .white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(podiumBackgroundColor(for: rank))
        )
    }

    private func regularPlayerRow(player: MultiplayerPlayerState, rank: Int) -> some View {
        HStack(spacing: 16) {
            Text("#\(rank)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 40, alignment: .leading)
            
            EmojitarBadge(
                emoji: player.profile.emojitar.emoji,
                color: player.profile.emojitar.color,
                size: .sm
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.profile.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("\(player.score) pts")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    private func podiumBackgroundColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow.opacity(0.35)
        case 2: return Color.gray.opacity(0.25)
        case 3: return Color.orange.opacity(0.25)
        default: return Color.white.opacity(0.12)
        }
    }
}
