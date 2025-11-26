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
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    @State private var hasAutoStarted = false
    @State private var confettiBursts: [ConfettiParticle] = []
    @State private var showExitPrompt = false
    
    init(
        viewModel: GameViewModel,
        onSettingsTapped: @escaping () -> Void,
        onLeaderboardTapped: @escaping () -> Void,
        onMultiplayerTapped: @escaping () -> Void,
        multiplayerPlayers: [MultiplayerPlayerState] = []
    ) {
        self.viewModel = viewModel
        self.onSettingsTapped = onSettingsTapped
        self.onLeaderboardTapped = onLeaderboardTapped
        self.onMultiplayerTapped = onMultiplayerTapped
        self.multiplayerPlayers = multiplayerPlayers
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            gameBody
        }
        .onAppear {
            viewModel.resetGame()
            SoundEffectPlayer.shared.ensureAmbientLoopRunning()
        }
        .animation(.spring(), value: viewModel.showPlacementToast)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackChevronButton {
                    showExitPrompt = true
                }
            }        }
        .alert("Leave the game?", isPresented: $showExitPrompt) {
            Button("Leave", role: .destructive) {
                viewModel.quitGame()
                presentationMode.wrappedValue.dismiss()
            }
            Button("Stay", role: .cancel) { showExitPrompt = false }
        } message: {
            Text("Your current run will end.")
        }
        .onDeviceShake(perform: handleUserRequestedQuit)
    }

    private var gameBody: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 12) {
                    
                    VStack(alignment: .trailing) {
                        ProblemView(problem: viewModel.currentProblem)
                        AnswerView(answer: viewModel.userAnswer)
                    }
                    
                    VStack (alignment: .leading) {
                        ScoreView(currentScore: viewModel.score, highScore: viewModel.highScore)
                            .onChange(of: viewModel.triggerHighScoreShake) { trigger in
                                if trigger {
                                    launchConfetti()
                                }
                            }
                        LivesView(totalLives: viewModel.totalLives, remainingLives: viewModel.remainingLives, heartSize: lifeMeterHeartSize)
                        GameCountdownView(timeRatio: viewModel.timeRemainingRatio, seconds: viewModel.timeRemainingSeconds)
                        NumpadView(
                            userAnswer: $viewModel.userAnswer,
                            isButtonEnabled: { _ in viewModel.isGameActive },
                            onDisabledPress: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                SoundEffectPlayer.shared.playBlocked()
                            },
                            onPress: { value in
                                viewModel.handleNumpadPress(value: value)
                            }
                        )
                    }
                }
                    .frame(maxWidth: 500, maxHeight: .infinity)
            }
            .padding(.horizontal, mainHorizontalPadding)
                .frame(width: geo.size.width, height: geo.size.height)
                .background(animatedBackgroundColor)
                .offset(x: viewModel.screenShake)

                if viewModel.isGameOver {
                    PostGameView(score: viewModel.score,
                                 leaderboardEntries: viewModel.leaderboardEntries,
                                 onNewGame: {
                                     self.presentationMode.wrappedValue.dismiss()
                                 })
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                }
                
                if viewModel.showHighScoreCelebration {
                    HighScoreCelebrationView(score: viewModel.score,onDismiss: viewModel.dismissCelebration)
                }

                if viewModel.showPlacementToast, let placement = viewModel.latestPlacement {
                    PlacementToastView(placement: placement)
                        .padding(.top, 80)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onTwoFingerSwipeDown(perform: handleUserRequestedQuit)
    }
    
    // MARK: - Adaptive Properties
    
    private var isRegularSizeClass: Bool { sizeClass == .regular }
    
    private var mainHorizontalPadding: CGFloat { isRegularSizeClass ? 80 : 32 }
    private var promptFontSize: CGFloat { isRegularSizeClass ? 90 : 56 }
    private var countdownClockSize: CGFloat { isRegularSizeClass ? 72 : 58 }
    private var countdownClockFontSize: CGFloat { isRegularSizeClass ? 32 : 22 }
    private var lifeMeterHeartSize: CGFloat { isRegularSizeClass ? 20 : 14 }

    private func handleUserRequestedQuit() {
        guard viewModel.isGameActive else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        viewModel.quitGame()
    }

    private var isMultiplayer: Bool { !multiplayerPlayers.isEmpty }
    private var topPadding: CGFloat { isMultiplayer ? 120 : 36 }
    
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

    private var confettiLayer: some View {
        ZStack {
            ForEach(confettiBursts) { particle in
                ConfettiParticleView(particle: particle)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func launchConfetti() {
        let now = Date().timeIntervalSince1970
        let newBursts = (0..<14).map { index in
            ConfettiParticle(
                id: "\(now)-\(index)",
                startX: CGFloat.random(in: -80...80),
                startY: CGFloat.random(in: -10...30),
                endX: CGFloat.random(in: -120...120),
                endY: CGFloat.random(in: -180...(-120)),
                delay: Double(index) * 0.02,
                lifetime: 1.4 + Double.random(in: 0...0.4),
                spin: Double.random(in: -90...180)
            )
        }
        confettiBursts.append(contentsOf: newBursts)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            confettiBursts.removeAll { particle in
                newBursts.contains(where: { $0.id == particle.id })
            }
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

private struct ConfettiParticle: Identifiable, Equatable {
    let id: String
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let delay: Double
    let lifetime: Double
    let spin: Double
}

private struct ConfettiParticleView: View {
    let particle: ConfettiParticle
    @State private var animate = false
    
    var body: some View {
        Text("🎊")
            .font(.system(size: 26))
            .opacity(animate ? 0 : 1)
            .offset(x: animate ? particle.endX : particle.startX,
                    y: animate ? particle.endY : particle.startY)
            .rotationEffect(.degrees(animate ? particle.spin : 0))
            .animation(.easeOut(duration: particle.lifetime).delay(particle.delay), value: animate)
            .onAppear {
                animate = true
            }
    }
}

struct MiniLeaderboardView: View {
    let entries: [LeaderboardEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Leaderboard")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            
            if entries.isEmpty {
                Text("Be the first to score!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(entries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 16) {
                        Text("#\(index + 1)")
                            .font(.bobaland(size: 24))
                            .foregroundColor(.white)
                        VStack(alignment: .leading) {
                            Text(entry.displayName)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text("\(entry.score) pts")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
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
                
                ScrollView {
                    MiniLeaderboardView(entries: leaderboardEntries)
                        .padding(.horizontal, 40)
                }
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

// MARK: - Gesture Helpers

private struct TwoFingerSwipeDownCaptureView: UIViewRepresentable {
    let action: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        
        let recognizer = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        recognizer.direction = .down
        recognizer.numberOfTouchesRequired = 2
        recognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(recognizer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    final class Coordinator: NSObject {
        private let action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
        
        @objc func handleSwipe(_ recognizer: UISwipeGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            action()
        }
    }
}

private struct TwoFingerSwipeDownModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content.background(TwoFingerSwipeDownCaptureView(action: action))
    }
}

private struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            action()
        }
    }
}

extension View {
    func onTwoFingerSwipeDown(perform action: @escaping () -> Void) -> some View {
        modifier(TwoFingerSwipeDownModifier(action: action))
    }
    
    func onDeviceShake(perform action: @escaping () -> Void) -> some View {
        modifier(DeviceShakeViewModifier(action: action))
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        NotificationCenter.default.post(name: .deviceDidShake, object: nil)
    }
}

struct GameSceneView_Previews: PreviewProvider {
    static var previews: some View {
        GameSceneView(
            viewModel: GameViewModel(),
            onSettingsTapped: {},
            onLeaderboardTapped: {},
            onMultiplayerTapped: {}
        )
    }
}
