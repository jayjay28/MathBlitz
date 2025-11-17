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
    var isHost: Bool
    var isRematchInProgress: Bool
    var isLocalReady: Bool
    var allPlayersReady: Bool
    var localPlayerId: String?
    var onRematch: () -> Void
    var onLeave: () -> Void
    var onToggleReady: (Bool) -> Void
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            header
            
            if sortedPlayers.isEmpty {
                Text("No scores yet.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            } else {
                scoresList
            }
            
            actionSection
            
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
    
    private var scoresList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(sortedPlayers.enumerated()), id: \.1.id) { index, player in
                    HStack(spacing: 12) {
                        Text("#\(index + 1)")
                            .foregroundColor(.white)
                            .font(.bobaland(size: 20))
                        Text(player.profile.emojitar.emoji)
                            .font(.system(size: 28))
                        Text(player.profile.displayName)
                            .font(.bobaland(size: 20))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(player.score)")
                            .font(.bobaland(size: 28))
                            .foregroundColor(player.id == winnerId ? .green : .white)
                        Text(player.isReady ? "Ready" : "Sitting Out")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(player.isReady ? .green : .red)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            localParticipationControls
            rematchControls
        }
    }
    
    private var localParticipationControls: some View {
        Group {
            if localPlayerId != nil {
                Button(action: { onToggleReady(!isLocalReady) }) {
                    Text(isLocalReady ? "I'm Out" : "Count Me In")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(isLocalReady ? 0.15 : 0.3))
                        .cornerRadius(18)
                }
                
                Button(action: onLeave) {
                    Text("Leave Match")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(14)
                }
            }
        }
    }
    
    private var rematchControls: some View {
        VStack(spacing: 12) {
            if isHost {
                Button(action: onRematch) {
                    HStack {
                        if isRematchInProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isRematchInProgress ? "Starting Rematch…" : "Rematch")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(allPlayersReady ? 0.3 : 0.1))
                    .cornerRadius(18)
                }
                .disabled(isRematchInProgress || !allPlayersReady)
                
                Text(allPlayersReady ? "All racers are ready!" : "Waiting for everyone to confirm or opt out.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            } else {
                Text(allPlayersReady ? "Host can start the rematch any moment." : "Tap above to sit out or let others know you're ready.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
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

#if DEBUG
struct ScoreboardView_Previews: PreviewProvider {
    static let samplePlayers: [MultiplayerPlayerState] = [
        .mock(id: "p1", displayName: "Speedy Sam", score: 18, isFirstCorrect: true, isCorrect: true, isReady: true),
        .mock(id: "p2", displayName: "Rocket Rae", score: 14, isReady: true),
        .mock(id: "p3", displayName: "Turbo Taj", score: 9, isReady: false)
    ]
    
    static var previews: some View {
        ScoreboardView(
            players: samplePlayers,
            winnerId: samplePlayers.first?.id,
            isHost: true,
            isRematchInProgress: false,
            isLocalReady: false,
            allPlayersReady: false,
            localPlayerId: samplePlayers.first?.id,
            onRematch: {},
            onLeave: {},
            onToggleReady: { _ in },
            onClose: {}
        )
        .previewDisplayName("Scoreboard Rematch")
    }
}
#endif
