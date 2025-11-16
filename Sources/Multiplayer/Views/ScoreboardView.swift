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
    var isHost: Bool = false
    var isReturningToLobby: Bool = false
    var onReturnToLobby: () -> Void = {}
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
                                displayName: player.profile.displayName,
                                score: player.score,
                                rank: index + 1,
                                caption: "#\(index + 1)",
                                isWinner: player.id == winnerId,
                                style: .large
                            )
                        }
                    }
                    .padding(.horizontal, 6)
                }
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
    
    private var actionSection: some View {
        VStack(spacing: 12) {
            if isHost {
                Button(action: onReturnToLobby) {
                    HStack {
                        if isReturningToLobby {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isReturningToLobby ? "Returning to Lobby…" : "Return to Lobby")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(16)
                }
                .disabled(isReturningToLobby)
                
                Text("Send everyone back to the ready room to decide if you want a rematch.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text("Waiting for the host to return to the lobby or end the session.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
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
