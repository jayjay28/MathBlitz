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
    var onSubmitAnswer: (Int) -> Void
    var onBack: () -> Void
    
    @State private var userAnswer: String = ""
    @State private var phase: BackgroundPhase = .countdown
    @State private var screenShake: CGFloat = 0
    @State private var hasSubmittedThisQuestion = false
    @State private var numpadShake: CGFloat = 0 // New state for numpad shake
    @State private var numpadFlash: Bool = false // New state for numpad flash
    
    private let numpadRows = [
        ["1","2","3"],
        ["4","5","6"],
        ["7","8","9"],
        ["C","0","⌫"]
    ]
    
    private var isLocked: Bool {
        round.answers.contains { $0.isCorrect }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                VStack(spacing: 10) {
                    Spacer()
                    questionSection(for: geo.size)
                    VStack {
                        countdownClock
                        Spacer()
                        PlayerDock(players: players)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)

                        numpadView
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 24)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 36)
                .frame(width: geo.size.width, height: geo.size.height)
                .background(animatedBackgroundColor)
                .offset(x: screenShake)
                
                Button(action: onBack) {
                    Label("Leave", systemImage: "door.left.hand.open")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding(.leading, 16)
                .padding(.top, geo.safeAreaInsets.top + 8)
            }
        }
        .onChange(of: round.questionIndex) { _ in
            userAnswer = ""
            phase = .countdown
            hasSubmittedThisQuestion = false
        }
    }
    
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
        
        return HStack(alignment: .bottom, spacing: 16) {
            Text("\(round.problem.a) × \(round.problem.b) =")
                .font(.bobaland(size: promptSize))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            
            Text(answerText)
                .font(.bobaland(size: answerSize))
                .foregroundColor(isLocked ? .gray : .cyan)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .offset(x: screenShake)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }
    
    private var numpadView: some View {
        VStack(spacing: 12) {
            ForEach(numpadRows, id: \.self) { row in
                HStack {
                    ForEach(row, id: \.self) { value in
                        let isDigit = value.allSatisfy { $0.isNumber }
                        Button {
                            handleNumpadPress(value: value)
                        } label: {
                            Text(value)
                                .font(isDigit ? .bobaland(size: 44) : .system(size: 28, weight: .bold, design: .rounded))
                                .frame(width: 80, height: 80)
                                .background(
                                    Circle()
                                        .fill(numpadFlash ? Color.red.opacity(0.6) : Color.white.opacity(isLocked ? 0.1 : 0.25))
                                )
                                .foregroundColor(.white)
                                .shadow(radius: 3)
                        }
                        .disabled(isLocked || hasSubmittedThisQuestion)
                    }
                }
            }
        }
        .offset(x: numpadShake) // Apply shake here
    }
    
    private func handleNumpadPress(value: String) {
        guard !(isLocked || hasSubmittedThisQuestion) else {
            triggerNumpadBlockedFeedback()
            return
        }
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
            triggerScreenShake()
            userAnswer = ""
        }
    }
    
    private func triggerScreenShake() {
        let shakeAmount: CGFloat = 10
        withAnimation(.default) { screenShake = shakeAmount }
        withAnimation(.default.delay(0.1)) { screenShake = -shakeAmount }
        withAnimation(.default.delay(0.2)) { screenShake = shakeAmount }
        withAnimation(.default.delay(0.3)) { screenShake = 0 }
    }
    
    private func triggerNumpadBlockedFeedback() {
        // Shake
        let shakeAmount: CGFloat = 8
        withAnimation(.default) { numpadShake = shakeAmount }
        withAnimation(.default.delay(0.1)) { numpadShake = -shakeAmount }
        withAnimation(.default.delay(0.2)) { numpadShake = shakeAmount }
        withAnimation(.default.delay(0.3)) { numpadShake = 0 }

        // Flash
        withAnimation(.easeOut(duration: 0.15)) {
            numpadFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.2)) {
                numpadFlash = false
            }
        }
        
        // Haptic feedback for error
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Previews
extension MultiplayerRound {
    static var mock: MultiplayerRound {
        MultiplayerRound(
            id: UUID().uuidString,
            problem: Problem(a: 7, b: 8),
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
    static func mock(id: String, displayName: String, score: Int, isFirstCorrect: Bool = false, isCorrect: Bool = false) -> MultiplayerPlayerState {
        MultiplayerPlayerState(
            profile: PlayerProfile.fresh(
                id: id,
                displayName: displayName,
                emojitar: Emojitar(emoji: "🚀", colorHex: "#FFD700"),
                mode: .kids
            ),
            isReady: true,
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
                    MultiplayerPlayerState.mock(id: "p2", displayName: "Player Two", score: 5, isFirstCorrect: true)
                ],
                timeRemaining: 25,
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
                onSubmitAnswer: { _ in },
                onBack: {}
            )
            .previewDisplayName("iPhone Low Time")
            .previewDevice("iPhone 15 Pro Max")

            MultiplayerRoundPlayView(
                round: MultiplayerRound.mock,
                players: [
                    MultiplayerPlayerState.mock(id: "p1", displayName: "Player One", score: 10),
                    MultiplayerPlayerState.mock(id: "p2", displayName: "Player Two", score: 5, isFirstCorrect: true),
                    MultiplayerPlayerState.mock(id: "p3", displayName: "Player Three", score: 3)
                ],
                timeRemaining: 15,
                onSubmitAnswer: { _ in },
                onBack: {}
            )
            .previewDisplayName("iPad Pro 11-inch")
            .previewDevice("iPad Pro (11-inch) (4th generation)")
        }
    }
}
