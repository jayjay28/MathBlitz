//
//  MultiplayerScoreCardView.swift
//  MathBlitz
//
//  Created by Codex on 11/13/25.
//

import SwiftUI

struct MultiplayerScoreCardView: View {
    let emoji: String
    let color: Color
    let displayName: String
    let score: Int
    let rank: Int
    let isWinner: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            Text("\(score)")
                .font(.bobaland(size: 40))
                .foregroundColor(isWinner ? .yellow : .white)
            
            EmojitarBadge(
                emoji: emoji,
                color: color,
                size: .md,
                ring: isWinner,
                glow: isWinner,
                highlight: isWinner
            )
            .frame(width: 72, height: 72)
            
            Text(displayName)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            Text("#\(rank)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(minWidth: 90)
    }
}

struct MultiplayerScoreCardView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            MultiplayerScoreCardView(
                emoji: "⚡️",
                color: .yellow,
                displayName: "Clyon",
                score: 18,
                rank: 1,
                isWinner: true
            )
            MultiplayerScoreCardView(
                emoji: "🦖",
                color: .green,
                displayName: "Ada",
                score: 12,
                rank: 2,
                isWinner: false
            )
            MultiplayerScoreCardView(
                emoji: "🎯",
                color: .purple,
                displayName: "Max",
                score: 8,
                rank: 3,
                isWinner: false
            )
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
