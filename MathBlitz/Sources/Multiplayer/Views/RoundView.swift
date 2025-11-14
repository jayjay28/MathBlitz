//
//  RoundView.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct RoundView: View {
    var gameId: String
    var round: MultiplayerRound
    var players: [MultiplayerPlayerState]
    var localPlayerId: String?
    var onSubmit: (Int) -> Void
    
    @State private var answerText: String = ""
    @FocusState private var answerFocused: Bool
    var body: some View {
        VStack(spacing: 24) {
            questionHeader
            answerEntry
            Divider().background(Color.white.opacity(0.15))
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(players.sorted(by: sortPlayers)) { player in
                        playerRow(player)
                    }
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .onChange(of: round.firstCorrectPlayerId) { newWinner in
            guard let newWinner else { return }
            AnalyticsClient.track(event: .firstCorrect(playerId: newWinner, roundId: round.id, latency: Date().timeIntervalSince(round.startedAt)))
            fireWinnerHaptic(for: newWinner)
        }
        .onChange(of: round.state) { newState in
            guard newState == .locked else { return }
            let duration = (round.lockedAt ?? Date()).timeIntervalSince(round.startedAt)
            AnalyticsClient.track(event: .roundCompleted(gameId: gameId, duration: max(0, duration)))
        }
    }
    
    private var questionHeader: some View {
        VStack(spacing: 8) {
            Text("Round \(round.id.uppercased())")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Text("\(round.problem.a) × \(round.problem.b)")
                .font(.bobaland(size: 72))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var answerEntry: some View {
        HStack(spacing: 16) {
            TextField("Your answer", text: $answerText)
                .keyboardType(.numberPad)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding()
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .focused($answerFocused)
            
            Button {
                submitAnswer()
            } label: {
                Text("Send")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .padding(.vertical, 18)
                    .padding(.horizontal, 20)
                    .background(canSubmit ? Color.white : Color.gray.opacity(0.4))
                    .foregroundColor(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .disabled(!canSubmit)
        }
    }
    
    private func playerRow(_ player: MultiplayerPlayerState) -> some View {
        HStack(spacing: 14) {
            EmojitarBadge(
                emoji: player.profile.emojitar.emoji,
                color: player.profile.emojitar.color,
                size: .md,
                ring: player.isCorrect || player.isFirstCorrect,
                glow: player.isFirstCorrect,
                highlight: player.isFirstCorrect
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(player.profile.displayName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if let answer = player.latestAnswer {
                    Text("Answered \(answer)\(player.isCorrect ? " ✓" : "")")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(player.isCorrect ? .green.opacity(0.9) : .white.opacity(0.65))
                } else {
                    Text("Thinking…")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            Spacer()
            if let submitted = player.submittedAt {
                Text(submitted, style: .time)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            if player.isFirstCorrect {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.system(size: 20, weight: .bold))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(player.isFirstCorrect ? 0.25 : 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(player.isFirstCorrect ? Color.yellow.opacity(0.7) : Color.clear, lineWidth: 2)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: player.isFirstCorrect)
    }
    
    private func submitAnswer() {
        guard canSubmit, let value = Int(answerText) else { return }
        onSubmit(value)
        answerText = ""
        answerFocused = false
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
    
    private var canSubmit: Bool {
        Int(answerText) != nil && round.state == .open
    }
    
    private func sortPlayers(_ lhs: MultiplayerPlayerState, _ rhs: MultiplayerPlayerState) -> Bool {
        if lhs.isFirstCorrect {
            return true
        }
        if rhs.isFirstCorrect {
            return false
        }
        return lhs.score > rhs.score
    }
    
    private func fireWinnerHaptic(for playerId: String) {
        guard playerId == localPlayerId else { return }
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}
