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
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack {
                HStack(spacing: 12) {
                    ForEach(players) { player in
                        PlayerDockRow(player: player)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity) // Force ZStack to take full width
        }
    }
}

private struct PlayerDockRow: View {
    var player: MultiplayerPlayerState
    
    @State private var showPlusOne = false
    @State private var lastScore = -1

    var body: some View {
        let status = statusInfo(for: player)
        HStack(spacing: 10) {
            ZStack(alignment: .top) {
                EmojitarBadge(
                    emoji: player.profile.emojitar.emoji,
                    color: player.profile.emojitar.color,
                    size: .sm,
                    ring: player.isFirstCorrect,
                    glow: player.isFirstCorrect,
                    highlight: player.isFirstCorrect
                )
                
                if showPlusOne {
                    Text("+1")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.yellow)
                        .transition(.asymmetric(
                            insertion: .modifier(
                                active: AnimatingPlusOne(progress: 0),
                                identity: AnimatingPlusOne(progress: 1)
                            ),
                            removal: .opacity
                        ))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                                withAnimation(.easeIn(duration: 0.25)) {
                                    showPlusOne = false
                                }
                            }
                        }
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.profile.displayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(status.label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(status.color)
                    Spacer()
                    Text("Score: \(player.score)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.35), in: Capsule())
        .onAppear {
            lastScore = player.score
        }
        .onChange(of: player.score) { newScore in
            if newScore > lastScore {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                    showPlusOne = true
                }
            }
            lastScore = newScore
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
}

private struct AnimatingPlusOne: ViewModifier, Animatable {
    var progress: CGFloat
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(1.0 - progress)
            .offset(y: -30 * progress)
            .scaleEffect(1.0 + (0.5 * (1.0 - progress)))
    }
}
