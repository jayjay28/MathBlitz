//
//  MultiplayerScoreCardView.swift
//  MathBlitz
//
//  Created by Codex on 11/13/25.
//

import SwiftUI

struct MultiplayerScoreCardView: View {
    enum Style {
        case large
        case compact
        
        var scoreSize: CGFloat { self == .large ? 40 : 26 }
        var emojiSize: CGFloat { self == .large ? 44 : 30 }
        var nameSize: CGFloat { self == .large ? 16 : 13 }
        var spacing: CGFloat { self == .large ? 10 : 6 }
    }
    
    let emoji: String
    let displayName: String
    let score: Int
    let rank: Int
    var isWinner: Bool = false
    var style: Style = .large
    
    var body: some View {
        VStack(spacing: style.spacing) {
            Text("\(score)")
                .font(.bobaland(size: style.scoreSize))
                .foregroundColor(isWinner ? .yellow : .white)
            
            Text(emoji)
                .font(.system(size: style.emojiSize))
                .shadow(color: isWinner ? .yellow.opacity(0.3) : .clear, radius: 6, x: 0, y: 2)
            
            Text(displayName)
                .font(.system(size: style.nameSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(minWidth: style == .large ? 90 : 70)
    }
}

struct MultiplayerScoreCardView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            MultiplayerScoreCardView(
                emoji: "⚡️",
                displayName: "Clyon",
                score: 18,
                rank: 1,
                isWinner: true,
                style: .large
            )
            MultiplayerScoreCardView(
                emoji: "🦖",
                displayName: "Ada",
                score: 12,
                rank: 2,
                style: .compact
            )
            MultiplayerScoreCardView(
                emoji: "🎯",
                displayName: "Max",
                score: 8,
                rank: 3,
                style: .compact
            )
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
