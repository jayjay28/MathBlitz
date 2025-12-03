//
//  MultiplayerRoundPlayView.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

struct MultiplayerRoundPlayView: View {
    var round: MultiplayerRound
    var players: [MultiplayerPlayerState]
    var timeRemaining: Int
    var roundDuration: TimeInterval
    var winnerId: String?
    var onSubmitAnswer: (Int) -> Void
    var onBack: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    
    @State private var userAnswer: String = ""
    @State private var phase: BackgroundPhase = .countdown
    @State private var screenShake: CGFloat = 0
    @State private var hasSubmittedThisQuestion = false
    
    private var isLocked: Bool {
        round.answers.contains { $0.isCorrect }
    }
    
    private var sortedPlayers: [MultiplayerPlayerState] {
        players.sorted { $0.score > $1.score }
    }

    private var isRegularSizeClass: Bool { sizeClass == .regular }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                VStack(spacing: 10) {
                    questionSection(for: geo.size)
                        .padding(.top, max(geo.safeAreaInsets.top, 8))
                    HStack {
                        GameCountdownView(timeRatio: Double(timeRemaining) / roundDuration, seconds: timeRemaining)
                        animatedScoreboard
                    }
                    .padding(.horizontal, isRegularSizeClass ? 40: 0)
                    .frame(maxWidth: 400)
                    
                    NumpadView(
                        userAnswer: $userAnswer,
                        isButtonEnabled: { _ in !isLocked && !hasSubmittedThisQuestion },
                        onDisabledPress: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            SoundEffectPlayer.shared.playBlocked()
                        },
                        onPress: { value in
                            handleNumpadPress(value: value)
                        }
                    )
                    .frame(maxWidth: 400)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0))
                }
                .padding(.horizontal, mainHorizontalPadding)
                .padding(.bottom, geo.safeAreaInsets.bottom)
                .frame(width: geo.size.width, height: geo.size.height)
                .background(animatedBackgroundColor)
                .offset(x: screenShake)
            }
        }
        .onChange(of: round.questionIndex) { _ in
            userAnswer = ""
            phase = .countdown
            hasSubmittedThisQuestion = false
        }
        .onAppear {
            SoundEffectPlayer.shared.ensureAmbientLoopRunning()
        }
    }
    
    private var mainHorizontalPadding: CGFloat { isRegularSizeClass ? 80 : 32 }

    private var animatedBackgroundColor: Color {
        if timeRemaining <= 10 && timeRemaining > 0 {
            return Color.red.opacity(0.9)
        }
        switch phase {
        case .success: return Color.green.opacity(0.85)
        case .failure: return Color.red.opacity(0.9)
        case .timeout: return Color.orange.opacity(0.9)
        case .countdown: return Color.blue.opacity(0.6)
        }
    }
    
    private var countdownClock: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                Text("\(max(0, timeRemaining))")
                    .font(.bobaland(size: 22))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: 58, height: 58)
            .scaleEffect(timeRemaining <= 10 ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: timeRemaining <= 10)
            Text("time left")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private func questionSection(for size: CGSize) -> some View {
        let shortestSide = min(size.width, size.height)
        let promptSize = max(56, shortestSide * 0.12)
        let answerSize = max(72, shortestSide * 0.16)
        let answerText = userAnswer.isEmpty ? "?" : userAnswer
        
        return VStack(spacing: 16) {
            Text("\(round.problem.a) × \(round.problem.b)")
                .font(.bobaland(size: promptSize))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            
            Text(answerText)
                .font(.bobaland(size: answerSize))
                .foregroundColor(isLocked ? Color.white.opacity(0.5) : .white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .offset(x: screenShake)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }

    private var animatedScoreboard: some View {
        VStack(spacing: 8) {
            ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                HStack(spacing: 8) {
//                    Text("#\(index + 1)")
//                        .font(.bobaland(size: 18))
//                        .foregroundColor(player.id == winnerId ? .yellow : .white.opacity(0.7))
//                        .frame(width: 28, alignment: .leading)
                    Text(player.profile.displayName)
                        .font(.bobaland(size: 18))
                        .foregroundColor(player.id == winnerId ? .yellow : .white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(player.score)")
                        .font(.bobaland(size: 24))
                        .foregroundColor(player.id == winnerId ? .yellow : .white)
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: sortedOrderKey)
    }
    
    private var sortedOrderKey: String {
        sortedPlayers.map { "\($0.id):\($0.score)" }.joined(separator: "|")
    }
    
    private func handleNumpadPress(value: String) {
        if value == "⌫" {
            if !userAnswer.isEmpty {
                userAnswer.removeLast()
            }
        } else if value == "C" {
            userAnswer = ""
        } else {
            userAnswer += value
            if let answerInt = Int(userAnswer) {
                if answerInt == round.problem.answer {
                    submit(answer: answerInt, correct: true)
                } else if userAnswer.count >= String(round.problem.answer).count {
                    submit(answer: answerInt, correct: false)
                }
            }
        }
    }
    
    private func submit(answer: Int, correct: Bool) {
        if correct {
            phase = .success
            hasSubmittedThisQuestion = true
            onSubmitAnswer(answer)
        } else {
            phase = .failure
            userAnswer = ""
            // Add shake for wrong answer
            let shakeAmount: CGFloat = 8
            withAnimation(.default) { screenShake = shakeAmount }
            withAnimation(.default.delay(0.1)) { screenShake = -shakeAmount }
            withAnimation(.default.delay(0.2)) { screenShake = shakeAmount }
            withAnimation(.default.delay(0.3)) { screenShake = 0 }
            SoundEffectPlayer.shared.playBlocked()
        }
    }
}

// MARK: - Previews
extension MultiplayerRound {
    static var mock: MultiplayerRound {
        MultiplayerRound(
            id: UUID().uuidString,
            problem: Problem(a: 7, b: 8, operation: .multiply),
            state: .open,
            startedAt: Date(),
            lockedAt: nil,
            answers: [],
            firstCorrectPlayerId: nil,
            questionIndex: 1
        )
    }
}

extension MultiplayerPlayerState {
    static func mock(id: String, displayName: String, score: Int, isFirstCorrect: Bool = false, isCorrect: Bool = false, isReady: Bool = true) -> MultiplayerPlayerState {
        MultiplayerPlayerState(
            profile: PlayerProfile.fresh(
                id: id,
                displayName: displayName,
                emojitar: Emojitar(emoji: "🚀", colorHex: "#FFD700"),
                mode: .kids
            ),
            isReady: isReady,
            score: score,
            latestAnswer: nil,
            isCorrect: isCorrect,
            isFirstCorrect: isFirstCorrect,
            submittedAt: nil
        )
    }
}

struct MultiplayerRoundPlayView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MultiplayerRoundPlayView(
                round: MultiplayerRound.mock,
                players: [
                    MultiplayerPlayerState.mock(id: "p1", displayName: "Player One", score: 10),
                    MultiplayerPlayerState.mock(id: "p2", displayName: "Player Two", score: 5, isFirstCorrect: true),
                    MultiplayerPlayerState.mock(id: "p3", displayName: "Player Three", score: 3),
                    MultiplayerPlayerState.mock(id: "p4", displayName: "Player Four", score: 5)
                ],
                timeRemaining: 25,
                roundDuration: 60,
                winnerId: "p1",
                onSubmitAnswer: { _ in },
                onBack: {}
            )
            .previewDisplayName("iPhone Default")

            MultiplayerRoundPlayView(
                round: MultiplayerRound.mock,
                players: [
                    MultiplayerPlayerState.mock(id: "p1", displayName: "Player One", score: 10),
                    MultiplayerPlayerState.mock(id: "p2", displayName: "Player Two", score: 5, isFirstCorrect: true)
                    
                ],
                timeRemaining: 8, // Test low time remaining
                roundDuration: 60,
                onSubmitAnswer: { _ in },
                onBack: {}
            )
            .previewDisplayName("iPhone Low Time")
            .previewDevice("iPhone 15 Pro Max")

            MultiplayerRoundPlayView(
                round: MultiplayerRound.mock,
                players: [
                    MultiplayerPlayerState.mock(id: "p1", displayName: "Player One", score: 10),
                    MultiplayerPlayerState.mock(id: "p2", displayName: "Player Two", score: 50, isFirstCorrect: true),
                    MultiplayerPlayerState.mock(id: "p3", displayName: "Player Three", score: 3),
                ],
                timeRemaining: 15,
                roundDuration: 60,
                winnerId: "p2",
                onSubmitAnswer: { _ in },
                onBack: {}
            )
            .previewDisplayName("iPad Pro 11-inch")
            .previewDevice("iPad Pro (11-inch) (4th generation)")
        }
    }
}
