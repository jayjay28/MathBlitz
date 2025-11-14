//
//  GameSceneView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI

struct GameSceneView: View {
    @ObservedObject var viewModel: GameViewModel
    let onSettingsTapped: () -> Void
    let onLeaderboardTapped: () -> Void
    let onMultiplayerTapped: () -> Void
    let multiplayerPlayers: [MultiplayerPlayerState]
    private let requireManualStart: Bool
    
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    @State private var isMenuOpen = false
    @State private var showStartPanel: Bool
    @State private var pendingMode: GameMode
    @State private var hasAutoStarted = false
    @State private var scoreShakeOffset: CGFloat = 0
    
    init(
        viewModel: GameViewModel,
        onSettingsTapped: @escaping () -> Void,
        onLeaderboardTapped: @escaping () -> Void,
        onMultiplayerTapped: @escaping () -> Void,
        multiplayerPlayers: [MultiplayerPlayerState] = [],
        requireManualStart: Bool = true
    ) {
        self.viewModel = viewModel
        self.onSettingsTapped = onSettingsTapped
        self.onLeaderboardTapped = onLeaderboardTapped
        self.onMultiplayerTapped = onMultiplayerTapped
        self.multiplayerPlayers = multiplayerPlayers
        self.requireManualStart = requireManualStart
        _pendingMode = State(initialValue: viewModel.gameMode)
        _showStartPanel = State(initialValue: requireManualStart)
    }
    
    private let numpadRows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["C", "0", "⌫"]
    ]
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            if showStartPanel {
                ManualStartOverlay(
                    pendingMode: $pendingMode,
                    onStart: startManualGame,
                    onMultiplayerTapped: onMultiplayerTapped
                )
                .transition(.opacity)
            } else {
                gameBody
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .onAppear(perform: handleAppear)
        .onChange(of: viewModel.gameMode) { mode in
            pendingMode = mode
        }
        .animation(.spring(), value: viewModel.showPlacementToast)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isMenuOpen)
    }

    private var gameBody: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                VStack(spacing: 10) {
                    Spacer(minLength: 20)
                    
                    questionSection(for: geo.size)
                    
                    Spacer(minLength: 20)
                    
                    VStack(spacing: 12) {
                        countdownClock
                        livesSection
                        ScoreAndBestView(currentScore: viewModel.score, highScore: viewModel.highScore, sizeClass: sizeClass)
                            .offset(x: scoreShakeOffset)
                            .onChange(of: viewModel.triggerHighScoreShake) { trigger in
                                if trigger {
                                    shakeScoreView()
                                }
                            }
                        numpadView
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 20)
                }
                .padding(.horizontal, mainHorizontalPadding)
                .padding(.bottom, 36)
                .frame(width: geo.size.width, height: geo.size.height)
                .background(animatedBackgroundColor)
                .offset(x: viewModel.screenShake)

                if !multiplayerPlayers.isEmpty {
                    PlayerDock(players: multiplayerPlayers)
                        .padding(.horizontal, 16)
                        .padding(.top, geo.safeAreaInsets.top + 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if viewModel.isGameOver {
                    PostGameView(score: viewModel.score,
                                 leaderboardEntries: viewModel.leaderboardEntries,
                                 onNewGame: presentManualStartPanel)
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                }
                
                menuButtonLayer

                if viewModel.showHighScoreCelebration {
                    HighScoreCelebrationView(score: viewModel.score,
                                             onDismiss: viewModel.dismissCelebration)
                }

                if viewModel.showSuccessFlash {
                    SuccessFlashView()
                        .transition(.scale.combined(with: .opacity))
                }

                if viewModel.showPlacementToast, let placement = viewModel.latestPlacement {
                    PlacementToastView(placement: placement)
                        .padding(.top, 80)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if isMenuOpen {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isMenuOpen = false
                            }
                        }
                SideMenuView(isEndGameEnabled: viewModel.isGameActive, onLeaderboard: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isMenuOpen = false
                    }
                    onLeaderboardTapped()
                }, onSettings: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isMenuOpen = false
                        }
                        onSettingsTapped()
                    }, onMultiplayer: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isMenuOpen = false
                        }
                        onMultiplayerTapped()
                }, onEndGame: {
                    withAnimation {
                        isMenuOpen = false
                        viewModel.quitGame()
                    }
                })
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
    }
    
    // MARK: - Adaptive Properties
    
    private var isRegularSizeClass: Bool { sizeClass == .regular }
    
    private var mainHorizontalPadding: CGFloat { isRegularSizeClass ? 80 : 32 }
    private var promptFontSize: CGFloat { isRegularSizeClass ? 90 : 56 }
    private var answerFontSize: CGFloat { isRegularSizeClass ? 110 : 72 }
    private var countdownClockSize: CGFloat { isRegularSizeClass ? 72 : 58 }
    private var countdownClockFontSize: CGFloat { isRegularSizeClass ? 32 : 22 }
    private var lifeMeterHeartSize: CGFloat { isRegularSizeClass ? 20 : 14 }
    
    private var numpadButtonSize: CGFloat { isRegularSizeClass ? 80 : 65 }
    private var numpadFontSize: CGFloat { isRegularSizeClass ? 44 : 36 }
    private var numpadSymbolFontSize: CGFloat { isRegularSizeClass ? 28 : 24 }
    
    // MARK: - Game Views

    private var animatedBackgroundColor: Color {
        switch viewModel.backgroundPhase {
        case .success:
            return Color.green.opacity(0.85)
        case .failure:
            return Color.red.opacity(0.9)
        case .timeout:
            return Color.orange.opacity(0.9)
        case .countdown:
            let clampedProgress = max(0, min(1, viewModel.timeRemainingRatio))
            return Color.green.mix(with: .red, by: 1 - clampedProgress)
        }
    }
    
    private var isMultiplayer: Bool { !multiplayerPlayers.isEmpty }
    private var topPadding: CGFloat { isMultiplayer ? 120 : 36 }
    
    private func handleAppear() {
        guard !hasAutoStarted else { return }
        if !requireManualStart {
            viewModel.resetGame()
            hasAutoStarted = true
        }
    }
    
    private func startManualGame() {
        viewModel.updateGameMode(pendingMode)
        FlowLogger.trace("Manual game start → mode \(pendingMode.rawValue)")
        viewModel.resetGame()
        hasAutoStarted = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showStartPanel = false
        }
    }
    
    private func presentManualStartPanel() {
        viewModel.prepareForManualRestart()
        pendingMode = viewModel.gameMode
        hasAutoStarted = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showStartPanel = true
        }
    }
    
    private func shakeScoreView() {
        let animation = Animation.linear(duration: 0.05)
        withAnimation(animation) { scoreShakeOffset = -10 }
        withAnimation(animation.delay(0.05)) { scoreShakeOffset = 10 }
        withAnimation(animation.delay(0.1)) { scoreShakeOffset = -6 }
        withAnimation(animation.delay(0.15)) { scoreShakeOffset = 6 }
        withAnimation(animation.delay(0.2)) { scoreShakeOffset = 0 }
    }

    private var numpadView: some View {
        VStack(spacing: 10) {
            ForEach(numpadRows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { value in
                        let isDigit = value.allSatisfy { $0.isNumber }
                        Button(action: { viewModel.handleNumpadPress(value: value) }) {
                            Text(value)
                                .font(isDigit ? .bobaland(size: numpadFontSize) : .system(size: numpadSymbolFontSize, weight: .bold, design: .rounded))
                                .frame(width: numpadButtonSize, height: numpadButtonSize)
                                .background(Color.white.opacity(0.25))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                    }
                }
            }
        }
    }
    
    private var countdownClock: some View {
        let ratio = max(0, min(1, viewModel.timeRemainingRatio))
        let seconds = max(0, viewModel.timeRemainingSeconds)
        
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                
                Circle()
                    .trim(from: 0, to: CGFloat(ratio))
                    .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(seconds)")
                    .font(.bobaland(size: countdownClockFontSize))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: countdownClockSize, height: countdownClockSize)
            .opacity(viewModel.backgroundPhase == .countdown ? 1 : 0.45)
            .animation(.easeInOut(duration: 0.2), value: viewModel.backgroundPhase)
            
            Text("time left")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .kerning(0.6)
        }
    }
    
    
    @ViewBuilder
    private func questionSection(for size: CGSize) -> some View {
        let answerText = viewModel.userAnswer.isEmpty ? "?" : viewModel.userAnswer
        
        HStack(alignment: .bottom, spacing: 16) {
            Text("\(viewModel.currentProblem.a) × \(viewModel.currentProblem.b) =")
                .font(.bobaland(size: promptFontSize))
                .foregroundColor(.white)
                .allowsTightening(true)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            Text(answerText)
                .font(.bobaland(size: answerFontSize))
                .foregroundColor(viewModel.backgroundPhase == .failure ? .white : .white)
                .allowsTightening(true)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .modifier(AnswerShakeModifier(phase: viewModel.backgroundPhase))
                .opacity(viewModel.backgroundPhase == .success ? 0 : 1)
                .animation(.easeInOut(duration: viewModel.backgroundPhase == .success ? 0.3 : 0.0),
                           value: viewModel.backgroundPhase == .success)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }
    
    private var livesSection: some View {
        VStack(spacing: 8) {
            Text("LIVES")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .kerning(1.1)
            
            LifeMeter(totalLives: viewModel.totalLives, remainingLives: viewModel.remainingLives, heartSize: lifeMeterHeartSize)
        }
    }

    private var questionsProgressRow: some View {
        HStack {
            Text("QUESTIONS")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text("\(viewModel.questionsAnsweredInLevel)/\(viewModel.currentLevel.questionsPerLevel)")
                .font(.bobaland(size: 28))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12), in: Capsule())
    }
}

extension GameSceneView {
    private var menuButtonLayer: some View {
        VStack {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isMenuOpen.toggle()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .padding(.leading, 24)
                .padding(.top, 20)
                
                Spacer()
            }
            
            Spacer()
        }
    }
}

struct ScoreAndBestView: View {
    let currentScore: Int
    let highScore: Int
    let sizeClass: UserInterfaceSizeClass?
    @State private var isAnimating = false
    
    private var isRegularSizeClass: Bool { sizeClass == .regular }
    private var labelSize: CGFloat { isRegularSizeClass ? 20 : 16 }
    private var valueSize: CGFloat { isRegularSizeClass ? 36 : 28 }

    var body: some View {
        HStack(spacing: 8) {
            if highScore <= 0 { Spacer() }

            Text("SCORE:")
                .font(.system(size: labelSize, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Text("\(currentScore)")
                .font(.bobaland(size: valueSize))
                .foregroundColor(.white)
                .scaleEffect(isAnimating ? 1.3 : 1.0)
                .onChange(of: currentScore) { _ in
                    isAnimating = false
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                        isAnimating = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            isAnimating = false
                        }
                    }
                }

            if highScore > 0 {
                Text("|")
                    .font(.system(size: labelSize, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))

                Text("BEST:")
                    .font(.system(size: labelSize, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Text("\(highScore)")
                    .font(.bobaland(size: valueSize))
                    .foregroundColor(.white)
            }

            if highScore <= 0 { Spacer() }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
}

struct LifeMeter: View {
    let totalLives: Int
    let remainingLives: Int
    let heartSize: CGFloat
    
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<totalLives, id: \.self) { index in
                Image(systemName: "heart.fill")
                    .foregroundColor(index < remainingLives ? .white : .white.opacity(0.3))
                    .font(.system(size: heartSize))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.15), in: Capsule())
    }
}

struct MiniLeaderboardView: View {
    let entries: [LeaderboardEntry]
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Leaderboard")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            
            if entries.isEmpty {
                Text("Be the first to score!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                ForEach(Array(entries.prefix(3).enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 16) {
                        Text("#\(index + 1)")
                            .font(.bobaland(size: 24))
                            .foregroundColor(.white)
                        VStack(alignment: .center) {
                            Text(entry.displayName)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text("\(entry.score) pts")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        // Removed background
    }
}

struct PlacementToastView: View {
    let placement: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("🎉")
                .font(.system(size: 32))
            VStack(alignment: .leading, spacing: 4) {
                Text("Round complete!")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("You’re currently #\(placement).")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.95))
        )
        .shadow(radius: 10)
    }
}

struct AnswerShakeModifier: ViewModifier {
    let phase: BackgroundPhase
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: phase) { newPhase in
                if newPhase == .failure {
                    shake()
                } else {
                    offset = 0
                }
            }
    }
    
    private func shake() {
        let animation = Animation.linear(duration: 0.05)
        withAnimation(animation) { offset = -10 }
        withAnimation(animation.delay(0.05)) { offset = 10 }
        withAnimation(animation.delay(0.1)) { offset = -6 }
        withAnimation(animation.delay(0.15)) { offset = 6 }
        withAnimation(animation.delay(0.2)) { offset = 0 }
    }
}

struct SideMenuView: View {
    let isEndGameEnabled: Bool
    let onLeaderboard: () -> Void
    let onSettings: () -> Void
    let onMultiplayer: () -> Void
    let onEndGame: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Game Menu")
                    .font(.bobaland(size: 42))
                    .foregroundColor(.white)
                
                SideMenuButton(icon: "trophy.fill",
                               title: "Leaderboard",
                               subtitle: "See who’s winning",
                               action: onLeaderboard)
                
                SideMenuButton(icon: "gearshape.fill",
                               title: "Settings",
                               subtitle: "Adjust your settings",
                               action: onSettings)
                
                SideMenuButton(icon: "person.3.fill",
                               title: "Multiplayer",
                               subtitle: "Play with friends",
                               action: onMultiplayer)
                
                SideMenuButton(icon: "xmark.circle.fill",
                               title: "End Game",
                               subtitle: "Return to main menu",
                               action: onEndGame, isEnabled: isEndGameEnabled)
                
                Spacer()
                
                Text("“What can I remove to make this better?”")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 32)
            }
            .padding(.top, 80)
            .padding(.bottom, 40)
            .padding(.horizontal, 28)
            .frame(width: 280, alignment: .leading)
            .background(
                LinearGradient(colors: [Color(red: 0.14, green: 0.12, blue: 0.26),
                                        Color(red: 0.22, green: 0.18, blue: 0.38)],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            )
            .ignoresSafeArea()
            
            Spacer()
        }
    }
}

private struct SideMenuButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    var isEnabled: Bool = true
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .frame(width: 44, height: 44)
                    .foregroundColor(.black)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(isEnabled ? 1 : 0.35)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}

struct SuccessFlashView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color.clear
            
            ZStack {
                RoundedRectangle(cornerRadius: 20) // Subtle background
                    .fill(Color.white.opacity(0.2))
                    .frame(width: animate ? 160 : 130, height: animate ? 160 : 130) // Slightly larger than emoji
                
                Text("👍")
                    .font(.system(size: animate ? 96 : 76))
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
            }
            .padding(36)
            .padding(24)
            // Removed background and clipShape
            .scaleEffect(animate ? 1 : 0.7)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    animate = true
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PostGameView: View {
    let score: Int
    let leaderboardEntries: [LeaderboardEntry]
    let onNewGame: () -> Void
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                
                Text("Final Score")
                    .font(.bobaland(size: 40))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("\(score)")
                    .font(.bobaland(size: 90))
                    .foregroundColor(.white)
                
                MiniLeaderboardView(entries: leaderboardEntries)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                
                Spacer()
                
                Button(action: onNewGame) {
                    Text("Play Again")
                        .font(.bobaland(size: 32))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(radius: 10)
                }
                
                Spacer().frame(height: 40)
            }
        }
    }
}

private struct PrimaryGameModeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.purple)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .shadow(radius: 5, y: 3)
    }
}

private struct ManualStartOverlay: View {
    @Binding var pendingMode: GameMode
    let onStart: () -> Void
    let onMultiplayerTapped: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Text("How do you want to play?")
                    .font(.bobaland(size: 44))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    Button(action: onStart) {
                        HStack(spacing: 20) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 32, weight: .medium))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Skill Lab")
                                    .font(.bobaland(size: 32))
                                Text("Train your brain")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .opacity(0.7)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .buttonStyle(PrimaryGameModeButtonStyle())
                    
                    Button(action: onMultiplayerTapped) {
                        HStack(spacing: 20) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 32, weight: .medium))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Multiplayer")
                                    .font(.bobaland(size: 32))
                                Text("Play with friends")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .opacity(0.7)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .buttonStyle(PrimaryGameModeButtonStyle())
                }
                
                VStack {
                    Text("Single Player Mode")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 6)
                    
                    Picker("Mode", selection: $pendingMode) {
                        ForEach(GameMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.top, 12)
            }
            .padding(28)
        }
        .transition(.opacity)
    }
}


struct HighScoreCelebrationView: View {
    let score: Int
    let onDismiss: () -> Void
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            
            VStack(spacing: 16) {
                Text("🎉")
                    .font(.system(size: 64))
                    .scaleEffect(animate ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animate)
                
                Text("You set a new record!")
                    .font(.bobaland(size: 40))
                    .foregroundColor(.white)
                
                Text("Score \(score)")
                    .font(.bobaland(size: 52))
                    .foregroundColor(.yellow)
                
                Button(action: onDismiss) {
                    Text("Awesome!")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(20)
                        .foregroundColor(.black)
                }
            }
            .padding(32)
            .background(
                LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(0.9)
            )
            .cornerRadius(36)
            .shadow(color: .pink.opacity(0.5), radius: 30, x: 0, y: 0)
        }
        .onAppear {
            animate = true
        }
    }
}
