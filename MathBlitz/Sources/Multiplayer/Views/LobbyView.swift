//
//  LobbyView.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct LobbyView: View {
    var players: [MultiplayerPlayerState]
    var localPlayerId: String?
    var isHost: Bool
    var maxPlayers: Int
    var sessionCode: String
    var onReadyToggle: (Bool) -> Void
    var onStartMatch: () -> Void
    var onExit: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button(action: onExit) {
                    Label("Leave", systemImage: "chevron.left")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                Spacer()
            }
            
            Text("Lobby")
                .font(.bobaland(size: 48))
                .foregroundColor(.white)
            
            Text("Invite code: \(sessionCode)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .padding(.bottom, 4)
            
            Text("\(players.count)/\(maxPlayers) players")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            
            if players.isEmpty {
                Text("Waiting for friends to join…")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            }
            
            VStack(spacing: 12) {
                ForEach(players) { player in
                    HStack(spacing: 16) {
                        EmojitarBadge(
                            emoji: player.profile.emojitar.emoji,
                            color: player.profile.emojitar.color,
                            size: .md,
                            ring: player.isReady,
                            glow: player.isReady
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(player.profile.displayName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(player.isReady ? "Ready" : "Getting ready…")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(player.isReady ? .green.opacity(0.9) : .white.opacity(0.7))
                        }
                        Spacer()
                        if player.id == localPlayerId {
                            ReadyToggleButton(isReady: player.isReady, action: onReadyToggle)
                        } else {
                            Image(systemName: player.isReady ? "checkmark.circle.fill" : "clock")
                                .foregroundColor(player.isReady ? .green : .white.opacity(0.7))
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            
            if isHost {
                Button(action: onStartMatch) {
                    Text("Start Match")
                        .font(.bobaland(size: 28))
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canStartMatch ? Color.white : Color.white.opacity(0.35))
                        .clipShape(Capsule())
                }
                .disabled(!canStartMatch)
                .padding(.top, 8)
                
                Text(startDescription)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            } else {
                Text("Host will start once everyone’s ready.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .onAppear {
            FlowLogger.trace("LobbyView appear → players=\(players.count)")
        }
        .onChange(of: players.count) { count in
            FlowLogger.trace("LobbyView player count changed → \(count)")
        }
    }
}

private extension LobbyView {
    var canStartMatch: Bool {
        guard players.count >= 2, players.count <= maxPlayers else { return false }
        return players.allSatisfy { $0.isReady }
    }
    
    var startDescription: String {
        if players.count > maxPlayers {
            return "Lobby full — kick someone before starting."
        } else if players.count < 2 {
            return "Need at least 2 players to start."
        } else if !players.allSatisfy({ $0.isReady }) {
            return "Everyone must tap Ready before starting."
        }
        return "All set! Launch when you’re ready."
    }
}

private struct ReadyToggleButton: View {
    @State private var isAnimating: Bool = false
    @State private var localOverride: Bool?
    var isReady: Bool
    var action: (Bool) -> Void
    
    private var currentReady: Bool {
        localOverride ?? isReady
    }
    
    var body: some View {
        Button {
            let next = !currentReady
            localOverride = next
            action(next)
            tapHaptic(isReady: next)
            if next {
                SoundEffectPlayer.shared.playReadyToggle()
            }
            FlowLogger.trace("Lobby ready button tapped → next=\(next)")
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isAnimating.toggle()
            }
        } label: {
            Text(currentReady ? "Ready!" : "I’m ready")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.purple)
                .padding(.vertical, 8)
                .padding(.horizontal, 18)
                .background(Color.white)
                .clipShape(Capsule())
        }
        .scaleEffect(isAnimating ? 1.05 : 1.0)
    }
    
    private func tapHaptic(isReady: Bool) {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(isReady ? .success : .warning)
        #endif
    }
}
