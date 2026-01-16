//
//  DailyChallengeView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 12/4/25.
//

import SwiftUI

struct DailyChallengeView: View {
    @Binding var showCountdown: Bool
    @Binding var countdownSeconds: Int
    
    var onUnlock: () -> Void

    var body: some View {
        Group {
            if showCountdown {
                CountdownView(players: DailyChallengeView_Previews.samplePlayers, secondsRemaining: countdownSeconds)
            } else {
//
                
                Button(action: onUnlock) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 28, weight: .medium))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's Challenge")
                                .font(.bobaland(size: 28))
                            Text("A new set of problems awaits")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .opacity(0.8)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .buttonStyle(DailyChallengeButtonStyle())
            }
        }
    }
}

private struct DailyChallengeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
    }
}

struct DailyChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        DailyChallengeView(
            showCountdown: .constant(false),
            countdownSeconds: .constant(3),
            onUnlock: {}
        )
    }
    
    // Dummy player data for CountdownView preview
    static var samplePlayers: [MultiplayerPlayerState] {
        let emojis = Emojitar.emojiPalette
        let colors = Emojitar.colorPalette
        return (0..<1).map { index in
            let profile = PlayerProfile.fresh(
                id: "daily-player-\(index)",
                displayName: "Daily Player",
                emojitar: Emojitar(
                    emoji: emojis[index % emojis.count],
                    colorHex: colors[index % colors.count]
                ),
                mode: .kids
            )
            return MultiplayerPlayerState(
                profile: profile,
                isReady: true,
                score: 0,
                latestAnswer: nil,
                isCorrect: false,
                isFirstCorrect: false,
                submittedAt: nil
            )
        }
    }
}
