//
//  GameViewModel.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import Foundation
import SwiftUI
import FirebaseAuth
import CoreHaptics // Import CoreHaptics

#if canImport(UIKit)
import UIKit
#endif

enum BackgroundPhase {
    case countdown, success, failure, timeout
}

@MainActor
class GameViewModel: ObservableObject {
    @Published var currentProblem: Problem = Problem(a: 2, b: 2, operation: .multiply)
    @Published var userAnswer: String = ""
    @Published var score: Int = 0
    @Published var isGameActive: Bool = true
    @Published var backgroundPhase: BackgroundPhase = .countdown
    @Published var timeRemainingRatio: Double = 1.0
    @Published var rawTimeRemaining: Double = 0.0 // New variable for millisecond precision
    @Published var timeRemainingSeconds: Int = 0
    @Published var screenShake: CGFloat = 0
    @Published var currentLevelIndex: Int = 0
    @Published var questionsAnsweredInLevel: Int = 0
    @Published var remainingLives: Int = 3
    @Published var isGameOver: Bool = false
    @Published var highScore: Int = 0
    @Published var showHighScoreCelebration: Bool = false
    @Published var didBeatHighScore: Bool = false
    @Published var showSuccessFlash: Bool = false
    @Published var latestPlacement: Int?
    @Published var showPlacementToast: Bool = false
    @Published var gameMode: GameMode
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var triggerHighScoreShake = false
    
    private let maxLives = 3
    private let modeStorageKey = "MathBlitzGameMode"
    private var shouldShowPlacementToast = false
    private var problemsGeneratedInCurrentGame: Set<Problem> = []
    
    var gameTimer: Timer?
    private var heartbeatTimer: Timer?
    private let timerResolution: TimeInterval = 0.05
    private var roundStartTime: Date = Date()
    
    private var hapticEngine: CHHapticEngine?
    
    private let kidsLevels = [
        Level(levelNumber: 1, numberRange: 2...5, gameDuration: 20.0, questionsPerLevel: 5),
        Level(levelNumber: 2, numberRange: 2...8, gameDuration: 20.0, questionsPerLevel: 6),
        Level(levelNumber: 3, numberRange: 2...10, gameDuration: 20.0, questionsPerLevel: 8),
        Level(levelNumber: 4, numberRange: 4...12, gameDuration: 20.0, questionsPerLevel: 10),
        Level(levelNumber: 5, numberRange: 8...15, gameDuration: 20.0, questionsPerLevel: 12)
    ]
    
    private let adultLevels = [
        Level(levelNumber: 1, numberRange: 5...12, gameDuration: 8.0, questionsPerLevel: 6),
        Level(levelNumber: 2, numberRange: 5...15, gameDuration: 7.0, questionsPerLevel: 8),
        Level(levelNumber: 3, numberRange: 6...18, gameDuration: 6.0, questionsPerLevel: 10),
        Level(levelNumber: 4, numberRange: 8...22, gameDuration: 5.5, questionsPerLevel: 12),
        Level(levelNumber: 5, numberRange: 10...25, gameDuration: 5.0, questionsPerLevel: 14)
    ]
    
    var levels: [Level] { gameMode == .kids ? kidsLevels : adultLevels }
    var currentLevel: Level { levels[min(currentLevelIndex, levels.count - 1)] }
    var totalLives: Int { maxLives }
    var isMultiplayerContext: Bool = false
    
    init() {
        let storedModeRaw = UserDefaults.standard.string(forKey: modeStorageKey)
        let storedMode = GameMode(rawValue: storedModeRaw ?? "") ?? .kids
        self.gameMode = storedMode
        self.highScore = UserDefaults.standard.integer(forKey: highScoreStorageKey(for: storedMode))
        
        prepareHeartbeatHaptics()
        
        if Auth.auth().currentUser != nil {
            Task { [weak self] in await self?.fetchLeaderboard() }
        }
    }
    
    func updateGameMode(_ mode: GameMode) {
        guard mode != gameMode else { return }
        gameMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: modeStorageKey)
        loadHighScore(for: mode)
        resetGame()
        Task { [weak self] in await self?.fetchLeaderboard() }
    }
    
    func fetchLeaderboard() async {
        do {
            let entries = try await LeaderboardService.shared.fetchTopEntries(mode: gameMode, limit: 10)
            leaderboardEntries = entries
            updatePlacement(using: entries)
            maybeTriggerPlacementToast()
        } catch { print("Failed to load leaderboard: \(error.localizedDescription)") }
    }

    func handleNumpadPress(value: String) {
        guard isGameActive else { return }
        if value == "⌫" { if !userAnswer.isEmpty { userAnswer.removeLast() } }
        else if value == "C" { userAnswer = "" }
        else {
            userAnswer += value
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self, self.isGameActive else { return }
                if let answerInt = Int(self.userAnswer), answerInt == self.currentProblem.answer {
                    self.checkAnswer(correct: true)
                } else if self.userAnswer.count >= String(self.currentProblem.answer).count {
                    self.checkAnswer(correct: false)
                }
            }
        }
    }
    
    func newRound() {
        guard !isGameOver else { return }
        stopTimers()
        isGameActive = true
        userAnswer = ""
        backgroundPhase = .countdown
        timeRemainingRatio = 1.0
        rawTimeRemaining = currentLevel.gameDuration // Initialize rawTimeRemaining
        timeRemainingSeconds = Int(ceil(currentLevel.gameDuration))
        generateProblem()
        startCountdown()
    }
    
    func handleTimesUp() {
        guard isGameActive, backgroundPhase != .timeout else { return }
        stopTimers()
        isGameActive = false
        backgroundPhase = .timeout
        triggerScreenShake()
        triggerHapticFailure()
        registerMistake()
        rawTimeRemaining = 0.0 // Ensure rawTimeRemaining is 0
        scheduleNextRound(after: 1.2)
    }
    
    func checkAnswer(correct: Bool) {
        guard isGameActive else { return }
        stopTimers()
        isGameActive = false
        
        if correct {
            score += timeRemainingSeconds
            if score > highScore && highScore > 0 && !didBeatHighScore {
                didBeatHighScore = true; triggerHighScoreShake = true
            }
            questionsAnsweredInLevel += 1
            backgroundPhase = .success
            triggerSuccessFlash()
            if questionsAnsweredInLevel >= currentLevel.questionsPerLevel { levelUp() }
            scheduleNextRound(after: 0.4)
        } else {
            backgroundPhase = .failure
            triggerScreenShake()
            triggerHapticFailure()
            registerMistake()
            scheduleNextRound(after: 0)
        }
    }
    
    func levelUp() {
        currentLevelIndex = min(currentLevelIndex + 1, levels.count - 1)
        questionsAnsweredInLevel = 0
    }
    
    func resetGame() {
        stopTimers()
        score = 0; currentLevelIndex = 0; questionsAnsweredInLevel = 0
        backgroundPhase = .countdown; timeRemainingRatio = 1.0
        remainingLives = maxLives; isGameOver = false
        showHighScoreCelebration = false; didBeatHighScore = false; triggerHighScoreShake = false
        loadHighScore(for: gameMode)
        userAnswer = ""; problemsGeneratedInCurrentGame.removeAll()
        newRound()
        TestGameStartNotifier.shared.broadcastGameStart(mode: gameMode)
    }
    
    func prepareForManualRestart() {
        stopTimers()
        score = 0; currentLevelIndex = 0; questionsAnsweredInLevel = 0
        backgroundPhase = .countdown; timeRemainingRatio = 1.0; rawTimeRemaining = currentLevel.gameDuration; timeRemainingSeconds = Int(ceil(currentLevel.gameDuration))
        remainingLives = maxLives; showHighScoreCelebration = false; didBeatHighScore = false
        triggerHighScoreShake = false; userAnswer = ""; isGameActive = false; isGameOver = false
    }
    
    func quitGame() {
        stopTimers()
        isGameActive = false
        isGameOver = true
    }
    
    func dismissCelebration() {
        showHighScoreCelebration = false
        didBeatHighScore = false
    }
    
    func triggerScreenShake() {
        let shakeAmount: CGFloat = 10
        withAnimation(.default) { screenShake = shakeAmount }
        withAnimation(.default.delay(0.1)) { screenShake = -shakeAmount }
        withAnimation(.default.delay(0.2)) { screenShake = shakeAmount }
        withAnimation(.default.delay(0.3)) { screenShake = 0 }
    }
    
    private func stopTimers() {
        gameTimer?.invalidate()
        gameTimer = nil
        stopHeartbeat()
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func registerMistake() {
        remainingLives = max(0, remainingLives - 1)
        if remainingLives == 0 { endGame() }
    }
    
    private func endGame() {
        stopTimers()
        isGameActive = false; isGameOver = true
        if !isMultiplayerContext {
            updateHighScoreIfNeeded()
            submitScoreToLeaderboard(score)
        }
        timeRemainingSeconds = 0; rawTimeRemaining = 0.0
    }
    
    private func updateHighScoreIfNeeded() {
        guard !isMultiplayerContext else { return }
        guard score > highScore else { didBeatHighScore = false; return }
        highScore = score
        UserDefaults.standard.set(score, forKey: highScoreStorageKey(for: gameMode))
        showHighScoreCelebration = true; didBeatHighScore = true
    }
    
    private func scheduleNextRound(after delay: TimeInterval) {
        if delay <= 0 { newRound(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.newRound() }
    }
    
    private func generateProblem() {
        let range = currentLevel.numberRange
        let allowedOperations: [OperationType] = gameMode == .kids ? [.add, .subtract, .multiply] : [.add, .subtract, .multiply]
        var newProblem: Problem
        repeat {
            newProblem = Problem.random(range: range, operations: allowedOperations)
        } while problemsGeneratedInCurrentGame.contains(newProblem) && problemsGeneratedInCurrentGame.count < range.count * range.count * allowedOperations.count
        self.currentProblem = newProblem
        problemsGeneratedInCurrentGame.insert(newProblem)
    }
    
    private func startCountdown() {
        roundStartTime = Date()
        stopTimers()
        timeRemainingRatio = 1.0
        timeRemainingSeconds = Int(ceil(currentLevel.gameDuration))
        gameTimer = Timer.scheduledTimer(withTimeInterval: timerResolution, repeats: true) { [weak self] timer in
            self?.handleTimerTick(timer: timer)
        }
    }
    
    private func handleTimerTick(timer: Timer) {
        let elapsed = Date().timeIntervalSince(roundStartTime)
        let duration = currentLevel.gameDuration
        let remaining = duration - elapsed
        
        if remaining <= 0 {
            timeRemainingRatio = 0; timeRemainingSeconds = 0; rawTimeRemaining = 0.0; handleTimesUp(); return
        }
        
        // Trigger heartbeat haptic when 30% of time is left
        if remaining <= currentLevel.gameDuration * 0.3 && heartbeatTimer == nil { startHeartbeat() }
        
        timeRemainingRatio = max(0, min(1, remaining / duration))
        timeRemainingSeconds = max(0, Int(ceil(remaining)))
        rawTimeRemaining = remaining
    }
    
    private func prepareHeartbeatHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            
            hapticEngine?.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason)")
            }
            hapticEngine?.resetHandler = { [weak self] in
                print("Haptic engine reset. Restarting.")
                do {
                    try self?.hapticEngine?.start()
                } catch {
                    print("Failed to restart the haptic engine: \(error)")
                }
            }
        } catch {
            print("Error creating or starting haptic engine: \(error.localizedDescription)")
        }
    }
    

    
    private func triggerHapticFailure() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }

    private func startHeartbeat() {
        guard heartbeatTimer == nil else { return }
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
            self.playHeartbeatHapticPattern()
        }
    }
    
    private func playHeartbeatHapticPattern() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, let engine = hapticEngine else { return }
        do {
            try engine.start() // Idempotent call
            var events = [CHHapticEvent]()
            let intensity1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
            let sharpness1 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            let event1 = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity1, sharpness1], relativeTime: 0)
            let intensity2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
            let sharpness2 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            let event2 = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity2, sharpness2], relativeTime: 0.18)
            events.append(contentsOf: [event1, event2])
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play heartbeat pattern: \(error.localizedDescription)")
        }
    }
    
    private func submitScoreToLeaderboard(_ finalScore: Int) {
        guard !isMultiplayerContext, finalScore > 0 else { return }
        let mode = gameMode
        Task { [weak self] in
            do {
                try await LeaderboardService.shared.submitScore(finalScore, mode: mode)
                await self?.fetchLeaderboard()
            } catch { print("Failed to submit leaderboard score: \(error.localizedDescription)") }
        }
    }
    
    private func loadHighScore(for mode: GameMode) {
        highScore = UserDefaults.standard.integer(forKey: highScoreStorageKey(for: mode))
    }
    
    private func highScoreStorageKey(for mode: GameMode) -> String {
        return "MathBlitzHighScore_\(mode.rawValue)"
    }
    
    private func triggerSuccessFlash() {
        guard !showSuccessFlash else { return }
        showSuccessFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.showSuccessFlash = false
        }
    }
    
    private func updatePlacement(using entries: [LeaderboardEntry]) {
        guard let currentId = Auth.auth().currentUser?.uid else { latestPlacement = nil; return }
        if let index = entries.firstIndex(where: { $0.id == currentId }) {
            latestPlacement = index + 1
        } else {
            latestPlacement = nil
        }
    }
    
    private func maybeTriggerPlacementToast() {
        guard shouldShowPlacementToast, latestPlacement != nil else { return }
        shouldShowPlacementToast = false
        showPlacementToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.showPlacementToast = false
        }
    }
}