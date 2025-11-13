//
//  CountdownView.swift
//  TurboXTable
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

struct CountdownView: View {
    var players: [MultiplayerPlayerState]
    var secondsRemaining: Int
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Ready?")
                .font(.bobaland(size: 52))
                .foregroundColor(.white)
            
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 10)
                    .frame(width: 200, height: 200)
                    .overlay {
                        Text("\(secondsRemaining)")
                            .font(.bobaland(size: 88))
                            .foregroundColor(.white)
                            .scaleEffect(springyScale)
                            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: secondsRemaining)
                    }
                
                ForEach(players.prefix(5)) { player in
                    EmojitarBadge(
                        emoji: player.profile.emojitar.emoji,
                        color: player.profile.emojitar.color,
                        size: .lg,
                        ring: true,
                        glow: true
                    )
                    .offset(offset(for: player))
                    .rotationEffect(.degrees(Double.random(in: -6...6)))
                }
            }
            .frame(height: 280)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(players) { player in
                        VStack(spacing: 6) {
                            EmojitarBadge(
                                emoji: player.profile.emojitar.emoji,
                                color: player.profile.emojitar.color,
                                size: .md
                            )
                            Text(player.profile.displayName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                        .frame(width: 72)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RadialGradient(colors: [.pink, .purple], center: .center, startRadius: 80, endRadius: 500)
                .ignoresSafeArea()
        )
    }
    
    private var springyScale: CGFloat {
        secondsRemaining == 0 ? 1.2 : 1.0
    }
    
    private func offset(for player: MultiplayerPlayerState) -> CGSize {
        guard let index = players.firstIndex(of: player) else { return .zero }
        let angle = Double(index) / Double(max(players.count, 1)) * (2 * Double.pi)
        let radius: CGFloat = 120
        return CGSize(
            width: CGFloat(cos(angle)) * radius,
            height: CGFloat(sin(angle)) * radius
        )
    }
}
